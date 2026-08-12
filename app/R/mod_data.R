# app/R/mod_data.R
# Wave 5: exact source-table access through DT plus an unmodified CSV download.

mod_data_ui <- function(id) {
  ns <- NS(id)

  tags$section(
    class = "raw-data-page",
    `aria-labelledby` = ns("raw_data_title"),
    div(
      class = "raw-data-hero",
      div(
        p("SOURCE ROWS · NO DASHBOARD FILTERING", class = "raw-data-hero__eyebrow"),
        h1("Raw goal data", id = ns("raw_data_title")),
        p(
          "Inspect the exact goal-level master used by the analysis. Search, filter, sort, or download the original 29-field CSV.",
          class = "raw-data-hero__lede"
        )
      ),
      downloadButton(
        ns("download_master"),
        "Download exact CSV",
        class = "btn-primary raw-data-download"
      )
    ),
    uiOutput(ns("data_audit")),
    card(
      class = "raw-data-card",
      card_header(
        div(
          h2("goals_master_final.csv", id = ns("raw_table_title")),
          span("One row per goal · original source headers", class = "raw-data-card__unit")
        )
      ),
      card_body(
        div(
          class = "raw-data-table-region",
          role = "region",
          `aria-labelledby` = ns("raw_table_title"),
          tabindex = "0",
          DT::DTOutput(ns("master_table"))
        ),
        p(
          "The global K, penalty, competition, and venue controls do not filter this table. Dashboard-derived fields such as Era, Penalty, and Comp_Group are intentionally excluded.",
          class = "raw-data-note"
        )
      )
    ),
    card(
      class = "raw-data-reading-card",
      card_header(h2("Transparency notes")),
      card_body(tags$ul(
        tags$li("Player names retain their source representation: Lionel Messi and C. Ronaldo."),
        tags$li("Blank xG values reflect Understat's limited league and date coverage; xG is not used in the current weight."),
        tags$li("Elo_Source records whether opponent strength came from a direct rating or a documented fallback."),
        tags$li("Three 2026 World Cup goals lack match context and therefore have no Difficulty_Score; they are not removed."),
        tags$li("Weighted_Goal is the stored K = 1 contribution. Interactive selected-K values are calculated in memory and do not overwrite this file.")
      ))
    )
  )
}

mod_data_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    if (!requireNamespace("DT", quietly = TRUE)) {
      stop("The Raw Data tab requires the installed runtime package 'DT'.")
    }

    raw_goals <- data.table::copy(shiny::isolate(state$raw_goals))
    raw_path <- shiny::isolate(state$raw_goals_path)
    stopifnot(
      file.exists(raw_path),
      nrow(raw_goals) == 1738L,
      ncol(raw_goals) == 29L,
      !anyDuplicated(raw_goals$goal_id),
      sum(raw_goals$Player == "Lionel Messi") == 847L,
      sum(raw_goals$Player == "C. Ronaldo") == 891L
    )

    output$data_audit <- renderUI({
      dates <- as.Date(raw_goals$Date)
      tags$dl(
        class = "raw-data-audit",
        tags$div(tags$dt("Rows"), tags$dd(format(nrow(raw_goals), big.mark = ","))),
        tags$div(tags$dt("Fields"), tags$dd(ncol(raw_goals))),
        tags$div(tags$dt("Unique goal IDs"), tags$dd(format(data.table::uniqueN(raw_goals$goal_id), big.mark = ","))),
        tags$div(tags$dt("Date range"), tags$dd(sprintf("%s to %s", min(dates), max(dates))))
      )
    })

    output$master_table <- DT::renderDT({
      DT::datatable(
        as.data.frame(raw_goals),
        rownames = FALSE,
        filter = "top",
        escape = TRUE,
        class = "compact stripe hover",
        options = list(
          pageLength = 25,
          lengthMenu = list(c(10, 25, 50, 100), c("10", "25", "50", "100")),
          scrollX = TRUE,
          autoWidth = FALSE,
          searchHighlight = TRUE,
          deferRender = TRUE,
          language = list(
            search = "Search all fields:",
            info = "Showing _START_ to _END_ of _TOTAL_ goals"
          ),
          columnDefs = list(list(className = "dt-nowrap", targets = "_all"))
        )
      )
    }, server = TRUE)

    output$download_master <- downloadHandler(
      filename = function() "goals_master_final.csv",
      contentType = "text/csv",
      content = function(file) {
        copied <- file.copy(raw_path, file, overwrite = TRUE, copy.mode = TRUE)
        if (!isTRUE(copied)) stop("Could not prepare the source CSV download.")
      }
    )
  })
}
