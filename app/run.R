# Launch the Shiny app with app/ as the application directory.
# This is important: Shiny then serves app/www/ as static assets.
#
#   Rscript app/run.R
#
# The guards below turn the three ways this launch usually fails into readable
# errors. Each one has cost a debugging session at least once.

port_text <- trimws(Sys.getenv("SHINY_PORT", unset = "3838"))
if (!grepl("^[0-9]+$", port_text)) {
  stop("SHINY_PORT must be an integer from 1 to 65535.", call. = FALSE)
}

APP_PORT <- suppressWarnings(as.integer(port_text))
if (is.na(APP_PORT) || APP_PORT < 1L || APP_PORT > 65535L) {
  stop("SHINY_PORT must be an integer from 1 to 65535.", call. = FALSE)
}

APP_HOST <- trimws(Sys.getenv("SHINY_HOST", unset = "127.0.0.1"))
if (!APP_HOST %in% c("127.0.0.1", "0.0.0.0", "::")) {
  stop(
    "SHINY_HOST must be one of 127.0.0.1, 0.0.0.0, or ::.",
    call. = FALSE
  )
}

json_escape <- function(value) {
  value <- gsub("\\\\", "\\\\\\\\", as.character(value), fixed = TRUE)
  value <- gsub('"', '\\"', value, fixed = TRUE)
  value <- gsub("\r", "\\\\r", value, fixed = TRUE)
  gsub("\n", "\\\\n", value, fixed = TRUE)
}

log_event <- function(level, event, message = NULL) {
  fields <- c(
    sprintf('"timestamp":"%s"', format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
    sprintf('"level":"%s"', json_escape(level)),
    sprintf('"event":"%s"', json_escape(event)),
    sprintf('"host":"%s"', json_escape(APP_HOST)),
    sprintf('"port":%d', APP_PORT)
  )
  if (!is.null(message)) {
    fields <- c(fields, sprintf('"message":"%s"', json_escape(message)))
  }
  cat("{", paste(fields, collapse = ","), "}\n", sep = "")
  flush.console()
}

# --- Guard 1: the Shiny stack is installed -----------------------------------
# library(shiny) on its own dies with a bare "there is no package called 'shiny'",
# which gives no hint about which library was searched. system.file() returns ""
# when a package isn't on the path and is far cheaper than installed.packages().
if (!nzchar(system.file(package = "shiny"))) {
  stop("shiny is not installed on this library path:\n  ",
       paste(.libPaths(), collapse = "\n  "),
       "\n  Install the app stack with: ",
       'install.packages(c("shiny", "bslib", "data.table", "plotly", "DT"))',
       call. = FALSE)
}

# --- Guard 2: application directory ------------------------------------------
# Resolve from this script's own location so the launcher works from any CWD.
# (Do not use commandArgs()[1] -- that is the R binary, not the script.)
args     <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
app_dir  <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  normalizePath("app", mustWork = TRUE)   # sourced interactively, from repo root
}

# --- Guard 3: port availability ----------------------------------------------
# A previous instance left running holds the port, and httpuv reports that as
# "Failed to create server", which reads like an app crash. Connecting
# successfully means something is already listening.
con <- suppressWarnings(try(
  socketConnection("127.0.0.1", APP_PORT, open = "r+", blocking = TRUE, timeout = 1),
  silent = TRUE))
if (!inherits(con, "try-error")) {
  close(con)
  stop(sprintf(paste0(
    "port %d is already in use -- an earlier instance is probably still ",
    "running.\n  Find it:  Get-NetTCPConnection -LocalPort %d | ",
    "Select-Object OwningProcess\n  Stop it:  Stop-Process -Id <pid>"),
    APP_PORT, APP_PORT), call. = FALSE)
}

suppressPackageStartupMessages(library(shiny))

log_event("info", "app_start")
exit_status <- tryCatch({
  shiny::runApp(
    appDir = app_dir,
    port = APP_PORT,
    host = APP_HOST,
    launch.browser = FALSE,
    quiet = TRUE
  )
  0L
}, error = function(error) {
  log_event("error", "app_failure", conditionMessage(error))
  1L
})

if (exit_status != 0L) {
  quit(save = "no", status = exit_status, runLast = FALSE)
}
