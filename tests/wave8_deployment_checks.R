# Wave 8 deployment-bundle and unchanged-analysis checks.
# Run from the repository root with:
#   Rscript tests/wave8_deployment_checks.R

stopifnot(
  file.exists("scripts/09_deploy_shinyapps.R"),
  file.exists("app/app.R"),
  requireNamespace("rsconnect", quietly = TRUE)
)
invisible(parse(file = "scripts/09_deploy_shinyapps.R"))

deploy_source <- readLines(
  "scripts/09_deploy_shinyapps.R",
  warn = FALSE,
  encoding = "UTF-8"
)
deploy_text <- paste(deploy_source, collapse = "\n")

stopifnot(
  grepl('APP_NAME <- "messi-vs-ronaldo-r"', deploy_text, fixed = TRUE),
  grepl('SERVER <- "shinyapps.io"', deploy_text, fixed = TRUE),
  grepl("rsconnect::deployApp(", deploy_text, fixed = TRUE),
  grepl("rsconnect::appDependencies(", deploy_text, fixed = TRUE),
  grepl('Sys.getenv("SHINYAPPS_ACCOUNT"', deploy_text, fixed = TRUE),
  grepl("launch.browser = FALSE", deploy_text, fixed = TRUE),
  grepl("forceUpdate = is_linked_update", deploy_text, fixed = TRUE),
  !grepl("setAccountInfo\\s*\\([^.]", deploy_text, perl = TRUE),
  !grepl("token\\s*<-", deploy_text, ignore.case = TRUE),
  !grepl("secret\\s*<-", deploy_text, ignore.case = TRUE)
)

app_dir <- normalizePath("app", mustWork = TRUE)
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
normalized_files <- gsub("\\\\", "/", app_files)

stopifnot(
  length(app_files) == 24L,
  all(file.exists(file.path(app_dir, app_files))),
  !"run.R" %in% app_files,
  !"Rprofile.container" %in% app_files,
  !any(grepl("(^|/)rsconnect/", normalized_files)),
  !any(grepl("[.]pem$|(^|/)[.]env$|(^|/)secrets/", normalized_files)),
  sum(file.info(file.path(app_dir, app_files))$size) < 2 * 1024^2
)

dependencies <- rsconnect::appDependencies(
  appDir = app_dir,
  appFiles = app_files
)
package_column <- intersect(c("Package", "package"), names(dependencies))
stopifnot(length(package_column) == 1L)
dependency_names <- as.character(dependencies[[package_column]])

required_runtime <- c(
  "shiny", "bslib", "data.table", "htmltools", "plotly", "DT"
)
forbidden_runtime <- c(
  "FactoMineR", "worldfootballR", "chromote", "rvest", "RSelenium"
)
stopifnot(
  all(required_runtime %in% dependency_names),
  !any(forbidden_runtime %in% dependency_names)
)

ignore_text <- readLines(".gitignore", warn = FALSE)
package_inventory <- paste(readLines("R/_packages.R", warn = FALSE), collapse = "\n")
stopifnot(
  any(trimws(ignore_text) == "app/rsconnect/"),
  grepl("library(rsconnect)", package_inventory, fixed = TRUE)
)

raw_source <- "data/processed/goals_master_final.csv"
raw_app <- "app/data/goals_master_final.csv"
stopifnot(
  unname(tools::md5sum(raw_source)) == "c43c3f995b1f301b4328c846eab2cf27",
  identical(unname(tools::md5sum(raw_source)), unname(tools::md5sum(raw_app)))
)

bundle <- readRDS("app/data/analysis_bundle.rds")
stopifnot(
  identical(nrow(bundle$goals), 1738L),
  identical(nrow(bundle$valid_matches), 2201L),
  sum(bundle$valid_matches$Minutes) == 181081,
  sum(bundle$valid_matches$Gls == 0L) == 1063L,
  sum(is.na(bundle$goals$Difficulty_Score)) == 3L,
  identical(
    names(bundle),
    c(
      "goals", "matches", "valid_matches", "per90", "trajectory",
      "boot_input", "famd_info", "meta", "version"
    )
  ),
  identical(bundle$version, "0.1.0")
)

signed_power_probe <- sign(c(-2, -0.5, 0, 0.5, 2)) *
  abs(c(-2, -0.5, 0, 0.5, 2))^0.5
stopifnot(all(is.finite(signed_power_probe)))

cat(sprintf(
  paste0(
    "Wave 8 deployment checks passed: %d allowlisted files, %s bytes; ",
    "six runtime packages discovered; source/data contracts unchanged.\n"
  ),
  length(app_files),
  format(sum(file.info(file.path(app_dir, app_files))$size),
         big.mark = ",", scientific = FALSE)
))
