# scripts/03_scrape_understat.R
# ---------------------------------------------------------------------------
# Phase 1, script 03 --- Understat per-goal xG (pre-scraped data)
#
# Understat covers only the top-5 European leagues (EPL, La liga, Bundesliga,
# Serie A, Ligue 1, RFPL) from the 2014-15 season onward. There is NO
# international or pre-2014 xG here --- that gap is documented in the quality
# report and filled (partially) by FBref season-level shooting xG.
#
# This script loads the pre-scraped league shot data via worldfootballR's
# load_understat_league_shots() (hosted on GitHub --- reachable, no scraping,
# no Cloudflare). It then filters to GOALS scored by Messi/Ronaldo, keeping
# the shot-level xG for each goal.
#
# Output: data/raw/understat_goals.rds
#   One row per Understat goal: player, date, minute, xG, shotType, situation,
#   home_team, away_team, match_id, league, season, player_assisted, lastAction
#
# Run: Rscript scripts/03_scrape_understat.R
# ---------------------------------------------------------------------------

source(here::here("R", "politeness.R"))

suppressPackageStartupMessages({
  library(worldfootballR)
  library(dplyr)
})

LEAGUES <- c("EPL", "La liga", "Bundesliga", "Serie A", "Ligue 1", "RFPL")

# Understat name variants per player, with exclusion patterns for lookalikes.
PLAYER_NAMES <- list(
  "Lionel Messi" = list(
    keep = c("Lionel Messi", "Messi"),
    drop = c("Junior Messias", "Messias")
  ),
  "C. Ronaldo" = list(
    keep = c("Cristiano Ronaldo", "Ronaldo"),
    drop = c("Ronaldo Vieira", "Ronaldo Da Silva", "Cristiano Ronaldo Dos Santos")
  )
)

is_target <- function(player, name, drop) {
  grepl(name, player, fixed = TRUE) &&
    !any(sapply(drop, function(d) grepl(d, player, fixed = TRUE)))
}

cat("== Loading Understat league shots (2014+ top-5) ==\n")
all_goals <- list()
for (lg in LEAGUES) {
  shots <- tryCatch(load_understat_league_shots(league = lg),
                    error = function(e) { message("  ", lg, " failed: ", conditionMessage(e)); NULL })
  if (is.null(shots)) next
  goals <- shots %>% dplyr::filter(.data[["result"]] == "Goal")
  for (player_name in names(PLAYER_NAMES)) {
    keep <- PLAYER_NAMES[[player_name]]$keep
    drop <- PLAYER_NAMES[[player_name]]$drop
    sub <- goals[sapply(goals$player, is_target, name = keep, drop = drop), ]
    if (nrow(sub) > 0) {
      sub$Player <- player_name
      all_goals[[length(all_goals) + 1]] <- sub
      cat("  ", lg, "-> ", player_name, ": ", nrow(sub), " goals\n", sep = "")
    }
  }
}

understat_goals <- dplyr::bind_rows(all_goals)

if (nrow(understat_goals) > 0) {
  # date parsing: Understat dates are "YYYY-MM-DD HH:MM:SS"
  understat_goals$match_date <- as.Date(substr(understat_goals$date, 1, 10))
  understat_goals$xG <- as.numeric(understat_goals$xG)
  understat_goals$minute <- as.numeric(understat_goals$minute)
  saveRDS(understat_goals, file.path(DATA_RAW_DIR, "understat_goals.rds"))
  cat("\nSaved data/raw/understat_goals.rds:", nrow(understat_goals), "goals\n")
} else {
  cat("\nNo Understat goals found --- check player name matching\n")
}

cat("\n03_scrape_understat.R complete.\n")