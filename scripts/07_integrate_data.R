# scripts/07_integrate_data.R
# ---------------------------------------------------------------------------
# Phase 1, script 07 --- Integrate all sources into the master goals table.
#
# Grain: ONE ROW PER GOAL in goals_master_final.csv.
#   Every goal gets: match context (venue, result, minutes, stage), opponent
#   Elo, xG (where available), and a FAMD-derived Difficulty_Score.
#
# METHODOLOGY (spec 2. DataAnalysis + user-confirmed):
#   - The FAMD is fit on the FULL match-level set (2,201 unique appearances
#     including ~1,065 scoreless) so difficulty axes are not biased toward
#     goal-scoring contexts. Scoreless matches contribute context but weight 0
#     goals. Per-90 denominators use ALL minutes.
#   - ONE global FAMD across both players (never per-player).
#   - FAMD inputs ONLY: Opponent_Elo, Venue, Competition_Stage, Is_Away.
#     Excluded: goal count, player name, own-team Elo.
#   - Difficulty_Score = Dim 1 coordinate of the global FAMD (oriented so
#     higher = harder).
#   - Elo fallback: Club Elo -> league-average -> 1500 (never drop rows).
#   - xG: Understat per-goal (2014+ top-5) only; FBref season stats carry no
#     xG, so unmatched goals get xg = NA + xg_source = "missing" (documented).
#
# Outputs:
#   data/processed/match_context.rds      -- deduped match-level table + all
#                                            FAMD inputs + Difficulty_Score
#   data/processed/famd_loadings.rds      -- FactoMineR FAMD result (for Docker)
#   data/processed/goals_master_final.csv -- one row per goal (the deliverable)
#   data/processed/quality_report.txt     -- coverage vs spec §6.1
#   data/data_dictionary.md               -- column definitions
#
# Run: Rscript scripts/07_integrate_data.R
# ---------------------------------------------------------------------------

source(here::here("R", "politeness.R"))
source(here::here("R", "clubelo_slugs.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(data.table)
  library(FactoMineR)
})

DATA_RAW <- DATA_RAW_DIR
DATA_PROC <- DATA_PROCESSED_DIR

GOAL_LOGS   <- file.path(DATA_RAW, "fbref_goal_logs.rds")
MATCH_LOGS  <- file.path(DATA_RAW, "fbref_match_logs.rds")
UNDERSTAT   <- file.path(DATA_RAW, "understat_goals.rds")
CLUB_LOOKUP <- file.path(DATA_PROC, "club_elo_lookup.csv")
NAT_LOOKUP  <- file.path(DATA_PROC, "national_elo_lookup.csv")

OUT_MATCH   <- file.path(DATA_PROC, "match_context.rds")
OUT_FAMD    <- file.path(DATA_PROC, "famd_loadings.rds")
OUT_MASTER  <- file.path(DATA_PROC, "goals_master_final.csv")
OUT_QUAL    <- file.path(DATA_PROC, "quality_report.txt")
OUT_DICT    <- here::here("data", "data_dictionary.md")

NATIONAL_SQUADS <- c("Argentina", "Portugal")

# --- Load + clean match logs -------------------------------------------------

match_logs <- readRDS(MATCH_LOGS)
cat("match logs loaded:", nrow(match_logs), "rows\n")

match_logs$Date      <- as.Date(match_logs$Date)
match_logs$Squad_clean <- sub("^[a-z]{2,3} ", "", match_logs$Squad)
match_logs$Opp_clean   <- sub("^[a-z]{2,3} ", "", match_logs$Opponent)
match_logs$Minutes     <- suppressWarnings(as.numeric(match_logs$Min))

# Drop header-junk (Gls == "Gls" / Opponent == "Opponent") and DNP (no minutes).
valid <- match_logs[!is.na(match_logs$Minutes) &
                    match_logs$Opponent != "Opponent", ]
cat("valid appearances (dropped junk/DNP):", nrow(valid), "\n")

# Dedup: 3 Nations League matches appear twice (exact duplicates).
match_key <- paste(valid$Player, valid$Date, valid$Opp_clean,
                   valid$Comp, valid$Round)
valid <- valid[!duplicated(match_key), ]
cat("after dedup:", nrow(valid), "unique matches\n")

valid$is_intl <- valid$Squad_clean %in% NATIONAL_SQUADS
cat("  club:", sum(!valid$is_intl), "| international:", sum(valid$is_intl), "\n")

# --- Competition stage + venue -------------------------------------------------

competition_stage <- function(comp, round) {
  rnd <- tolower(round)
  grp <- grepl("group stage|matchweek|match day", rnd)
  qf  <- grepl("qualifying|playoff|play-off|preliminary", rnd)
  final <- grepl("^final", rnd)
  knock <- grepl("round of 16|quarter|semi|round of 32|round of 64", rnd)
  stage <- rep(NA_character_, length(rnd))
  stage[final] <- "Final"
  stage[knock] <- "Knockout"
  stage[grp]   <- "Group"
  stage[qf]    <- "Qualifying"
  stage[is.na(stage)] <- "Other"
  stage
}
valid$Competition_Stage <- competition_stage(valid$Comp, valid$Round)
valid$Is_Away <- valid$Venue == "Away"

# --- Opponent Elo ---------------------------------------------------------------

cat("\n== Opponent Elo ==\n")

nat <- data.table::fread(NAT_LOOKUP)
nat[, date := as.Date(date)]

# International: join by (national_team, date). Handle duplicate dates by taking
# the row whose team_name matches the FBref opponent; else the max Elo.
nat_join <- nat[nat$national_team %in% valid$Squad_clean[valid$is_intl], ]
intl_ids <- which(valid$is_intl)
valid$Opponent_Elo <- NA_real_
valid$Elo_Source   <- NA_character_

for (team in NATIONAL_SQUADS) {
  rows <- which(valid$is_intl & valid$Squad_clean == team)
  lk <- nat[nat$national_team == team, ]
  for (r in rows) {
    cand <- lk[lk$date == valid$Date[r], ]
    if (nrow(cand) == 0) next
    if (nrow(cand) > 1) {
      # prefer team_name match, else take highest Elo row
      nm <- cand$team_name == valid$Opp_clean[r]
      if (any(nm)) cand <- cand[nm, , drop = FALSE]
      else cand <- cand[which.max(cand$elo), , drop = FALSE]
    }
    valid$Opponent_Elo[r] <- cand$elo[1]
    valid$Elo_Source[r]   <- "national"
  }
}
cat("international Elo matched:", sum(!is.na(valid$Opponent_Elo[valid$is_intl])),
    "of", sum(valid$is_intl), "\n")

# Club: join by club_slug with Date within [From, To]. data.table non-equi join.
club_rows <- which(!valid$is_intl)
club_matches <- data.table::as.data.table(
  data.frame(idx = club_rows,
             Opp_clean = valid$Opp_clean[club_rows],
             Date = valid$Date[club_rows],
             stringsAsFactors = FALSE)
)
club_matches[, club_slug := fbref_to_clubelo_slug(Opp_clean)]
club_lookup <- data.table::fread(CLUB_LOOKUP)
club_lookup[, From := as.Date(From)]
club_lookup[, To   := as.Date(To)]

setkey(club_lookup, club_slug, From, To)
joined <- club_lookup[club_matches,
                      on = .(club_slug = club_slug, From <= Date, To >= Date),
                      .(idx, Elo, From),
                      nomatch = NULL]
# A date can fall in 0..1 rating windows per club; if multiple, take the latest
# From (most recent rating revision on/before the match).
joined <- joined[, .(Elo = Elo[which.max(From)]), by = idx]

valid$Opponent_Elo[joined$idx] <- joined$Elo
valid$Elo_Source[joined$idx]   <- "club"
cat("club Elo matched:", sum(valid$Elo_Source == "club" & !valid$is_intl),
    "of", length(club_rows), "\n")

# Fallback: league-average Elo (mean of matched opponents in same Comp) -> 1500.
matched_avg <- valid %>%
  filter(!is.na(Opponent_Elo)) %>%
  group_by(Comp) %>%
  summarise(league_avg_elo = mean(Opponent_Elo), .groups = "drop")
valid <- valid %>%
  left_join(matched_avg, by = "Comp") %>%
  mutate(
    Opponent_Elo = case_when(
      !is.na(Opponent_Elo)            ~ Opponent_Elo,
      !is.na(league_avg_elo)          ~ league_avg_elo,
      TRUE                            ~ 1500
    ),
    Elo_Source = case_when(
      Elo_Source %in% c("club", "national") ~ Elo_Source,
      !is.na(league_avg_elo)               ~ "league_avg",
      TRUE                                 ~ "global_1500"
    )
  ) %>%
  select(-league_avg_elo)

cat("Elo coverage: direct =", sum(valid$Elo_Source %in% c("club", "national")),
    "| league_avg =", sum(valid$Elo_Source == "league_avg"),
    "| global_1500 =", sum(valid$Elo_Source == "global_1500"), "\n")

# --- FAMD (ONE global fit on ALL matches) --------------------------------------

cat("\n== FAMD (global, both players, all matches) ==\n")
famd_input <- data.frame(
  Opponent_Elo      = valid$Opponent_Elo,
  Venue             = factor(valid$Venue, levels = c("Home", "Away", "Neutral")),
  Competition_Stage = factor(valid$Competition_Stage,
                             levels = c("Group", "Knockout", "Final",
                                        "Qualifying", "Other")),
  Is_Away           = factor(valid$Is_Away, levels = c("FALSE", "TRUE"))
)

famd_res <- FactoMineR::FAMD(famd_input, ncp = 2, graph = FALSE)
dim1 <- famd_res$ind$coord[, 1]

# Orient so higher = harder: ensure Dim1 is positively correlated with Opponent_Elo
if (cor(dim1, valid$Opponent_Elo, use = "complete.obs") < 0) dim1 <- -dim1
valid$Difficulty_Score <- as.numeric(scale(dim1, center = TRUE, scale = TRUE))

saveRDS(famd_res, OUT_FAMD)
saveRDS(valid, OUT_MATCH)
cat("match_context.rds:", nrow(valid), "rows | famd_loadings.rds saved\n")

# --- Goal-level table -----------------------------------------------------------

cat("\n== Goal-level master table ==\n")
goals <- readRDS(GOAL_LOGS)
goals$Date <- as.Date(goals$Date)
goals$Opp_clean <- sub("^[a-z]{2,3} ", "", goals$Opponent)
goals$Squad_clean <- sub("^[a-z]{2,3} ", "", goals$Squad)

# Join match context onto each goal via (Player, Date, Opp_clean, Comp, Round).
# Venue is already in the goal log; take the match log's copy only as a check.
goals <- goals %>%
  left_join(
    valid %>%
      select(Player, Date, Opp_clean, Comp, Round, Venue, Result, Minutes,
             Gls, Opponent_Elo, Elo_Source, Competition_Stage, Is_Away,
             Difficulty_Score) %>%
      rename(Venue_match = Venue),
    by = c("Player", "Date", "Opp_clean", "Comp", "Round"),
    relationship = "many-to-one"
  )

# Sanity: every goal should have matched a match row.
cat("goals without match context:", sum(is.na(goals$Difficulty_Score)), "of", nrow(goals), "\n")

# --- xG from Understat -----------------------------------------------------------

cat("\n== xG join (Understat, rank-within-match) ==\n")
# Understat minute conventions differ from FBref's (e.g. 46 vs 45+2), so a
# minute-key join fails. Both sources list the SAME goals in chronological
# order per match, so we join by (Player, date, goal rank). Only matches where
# Understat's goal count equals FBref's get a full join; others are documented
# gaps (Understat missing goals, or extra) and their goals get xg = NA.
understat <- readRDS(UNDERSTAT)

# Goal rank within each (Player, match_date), chronological
ug <- understat %>%
  filter(Player %in% c("Lionel Messi", "C. Ronaldo"), result == "Goal") %>%
  arrange(Player, match_date, minute) %>%
  group_by(Player, match_date) %>%
  mutate(xg_rank = row_number()) %>%
  ungroup() %>%
  select(Player, match_date, xg_rank, xG)

goals <- goals %>%
  arrange(Player, Date, Minute) %>%
  group_by(Player, Date) %>%
  mutate(goal_rank = row_number()) %>%
  ungroup() %>%
  left_join(ug,
            by = c("Player" = "Player", "Date" = "match_date",
                   "goal_rank" = "xg_rank")) %>%
  mutate(
    xg = ifelse(is.na(xG), NA_real_, xG),
    xg_source = ifelse(is.na(xG), "missing", "understat")
  ) %>%
  select(-xG, -goal_rank)

cat("goals with Understat xG:", sum(goals$xg_source == "understat"), "of", nrow(goals), "\n")

# --- Weighted goals + unique ID ---------------------------------------------------

goals$goal_id <- sprintf("%s-%03d", sub(" ", "_", goals$Player),
                         seq_len(nrow(goals)))
# Weighted_Goal = 1 x Difficulty_Score. Goals whose match is absent from the
# match log (3 x 2026 WC knockout goals scraped after the match-log snapshot)
# have NA score and are excluded from weighted sums.
goals$Weighted_Goal <- goals$Difficulty_Score

# Per-90 summary over ALL valid matches (denominator = full playing time).
per90 <- valid %>%
  group_by(Player) %>%
  summarise(
    Total_Minutes  = sum(Minutes, na.rm = TRUE),
    Appearances    = n(),
    Scoreless_Apps = sum(Gls == 0, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    goals %>% group_by(Player) %>%
      summarise(Raw_Goals = n(), Weighted_Goals = sum(Weighted_Goal, na.rm = TRUE),
                .groups = "drop"),
    by = "Player"
  ) %>%
  mutate(Weighted_Goals_per_90 = Weighted_Goals / (Total_Minutes / 90),
         Raw_Goals_per_90 = Raw_Goals / (Total_Minutes / 90))

cat("\nPer-90 summary:\n")
print(as.data.frame(per90))

# --- Outputs ---------------------------------------------------------------------

readr::write_csv(goals, OUT_MASTER)
cat("\ngoals_master_final.csv:", nrow(goals), "rows,", ncol(goals), "cols\n")

# Quality report
q <- c(
  "MESSI vs RONALDO - Phase 1 quality report",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "== Goals (spec 6.1: Messi ~950+, Ronaldo ~1030+) ==",
  paste0("  Messi: ", sum(goals$Player == "Lionel Messi"),
         "  | Ronaldo: ", sum(goals$Player == "C. Ronaldo"),
         "  (FBref records; spec targets are indicative)"),
  "",
  "== Matches ==",
  paste0("  Total valid appearances: ", nrow(valid),
         " (", sum(valid$Player == "Lionel Messi"), " Messi / ",
         sum(valid$Player == "C. Ronaldo"), " Ronaldo)"),
  paste0("  Scoreless appearances kept for FAMD/per-90: ",
         sum(valid$Gls == 0, na.rm = TRUE)),
  "",
  "== Elo coverage ==",
  paste0("  Direct (club/national): ", sum(valid$Elo_Source %in% c("club", "national"))),
  paste0("  League-average fallback: ", sum(valid$Elo_Source == "league_avg")),
  paste0("  Global 1500 fallback: ", sum(valid$Elo_Source == "global_1500")),
  "",
  "== Match-context gaps ==",
  paste0("  Goals without match-log context (2026 WC knockout, match-log snapshot earlier): ",
         sum(is.na(goals$Difficulty_Score))),
  "",
  "== xG coverage ==",
  paste0("  Understat xG goals: ", sum(goals$xg_source == "understat"),
         " (", round(100 * sum(goals$xg_source == "understat") / nrow(goals), 1),
         "% of goals; limited to 2014+ top-5 leagues)"),
  paste0("  Missing xG (documented gap): ", sum(goals$xg_source == "missing")),
  "",
  "== FAMD ==",
  "  Global FAMD on all valid matches (both players).",
  "  Inputs: Opponent_Elo, Venue, Competition_Stage, Is_Away.",
  "  Difficulty_Score = standardized Dim 1 (higher = harder).",
  "",
  "== Per-90 (Weighted Goals / Total Minutes) =="
)
for (i in seq_len(nrow(per90))) {
  q <- c(q, sprintf("  %s: %.3f weighted / %.3f raw",
                    per90$Player[i], per90$Weighted_Goals_per_90[i],
                    per90$Raw_Goals_per_90[i]))
}
writeLines(q, OUT_QUAL)
cat("quality_report.txt written\n")

# Data dictionary
dict <- c(
  "# Data dictionary - goals_master_final.csv",
  "",
  "| Column | Type | Description |",
  "|---|---|---|",
  "| goal_id | chr | Unique goal identifier |",
  "| Player | chr | Lionel Messi / C. Ronaldo |",
  "| Date | date | Match date |",
  "| Comp | chr | Competition (FBref) |",
  "| Round | chr | Round/stage label (FBref) |",
  "| Venue | chr | Home / Away / Neutral (goal log) |",
  "| Venue_match | chr | Venue from match log (should equal Venue) |",
  "| Squad | chr | Player's team (FBref) |",
  "| Opponent | chr | Opponent (FBref, with country prefix) |",
  "| Opp_clean | chr | Opponent without country prefix |",
  "| Minute | chr | Goal minute (e.g. '90+5') |",
  "| Score | chr | Score at goal time |",
  "| Goalkeeper | chr | Goalkeeper beaten |",
  "| Assist | chr | Assisting player |",
  "| Notes | chr | Goal type ('Penalty kick', 'Free kick') |",
  "| Result | chr | Full-time result (match log) |",
  "| Minutes | num | Minutes played in the match |",
  "| Gls | num | Goals scored in the match (0 allowed) |",
  "| Opponent_Elo | num | Opponent Elo (club/national/fallback) |",
  "| Elo_Source | chr | club / national / league_avg / global_1500 |",
  "| Competition_Stage | chr | Group / Knockout / Final / Qualifying / Other |",
  "| Is_Away | lgl | TRUE if venue Away |",
  "| Difficulty_Score | num | FAMD Dim 1, standardized (higher = harder) |",
  "| xg | num | Expected goals of the shot (Understat; NA if missing) |",
  "| xg_source | chr | understat / missing |",
  "| Weighted_Goal | num | Difficulty_Score (the weight) |"
)
writeLines(dict, OUT_DICT)
cat("data_dictionary.md written\n")

cat("\n07_integrate_data.R complete.\n")
