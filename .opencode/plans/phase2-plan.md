# Phase 2 — Interactive Dashboard (Messi vs Ronaldo)

Status: **Wave 1 complete; awaiting review for Wave 2** (user-approved wave-by-wave review model).
Phase 1 complete: `a3c0a7f` (pipeline) + `016ff08` (docs). Working tree clean at start of Phase 2.

## Deliverable

A bslib Shiny dashboard (`app/`, port 3838) comparing Messi vs Ronaldo on **weighted** performance metrics, with the FAMD difficulty index front and center. Deployed to **shinyapps.io**; a Dockerfile is also produced (Wave 7) for reproducibility, but the deployed artifact is an rsconnect bundle, not the image.

## Fixed decisions (from user — do not re-open)

1. **Layout-first, not blog-first.** The dashboard is built now; blog conversion is a much later phase. Every tab is a module so content can be reused later.
2. **Weighted metrics are the front.** Default metric = Weighted Goals per 90. Raw goals are only the "Reality Check" comparison.
3. **shinyapps.io** is the deploy target via `rsconnect`. Dockerfile still produced for reproducibility (Wave 7).
4. **Wave-by-wave review**: after each wave, stop and summarize; proceed only after approval.
5. **Photos**: CC-licensed Wikimedia Commons images (`app/www/img/`) with graceful fallback; `app/www/ATTRIBUTIONS.md` documents sources.

## Methodology constraints (from AGENTS.md — never violate)

- ONE global FAMD on both players' matches. Inputs only: `Opponent_Elo`, `Venue`, `Competition_Stage`, `Is_Away`. `Difficulty_Score` = standardized Dim 1 (oriented higher = harder). `Weighted_Goal = 1 × Difficulty_Score`.
- Never re-run FAMD in the app — load `famd_loadings.rds` + the pre-joined `Difficulty_Score` columns.
- K-slider (0.5–3.0) **exponentiates stored scores** (`Score ^ K`) — pure UI math, no recomputation.
- Never drop rows on missing Elo (fallback chain: club → league-average → global 1500).
- Never filter to goal-scoring matches only; per-90 denominator uses ALL valid minutes (incl. 1,063 scoreless of 2,201).
- No binning of continuous Opponent Elo (scatter + loess).
- Bootstrap at **match level**, 10,000 resamples, difference = threshold difference (Messi − Ronaldo) in Weighted Goals per 90, CI 2.5/97.5 percentiles. Runs only on "Update Analysis" button click.
- No p-value flags, no Bonferroni — show the full bootstrap density.
- Do not z-score goals before weighting. Raw counts; weights multiplicative.

## Data inputs (Phase 1 outputs, committed)

- `data/processed/goals_master_final.csv` — 1,738 goals (Messi 847, Ronaldo 891), 29 cols, unique `goal_id` (no dupes).
- `data/processed/match_context.rds` — 2,201 rows incl. scoreless appearances; `Difficulty_Score` + `Opponent_Elo` already joined per match.
- `data/processed/famd_loadings.rds` — FactoMineR FAMD output (`eig`, `var`, `quali.var`, `quanti.var`, `ind`, `svd`, `call`).
- `data/processed/quality_report.txt` + `data/data_dictionary.md` — validation/documentation.

## Waves (build order + review gates)

### Wave 0 — Prep & data (complete, commit `92271d9`)
- **`scripts/08_prepare_analysis.R`** → `data/processed/analysis_bundle.rds`:
  - `bundle$goals` — goal-level rows (theme-ready: era labels, penalty flag, xG, difficulty, weighted).
  - `bundle$matches` — match-context rows (for per-90 denominator + bootstrap; includes scoreless).
  - `bundle$per90_base` — per-90 stats tables at K=1 (weighted + raw) for both players.
  - `bundle$boot_input` — match-level rows of weighted-goal sums (Messi/Ronaldo) for bootstrap.
  - `bundle$eras` — career era segments/tablets.
  - `bundle$meta` — content hash, generated-at, key validation cross-check numbers.
- **`app/` skeleton**: `app.R` (bslib theme + sidebar layout + tabset), `R/theme.R` (Messi blue / Ronaldo red tokens), `R/mod_*.R` stubs per tab, `www/` (css + `img/` + ATTRIBUTIONS.md).
- **Photos**: download CC-licensed images (Wikimedia Commons) with fallback; ATTRIBUTIONS.md.
- **Smoke check**: app boots locally (script exits after "Listening on..." + one HTTP GET).

### Wave 1 — Overview (complete, pending commit in current handoff)
- 4 KPI cards (Weighted Goals per 90, Raw Goals, Minutes, Appearances — leader bolded), intro panels (motivation, existing approaches, what we built), photos. `mod_overview.R`.

### Wave 2 — Weighting (core methodology tab)
- K-slider sensitivity stress-test vs Weighted per 90 (line over K, both players).
- Reality Check: raw vs weighted bar chart for both players.
- Difficulty distribution density plot (goal-level) + goal-count by difficulty decile.

### Wave 3 — Head-to-Head
- Cumulative weighted-goals trajectories (career time), age-axis comparison.
- Opponent Elo scatter (per-goal, loess, no bins).
- Penalty analysis (PK vs open play per player; PK-free weighting toggle).
- Comp filter, venue filter.

### Wave 4 — Inference
- "Update Analysis" button → match-level bootstrap (10k), density of difference + CI band, Cohen's d, asymmetry (Messi > Ronaldo) probability. Subgroup table (by era/comp).

### Wave 5 — Methodology / Summary / Raw Data
- Methodology: step-by-step narrative (data collection, FAMD, weighting, bootstrap) with math explanation.
- Summary: definitive head-to-head table (weighted & raw across dimensions).
- Raw data: DT table of `goals_master_final.csv`.

### Wave 6 — Polish
- Loader UX (waiter), `bindCache()` per plot, mobile responsive layout, final visual pass.

### Wave 7 — Docker
- `Dockerfile` (rocker/shiny-verse:4.5.0 pinned, multi-stage, non-root, HEALTHCHECK, port 3838) + `.dockerignore`; include only bundle + app; no worldfootballR/FactoMineR at runtime.

### Wave 8 — Deploy
- `scripts/09_deploy_shinyapps.R` (rsconnect), deploy, verify live URL.

## Gotchas (carrying from Phase 1)

- Windows: run scripts with `Rscript --no-init-file --no-restore --no-save` (user library, NOT renv — renv loads wfR >5 min).
- Use `data.table::fread` for big CSV (26 s vs >2 min `readr`).
- 3 goals lack match context (2026 WC knockout window) — NA Difficulty; keep NA, do not drop.
- DNP rows (Minutes == 0/NA) dropped from per-90 denominator, but zero-goal appearances MUST stay.
- Penalty flag: `Notes` contains "Penalty kick".
- `Venue` in goals file may be "Home"/"Away"/"Neutral" — map consistently with `Is_Away`.
- Elo fallback order: club-by-date → national-by-date → league-average → 1500.
- Git on D: drive is slow — background `Start-Process` + poll; `-F message.txt` for commit messages.
