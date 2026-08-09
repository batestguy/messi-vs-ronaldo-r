# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read first

**`AGENTS.md` is the single source of truth — read it top to bottom before you touch anything. If any other file (including this one) contradicts it, AGENTS.md wins; surface the conflict rather than silently picking one.** Its `## START HERE` block holds the five rules that get broken most often.

`AGENTS.md` is the authoritative operating guide — read it before writing code. The four root `.txt` files are the project spec and their numeric prefixes are the build-phase order: `Goals and desires and build plan.txt` (vision) → `1. Datacollection info.txt` → `2. DataAnalysis.txt` → `3. Containerization.txt`. Don't contradict them without surfacing the conflict.

Current status: Phase 1 (scraping pipeline) complete; Phase 2 (Shiny dashboard) in progress. `.opencode/plans/phase2-plan.md` holds the wave plan (0–8), `.opencode/plans/phase2-handoff.md` the resume point. **The user reviews after each wave — stop and summarize rather than running waves back to back.**

## Commands

Plain `Rscript` everywhere — no flags. There is no `.Rprofile` and no environment manager; every package resolves from the user library `C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5`. (renv was removed on 2026-08-09; if you see `--no-init-file` in an older note, it is stale — it existed only to skip `renv/activate.R`.)

```powershell
# Run the dashboard (from repo root, NOT `Rscript app/app.R` — see below)
Rscript app/run.R                        # serves http://127.0.0.1:3838

# Rebuild the analysis bundle the app consumes
Rscript scripts/08_prepare_analysis.R

# Phase 1 scrapers (need worldfootballR + headful Chrome — see below)
Rscript scripts/02_scrape_fbref.R
Rscript scripts/03_scrape_understat.R
Rscript scripts/04_collect_elo_ratings.R
Rscript scripts/05_scrape_transfermarkt.R
Rscript scripts/07_integrate_data.R
```

`R/_packages.R` is not sourced at runtime and feeds no lockfile — it is a human-readable inventory recording which packages each stage needs and why the two GitHub pins exist. Add new dependencies there for the next reader, and install them with plain `install.packages()`. `r_packages.csv` is a stale partial snapshot, not a manifest.

There is no test suite and no linter configured. Verification is done by running scripts end to end and by browser-checking the app (Playwright / chrome-devtools MCP against `http://127.0.0.1:3838`).

### Launching the app

Always `app/run.R`, never `Rscript app/app.R` directly: `run.R` calls `shiny::runApp(appDir = "app")` so Shiny serves `app/www/` as static assets. Launched via `app.R` the stylesheet and player images 404. Restart the process after code changes, then refresh the browser.

## Architecture

Two stages joined by one file.

**Stage 1 — scrape → integrate (`scripts/0*.R`, complete).** Numbered scripts run in order and write immutable raw output to `data/raw/`; all cleaning lives in `data/processed/`. `07_integrate_data.R` joins everything into the primary deliverable `data/processed/goals_master_final.csv` (1,738 goals, one row per goal; columns documented in `data/data_dictionary.md`), plus `match_context.rds` (2,201 matches including scoreless appearances), `famd_loadings.rds` and `quality_report.txt`. Script `06` (WhoScored) is deferred.

Shared helpers under `R/` are sourced by the scripts, never duplicated:
- `R/politeness.R` — paths, User-Agent, 3s request floor, robots.txt check, `data/raw/html_cache/`, scrape log to `data/raw/scrape_log.csv`. Source this first in any script that hits the network.
- `R/browser_scrape.R` — FBref is behind a Cloudflare managed challenge that httr/rvest cannot pass. Launches/attaches persistent **headful** Chrome on port 9333 with a stable `%LOCALAPPDATA%/MessivsRonaldo-chrome-profile`, and `patch_fbref_load_page()` monkey-patches worldfootballR's internal `.load_page()` so every `fb_*` call goes through Chrome + cache. First-ever FBref visit takes ~85s while Cloudflare auto-solves; if it seems to hang, wait.
- `R/clubelo_slugs.R` — one slug derivation shared by script 04 (fetch) and 07 (join), so they can't drift.

**Stage 2 — bundle → dashboard (`scripts/08` + `app/`, in progress).** `08_prepare_analysis.R` precomputes everything expensive into `analysis_bundle.rds` (written to both `data/processed/` and `app/data/`): `$goals`, `$matches`, `$per90_base`, `$boot_input`, `$eras`, `$meta`. **The app never loads worldfootballR or FactoMineR and never re-runs FAMD** — it reads the bundle and does arithmetic. If the app needs a new derived field, add it in `08` and rebuild the bundle rather than computing it in a module.

`app/app.R` is the shell: bslib `page_navbar` + global sidebar (K slider, penalty toggle, "Update analysis" button), one `nav_panel` per tab. Tabs are Shiny modules in `app/R/mod_*.R` — several are still Wave-0 stubs. The shell owns a single `reactiveValues` `state` (`bundle`, `K`, `exclude_pen`, `boot_trigger`) and passes it to every `mod_*_server(id, state)`; modules read from `state`, they don't re-read the bundle from disk. `app/R/theme.R` holds the bslib theme and the Messi-blue / Ronaldo-red color tokens. Keep `app.R`'s top-level `library()` calls minimal — plotly and DT are heavy and are meant to load inside the modules that use them.

## Methodological constraints — do not violate

These are analysis decisions, not preferences; breaking one silently invalidates the result. Full list in `AGENTS.md`; the ones that get broken by accident:

- **FAMD, not PCA** (mixed continuous + categorical), and **one global FAMD over both players** — never per-player, or the indices stop being comparable.
- FAMD inputs are exactly `Opponent_Elo`, `Venue`, `Competition_Stage`, `Is_Away`. Exclude goal count, player name, and the player's **own** team Elo.
- `Difficulty_Score` = Dim 1 loadings; `Weighted_Goal = 1 × Difficulty_Score`. The K slider (0.5–3.0) is a sensitivity stress test applied in-app as a **signed** power `sign(x) * abs(x)^K` — plain `x^K` produces NaN on the negative scores.
- **Never filter to goal-scoring matches.** ~1,063 of 2,201 appearances are scoreless and are needed by the FAMD, the per-90 denominator, and the match-level bootstrap.
- **Never drop rows for missing Elo** — impute via club → national → league-average → global 1500.
- Bootstrap at the **match** level, 10,000 resamples, difference (Messi − Ronaldo) in Weighted Goals per 90, CI at the 2.5/97.5 percentiles. It runs only on the "Update analysis" click, never on slider drag.
- Don't z-score goals before weighting, don't bin continuous Opponent Elo for plots (scatter + loess), don't show p-values as binary flags or Bonferroni-adjust — show the bootstrap density.
- Default displayed metric is **Weighted Goals per 90**; raw goals appear only as the "Reality Check".

## Data and dependency constraints

- `worldfootballR` is archived (Sep 2025) and stale on CRAN — installed from GitHub commit `72af453f9eea` (`remotes::install_github("JaseZiv/worldfootballR", ref = "72af453f")`). Never install it from CRAN. `kickR` is deliberately deferred (pulls in RSelenium).
- **No renv, and do not re-add it** — removed 2026-08-09 along with `renv.lock`, `renv/` and `.Rprofile`. The spec mandates it (`3. Containerization.txt:57`, marked "Non-Negotiable"), so this is a deliberate divergence; the full rationale is in `AGENTS.md` under *On renv*. Short version: the container needs six packages and never runs FAMD, so shipping the precomputed `.rds` already delivers what the lockfile was supposed to guarantee. Wave 7's Dockerfile pins via a dated Posit PPM snapshot instead.
- Do not scrape Fotmob (TOS). FBref tables are sometimes wrapped in HTML comments, so default rvest selectors miss them.
- FBref goal-log tables repeat their header every ~56 rows and contain empty spacer rows — filter on the `Date` column, never on `Rk`. Match-log pages have a two-row header; row 2 has the real names. Opponent names carry 2–3 letter country prefixes (`it Milan`, `sct Celtic`) — strip with `^[a-z]{2,3} `.
- `data/raw/` and `data/external/` are gitignored (large, reproducible); `data/processed/` is tracked except the 33MB `club_elo_lookup.csv`.
- Deploy target is **shinyapps.io** via rsconnect; the Dockerfile (Wave 7) exists for reproducibility only. Docker base is `rocker/shiny-verse:4.5.0`, pinned, non-root `shiny` user, port 3838.
