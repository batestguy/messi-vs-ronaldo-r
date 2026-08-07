# scripts/02_scrape_fbref.R
# ---------------------------------------------------------------------------
# Phase 1, script 02 --- FBref scraping (goal logs + match logs + season stats)
#
# FBref sits behind a Cloudflare managed challenge, so all fetches go through
# headful Chrome (R/browser_scrape.R patches worldfootballR's .load_page()).
# Every fetched page is cached to data/raw/html_cache/; re-runs never touch
# the network. Scrape log appended to data/raw/scrape_log.csv.
#
# Outputs (data/raw/):
#   fbref_goal_logs.rds       -- one row per goal, BOTH players (938 + 1024)
#   fbref_match_logs.rds      -- per-match logs, all seasons, both players
#   fbref_season_stats.rds    -- season-level aggregates (standard + shooting)
#
# Run: Rscript scripts/02_scrape_fbref.R
# ---------------------------------------------------------------------------

source(here::here("R", "politeness.R"))
source(here::here("R", "browser_scrape.R"))

suppressPackageStartupMessages({
  library(worldfootballR)
  library(dplyr)
  library(readr)
  library(xml2)
})

patch_fbref_load_page()

# --- Configuration ----------------------------------------------------------

PLAYERS <- tibble::tribble(
  ~player_name, ~fbref_url,                                    ~first_season_end,
  "Lionel Messi", "https://fbref.com/en/players/d70ce98e/Lionel-Messi",   2005L,
  "C. Ronaldo",   "https://fbref.com/en/players/dea698d9/Cristiano-Ronaldo", 2003L
)
CURRENT_SEASON_END <- 2026L   # FBref's current season-end year (2025-26)

# --- Helpers ----------------------------------------------------------------

# The match-log page has a two-row header; row 2 carries the real column names.
parse_match_log_table <- function(html) {
  tables <- rvest::html_nodes(html, "table")
  if (length(tables) == 0) return(tibble::tibble())
  t <- rvest::html_table(tables[[1]], header = FALSE)
  if (nrow(t) < 2) return(tibble::tibble())
  names(t) <- as.character(unlist(t[2, ]))
  t <- t[-c(1, 2), ]
  t <- t[!is.na(t[[1]]) & t[[1]] != "", ]
  t
}

fetch_goal_log <- function(player_name, fbref_url) {
  goal_log_url <- sub("/[^/]+$", "", fbref_url) %>%
    paste0("/goallogs/all_comps/", basename(fbref_url), "-Goal-Log")
  # fallback URL construction if above is malformed:
  if (!grepl("goallogs", goal_log_url)) {
    goal_log_url <- paste0(
      "https://fbref.com/en/players/",
      sub(".*players/([^/]+)/.*", "\\1", fbref_url),
      "/goallogs/all_comps/",
      sub(".*players/[^/]+/", "", fbref_url), "-Goal-Log"
    )
  }
  html <- worldfootballR:::.load_page(goal_log_url)
  tables <- rvest::html_nodes(html, "table")
  t <- rvest::html_table(tables[[1]], header = TRUE)
  # FBref repeats the column header every ~56 rows and leaves Rk blank on some
  # real rows, so filter on the Date column instead of Rk:
  t <- t %>%
    dplyr::filter(!is.na(.data[["Date"]]),
                  .data[["Date"]] != "",
                  .data[["Date"]] != "Date") %>%
    dplyr::mutate(Player = player_name, .before = 1)
}

fetch_season_match_logs <- function(player_name, fbref_url, seasons) {
  player_id <- sub(".*players/([^/]+)/.*", "\\1", fbref_url)
  player_slug <- sub(".*players/[^/]+/", "", fbref_url)
  out <- list()
  for (season in seasons) {
    url <- paste0(
      "https://fbref.com/en/players/", player_id,
      "/matchlogs/", season - 1, "-", season,
      "/summary/", player_slug, "-Match-Logs"
    )
    html <- tryCatch(worldfootballR:::.load_page(url),
                     error = function(e) NULL)
    if (is.null(html)) { message("  no match log for ", season - 1, "-", season); next }
    t <- parse_match_log_table(html)
    if (nrow(t) == 0) next
    t$Season_End <- season
    out[[length(out) + 1]] <- t
    Sys.sleep(1)
  }
  if (length(out) == 0) return(tibble::tibble())
  dplyr::bind_rows(out) %>% dplyr::mutate(Player = player_name, .before = 1)
}

fetch_season_stats <- function(fbref_url, stat_type) {
  suppressWarnings(worldfootballR::fb_player_season_stats(
    player_url = fbref_url, stat_type = stat_type))
}

# --- Goal logs (primary goal-level source) ----------------------------------

cat("== Goal logs ==\n")
goal_logs <- list()
for (i in seq_len(nrow(PLAYERS))) {
  p <- PLAYERS[i, ]
  cat("Fetching goal log for ", p$player_name, "...\n", sep = "")
  gl <- tryCatch(fetch_goal_log(p$player_name, p$fbref_url),
                 error = function(e) { message("goal log error: ", conditionMessage(e)); NULL })
  if (!is.null(gl)) {
    cat("  rows: ", nrow(gl), "\n", sep = "")
    goal_logs[[p$player_name]] <- gl
  }
}
goal_logs_all <- dplyr::bind_rows(goal_logs)

# --- Match logs (per-season) ------------------------------------------------

cat("\n== Match logs ==\n")
match_logs <- list()
for (i in seq_len(nrow(PLAYERS))) {
  p <- PLAYERS[i, ]
  seasons <- seq(p$first_season_end, CURRENT_SEASON_END)
  cat("Fetching match logs for ", p$player_name, " (", length(seasons),
      " seasons)...\n", sep = "")
  ml <- fetch_season_match_logs(p$player_name, p$fbref_url, seasons)
  cat("  rows: ", nrow(ml), "\n", sep = "")
  match_logs[[p$player_name]] <- ml
}
match_logs_all <- dplyr::bind_rows(match_logs)

# --- Season stats (standard + shooting for xG) ------------------------------

cat("\n== Season stats ==\n")
season_stats <- list()
for (i in seq_len(nrow(PLAYERS))) {
  p <- PLAYERS[i, ]
  for (st in c("standard", "shooting")) {
    cat("Fetching ", st, " season stats for ", p$player_name, "...\n", sep = "")
    ss <- tryCatch(fetch_season_stats(p$fbref_url, st),
                   error = function(e) { message("  error: ", conditionMessage(e)); NULL })
    if (!is.null(ss)) {
      ss$Player <- p$player_name
      ss$StatType <- st
      season_stats[[paste(p$player_name, st)]] <- ss
    }
  }
}
season_stats_all <- dplyr::bind_rows(season_stats)

# --- Save -------------------------------------------------------------------

saveRDS(goal_logs_all,     file.path(DATA_RAW_DIR, "fbref_goal_logs.rds"))
saveRDS(match_logs_all,    file.path(DATA_RAW_DIR, "fbref_match_logs.rds"))
saveRDS(season_stats_all,  file.path(DATA_RAW_DIR, "fbref_season_stats.rds"))

cat("\nSaved:\n")
cat("  data/raw/fbref_goal_logs.rds     ", nrow(goal_logs_all), " goals\n")
cat("  data/raw/fbref_match_logs.rds    ", nrow(match_logs_all), " matches\n")
cat("  data/raw/fbref_season_stats.rds  ", nrow(season_stats_all), " rows\n")
cat("\n02_scrape_fbref.R complete.\n")