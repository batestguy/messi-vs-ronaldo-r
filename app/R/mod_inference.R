# app/R/mod_inference.R
# Wave 4: Inference (match-level bootstrap, CI, Cohen's d, subgroups).
# Stub in Wave 0.

mod_inference_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header = "Inference / Uncertainty",
    card(
      class = "text-muted p-3",
      "Wave 4 pending — match-level bootstrap (10k resamples) of the weighted
      per-90 difference, density + CI, Cohen's d, subgroup comparison."
    )
  )
}

mod_inference_server <- function(id, bundle, state) {
  moduleServer(id, function(input, output, session) {})
}