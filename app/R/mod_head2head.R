# app/R/mod_head2head.R
# Wave 3: Head-to-Head (trajectories, Elo scatter, penalties, filters).
# Stub in Wave 0.

mod_head2head_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header = "Head-to-Head",
    card(
      class = "text-muted p-3",
      "Wave 3 pending — cumulative weighted trajectories, opponent-Elo scatter,
      penalty vs open-play breakdown, era/competition filters."
    )
  )
}

mod_head2head_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {})
}