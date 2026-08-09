# R/politeness.R
# ---------------------------------------------------------------------------
# Scrape politeness utilities for the Messi vs Ronaldo data-collection pipeline.
# source() this once from every script that hits the web. Do not duplicate these
# concerns elsewhere.
#
# Responsibilities:
#   - Single User-Agent string (descriptive, polite).
#   - 3-second floor between requests (bumpable per call).
#   - robots.txt check before first request to a new host (in-memory cached).
#   - HTML cache under data/raw/html_cache/ so re-runs don't re-scrape (spec 3.4).
#   - Scrape logger -> data/raw/scrape_log.csv  (every attempt, success or fail).
#
# Depends on: httr, curl, digest, readr, here  (all in the user library)
# Does NOT depend on worldfootballR / kickR.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(httr)
  library(curl)
  library(digest)
  library(readr)
  library(here)
})

# --- Paths (single source of truth) -----------------------------------------

DATA_RAW_DIR       <- here::here("data", "raw")
DATA_PROCESSED_DIR <- here::here("data", "processed")
DATA_EXTERNAL_DIR  <- here::here("data", "external")
HTML_CACHE_DIR     <- file.path(DATA_RAW_DIR, "html_cache")
SCRAPE_LOG_PATH    <- file.path(DATA_RAW_DIR, "scrape_log.csv")

ensure_dirs <- function() {
  for (d in c(DATA_RAW_DIR, DATA_PROCESSED_DIR, DATA_EXTERNAL_DIR, HTML_CACHE_DIR))
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
}
ensure_dirs()

# --- Configuration ----------------------------------------------------------

USER_AGENT      <- "MessiVsRonaldo/0.1 (research; github.com/owner/messi-vs-ronaldo)"
MIN_DELAY_SECS  <- 3                           # floor; bump per call if needed

.last_request_time <- NULL       # per-session (not shared across R processes)

# null-coalesce operator (defined early; used by robots check)
`%||%` <- function(a, b) if (is.null(a)) b else a

# --- Scrape logger ----------------------------------------------------------

log_attempt <- function(source, url, http_status, rows = NA_integer_, note = "") {
  row <- data.frame(
    timestamp    = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    source       = source,
    url          = url,
    http_status  = as.integer(http_status),
    rows         = as.integer(rows),
    note         = note,
    stringsAsFactors = FALSE
  )
  ok <- file.exists(SCRAPE_LOG_PATH)
  write.table(row, file = SCRAPE_LOG_PATH, append = ok,
              sep = ",", row.names = FALSE, col.names = !ok,
              quote = TRUE, na = "")
  invisible(row)
}

# --- robots.txt check (minimal, no extra package) ---------------------------

.robots_cache <- new.env()   # host -> list(user_agent -> list(disallow, allow))

robots_allowed <- function(url) {
  parsed <- httr::parse_url(url)
  host   <- parsed$hostname
  scheme <- parsed$scheme %||% "https"
  if (is.null(host)) return(TRUE)                       # non-HTTP: skip check

  if (is.null(.robots_cache[[host]])) {
    robots_url <- paste0(scheme, "://", host, "/robots.txt")
    rb <- tryCatch(
      httr::content(httr::GET(robots_url, httr::user_agent(USER_AGENT), httr::timeout(15)),
                    as = "text", encoding = "UTF-8"),
      error = function(e) ""
    )
    .robots_cache[[host]] <- parse_robots(rb)
  }
  rules <- .robots_cache[[host]]
  if (is.null(rules) || length(rules) == 0) return(TRUE)

  ua_match <- rules[[USER_AGENT]] %||% rules[["*"]]
  if (is.null(ua_match)) return(TRUE)
  path <- parsed$path
  if (!is.null(parsed$query)) path <- paste0(path, "?", parsed$query)
  for (pattern in ua_match$disallow) {
    if (pattern == "") next
    if (grepl(glob2rx(pattern), path)) return(FALSE)
  }
  TRUE
}

parse_robots <- function(text) {
  if (!nzchar(text)) return(NULL)
  rules <- list(); cur_ua <- NULL; cur_dis <- character(); cur_all <- character()
  flush_ua <- function() {
    if (!is.null(cur_ua)) rules[[cur_ua]] <<- list(disallow = cur_dis, allow = cur_all)
  }
  for (ln in strsplit(text, "\n")[[1L]]) {
    ln <- trimws(ln)
    if (ln == "" || startsWith(ln, "#")) next
    parts <- strsplit(ln, ":", fixed = TRUE)[[1L]]
    key <- tolower(trimws(parts[1L]))
    val <- if (length(parts) > 1L) trimws(paste(parts[-1L], collapse = ":")) else ""
    if (key == "user-agent") { flush_ua(); cur_ua <- val; cur_dis <- character(); cur_all <- character() }
    else if (key == "disallow") cur_dis <- c(cur_dis, val)
    else if (key == "allow")    cur_all <- c(cur_all, val)
  }
  flush_ua()
  rules
}

# --- Rate-limited GET -------------------------------------------------------

polite_get <- function(url, source = "unknown", delay = MIN_DELAY_SECS,
                       obey_robots = TRUE) {
  if (obey_robots && !robots_allowed(url)) {
    log_attempt(source, url, 403L, NA_integer_, "blocked by robots.txt")
    message("robots.txt disallows: ", url)
    return(list(ok = FALSE, status = 403L, response = NULL))
  }
  if (!is.null(.last_request_time)) {
    elapsed <- as.numeric(difftime(Sys.time(), .last_request_time, units = "secs"))
    if (elapsed < delay) Sys.sleep(delay - elapsed)
  }
  res <- tryCatch(
    httr::GET(url, httr::user_agent(USER_AGENT), httr::timeout(60)),
    error = function(e) e
  )
  .last_request_time <<- Sys.time()
  if (inherits(res, "error")) {
    log_attempt(source, url, 999L, NA_integer_, conditionMessage(res))
    return(list(ok = FALSE, status = 999L, response = NULL))
  }
  status <- httr::status_code(res)
  log_attempt(source, url, status, NA_integer_, "ok")
  list(ok = !httr::http_error(res), status = status, response = res)
}

# --- HTML cache (spec 3.4) --------------------------------------------------

cache_path <- function(url, source = "unknown") {
  h <- digest(url, algo = "sha1", serialize = FALSE)
  file.path(HTML_CACHE_DIR, paste0(source, "_", substr(h, 1L, 12L), ".html"))
}

fetch_html <- function(url, source = "unknown", force_refresh = FALSE) {
  dest <- cache_path(url, source)
  if (!force_refresh && file.exists(dest)) {
    log_attempt(source, url, 304L, NA_integer_, "cache hit")
    return(list(ok = TRUE, cached = TRUE,
                html = readr::read_file(dest), path = dest))
  }
  res <- polite_get(url, source = source)
  if (!res$ok) return(res)
  writeBin(httr::content(res$response, as = "raw"), dest)
  list(ok = TRUE, cached = FALSE,
       html = httr::content(res$response, "text", encoding = "UTF-8"), path = dest)
}