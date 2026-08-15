# app/R/mod_head2head.R
# Wave 3: age-aligned trajectories, opponent-Elo context, and penalty mix.

H2H_MATCH_KEYS <- c("Player", "Date", "Comp", "Round", "Opp_clean")
H2H_BIRTH_DATES <- as.Date(c(Messi = "1987-06-24", Ronaldo = "1985-02-05"))

h2h_value_card <- function(label, value, detail, class = "") {
  tags$article(
    class = paste("h2h-value-card", class),
    div(label, class = "h2h-value-card__label"),
    div(value, class = "h2h-value-card__value"),
    div(detail, class = "h2h-value-card__detail")
  )
}

h2h_plot_config <- function(plot) {
  plotly::config(
    plot,
    displaylogo = FALSE,
    responsive = TRUE,
    modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d")
  )
}

h2h_empty_plot <- function(message, x_title = "", y_title = "") {
  plot <- plotly::plot_ly(
    x = numeric(),
    y = numeric(),
    type = "scatter",
    mode = "markers",
    hoverinfo = "skip",
    showlegend = FALSE
  )
  plotly::layout(
    plot,
    margin = list(l = 56, r = 20, b = 54, t = 18),
    xaxis = list(title = x_title, showgrid = FALSE, zeroline = FALSE),
    yaxis = list(title = y_title, showgrid = FALSE, zeroline = FALSE),
    annotations = list(list(
      x = 0.5, y = 0.5, xref = "paper", yref = "paper",
      text = message, showarrow = FALSE, align = "center",
      font = list(color = "#6B7A8D", size = 13)
    ))
  )
}

h2h_scope_text <- function(competition, venue) {
  paste(
    if (identical(competition, "All competitions")) {
      "All competitions"
    } else {
      competition
    },
    if (identical(venue, "All venues")) {
      "All venues"
    } else {
      venue
    },
    sep = " · "
  )
}

mod_head2head_ui <- function(id) {
  ns <- NS(id)

  tags$section(
    class = "h2h-lab",
    `aria-labelledby` = ns("h2h_title"),
    div(
      class = "h2h-lab__header",
      div(
        p("CAREER TRAJECTORIES", class = "h2h-lab__eyebrow"),
        h1("Head-to-Head", id = ns("h2h_title")),
        p(
          "Align the careers by age, inspect every eligible goal against opponent Elo, and see how much of each scoring record came from penalties.",
          class = "h2h-lab__lede"
        )
      ),
      uiOutput(ns("context_badges"))
    ),

    uiOutput(ns("scope_notice")),
    uiOutput(ns("headline_cards")),

    card(
      class = "h2h-card h2h-card--trajectory",
      card_header(
        div(
          h2("Career trajectory", id = ns("trajectory_title")),
          span(
            "The selected competition and venue restart the comparison.",
            class = "h2h-card__unit"
          )
        ),
        div(
          class = "h2h-chart-controls",
          selectInput(
            ns("trajectory_measure"),
            "Measure",
            choices = c(
              "Cumulative weighted index" = "cumulative",
              "Rolling 30-appearance weighted index / 90" = "rolling30"
            ),
            selected = "cumulative",
            width = NULL
          ),
          selectInput(
            ns("trajectory_axis"),
            "Axis",
            choices = c("Age" = "age", "Calendar date" = "date"),
            selected = "age",
            width = NULL
          )
        )
      ),
      card_body(
        plotly::plotlyOutput(ns("trajectory_plot"), height = "390px"),
        p(
          "Rolling values begin at appearance 30 within the filtered scope. The age-30 guide appears only on the age axis.",
          class = "chart-note"
        ),
        tags$p(
          textOutput(ns("trajectory_summary"), inline = TRUE),
          class = "visually-hidden",
          role = "note"
        )
      )
    ),

    div(
      class = "h2h-grid h2h-grid--detail",
      card(
        class = "h2h-card",
        card_header(
          h2("Opponent Elo and selected-K contribution", id = ns("elo_title")),
          span("One unjittered marker per eligible goal", class = "h2h-card__unit")
        ),
        card_body(
          plotly::plotlyOutput(ns("elo_scatter"), height = "380px"),
          p(
            textOutput(ns("elo_note"), inline = TRUE),
            class = "chart-note"
          ),
          tags$p(
            textOutput(ns("elo_summary"), inline = TRUE),
            class = "visually-hidden",
            role = "note"
          )
        )
      ),
      card(
        class = "h2h-card",
        card_header(
          h2("Penalty dependency", id = ns("penalty_title")),
          span("Raw goal composition", class = "h2h-card__unit")
        ),
        card_body(
          plotly::plotlyOutput(ns("penalty_chart"), height = "380px"),
          p(
            textOutput(ns("penalty_note"), inline = TRUE),
            class = "chart-note"
          ),
          tags$p(
            textOutput(ns("penalty_summary"), inline = TRUE),
            class = "visually-hidden",
            role = "note"
          )
        )
      )
    ),

    card(
      class = "h2h-interpretation",
      card_header(h2("Scope and interpretation", id = ns("caveats_title"))),
      card_body(uiOutput(ns("caveats")))
    )
  )
}

mod_head2head_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    if (!requireNamespace("plotly", quietly = TRUE)) {
      stop("The Head-to-Head tab requires the installed runtime package 'plotly'.")
    }

    goals <- data.table::copy(shiny::isolate(state$bundle$goals))
    matches <- data.table::copy(shiny::isolate(state$bundle$valid_matches))

    stopifnot(
      nrow(goals) == 1738L,
      nrow(matches) == 2201L,
      sum(matches$Minutes) == 181081,
      sum(as.numeric(matches$Gls) == 0) == 1063L,
      sum(is.na(goals$Difficulty_Score)) == 3L,
      all(H2H_MATCH_KEYS %in% names(goals)),
      all(H2H_MATCH_KEYS %in% names(matches)),
      matches[, .N, by = H2H_MATCH_KEYS][N > 1, .N] == 0L
    )

    filtered_matches <- reactive({
      result <- matches
      if (!identical(state$competition, "All competitions")) {
        result <- result[Comp == state$competition]
      }
      if (!identical(state$venue, "All venues")) {
        result <- result[Venue == state$venue]
      }
      result
    })

    filtered_goals <- reactive({
      result <- goals
      if (!identical(state$competition, "All competitions")) {
        result <- result[Comp == state$competition]
      }
      if (!identical(state$venue, "All venues")) {
        result <- result[Venue == state$venue]
      }
      result
    })

    eligible_goals <- reactive({
      result <- filtered_goals()
      if (isTRUE(state$exclude_pen)) result <- result[Penalty == FALSE]
      result
    })

    scored_goals <- reactive({
      eligible_goals()[!is.na(Difficulty_Score)]
    })

    selected_metrics <- reactive({
      appearance_base <- data.table::data.table(Player = P_ORDER)
      appearances <- filtered_matches()[, .(
        Appearances = .N,
        Minutes = sum(Minutes)
      ), by = Player]
      result <- merge(
        appearance_base,
        appearances,
        by = "Player",
        all.x = TRUE,
        sort = FALSE
      )
      result[is.na(Appearances), `:=`(Appearances = 0L, Minutes = 0)]

      weighted <- scored_goals()[, .(
        Weighted = sum(signed_difficulty_power(Difficulty_Score, state$K)),
        Weighted_Goals = .N
      ), by = Player]
      result <- merge(result, weighted, by = "Player", all.x = TRUE, sort = FALSE)
      result[is.na(Weighted), `:=`(Weighted = 0, Weighted_Goals = 0L)]
      result[, Weighted_per90 := data.table::fifelse(
        Appearances > 0L & Minutes > 0,
        90 * Weighted / Minutes,
        NA_real_
      )]
      result[match(P_ORDER, Player)]
    })

    output$context_badges <- shiny::bindCache(renderUI({
      div(
        class = "h2h-context",
        span(sprintf("K = %.1f", state$K), class = "h2h-context__badge"),
        span(
          if (isTRUE(state$exclude_pen)) "Penalties excluded" else "Penalties included",
          class = paste(
            "h2h-context__badge",
            if (isTRUE(state$exclude_pen)) "h2h-context__badge--muted" else NULL
          )
        ),
        span(
          h2h_scope_text(state$competition, state$venue),
          class = "h2h-context__badge h2h-context__badge--scope"
        )
      )
    }), state$K, state$exclude_pen, state$competition, state$venue)

    output$scope_notice <- shiny::bindCache(renderUI({
      represented <- unique(filtered_matches()$Player)
      if (length(represented) == 2L) return(NULL)

      message <- if (!length(represented)) {
        "No valid appearances exist in this competition and venue scope."
      } else {
        missing_player <- setdiff(P_ORDER, represented)
        sprintf(
          "%s has no valid appearances in this scope; their rate and the player gap are shown as N/A.",
          missing_player
        )
      }
      div(message, class = "h2h-scope-notice", role = "status")
    }), state$competition, state$venue)

    output$headline_cards <- shiny::bindCache(renderUI({
      metrics <- selected_metrics()
      messi <- metrics[Player == "Messi"]
      ronaldo <- metrics[Player == "Ronaldo"]
      gap <- if (is.finite(messi$Weighted_per90) && is.finite(ronaldo$Weighted_per90)) {
        messi$Weighted_per90 - ronaldo$Weighted_per90
      } else {
        NA_real_
      }
      eligible_n <- nrow(eligible_goals())
      scored_n <- nrow(scored_goals())
      coverage <- if (eligible_n > 0L) scored_n / eligible_n else NA_real_
      format_rate <- function(value) {
        if (is.finite(value)) sprintf("%.4f", value) else "N/A"
      }

      div(
        class = "h2h-headlines",
        h2h_value_card(
          "Messi weighted index / 90",
          format_rate(messi$Weighted_per90),
          sprintf("%s appearances · %s minutes",
                  format(messi$Appearances, big.mark = ","),
                  format(messi$Minutes, big.mark = ",")),
          "h2h-value-card--messi"
        ),
        h2h_value_card(
          "Ronaldo weighted index / 90",
          format_rate(ronaldo$Weighted_per90),
          sprintf("%s appearances · %s minutes",
                  format(ronaldo$Appearances, big.mark = ","),
                  format(ronaldo$Minutes, big.mark = ",")),
          "h2h-value-card--ronaldo"
        ),
        h2h_value_card(
          "Messi − Ronaldo gap",
          if (is.finite(gap)) sprintf("%+.4f", gap) else "N/A",
          "weighted index units per 90",
          "h2h-value-card--gap"
        ),
        h2h_value_card(
          "Weighted-goal coverage",
          if (is.finite(coverage)) sprintf("%.1f%%", 100 * coverage) else "N/A",
          sprintf("%s of %s eligible goals carry a difficulty score",
                  format(scored_n, big.mark = ","),
                  format(eligible_n, big.mark = ",")),
          "h2h-value-card--coverage"
        )
      )
    }), state$K, state$exclude_pen, state$competition, state$venue)

    trajectory_data <- reactive({
      contributions <- scored_goals()[, .(
        Weighted = sum(signed_difficulty_power(Difficulty_Score, state$K)),
        Eligible_Goals = .N
      ), by = H2H_MATCH_KEYS]

      trajectory <- merge(
        filtered_matches(),
        contributions,
        by = H2H_MATCH_KEYS,
        all.x = TRUE,
        sort = FALSE
      )
      trajectory[is.na(Weighted), `:=`(Weighted = 0, Eligible_Goals = 0L)]
      data.table::setorder(
        trajectory,
        Player, Date, Comp, Round, Opp_clean
      )
      trajectory[, Appearance := seq_len(.N), by = Player]
      trajectory[, Birth_Date := H2H_BIRTH_DATES[Player]]
      trajectory[, Age := as.numeric(Date - Birth_Date) / 365.2425]
      trajectory[, `:=`(
        Cumulative = cumsum(Weighted),
        Rolling_Weighted = data.table::frollsum(
          Weighted, 30L, align = "right", fill = NA_real_
        ),
        Rolling_Minutes = data.table::frollsum(
          Minutes, 30L, align = "right", fill = NA_real_
        )
      ), by = Player]
      trajectory[, Rolling30 := 90 * Rolling_Weighted / Rolling_Minutes]
      trajectory
    })

    output$trajectory_plot <- shiny::bindCache(plotly::renderPlotly({
      trajectory <- trajectory_data()
      measure <- input$trajectory_measure %||% "cumulative"
      axis <- input$trajectory_axis %||% "age"
      value_col <- if (identical(measure, "rolling30")) "Rolling30" else "Cumulative"
      y_title <- if (identical(measure, "rolling30")) {
        "Rolling 30-appearance weighted index / 90"
      } else {
        "Cumulative weighted index"
      }

      plot_data <- trajectory[is.finite(get(value_col))]
      if (!nrow(plot_data)) {
        message <- if (!nrow(trajectory)) {
          "No appearances are available in this scope."
        } else {
          "At least 30 filtered appearances are needed for the rolling view."
        }
        return(h2h_plot_config(h2h_empty_plot(
          message,
          if (identical(axis, "age")) "Age" else "Calendar date",
          y_title
        )))
      }

      plot_data[, Plot_Value := get(value_col)]
      plot_data[, Plot_X := if (identical(axis, "age")) Age else Date]
      plot_data[, Hover := sprintf(
        paste0(
          "<b>%s</b><br>",
          "Date: %s<br>",
          "Age: %.2f<br>",
          "Opponent: %s<br>",
          "Competition: %s<br>",
          "Venue: %s<br>",
          "Filtered appearance: %d<br>",
          "%s: %.4f"
        ),
        Player,
        format(Date, "%Y-%m-%d"),
        Age,
        Opp_clean,
        Comp,
        Venue,
        Appearance,
        if (identical(measure, "rolling30")) {
          "Rolling weighted index / 90"
        } else {
          "Cumulative weighted index"
        },
        Plot_Value
      )]

      plot <- plotly::plot_ly()
      for (player in intersect(P_ORDER, unique(plot_data$Player))) {
        player_data <- plot_data[Player == player]
        plot <- plotly::add_trace(
          plot,
          data = player_data,
          x = ~Plot_X,
          y = ~Plot_Value,
          text = ~Hover,
          hoverinfo = "text",
          type = "scatter",
          mode = "lines",
          name = player,
          line = list(
            color = unname(P_COLOR[player]),
            width = 2.6,
            dash = if (player == "Ronaldo") "dash" else "solid"
          )
        )
      }

      shapes <- list()
      annotations <- list()
      if (identical(axis, "age")) {
        shapes <- list(list(
          type = "line",
          x0 = 30, x1 = 30, xref = "x",
          y0 = 0, y1 = 1, yref = "paper",
          line = list(color = "#8793A1", width = 1, dash = "dot")
        ))
        annotations <- list(list(
          x = 30, y = 0.03, xref = "x", yref = "paper",
          text = "Age 30", showarrow = FALSE,
          xanchor = "left", yanchor = "bottom",
          bgcolor = "rgba(255,255,255,.78)",
          borderpad = 2,
          font = list(color = "#657486", size = 11)
        ))
      }

      plot <- plotly::layout(
        plot,
        margin = list(l = 74, r = 24, b = 60, t = 24),
        hovermode = "closest",
        legend = list(orientation = "h", x = 0, y = 1.08),
        xaxis = list(
          title = if (identical(axis, "age")) "Age" else "Calendar date"
        ),
        yaxis = list(title = y_title, zeroline = TRUE, zerolinecolor = "#B4BDC7"),
        shapes = shapes,
        annotations = annotations
      )
      h2h_plot_config(plot)
    }),
    state$K,
    state$exclude_pen,
    state$competition,
    state$venue,
    input$trajectory_measure,
    input$trajectory_axis)

    output$trajectory_summary <- renderText({
      trajectory <- trajectory_data()
      measure <- input$trajectory_measure %||% "cumulative"
      summaries <- vapply(P_ORDER, function(player) {
        player_data <- trajectory[Player == player]
        if (!nrow(player_data)) {
          return(paste(player, "has no appearances in this scope."))
        }
        values <- if (identical(measure, "rolling30")) {
          player_data$Rolling30
        } else {
          player_data$Cumulative
        }
        values <- values[is.finite(values)]
        if (!length(values)) {
          return(paste(player, "has fewer than 30 appearances in this scope."))
        }
        sprintf(
          "%s ends at %.4f %s.",
          player,
          tail(values, 1),
          if (identical(measure, "rolling30")) {
            "weighted index units per 90 over the latest 30 filtered appearances"
          } else {
            "cumulative weighted index units"
          }
        )
      }, character(1))
      paste(summaries, collapse = " ")
    })

    scatter_data <- reactive({
      result <- scored_goals()[!is.na(Opponent_Elo)]
      result[, Contribution := signed_difficulty_power(Difficulty_Score, state$K)]
      result
    })

    loess_status <- reactive({
      scatter <- scatter_data()
      result <- data.table::data.table(Player = P_ORDER)
      counts <- scatter[, .(
        Goals = .N,
        Distinct_Elo = data.table::uniqueN(Opponent_Elo)
      ), by = Player]
      result <- merge(result, counts, by = "Player", all.x = TRUE, sort = FALSE)
      result[is.na(Goals), `:=`(Goals = 0L, Distinct_Elo = 0L)]
      result[, Show_Loess := Goals >= 10L & Distinct_Elo >= 5L]
      result[match(P_ORDER, Player)]
    })

    output$elo_scatter <- shiny::bindCache(plotly::renderPlotly({
      scatter <- scatter_data()
      if (!nrow(scatter)) {
        return(h2h_plot_config(h2h_empty_plot(
          "No eligible goals with difficulty and Elo values are available in this scope.",
          "Opponent Elo",
          sprintf("Selected-K contribution (K = %.1f)", state$K)
        )))
      }

      scatter[, Hover := sprintf(
        paste0(
          "<b>%s</b><br>",
          "Date: %s<br>",
          "Opponent: %s<br>",
          "Competition: %s<br>",
          "Venue: %s<br>",
          "Opponent Elo: %.0f<br>",
          "Base difficulty score: %.4f<br>",
          "Selected-K contribution: %.4f<br>",
          "Penalty: %s"
        ),
        Player,
        format(Date, "%Y-%m-%d"),
        Opp_clean,
        Comp,
        Venue,
        Opponent_Elo,
        Difficulty_Score,
        Contribution,
        ifelse(Penalty, "Yes", "No")
      )]

      plot <- plotly::plot_ly()
      represented <- intersect(P_ORDER, unique(scatter$Player))
      for (player in represented) {
        player_data <- scatter[Player == player]
        plot <- plotly::add_markers(
          plot,
          data = player_data,
          x = ~Opponent_Elo,
          y = ~Contribution,
          text = ~Hover,
          hoverinfo = "text",
          name = paste(player, "goals"),
          legendgroup = player,
          marker = list(
            color = unname(P_COLOR[player]),
            size = 6.5,
            opacity = 0.47,
            line = list(width = 0)
          )
        )
      }

      status <- loess_status()
      for (player in status[Show_Loess == TRUE, Player]) {
        player_data <- scatter[Player == player]
        model <- suppressWarnings(try(
          stats::loess(
            Contribution ~ Opponent_Elo,
            data = as.data.frame(player_data),
            span = 0.75,
            degree = 2,
            na.action = stats::na.exclude,
            control = stats::loess.control(surface = "direct")
          ),
          silent = TRUE
        ))
        if (inherits(model, "try-error")) next

        grid <- data.table::data.table(
          Opponent_Elo = seq(
            min(player_data$Opponent_Elo),
            max(player_data$Opponent_Elo),
            length.out = 120L
          )
        )
        grid[, Contribution := suppressWarnings(as.numeric(
          stats::predict(model, newdata = as.data.frame(grid))
        ))]
        grid <- grid[is.finite(Contribution)]
        if (nrow(grid) < 2L) next

        plot <- plotly::add_lines(
          plot,
          data = grid,
          x = ~Opponent_Elo,
          y = ~Contribution,
          name = paste(player, "LOESS"),
          legendgroup = player,
          line = list(
            color = unname(P_COLOR[player]),
            width = 3.2,
            dash = if (player == "Ronaldo") "dash" else "solid"
          ),
          hovertemplate = paste0(
            "<b>", player, " descriptive LOESS</b><br>",
            "Opponent Elo: %{x:.0f}<br>",
            "Smoothed contribution: %{y:.4f}<extra></extra>"
          )
        )
      }

      plot <- plotly::layout(
        plot,
        margin = list(l = 70, r = 22, b = 62, t = 22),
        hovermode = "closest",
        legend = list(orientation = "h", x = 0, y = 1.09),
        xaxis = list(title = "Opponent Elo · continuous, unbinned"),
        yaxis = list(
          title = sprintf("Selected-K contribution (K = %.1f)", state$K),
          zeroline = TRUE,
          zerolinecolor = "#9AA5B1"
        )
      )
      h2h_plot_config(plot)
    }), state$K, state$exclude_pen, state$competition, state$venue)

    output$elo_note <- renderText({
      status <- loess_status()
      shown <- status[Show_Loess == TRUE, Player]
      suppressed <- status[Show_Loess == FALSE, Player]
      base <- if (length(shown)) {
        paste(
          "Descriptive LOESS shown for",
          paste(shown, collapse = " and "),
          "without confidence bands."
        )
      } else {
        "No descriptive LOESS curve meets the current minimum."
      }
      if (length(suppressed)) {
        paste0(
          base,
          " Suppressed for ",
          paste(suppressed, collapse = " and "),
          " because fewer than 10 goals or 5 distinct Elo values remain."
        )
      } else {
        base
      }
    })

    output$elo_summary <- renderText({
      status <- loess_status()
      paste(
        sprintf(
          "Messi has %d eligible plotted goals across %d distinct Elo values.",
          status[Player == "Messi", Goals],
          status[Player == "Messi", Distinct_Elo]
        ),
        sprintf(
          "Ronaldo has %d eligible plotted goals across %d distinct Elo values.",
          status[Player == "Ronaldo", Goals],
          status[Player == "Ronaldo", Distinct_Elo]
        ),
        "Markers use actual unjittered values."
      )
    })

    penalty_data <- reactive({
      scope_goals <- filtered_goals()
      if (nrow(scope_goals)) {
        scope_goals[, Goal_Type := ifelse(Penalty, "Penalty", "Open play")]
        counts <- scope_goals[, .(Goals = .N), by = .(Player, Goal_Type)]
      } else {
        counts <- data.table::data.table(
          Player = character(),
          Goal_Type = character(),
          Goals = integer()
        )
      }

      complete <- data.table::CJ(
        Player = P_ORDER,
        Goal_Type = c("Open play", "Penalty"),
        unique = TRUE
      )
      result <- merge(
        complete,
        counts,
        by = c("Player", "Goal_Type"),
        all.x = TRUE,
        sort = FALSE
      )
      result[is.na(Goals), Goals := 0L]
      result[, Total := sum(Goals), by = Player]
      result[, Share := data.table::fifelse(Total > 0L, Goals / Total, 0)]
      result[, Goal_Type := factor(
        Goal_Type,
        levels = c("Open play", "Penalty")
      )]
      result[, Player_Order := match(Player, P_ORDER)]
      data.table::setorder(result, Player_Order, Goal_Type)
      result[, Player_Order := NULL]
      result
    })

    output$penalty_chart <- shiny::bindCache(plotly::renderPlotly({
      composition <- penalty_data()
      plot <- plotly::plot_ly()

      for (goal_type in c("Open play", "Penalty")) {
        segment <- composition[Goal_Type == goal_type]
        excluded_segment <- identical(goal_type, "Penalty") &&
          isTRUE(state$exclude_pen)
        segment[, Label := ifelse(
          Goals > 0L,
          if (excluded_segment) {
            sprintf("%d · %.1f%%<br>excluded", Goals, 100 * Share)
          } else {
            sprintf("%d · %.1f%%", Goals, 100 * Share)
          },
          ""
        )]
        segment[, Hover := sprintf(
          paste0(
            "<b>%s · %s</b><br>",
            "Goals: %d<br>",
            "Share of player's goals: %.1f%%<br>",
            "Weighted calculations: %s"
          ),
          Player,
          as.character(Goal_Type),
          Goals,
          100 * Share,
          ifelse(
            Goal_Type == "Penalty" & isTRUE(state$exclude_pen),
            "excluded by the current toggle",
            "included when a difficulty score is available"
          )
        )]

        marker_colors <- if (identical(goal_type, "Open play")) {
          unname(P_COLOR[segment$Player])
        } else if (excluded_segment) {
          rep("#C9D0D8", nrow(segment))
        } else {
          unname(P_LIGHT[segment$Player])
        }

        plot <- plotly::add_bars(
          plot,
          data = segment,
          x = ~Player,
          y = ~Goals,
          text = ~Label,
          textposition = "inside",
          insidetextanchor = "middle",
          hovertext = ~Hover,
          hoverinfo = "text",
          name = if (excluded_segment) {
            "Penalty · excluded from weighting"
          } else {
            goal_type
          },
          marker = list(
            color = marker_colors,
            line = list(
              color = if (excluded_segment) "#8F99A5" else "#FFFFFF",
              width = if (excluded_segment) 1.2 else 0.6
            )
          )
        )
      }

      max_total <- max(composition$Total)
      plot <- plotly::layout(
        plot,
        barmode = "stack",
        margin = list(l = 58, r = 16, b = 52, t = 22),
        legend = list(orientation = "h", x = 0, y = 1.11),
        xaxis = list(title = "", categoryorder = "array", categoryarray = P_ORDER),
        yaxis = list(
          title = "Goals in selected scope",
          rangemode = "tozero",
          range = if (max_total == 0L) c(0, 1) else NULL
        ),
        uniformtext = list(minsize = 9, mode = "hide")
      )
      h2h_plot_config(plot)
    }), state$competition, state$venue, state$exclude_pen)

    output$penalty_note <- renderText({
      if (isTRUE(state$exclude_pen)) {
        "Penalty segments are muted and excluded from headline, trajectory, and Elo calculations; they remain visible here for disclosure."
      } else {
        "Both goal types are included in weighted calculations when a difficulty score is available."
      }
    })

    output$penalty_summary <- renderText({
      composition <- penalty_data()
      player_summary <- vapply(P_ORDER, function(player) {
        rows <- composition[Player == player]
        open <- rows[Goal_Type == "Open play"]
        penalty <- rows[Goal_Type == "Penalty"]
        sprintf(
          "%s has %d open-play goals, %.1f percent, and %d penalties, %.1f percent.",
          player,
          open$Goals,
          100 * open$Share,
          penalty$Goals,
          100 * penalty$Share
        )
      }, character(1))
      paste(player_summary, collapse = " ")
    })

    output$caveats <- shiny::bindCache(renderUI({
      metrics <- selected_metrics()
      scope_goals <- filtered_goals()
      eligible <- eligible_goals()
      missing_n <- eligible[is.na(Difficulty_Score), .N]
      represented <- metrics[Appearances > 0L, Player]

      tags$ul(
        class = "h2h-caveats",
        tags$li(
          tags$strong("Filtered denominators: "),
          sprintf(
            "%s valid appearances and %s minutes are retained in this scope, including scoreless appearances; penalty exclusion changes only goal contributions.",
            format(sum(metrics$Appearances), big.mark = ","),
            format(sum(metrics$Minutes), big.mark = ",")
          )
        ),
        tags$li(
          tags$strong("Difficulty coverage: "),
          sprintf(
            "%d of %d currently eligible goals lack a difficulty score. They remain in raw penalty counts but are excluded from weighted views.",
            missing_n,
            nrow(eligible)
          )
        ),
        tags$li(
          tags$strong("Centred index: "),
          sprintf(
            "selected-K contributions at K = %.1f can be negative. These are index units, not negative literal goals.",
            state$K
          )
        ),
        tags$li(
          tags$strong("Trajectory window: "),
          "cumulative totals and rolling windows restart inside the selected competition and venue scope; the first 29 filtered appearances have no rolling estimate."
        ),
        tags$li(
          tags$strong("Sparse scopes: "),
          if (length(represented) == 2L) {
            "both players have appearances here, but small goal or Elo samples can still suppress a smoother."
          } else if (length(represented) == 1L) {
            paste(setdiff(P_ORDER, represented), "has no valid appearances here, so comparative values are N/A.")
          } else {
            "neither player has a valid appearance here, so weighted rates are N/A."
          }
        ),
        tags$li(
          tags$strong("Descriptive smoothing only: "),
          "LOESS uses the actual unjittered goal values and is suppressed below 10 goals or 5 distinct Elo values. It is not an inferential model."
        ),
        tags$li(
          tags$strong("Where uncertainty lives: "),
          "This Head-to-Head page remains descriptive. For match-level bootstrap intervals, directional probability, and Cohen's d under the selected scope, open Inference and select Update analysis."
        )
      )
    }), state$K, state$exclude_pen, state$competition, state$venue)
  })
}
