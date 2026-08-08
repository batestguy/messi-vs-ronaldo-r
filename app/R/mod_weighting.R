# app/R/mod_weighting.R
# Wave 2: Weighting tab (core methodology — difficulty index, K slider).
# Stub in Wave 0.

mod_weighting_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header = "Weighting / Difficulty",
    card(
      class = "text-muted p-3",
      "Wave 2 pending — K-slider sensitivity, difficulty density, Reality Check bars."
    )
  )
}

mod_weighting_server <- function(id, bundle, state) {
  moduleServer(id, function(input, output, session) {})
}