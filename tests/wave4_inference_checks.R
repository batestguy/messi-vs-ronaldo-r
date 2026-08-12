suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(data.table)
  library(htmltools)
})

P_ORDER <- c("Messi", "Ronaldo")
P_COLOR <- c(Messi = "#14447D", Ronaldo = "#A61E2C")
source("app/R/mod_weighting.R")
source("app/R/mod_inference.R")

bundle <- readRDS("app/data/analysis_bundle.rds")
goals <- bundle$goals
matches <- bundle$valid_matches

stopifnot(
  nrow(goals) == 1738L,
  nrow(matches) == 2201L,
  sum(matches$Minutes) == 181081,
  sum(matches$Gls == 0) == 1063L,
  sum(is.na(goals$Difficulty_Score)) == 3L
)

default <- inference_snapshot(1, FALSE, "All competitions", "All venues")
analysis <- inference_run_analysis(goals, matches, default)
overall <- analysis$overall
independent <- inference_independent_check(analysis$appearances)

stopifnot(
  abs(overall$players[Player == "Messi", Rate] - 0.1336718582) < 5e-10,
  abs(overall$players[Player == "Ronaldo", Rate] - 0.0384164403) < 5e-10,
  abs(overall$observed_gap - 0.0952554179) < 5e-10,
  length(overall$differences) == INFERENCE_REPS,
  all(is.finite(overall$differences)),
  overall$interval[1] <= overall$interval[2],
  overall$probability_above_zero >= 0,
  overall$probability_above_zero <= 1,
  identical(
    unname(attr(overall$differences, "sample_sizes")),
    c(1031L, 1170L)
  ),
  identical(
    overall$differences,
    inference_bootstrap_difference(analysis$appearances)
  ),
  abs(independent$Messi_Rate - overall$players[Player == "Messi", Rate]) < 1e-12,
  abs(independent$Ronaldo_Rate - overall$players[Player == "Ronaldo", Rate]) < 1e-12,
  abs(independent$Gap - overall$observed_gap) < 1e-12,
  abs(independent$Cohens_d - overall$cohens_d) < 1e-12,
  identical(analysis$era$Subgroup, INFERENCE_ERA_LEVELS),
  identical(analysis$family$Subgroup, INFERENCE_FAMILY_LEVELS),
  sum(analysis$era$Messi_Appearances) == 1031L,
  sum(analysis$era$Ronaldo_Appearances) == 1170L,
  sum(analysis$family$Messi_Appearances) == 1031L,
  sum(analysis$family$Ronaldo_Appearances) == 1170L,
  identical(analysis$family$Sparse, c(FALSE, FALSE, TRUE, FALSE, TRUE))
)

for (k in c(0.5, 1, 1.5, 3)) {
  for (exclude_penalty in c(FALSE, TRUE)) {
    scope <- inference_prepare_appearances(
      goals,
      matches,
      inference_snapshot(k, exclude_penalty, "All competitions", "All venues")
    )
    summary <- inference_summarize(scope, run_bootstrap = FALSE)
    stopifnot(
      all(is.finite(scope$Weighted)),
      all(is.finite(scope$Appearance_Rate)),
      all(is.finite(summary$players$Rate)),
      sum(scope$Minutes) == 181081
    )
  }
}

scope_specs <- list(
  champions_away = inference_snapshot(1, FALSE, "Champions Lg", "Away"),
  world_cup_neutral = inference_snapshot(1, FALSE, "World Cup", "Neutral"),
  mls = inference_snapshot(1, FALSE, "MLS", "All venues"),
  fa_cup = inference_snapshot(1, FALSE, "FA Cup", "All venues"),
  empty = inference_snapshot(1, FALSE, "MLS", "Neutral")
)
expected_apps <- list(
  champions_away = c(Messi = 81L, Ronaldo = 92L),
  world_cup_neutral = c(Messi = 29L, Ronaldo = 25L),
  mls = c(Messi = 76L, Ronaldo = 0L),
  fa_cup = c(Messi = 0L, Ronaldo = 1L),
  empty = c(Messi = 0L, Ronaldo = 0L)
)
for (name in names(scope_specs)) {
  scope <- inference_prepare_appearances(goals, matches, scope_specs[[name]])
  counts <- table(factor(scope$Player, levels = P_ORDER))
  stopifnot(identical(as.integer(counts), as.integer(expected_apps[[name]])))
  summary <- inference_summarize(scope)
  if (name %in% c("mls", "fa_cup", "empty")) {
    stopifnot(!summary$can_infer, !length(summary$differences))
  }
}

# Filtered exact-competition family views contain only their inherited family.
ucl <- inference_run_analysis(
  goals, matches,
  inference_snapshot(1, FALSE, "Champions Lg", "Away")
)
stopifnot(identical(ucl$family$Subgroup, "Continental"))

# A module-level reactive test proves controls alone do not rerun inference.
testServer(mod_inference_server, args = list(state = local({
  x <- reactiveValues(
    bundle = bundle,
    K = 1,
    exclude_pen = FALSE,
    competition = "All competitions",
    venue = "All venues",
    boot_trigger = 0
  )
  x
})), {
  session$flushReact()
  stopifnot(is.null(result()))
  state$K <- 1.5
  state$exclude_pen <- TRUE
  state$competition <- "MLS"
  state$venue <- "Neutral"
  session$flushReact()
  stopifnot(is.null(result()), state$boot_trigger == 0)
  state$boot_trigger <- state$boot_trigger + 1
  session$flushReact()
  frozen <- result()
  stopifnot(
    !is.null(frozen),
    frozen$snapshot$K == 1.5,
    frozen$snapshot$exclude_pen,
    identical(frozen$snapshot$competition, "MLS"),
    identical(frozen$snapshot$venue, "Neutral"),
    nrow(frozen$appearances) == 0L,
    state$boot_trigger == 1
  )
  state$K <- 3
  session$flushReact()
  stopifnot(
    identical(result()$snapshot, frozen$snapshot),
    !inference_same_snapshot(result()$snapshot, live_snapshot())
  )
})

cat(sprintf(
  paste0(
    "Wave 4 checks passed. Default gap %.10f; CI [%.10f, %.10f]; ",
    "P(gap>0) %.10f; Cohen's d %.10f.\n"
  ),
  overall$observed_gap,
  overall$interval[1],
  overall$interval[2],
  overall$probability_above_zero,
  overall$cohens_d
))
