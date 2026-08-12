# app/R/mod_inference.R
# Wave 4: button-frozen, match-level bootstrap inference and subgroup views.

INFERENCE_MATCH_KEYS <- c("Player", "Date", "Comp", "Round", "Opp_clean")
INFERENCE_REPS <- 10000L
INFERENCE_SEED <- 20260812L
INFERENCE_ERA_LEVELS <- c(
  "Rise (2002-08)", "Peak (2009-14)", "Prime (2015-18)",
  "Transition (2019-22)", "Late (2023-26)"
)
INFERENCE_FAMILY_LEVELS <- c(
  "League", "Continental", "Domestic cup", "International", "Other"
)

inference_snapshot <- function(k, exclude_pen, competition, venue) {
  list(
    K = round(as.numeric(k), 1),
    exclude_pen = isTRUE(exclude_pen),
    competition = as.character(competition),
    venue = as.character(venue)
  )
}

inference_snapshot_key <- function(snapshot) {
  paste(
    sprintf("%.1f", snapshot$K),
    if (snapshot$exclude_pen) "no-penalties" else "all-goals",
    snapshot$competition,
    snapshot$venue,
    sep = "|"
  )
}

inference_density_cache_key <- function(bundle_stamp, analysis) {
  stamp <- as.character(bundle_stamp)[1L]
  if (is.na(stamp) || !nzchar(stamp)) stamp <- "bundle"
  snapshot_key <- if (is.null(analysis)) {
    "not-run"
  } else {
    inference_snapshot_key(analysis$snapshot)
  }
  paste(stamp, snapshot_key, sep = "|")
}

inference_same_snapshot <- function(left, right) {
  !is.null(left) && !is.null(right) &&
    isTRUE(all.equal(left$K, right$K, tolerance = 1e-12)) &&
    identical(left$exclude_pen, right$exclude_pen) &&
    identical(left$competition, right$competition) &&
    identical(left$venue, right$venue)
}

inference_scope_label <- function(snapshot) {
  paste(
    sprintf("K = %.1f", snapshot$K),
    if (snapshot$exclude_pen) "penalties excluded" else "penalties included",
    snapshot$competition,
    snapshot$venue,
    sep = " · "
  )
}

inference_prepare_appearances <- function(goals, matches, snapshot) {
  scoped_matches <- data.table::copy(matches)
  scoped_goals <- data.table::copy(goals)

  if (!identical(snapshot$competition, "All competitions")) {
    scoped_matches <- scoped_matches[Comp == snapshot$competition]
    scoped_goals <- scoped_goals[Comp == snapshot$competition]
  }
  if (!identical(snapshot$venue, "All venues")) {
    scoped_matches <- scoped_matches[Venue == snapshot$venue]
    scoped_goals <- scoped_goals[Venue == snapshot$venue]
  }
  if (snapshot$exclude_pen) scoped_goals <- scoped_goals[Penalty == FALSE]

  family_map <- unique(goals[, .(Comp, Comp_Group)])
  stopifnot(family_map[, .N, by = Comp][N > 1L, .N] == 0L)
  scoped_matches <- merge(
    scoped_matches, family_map, by = "Comp", all.x = TRUE, sort = FALSE
  )
  scoped_matches[is.na(Comp_Group), Comp_Group := "Other"]

  contributions <- scoped_goals[!is.na(Difficulty_Score), .(
    Weighted = sum(signed_difficulty_power(Difficulty_Score, snapshot$K)),
    Eligible_Goals = .N
  ), by = INFERENCE_MATCH_KEYS]

  appearances <- merge(
    scoped_matches, contributions,
    by = INFERENCE_MATCH_KEYS, all.x = TRUE, sort = FALSE
  )
  appearances[is.na(Weighted), `:=`(Weighted = 0, Eligible_Goals = 0L)]
  appearances[, Appearance_Rate := 90 * Weighted / Minutes]
  appearances[, Era := factor(as.character(Era), levels = INFERENCE_ERA_LEVELS)]
  appearances[, Comp_Group := factor(Comp_Group, levels = INFERENCE_FAMILY_LEVELS)]
  data.table::setorder(appearances, Player, Date, Comp, Round, Opp_clean)
  attr(appearances, "eligible_goals") <- nrow(scoped_goals)
  attr(appearances, "missing_difficulty") <- sum(is.na(scoped_goals$Difficulty_Score))
  appearances
}

inference_player_summary <- function(appearances) {
  base <- data.table::data.table(Player = P_ORDER)
  observed <- appearances[, .(
    Appearances = .N,
    Minutes = sum(Minutes),
    Weighted = sum(Weighted),
    Rate = 90 * sum(Weighted) / sum(Minutes)
  ), by = Player]
  result <- merge(base, observed, by = "Player", all.x = TRUE, sort = FALSE)
  result[is.na(Appearances), `:=`(
    Appearances = 0L,
    Minutes = 0,
    Weighted = 0,
    Rate = NA_real_
  )]
  result[match(P_ORDER, Player)]
}

inference_cohens_d <- function(appearances) {
  m <- appearances[Player == "Messi", Appearance_Rate]
  r <- appearances[Player == "Ronaldo", Appearance_Rate]
  if (length(m) < 2L || length(r) < 2L) return(NA_real_)
  pooled_var <- ((length(m) - 1) * stats::var(m) +
    (length(r) - 1) * stats::var(r)) /
    (length(m) + length(r) - 2)
  if (!is.finite(pooled_var) || pooled_var <= 0) return(NA_real_)
  (mean(m) - mean(r)) / sqrt(pooled_var)
}

inference_bootstrap_difference <- function(
  appearances,
  reps = INFERENCE_REPS,
  seed = INFERENCE_SEED
) {
  m <- appearances[Player == "Messi"]
  r <- appearances[Player == "Ronaldo"]
  if (nrow(m) < 2L || nrow(r) < 2L) return(NULL)

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(seed)
  m_rate <- numeric(reps)
  r_rate <- numeric(reps)
  for (i in seq_len(reps)) {
    mi <- sample.int(nrow(m), nrow(m), replace = TRUE)
    ri <- sample.int(nrow(r), nrow(r), replace = TRUE)
    m_rate[i] <- 90 * sum(m$Weighted[mi]) / sum(m$Minutes[mi])
    r_rate[i] <- 90 * sum(r$Weighted[ri]) / sum(r$Minutes[ri])
  }
  differences <- m_rate - r_rate
  stopifnot(length(differences) == reps, all(is.finite(differences)))
  attr(differences, "sample_sizes") <- c(
    Messi = nrow(m),
    Ronaldo = nrow(r)
  )
  differences
}

inference_summarize <- function(appearances, run_bootstrap = TRUE) {
  players <- inference_player_summary(appearances)
  both_present <- all(players$Appearances > 0L)
  observed_gap <- if (both_present) {
    players[Player == "Messi", Rate] - players[Player == "Ronaldo", Rate]
  } else {
    NA_real_
  }
  can_infer <- all(players$Appearances >= 2L)
  differences <- if (run_bootstrap && can_infer) {
    inference_bootstrap_difference(appearances)
  } else {
    NULL
  }
  interval <- if (length(differences)) {
    unname(stats::quantile(differences, c(0.025, 0.975), names = FALSE))
  } else {
    c(NA_real_, NA_real_)
  }

  list(
    players = players,
    observed_gap = observed_gap,
    differences = differences,
    interval = interval,
    probability_above_zero = if (length(differences)) mean(differences > 0) else NA_real_,
    cohens_d = if (can_infer) inference_cohens_d(appearances) else NA_real_,
    can_infer = can_infer,
    both_present = both_present
  )
}

inference_subgroup_table <- function(appearances, variable, levels) {
  rows <- lapply(levels, function(level) {
    subset <- appearances[as.character(get(variable)) == level]
    summary <- inference_summarize(subset, run_bootstrap = TRUE)
    players <- summary$players
    data.table::data.table(
      Subgroup = level,
      Messi_Appearances = players[Player == "Messi", Appearances],
      Messi_Rate = players[Player == "Messi", Rate],
      Ronaldo_Appearances = players[Player == "Ronaldo", Appearances],
      Ronaldo_Rate = players[Player == "Ronaldo", Rate],
      Gap = summary$observed_gap,
      CI_Low = summary$interval[1],
      CI_High = summary$interval[2],
      Cohens_d = summary$cohens_d,
      Sparse = any(players$Appearances < 30L),
      Can_Infer = summary$can_infer
    )
  })
  data.table::rbindlist(rows)
}

inference_run_analysis <- function(goals, matches, snapshot) {
  appearances <- inference_prepare_appearances(goals, matches, snapshot)
  overall <- inference_summarize(appearances, run_bootstrap = TRUE)
  era <- inference_subgroup_table(appearances, "Era", INFERENCE_ERA_LEVELS)
  represented_families <- INFERENCE_FAMILY_LEVELS[
    INFERENCE_FAMILY_LEVELS %in% as.character(unique(appearances$Comp_Group))
  ]
  family <- inference_subgroup_table(
    appearances, "Comp_Group", represented_families
  )
  list(
    snapshot = snapshot,
    appearances = appearances,
    eligible_goals = attr(appearances, "eligible_goals"),
    missing_difficulty = attr(appearances, "missing_difficulty"),
    overall = overall,
    era = era,
    family = family
  )
}

inference_independent_check <- function(appearances) {
  players <- inference_player_summary(appearances)
  m <- appearances[Player == "Messi", Appearance_Rate]
  r <- appearances[Player == "Ronaldo", Appearance_Rate]
  pooled_sd <- if (length(m) >= 2L && length(r) >= 2L) {
    sqrt(
      ((length(m) - 1) * stats::var(m) + (length(r) - 1) * stats::var(r)) /
        (length(m) + length(r) - 2)
    )
  } else {
    NA_real_
  }
  list(
    Messi_Rate = 90 * sum(
      appearances[Player == "Messi", Weighted]
    ) / sum(appearances[Player == "Messi", Minutes]),
    Ronaldo_Rate = 90 * sum(
      appearances[Player == "Ronaldo", Weighted]
    ) / sum(appearances[Player == "Ronaldo", Minutes]),
    Gap = players[Player == "Messi", Rate] - players[Player == "Ronaldo", Rate],
    Cohens_d = if (is.finite(pooled_sd) && pooled_sd > 0) {
      (mean(m) - mean(r)) / pooled_sd
    } else {
      NA_real_
    }
  )
}

inference_value_card <- function(label, value, detail, class = "") {
  tags$article(
    class = paste("inference-value-card", class),
    div(label, class = "inference-value-card__label"),
    div(value, class = "inference-value-card__value"),
    div(detail, class = "inference-value-card__detail")
  )
}

inference_empty_plot <- function(message) {
  plot <- plotly::plot_ly(
    x = numeric(), y = numeric(), type = "scatter", mode = "markers",
    hoverinfo = "skip", showlegend = FALSE
  )
  plotly::layout(
    plot,
    margin = list(l = 64, r = 20, b = 58, t = 20),
    xaxis = list(title = "Messi - Ronaldo weighted-index gap / 90", showgrid = FALSE),
    yaxis = list(title = "Bootstrap density", showgrid = FALSE),
    annotations = list(list(
      x = 0.5, y = 0.5, xref = "paper", yref = "paper",
      text = message, showarrow = FALSE, align = "center",
      font = list(color = "#6B7A8D", size = 13)
    ))
  )
}

inference_plot_config <- function(plot) {
  plotly::config(
    plot,
    displaylogo = FALSE,
    responsive = TRUE,
    modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d")
  )
}

mod_inference_ui <- function(id) {
  ns <- NS(id)

  tags$section(
    class = "inference-lab",
    `aria-labelledby` = ns("inference_title"),
    div(
      class = "inference-lab__header",
      div(
        p("MATCH-LEVEL UNCERTAINTY", class = "inference-lab__eyebrow"),
        h1("Inference and Uncertainty", id = ns("inference_title")),
        p(
          "Freeze the current assumptions, resample complete appearances, and inspect the full distribution of the Messi - Ronaldo weighted-index gap.",
          class = "inference-lab__lede"
        )
      ),
      uiOutput(ns("frozen_badges"))
    ),

    uiOutput(ns("analysis_status")),
    uiOutput(ns("coverage_note")),
    uiOutput(ns("headline_cards")),

    card(
      class = "inference-card inference-card--density",
      card_header(
        div(
          h2("Bootstrap distribution", id = ns("density_title")),
          span("10,000 within-player match resamples", class = "inference-card__unit")
        )
      ),
      card_body(
        plotly::plotlyOutput(ns("bootstrap_density"), height = "410px"),
        p(
          "The shaded band is the 95% percentile interval. Reference lines mark zero and the observed ratio-of-sums gap.",
          class = "chart-note"
        ),
        tags$p(
          textOutput(ns("density_summary"), inline = TRUE),
          class = "visually-hidden",
          role = "note"
        )
      )
    ),

    card(
      class = "inference-card inference-card--subgroups",
      card_header(
        div(
          h2("Subgroup uncertainty", id = ns("subgroup_title")),
          span("Descriptive rates plus guarded intervals", class = "inference-card__unit")
        ),
        selectInput(
          ns("subgroup_view"),
          "Group rows by",
          choices = c("Career era" = "era", "Competition family" = "family"),
          selected = "era",
          width = NULL
        )
      ),
      card_body(
        div(
          class = "inference-table-wrap",
          uiOutput(ns("subgroup_table"))
        ),
        p(
          "Sparse means fewer than 30 appearances for at least one player. Intervals and d are suppressed unless both players have at least two appearances.",
          class = "chart-note"
        )
      )
    ),

    card(
      class = "inference-interpretation",
      card_header(h2("How to interpret this analysis", id = ns("interpretation_title"))),
      card_body(
        tags$ul(
          class = "inference-caveats",
          tags$li(tags$strong("Resampling unit: "), "whole appearances, independently within each player; each replicate preserves that player's selected-scope appearance count."),
          tags$li(tags$strong("Primary estimator: "), "the ratio of summed selected-K goal contributions to summed valid minutes, scaled to 90 minutes."),
          tags$li(tags$strong("Directional probability: "), "the share of bootstrap differences above zero. It is descriptive uncertainty, not a p-value or a binary verdict."),
          tags$li(tags$strong("Cohen's d: "), "the conventional pooled-SD difference between appearance-level weighted rates; it complements but does not replace the ratio-of-sums estimator."),
          tags$li(tags$strong("Missing difficulty: "), "goals without a score stay disclosed but add nothing to weighted numerators. Penalty exclusion changes contributions only."),
          tags$li(tags$strong("Subgroups: "), "inherit the frozen global competition and venue scope. Sparse rows should be treated as exploratory."),
          tags$li(tags$strong("No winner flag: "), "the complete distribution, numerical interval, probability, and effect size are reported without p-values or significance labels.")
        )
      )
    )
  )
}

mod_inference_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    if (!requireNamespace("plotly", quietly = TRUE)) {
      stop("The Inference tab requires the installed runtime package 'plotly'.")
    }

    goals <- data.table::copy(shiny::isolate(state$bundle$goals))
    matches <- data.table::copy(shiny::isolate(state$bundle$valid_matches))
    stopifnot(
      nrow(goals) == 1738L,
      nrow(matches) == 2201L,
      sum(matches$Minutes) == 181081,
      sum(as.numeric(matches$Gls) == 0) == 1063L,
      sum(is.na(goals$Difficulty_Score)) == 3L,
      matches[, .N, by = INFERENCE_MATCH_KEYS][N > 1L, .N] == 0L
    )

    result <- reactiveVal(NULL)
    result_cache <- new.env(parent = emptyenv())
    bundle_stamp <- shiny::isolate(as.character(state$bundle$meta$built_at)[1L])
    density_cache_key <- reactive(
      inference_density_cache_key(bundle_stamp, result())
    )

    live_snapshot <- reactive(inference_snapshot(
      state$K, state$exclude_pen, state$competition, state$venue
    ))

    observeEvent(state$boot_trigger, {
      snapshot <- shiny::isolate(live_snapshot())
      key <- inference_snapshot_key(snapshot)
      if (exists(key, envir = result_cache, inherits = FALSE)) {
        result(get(key, envir = result_cache, inherits = FALSE))
        return()
      }

      analysis <- withProgress(
        message = "Running match-level bootstrap",
        detail = "Overall and subgroup distributions · 10,000 resamples each",
        value = 0,
        {
          incProgress(0.08, detail = "Joining goals to all valid appearances")
          appearances <- inference_prepare_appearances(goals, matches, snapshot)
          incProgress(0.18, detail = "Overall comparison")
          overall <- inference_summarize(appearances, run_bootstrap = TRUE)
          incProgress(0.34, detail = "Career-era subgroups")
          era <- inference_subgroup_table(
            appearances, "Era", INFERENCE_ERA_LEVELS
          )
          represented_families <- INFERENCE_FAMILY_LEVELS[
            INFERENCE_FAMILY_LEVELS %in% as.character(unique(appearances$Comp_Group))
          ]
          incProgress(0.32, detail = "Competition-family subgroups")
          family <- inference_subgroup_table(
            appearances, "Comp_Group", represented_families
          )
          incProgress(0.08, detail = "Preparing results")
          list(
            snapshot = snapshot,
            appearances = appearances,
            eligible_goals = attr(appearances, "eligible_goals"),
            missing_difficulty = attr(appearances, "missing_difficulty"),
            overall = overall,
            era = era,
            family = family
          )
        }
      )
      assign(key, analysis, envir = result_cache)
      result(analysis)
    }, ignoreInit = TRUE)

    output$frozen_badges <- renderUI({
      analysis <- result()
      if (is.null(analysis)) {
        return(div(
          class = "inference-context",
          span("Not run yet", class = "inference-context__badge inference-context__badge--pending")
        ))
      }
      snapshot <- analysis$snapshot
      div(
        class = "inference-context",
        span(sprintf("K = %.1f", snapshot$K), class = "inference-context__badge"),
        span(
          if (snapshot$exclude_pen) "Penalties excluded" else "Penalties included",
          class = "inference-context__badge"
        ),
        span(
          paste(snapshot$competition, snapshot$venue, sep = " · "),
          class = "inference-context__badge inference-context__badge--scope"
        )
      )
    })

    output$analysis_status <- renderUI({
      analysis <- result()
      if (is.null(analysis)) {
        return(div(
          "Choose assumptions in the sidebar, then select Update analysis to run the inference.",
          class = "inference-status inference-status--pending",
          role = "status"
        ))
      }
      stale <- !inference_same_snapshot(analysis$snapshot, live_snapshot())
      if (stale) {
        div(
          "Controls changed - results below still use the frozen settings shown above. Select Update analysis to refresh them.",
          class = "inference-status inference-status--stale",
          role = "status"
        )
      } else {
        div(
          paste("Results match the current controls:", inference_scope_label(analysis$snapshot)),
          class = "inference-status inference-status--current",
          role = "status"
        )
      }
    })

    output$coverage_note <- renderUI({
      analysis <- result()
      if (is.null(analysis)) return(NULL)
      scored <- analysis$eligible_goals - analysis$missing_difficulty
      div(
        sprintf(
          paste0(
            "Frozen denominator: %s appearances and %s valid minutes. ",
            "Weighted numerators use %s of %s eligible goals; %s missing-difficulty goal%s contribute zero."
          ),
          format(nrow(analysis$appearances), big.mark = ","),
          format(sum(analysis$appearances$Minutes), big.mark = ","),
          format(scored, big.mark = ","),
          format(analysis$eligible_goals, big.mark = ","),
          format(analysis$missing_difficulty, big.mark = ","),
          if (analysis$missing_difficulty == 1L) "" else "s"
        ),
        class = "inference-coverage-note",
        role = "note"
      )
    })

    output$headline_cards <- renderUI({
      analysis <- result()
      if (is.null(analysis)) {
        return(div(
          class = "inference-headlines",
          inference_value_card("Observed gap / 90", "N/A", "Run the analysis", "inference-value-card--gap"),
          inference_value_card("95% percentile interval", "N/A", "Run the analysis", "inference-value-card--interval"),
          inference_value_card("Bootstrap P(gap > 0)", "N/A", "Run the analysis", "inference-value-card--probability"),
          inference_value_card("Match-level Cohen's d", "N/A", "Run the analysis", "inference-value-card--effect")
        ))
      }
      overall <- analysis$overall
      format_value <- function(value, pattern = "%.4f") {
        if (is.finite(value)) sprintf(pattern, value) else "N/A"
      }
      interval_text <- if (all(is.finite(overall$interval))) {
        sprintf("[%+.4f, %+.4f]", overall$interval[1], overall$interval[2])
      } else {
        "N/A"
      }
      reason <- if (!overall$both_present) {
        "Both players need appearances for a gap"
      } else if (!overall$can_infer) {
        "Both players need at least two appearances"
      } else {
        "10,000 finite match-level differences"
      }
      div(
        class = "inference-headlines",
        inference_value_card(
          "Observed gap / 90",
          format_value(overall$observed_gap, "%+.4f"),
          "ratio of sums · Messi - Ronaldo",
          "inference-value-card--gap"
        ),
        inference_value_card(
          "95% percentile interval",
          interval_text,
          reason,
          "inference-value-card--interval"
        ),
        inference_value_card(
          "Bootstrap P(gap > 0)",
          format_value(overall$probability_above_zero, "%.3f"),
          "share of resampled gaps above zero",
          "inference-value-card--probability"
        ),
        inference_value_card(
          "Match-level Cohen's d",
          format_value(overall$cohens_d, "%+.3f"),
          "pooled-SD appearance-rate difference",
          "inference-value-card--effect"
        )
      )
    })

    output$bootstrap_density <- shiny::bindCache(plotly::renderPlotly({
      analysis <- result()
      if (is.null(analysis)) {
        return(inference_plot_config(inference_empty_plot(
          "Select Update analysis to generate the bootstrap distribution."
        )))
      }
      overall <- analysis$overall
      if (!length(overall$differences)) {
        return(inference_plot_config(inference_empty_plot(
          "Both players need at least two valid appearances in the frozen scope."
        )))
      }

      differences <- overall$differences
      if (stats::sd(differences) > 0) {
        density <- stats::density(differences, n = 512)
        curve <- data.table::data.table(Gap = density$x, Density = density$y)
      } else {
        centre <- differences[1]
        epsilon <- max(abs(centre) * 0.01, 1e-6)
        curve <- data.table::data.table(
          Gap = c(centre - epsilon, centre, centre + epsilon),
          Density = c(0, 1, 0)
        )
      }
      curve[, Hover := sprintf(
        "Bootstrap gap: %+.4f<br>Estimated density: %.3f", Gap, Density
      )]

      plot <- plotly::plot_ly(
        curve,
        x = ~Gap,
        y = ~Density,
        text = ~Hover,
        hoverinfo = "text",
        type = "scatter",
        mode = "lines",
        line = list(color = "#15324B", width = 2.8),
        fill = "tozeroy",
        fillcolor = "rgba(21,50,75,.13)",
        name = "Bootstrap density",
        showlegend = FALSE
      )
      shapes <- list(
        list(
          type = "rect",
          x0 = overall$interval[1], x1 = overall$interval[2], xref = "x",
          y0 = 0, y1 = 1, yref = "paper",
          fillcolor = "rgba(28,124,125,.16)",
          line = list(width = 0),
          layer = "below"
        ),
        list(
          type = "line", x0 = 0, x1 = 0, xref = "x",
          y0 = 0, y1 = 1, yref = "paper",
          line = list(color = "#657486", width = 1.5, dash = "dot")
        ),
        list(
          type = "line",
          x0 = overall$observed_gap, x1 = overall$observed_gap, xref = "x",
          y0 = 0, y1 = 1, yref = "paper",
          line = list(color = "#A61E2C", width = 2.2, dash = "dash")
        )
      )
      annotations <- list(
        list(
          x = 0, y = 1.02, xref = "x", yref = "paper",
          text = "Zero", showarrow = FALSE, yanchor = "bottom",
          font = list(color = "#657486", size = 11)
        ),
        list(
          x = overall$observed_gap, y = .9, xref = "x", yref = "paper",
          text = sprintf("Observed %+.4f", overall$observed_gap),
          showarrow = FALSE, xanchor = "left",
          bgcolor = "rgba(255,255,255,.86)",
          borderpad = 2,
          font = list(color = "#A61E2C", size = 11)
        )
      )
      plot <- plotly::layout(
        plot,
        margin = list(l = 68, r = 28, b = 62, t = 32),
        hovermode = "closest",
        xaxis = list(title = "Messi - Ronaldo weighted-index gap / 90"),
        yaxis = list(title = "Bootstrap density", rangemode = "tozero"),
        shapes = shapes,
        annotations = annotations
      )
      inference_plot_config(plot)
    }), density_cache_key())

    output$density_summary <- renderText({
      analysis <- result()
      if (is.null(analysis)) return("The bootstrap has not been run.")
      overall <- analysis$overall
      if (!length(overall$differences)) {
        return("The frozen scope does not contain at least two valid appearances for both players, so no interval is available.")
      }
      sprintf(
        paste0(
          "The density summarizes %s finite match-level bootstrap differences. ",
          "The observed Messi minus Ronaldo gap is %+.4f weighted index units per 90. ",
          "The 95 percent percentile interval is %+.4f to %+.4f, and %.1f percent of differences are above zero."
        ),
        format(length(overall$differences), big.mark = ","),
        overall$observed_gap,
        overall$interval[1],
        overall$interval[2],
        100 * overall$probability_above_zero
      )
    })

    output$subgroup_table <- renderUI({
      analysis <- result()
      if (is.null(analysis)) {
        return(div(
          "Subgroup results appear after Update analysis.",
          class = "inference-table-empty",
          role = "status"
        ))
      }
      view <- input$subgroup_view %||% "era"
      table_data <- if (identical(view, "family")) analysis$family else analysis$era
      if (!nrow(table_data)) {
        return(div(
          "No subgroup contains a valid appearance in this frozen scope.",
          class = "inference-table-empty",
          role = "status"
        ))
      }

      rate <- function(value) if (is.finite(value)) sprintf("%.4f", value) else "N/A"
      gap <- function(value) if (is.finite(value)) sprintf("%+.4f", value) else "N/A"
      effect <- function(value) if (is.finite(value)) sprintf("%+.3f", value) else "N/A"
      interval <- function(low, high) {
        if (is.finite(low) && is.finite(high)) {
          sprintf("[%+.4f, %+.4f]", low, high)
        } else {
          "N/A"
        }
      }

      rows <- lapply(seq_len(nrow(table_data)), function(i) {
        row <- table_data[i]
        note <- if (!row$Can_Infer) {
          "Sparse · inference suppressed"
        } else if (row$Sparse) {
          "Sparse"
        } else {
          "Adequate count"
        }
        tags$tr(
          class = if (row$Sparse) "inference-table__row--sparse" else NULL,
          tags$th(scope = "row", row$Subgroup),
          tags$td(format(row$Messi_Appearances, big.mark = ",")),
          tags$td(rate(row$Messi_Rate)),
          tags$td(format(row$Ronaldo_Appearances, big.mark = ",")),
          tags$td(rate(row$Ronaldo_Rate)),
          tags$td(gap(row$Gap)),
          tags$td(interval(row$CI_Low, row$CI_High)),
          tags$td(effect(row$Cohens_d)),
          tags$td(note)
        )
      })

      tags$table(
        class = "inference-table",
        tags$caption(
          if (identical(view, "family")) {
            "Competition-family results under the frozen global scope"
          } else {
            "Career-era results under the frozen global scope"
          }
        ),
        tags$thead(tags$tr(
          tags$th(scope = "col", "Subgroup"),
          tags$th(scope = "col", "Messi apps"),
          tags$th(scope = "col", "Messi / 90"),
          tags$th(scope = "col", "Ronaldo apps"),
          tags$th(scope = "col", "Ronaldo / 90"),
          tags$th(scope = "col", "Gap"),
          tags$th(scope = "col", "95% interval"),
          tags$th(scope = "col", "Cohen's d"),
          tags$th(scope = "col", "Count note")
        )),
        tags$tbody(rows)
      )
    })

    list(
      result = result,
      live_snapshot = live_snapshot
    )
  })
}
