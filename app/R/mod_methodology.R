# app/R/mod_methodology.R
# Wave 5: Methodology (2-page scroll narrative: data, FAMD, weighting, bootstrap).
# Stub in Wave 0.

mod_methodology_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header = "Methodology",
    card(
      class = "text-muted p-3",
      "Wave 5 pending — data collection, FAMD construction, weighting, bootstrap,
      limitations and sources."
    )
  )
}

mod_methodology_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {})
}