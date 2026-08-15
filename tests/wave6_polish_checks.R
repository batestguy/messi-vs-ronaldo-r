# Wave 6 deterministic verification for shell polish, accessibility, and cache coverage.
# Run from the repository root with:
#   Rscript tests/wave6_polish_checks.R

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(data.table)
  library(htmltools)
})

P_ORDER <- c("Messi", "Ronaldo")
P_COLOR <- c(Messi = "#14447D", Ronaldo = "#A61E2C")
source("app/R/theme.R")
source("app/R/mod_weighting.R")
source("app/R/mod_inference.R")

for (path in c(
  "app/app.R",
  "app/R/mod_weighting.R",
  "app/R/mod_head2head.R",
  "app/R/mod_inference.R"
)) {
  parse(file = path)
}

app_source <- paste(readLines("app/app.R", warn = FALSE), collapse = "\n")
css_source <- paste(readLines("app/www/css.css", warn = FALSE), collapse = "\n")
js_source <- paste(readLines("app/www/app.js", warn = FALSE), collapse = "\n")
package_source <- paste(readLines("R/_packages.R", warn = FALSE), collapse = "\n")

stopifnot(
  grepl("css.css?v=20260815-review1", app_source, fixed = TRUE),
  grepl("app.js?v=20260812-wave6", app_source, fixed = TRUE),
  grepl('open = "desktop"', app_source, fixed = TRUE),
  grepl("shiny::busyIndicatorOptions(", app_source, fixed = TRUE),
  grepl('spinner_selector = ".shiny-bound-output"', app_source, fixed = TRUE),
  grepl('fade_selector = ".shiny-bound-output"', app_source, fixed = TRUE),
  grepl('id = "app-live-status"', app_source, fixed = TRUE),
  grepl('aria-live', app_source, fixed = TRUE),
  grepl('name = "theme-color"', app_source, fixed = TRUE),
  !grepl("waiter", app_source, ignore.case = TRUE),
  !grepl("waiter", package_source, ignore.case = TRUE)
)

stopifnot(
  grepl("#dashboard-main", js_source, fixed = TRUE),
  grepl("Skip to dashboard content", js_source, fixed = TRUE),
  grepl("shiny:busy.wave6", js_source, fixed = TRUE),
  grepl("shiny:idle.wave6", js_source, fixed = TRUE),
  grepl("Updating dashboard", js_source, fixed = TRUE),
  grepl("Dashboard updated.", js_source, fixed = TRUE),
  grepl(".skip-link", css_source, fixed = TRUE),
  grepl(":focus-visible", css_source, fixed = TRUE),
  grepl("@media (prefers-reduced-motion: reduce)", css_source, fixed = TRUE),
  grepl("safe-area-inset-bottom", css_source, fixed = TRUE),
  grepl("overscroll-behavior", css_source, fixed = TRUE),
  grepl("font-variant-numeric: tabular-nums", css_source, fixed = TRUE)
)

stopifnot(
  grepl(".navbar .navbar-brand", css_source, fixed = TRUE),
  grepl(".navbar .nav-link.active", css_source, fixed = TRUE),
  grepl("color: #43576a", css_source, fixed = TRUE),
  grepl("color: #1c7c7d", css_source, fixed = TRUE),
  grepl(".navbar .navbar-toggler-icon", css_source, fixed = TRUE)
)

plot_files <- c(
  "app/R/mod_weighting.R",
  "app/R/mod_head2head.R",
  "app/R/mod_inference.R"
)
plot_source <- paste(
  vapply(
    plot_files,
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  ),
  collapse = "\n"
)
count_fixed <- function(needle, haystack) {
  hits <- gregexpr(needle, haystack, fixed = TRUE)[[1L]]
  if (hits[1L] < 0L) 0L else length(hits)
}
stopifnot(
  count_fixed("plotly::renderPlotly({", plot_source) == 8L,
  count_fixed("shiny::bindCache(plotly::renderPlotly({", plot_source) == 8L
)

bundle <- readRDS("app/data/analysis_bundle.rds")
goals <- bundle$goals
matches <- bundle$valid_matches
stopifnot(
  identical(names(bundle), c(
    "goals", "matches", "valid_matches", "per90", "trajectory",
    "boot_input", "famd_info", "meta", "version"
  )),
  identical(bundle$version, "0.1.0"),
  nrow(goals) == 1738L,
  nrow(matches) == 2201L,
  sum(matches$Minutes) == 181081,
  sum(matches$Gls == 0) == 1063L,
  sum(is.na(goals$Difficulty_Score)) == 3L
)

snapshot <- inference_snapshot(1, FALSE, "All competitions", "All venues")
appearance_scope <- inference_prepare_appearances(goals, matches, snapshot)
baseline <- inference_summarize(appearance_scope, run_bootstrap = FALSE)
stopifnot(
  abs(baseline$players[Player == "Messi", Rate] - 0.1336718582) < 5e-10,
  abs(baseline$players[Player == "Ronaldo", Rate] - 0.0384164403) < 5e-10,
  abs(baseline$observed_gap - 0.0952554179) < 5e-10
)

stamp <- as.character(bundle$meta$built_at)[1L]
analysis <- list(snapshot = snapshot)
same_key <- inference_density_cache_key(stamp, analysis)
stopifnot(
  identical(same_key, inference_density_cache_key(stamp, analysis)),
  !identical(
    same_key,
    inference_density_cache_key(
      stamp,
      list(snapshot = inference_snapshot(1.5, FALSE, "All competitions", "All venues"))
    )
  ),
  !identical(
    same_key,
    inference_density_cache_key(
      stamp,
      list(snapshot = inference_snapshot(1, FALSE, "Champions Lg", "Away"))
    )
  ),
  !identical(same_key, inference_density_cache_key("different-bundle", analysis)),
  grepl("not-run", inference_density_cache_key(stamp, NULL), fixed = TRUE)
)

stopifnot(
  identical(names(formals(mod_inference_ui)), "id"),
  identical(names(formals(mod_inference_server)), c("id", "state"))
)

runtime_packages <- c("shiny", "bslib", "data.table", "htmltools", "plotly", "DT")
stopifnot(all(vapply(
  runtime_packages,
  function(package) grepl(
    paste0("library(", package, ")"),
    package_source,
    fixed = TRUE
  ),
  logical(1)
)))

cat(
  paste0(
    "Wave 6 polish checks passed: 8/8 Plotly outputs cached; ",
    "shell/accessibility tokens present; baseline gap ",
    sprintf("%.4f", baseline$observed_gap), ".\n"
  )
)
