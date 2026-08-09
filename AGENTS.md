# AGENTS.md

Guidance for OpenCode/AI agents in this repo. Read before writing code.

## START HERE — read this before you touch anything

**This file is the single source of truth for this repo.** If any other document
contradicts it, this file wins — surface the conflict, do not silently pick one.
(The four root `.txt` files remain the authoritative *spec*; where the build has
deliberately diverged from them, it is annotated below rather than overwritten.)

1. **There is no renv in this project. Do not add it.** Removed 2026-08-09; the
   spec still mandates it, and that divergence is deliberate — see *On renv* under
   *Stack & environment* before you act on `3. Containerization.txt`.
2. **Every command is plain `Rscript <script>`** — no `--no-init-file`, no flags.
   There is no `.Rprofile`. Packages come from the user library.
3. **Launch the app only via `app/run.R`**, never `Rscript app/app.R` — the latter
   404s every static asset in `app/www/`.
4. **The K-slider is a SIGNED power: `sign(x) * abs(x)^K`.** Plain `x^K` returns
   `NaN` on the negative difficulty scores.
5. **Stop after each wave and summarize.** Do not chain waves; the user reviews each one.

## What this repo is

- **Phase 1 (data collection) is COMPLETE and committed (git `a3c0a7f`).** **Phase 2 (Shiny dashboard) is IN PROGRESS** — see `.opencode/plans/phase2-plan.md` for the wave plan (0–8) and `.opencode/plans/phase2-handoff.md` for the current resume point; after each wave there is a review gate. The four `.txt` files are the authoritative spec, and their **numeric prefixes are the build-phase order**: `Goals and desires and build plan.txt` (vision), `1. Datacollection info.txt`, `2. DataAnalysis.txt`, `3. Containerization.txt`. Read them in numbered order before generating code; don't contradict them without surfacing the conflict.
- **No Kaggle CSVs.** The original spec's "quick win" manual Kaggle downloads were dropped — everything is scraped directly (goal-level data comes from FBref's own goal-log pages, which cover club + international).
- **Primary deliverable:** `data/processed/goals_master_final.csv` (1,738 goals, one row/goal) built by `scripts/07_integrate_data.R` from the raw scrapes. See `data/data_dictionary.md` for columns. The dashboard consumes `app/data/analysis_bundle.rds` (built by `scripts/08_prepare_analysis.R` from the processed outputs).

## Stack & environment

- **R 4.5.2** (`rocker/shiny-verse:4.5.0` pinned for Docker). `r_packages.csv` is only a partial reference snapshot, never a manifest.
- **One library, no environment manager.** Everything lives in the user library `C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5`. There is no `.Rprofile`, so plain `Rscript <script>` is correct everywhere. `R/_packages.R` is a human-readable inventory of what each part needs — it is not sourced at runtime and feeds no lockfile.
- `worldfootballR` is **unmaintained/archived (Sep 2025); CRAN version stale** — pinned to GitHub commit `72af453f9eea` (installed in the user library at that SHA). **Never install from CRAN.** Reinstall with `remotes::install_github("JaseZiv/worldfootballR", ref = "72af453f")`. `kickR` (GitHub `ed583cdb047d`) is **deferred** — it imports RSelenium (heavy); re-enable only if `fb_*` fails (see `R/_packages.R`).
- `chromote` is a **runtime dependency** — FBref is behind a Cloudflare managed challenge that plain `httr`/`rvest` cannot pass.
- **Deployment does not need a lockfile either.** `rsconnect` builds its own manifest by scanning app source against the installed libraries, so Wave 8 (shinyapps.io) never reads one. Wave 7's Dockerfile pins by **dated Posit PPM snapshot** instead — see *Docker / deployment*.
- Avoid `shinydashboard` (heavy JS) and `rJava`/text-analysis libs. **On `shiny.fluent`:** the spec recommends it (`2. DataAnalysis.txt:176`, `3. Containerization.txt:353`), but the build is **bslib-only** — `shiny.fluent` is not installed and not used anywhere in `app/`. Deliberate divergence; **do not add it.**

### On renv — deliberate divergence from the spec (2026-08-09)

**The spec mandates renv and this build does not use it.** `3. Containerization.txt:57`
heads its section *"Dependency Management with renv (Non-Negotiable)"*, and the vision doc
names renv four times as the reproducibility story. renv was nonetheless **removed** —
`renv.lock`, `renv/`, and `.Rprofile` are all deleted. Do not re-add it. The reasoning,
so it isn't relitigated:

- **The container never runs FAMD.** `3. Containerization.txt:68` justifies renv as the
  thing that "freezes the statistical methodology" so a FactoMineR update can't shift the
  loadings. But the same spec requires FAMD to be precomputed locally and shipped as
  `.rds`; the image only multiplies numbers. **Shipping the artifact is a stronger
  guarantee than pinning the library that produced it** — and `scripts/08` now stamps
  `bundle$meta$pkg_versions` with the FactoMineR version that actually built it.
- **The image needs six packages** — `shiny`, `bslib`, `data.table`, `htmltools`,
  `plotly`, `DT`. A 69-package lockfile and a 172.6 MB project library served none of them.
- **The lockfile was written at project start**, before the dashboard existed, so it
  contained no `shiny` and no `FactoMineR` — `renv::restore()` would have built a
  container that could not boot. That is the general failure: **lock the environment once
  the app is built and the dependency set is known, never at project start.** A lockfile
  is a record of what you ended up depending on; written early it looks correct while
  being wrong, and the gap surfaces far from its cause.

Deleting `.Rprofile` (whose only line was `source("renv/activate.R")`) is what removes
`--no-init-file` from every command in this project.

### Launching the dashboard

**Always `app/run.R`, never `Rscript app/app.R`.** `run.R` calls `shiny::runApp(appDir = ...)` so Shiny serves `app/www/` as static assets; launched via `app.R` the stylesheet and player images 404. It also guards the three ways this launch fails (Shiny stack not installed, wrong working directory, port 3838 already held by an earlier instance).

```powershell
Rscript app/run.R   # http://127.0.0.1:3838
```

Restart the process after code changes, then refresh the browser.

## Phase 1 pipeline (all scraping — no manual downloads)

- `R/politeness.R` — paths, User-Agent, robots check, scrape logger (`data/raw/scrape_log.csv`), HTML cache.
- `R/clubelo_slugs.R` — **shared** ClubElo slug derivation (transliterate → override map → strip non-alnum), used by BOTH 04 (fetch) and 07 (join). Vectorized.
- `R/browser_scrape.R` — **FBref access requires headful Chrome.** Launch/attach a persistent headful Chrome on port 9333 with a stable `%LOCALAPPDATA%/MessivsRonaldo-chrome-profile`; the first-ever visit to FBref takes ~85 s (Cloudflare auto-solves and stores `cf_clearance` in the profile); after that it's fast. `patch_fbref_load_page()` replaces worldfootballR's internal `.load_page()` so every `fb_*` call fetches via Chrome + cache. If the challenge hangs, wait — it clears.
- Scripts run in numbered order: `02_scrape_fbref.R` (goal logs + match logs + season stats; outputs `data/raw/fbref_*.rds`) → `03_scrape_understat.R` → `04_collect_elo_ratings.R` → `05_scrape_transfermarkt.R` → `07_integrate_data.R` (joins → `data/processed/goals_master_final.csv`). WhoScored (`06`) deferred. **07 is DONE** — outputs `goals_master_final.csv` (1,738 goals), `match_context.rds` (2,201 matches), `famd_loadings.rds`, `quality_report.txt`, `data/data_dictionary.md`.
- **Elo sources (04):** ClubElo API for clubs (`api.clubelo.com/<Slug>` — **flaky, retry with backoff + preflight probe**; if API unreachable, club phase is SKIPPED, cached data kept — re-run later). National Elo from **eloratings.net per-team TSV** (`www.eloratings.net/{Team}.tsv`; each row carries both teams' Elo in cols 11–12; files keyed by team CODE like `AR`/`PT` resolved via `en.teams.tsv`) — NOT the martj42 CSV, which has no Elo column. 04 runs national FIRST (independent of ClubElo), club SECOND.
- **Elo fallback chain (07):** club lookup by date range → national lookup by date → league-average (mean of matched clubs in same Comp) → global 1500. Never drop rows. Current coverage: 82% direct, 90.6% direct-or-league (spec §6.1 target >90%). Saudi/MLS/Mexican clubs legitimately fall to 1500 (no public Elo source).
- **Understat xG join gotcha (07):** Understat minutes differ from FBref (`46` vs `45+2`), so join by **goal rank within (Player, date)** — both sources list the same goals chronologically. 483/1,738 goals get xG (2014+ top-5 only; documented gap).
- **3 goals lack match context (2026 WC knockout):** the match log snapshot predates the goal log snapshot; those 3 goals have NA Difficulty_Score/context (documented in quality report).
- **FBref goal-log page gotchas:** the `goallogs/all_comps/<slug>-Goal-Log` table repeats its column header every ~56 rows AND contains fully-empty spacer rows. Filter on the `Date` column (`Date` not in `""`, `"Date"`, `NA`), never on `Rk`. The `Notes` column carries goal type ("Penalty kick", "Free kick"). Match-log pages have a two-row header — row 2 is the real column names.
- **FBref opponent country prefixes are 2–3 letters** (`it Milan`, `eng Arsenal`, `sct Celtic`, `nir Northern Ireland`): strip with `^[a-z]{2,3} `.

## Methodological constraints — do NOT violate (highest-signal)

- **FAMD, not PCA** — chosen because the data mixes continuous (Opponent Elo) and categorical (Venue, Competition Stage).
- **Run ONE global FAMD** on the combined dataset of both players. Never per-player FAMDs — indices become non-comparable.
- **FAMD inputs are only:** `Opponent_Elo`, `Venue`, `Competition_Stage`, `Is_Away`. **Exclude** the goal count, the player name, and the player's **own** team Elo (it penalizes early/late-career goals).
- `Difficulty_Score = Dim 1 loadings`; `Weighted Goal = 1 × Difficulty_Score`. The **K-parameter slider (0.5–3.0)** applies a **signed power** for sensitivity stress-testing — it is not part of the base weights:
  ```r
  sign(Difficulty_Score) * abs(Difficulty_Score)^K
  ```
  **Never plain `Difficulty_Score ^ K`** — difficulty scores are centred and roughly half are negative, and a negative base with a fractional exponent returns `NaN`. Already documented at `scripts/08_prepare_analysis.R:18-19`.
- **Do not z-score** goals before weighting — it destroys the count nature. Keep raw counts; weights are multiplicative.
- **Do not drop rows** with missing Elo. Impute via fallback: Club Elo → league-average Elo → global 1500.
- **Do not bin** continuous Opponent Elo into Strong/Weak for plots — use scatter + loess.
- **Bootstrap at the MATCH level** (not goal level), 10,000 resamples with replacement, record the difference (Messi − Ronaldo) in Weighted Goals per 90. CI = 2.5/97.5 percentiles.
- **NEVER filter to goal-scoring matches only** — **48.3% of appearances (1,063 of 2,201) are scoreless** (verified against `match_context.rds`). Note 2,263 is the *raw* match-log row count and 2,201 the cleaned count — they are not interchangeable. The FAMD, the per-90 denominator, and the match-level bootstrap all need the FULL match set. Flow: match logs (all appearances incl. scoreless) → ONE global FAMD on all matches → Difficulty_Score joined to goal-level rows (only Goals ≥ 1 get weighted) → per-90 = sum(Weighted Goals) / sum(Minutes across ALL valid matches). The 12 header-junk rows (Gls == "Gls") and 47 DNP rows (no minutes) are dropped, but zero-goal appearances are kept.
- **Do not present p-values as binary flags** and do **not** Bonferroni-adjust in the exploratory dashboard — show the full bootstrap density.
- **Dashboard default metric = Weighted Goals per 90**, never Raw Goals (Raw is only the "Reality Check" comparison).
- **Shiny performance:** store pre-computed FAMD scores in a `reactiveVal()`; the K-slider only multiplies them; the bootstrap runs **only** on an explicit "Update Analysis" button click (not on slider drag — freezes the app). Use `shiny::bindCache()` on `renderPlot`.

## Docker / deployment (`3. Containerization.txt`)

- Base image `rocker/shiny-verse:4.5.0` **pinned — never `latest`**. Multi-stage; target < 1.5 GB; runs as the non-root `shiny` user (don't override). Shiny port **3838**.
- **FAMD must be pre-computed locally** and saved as `data/famd_loadings.rds`; the container only loads the `.rds` and multiplies — never run FAMD at startup (~2s vs ~15s, memory-safe).
- **Layer order for cache efficiency:** base → system deps → R packages → app code → CMD.
- **Package pinning is a dated Posit PPM snapshot, not renv** (see *On renv* above). The frozen date makes the install reproducible, and PPM serves precompiled Linux binaries so the layer builds far faster than a source `renv::restore()`:
  ```dockerfile
  RUN R -e 'options(repos = "https://packagemanager.posit.co/cran/2026-08-09"); \
            install.packages(c("shiny","bslib","data.table","htmltools","plotly","DT"))'
  ```
  Those six are the whole runtime — no `worldfootballR`, no `FactoMineR`. Never call `install.packages()` there without the pinned `repos`.
- System libs the base lacks (ggplot2/plotly/HTTPS): `libssl-dev`, `libcurl4-openssl-dev`, `libxml2-dev`, `libfreetype6-dev`, `libharfbuzz-dev`, `libpng-dev`, `libjpeg-dev`.
- `HEALTHCHECK` curls `http://localhost:3838/`. Logs to **stdout** (JSON), not files. Data is <1 MB — embed in the image, no volume mounts.

## Data-collection gotchas

- **Do not scrape Fotmob** — TOS changed; removed from `worldfootballR`.
- **FBref tables are sometimes HTML comments** — default `rvest` selectors miss them; parse the comment blocks separately.
- **Understat xG covers only top-5 European leagues from 2014+** — document the gap; use season-level xG as fallback.
- **Scraping politeness is mandatory:** 3–5 s delays, descriptive User-Agent, respect `robots.txt`, cache locally to avoid re-scraping.
- `data/raw/` is immutable; all cleaning lives in `data/processed/` with documentation.
