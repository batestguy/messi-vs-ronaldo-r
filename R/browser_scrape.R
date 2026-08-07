# R/browser_scrape.R
# ---------------------------------------------------------------------------
# Headful-Chrome access to FBref for the Messi vs Ronaldo pipeline.
#
# WHY THIS EXISTS
#   FBref sits behind a Cloudflare "managed challenge". Plain httr/rvest
#   requests (including worldfootballR's internal .load_page()) get an
#   endless "Performing security verification" interstitial. A REAL, headful
#   Chrome browser eventually auto-solves the challenge (~85 s on first-ever
#   visit) and stores a `cf_clearance` cookie in its profile. Reusing that
#   profile makes subsequent loads fast.
#
# WHAT THIS FILE DOES
#   - Launches (or attaches to) a persistent headful Chrome with a stable
#     user-data-dir profile, exposed on a fixed remote-debugging port.
#   - Provides browser_get_html(): navigate, wait for the challenge to clear,
#     return the rendered outerHTML.
#   - Patches worldfootballR's internal .load_page() so every fb_* function
#     fetches through Chrome instead of httr. Fetched pages are cached to
#     data/raw/html_cache/ (spec 3.4) so re-runs never touch the network.
#
# USAGE (must source after politeness.R):
#   source("R/politeness.R"); source("R/browser_scrape.R")
#   library(worldfootballR)
#   patch_fbref_load_page()
#   # ... use fb_player_goal_logs() etc. normally ...
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(chromote)
  library(processx)
})

# --- Configuration ----------------------------------------------------------

BROWSER_HOST   <- "127.0.0.1"
BROWSER_PORT   <- 9333L
BROWSER_CHROME <- file.path("C:/Program Files/Google/Chrome/Application/chrome.exe")
BROWSER_PROFILE <- file.path(Sys.getenv("LOCALAPPDATA", tempdir()),
                             "MessivsRonaldo-chrome-profile")
BROWSER_WAIT_MAX <- 170          # seconds to allow Cloudflare to solve first time

.browser_env <- new.env()
.browser_env$session <- NULL

# --- Chrome lifecycle -------------------------------------------------------

browser_up <- function() {
  ok <- tryCatch({
    con <- url(paste0("http://", BROWSER_HOST, ":", BROWSER_PORT, "/json/version"), "rb")
    on.exit(close(con))
    !is.null(jsonlite::fromJSON(con)$webSocketDebuggerUrl)
  }, error = function(e) FALSE)
  isTRUE(ok)
}

launch_browser <- function() {
  if (browser_up()) return(invisible(TRUE))
  if (!file.exists(BROWSER_CHROME))
    stop("Chrome not found at: ", BROWSER_CHROME,
         " - set BROWSER_CHROME in R/browser_scrape.R")
  dir.create(BROWSER_PROFILE, showWarnings = FALSE, recursive = TRUE)
  args <- c(
    paste0("--remote-debugging-port=", BROWSER_PORT),
    paste0("--user-data-dir=", BROWSER_PROFILE),
    "--no-first-run",
    "--disable-gpu",
    "--disable-blink-features=AutomationControlled",
    paste0("--remote-allow-origins=http://", BROWSER_HOST, ":", BROWSER_PORT)
  )
  proc <- process$new(BROWSER_CHROME, args, supervise = FALSE)
  for (i in seq_len(40)) {            # wait up to ~20 s for the port
    if (browser_up()) break
    Sys.sleep(0.5)
  }
  if (!browser_up()) stop("Chrome launched but debugging port never opened")
  message("Headful Chrome started (port ", BROWSER_PORT, ", profile ",
          BROWSER_PROFILE, ")")
  invisible(TRUE)
}

ensure_session <- function() {
  launch_browser()
  if (is.null(.browser_env$session) || !.browser_env$session$is_active()) {
    remote <- ChromeRemote$new(BROWSER_HOST, BROWSER_PORT)
    chr    <- Chromote$new(browser = remote)
    .browser_env$session <- chr$new_session()
  }
  .browser_env$session
}

# --- Page fetch via Chrome --------------------------------------------------

page_text <- function(s, n = 160) {
  tryCatch(
    s$Runtime$evaluate(
      sprintf('document.body ? document.body.innerText.slice(0, %d) : ""', n),
      returnByValue = TRUE)$result$value,
    error = function(e) "")
}

page_html <- function(s) {
  tryCatch(
    s$Runtime$evaluate('document.documentElement.outerHTML',
                       returnByValue = TRUE)$result$value,
    error = function(e) NULL)
}

is_challenge <- function(txt) {
  grepl("Performing security verification|Verifying you are human|Just a moment",
        txt)
}

browser_get_html <- function(url, wait_max = BROWSER_WAIT_MAX) {
  s <- ensure_session()
  s$Page$navigate(url)
  t0 <- Sys.time()
  repeat {
    Sys.sleep(3)
    txt <- page_text(s)
    if (!is_challenge(txt) && nzchar(txt)) break
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > wait_max) {
      warning("Cloudflare challenge not cleared within ", wait_max,
              "s for ", url)
      break
    }
  }
  html <- page_html(s)
  if (is.null(html) || nchar(html) < 500) {
    stop("Empty or challenge page for ", url)
  }
  html
}

# --- worldfootballR .load_page patch ----------------------------------------

load_page_patch <- function(page_url) {
  dest <- cache_path(page_url, source = "fbref")
  if (file.exists(dest)) {
    log_attempt("fbref", page_url, 304L, NA_integer_, "cache hit")
    return(xml2::read_html(dest))
  }
  html <- browser_get_html(page_url)
  writeBin(charToRaw(html), dest)
  log_attempt("fbref", page_url, 200L, NA_integer_, "browser fetch")
  xml2::read_html(html)
}

patch_fbref_load_page <- function() {
  if (!requireNamespace("worldfootballR", quietly = TRUE))
    stop("worldfootballR must be installed to patch .load_page")
  assignInNamespace(".load_page", load_page_patch, ns = "worldfootballR")
  message("worldfootballR .load_page() patched to use headful Chrome + cache")
  invisible(TRUE)
}