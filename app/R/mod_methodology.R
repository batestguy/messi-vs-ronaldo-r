# app/R/mod_methodology.R
# Wave 5: an accessible, data-backed explanation of the complete analysis path.

METHODOLOGY_FAMD_GROUP_SIZES <- c(
  Venue = 3L,
  Competition_Stage = 5L,
  Is_Away = 2L
)

methodology_formula <- function(label, mathml, explanation) {
  tags$article(
    class = "method-formula",
    role = "note",
    `aria-label` = label,
    HTML(mathml),
    p(explanation)
  )
}

methodology_famd_contributions <- function(famd_info) {
  stopifnot(
    is.list(famd_info),
    nrow(famd_info$quanti_contrib) >= 1L,
    length(famd_info$quali_contrib) >= sum(METHODOLOGY_FAMD_GROUP_SIZES)
  )

  opponent <- as.numeric(famd_info$quanti_contrib[1L, 1L, with = FALSE][[1L]])
  # scripts/08 retained the qualitative contribution matrix column-wise as a
  # list. The first ten values are Dim 1: 3 Venue modalities, 5 Stage
  # modalities, and 2 Is_Away modalities. Summing modalities recovers the
  # variable-level contribution without running FAMD in the app.
  qualitative <- vapply(
    famd_info$quali_contrib,
    function(value) as.numeric(value[[1L]][1L]),
    numeric(1)
  )
  dim1 <- qualitative[seq_len(sum(METHODOLOGY_FAMD_GROUP_SIZES))]
  ends <- cumsum(METHODOLOGY_FAMD_GROUP_SIZES)
  starts <- c(1L, head(ends, -1L) + 1L)
  grouped <- vapply(
    seq_along(METHODOLOGY_FAMD_GROUP_SIZES),
    function(i) sum(dim1[starts[i]:ends[i]]),
    numeric(1)
  )

  data.table::data.table(
    Variable = c("Opponent_Elo", names(METHODOLOGY_FAMD_GROUP_SIZES)),
    Kind = c("Continuous", "Categorical", "Categorical", "Categorical"),
    Contribution = c(opponent, grouped),
    Role = c(
      "Time-specific opponent strength",
      "Home, away, or neutral context",
      "Group, knockout, final, qualifying, or other",
      "Explicit away-match indicator"
    )
  )
}

methodology_contribution_table <- function(rows) {
  tags$div(
    class = "method-table-wrap",
    tags$table(
      class = "method-table",
      tags$caption("Contribution to the stored global FAMD Dimension 1"),
      tags$thead(tags$tr(
        tags$th(scope = "col", "Input"),
        tags$th(scope = "col", "Kind"),
        tags$th(scope = "col", "Dim 1 contribution"),
        tags$th(scope = "col", "Role")
      )),
      tags$tbody(lapply(seq_len(nrow(rows)), function(i) {
        row <- rows[i]
        tags$tr(
          tags$th(scope = "row", row$Variable),
          tags$td(row$Kind),
          tags$td(sprintf("%.1f%%", row$Contribution)),
          tags$td(row$Role)
        )
      }))
    )
  )
}

mod_methodology_ui <- function(id) {
  ns <- NS(id)

  tags$article(
    class = "methodology-page",
    `aria-labelledby` = ns("methodology_title"),
    div(
      class = "methodology-hero",
      p("FROM SOURCE ROWS TO UNCERTAINTY", class = "methodology-hero__eyebrow"),
      h1("Methodology", id = ns("methodology_title")),
      p(
        "A transparent account of what is measured, how context becomes an index, and where interpretation must stop.",
        class = "methodology-hero__lede"
      ),
      uiOutput(ns("audit_strip"))
    ),

    tags$nav(
      class = "methodology-map",
      `aria-label` = "Methodology steps",
      tags$ol(
        tags$li(tags$a(href = paste0("#", ns("method_data")), "1", span("Collect and clean"))),
        tags$li(tags$a(href = paste0("#", ns("method_famd")), "2", span("Build one index"))),
        tags$li(tags$a(href = paste0("#", ns("method_weight")), "3", span("Weight and normalize"))),
        tags$li(tags$a(href = paste0("#", ns("method_boot")), "4", span("Resample matches"))),
        tags$li(tags$a(href = paste0("#", ns("method_limits")), "5", span("State the limits")))
      )
    ),

    tags$section(
      class = "method-section",
      `aria-labelledby` = ns("method_data"),
      div(class = "method-section__number", "01"),
      div(
        class = "method-section__content",
        h2("Collect every goal, retain every valid appearance", id = ns("method_data")),
        p(
          "FBref goal logs supply the one-row-per-goal master table, while match logs supply the exposure population. ClubElo and World Football Elo describe opponent strength; Understat adds partial shot-level xG coverage; Transfermarkt supports career metadata. All collection is cached and rate-limited."
        ),
        uiOutput(ns("data_flow")),
        div(
          class = "method-note method-note--gold",
          tags$strong("Denominator rule"),
          p("A scoreless appearance still consumed playing time. It therefore contributes zero to the numerator and remains in the per-90 denominator.")
        )
      )
    ),

    tags$section(
      class = "method-section",
      `aria-labelledby` = ns("method_famd"),
      div(class = "method-section__number", "02"),
      div(
        class = "method-section__content",
        h2("Fit one global FAMD", id = ns("method_famd")),
        p(
          "Factor Analysis of Mixed Data handles the continuous Elo input and categorical match context together. The model is fitted once to both players' valid appearances, so every score uses the same coordinate system. Player identity, goal count, and the player's own team Elo are excluded."
        ),
        uiOutput(ns("famd_summary")),
        methodology_formula(
          "Difficulty for appearance i equals its oriented and standardized global FAMD Dimension 1 score.",
          paste0(
            '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">',
            '<mrow><msub><mi>D</mi><mi>i</mi></msub><mo>=</mo>',
            '<mtext>standardized global FAMD Dim 1 score</mtext></mrow></math>'
          ),
          "The axis is oriented so higher values are intended to represent harder context; zero is the centre of an index, not 'no difficulty'."
        ),
        div(
          class = "method-note method-note--red",
          tags$strong("Interpret the index honestly"),
          p("Venue and Is_Away overlap conceptually and dominate this first dimension. Opponent Elo contributes comparatively little, so Dim 1 is not a pure opponent-strength scale.")
        )
      )
    ),

    tags$section(
      class = "method-section",
      `aria-labelledby` = ns("method_weight"),
      div(class = "method-section__number", "03"),
      div(
        class = "method-section__content",
        h2("Apply signed power, then divide by all valid minutes", id = ns("method_weight")),
        div(
          class = "method-formula-grid",
          methodology_formula(
            "Weighted contribution at K equals sign of D i times absolute D i raised to K.",
            paste0(
              '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">',
              '<mrow><msub><mi>WG</mi><mi>i</mi></msub><mo>(</mo><mi>K</mi><mo>)</mo><mo>=</mo>',
              '<mi mathvariant="normal">sign</mi><mo>(</mo><msub><mi>D</mi><mi>i</mi></msub><mo>)</mo>',
              '<mo>×</mo><msup><mrow><mo>|</mo><msub><mi>D</mi><mi>i</mi></msub><mo>|</mo></mrow><mi>K</mi></msup>',
              '</mrow></math>'
            ),
            "Signed power keeps negative centred scores finite at fractional K. K = 1 preserves the stored base index."
          ),
          methodology_formula(
            "Player weighted index per 90 equals 90 times summed eligible contributions divided by summed valid appearance minutes.",
            paste0(
              '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">',
              '<mrow><msub><mi>W</mi><mn>90</mn></msub><mo>=</mo><mn>90</mn><mo>×</mo>',
              '<mfrac><mrow><mo>∑</mo><msub><mi>WG</mi><mi>i</mi></msub><mo>(</mo><mi>K</mi><mo>)</mo></mrow>',
              '<mrow><mo>∑</mo><msub><mi>minutes</mi><mi>j</mi></msub></mrow></mfrac>',
              '</mrow></math>'
            ),
            "Raw per 90 uses the same denominator and replaces the weighted numerator with the number of eligible goals."
          )
        ),
        tags$ul(
          class = "method-rules",
          tags$li("Penalty exclusion removes penalty goals from weighted and raw numerators only."),
          tags$li("A goal with missing difficulty remains a raw goal but adds nothing to the weighted numerator."),
          tags$li("Competition and venue scope both goal numerators and valid-appearance denominators."),
          tags$li("Weighted values are centred index units, not literal fractional goals.")
        )
      )
    ),

    tags$section(
      class = "method-section",
      `aria-labelledby` = ns("method_boot"),
      div(class = "method-section__number", "04"),
      div(
        class = "method-section__content",
        h2("Resample whole appearances to describe uncertainty", id = ns("method_boot")),
        p(
          "Inference freezes the four sidebar settings only when Update analysis is clicked. Messi and Ronaldo are then resampled independently within player, with replacement, preserving each player's selected-scope appearance count."
        ),
        div(
          class = "method-formula-grid",
          methodology_formula(
            "Bootstrap gap star equals Messi resampled ratio-of-sums rate minus Ronaldo resampled ratio-of-sums rate.",
            paste0(
              '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">',
              '<mrow><msup><mi>Δ</mi><mo>*</mo></msup><mo>=</mo>',
              '<msubsup><mi>W</mi><mn>90</mn><mtext>Messi*</mtext></msubsup><mo>−</mo>',
              '<msubsup><mi>W</mi><mn>90</mn><mtext>Ronaldo*</mtext></msubsup>',
              '</mrow></math>'
            ),
            "Ten thousand seeded replicates form the complete displayed distribution; the 2.5th and 97.5th percentiles form its interval."
          ),
          methodology_formula(
            "Cohen's d equals the difference in mean appearance rates divided by their pooled standard deviation.",
            paste0(
              '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">',
              '<mrow><mi>d</mi><mo>=</mo><mfrac>',
              '<mrow><msub><mover><mi>x</mi><mo>¯</mo></mover><mi>M</mi></msub><mo>−</mo>',
              '<msub><mover><mi>x</mi><mo>¯</mo></mover><mi>R</mi></msub></mrow>',
              '<msub><mi>s</mi><mtext>pooled</mtext></msub></mfrac></mrow></math>'
            ),
            "Cohen's d complements the primary ratio-of-sums gap; it does not redefine it."
          )
        ),
        div(
          class = "method-note method-note--teal",
          tags$strong("What the probability means"),
          p("P(gap > 0) is the share of seeded bootstrap gaps above zero. It is not a p-value and is not converted into a significant/not-significant badge.")
        )
      )
    ),

    tags$section(
      class = "method-section method-section--limits",
      `aria-labelledby` = ns("method_limits"),
      div(class = "method-section__number", "05"),
      div(
        class = "method-section__content",
        h2("Limits travel with every result", id = ns("method_limits")),
        tags$ul(
          class = "method-limit-grid",
          tags$li(tags$strong("Coverage snapshot"), span("The files end in 2026 and are not live official career totals.")),
          tags$li(tags$strong("Index scope"), span("One FAMD dimension compresses context and leaves most total variation outside the index.")),
          tags$li(tags$strong("Fallback Elo"), span("League-average and global values preserve rows but are less specific than historical direct ratings.")),
          tags$li(tags$strong("Partial xG"), span("Shot-level xG is descriptive enrichment and never enters the current weight.")),
          tags$li(tags$strong("Exploratory subgroups"), span("Era and competition-family comparisons do not isolate causal effects.")),
          tags$li(tags$strong("Conditional uncertainty"), span("The bootstrap describes sampling variation under the selected index and scope, not every plausible football model."))
        ),
        p(
          "Inspect the exact 29-field goal table in Raw Data, compare weighted and raw rates in Summary, and use Inference for the frozen uncertainty distribution.",
          class = "methodology-closing"
        )
      )
    )
  )
}

mod_methodology_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    bundle <- shiny::isolate(state$bundle)
    goals <- data.table::copy(bundle$goals)
    matches <- data.table::copy(bundle$valid_matches)
    contributions <- methodology_famd_contributions(bundle$famd_info)

    stopifnot(
      nrow(goals) == 1738L,
      nrow(matches) == 2201L,
      sum(matches$Minutes) == 181081,
      sum(matches$Gls == 0) == 1063L,
      sum(is.na(goals$Difficulty_Score)) == 3L,
      abs(sum(contributions$Contribution) - 100) < 1e-6
    )

    output$audit_strip <- renderUI({
      tags$dl(
        class = "method-audit-strip",
        tags$div(tags$dt("Goals"), tags$dd(format(nrow(goals), big.mark = ","))),
        tags$div(tags$dt("Valid appearances"), tags$dd(format(nrow(matches), big.mark = ","))),
        tags$div(tags$dt("Scoreless"), tags$dd(format(sum(matches$Gls == 0), big.mark = ","))),
        tags$div(tags$dt("Minutes"), tags$dd(format(sum(matches$Minutes), big.mark = ",")))
      )
    })

    output$data_flow <- renderUI({
      direct <- sum(matches$Elo_Source %in% c("club", "national"))
      direct_or_league <- sum(matches$Elo_Source %in% c("club", "national", "league_avg"))
      tags$div(
        class = "method-flow",
        tags$article(h3("Goal grain"), p(sprintf(
          "%s Messi goals and %s Ronaldo goals; all %s goal IDs are unique.",
          format(sum(goals$Player == "Messi"), big.mark = ","),
          format(sum(goals$Player == "Ronaldo"), big.mark = ","),
          format(nrow(goals), big.mark = ",")
        ))),
        tags$article(h3("Appearance grain"), p(sprintf(
          "%s scoreless appearances remain among %s valid rows and %s total minutes.",
          format(sum(matches$Gls == 0), big.mark = ","),
          format(nrow(matches), big.mark = ","),
          format(sum(matches$Minutes), big.mark = ",")
        ))),
        tags$article(h3("Context coverage"), p(sprintf(
          "Direct Elo covers %.1f%% of appearances; direct-or-league coverage reaches %.1f%% before the global 1500 fallback.",
          100 * direct / nrow(matches), 100 * direct_or_league / nrow(matches)
        ))),
        tags$article(h3("Known gaps"), p(sprintf(
          "%s goals have shot-level xG; %s goals lack a joined difficulty score and remain disclosed.",
          format(sum(!is.na(goals$xg)), big.mark = ","),
          format(sum(is.na(goals$Difficulty_Score)), big.mark = ",")
        )))
      )
    })

    output$famd_summary <- renderUI({
      div(
        class = "method-famd-grid",
        div(
          class = "method-famd-stat",
          span("DIMENSION 1", class = "method-famd-stat__label"),
          strong(sprintf("%.1f%%", bundle$famd_info$eig[1L, 2L, with = FALSE][[1L]])),
          p(sprintf("of variation across %s valid appearances", format(bundle$famd_info$n_individuals, big.mark = ",")))
        ),
        methodology_contribution_table(contributions)
      )
    })
  })
}
