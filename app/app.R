# app/app.R — Messi vs Ronaldo: weighted-difficulty dashboard (Phase 2).
# Run locally:  Rscript app/run.R
# Then browse http://127.0.0.1:3838
#
# Runtime deps: shiny/bslib/plotly/DT/data.table — the whole app stack.
# No worldfootballR / FactoMineR at runtime: everything is precomputed in
#   data/processed/analysis_bundle.rds by scripts/08_prepare_analysis.R.

# Plotly and DT stay out of the global search path; their modules load them lazily
# only when the corresponding tab needs them.
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
raw_goals_path <- file.path(app_dir, "data", "goals_master_final.csv")
if (!file.exists(raw_goals_path))
  stop("Missing app/data/goals_master_final.csv — run scripts/08_prepare_analysis.R first.")
raw_goals <- fread(
  raw_goals_path,
  colClasses = "character",
  na.strings = NULL,
  showProgress = FALSE
)
stopifnot(
  nrow(raw_goals) == 1738L,
  ncol(raw_goals) == 29L,
  !anyDuplicated(raw_goals$goal_id)
)
competition_choices <- c(
  "All competitions",
  sort(unique(bundle$valid_matches$Comp))
)
stopifnot(length(competition_choices) == 32L)

# Offline-safe native MathML. Shiny's withMathJax() loads MathJax from a CDN,
# which would break the app's offline/container-safe presentation. htmltools'
# tag catalogue does not include MathML constructors, so this trusted static
# markup is inserted directly rather than interpreted as text.
weight_formula_panel <- function() {
  div(
    class = "weight-formula",
    role = "note",
    `aria-label` = paste(
      "Weighted goal at K equals sign of Difficulty Score times the absolute",
      "value of Difficulty Score raised to K. At K equals one, weighted goal",
      "equals Difficulty Score."
    ),
    div("Signed-power weighting", class = "weight-formula__title"),
    HTML(paste0(
      '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block" ',
      'class="weight-formula__equation">',
      '<mtable columnalign="left" rowspacing="0.18em"><mtr><mtd><mrow>',
      '<msub><mi>WG</mi><mi>k</mi></msub><mo>=</mo>',
      '<mi mathvariant="normal">sign</mi><mo>(</mo>',
      '<msub><mi>Difficulty</mi><mi>Score</mi></msub><mo>)</mo>',
      '</mrow></mtd></mtr><mtr><mtd><mrow><mspace width="1.35em"/>',
      '<mo>×</mo>',
      '<msup><mrow><mo>|</mo><msub><mi>Difficulty</mi><mi>Score</mi></msub>',
      '<mo>|</mo></mrow><mi>K</mi></msup>',
      '</mrow></mtd></mtr></mtable></math>'
    )),
    HTML(paste0(
      '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block" ',
      'class="weight-formula__base">',
      '<mrow><mi>K</mi><mo>=</mo><mn>1</mn><mo>⇒</mo>',
      '<msub><mi>WG</mi><mn>1</mn></msub><mo>=</mo>',
      '<msub><mi>Difficulty</mi><mi>Score</mi></msub></mrow></math>'
    )),
    p(
      "K changes sensitivity to the stored difficulty score; K = 1 preserves the base index.",
      class = "weight-formula__help"
    )
  )
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- page_navbar(
  # Unicode glyph, not a Bootstrap Icons class: bsicons isn't installed and the
  # bi-* CSS is never loaded, so <i class="bi bi-trophy-fill"> rendered 0px wide.
  # A CDN link would fix it but breaks the offline container build.
  title = tags$span(
    tags$span(
      "\U0001F3C6",
      style = "margin-right:8px;",
      `aria-hidden` = "true"
    ),
    tags$span("Messi vs Ronaldo — The Weighted Case", translate = "no")
  ),
  theme = app_theme(),
  id = "main_tabs",
  # Version the static stylesheet so browsers cannot pair revised Overview
  # markup with an older cached layout (large intrinsic SVGs otherwise leak).
  header = tagList(
    tags$head(
      tags$meta(name = "theme-color", content = BRAND$bg),
      tags$link(
        rel = "icon",
        href = paste0(
          "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' ",
          "viewBox='0 0 100 100'%3E%3Ctext y='.9em' font-size='90'%3E",
          "%F0%9F%8F%86%3C/text%3E%3C/svg%3E"
        )
      ),
      tags$link(
        rel = "stylesheet",
        href = "css.css?v=20260815-review1"
      ),
      tags$script(src = "app.js?v=20260812-wave6", defer = NA)
    ),
    shiny::busyIndicatorOptions(
      spinner_type = "dots",
      spinner_color = BRAND$messi,
      spinner_size = "2rem",
      spinner_delay = "250ms",
      spinner_selector = ".shiny-bound-output",
      fade_opacity = 0.72,
      fade_selector = ".shiny-bound-output",
      pulse_background = paste0(
        "linear-gradient(90deg, ", BRAND$messi,
        ", #1C7C7D 50%, ", BRAND$ronaldo, ")"
      ),
      pulse_height = "3px",
      pulse_speed = "1.2s"
    )
  ),
  sidebar = sidebar(
    open = "desktop",
    title = "Analysis controls",
    sliderInput("k_power", "Difficulty exponent (K)",
                min = 0.5, max = 3, value = 1, step = 0.1),
    # Signed power, not a plain exponent: about half the difficulty scores are
    # negative, and a negative base with a fractional K returns NaN.
    weight_formula_panel(),
    checkboxInput("exclude_pen", "Exclude penalty goals", value = FALSE),
    selectInput(
      "competition_filter",
      "Competition",
      choices = competition_choices,
      selected = "All competitions"
    ),
    selectInput(
      "venue_filter",
      "Venue",
      choices = c("All venues", "Home", "Away", "Neutral"),
      selected = "All venues"
    ),
    p(
      "K and penalty settings update Weighting, Head-to-Head, and the live Summary. Competition and venue update Head-to-Head and the live Summary. Inference keeps its last clicked settings.",
      class = "small text-muted"
    ),
    actionButton("run_boot", "Update analysis", class = "btn-primary w-100"),
    p(
      "Runs or restores the 10,000-resample Inference analysis. Overview, Methodology, Summary, and Raw Data do not use this button.",
      class = "small text-muted"
    ),
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
  footer = tagList(
    div(
      id = "app-live-status",
      class = "visually-hidden",
      role = "status",
      `aria-live` = "polite",
      `aria-atomic` = "true"
    ),
    div(
      class = "small text-muted text-center py-3",
      "Weighted Goals = difficulty-adjusted scoring output (see Methodology tab)."
    )
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {
  state <- reactiveValues(
    bundle = bundle,
    raw_goals = raw_goals,
    raw_goals_path = raw_goals_path,
    K = 1,
    exclude_pen = FALSE,
    competition = "All competitions",
    venue = "All venues",
    boot_trigger = 0
  )
  observeEvent(input$k_power, state$K <- input$k_power)
  observeEvent(input$exclude_pen, state$exclude_pen <- input$exclude_pen)
  observeEvent(input$competition_filter, state$competition <- input$competition_filter)
  observeEvent(input$venue_filter, state$venue <- input$venue_filter)
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
