# scripts/05_scrape_transfermarkt.R
# ---------------------------------------------------------------------------
# Phase 1, script 05 --- Transfermarkt player data (OPTIONAL in spec Step 5)
#
# Purpose: market value history + transfer history for Messi and Ronaldo.
#
# Sources (via worldfootballR, plain rvest/static HTML --- no Cloudflare):
#   - tm_player_bio():          current + max market value, clubs, DOB, etc.
#   - tm_player_transfer_history(get_extra_info=FALSE):
#                               every transfer with fees (transfer_value) and
#                               market value at the time (market_value).
#
# NOTE on "market value history": a full per-date valuation curve lives on
# Transfermarkt's marktwertverlauf page, which was unreachable/throttled during
# tests. The transfer table's `market_value` column (value at each transfer) +
# bio's `player_valuation` / `max_player_valuation` cover the spec's intent
# without the extra scrape. Documented gap, not a blocker.
#
# Politeness: every request goes through R/politeness.R polite_get machinery
# where possible; worldfootballR tm_* functions do their own requests but we
# rate-limit between them with the standard delay.
#
# Outputs:
#   data/raw/transfermarkt_bio.rds       -- bio rows (Messi, Ronaldo)
#   data/raw/transfermarkt_transfers.rds -- transfer history rows
#   data/processed/transfermarkt_summary.csv -- merged, tidy (for 07/dashboard)
#
# Run: Rscript --no-init-file --no-restore --no-save scripts/05_scrape_transfermarkt.R
#      (uses the FAST user library; renv.lock is the manifest of record for Docker)
# ---------------------------------------------------------------------------

source(here::here("R", "politeness.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(worldfootballR)
})

PLAYER_URLS <- c(
  "https://www.transfermarkt.com/lionel-messi/profil/spieler/28003",
  "https://www.transfermarkt.com/cristiano-ronaldo/profil/spieler/8198"
)

BIO_RDS     <- file.path(DATA_RAW_DIR, "transfermarkt_bio.rds")
TRANSF_RDS  <- file.path(DATA_RAW_DIR, "transfermarkt_transfers.rds")
SUMMARY_CSV <- file.path(DATA_PROCESSED_DIR, "transfermarkt_summary.csv")

# tm_player_bio() makes a SECOND request to a "rueckennummern" (squad number)
# sub-page; when Transfermarkt throttles it, xml2::read_html returns NA and the
# downstream parse crashes. Transfermarkt also returns 504 to plain httr GETs but
# serves xml2::read_html fine --- so we fetch each player's profile directly with
# xml2::read_html + politeness delay + retries, and parse only the fields we need.
# This is more robust than the package function for two static pages.
with_retry <- function(expr, attempts = 6, backoff = c(10, 20, 40, 60, 90, 120)) {
  for (i in seq_len(attempts)) {
    res <- tryCatch(expr, error = function(e) e)
    if (!inherits(res, "error")) return(res)
    if (i == attempts) stop(res)
    cat("  retry", i, "after error:", conditionMessage(res), "\n")
    Sys.sleep(backoff[i])
  }
}

scrape_bio_direct <- function(player_url) {
  with_retry({
    pg <- xml2::read_html(player_url)
    Sys.sleep(MIN_DELAY_SECS)
    name <- pg %>% rvest::html_node("h1") %>% rvest::html_text() %>% stringr::str_squish()
    val <- pg %>% rvest::html_nodes(".data-header__market-value-wrapper") %>%
      rvest::html_text() %>% stringr::str_squish()
    val <- gsub(" Last.*", "", val)
    val_max <- pg %>% rvest::html_nodes(".max") %>% rvest::html_text() %>% stringr::str_squish()
    val_max <- val_max[grepl("[0-9]", val_max)][1]
    val_max_date <- pg %>% rvest::html_nodes(".tm-player-market-value-development__max div") %>%
      rvest::html_text() %>% stringr::str_squish()
    val_max_date <- val_max_date[length(val_max_date)]
    X1 <- pg %>% rvest::html_nodes(".info-table__content--regular") %>%
      rvest::html_text() %>% stringr::str_squish()
    X2 <- pg %>% rvest::html_nodes(".info-table__content--bold") %>%
      rvest::html_text() %>% stringr::str_squish()
    info <- setNames(as.list(X2), gsub(":", "", X1))
    pick <- function(k) {
      v <- info[[k]]
      if (is.null(v)) NA_character_ else v
    }
    bio <- tibble::tibble(
      player_name = gsub("#[0-9]+ ", "", name),
      player_id   = as.numeric(stringr::str_extract(player_url, "(?<=spieler/)[0-9]+")),
      current_club = pick("Club"),
      date_of_birth = pick("Date of birth/Age"),
      height = pick("Height"),
      citizenship = pick("Citizenship"),
      position = pick("Position"),
      foot = pick("Foot"),
      player_valuation = suppressWarnings(as.numeric(gsub("[^0-9.]", "", val))) * 1e6,
      max_player_valuation = suppressWarnings(as.numeric(gsub("[^0-9.]", "", val_max))) * 1e6,
      max_player_valuation_date = val_max_date,
      URL = player_url,
      stringsAsFactors = FALSE
    )
    if (nrow(bio) == 0) stop("empty bio page (throttled?)")
    bio
  })
}

cat("== Transfermarkt: player bios ==\n")
if (file.exists(BIO_RDS)) {
  bio <- readRDS(BIO_RDS)
  cat("  cached bio:", nrow(bio), "rows\n")
} else {
  bio <- tryCatch(
    do.call(rbind, lapply(PLAYER_URLS, scrape_bio_direct)),
    error = function(e) {
      cat("  WARNING: bio scrape failed:", conditionMessage(e), "\n")
      cat("  Transfermarkt throttling; bio is optional. Saving empty bio.\n")
      NULL
    }
  )
  if (is.null(bio)) bio <- data.frame()
  saveRDS(bio, BIO_RDS)
  cat("  saved bio:", nrow(bio), "rows\n")
}

cat("== Transfermarkt: transfer history ==\n")
if (file.exists(TRANSF_RDS)) {
  th <- readRDS(TRANSF_RDS)
  cat("  cached transfers:", nrow(th), "rows\n")
} else {
  # get_extra_info=TRUE triggers per-transfer sub-scrapes and times out (>5 min);
  # FALSE gives fees + market value per transfer in seconds. Extra info (agency,
  # scout) is out of scope.
  th <- tm_player_transfer_history(PLAYER_URLS, get_extra_info = FALSE)
  Sys.sleep(MIN_DELAY_SECS)
  saveRDS(th, TRANSF_RDS)
  cat("  saved transfers:", nrow(th), "rows\n")
}

cat("\n== Build merged summary ==\n")
if (nrow(bio) > 0 && "player_name" %in% names(bio)) {
  bio_cols <- bio %>% dplyr::select(player_name, player_valuation,
                                    max_player_valuation, max_player_valuation_date,
                                    date_of_birth, height, position, foot, current_club)
  summary_df <- th %>% dplyr::left_join(bio_cols, by = "player_name") %>%
    dplyr::arrange(player_name, transfer_date)
} else {
  cat("  (bio unavailable - summary = transfer history only)\n")
  summary_df <- th %>% dplyr::arrange(player_name, transfer_date)
}

readr::write_csv(summary_df, SUMMARY_CSV)
cat("  transfermarkt_summary.csv:", nrow(summary_df), "rows\n")
cat("\nBio rows:\n")
if (nrow(bio) > 0) {
  print(bio %>% dplyr::select(player_name, player_valuation, max_player_valuation,
                              max_player_valuation_date))
} else {
  cat("  (none - Transfermarkt throttled the bio scrape)\n")
}
cat("\nTransfer counts:\n")
print(th %>% dplyr::count(player_name))

cat("\n05_scrape_transfermarkt.R complete.\n")
