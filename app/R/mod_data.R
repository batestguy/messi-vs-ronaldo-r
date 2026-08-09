# app/R/mod_data.R
# Wave 5: Raw data (DT table of the goal-level master).
# Stub in Wave 0.

mod_data_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header = "Raw data",
    card(
      class = "text-muted p-3",
      "Wave 5 pending — interactive table of all 1,738 goals with search/filter."
    )
  )
}

mod_data_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {})
}