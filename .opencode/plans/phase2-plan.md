# Phase 2 — Interactive Dashboard (Messi vs Ronaldo)

Status: **Paused at the fully verified Wave 6 review gate; resume with Wave 7 only after a new user instruction** (user-approved wave-by-wave review model).
Phase 1 complete: `a3c0a7f` (pipeline) + `016ff08` (docs). Working tree clean at start of Phase 2.

## Deliverable

A bslib Shiny dashboard (`app/`, port 3838) comparing Messi vs Ronaldo on **weighted** performance metrics, with the FAMD difficulty index front and center. Deployed to **shinyapps.io**; a Dockerfile is also produced (Wave 7) for reproducibility, but the deployed artifact is an rsconnect bundle, not the image.

## Fixed decisions (from user — do not re-open)

1. **Layout-first, not blog-first.** The dashboard is built now; blog conversion is a much later phase. Every tab is a module so content can be reused later.
2. **Weighted metrics are the front.** Default metric = Weighted Goals per 90. Raw goals are only the "Reality Check" comparison.
3. **shinyapps.io** is the deploy target via `rsconnect`. Dockerfile still produced for reproducibility (Wave 7). Note `rsconnect` builds its **own** manifest by scanning app source against the installed libraries — it needs no lockfile at all. Wave 7 pins via a dated Posit PPM snapshot instead (renv removed 2026-08-09).
4. **Wave-by-wave review**: after each wave, stop and summarize; proceed only after approval.
5. **Photos**: CC-licensed Wikimedia Commons images (`app/www/img/`) with graceful fallback; `app/www/ATTRIBUTIONS.md` documents sources.

## Methodology constraints (from AGENTS.md — never violate)

- ONE global FAMD on both players' matches. Inputs only: `Opponent_Elo`, `Venue`, `Competition_Stage`, `Is_Away`. `Difficulty_Score` = standardized Dim 1 (oriented higher = harder). `Weighted_Goal = 1 × Difficulty_Score`.
- Never re-run FAMD in the app — load `famd_loadings.rds` + the pre-joined `Difficulty_Score` columns.
- K-slider (0.5–3.0) applies a **signed power** to the stored scores — `sign(Score) * abs(Score)^K` — pure UI math, no recomputation. **Never plain `Score ^ K`**: roughly half the difficulty scores are negative and a negative base with a fractional exponent yields `NaN`.
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

### Wave 1 — Overview (complete; baseline commit `4450c03`, revised 2026-08-11)
- Four KPI cards (Weighted Goals per 90, Raw Goals, Total Goals, Appearances — leader bolded) and the two original intro panels.
- Country profiles separate national-team identity from dashboard coverage and retain the circular player portraits.
- Server-rendered senior club journeys use static era metadata but calculate snapshot goal counts from `bundle$goals`.
- Eight local crest SVGs, meaningful alt text, current-chapter highlights, and full source/trademark documentation.
- Offline-safe native MathML explains the signed-power formula in the global-controls sidebar; no MathJax/CDN.
- Responsive desktop timeline and narrow-screen card layouts. The stylesheet URL is versioned to prevent browsers from combining revised markup with stale CSS.
- No analytical calculations, bundle schemas, package dependencies, or public data files changed.
- Full implementation and verification record: `.opencode/plans/phase2-handoff.md`.

### Wave 2 — Weighting (complete)
- Guided Weighting Lab with four live cards: both selected-K weighted rates, Messi−Ronaldo gap, and computed lead-stability status across all 26 K values.
- Precomputed signed-power sensitivity grid for both penalty settings; slider movement selects stored rows and never invokes bootstrap work.
- Plotly K-sensitivity hero curve, Reality Check, normalized K=1 difficulty density, and fixed global difficulty-decile goal counts with accessible text summaries.
- Penalty toggle applies to all Wave 2 goal numerators while every per-90 denominator retains all 2,201 valid appearances, including 1,063 scoreless appearances.
- Overview remains the fixed K=1/all-goals baseline and now displays that contract explicitly.
- Responsive layouts stack below 1200 px; stylesheet cache token is `css.css?v=20260811-wave2`.
- Source/data/runtime checks and live-browser passes at 1919×862 and 390×844 are complete. The corrected decile tooltip was verified with penalties included and excluded; no placeholders, horizontal overflow, Shiny output errors, or new console errors remain.

### Wave 3 — Head-to-Head (complete)
- Competition and venue filters live in shared state but apply only to Head-to-Head in this wave. Numerators and all-valid-appearance denominators use the same selected scope.
- Four selected-scope cards report both weighted index rates per 90, the Messi−Ronaldo gap, and weighted-goal coverage, with distinct `N/A` and zero-output states.
- Age-aligned or calendar-date trajectories show cumulative selected-K weighted index or rolling 30-filtered-appearance weighted index per 90. Age uses fixed birth-date display metadata and shows an age-30 guide only on the age axis.
- The opponent-Elo view keeps one unjittered marker per eligible goal and overlays guarded, descriptive player LOESS curves without bins, confidence bands, or inference.
- The penalty-dependency chart always discloses raw penalty/open-play counts and shares. Excluded penalty segments remain visible but muted while headline, trajectory, and Elo views follow the penalty toggle.
- Missing difficulty, centred negative index values, filtered denominators, sparse scopes, descriptive LOESS, and the absence of Wave 4 confidence intervals are disclosed in the UI.
- Bundle/schema/dependencies/FAMD remain unchanged; the stylesheet cache token is `css.css?v=20260812-wave3`.
- Source, interaction, HTTP, and live-browser checks passed at 1919×862 and 390×844 with no overflow or Shiny output errors. Exact verification values and representative-filter results are in `.opencode/plans/phase2-handoff.md`.

### Wave 4 — Inference (complete)
- `Update analysis` freezes K, penalty, competition, and venue; control changes do not rerun inference and show a stale-results notice until the next click.
- Eligible goal contributions are joined to all valid appearances with the established match key, preserving scoreless rows and all selected-scope minutes.
- 10,000 deterministic, independent within-player match resamples use seed `20260812`; each replicate preserves the player's selected-scope appearance count and computes the ratio-of-sums weighted index per 90.
- Four result cards report the observed Messi-Ronaldo gap, 95% percentile interval, directional probability above zero, and conventional pooled-SD appearance-level Cohen's d without p-values or binary winner/significance flags.
- The Plotly density includes interval shading, zero and observed reference lines, formatted hover text, and an accessible numerical summary.
- Career-era and competition-family tables are both precomputed on the click. Descriptive rates remain available with appearances; intervals and d require at least two appearances per player; fewer than 30 for either player is marked sparse.
- Empty and one-player scopes use `N/A` and explanatory states. Missing-difficulty goals contribute zero to weighted numerators and remain disclosed.
- The stylesheet token is `css.css?v=20260812-wave4`. No bundle, FAMD, dependency, or source-data change was made.
- The Wave 4 study guide is retained as `output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf`; the Word intermediate and temporary renders were removed after full visual/text validation.

### Wave 5 — Methodology / Summary / Raw Data (complete)
- Methodology now presents the full data-collection → global FAMD → signed-power weighting → all-valid-minute rate → match-bootstrap chain with native offline MathML, exact coverage disclosures, stored Dim 1 variance, and reconstructed input contributions. FAMD is never rerun.
- Summary provides a fixed K=1/all-goals career reference and an immediately reactive selected-scope view. Both contain overall, five career-era, five competition-family, and three venue rows (14 fixed rows) with appearances/minutes, weighted rates/gaps, and raw rates/gaps.
- The fixed reference is isolated from sidebar changes. The live view follows K, penalty, competition, and venue without invoking or depending on the Inference button; `N/A` remains distinct from a real zero.
- Raw Data loads the exact 1,738 × 29 `goals_master_final.csv` as character data, supports global and per-column search, sorting, pagination, internal horizontal scrolling, and a byte-identical download. Sidebar controls do not affect it.
- `scripts/08_prepare_analysis.R` now copies that source CSV exactly into `app/data/` when rebuilding the existing bundle; the analysis-bundle schema and FAMD artifacts remain unchanged.
- Responsive desktop/mobile checks pass at 1919×862 and 390×844. The stylesheet token is `css.css?v=20260812-wave5`; root, CSS, and portrait requests return HTTP 200; the offline favicon removes the prior console 404.
- `tests/wave5_content_checks.R` and the Wave 4 regression suite pass. Exact source/app/download MD5 is `c43c3f995b1f301b4328c846eab2cf27`.
- The retained 29-page Wave 5 study guide is `output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf`; extracted text, page geometry/bounds, pagination, and all rendered pages were validated, and the Word intermediate and temporary renders were removed.

### Wave 6 — Polish (complete; awaiting review)
- Native `shiny::busyIndicatorOptions()` supplies delayed output spinners, fade treatment, and a branded page pulse; no package dependency was added.
- All eight Plotly outputs across Weighting, Head-to-Head, and Inference are wrapped in `shiny::bindCache()`. The Inference density key uses the bundle build stamp and the frozen K/penalty/competition/venue snapshot.
- The analysis sidebar opens on desktop and initializes collapsed on mobile. Safe-area padding, internal wide-table scrolling, narrow formula containment, explicit focus rings, compact Plotly modebars, and reduced-motion overrides complete the responsive pass.
- Versioned local `app.js?v=20260812-wave6` adds a keyboard skip link/main focus target and debounced polite loading announcements without external assets.
- Versioned CSS is `css.css?v=20260812-wave6`. The bundle schema, source data, global FAMD, module APIs, signed-power formula, all-valid-minute denominators, and six-package runtime remain unchanged.
- Wave 4, Wave 5, and new Wave 6 regressions pass. Browser checks cover all tabs at 1919×862 and 390×844 plus 768×1024 and 320×700 containment, native loading feedback, keyboard skip-link activation, zero console warnings/errors, and HTTP 200 for root/CSS/JS/portrait.

### ~~Wave 7.0 — Repair `renv.lock`~~ — RESOLVED 2026-08-09 by removing renv

Superseded. The lockfile was not repaired; **renv was removed from the project entirely**
(`renv.lock`, `renv/`, `.Rprofile` deleted). Rationale in `AGENTS.md` under *On renv* —
the container needs six packages and never runs FAMD, so the precomputed `.rds` already
delivers what the lockfile was meant to guarantee. Wave 7 is no longer blocked.

### Wave 7 — Docker
- `Dockerfile` (rocker/shiny-verse:4.5.0 pinned, multi-stage, non-root, HEALTHCHECK, port 3838) + `.dockerignore`; include only bundle + app; no worldfootballR/FactoMineR at runtime.
- **Package install pins by dated Posit PPM snapshot, not renv.** Frozen date = reproducible, and PPM serves precompiled Linux binaries so the layer builds fast:
  ```dockerfile
  RUN R -e 'options(repos = "https://packagemanager.posit.co/cran/2026-08-09"); \
            install.packages(c("shiny","bslib","data.table","htmltools","plotly","DT"))'
  ```
- Those six are the entire runtime. Verify by building and hitting `http://localhost:3838` — do not assume the list; if a module gains a dependency in Waves 2–6, add it here and to `R/_packages.R`.

### Wave 8 — Deploy
- `scripts/09_deploy_shinyapps.R` (rsconnect), deploy, verify live URL.

## Gotchas (carrying from Phase 1)

- Run scripts with plain `Rscript <script>` — no flags. There is no `.Rprofile` and no renv (removed 2026-08-09); everything resolves from the user library.
- Use `data.table::fread` for big CSV (26 s vs >2 min `readr`).
- 3 goals lack match context (2026 WC knockout window) — NA Difficulty; keep NA, do not drop.
- DNP rows (Minutes == 0/NA) dropped from per-90 denominator, but zero-goal appearances MUST stay.
- Penalty flag: `Notes` contains "Penalty kick".
- `Venue` in goals file may be "Home"/"Away"/"Neutral" — map consistently with `Is_Away`.
- Elo fallback order: club-by-date → national-by-date → league-average → 1500.
- Git on D: drive is slow — background `Start-Process` + poll; `-F message.txt` for commit messages.
