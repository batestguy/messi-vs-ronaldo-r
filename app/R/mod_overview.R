# app/R/mod_overview.R
# Wave 1: Overview tab.
# Stub in Wave 0 — placeholder card; real implementation lands in Wave 1.

mod_overview_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header("Overview"),
    div(
      class = "text-muted p-3",
      "Wave 1 pending — this module will show the weighted-vs-raw verdict, KPI cards
      and the intro story for why weighted metrics beat raw tallies."
    )
  )
}

mod_overview_server <- function(id, bundle, state) {
  moduleServer(id, function(input, output, session) {})
}