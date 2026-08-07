# R/_packages.R
# ---------------------------------------------------------------------------
# Project package manifest for the renv lockfile.
# This file is NOT sourced at runtime. Its only job is to give renv::snapshot()
# the list of packages that must be pinned in renv.lock. Add a package here
# ONLY when it becomes a real runtime dependency, then run:
#     Rscript -e 'renv::snapshot(confirm = FALSE)'
# and commit the updated renv.lock.
# ---------------------------------------------------------------------------

# Scrapers --- GitHub-only; pinned to specific commits in renv.lock
library(worldfootballR)   # GitHub (archived Sep 2025): JaseZiv/worldfootballR@72af453f
# library(kickR)          # DEFERRED (jeffreyohene/kickR@ed583cdb): imports RSelenium
#                         # (heavy browser-automation chain, contrary to lean-Docker
#                         # guidance). Re-enable ONLY if worldfootballR fb_* fails in
#                         # Wave B; it stays GitHub-pinned so re-adding is drift-free.

# HTTP / scraping infrastructure
library(httr)
library(curl)
library(rvest)
library(digest)
library(readr)
library(here)

# Data wrangling
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)
library(janitor)
library(naniar)