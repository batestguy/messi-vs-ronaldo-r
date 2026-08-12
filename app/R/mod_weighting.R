# app/R/mod_weighting.R
# Wave 2: Weighting Lab — signed-power sensitivity and difficulty context.

WEIGHTING_K_GRID <- seq(0.5, 3, by = 0.1)

signed_difficulty_power <- function(score, k) {
  sign(score) * abs(score)^k
}

weighting_value_card <- function(label, value, detail, class = "") {
  tags$article(
    class = paste("weighting-value-card", class),
    div(label, class = "weighting-value-card__label"),
    div(value, class = "weighting-value-card__value"),
    div(detail, class = "weighting-value-card__detail")
  )
}

weighting_plot_config <- function(plot) {
  plotly::config(
    plot,
    displaylogo = FALSE,
    responsive = TRUE,
    modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d")
  )
}

mod_weighting_ui <- function(id) {
  ns <- NS(id)

  tags$section(
    class = "weighting-lab",
    `aria-labelledby` = ns("weighting_title"),
    div(
      class = "weighting-lab__header",
      div(
        p("DIFFICULTY SENSITIVITY", class = "weighting-lab__eyebrow"),
        h1("Weighting Lab", id = ns("weighting_title")),
        p(
          "Does the comparison remain stable when difficulty sensitivity changes?",
          class = "weighting-lab__lede"
        )
      ),
      uiOutput(ns("context_badges"))
    ),

    uiOutput(ns("headline_cards")),

    div(
      class = "weighting-grid weighting-grid--hero",
      card(
        class = "weighting-card weighting-card--hero",
        card_header(
          h2("K-sensitivity curve", id = ns("curve_title")),
          span("Weighted index units per 90", class = "weighting-card__unit")
        ),
        card_body(
          plotly::plotlyOutput(ns("sensitivity_curve"), height = "370px"),
          tags$p(
            textOutput(ns("curve_summary"), inline = TRUE),
            class = "visually-hidden",
            role = "note"
          )
        )
      ),
      card(
        class = "weighting-card weighting-guide",
        card_header(h2("How to read K", id = ns("guide_title"))),
        card_body(
          tags$ol(
            class = "k-guide",
            tags$li(
              span("K < 1", class = "k-guide__badge"),
              div(tags$strong("Compresses extremes"),
                  p("Easy and hard scores move closer together."))
            ),
            tags$li(
              span("K = 1", class = "k-guide__badge k-guide__badge--base"),
              div(tags$strong("Preserves the base index"),
                  p("The stored FAMD difficulty score is unchanged."))
            ),
            tags$li(
              span("K > 1", class = "k-guide__badge"),
              div(tags$strong("Amplifies extremes"),
                  p("The easiest and hardest contexts matter more."))
            )
          ),
          div(
            class = "weighting-guide__note",
            tags$strong("Why signed power?"),
            p(
              "Difficulty scores are centred around zero. Preserving the sign keeps fractional K values finite and retains the direction of every score."
            )
          )
        )
      )
    ),

    div(
      class = "weighting-grid weighting-grid--detail",
      card(
        class = "weighting-card",
        card_header(
          h2("Reality Check", id = ns("reality_title")),
          span("Raw rate vs selected-K index rate", class = "weighting-card__unit")
        ),
        card_body(
          plotly::plotlyOutput(ns("reality_check"), height = "320px"),
          p(
            "Weighted bars are index units, not literal goals. Compare players within a metric; do not compare the absolute height of raw and weighted bars.",
            class = "chart-note"
          ),
          tags$p(
            textOutput(ns("reality_summary"), inline = TRUE),
            class = "visually-hidden",
            role = "note"
          )
        )
      ),
      card(
        class = "weighting-card",
        card_header(
          h2("Base difficulty density", id = ns("density_title")),
          span("Original K = 1 score", class = "weighting-card__unit")
        ),
        card_body(
          plotly::plotlyOutput(ns("difficulty_density"), height = "320px"),
          p(
            "Each player's curve is normalized to area 1. Vertical markers show medians; the K slider does not reshape this base-score view.",
            class = "chart-note"
          ),
          tags$p(
            textOutput(ns("density_summary"), inline = TRUE),
            class = "visually-hidden",
            role = "note"
          )
        )
      )
    ),

    card(
      class = "weighting-card weighting-card--deciles",
      card_header(
        h2("Goal counts by global difficulty decile", id = ns("decile_title")),
        span("D1 easiest · D10 hardest", class = "weighting-card__unit")
      ),
      card_body(
        plotly::plotlyOutput(ns("difficulty_deciles"), height = "350px"),
        p(
          "Deciles are assigned once from the combined dataset before penalty filtering, so D1–D10 retain the same meaning when the toggle changes.",
          class = "chart-note"
        ),
        tags$p(
          textOutput(ns("decile_summary"), inline = TRUE),
          class = "visually-hidden",
          role = "note"
        )
      )
    ),

    card(
      class = "weighting-interpretation",
      card_header(h2("Interpretation and data caveats", id = ns("caveats_title"))),
      card_body(uiOutput(ns("caveats")))
    )
  )
}

mod_weighting_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    if (!requireNamespace("plotly", quietly = TRUE)) {
      stop("The Weighting Lab requires the installed runtime package 'plotly'.")
    }

    goals <- data.table::copy(shiny::isolate(state$bundle$goals))
    matches <- data.table::copy(shiny::isolate(state$bundle$valid_matches))

    stopifnot(
      nrow(goals) == 1738L,
      nrow(matches) == 2201L,
      sum(is.na(goals$Difficulty_Score)) == 3L,
      all(c("Player", "Difficulty_Score", "Penalty") %in% names(goals)),
      all(c("Player", "Minutes") %in% names(matches))
    )

    player_minutes <- matches[, .(Minutes = sum(Minutes)), by = Player]
    data.table::setkey(player_minutes, Player)

    # Fixed combined-dataset deciles are assigned before either penalty subset.
    scored_goals <- goals[!is.na(Difficulty_Score)]
    scored_goals[, Difficulty_Rank := rank(Difficulty_Score, ties.method = "first")]
    scored_goals[, Decile_Number := pmin(
      10L,
      floor((Difficulty_Rank - 1) * 10 / .N) + 1L
    )]
    scored_goals[, Difficulty_Decile := factor(
      paste0("D", Decile_Number),
      levels = paste0("D", 1:10)
    )]
    decile_ranges <- scored_goals[, .(
      Score_Min = min(Difficulty_Score),
      Score_Max = max(Difficulty_Score)
    ), by = .(Difficulty_Decile)]

    build_k_grid <- function(exclude_penalty) {
      eligible <- scored_goals
      if (exclude_penalty) eligible <- eligible[Penalty == FALSE]

      grid <- data.table::CJ(
        K = round(WEIGHTING_K_GRID, 1),
        Player = P_ORDER,
        unique = TRUE
      )
      grid[, Weighted_per90 := vapply(seq_len(.N), function(i) {
        player <- Player[i]
        score_sum <- sum(signed_difficulty_power(
          eligible[Player == player, Difficulty_Score],
          K[i]
        ))
        90 * score_sum / player_minutes[player, Minutes]
      }, numeric(1))]
      grid[, Exclude_Penalties := exclude_penalty]
      grid
    }

    # Exactly 26 grid points for each player and penalty scenario. Slider moves
    # only select one of these stored rows; no score power is recomputed.
    k_grid_all <- data.table::rbindlist(list(
      build_k_grid(FALSE),
      build_k_grid(TRUE)
    ))
    stopifnot(nrow(k_grid_all) == 26L * 2L * 2L)

    raw_rates <- function(exclude_penalty) {
      eligible <- goals
      if (exclude_penalty) eligible <- eligible[Penalty == FALSE]
      counts <- eligible[, .(Goals = .N), by = Player]
      result <- merge(counts, player_minutes, by = "Player", sort = FALSE)
      result[, Raw_per90 := 90 * Goals / Minutes]
      result
    }

    active_grid <- reactive({
      k_grid_all[Exclude_Penalties == isTRUE(state$exclude_pen)]
    })

    selected_metrics <- reactive({
      selected_k <- round(state$K, 1)
      weighted <- active_grid()[K == selected_k]
      raw <- raw_rates(isTRUE(state$exclude_pen))
      result <- merge(weighted, raw, by = "Player", sort = FALSE)
      result[match(P_ORDER, Player)]
    })

    stability <- reactive({
      wide <- data.table::dcast(
        active_grid(),
        K ~ Player,
        value.var = "Weighted_per90"
      )
      wide[, Gap := Messi - Ronaldo]
      adjacent <- which(
        wide$Gap[-nrow(wide)] == 0 |
          wide$Gap[-1L] == 0 |
          sign(wide$Gap[-nrow(wide)]) != sign(wide$Gap[-1L])
      )

      if (!length(adjacent)) {
        lead <- if (all(wide$Gap > 0)) "Messi" else "Ronaldo"
        return(list(
          stable = TRUE,
          label = "No lead change across K=0.5–3.0",
          detail = paste(lead, "leads at all 26 tested values."),
          intervals = character()
        ))
      }

      intervals <- unique(sprintf(
        "K=%.1f–%.1f",
        wide$K[adjacent],
        wide$K[adjacent + 1L]
      ))
      list(
        stable = FALSE,
        label = paste("Lead changes between", paste(intervals, collapse = ", ")),
        detail = "Treat the comparison as sensitive in the reported adjacent grid interval(s).",
        intervals = intervals
      )
    })

    output$context_badges <- shiny::bindCache(renderUI({
      div(
        class = "weighting-context",
        span(sprintf("K = %.1f", state$K), class = "weighting-context__badge"),
        span(
          if (isTRUE(state$exclude_pen)) "Penalties excluded" else "Penalties included",
          class = paste(
            "weighting-context__badge",
            if (isTRUE(state$exclude_pen)) "weighting-context__badge--pen-off" else NULL
          )
        )
      )
    }), state$K, state$exclude_pen)

    output$headline_cards <- shiny::bindCache(renderUI({
      metrics <- selected_metrics()
      messi <- metrics[Player == "Messi"]
      ronaldo <- metrics[Player == "Ronaldo"]
      gap <- messi$Weighted_per90 - ronaldo$Weighted_per90
      stable <- stability()

      div(
        class = "weighting-headlines",
        weighting_value_card(
          "Messi weighted / 90",
          sprintf("%.4f", messi$Weighted_per90),
          sprintf("at K = %.1f", state$K),
          "weighting-value-card--messi"
        ),
        weighting_value_card(
          "Ronaldo weighted / 90",
          sprintf("%.4f", ronaldo$Weighted_per90),
          sprintf("at K = %.1f", state$K),
          "weighting-value-card--ronaldo"
        ),
        weighting_value_card(
          "Messi − Ronaldo gap",
          sprintf("%+.4f", gap),
          "weighted index units per 90",
          "weighting-value-card--gap"
        ),
        weighting_value_card(
          "Stability status",
          stable$label,
          stable$detail,
          if (stable$stable) {
            "weighting-value-card--stable"
          } else {
            "weighting-value-card--sensitive"
          }
        )
      )
    }), state$K, state$exclude_pen)

    output$sensitivity_curve <- shiny::bindCache(plotly::renderPlotly({
      curve <- active_grid()
      selected <- curve[K == round(state$K, 1)]
      endpoint <- curve[K == max(K)]

      plot <- plotly::plot_ly()
      for (player in P_ORDER) {
        player_curve <- curve[Player == player]
        plot <- plotly::add_lines(
          plot,
          data = player_curve,
          x = ~K,
          y = ~Weighted_per90,
          name = player,
          line = list(
            color = unname(P_COLOR[player]),
            width = 3,
            dash = if (player == "Ronaldo") "dash" else "solid"
          ),
          hovertemplate = paste0(
            "<b>", player, "</b><br>",
            "K: %{x:.1f}<br>",
            "Weighted index / 90: %{y:.4f}<extra></extra>"
          )
        )
      }
      plot <- plotly::add_segments(
        plot,
        x = min(WEIGHTING_K_GRID),
        xend = 3.12,
        y = 0,
        yend = 0,
        line = list(color = "#8793A1", width = 1, dash = "dot"),
        hoverinfo = "skip",
        showlegend = FALSE
      )
      for (player in P_ORDER) {
        marker <- selected[Player == player]
        plot <- plotly::add_markers(
          plot,
          data = marker,
          x = ~K,
          y = ~Weighted_per90,
          marker = list(
            color = unname(P_COLOR[player]),
            size = 11,
            line = list(color = "#FFFFFF", width = 2)
          ),
          hovertemplate = paste0(
            "<b>Selected · ", player, "</b><br>",
            "K: %{x:.1f}<br>",
            "Weighted index / 90: %{y:.4f}<extra></extra>"
          ),
          showlegend = FALSE
        )
      }
      annotations <- lapply(P_ORDER, function(player) {
        row <- endpoint[Player == player]
        list(
          x = 3.04,
          y = row$Weighted_per90,
          text = paste0("<b>", player, "</b>"),
          showarrow = FALSE,
          xanchor = "left",
          font = list(color = unname(P_COLOR[player]), size = 12)
        )
      })
      plot <- plotly::layout(
        plot,
        margin = list(l = 68, r = 84, b = 60, t = 20),
        hovermode = "x unified",
        legend = list(orientation = "h", x = 0, y = 1.08),
        xaxis = list(
          title = "Difficulty exponent (K)",
          range = c(0.5, 3.17),
          tickmode = "array",
          tickvals = c(0.5, 1, 1.5, 2, 2.5, 3)
        ),
        yaxis = list(title = "Weighted index units per 90", zeroline = FALSE),
        annotations = annotations
      )
      weighting_plot_config(plot)
    }), state$K, state$exclude_pen)

    output$curve_summary <- renderText({
      metrics <- selected_metrics()
      stable <- stability()
      sprintf(
        "At K %.1f, Messi is %.4f and Ronaldo is %.4f weighted index units per 90. %s",
        state$K,
        metrics[Player == "Messi", Weighted_per90],
        metrics[Player == "Ronaldo", Weighted_per90],
        stable$label
      )
    })

    output$reality_check <- shiny::bindCache(plotly::renderPlotly({
      metrics <- selected_metrics()
      long <- data.table::rbindlist(list(
        metrics[, .(
          Player,
          Metric = "Raw goals / 90",
          Value = Raw_per90,
          Unit = "goals per 90"
        )],
        metrics[, .(
          Player,
          Metric = sprintf("Weighted index / 90 (K=%.1f)", state$K),
          Value = Weighted_per90,
          Unit = "index units per 90"
        )]
      ))
      long[, Metric := factor(
        Metric,
        levels = c("Raw goals / 90", sprintf("Weighted index / 90 (K=%.1f)", state$K))
      )]

      plot <- plotly::plot_ly()
      for (player in P_ORDER) {
        player_data <- long[Player == player]
        plot <- plotly::add_bars(
          plot,
          data = player_data,
          x = ~Metric,
          y = ~Value,
          name = player,
          marker = list(color = unname(P_COLOR[player])),
          customdata = ~Unit,
          hovertemplate = paste0(
            "<b>", player, "</b><br>",
            "%{x}<br>",
            "%{y:.4f} %{customdata}<extra></extra>"
          )
        )
      }
      plot <- plotly::layout(
        plot,
        barmode = "group",
        margin = list(l = 62, r = 20, b = 78, t = 18),
        legend = list(orientation = "h", x = 0, y = 1.08),
        xaxis = list(title = ""),
        yaxis = list(title = "Rate per 90", zeroline = TRUE, zerolinecolor = "#8793A1")
      )
      weighting_plot_config(plot)
    }), state$K, state$exclude_pen)

    output$reality_summary <- renderText({
      metrics <- selected_metrics()
      paste(
        sprintf(
          "Messi: %.4f raw goals per 90 and %.4f weighted index units per 90.",
          metrics[Player == "Messi", Raw_per90],
          metrics[Player == "Messi", Weighted_per90]
        ),
        sprintf(
          "Ronaldo: %.4f raw goals per 90 and %.4f weighted index units per 90.",
          metrics[Player == "Ronaldo", Raw_per90],
          metrics[Player == "Ronaldo", Weighted_per90]
        )
      )
    })

    density_data <- reactive({
      eligible <- scored_goals
      if (isTRUE(state$exclude_pen)) eligible <- eligible[Penalty == FALSE]
      score_range <- range(scored_goals$Difficulty_Score)
      curves <- lapply(P_ORDER, function(player) {
        scores <- eligible[Player == player, Difficulty_Score]
        density <- stats::density(
          scores,
          from = score_range[1],
          to = score_range[2],
          n = 256
        )
        data.table::data.table(
          Player = player,
          Difficulty_Score = density$x,
          Density = density$y,
          Median = stats::median(scores)
        )
      })
      data.table::rbindlist(curves)
    })

    output$difficulty_density <- shiny::bindCache(plotly::renderPlotly({
      curves <- density_data()
      plot <- plotly::plot_ly()
      for (player in P_ORDER) {
        player_curve <- curves[Player == player]
        plot <- plotly::add_lines(
          plot,
          data = player_curve,
          x = ~Difficulty_Score,
          y = ~Density,
          name = player,
          line = list(color = unname(P_COLOR[player]), width = 2.5),
          fill = "tozeroy",
          fillcolor = if (player == "Messi") "rgba(20,68,125,.18)" else "rgba(166,30,44,.16)",
          hovertemplate = paste0(
            "<b>", player, "</b><br>",
            "Base score: %{x:.3f}<br>",
            "Normalized density: %{y:.3f}<extra></extra>"
          )
        )
        median_value <- unique(player_curve$Median)
        plot <- plotly::add_segments(
          plot,
          x = median_value,
          xend = median_value,
          y = 0,
          yend = max(player_curve$Density),
          line = list(color = unname(P_COLOR[player]), width = 1.5, dash = "dot"),
          hoverinfo = "skip",
          showlegend = FALSE
        )
      }
      plot <- plotly::layout(
        plot,
        margin = list(l = 60, r = 20, b = 58, t = 18),
        legend = list(orientation = "h", x = 0, y = 1.08),
        xaxis = list(title = "Base difficulty score (K = 1)"),
        yaxis = list(title = "Normalized density", rangemode = "tozero")
      )
      weighting_plot_config(plot)
    }), state$exclude_pen)

    output$density_summary <- renderText({
      curves <- density_data()
      medians <- unique(curves[, .(Player, Median)])
      sprintf(
        "Base difficulty medians are %.3f for Messi and %.3f for Ronaldo. Curves are normalized within player.",
        medians[Player == "Messi", Median],
        medians[Player == "Ronaldo", Median]
      )
    })

    decile_data <- reactive({
      eligible <- scored_goals
      if (isTRUE(state$exclude_pen)) eligible <- eligible[Penalty == FALSE]
      counts <- eligible[, .(Count = .N), by = .(Player, Difficulty_Decile)]
      complete <- data.table::CJ(
        Player = P_ORDER,
        Difficulty_Decile = factor(paste0("D", 1:10), levels = paste0("D", 1:10)),
        unique = TRUE
      )
      result <- merge(
        complete,
        counts,
        by = c("Player", "Difficulty_Decile"),
        all.x = TRUE,
        sort = FALSE
      )
      result[is.na(Count), Count := 0L]
      result <- merge(result, decile_ranges, by = "Difficulty_Decile", sort = FALSE)
      result[, Player_Share := Count / sum(Count), by = Player]
      result[, Score_Range := sprintf("%.3f to %.3f", Score_Min, Score_Max)]
      result[, Share_Label := sprintf("%.1f%%", 100 * Player_Share)]
      result[, Player_Order := match(Player, P_ORDER)]
      data.table::setorder(result, Player_Order, Difficulty_Decile)
      result[, Player_Order := NULL]
      result
    })

    output$difficulty_deciles <- shiny::bindCache(plotly::renderPlotly({
      deciles <- decile_data()
      plot <- plotly::plot_ly()
      for (player in P_ORDER) {
        player_data <- deciles[Player == player]
        player_data[, Hover := sprintf(
          paste0(
            "<b>%s · %s</b><br>",
            "Base score range: %s<br>",
            "Goals: %d<br>",
            "Share of player's eligible goals: %s"
          ),
          player,
          as.character(Difficulty_Decile),
          Score_Range,
          Count,
          Share_Label
        )]
        plot <- plotly::add_bars(
          plot,
          data = player_data,
          x = ~Difficulty_Decile,
          y = ~Count,
          name = player,
          marker = list(color = unname(P_COLOR[player])),
          text = ~Hover,
          hoverinfo = "text"
        )
      }

      plot <- plotly::layout(
        plot,
        barmode = "group",
        margin = list(l = 62, r = 20, b = 60, t = 18),
        legend = list(orientation = "h", x = 0, y = 1.08),
        xaxis = list(title = "Global difficulty decile"),
        yaxis = list(title = "Eligible goals", rangemode = "tozero")
      )
      weighting_plot_config(plot)
    }), state$exclude_pen)

    output$decile_summary <- renderText({
      deciles <- decile_data()
      sprintf(
        "In the hardest global decile, Messi has %d eligible goals and Ronaldo has %d. Decile boundaries are fixed before penalty filtering.",
        deciles[Player == "Messi" & Difficulty_Decile == "D10", Count],
        deciles[Player == "Ronaldo" & Difficulty_Decile == "D10", Count]
      )
    })

    output$caveats <- shiny::bindCache(renderUI({
      raw <- raw_rates(isTRUE(state$exclude_pen))
      eligible <- goals
      if (isTRUE(state$exclude_pen)) eligible <- eligible[Penalty == FALSE]
      weighted_n <- eligible[!is.na(Difficulty_Score), .N]
      missing_n <- eligible[is.na(Difficulty_Score), .N]

      tagList(
        tags$ul(
          class = "weighting-caveats",
          tags$li(
            tags$strong("What stability means: "),
            "the identity of the higher weighted-per-90 rate is checked at all 26 K values. It is a sensitivity result, not a final verdict."
          ),
          tags$li(
            tags$strong("Denominators stay complete: "),
            sprintf(
              "%s valid appearance minutes are retained, including 1,063 scoreless appearances.",
              format(sum(matches$Minutes), big.mark = ",")
            )
          ),
          tags$li(
            tags$strong("Penalty toggle: "),
            "changes goal numerators only; it never removes appearance minutes."
          ),
          tags$li(
            tags$strong("Raw versus weighted coverage: "),
            sprintf(
              "raw rates count %d eligible goals; weighted views use %d goals with a difficulty score. %d eligible goal%s lack that score and are disclosed rather than imputed in this tab.",
              sum(raw$Goals), weighted_n, missing_n, if (missing_n == 1L) "" else "s"
            )
          ),
          tags$li(
            tags$strong("Negative values are valid: "),
            "the centred index can produce negative weighted rates at amplified K values; these are index outputs, not negative literal goals."
          )
        )
      )
    }), state$exclude_pen)
  })
}
