# app/R/mod_summary.R
# Wave 5: fixed-reference and live selected-scope descriptive comparisons.

SUMMARY_PLAYERS <- c("Messi", "Ronaldo")
SUMMARY_ERA_LEVELS <- c(
  "Rise (2002-08)", "Peak (2009-14)", "Prime (2015-18)",
  "Transition (2019-22)", "Late (2023-26)"
)
SUMMARY_FAMILY_LEVELS <- c(
  "League", "Continental", "Domestic cup", "International", "Other"
)
SUMMARY_VENUE_LEVELS <- c("Home", "Away", "Neutral")

summary_snapshot <- function(
  k = 1,
  exclude_pen = FALSE,
  competition = "All competitions",
  venue = "All venues"
) {
  list(
    K = as.numeric(k),
    exclude_pen = isTRUE(exclude_pen),
    competition = as.character(competition),
    venue = as.character(venue)
  )
}

summary_scope_label <- function(snapshot) {
  paste(
    sprintf("K %.1f", snapshot$K),
    if (snapshot$exclude_pen) "penalties excluded" else "penalties included",
    snapshot$competition,
    snapshot$venue,
    sep = " · "
  )
}

summary_prepare_scope <- function(goals, matches, snapshot) {
  scoped_goals <- data.table::copy(goals)
  scoped_matches <- data.table::copy(matches)

  if (!identical(snapshot$competition, "All competitions")) {
    scoped_goals <- scoped_goals[Comp == snapshot$competition]
    scoped_matches <- scoped_matches[Comp == snapshot$competition]
  }
  if (!identical(snapshot$venue, "All venues")) {
    scoped_goals <- scoped_goals[Venue == snapshot$venue]
    scoped_matches <- scoped_matches[Venue == snapshot$venue]
  }
  if (snapshot$exclude_pen) scoped_goals <- scoped_goals[Penalty == FALSE]

  family_map <- unique(goals[, .(Comp, Comp_Group)])
  scoped_matches <- merge(
    scoped_matches,
    family_map,
    by = "Comp",
    all.x = TRUE,
    sort = FALSE
  )
  scoped_matches[is.na(Comp_Group), Comp_Group := "Other"]
  scoped_matches[, `:=`(
    Era = factor(as.character(Era), levels = SUMMARY_ERA_LEVELS),
    Comp_Group = factor(as.character(Comp_Group), levels = SUMMARY_FAMILY_LEVELS),
    Venue = factor(as.character(Venue), levels = SUMMARY_VENUE_LEVELS)
  )]
  scoped_goals[, `:=`(
    Era = factor(as.character(Era), levels = SUMMARY_ERA_LEVELS),
    Comp_Group = factor(as.character(Comp_Group), levels = SUMMARY_FAMILY_LEVELS),
    Venue = factor(as.character(Venue), levels = SUMMARY_VENUE_LEVELS),
    Selected_Weight = signed_difficulty_power(Difficulty_Score, snapshot$K)
  )]

  list(goals = scoped_goals, matches = scoped_matches, snapshot = snapshot)
}

summary_dimension_long <- function(scoped, variable = NULL, levels = NULL, section = "Overall") {
  goals <- data.table::copy(scoped$goals)
  matches <- data.table::copy(scoped$matches)

  if (is.null(variable)) {
    goals[, Summary_Scope := "All selected data"]
    matches[, Summary_Scope := "All selected data"]
    levels <- "All selected data"
  } else {
    goals[, Summary_Scope := as.character(get(variable))]
    matches[, Summary_Scope := as.character(get(variable))]
  }

  denominator <- matches[!is.na(Summary_Scope), .(
    Apps = .N,
    Minutes = sum(Minutes)
  ), by = .(Player, Summary_Scope)]
  numerator <- goals[!is.na(Summary_Scope), .(
    Raw = .N,
    Weighted = sum(Selected_Weight, na.rm = TRUE),
    Missing_Difficulty = sum(is.na(Difficulty_Score))
  ), by = .(Player, Summary_Scope)]

  scaffold <- data.table::CJ(
    Player = SUMMARY_PLAYERS,
    Summary_Scope = as.character(levels),
    unique = TRUE
  )
  rows <- merge(scaffold, denominator, by = c("Player", "Summary_Scope"), all.x = TRUE, sort = FALSE)
  rows <- merge(rows, numerator, by = c("Player", "Summary_Scope"), all.x = TRUE, sort = FALSE)
  rows[is.na(Apps), `:=`(Apps = 0L, Minutes = 0)]
  rows[is.na(Raw), `:=`(Raw = 0L, Weighted = 0, Missing_Difficulty = 0L)]
  rows[, `:=`(
    Weighted_per90 = data.table::fifelse(Minutes > 0, 90 * Weighted / Minutes, NA_real_),
    Raw_per90 = data.table::fifelse(Minutes > 0, 90 * Raw / Minutes, NA_real_),
    Section = section,
    Scope_Order = match(Summary_Scope, as.character(levels))
  )]
  rows[, Player_Order := match(Player, SUMMARY_PLAYERS)]
  data.table::setorder(rows, Scope_Order, Player_Order)
  rows[, Player_Order := NULL]
  rows
}

summary_comparison_table <- function(scoped, include_empty = TRUE) {
  long <- data.table::rbindlist(list(
    summary_dimension_long(scoped, section = "Overall"),
    summary_dimension_long(scoped, "Era", SUMMARY_ERA_LEVELS, "Career era"),
    summary_dimension_long(scoped, "Comp_Group", SUMMARY_FAMILY_LEVELS, "Competition family"),
    summary_dimension_long(scoped, "Venue", SUMMARY_VENUE_LEVELS, "Venue")
  ), use.names = TRUE)

  wide <- data.table::dcast(
    long,
    Section + Summary_Scope + Scope_Order ~ Player,
    value.var = c(
      "Apps", "Minutes", "Raw", "Weighted", "Weighted_per90",
      "Raw_per90", "Missing_Difficulty"
    )
  )
  for (prefix in c("Apps", "Minutes", "Raw", "Weighted", "Weighted_per90", "Raw_per90", "Missing_Difficulty")) {
    for (player in SUMMARY_PLAYERS) {
      name <- paste(prefix, player, sep = "_")
      if (!name %in% names(wide)) {
        wide[, (name) := if (grepl("per90", prefix, fixed = TRUE)) NA_real_ else 0]
      }
    }
  }
  wide[, `:=`(
    Weighted_Gap = data.table::fifelse(
      !is.na(Weighted_per90_Messi) & !is.na(Weighted_per90_Ronaldo),
      Weighted_per90_Messi - Weighted_per90_Ronaldo,
      NA_real_
    ),
    Raw_Gap = data.table::fifelse(
      !is.na(Raw_per90_Messi) & !is.na(Raw_per90_Ronaldo),
      Raw_per90_Messi - Raw_per90_Ronaldo,
      NA_real_
    )
  )]
  section_order <- c("Overall", "Career era", "Competition family", "Venue")
  wide[, Section_Order := match(Section, section_order)]
  data.table::setorder(wide, Section_Order, Scope_Order)
  if (!include_empty) {
    wide <- wide[Section == "Overall" | Apps_Messi + Apps_Ronaldo > 0]
  }
  wide[]
}

summary_fmt_rate <- function(value, signed = FALSE) {
  if (is.na(value) || !is.finite(value)) return("N/A")
  if (signed) sprintf("%+.4f", value) else sprintf("%.4f", value)
}

summary_fmt_exposure <- function(apps, minutes) {
  if (is.na(apps) || apps <= 0L) return("N/A")
  sprintf("%s / %s", format(apps, big.mark = ","), format(minutes, big.mark = ","))
}

summary_semantic_table <- function(rows, caption) {
  tags$div(
    class = "summary-table-wrap",
    tags$table(
      class = "summary-table",
      tags$caption(caption),
      tags$thead(tags$tr(
        tags$th(scope = "col", "Dimension"),
        tags$th(scope = "col", "Scope"),
        tags$th(scope = "col", "Messi apps / min"),
        tags$th(scope = "col", "Ronaldo apps / min"),
        tags$th(scope = "col", "Messi weighted / 90"),
        tags$th(scope = "col", "Ronaldo weighted / 90"),
        tags$th(scope = "col", "Weighted gap"),
        tags$th(scope = "col", "Messi raw / 90"),
        tags$th(scope = "col", "Ronaldo raw / 90"),
        tags$th(scope = "col", "Raw gap")
      )),
      tags$tbody(lapply(seq_len(nrow(rows)), function(i) {
        row <- rows[i]
        tags$tr(
          class = if (row$Apps_Messi == 0L || row$Apps_Ronaldo == 0L) "summary-table__row--incomplete" else NULL,
          tags$td(row$Section),
          tags$th(scope = "row", row$Summary_Scope),
          tags$td(summary_fmt_exposure(row$Apps_Messi, row$Minutes_Messi)),
          tags$td(summary_fmt_exposure(row$Apps_Ronaldo, row$Minutes_Ronaldo)),
          tags$td(summary_fmt_rate(row$Weighted_per90_Messi)),
          tags$td(summary_fmt_rate(row$Weighted_per90_Ronaldo)),
          tags$td(summary_fmt_rate(row$Weighted_Gap, TRUE)),
          tags$td(summary_fmt_rate(row$Raw_per90_Messi)),
          tags$td(summary_fmt_rate(row$Raw_per90_Ronaldo)),
          tags$td(summary_fmt_rate(row$Raw_Gap, TRUE))
        )
      }))
    )
  )
}

mod_summary_ui <- function(id) {
  ns <- NS(id)

  tags$section(
    class = "summary-page",
    `aria-labelledby` = ns("summary_title"),
    div(
      class = "summary-hero",
      div(
        p("WEIGHTED FIRST · RAW BESIDE IT", class = "summary-hero__eyebrow"),
        h1("Definitive comparison table", id = ns("summary_title")),
        p(
          "One fixed reference and one live selected-scope view, using the same all-valid-minute denominator rules.",
          class = "summary-hero__lede"
        )
      ),
      div(
        class = "summary-legend",
        span(class = "summary-legend__weighted", "Weighted index / 90"),
        span(class = "summary-legend__raw", "Raw goals / 90")
      )
    ),

    card(
      class = "summary-card summary-card--baseline",
      card_header(
        div(
          h2("Fixed career reference", id = ns("baseline_title")),
          span("K 1.0 · penalties included · all competitions · all venues", class = "summary-card__unit")
        ),
        span("Reference", class = "summary-status summary-status--fixed")
      ),
      card_body(
        uiOutput(ns("baseline_table")),
        p(
          "This view never changes with the sidebar and matches the Overview baseline. It is a reproducible anchor, not a winner declaration.",
          class = "summary-note"
        )
      )
    ),

    card(
      class = "summary-card summary-card--live",
      card_header(
        div(
          h2("Live selected-scope comparison", id = ns("live_title")),
          uiOutput(ns("live_context"))
        ),
        span("Updates immediately", class = "summary-status summary-status--live")
      ),
      card_body(
        uiOutput(ns("live_notice")),
        uiOutput(ns("live_table")),
        p(
          "Live rows are descriptive. For confidence intervals, the full density, directional probability, and Cohen's d, use the button-frozen Inference tab.",
          class = "summary-note"
        )
      )
    ),

    card(
      class = "summary-reading-card",
      card_header(h2("Reading rules", id = ns("summary_rules"))),
      card_body(tags$ul(
        tags$li(tags$strong("Weighted gap: "), "Messi weighted index / 90 minus Ronaldo weighted index / 90."),
        tags$li(tags$strong("Raw gap: "), "Messi raw goals / 90 minus Ronaldo raw goals / 90."),
        tags$li(tags$strong("Apps / min: "), "every valid selected-scope appearance and minute, including scoreless appearances."),
        tags$li(tags$strong("N/A: "), "no valid exposure for at least one requested player; a genuine zero remains 0.0000."),
        tags$li(tags$strong("Missing difficulty: "), "the goal remains raw but contributes zero weighted index units.")
      ))
    )
  )
}

mod_summary_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    goals <- data.table::copy(shiny::isolate(state$bundle$goals))
    matches <- data.table::copy(shiny::isolate(state$bundle$valid_matches))

    stopifnot(
      nrow(goals) == 1738L,
      nrow(matches) == 2201L,
      sum(matches$Minutes) == 181081,
      sum(matches$Gls == 0) == 1063L,
      sum(is.na(goals$Difficulty_Score)) == 3L
    )

    baseline <- summary_comparison_table(summary_prepare_scope(
      goals,
      matches,
      summary_snapshot()
    ))

    live_snapshot <- reactive(summary_snapshot(
      k = state$K,
      exclude_pen = state$exclude_pen,
      competition = state$competition,
      venue = state$venue
    ))

    live_rows <- reactive({
      summary_comparison_table(
        summary_prepare_scope(goals, matches, live_snapshot()),
        include_empty = FALSE
      )
    })

    output$baseline_table <- renderUI({
      summary_semantic_table(
        baseline,
        "Fixed K = 1 career reference across overall, era, competition-family, and venue dimensions"
      )
    })

    output$live_context <- renderUI({
      span(summary_scope_label(live_snapshot()), class = "summary-card__unit")
    })

    output$live_notice <- renderUI({
      overall <- live_rows()[Section == "Overall"]
      if (!nrow(overall) || overall$Apps_Messi + overall$Apps_Ronaldo == 0L) {
        return(div(
          "No valid appearances exist in the selected competition and venue scope. Rates are N/A until the scope changes.",
          class = "summary-notice",
          role = "status"
        ))
      }
      missing_player <- c(
        if (overall$Apps_Messi == 0L) "Messi" else character(),
        if (overall$Apps_Ronaldo == 0L) "Ronaldo" else character()
      )
      if (length(missing_player)) {
        return(div(
          sprintf("%s has no valid appearances in this scope, so player gaps are N/A.", paste(missing_player, collapse = " and ")),
          class = "summary-notice",
          role = "status"
        ))
      }
      NULL
    })

    output$live_table <- renderUI({
      summary_semantic_table(
        live_rows(),
        paste("Live descriptive comparison:", summary_scope_label(live_snapshot()))
      )
    })
  })
}
