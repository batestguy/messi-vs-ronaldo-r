# app/R/theme.R
# Global visual identity for the dashboard.
# Single source of truth for tokens, reused by every module (and later the blog).

suppressPackageStartupMessages({
  library(bslib)
  library(htmltools)
})

# ---------------------------------------------------------------------------
# Brand tokens
# ---------------------------------------------------------------------------
BRAND <- list(
  name       = "Messi vs Ronaldo — The Weighted Case",
  messi      = "#14447D",          # deep Argentina blue
  messi_light= "#5B8CC7",
  ronaldo    = "#A61E2C",          # deep Portugal red
  ronaldo_light = "#D05A66",
  neutral    = "#5C6B7A",
  bg         = "#F5F7FB",
  card       = "#FFFFFF",
  ink        = "#17202A",
  muted      = "#6B7A8D"
)

P_COLOR <- c(Messi = BRAND$messi, Ronaldo = BRAND$ronaldo)
P_LIGHT <- c(Messi = BRAND$messi_light, Ronaldo = BRAND$ronaldo_light)
P_ORDER <- c("Messi", "Ronaldo")

# ---------------------------------------------------------------------------
# bslib theme (no external font dependency — offline-safe, small images)
# ---------------------------------------------------------------------------
app_theme <- function() {
  bs_theme(
    version      = 5,
    bootswatch   = "flatly",
    primary      = BRAND$messi,
    secondary    = BRAND$ronaldo,
    navbar_bg    = "#ffffff",
    `navbar-color` = BRAND$ink,
    `navbar-hover-color` = BRAND$messi,
    `navbar-active-color` = BRAND$messi,
    `navbar-brand-color` = BRAND$ink,
    `navbar-brand-hover-color` = BRAND$messi,
    heading_color = BRAND$ink,
    body_bg      = BRAND$bg,
    body_color   = BRAND$ink,
    font_scale   = 1.02
  )
}

# ---------------------------------------------------------------------------
# Cards / layout helpers
# ---------------------------------------------------------------------------
`%||%` <- function(a, b) if (is.null(a)) b else a

kpi_card <- function(title, value, sub = NULL, accent = NULL) {
  card(
    class = "kpi-card shadow-sm",
    card_header(
      class = "kpi-head",
      h6(title, class = "kpi-title")
    ),
    card_body(
      h2(value, class = "kpi-value", style = sprintf("color:%s;", accent %||% BRAND$ink)),
      if (!is.null(sub)) div(sub, class = "kpi-sub text-muted")
    )
  )
}

lead_badge <- function(player, label) {
  span(class = "badge lead-badge",
       style = sprintf("background:%s;color:#fff;", P_COLOR[[player]]),
       paste0("Leads: ", label))
}

p_text <- function(...) p(class = "text-muted", ...)
