# Deploy the verified dashboard to shinyapps.io.
#
# Run from the repository root with:
#   Rscript scripts/09_deploy_shinyapps.R
#
# Authentication is read only from rsconnect's user-level account store.
# Never place a token or secret in this repository or pass one to this script.

APP_NAME <- "messi-vs-ronaldo-r"
APP_TITLE <- "Messi vs Ronaldo — The Weighted Case"
SERVER <- "shinyapps.io"

REQUIRED_RUNTIME <- c(
  "shiny", "bslib", "data.table", "htmltools", "plotly", "DT"
)
FORBIDDEN_RUNTIME <- c(
  "FactoMineR", "worldfootballR", "chromote", "rvest", "RSelenium"
)

script_args <- commandArgs(trailingOnly = FALSE)
script_file_arg <- grep("^--file=", script_args, value = TRUE)
script_path <- if (length(script_file_arg)) {
  normalizePath(sub("^--file=", "", script_file_arg[1L]), mustWork = TRUE)
} else {
  normalizePath("scripts/09_deploy_shinyapps.R", mustWork = TRUE)
}
repo_dir <- dirname(dirname(script_path))
app_dir <- normalizePath(file.path(repo_dir, "app"), mustWork = TRUE)

if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop(
    "rsconnect is not installed. Install it in the user library, then rerun.",
    call. = FALSE
  )
}

tree_files <- function(directory) {
  files <- list.files(
    file.path(app_dir, directory),
    all.files = TRUE,
    full.names = FALSE,
    recursive = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  file.path(directory, files)
}

app_files <- sort(c(
  "app.R",
  tree_files("R"),
  tree_files("www"),
  file.path("data", c("analysis_bundle.rds", "goals_master_final.csv"))
))

missing_files <- app_files[!file.exists(file.path(app_dir, app_files))]
if (length(missing_files)) {
  stop(
    "Deployment bundle is missing: ", paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

forbidden_file_pattern <- paste0(
  "(^|/)([.]env|secrets)(/|$)|kaggle[.]json$|[.]pem$|",
  "(^|/)(run[.]R|Rprofile[.]container)$|(^|/)rsconnect/"
)
normalized_files <- gsub("\\\\", "/", app_files)
if (any(grepl(forbidden_file_pattern, normalized_files, ignore.case = TRUE))) {
  stop("A forbidden file entered the deployment bundle.", call. = FALSE)
}

dependencies <- rsconnect::appDependencies(
  appDir = app_dir,
  appFiles = app_files
)
package_column <- intersect(c("Package", "package"), names(dependencies))
if (length(package_column) != 1L) {
  stop("Could not identify package names in the rsconnect manifest.", call. = FALSE)
}
dependency_names <- as.character(dependencies[[package_column]])

missing_packages <- setdiff(REQUIRED_RUNTIME, dependency_names)
forbidden_packages <- intersect(FORBIDDEN_RUNTIME, dependency_names)
if (length(missing_packages)) {
  stop(
    "rsconnect did not discover required runtime packages: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}
if (length(forbidden_packages)) {
  stop(
    "Development-only packages entered the deployment manifest: ",
    paste(forbidden_packages, collapse = ", "),
    call. = FALSE
  )
}

bundle_bytes <- sum(file.info(file.path(app_dir, app_files))$size)
cat(sprintf(
  "Validated deployment bundle: %d files, %s bytes.\n",
  length(app_files), format(bundle_bytes, big.mark = ",", scientific = FALSE)
))
cat("Required runtime packages:", paste(REQUIRED_RUNTIME, collapse = ", "), "\n")

accounts <- rsconnect::accounts(server = SERVER)
if (!nrow(accounts)) {
  stop(paste(
    "No shinyapps.io account is configured on this computer.",
    "Sign in to shinyapps.io, open Account > Tokens, add a token, and run",
    "the dashboard-provided rsconnect::setAccountInfo(...) command locally.",
    "Do not paste that command, token, or secret into chat or this repository."
  ), call. = FALSE)
}

requested_account <- trimws(Sys.getenv("SHINYAPPS_ACCOUNT", unset = ""))
account_names <- unique(as.character(accounts$name))
if (!nzchar(requested_account)) {
  if (length(account_names) != 1L) {
    stop(
      "Multiple shinyapps.io accounts are configured. Set SHINYAPPS_ACCOUNT ",
      "to the account name, then rerun the same Rscript command.",
      call. = FALSE
    )
  }
  requested_account <- account_names[[1L]]
}
if (!requested_account %in% account_names) {
  stop(
    "SHINYAPPS_ACCOUNT does not match a configured shinyapps.io account.",
    call. = FALSE
  )
}

remote_apps <- rsconnect::applications(
  account = requested_account,
  server = SERVER
)
remote_name_column <- intersect(c("name", "appName"), names(remote_apps))
if (NROW(remote_apps) > 0L && length(remote_name_column) != 1L) {
  stop("Could not identify application names returned by shinyapps.io.", call. = FALSE)
}
remote_names <- if (NROW(remote_apps) > 0L) {
  as.character(remote_apps[[remote_name_column]])
} else {
  character()
}

record_path <- file.path(
  app_dir, "rsconnect", SERVER, requested_account, paste0(APP_NAME, ".dcf")
)
is_linked_update <- file.exists(record_path)
if (APP_NAME %in% remote_names && !is_linked_update) {
  stop(
    "A remote application named '", APP_NAME,
    "' already exists, but this project is not linked to it. Refusing to ",
    "overwrite it. Review the existing app before retrying.",
    call. = FALSE
  )
}

cat(sprintf(
  "%s '%s' on account '%s'.\n",
  if (is_linked_update) "Updating" else "Creating",
  APP_NAME,
  requested_account
))

rsconnect::deployApp(
  appDir = app_dir,
  appFiles = app_files,
  appName = APP_NAME,
  appTitle = APP_TITLE,
  account = requested_account,
  server = SERVER,
  launch.browser = FALSE,
  lint = TRUE,
  logLevel = "verbose",
  forceUpdate = is_linked_update
)

cat(sprintf(
  "Deployment completed. Expected URL: https://%s.shinyapps.io/%s/\n",
  requested_account,
  APP_NAME
))
