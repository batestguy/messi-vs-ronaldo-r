# app/R/mod_summary.R
# Wave 5: Summary (definitive head-to-head table, weighted & raw across dimensions).
# Stub in Wave 0.

mod_summary_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header = "Summary",
    card(
      class = "text-muted p-3",
      "Wave 5 pending — the final head-to-head table across all dimensions."
    )
  )
}

mod_summary_server <- function(id, bundle, state) {
  moduleServer(id, function(input, output, session) {})
}