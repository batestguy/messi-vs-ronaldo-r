# Wave 5 deterministic verification for Methodology, Summary, and Raw Data.
# Run from the repository root with:
#   Rscript tests/wave5_content_checks.R

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(data.table)
  library(htmltools)
})

P_ORDER <- c("Messi", "Ronaldo")
source("app/R/theme.R")
source("app/R/mod_weighting.R")
source("app/R/mod_methodology.R")
source("app/R/mod_summary.R")
source("app/R/mod_data.R")

for (path in c(
  "app/app.R",
  "app/R/mod_methodology.R",
  "app/R/mod_summary.R",
  "app/R/mod_data.R",
  "scripts/08_prepare_analysis.R"
)) {
  parse(file = path)
}

bundle <- readRDS("app/data/analysis_bundle.rds")
goals <- bundle$goals
matches <- bundle$valid_matches
raw_source <- fread("data/processed/goals_master_final.csv", showProgress = FALSE)
raw_app <- fread("app/data/goals_master_final.csv", showProgress = FALSE)

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
  sum(is.na(goals$Difficulty_Score)) == 3L,
  sum(goals$Player == "Messi") == 847L,
  sum(goals$Player == "Ronaldo") == 891L,
  nrow(raw_source) == 1738L,
  ncol(raw_source) == 29L,
  identical(names(raw_source), names(raw_app)),
  identical(raw_source, raw_app),
  identical(unname(tools::md5sum("data/processed/goals_master_final.csv")),
            unname(tools::md5sum("app/data/goals_master_final.csv"))),
  !anyDuplicated(raw_app$goal_id),
  sum(raw_app$Player == "Lionel Messi") == 847L,
  sum(raw_app$Player == "C. Ronaldo") == 891L
)

contributions <- methodology_famd_contributions(bundle$famd_info)
expected_contributions <- c(
  Opponent_Elo = 0.8012735,
  Venue = 48.6372035,
  Competition_Stage = 2.2663320,
  Is_Away = 48.2951910
)
stopifnot(
  identical(contributions$Variable, names(expected_contributions)),
  max(abs(contributions$Contribution - expected_contributions)) < 1e-7,
  abs(sum(contributions$Contribution) - 100) < 1e-7,
  abs(bundle$famd_info$eig[1L, 2L, with = FALSE][[1L]] - 25.29678) < 1e-4,
  bundle$famd_info$n_individuals == 2201L
)

baseline <- summary_comparison_table(summary_prepare_scope(
  goals,
  matches,
  summary_snapshot()
))
overall <- baseline[Section == "Overall"]
stopifnot(
  nrow(baseline) == 14L,
  identical(baseline$Section, c(
    "Overall",
    rep("Career era", 5L),
    rep("Competition family", 5L),
    rep("Venue", 3L)
  )),
  overall$Apps_Messi == 1031L,
  overall$Apps_Ronaldo == 1170L,
  overall$Minutes_Messi == 85131,
  overall$Minutes_Ronaldo == 95950,
  overall$Raw_Messi == 847L,
  overall$Raw_Ronaldo == 891L,
  abs(overall$Weighted_per90_Messi - 0.1336718582) < 5e-10,
  abs(overall$Weighted_per90_Ronaldo - 0.0384164403) < 5e-10,
  abs(overall$Weighted_Gap - 0.0952554179) < 5e-10,
  abs(overall$Raw_per90_Messi - 0.8954435) < 5e-7,
  abs(overall$Raw_per90_Ronaldo - 0.8357478) < 5e-7,
  overall$Missing_Difficulty_Messi == 2L,
  overall$Missing_Difficulty_Ronaldo == 1L
)

for (section in c("Career era", "Competition family", "Venue")) {
  rows <- baseline[Section == section]
  stopifnot(
    sum(rows$Apps_Messi) == overall$Apps_Messi,
    sum(rows$Apps_Ronaldo) == overall$Apps_Ronaldo,
    sum(rows$Minutes_Messi) == overall$Minutes_Messi,
    sum(rows$Minutes_Ronaldo) == overall$Minutes_Ronaldo,
    sum(rows$Raw_Messi) == overall$Raw_Messi,
    sum(rows$Raw_Ronaldo) == overall$Raw_Ronaldo,
    sum(rows$Missing_Difficulty_Messi) == overall$Missing_Difficulty_Messi,
    sum(rows$Missing_Difficulty_Ronaldo) == overall$Missing_Difficulty_Ronaldo
  )
}

for (k in c(0.5, 1, 1.5, 3)) {
  for (excluded in c(FALSE, TRUE)) {
    rows <- summary_comparison_table(summary_prepare_scope(
      goals,
      matches,
      summary_snapshot(k, excluded)
    ))
    numeric_values <- unlist(rows[, .(
      Weighted_per90_Messi, Weighted_per90_Ronaldo, Weighted_Gap,
      Raw_per90_Messi, Raw_per90_Ronaldo, Raw_Gap
    )])
    stopifnot(all(is.finite(numeric_values)))
    selected_overall <- rows[Section == "Overall"]
    stopifnot(
      selected_overall$Apps_Messi == 1031L,
      selected_overall$Apps_Ronaldo == 1170L,
      selected_overall$Minutes_Messi + selected_overall$Minutes_Ronaldo == 181081
    )
    if (excluded) {
      stopifnot(
        selected_overall$Raw_Messi == 741L,
        selected_overall$Raw_Ronaldo == 722L
      )
    }
  }
}

scope_probe <- function(competition, venue = "All venues") {
  summary_comparison_table(
    summary_prepare_scope(goals, matches, summary_snapshot(1, FALSE, competition, venue)),
    include_empty = FALSE
  )[Section == "Overall"]
}

champions_away <- scope_probe("Champions Lg", "Away")
world_cup_neutral <- scope_probe("World Cup", "Neutral")
mls <- scope_probe("MLS")
fa_cup <- scope_probe("FA Cup")
empty <- scope_probe("MLS", "Neutral")
stopifnot(
  champions_away$Apps_Messi == 81L,
  champions_away$Apps_Ronaldo == 92L,
  champions_away$Raw_Messi == 49L,
  champions_away$Raw_Ronaldo == 63L,
  world_cup_neutral$Apps_Messi == 29L,
  world_cup_neutral$Apps_Ronaldo == 25L,
  world_cup_neutral$Raw_Messi == 21L,
  world_cup_neutral$Raw_Ronaldo == 11L,
  mls$Apps_Messi == 76L,
  mls$Apps_Ronaldo == 0L,
  is.na(mls$Weighted_Gap),
  fa_cup$Apps_Messi == 0L,
  fa_cup$Apps_Ronaldo == 1L,
  fa_cup$Raw_Ronaldo == 0L,
  fa_cup$Raw_per90_Ronaldo == 0,
  identical(summary_fmt_rate(fa_cup$Raw_per90_Ronaldo), "0.0000"),
  identical(summary_fmt_rate(mls$Weighted_per90_Ronaldo), "N/A"),
  empty$Apps_Messi == 0L,
  empty$Apps_Ronaldo == 0L,
  is.na(empty$Raw_Gap)
)

exact_family_rows <- summary_comparison_table(
  summary_prepare_scope(
    goals,
    matches,
    summary_snapshot(1, FALSE, "Champions Lg", "Away")
  ),
  include_empty = FALSE
)[Section == "Competition family"]
stopifnot(
  nrow(exact_family_rows) == 1L,
  exact_family_rows$Summary_Scope == "Continental"
)

method_html <- as.character(mod_methodology_ui("method_test"))
summary_html <- as.character(mod_summary_ui("summary_test"))
data_html <- as.character(mod_data_ui("data_test"))
stopifnot(
  grepl("<math", method_html, fixed = TRUE),
  grepl("aria-label", method_html, fixed = TRUE),
  grepl("Methodology steps", method_html, fixed = TRUE),
  grepl("Definitive comparison table", summary_html, fixed = TRUE),
  grepl("Download exact CSV", data_html, fixed = TRUE),
  grepl("role=\"region\"", data_html, fixed = TRUE),
  grepl("css.css?v=20260812-wave6", paste(readLines("app/app.R"), collapse = "\n"), fixed = TRUE)
)

state <- reactiveValues(
  bundle = bundle,
  raw_goals = fread(
    "app/data/goals_master_final.csv",
    colClasses = "character",
    na.strings = NULL,
    showProgress = FALSE
  ),
  raw_goals_path = normalizePath("app/data/goals_master_final.csv"),
  K = 1,
  exclude_pen = FALSE,
  competition = "All competitions",
  venue = "All venues",
  boot_trigger = 0L
)

testServer(mod_summary_server, args = list(state = state), {
  session$flushReact()
  stopifnot(any(grepl("0.1337", as.character(output$baseline_table), fixed = TRUE)))
  state$K <- 3
  state$exclude_pen <- TRUE
  state$competition <- "Champions Lg"
  state$venue <- "Away"
  session$flushReact()
  stopifnot(
    state$boot_trigger == 0L,
    any(grepl("K 3.0", as.character(output$live_context), fixed = TRUE)),
    any(grepl("Continental", as.character(output$live_table), fixed = TRUE)),
    any(grepl("0.1337", as.character(output$baseline_table), fixed = TRUE))
  )
})

testServer(mod_methodology_server, args = list(state = state), {
  session$flushReact()
  stopifnot(
    any(grepl("1,738", as.character(output$audit_strip), fixed = TRUE)),
    any(grepl("25.3%", as.character(output$famd_summary), fixed = TRUE)),
    any(grepl("48.6%", as.character(output$famd_summary), fixed = TRUE))
  )
})

testServer(mod_data_server, args = list(state = state), {
  session$flushReact()
  stopifnot(
    any(grepl("1,738", as.character(output$data_audit), fixed = TRUE)),
    state$boot_trigger == 0L
  )
})

stopifnot(
  identical(names(formals(mod_methodology_ui)), "id"),
  identical(names(formals(mod_methodology_server)), c("id", "state")),
  identical(names(formals(mod_summary_ui)), "id"),
  identical(names(formals(mod_summary_server)), c("id", "state")),
  identical(names(formals(mod_data_ui)), "id"),
  identical(names(formals(mod_data_server)), c("id", "state"))
)

cat("Wave 5 content checks passed.\n")
cat("Baseline weighted / 90: Messi", sprintf("%.10f", overall$Weighted_per90_Messi),
    "Ronaldo", sprintf("%.10f", overall$Weighted_per90_Ronaldo), "\n")
cat("Baseline raw / 90: Messi", sprintf("%.10f", overall$Raw_per90_Messi),
    "Ronaldo", sprintf("%.10f", overall$Raw_per90_Ronaldo), "\n")
cat("CSV MD5:", unname(tools::md5sum("app/data/goals_master_final.csv")), "\n")
