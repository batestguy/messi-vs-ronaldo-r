# app/R/mod_overview.R
# Wave 1: Overview tab — headline KPI cards + intro text + player photos.

mod_overview_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # --- Player photos row ------------------------------------------------
    fluidRow(
      column(6, class = "text-center",
        tags$img(src = "img/messi.jpg", height = "170px",
                 style = "border-radius:50%; object-fit:cover; width:170px; border:3px solid #14447D;"),
        h3("Lionel Messi", style = "color:#14447D; margin-top:10px;"),
        tags$small("Argentina  |  2004–2026")
      ),
      column(6, class = "text-center",
        tags$img(src = "img/ronaldo.jpg", height = "170px",
                 style = "border-radius:50%; object-fit:cover; width:170px; border:3px solid #A61E2C;"),
        h3("Cristiano Ronaldo", style = "color:#A61E2C; margin-top:10px;"),
        tags$small("Portugal  |  2002–2026")
      )
    ),

    tags$br(),

    # --- KPI cards (server-rendered) ---------------------------------------
    uiOutput(ns("kpi_cards")),

    tags$hr(),

    # --- Intro panels -----------------------------------------------------
    fluidRow(
      column(6,
        card(
          card_header(tags$b("The Weighted Case")),
          p("Raw goal totals treat a close-range tap-in against a relegated
            side identically to a Champions League final winner. Our
            difficulty index — derived from a single FAMD on both players'
            career match history — weights every goal by opponent quality,
            venue, and competition stage."),
          p(tags$b("Default metric: Weighted Goals per 90."),
            " Raw tallies appear only as a Reality Check throughout.",
            class = "small text-muted")
        )
      ),
      column(6,
        card(
          card_header(tags$b("What We Built")),
          tags$ul(
            tags$li("1,738 goals across 2,201 appearances (2002–2026)"),
            tags$li("Opponent Elo coverage: 90.6% (club + national + league)"),
            tags$li("Penalty split: Messi 106 vs Ronaldo 169"),
            tags$li("xG: 483 goals (Understat, top-5 leagues 2014+)"),
            tags$li("Bootstrap inference at the match level (10k resamples) —
                     no p-value ceremonies")
          ),
          p("See Methodology tab for data provenance and step-by-step
            walk-through.", class = "small text-muted")
        )
      )
    )
  )
}

# ---------------------------------------------------------------------------
mod_overview_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    output$kpi_cards <- renderUI({

      p90 <- state$bundle$per90[Era == "All" & PenaltyIncl == TRUE]

      m_wp90 <- p90[Player == "Messi", Weighted_per90]
      r_wp90 <- p90[Player == "Ronaldo", Weighted_per90]
      m_rp90 <- p90[Player == "Messi", Raw_per90]
      r_rp90 <- p90[Player == "Ronaldo", Raw_per90]
      m_goals <- state$bundle$meta$totals$goals_messi
      r_goals <- state$bundle$meta$totals$goals_ronaldo
      m_apps  <- p90[Player == "Messi", Apps]
      r_apps  <- p90[Player == "Ronaldo", Apps]

      build_kpi <- function(title, subtitle, mv, rv, higher = TRUE,
                            fmt = function(x) sprintf("%.4f", x)) {
        m_lead <- if (higher) mv >= rv else mv <= rv
        r_lead <- if (higher) rv >= mv else rv <= mv

        card(
          card_header(tags$h6(title, style = "text-align:center;")),
          card_body(
            div(style = "display:flex; justify-content:space-around; gap:.65rem; text-align:center;",
              div(
                div(fmt(mv),
                    style = paste0("font-size:1.3rem; font-weight:",
                                   if (m_lead) "800" else "400",
                                   "; color:", if (m_lead) "#14447D" else "#17202A")),
                tags$small("Messi")
              ),
              div(
                div(fmt(rv),
                    style = paste0("font-size:1.3rem; font-weight:",
                                   if (r_lead) "800" else "400",
                                   "; color:", if (r_lead) "#A61E2C" else "#17202A")),
                tags$small("Ronaldo")
              )
            ),
            tags$p(subtitle, class = "small text-muted text-center mt-2 mb-0")
          )
        )
      }

      layout_column_wrap(
        width = 1/4,
        build_kpi("Weighted Goals", "per 90 (difficulty-adjusted)",
                  m_wp90, r_wp90, TRUE, function(x) sprintf("%.4f", x)),
        build_kpi("Raw Goals", "per 90 (Reality Check)",
                  m_rp90, r_rp90, TRUE, function(x) sprintf("%.4f", x)),
        build_kpi("Total Goals", "career tally",
                  m_goals, r_goals, TRUE, function(x) sprintf("%d", x)),
        build_kpi("Appearances", "matches played",
                  m_apps, r_apps, TRUE, function(x) sprintf("%d", x))
      )
    })

  })
}
