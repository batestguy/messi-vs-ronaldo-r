# 08_prepare_analysis.R
# Phase 2 Wave 0: build the analysis bundle consumed by the Shiny dashboard.
#
# Inputs (Phase 1 outputs, committed, immutable):
#   data/processed/goals_master_final.csv   (1,738 goals, one row per goal)
#   data/processed/match_context.rds        (2,201 matches, incl. 1,063 scoreless)
#   data/processed/famd_loadings.rds        (global FAMD output — loadings only, never re-run)
#
# Output:
#   data/processed/analysis_bundle.rds      (single RDS consumed by the app)
#   app/data/analysis_bundle.rds            (copy inside the app dir for rsconnect/Docker)
#   app/data/goals_master_final.csv          (exact source copy for Wave 5 Raw Data)
#
# Methodology constraints honoured (see AGENTS.md):
#   * ONE global FAMD on both players, never re-run in the app.
#   * Difficulty_Score = standardized Dim 1; Weighted_Goal = 1 x Difficulty_Score.
#   * No rows dropped: NA Elo stays NA (3 WC-knockout goals); per-90 denominators
#     use ALL valid minutes, scoreless matches included.
#   * K-slider support: signed power transform sign(x)*abs(x)^K applied in-app to
#     Weighted_Goal (negative scores preserved — plain x^K would produce NaN).
#   * Bootstrap data is match-level (each row = one appearance).
#
# Run:
#   Rscript scripts/08_prepare_analysis.R

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
})

BASE <- dirname(normalizePath(commandArgs(trailingOnly = FALSE)[1]))
# commandArgs file path points at the script; BASE becomes scripts/ dir
BASE <- sub("/scripts[^/]*$", "", BASE)
if (!dir.exists(file.path(BASE, "data"))) BASE <- "."  # fallback: run from repo root
if (!dir.exists(file.path(BASE, "data"))) stop("Cannot locate repo root; run from repo root or via scripts/")

G_PATH  <- file.path(BASE, "data/processed/goals_master_final.csv")
MC_PATH <- file.path(BASE, "data/processed/match_context.rds")
FA_PATH <- file.path(BASE, "data/processed/famd_loadings.rds")
OUT     <- file.path(BASE, "data/processed/analysis_bundle.rds")
APP_OUT <- file.path(BASE, "app/data/analysis_bundle.rds")
APP_RAW <- file.path(BASE, "app/data/goals_master_final.csv")

stopifnot(file.exists(G_PATH), file.exists(MC_PATH), file.exists(FA_PATH))
dir.create(dirname(APP_OUT), recursive = TRUE, showWarnings = FALSE)

## ---------------------------------------------------------------------------
## 1. Load + normalise
## ---------------------------------------------------------------------------
goals   <- as.data.table(fread(G_PATH))
matches <- as.data.table(readRDS(MC_PATH))
famd    <- readRDS(FA_PATH)

norm_player <- function(x) ifelse(x == "C. Ronaldo", "Ronaldo", ifelse(x == "Lionel Messi", "Messi", x))
goals[, Player := norm_player(Player)]
matches[, Player := norm_player(Player)]

# Dates: goals$Date is IDate in data.table; matches$Date is Date
goals[, Date := as.Date(Date)]
matches[, Date := as.Date(Date)]
goals[, Season := as.integer(format(Date, "%Y")) + (as.integer(format(Date, "%m")) >= 7)]
matches[, Season := as.integer(format(Date, "%Y")) + (as.integer(format(Date, "%m")) >= 7)]

## ---------------------------------------------------------------------------
## 2. Derived fields
## ---------------------------------------------------------------------------
# Era buckets (season start year), ordered factor for plots
ERA_BREAKS  <- c(0, 2009, 2015, 2019, 2023, Inf)
ERA_LABELS  <- c("Rise (2002-08)", "Peak (2009-14)", "Prime (2015-18)",
                 "Transition (2019-22)", "Late (2023-26)")
era_of <- function(s) factor(cut(s, breaks = ERA_BREAKS, labels = ERA_LABELS, right = FALSE),
                             levels = ERA_LABELS, ordered = TRUE)
goals[, Era := era_of(Season)]
matches[, Era := era_of(Season)]

# Penalty flag lives in Notes ("Penalty kick")
goals[, Penalty := !is.na(Notes) & Notes == "Penalty kick"]
goals[, Penalty := ifelse(is.na(Penalty), FALSE, Penalty)]

# Competition grouping for filters
COMP_GROUP <- c(
  "La Liga" = "League", "Premier League" = "League", "Serie A" = "League",
  "Ligue 1" = "League", "Primeira Liga" = "League", "Pro League" = "League",
  "MLS" = "League",
  "Champions Lg" = "Continental", "Europa Lg" = "Continental",
  "CCC" = "Continental", "Club World Cup" = "Continental",
  "Super Cup" = "Continental", "Supercopa" = "Continental",
  "Supercoppa" = "Continental", "Trophée des Champions" = "Continental",
  "Leagues Cup" = "Continental",
  "Copa del Rey" = "Domestic cup", "Coppa Italia" = "Domestic cup",
  "World Cup" = "International", "UEFA Euro" = "International",
  "Copa América" = "International", "Copa América Centenario" = "International",
  "WCQ" = "International", "Friendlies (M)" = "International",
  "UEFA Euro qual." = "International", "UEFA Nations League" = "International",
  "FIFA Confederations Cup" = "International"
)
goals[, Comp_Group := unname(COMP_GROUP[Comp])]
goals[is.na(Comp_Group), Comp_Group := "Other"]

# is_intl for matches -> carry onto goals via (Player, Date, Comp) join
intl_map <- unique(matches[, .(Player, Date, Comp, is_intl)])
goals <- merge(goals, intl_map, by = c("Player", "Date", "Comp"), all.x = TRUE, sort = FALSE)
goals[is.na(is_intl), is_intl := FALSE]   # 3 WC-knockout goals lack match context
goals[, Club_Goal := is_intl == FALSE]

# Elo source coverage stats
coverage <- goals[, .N, by = Elo_Source][order(-N)]

## ---------------------------------------------------------------------------
## 3. Per-90 tables (denominators = ALL valid match minutes)
## ---------------------------------------------------------------------------
valid <- matches[!is.na(Minutes) & Minutes > 0]
min_by_player <- valid[, .(Minutes = sum(Minutes), Apps = .N), by = Player]

per90_one <- function(gg, mm, with_pen = TRUE) {
  if (!with_pen) gg <- gg[Penalty == FALSE]
  agg <- gg[, .(Weighted = sum(Weighted_Goal, na.rm = TRUE), Raw = .N, GoalsN = .N), by = Player]
  agg <- merge(agg, mm, by = "Player", all.y = TRUE)
  agg[, `:=`(
    Weighted_per90 = Weighted / Minutes * 90,
    Raw_per90      = Raw / Minutes * 90
  )]
  agg
}

per90_all   <- per90_one(goals, min_by_player, TRUE)
per90_npen  <- per90_one(goals, min_by_player, FALSE)

per90_era <- rbindlist(lapply(levels(goals$Era), function(er) {
  gg <- goals[Era == er]; mm <- valid[Era == er, .(Minutes = sum(Minutes), Apps = .N), by = Player]
  out <- per90_one(gg, mm, TRUE); out[, Era := er]; out
}))
per90_era[, Era := factor(Era, levels = levels(goals$Era), ordered = TRUE)]

per90 <- rbindlist(list(
  cbind(per90_all, Era = factor("All", levels = c("All", levels(goals$Era)), ordered = TRUE), PenaltyIncl = TRUE),
  cbind(per90_npen, Era = factor("All", levels = c("All", levels(goals$Era)), ordered = TRUE), PenaltyIncl = FALSE),
  cbind(per90_era, PenaltyIncl = TRUE)
))
setorder(per90, PenaltyIncl, Era, Player)

## ---------------------------------------------------------------------------
## 4. Trajectory (cumulative + rolling 30-match weighted goals per 90)
## ---------------------------------------------------------------------------
# per-match weighted/raw sums from goals
match_goals <- goals[!is.na(Weighted_Goal), .(Weighted = sum(Weighted_Goal),
                                              Raw = .N), by = .(Player, Date)]
traj_src <- merge(valid[, .(Player, Date, Minutes)], match_goals,
                  by = c("Player", "Date"), all.x = TRUE)
traj_src[is.na(Weighted), `:=`(Weighted = 0, Raw = 0)]
setorder(traj_src, Player, Date)

traj <- traj_src[, {
  cum_w   <- cumsum(Weighted)
  cum_r   <- cumsum(Raw)
  # rolling 30-appearance window (weighted goals per 90 over that window)
  roll_w  <- frollapply(Weighted, 30, sum, align = "right", fill = NA_real_)
  roll_m  <- frollapply(Minutes, 30, sum, align = "right", fill = NA_real_)
  roll_r  <- frollapply(Raw, 30, sum, align = "right", fill = NA_real_)
  .(Date = Date, Minutes = Minutes, Weighted = Weighted, Raw = Raw,
    Cum_Weighted = cum_w, Cum_Raw = cum_r,
    Roll30_Wper90 = roll_w / roll_m * 90,
    Roll30_Rper90 = roll_r / roll_m * 90)
}, by = Player]

## ---------------------------------------------------------------------------
## 5. Bootstrap input (match-level rows)
## ---------------------------------------------------------------------------
boot_input <- valid[, .(Player, Date, Minutes)]
boot_input <- merge(boot_input, match_goals, by = c("Player", "Date"), all.x = TRUE)
boot_input[is.na(Weighted), `:=`(Weighted = 0, Raw = 0)]

## ---------------------------------------------------------------------------
## 6. FAMD summary for the methodology tab
## ---------------------------------------------------------------------------
famd_info <- list(
  eig = as.data.table(famd$eig),                       # eigenvalue, % variance, cum %
  quanti_contrib = as.data.table(famd$quanti.var$contrib),  # per variable
  quali_contrib  = lapply(famd$quali.var$contrib, as.data.table),
  n_individuals  = nrow(famd$ind$coord)
)

## ---------------------------------------------------------------------------
## 7. Meta + validation cross-check
## ---------------------------------------------------------------------------
meta <- list(
  built_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  r_version = R.version.string,
  # Reproducibility record. FactoMineR's version determines the Dim-1 loadings
  # and therefore every weighted score downstream, so stamp what actually
  # produced this bundle. (This replaces the renv lockfile, removed 2026-08-09:
  # recording what was used cannot drift out of date the way a pin can.)
  pkg_versions = vapply(c("FactoMineR", "data.table", "dplyr"),
                        function(p) as.character(packageVersion(p)),
                        character(1)),
  totals = list(
    goals_messi = nrow(goals[Player == "Messi"]),
    goals_ronaldo = nrow(goals[Player == "Ronaldo"]),
    matches_total = nrow(matches),
    matches_valid = nrow(valid),
    scoreless = nrow(valid[Gls == 0]),
    pens_messi = nrow(goals[Player == "Messi" & Penalty == TRUE]),
    pens_ronaldo = nrow(goals[Player == "Ronaldo" & Penalty == TRUE])
  ),
  coverage_goals = as.data.frame(coverage),
  xg_covered = sum(!is.na(goals$xg)),
  na_difficulty = sum(is.na(goals$Difficulty_Score))
)

known <- list(messi = 847, ronaldo = 891, pens_messi = 106, pens_ronaldo = 169)
stopifnot(meta$totals$goals_messi == known$messi,
          meta$totals$goals_ronaldo == known$ronaldo)

## ---------------------------------------------------------------------------
## 8. Assemble + save
## ---------------------------------------------------------------------------
bundle <- list(
  goals = goals,
  matches = matches,
  valid_matches = valid,
  per90 = per90,
  trajectory = traj,
  boot_input = boot_input,
  famd_info = famd_info,
  meta = meta,
  version = "0.1.0"
)

saveRDS(bundle, OUT, version = 3)
file.copy(OUT, APP_OUT, overwrite = TRUE)
file.copy(G_PATH, APP_RAW, overwrite = TRUE, copy.mode = TRUE)

## ---------------------------------------------------------------------------
## 9. Report
## ---------------------------------------------------------------------------
cat("\nanalysis_bundle.rds written:\n")
cat("  built with:", meta$r_version, "|",
    paste(names(meta$pkg_versions), meta$pkg_versions, collapse = ", "), "\n")
cat("  goals:", nrow(bundle$goals), " (Messi", meta$totals$goals_messi,
    "/ Ronaldo", meta$totals$goals_ronaldo, ")\n")
cat("  matches:", meta$totals$matches_total, "valid:", meta$totals$matches_valid,
    "scoreless:", meta$totals$scoreless, "\n")
cat("  penalties: Messi", meta$totals$pens_messi, "/ Ronaldo", meta$totals$pens_ronaldo, "\n")
cat("  Elo coverage (goals):\n")
print(as.data.frame(coverage), row.names = FALSE)
cat("  xG covered:", meta$xg_covered, "of", nrow(goals), "goals\n")
cat("  NA Difficulty_Score:", meta$na_difficulty, "goals\n")
cat("  per90 (weighted | raw):\n")
print(per90_all[, .(Player, Weighted_per90, Raw_per90)], row.names = FALSE, digits = 4)
cat("\nDone.\n")
