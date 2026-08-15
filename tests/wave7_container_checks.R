# Wave 7 Docker contract checks. Run with:
#   Rscript tests/wave7_container_checks.R

assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

dockerfile <- read_text("Dockerfile")
dockerignore <- readLines(".dockerignore", warn = FALSE)
launcher <- read_text("app/run.R")
inventory <- read_text("R/_packages.R")

base <- paste0(
  "rocker/shiny-verse:4.5.0@sha256:",
  "ccafdf812938dc85891b198f0728c8bf1706f1b0b7558b9fe696e98eb116056a"
)
assert(length(gregexpr(base, dockerfile, fixed = TRUE)[[1L]]) == 2L,
       "Dockerfile must pin both stages to the verified shiny-verse digest.")
assert(grepl(" AS packages", dockerfile, fixed = TRUE), "Missing packages build stage.")
assert(grepl(" AS runtime", dockerfile, fixed = TRUE), "Missing runtime stage.")
assert(grepl("https://packagemanager.posit.co/cran/2026-08-09", dockerfile, fixed = TRUE),
       "Dockerfile must use the dated Posit PPM snapshot.")

runtime_packages <- c("shiny", "bslib", "data.table", "htmltools", "plotly", "DT")
install_line <- grep("install.packages", readLines("Dockerfile", warn = FALSE), value = TRUE)
assert(length(install_line) == 1L, "Expected one explicit R package installation command.")
for (package in runtime_packages) {
  assert(grepl(sprintf('"%s"', package), install_line, fixed = TRUE),
         sprintf("Dockerfile is missing runtime package %s.", package))
  assert(grepl(sprintf("library(%s)", package), inventory, fixed = TRUE),
         sprintf("R/_packages.R is missing runtime package %s.", package))
}
assert(!grepl("renv", dockerfile, ignore.case = TRUE), "Dockerfile must not use renv.")
assert(!grepl("FactoMineR|worldfootballR", dockerfile),
       "Analysis and scraping packages must not enter the runtime image.")

system_libraries <- c(
  "curl", "libssl-dev", "libcurl4-openssl-dev", "libxml2-dev",
  "libfreetype6-dev", "libharfbuzz-dev", "libpng-dev", "libjpeg-dev"
)
for (library in system_libraries) {
  assert(grepl(library, dockerfile, fixed = TRUE),
         sprintf("Dockerfile is missing system library %s.", library))
}

required_tokens <- c(
  "R_LIBS_USER=/opt/messi-library",
  "R_PROFILE_USER=/opt/messi-vs-ronaldo/app/Rprofile.container",
  "COPY --chown=shiny:shiny app/ ./app/",
  "SHINY_SERVER_VERSION=1.5.24.1034",
  "USER shiny",
  "EXPOSE 3838",
  "HEALTHCHECK",
  "http://127.0.0.1:3838/",
  'CMD ["Rscript", "/opt/messi-vs-ronaldo/app/run.R"]'
)
for (token in required_tokens) {
  assert(grepl(token, dockerfile, fixed = TRUE), sprintf("Missing Docker token: %s", token))
}

assert(identical(dockerignore, c("**", "!Dockerfile", "!.dockerignore", "!app/", "!app/**")),
       ".dockerignore must remain an app-only allowlist.")

launcher_tokens <- c(
  'Sys.getenv("SHINY_HOST", unset = "127.0.0.1")',
  'Sys.getenv("SHINY_PORT", unset = "3838")',
  'log_event("info", "app_start")',
  'log_event("error", "app_failure"',
  "host = APP_HOST",
  "port = APP_PORT",
  "quiet = TRUE"
)
for (token in launcher_tokens) {
  assert(grepl(token, launcher, fixed = TRUE), sprintf("Missing launcher token: %s", token))
}

invisible(parse(file = "app/run.R"))
invisible(parse(file = "app/Rprofile.container"))
for (path in list.files("app/R", pattern = "[.]R$", full.names = TRUE)) {
  invisible(parse(file = path))
}

bundle <- readRDS("app/data/analysis_bundle.rds")
assert(nrow(bundle$goals) == 1738L, "Expected 1,738 goal rows in the bundle.")
assert(nrow(bundle$valid_matches) == 2201L, "Expected 2,201 valid appearances.")
assert(sum(bundle$valid_matches$Minutes) == 181081, "Expected 181,081 valid minutes.")
assert(sum(bundle$valid_matches$Gls == 0L) == 1063L, "Expected 1,063 scoreless appearances.")
assert(sum(is.na(bundle$goals$Difficulty_Score)) == 3L, "Expected three missing difficulty scores.")

cat("Wave 7 container checks passed: pinned two-stage image, app-only context, non-root runtime, health check, and unchanged data contracts.\n")
