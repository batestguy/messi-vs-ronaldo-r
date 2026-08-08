# Launch the Shiny app with app/ as the application directory.
# This is important: Shiny then serves app/www/ as static assets.

suppressPackageStartupMessages(library(shiny))

app_dir <- normalizePath("app", mustWork = TRUE)
shiny::runApp(
  appDir = app_dir,
  port = 3838,
  host = "127.0.0.1",
  launch.browser = FALSE
)
