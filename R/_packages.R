# R/_packages.R
# ---------------------------------------------------------------------------
# Human-readable dependency inventory. NOT sourced at runtime, and no longer
# feeds any lockfile -- renv was removed from this project on 2026-08-09 (see
# AGENTS.md, "On renv"). Its job now is to record what each part of the project
# needs and why the two GitHub pins exist.
#
# Everything below is installed in the user library:
#   C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5
# Install anything missing with plain install.packages(); the two GitHub pins
# are the only exceptions.
# ---------------------------------------------------------------------------

# === App runtime (Wave 7 Docker image needs THESE SIX AND NOTHING ELSE) =====
# The container never runs FAMD -- scripts/08 precomputes it into
# analysis_bundle.rds and the app only does arithmetic on the result.
library(shiny)
library(bslib)
library(data.table)
library(htmltools)
library(plotly)          # loaded lazily inside mod_weighting / mod_head2head
library(DT)              # loaded lazily inside mod_data

# === Deployment (local only -- never part of the app runtime) ==============
library(rsconnect)       # Wave 8 manifest creation + shinyapps.io publishing

# === Analysis (local only -- builds the bundle, never runs in the container) =
library(FactoMineR)      # FAMD. Its version determines the Dim-1 loadings, so
                         # scripts/08 records packageVersion() into bundle$meta.

# === Scrapers (Phase 1, local only) =========================================
# GitHub-only, pinned by commit. Reinstall with:
#   remotes::install_github("JaseZiv/worldfootballR", ref = "72af453f")
library(worldfootballR)  # ARCHIVED Sep 2025; CRAN copy is stale.
                         # NEVER install from CRAN. Pin: 72af453f9eea.
# library(kickR)         # DEFERRED (jeffreyohene/kickR@ed583cdb): imports
                         # RSelenium (heavy browser-automation chain, contrary
                         # to lean-Docker guidance). Re-enable ONLY if
                         # worldfootballR fb_* fails; the commit is recorded
                         # here so re-adding it is drift-free.

# HTTP / scraping infrastructure
library(httr)
library(curl)
library(rvest)
library(digest)
library(readr)
library(here)
library(chromote)        # runtime dep: FBref sits behind a Cloudflare managed
                         # challenge that plain httr/rvest cannot pass.

# Data wrangling
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)
library(janitor)
library(naniar)
