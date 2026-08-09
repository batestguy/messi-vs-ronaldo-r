# Launch the Shiny app with app/ as the application directory.
# This is important: Shiny then serves app/www/ as static assets.
#
#   Rscript app/run.R
#
# The guards below turn the three ways this launch usually fails into readable
# errors. Each one has cost a debugging session at least once.

APP_PORT <- 3838L
APP_HOST <- "127.0.0.1"

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
  socketConnection(APP_HOST, APP_PORT, open = "r+", blocking = TRUE, timeout = 1),
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

shiny::runApp(
  appDir = app_dir,
  port = APP_PORT,
  host = APP_HOST,
  launch.browser = FALSE
)
