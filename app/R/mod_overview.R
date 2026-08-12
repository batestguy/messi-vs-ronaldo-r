# app/R/mod_overview.R
# Wave 1: Overview tab — headline KPI cards + player identity and club journey.

# Static presentation metadata. Goal counts are deliberately not stored here:
# they are calculated from bundle$goals so the rail always describes the
# dashboard snapshot rather than an external/live career total.
CLUB_ERAS <- data.table::data.table(
  Player = c(rep("Messi", 3), rep("Ronaldo", 5)),
  Squad_clean = c(
    "Barcelona", "PSG", "Inter Miami",
    "Sporting CP", "Manchester Utd", "Real Madrid", "Juventus", "Al-Nassr"
  ),
  Club = c(
    "Barcelona", "Paris Saint-Germain", "Inter Miami",
    "Sporting CP", "Manchester United", "Real Madrid", "Juventus", "Al-Nassr"
  ),
  Years = c(
    "2004–2021", "2021–2023", "2023–present",
    "2002–2003", "2003–2009 · 2021–2022", "2009–2018", "2018–2021", "2023–present"
  ),
  Asset = c(
    "img/clubs/barcelona.svg", "img/clubs/psg.svg", "img/clubs/inter-miami.svg",
    "img/clubs/sporting-cp.svg", "img/clubs/manchester-united.svg",
    "img/clubs/real-madrid.svg", "img/clubs/juventus.svg", "img/clubs/al-nassr.svg"
  ),
  Current = c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE),
  Order = c(1L, 2L, 3L, 1L, 2L, 3L, 4L, 5L)
)

club_journey_ui <- function(clubs, player) {
  player_key <- tolower(player)

  div(
    class = "club-journey",
    div(
      class = "club-journey__header",
      tags$h3("Senior club journey"),
      span("dataset snapshot", class = "snapshot-badge")
    ),
    div(
      class = sprintf("club-rail club-rail--%d club-rail--%s", nrow(clubs), player_key),
      role = "list",
      `aria-label` = sprintf("%s senior club journey", player),
      lapply(seq_len(nrow(clubs)), function(i) {
        club <- clubs[i]
        tags$article(
          class = paste(
            "club-stop",
            if (isTRUE(club$Current)) "club-stop--current" else NULL
          ),
          role = "listitem",
          div(
            class = "club-stop__marker",
            div(
              class = "club-stop__crest",
              tags$img(
                src = club$Asset,
                alt = sprintf("%s crest", club$Club),
                width = 50,
                height = 50,
                loading = "lazy"
              )
            )
          ),
          div(class = "club-stop__name", club$Club),
          div(class = "club-stop__years", club$Years),
          div(
            class = "club-stop__goals",
            tags$strong(format(club$Goals, big.mark = ",", scientific = FALSE)),
            " goals in this dataset"
          ),
          if (isTRUE(club$Current)) {
            span("Current chapter", class = "current-chapter")
          }
        )
      })
    )
  )
}

mod_overview_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # --- Country + club journey profiles ---------------------------------
    fluidRow(
      class = "profile-grid",
      column(6,
        tags$section(
          class = "player-profile player-profile--messi",
          `aria-labelledby` = ns("messi_profile_name"),
          div(
            class = "player-identity",
            tags$img(
              src = "img/messi.jpg",
              alt = "Lionel Messi representing Argentina",
              width = 176,
              height = 176,
              class = "player-portrait player-portrait--messi"
            ),
            h2("Lionel Messi", id = ns("messi_profile_name"), class = "player-name"),
            p("Argentina national team", class = "player-country"),
            p("Dashboard coverage: 2004–2026", class = "player-coverage")
          ),
          uiOutput(ns("messi_clubs"))
        )
      ),
      column(6,
        tags$section(
          class = "player-profile player-profile--ronaldo",
          `aria-labelledby` = ns("ronaldo_profile_name"),
          div(
            class = "player-identity",
            tags$img(
              src = "img/ronaldo.jpg",
              alt = "Cristiano Ronaldo representing Portugal",
              width = 176,
              height = 176,
              class = "player-portrait player-portrait--ronaldo"
            ),
            h2("Cristiano Ronaldo", id = ns("ronaldo_profile_name"), class = "player-name"),
            p("Portugal national team", class = "player-country"),
            p("Dashboard coverage: 2002–2026", class = "player-coverage")
          ),
          uiOutput(ns("ronaldo_clubs"))
        )
      )
    ),

    tags$br(),

    # --- KPI cards (server-rendered) ---------------------------------------
    div(
      class = "overview-baseline",
      span(
        "Baseline: K=1 · penalties included",
        class = "overview-baseline__label"
      )
    ),
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

    club_eras <- reactive({
      eras <- data.table::copy(CLUB_ERAS)
      club_counts <- state$bundle$goals[, .(Goals = .N), by = .(Player, Squad_clean)]
      eras <- merge(
        eras,
        club_counts,
        by = c("Player", "Squad_clean"),
        all.x = TRUE,
        sort = FALSE
      )
      eras[is.na(Goals), Goals := 0L]
      data.table::setorder(eras, Player, Order)
      eras
    })

    output$messi_clubs <- renderUI({
      club_journey_ui(club_eras()[Player == "Messi"], "Messi")
    })

    output$ronaldo_clubs <- renderUI({
      club_journey_ui(club_eras()[Player == "Ronaldo"], "Ronaldo")
    })

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
