# app/app.R — Messi vs Ronaldo: weighted-difficulty dashboard (Phase 2).
# Run locally:  Rscript app/run.R
# Then browse http://127.0.0.1:3838
#
# Runtime deps: shiny/bslib/plotly/DT/data.table — the whole app stack.
# No worldfootballR / FactoMineR at runtime: everything is precomputed in
#   data/processed/analysis_bundle.rds by scripts/08_prepare_analysis.R.

# Only what Wave 1 needs. plotly/DT are heavy and load lazily in the modules
# that use them (mod_weighting / mod_data) in later waves.
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(data.table)
})

# --- locate app dir regardless of CWD (run from repo root or from app/) ---
app_dir <- tryCatch(dirname(normalizePath(sys.frame(1)$ofile)), error = function(e) NULL)
if (is.null(app_dir) || !file.exists(file.path(app_dir, "app.R"))) {
  app_dir <- if (dir.exists("app")) "app" else "."
}
app_dir <- normalizePath(app_dir)

for (f in c("theme.R", "mod_overview.R", "mod_weighting.R", "mod_head2head.R",
            "mod_inference.R", "mod_methodology.R", "mod_summary.R", "mod_data.R"))
  source(file.path(app_dir, "R", f))

# ---------------------------------------------------------------------------
# Data bundle (precomputed)
# ---------------------------------------------------------------------------
bundle_path <- file.path(app_dir, "data", "analysis_bundle.rds")
if (!file.exists(bundle_path))
  stop("Missing app/data/analysis_bundle.rds — run scripts/08_prepare_analysis.R first.")
bundle <- readRDS(bundle_path)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- page_navbar(
  # Unicode glyph, not a Bootstrap Icons class: bsicons isn't installed and the
  # bi-* CSS is never loaded, so <i class="bi bi-trophy-fill"> rendered 0px wide.
  # A CDN link would fix it but breaks the offline container build.
  title = tags$span(tags$span("\U0001F3C6", style = "margin-right:8px;"),
                    "Messi vs Ronaldo — The Weighted Case"),
  theme = app_theme(),
  id = "main_tabs",
  header = tags$head(tags$link(rel = "stylesheet", href = "css.css")),
  sidebar = sidebar(
    open = TRUE,
    title = "Global controls",
    sliderInput("k_power", "Difficulty exponent (K)",
                min = 0.5, max = 3, value = 1, step = 0.1),
    # Signed power, not a plain exponent: about half the difficulty scores are
    # negative, and a negative base with a fractional K returns NaN.
    helpText("Weighted goal = sign(Difficulty_Score) × |Difficulty_Score| ^ K. ",
             "K = 1 is the base weighting."),
    checkboxInput("exclude_pen", "Exclude penalty goals", value = FALSE),
    actionButton("run_boot", "Update analysis", class = "btn-primary w-100"),
    hr(),
    p("Snapshot 2004–2026 · 1,738 goals · data: FBref, ClubElo, Understat",
      class = "small text-muted")
  ),
  nav_panel("Overview",  mod_overview_ui("tab_overview")),
  nav_panel("Weighting", mod_weighting_ui("tab_weighting")),
  nav_panel("Head-to-Head", mod_head2head_ui("tab_h2h")),
  nav_panel("Inference",    mod_inference_ui("tab_inference")),
  nav_panel("Methodology",  mod_methodology_ui("tab_methodology")),
  nav_panel("Summary",      mod_summary_ui("tab_summary")),
  nav_panel("Raw data",     mod_data_ui("tab_data")),
  footer = div(class = "small text-muted text-center py-3",
               "Weighted Goals = difficulty-adjusted scoring output (see Methodology tab).")
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {
  state <- reactiveValues(
    bundle = bundle,
    K = 1,
    exclude_pen = FALSE,
    boot_trigger = 0
  )
  observeEvent(input$k_power, state$K <- input$k_power)
  observeEvent(input$exclude_pen, state$exclude_pen <- input$exclude_pen)
  observeEvent(input$run_boot, state$boot_trigger <- state$boot_trigger + 1)

  mod_overview_server("tab_overview", state)
  mod_weighting_server("tab_weighting", state)
  mod_head2head_server("tab_h2h", state)
  mod_inference_server("tab_inference", state)
  mod_methodology_server("tab_methodology", state)
  mod_summary_server("tab_summary", state)
  mod_data_server("tab_data", state)
}

shinyApp(ui, server, options = list(port = 3838, host = "127.0.0.1", launch.browser = FALSE))
