# scripts/04_collect_elo_ratings.R
# ---------------------------------------------------------------------------
# Phase 1, script 04 --- Opponent Elo ratings
#
# ORDER OF WORK:
#   1. National Elo (eloratings.net) FIRST --- independent of ClubElo, files
#      usually already on disk, and international matches always need it.
#   2. Club Elo (api.clubelo.com) SECOND --- behind a preflight probe. If the
#      API is unreachable, the club phase is SKIPPED (cached data kept) rather
#      than burning retries on an outage. Re-run when the API recovers.
#
# Sources:
#   - International matches: eloratings.net per-team TSV exports
#     (www.eloratings.net/{Argentina,Portugal}.tsv). Each row is one national
#     match and carries BOTH teams' Elo, so the two files cover every opponent
#     Messi/Ronaldo faced internationally. Team codes resolved via
#     en.teams.tsv.
#   - Club matches: ClubElo API (api.clubelo.com/<Slug>) --- daily ratings per
#     club. Slug = club display name with accents transliterated and all
#     non-alphanumerics removed, plus a curated override map for known
#     renames (e.g. "Real Betis" -> "Betis", "PSG" -> "ParisSG"). The API is
#     flaky/rate-limited: every fetch is retried with backoff.
#
# A match is international iff the player's Squad is their national team
# (Argentina for Messi, Portugal for Ronaldo) --- reliable discriminator.
#
# Fallback chain for missing Elo (spec 2. DataAnalysis 1.2):
#   Club Elo -> league-average Elo -> global 1500. The league-average step is
#   implemented in 07_integrate_data.R once match context is joined.
#
# Outputs:
#   data/external/eloratings/{team}.tsv       -- raw eloratings.net team exports (cached)
#   data/external/eloratings/en.teams.tsv     -- team code -> name map
#   data/processed/national_elo_lookup.csv    -- date, team_code, team_name, elo
#   data/external/club_elo/{slug}.csv         -- raw ClubElo histories (cached)
#   data/processed/club_elo_lookup.csv        -- long form: club, date_from, date_to, elo
#
# Run: Rscript --no-init-file --no-restore --no-save scripts/04_collect_elo_ratings.R
# ---------------------------------------------------------------------------

source(here::here("R", "politeness.R"))
source(here::here("R", "clubelo_slugs.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

CLUB_ELO_DIR <- file.path(DATA_EXTERNAL_DIR, "club_elo")
ELORATINGS_DIR <- file.path(DATA_EXTERNAL_DIR, "eloratings")
dir.create(CLUB_ELO_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(ELORATINGS_DIR, showWarnings = FALSE, recursive = TRUE)

ELORATINGS_BASE <- "https://www.eloratings.net"
NATIONAL_SQUADS <- c("Argentina", "Portugal")
CLUBELO_PROBE  <- "http://api.clubelo.com/RealMadrid"
ELO_MAX_RETRIES <- 3
ELO_BACKOFF_SECS <- c(3, 8, 15)

# --- ClubElo fetch (cached, retried) -----------------------------------------

fetch_club_elo <- function(slug) {
  dest <- file.path(CLUB_ELO_DIR, paste0(slug, ".csv"))
  if (file.exists(dest)) {
    df <- tryCatch(readr::read_csv(dest, show_col_types = FALSE),
                   error = function(e) NULL)
    if (!is.null(df) && nrow(df) > 0) return(list(slug = slug, df = df, cached = TRUE))
    # Empty/corrupt cache: drop and re-fetch.
    file.remove(dest)
  }
  url <- paste0("http://api.clubelo.com/", slug)
  for (attempt in seq_len(ELO_MAX_RETRIES)) {
    res <- polite_get(url, source = "clubelo", delay = 3)
    if (!res$ok) {                    # network error / non-2xx -> retry
      if (attempt < ELO_MAX_RETRIES) Sys.sleep(ELO_BACKOFF_SECS[attempt])
      next
    }
    txt <- httr::content(res$response, as = "text", encoding = "UTF-8")
    lines <- strsplit(txt, "\n")[[1]]
    lines <- lines[grepl(",", lines)]
    if (length(lines) > 2) {          # >1 data row => real club history
      writeLines(txt, dest)
      df <- tryCatch(readr::read_csv(dest, show_col_types = FALSE),
                     error = function(e) NULL)
      return(list(slug = slug, df = df, cached = FALSE))
    }
    # Header-only => club not rated by ClubElo; no point retrying.
    break
  }
  list(slug = slug, df = NULL, cached = FALSE)
}

# --- Classify matches: club vs international --------------------------------

match_logs <- readRDS(file.path(DATA_RAW_DIR, "fbref_match_logs.rds"))

# Drop header-repeat junk rows (Gls == "Gls") and DNP rows (no minutes).
valid <- match_logs[!is.na(suppressWarnings(as.numeric(match_logs$Min))), ]
valid <- valid[valid$Opponent != "Opponent", ]

clean_name <- function(x) sub("^[a-z]{2,3} ", "", x)   # strip en/eng/it/de/...
valid$Squad_clean <- clean_name(valid$Squad)
valid$Opp_clean  <- clean_name(valid$Opponent)

is_intl <- valid$Squad_clean %in% NATIONAL_SQUADS
cat("matches:", nrow(valid),
    "| club:", sum(!is_intl), "| international:", sum(is_intl), "\n")

club_opps <- sort(unique(valid$Opp_clean[!is_intl]))
natl_opps <- sort(unique(valid$Opp_clean[is_intl]))

# --- National Elo (eloratings.net per-team TSV) ------------------------------
# Runs FIRST: independent of ClubElo, and the raw files are usually already
# downloaded (elo-rating lookups are needed for international matches regardless).

cat("\n== National Elo (eloratings.net) ==\n")

download_eloratings_file <- function(name, dest) {
  if (file.exists(dest) && file.size(dest) > 0) { cat("  already present:", name, "\n"); return(TRUE) }
  url <- file.path(ELORATINGS_BASE, name)
  res <- polite_get(url, source = "eloratings", delay = 3)
  if (res$ok) {
    writeBin(httr::content(res$response, as = "raw"), dest)
    cat("  downloaded:", name, "\n")
    return(TRUE)
  }
  cat("  download FAILED:", name, "\n")
  FALSE
}

teams_tsv  <- file.path(ELORATINGS_DIR, "en.teams.tsv")
natl_done  <- download_eloratings_file("en.teams.tsv", teams_tsv)

# Team code -> English name lookup (eloratings uses 2-letter codes: AR, PT)
read_teams_tsv <- function() {
  utils::read.delim(teams_tsv, sep = "\t", header = FALSE, stringsAsFactors = FALSE,
                    fill = TRUE, quote = "")
}
code_to_name <- function() {
  if (!file.exists(teams_tsv)) return(character())
  tsv <- read_teams_tsv()
  nm <- tsv[[2]]; names(nm) <- tsv[[1]]
  nm
}
name_to_code <- function() {
  if (!file.exists(teams_tsv)) return(character())
  tsv <- read_teams_tsv()
  cd <- tsv[[1]]; names(cd) <- tsv[[2]]
  cd
}

# eloratings TSV files are keyed by team CODE (e.g. Argentina.tsv contains rows
# where either team is "AR"), not by full name. Resolve each squad's code, then
# filter on it.
parse_national_elo <- function(team, team_code) {
  dest <- file.path(ELORATINGS_DIR, paste0(team, ".tsv"))
  if (!download_eloratings_file(paste0(team, ".tsv"), dest)) return(NULL)
  d <- utils::read.delim(dest, sep = "\t", header = FALSE, stringsAsFactors = FALSE,
                         colClasses = "character", fill = TRUE, quote = "")
  names(d)[1:12] <- c("Year", "Month", "Day", "Team1", "Team2",
                      "G1", "G2", "Tournament", "Venue", "Change",
                      "Elo1", "Elo2")
  d$date <- as.Date(paste(d$Year, d$Month, d$Day, sep = "-"))
  d$Elo1 <- suppressWarnings(as.numeric(d$Elo1))
  d$Elo2 <- suppressWarnings(as.numeric(d$Elo2))
  # Rows involving `team_code`: the opponent is the other side; keep its Elo.
  sel1 <- d$Team1 == team_code
  sel2 <- d$Team2 == team_code
  out <- data.frame(
    date = d$date[sel1 | sel2],
    team_code = ifelse(d$Team1[sel1 | sel2] == team_code, d$Team2[sel1 | sel2], d$Team1[sel1 | sel2]),
    elo = ifelse(d$Team1[sel1 | sel2] == team_code, d$Elo2[sel1 | sel2], d$Elo1[sel1 | sel2]),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$elo), ]
  out
}

code_name <- code_to_name()
code_lookup <- name_to_code()

national_lookup <- list()
for (team in NATIONAL_SQUADS) {
  tc <- unname(code_lookup[team])
  if (is.null(tc) || is.na(tc)) {
    cat("  WARNING: no eloratings code for", team, "\n")
    next
  }
  df <- parse_national_elo(team, tc)
  if (!is.null(df)) {
    national_lookup[[team]] <- df
    cat("  ", team, " (code ", tc, "): ", nrow(df), " international matches parsed\n", sep = "")
  }
}

nat_flat <- do.call(rbind, lapply(names(national_lookup), function(team) {
  df <- national_lookup[[team]]
  df$national_team <- team
  df$team_name <- unname(code_name[df$team_code]) %||% df$team_code
  df
}))
if (!is.null(nat_flat) && nrow(nat_flat) > 0) {
  readr::write_csv(nat_flat, file.path(DATA_PROCESSED_DIR, "national_elo_lookup.csv"))
  cat("\nnational_elo_lookup.csv:", nrow(nat_flat), "rows\n")
}

cat("\nNational opponents needed:", paste(natl_opps, collapse = ", "), "\n")

# --- Fetch club Elo ---------------------------------------------------------

# Preflight: if the ClubElo API is unreachable, skip the club phase entirely
# (keeps existing cached CSVs/lookup intact) instead of burning retries on an
# outage. Re-run this script when the API is back; cached clubs make it fast.
clubelo_available <- function() {
  probe <- tryCatch(polite_get(CLUBELO_PROBE, source = "clubelo", delay = 3),
                    error = function(e) NULL)
  !is.null(probe) && probe$ok
}

cat("\n== Fetching ClubElo histories (", length(club_opps), " clubs) ==\n", sep = "")
if (!clubelo_available()) {
  cat("\nClubElo API UNREACHABLE -- skipping club phase (cached data kept).\n")
  cat("Re-run 04 when api.clubelo.com is back; cached clubs load instantly.\n")
} else {
  club_results <- list()
  failed <- character()
  for (opp in club_opps) {
    slug <- fbref_to_clubelo_slug(opp)
    if (slug %in% names(club_results)) next
    res <- fetch_club_elo(slug)
    club_results[[slug]] <- res
    if (is.null(res$df) || nrow(res$df) == 0) {
      failed <- c(failed, paste0(opp, " [", slug, "]"))
      cat("  MISS ", slug, " (", opp, ")\n", sep = "")
    } else {
      cat("  OK   ", slug, " (", opp, "): ", nrow(res$df), " rows", if (res$cached) " [cached]" else "", "\n", sep = "")
    }
  }

  club_lookup <- do.call(rbind, lapply(names(club_results), function(slug) {
    res <- club_results[[slug]]
    if (is.null(res$df) || nrow(res$df) == 0) return(NULL)
    res$df %>%
      dplyr::select(Club, Elo, From, To) %>%
      dplyr::mutate(
        club_slug = slug,
        Elo = suppressWarnings(as.numeric(Elo)),
        From = as.Date(From),
        To = as.Date(To)
      )
  }))
  if (!is.null(club_lookup) && nrow(club_lookup) > 0) {
    readr::write_csv(club_lookup, file.path(DATA_PROCESSED_DIR, "club_elo_lookup.csv"))
    cat("\nclub_elo_lookup.csv:", nrow(club_lookup), "rows,", length(unique(club_lookup$club_slug)), "clubs\n")
  }
  if (length(failed)) {
    cat("\nCLUBS WITHOUT CLUBELO RATING (need league-avg/1500 fallback):\n")
    cat(paste("  ", failed), sep = "\n")
  }
}

cat("\n04_collect_elo_ratings.R complete.\n")
