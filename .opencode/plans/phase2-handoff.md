# Phase 2 Handoff

Date: 2026-08-15
Status: **Project complete; public deployment and repository accepted; local services closed**

## Final Closeout

Wave 8 and the complete project are closed. The verified public application is live at
`https://qqxot9-batest-hommie.shinyapps.io/messi-vs-ronaldo-r/` under content
ID `17705139`. The final linked deployment is bundle `12413528`. The user
accepted the live experience and closed the project. The GitHub repository is
public at `https://github.com/batestguy/messi-vs-ronaldo-r`. Do not begin a new
phase, change source data, or rebuild the analysis bundle without a new user
request. Future approved app changes can be published with the same plain
`Rscript scripts/09_deploy_shinyapps.R` command; the ignored `app/rsconnect/`
record safely links updates to this application.

The local Shiny listener and Docker Desktop are stopped. Port 3838 is closed.
Docker was verified healthy after its disposable data was removed, then stopped;
it retains zero images, containers, volumes, or build cache. Its clean WSL disk
is 1.50 GiB. Ubuntu WSL, the user R library, Python installations, rsconnect
credentials, and the public shinyapps.io deployment were preserved. See
`docs/PROJECT_CLOSEOUT.md` for the reusable skills and final operating record.

- Wave 0 is committed as `92271d9`.
- The original Wave 1 implementation is committed as `4450c03`.
- The 2026-08-11 Wave 1 revision is committed as `94d260c` (`feat: expand
  Wave 1 profiles and weighting guidance`).
- Phase 1 remains complete at `a3c0a7f` (pipeline) + `016ff08` (docs).
- Local `main` tracks `origin/main` at the public GitHub repository
  `https://github.com/batestguy/messi-vs-ronaldo-r`.
- For the 2026-08-15 user review, the dashboard was launched through
  `Rscript app/run.R` at `http://127.0.0.1:3838` and intentionally left
  running. If that listener is no longer present, relaunch with the same
  command from the repository root.

## Launch and Refresh Contract

Always launch from the repository root with:

```powershell
Rscript app/run.R
```

Do not run `Rscript app/app.R`; that launch path does not serve `app/www/`
reliably. There is no renv and there are no command flags.

Restart the R process after source changes. The custom stylesheet is linked as
`css.css?v=20260815-review1` in `app/app.R`. If future work changes CSS and a
browser displays new markup with stale styles, bump this version token and
reload the page.

## Wave 1 Revision Implemented

### Signed-power equation panel

The sidebar now uses native, offline-safe MathML instead of plain help text:

```text
WGₖ = sign(Difficulty_Score) × |Difficulty_Score|ᴷ
K = 1 ⇒ WG₁ = Difficulty_Score
```

- `weight_formula_panel()` lives in `app/app.R`.
- The wrapper is a `role="note"` with a full accessible text label.
- The explanation states that K changes sensitivity and K = 1 preserves the
  base index.
- The first equation wraps into two MathML rows so it fits the sidebar.
- No MathJax or CDN dependency was introduced.
- This is presentation only; the analytical signed-power calculation did not
  change.

### Player identity and club journeys

Each Overview profile keeps the national-team portrait and player-colored
border, while separating national-team identity from dashboard coverage:

- Lionel Messi — Argentina national team; coverage 2004–2026.
- Cristiano Ronaldo — Portugal national team; coverage 2002–2026.

`CLUB_ERAS` in `app/R/mod_overview.R` is internal presentation metadata with
the fields `Player`, `Squad_clean`, `Club`, `Years`, `Asset`, `Current`, and
`Order`. Goal counts are not stored in the metadata; the server calculates them
from `bundle$goals` by `Player` and `Squad_clean`.

| Player | Club | Playing years shown | Goals in this dataset | Current chapter |
|--------|------|---------------------|----------------------:|-----------------|
| Messi | Barcelona | 2004–2021 | 627 | No |
| Messi | Paris Saint-Germain | 2021–2023 | 32 | No |
| Messi | Inter Miami | 2023–present | 90 | Yes |
| Ronaldo | Sporting CP | 2002–2003 | 3 | No |
| Ronaldo | Manchester United | 2003–2009 · 2021–2022 | 127 | No |
| Ronaldo | Real Madrid | 2009–2018 | 421 | No |
| Ronaldo | Juventus | 2018–2021 | 101 | No |
| Ronaldo | Al-Nassr | 2023–present | 102 | Yes |

The figures are explicitly labeled as a dataset snapshot, not official live
career totals. Manchester United's two spells correctly aggregate to 127 goals.

### Crest assets and legal notes

Eight local SVG assets now live in `app/www/img/clubs/`:

- `barcelona.svg`
- `psg.svg`
- `inter-miami.svg`
- `sporting-cp.svg`
- `manchester-united.svg`
- `real-madrid.svg`
- `juventus.svg`
- `al-nassr.svg`

Every crest has meaningful alt text and defensive `width`/`height` attributes.
Source, author/rights holder, copyright status, trademark status, the
identification-only disclaimer, and current-club references are recorded in
`app/www/ATTRIBUTIONS.md`.

The Manchester United and Real Madrid files are non-free marks hosted by
English Wikipedia. Review those two assets before public deployment outside an
identification/commentary context.

### Responsive presentation

`app/www/css.css` implements the club-history presentation:

- Desktop: two equal-height player cards; a connecting rail with three Messi
  stops and five Ronaldo stops.
- Below 1200 px: player profiles stack to preserve readable rail labels.
- Below 768 px: rails become two-column cards and the connecting line is
  removed.
- Below 340 px: club stops become one-column horizontal cards.
- Current clubs receive the player color, halo, and `Current chapter` badge.
- Portraits use fixed circular crops; crest containers preserve aspect ratio.
- The mobile navbar constrains the title so it cannot force page overflow.

## Brave Cache Incident and Fix

During user review, Brave showed the revised HTML with an older cached copy of
`css.css`. Portraits lost their circular presentation and SVG crests expanded
to their intrinsic dimensions, producing a very tall, broken layout.

The fix has two layers:

1. `app/app.R` versions the stylesheet URL as
   `css.css?v=20260811-wave1b`, forcing browsers to fetch the revised CSS.
2. Portrait and crest `<img>` elements carry explicit dimensions so a delayed
   stylesheet cannot expose giant intrinsic SVG sizes.

After restarting with `Rscript app/run.R`, the corrected page was reopened in
Brave with a fresh document URL.

## Verification Record

### R and data checks

- Parsed `app/app.R` and `app/R/mod_overview.R` successfully.
- Verified all eight calculated club counts listed above.
- Verified the Manchester United aggregate is 127.
- Verified the signed-power probe remains finite for negative scores at
  fractional K.
- Verified all eight SVG files exist, are non-empty, and contain SVG markup.
- `git diff --check` passes.

### Unchanged KPI baseline

No analytical calculations, bundle schemas, package dependencies, or public
data files changed. The Overview KPI values remain:

| KPI | Messi | Ronaldo |
|-----|------:|--------:|
| Weighted Goals per 90 | 0.1337 | 0.0384 |
| Raw Goals per 90 | 0.8954 | 0.8357 |
| Total Goals | 847 | 891 |
| Appearances | 1,031 | 1,170 |

### HTTP and browser checks

- `/`, `/css.css`, both player portraits, and all eight crest assets return
  HTTP 200.
- The versioned stylesheet endpoint
  `/css.css?v=20260811-wave1b` returns HTTP 200.
- Native MathML visually renders subscripts, superscripts, multiplication, and
  absolute-value bars without raw markup.
- At 1919 × 862, the club rail uses CSS Grid, crest medallions are 68 × 68 px,
  portraits are 176 × 176 px circles, and the page has no horizontal overflow.
- At 390 × 844, the rail wraps to two columns and the page has no horizontal
  overflow.
- There are no `.shiny-output-error` elements.
- The only browser-console error is the pre-existing `/favicon.ico` 404; it is
  unrelated to this revision and remains deferred to a polish wave.

## Files Changed in the Wave 1 Revision

| Path | Purpose |
|------|---------|
| `app/app.R` | Native MathML panel and versioned stylesheet link |
| `app/R/mod_overview.R` | Club metadata, server-calculated counts, accessible profile/rail UI, defensive image dimensions |
| `app/www/css.css` | Formula styling, player cards, desktop rail, responsive layouts, current-club treatment |
| `app/www/ATTRIBUTIONS.md` | Eight crest sources, legal status, disclaimer, current-club references |
| `app/www/img/clubs/*.svg` | Eight locally bundled club crests |
| `.opencode/plans/phase2-plan.md` | Corrected Wave 1 scope/status |
| `.opencode/plans/phase2-handoff.md` | This implementation and resume record |

## GitHub Delivery Record

- Repository: `batestguy/messi-vs-ronaldo-r`.
- Remote URL: `https://github.com/batestguy/messi-vs-ronaldo-r.git`.
- Visibility: public.
- Default branch: `main`.
- Local `main` tracks `origin/main`; the post-push ahead/behind count was
  `0 0`.
- GitHub associates commit `94d260c856c0a385f375c4fe5c8b01f5dc92050e`
  with the `batestguy` profile and commit email `batesthommie@gmail.com`.
- Repository content and commit history are publicly visible.

No force push or history rewrite was used.

## Global Reusable Skill

A machine-global Codex skill was created from the reusable parts of this work:

- Invocation: `$shiny-dashboard-wave-builder`.
- Location:
  `C:/Users/TOSHIBA/.codex/skills/shiny-dashboard-wave-builder/`.
- Main instructions: `SKILL.md`.
- Progressive verification reference:
  `references/verification-checklist.md`.
- UI metadata: `agents/openai.yaml`.

The skill covers review-gated bslib/Shiny implementation, data-backed UI,
offline MathML, licensed local assets, cache-safe responsive design, rendered
browser verification, handoff documentation, and explicitly authorized GitHub
delivery. It deliberately excludes this project's player-specific counts and
other domain facts.

The official `quick_validate.py` check reports `Skill is valid!`. A read-only
forward test also produced the correct workflow, preserved the analysis and
review-gate constraints, required desktop/mobile and runtime checks, and did
not edit the repository.

The global skill is installed on this machine and is not part of the project
repository or GitHub history.

## Closeout Rule

The project is complete. Keep all local services stopped and do not begin a new
phase unless the user explicitly reopens the project.


## Wave 2 — Weighting Lab Implementation Record

### User-visible result

The Weighting tab now answers: **Does the comparison remain stable when the
difficulty sensitivity K changes?** It contains:

- Four live headline cards for Messi weighted per 90, Ronaldo weighted per 90,
  the Messi−Ronaldo gap, and computed lead stability.
- A Plotly K-sensitivity hero curve with a solid Messi line, dashed Ronaldo
  line, zero reference, selected-K markers, direct end labels, and hover values.
- A grouped Reality Check comparing raw goals per 90 with selected-K weighted
  index units per 90.
- Normalized base-score densities that remain on K=1 and show player medians.
- Goal counts over fixed combined-dataset deciles, D1 easiest through D10
  hardest. Decile identities are assigned before penalty filtering.
- Interpretation copy that distinguishes index units from literal goals,
  discloses missing difficulty, explains valid negative outputs, and states
  that stability is a sensitivity result rather than a final verdict.

The sidebar is titled **Analysis controls**. It says Weighting updates
instantly and that **Update analysis** is reserved for the later inference tab.
Overview remains fixed and visibly says `Baseline: K=1 · penalties included`.

### Preserved contracts

- No bundle schema, public data, or dependency changed.
- The module consumes only `bundle$goals`, `bundle$valid_matches`, `state$K`,
  and `state$exclude_pen`.
- Weighted per 90 is
  `90 × Σ(sign(score) × abs(score)^K) / all valid appearance minutes`.
- Penalty exclusion changes goal numerators only. All 2,201 valid appearances,
  including 1,063 scoreless appearances, remain in denominators.
- Raw rates count every eligible goal. Weighted views omit only eligible goals
  with missing difficulty and disclose that difference.
- The 26-point `seq(0.5, 3, 0.1)` grid is precomputed for both penalty settings.
  Slider movement selects the stored point; it does not recalculate the grid or
  increment `boot_trigger`.
- Plot outputs are cached by their actual dependencies. Density and deciles
  depend only on the penalty setting; headline, curve, and Reality Check depend
  on K plus the penalty setting.

### Exact numerical verification

Bundle invariants passed:

- 1,738 goals.
- 2,201 valid appearances.
- 1,063 scoreless appearances.
- 1,735 non-missing difficulty scores and 3 missing.

At K=1 with penalties included, the unchanged baseline is:

| Metric | Messi | Ronaldo |
|---|---:|---:|
| Weighted index / 90 | 0.1337 | 0.0384 |
| Raw goals / 90 | 0.8954 | 0.8357 |

Signed-power probes were finite at K=0.5, 1, 1.5, and 3. At K=3 the weighted
rates correctly become negative: Messi −0.0009 and Ronaldo −0.1389 with
penalties included; Messi −0.0306 and Ronaldo −0.1066 with penalties excluded.
The stability result is **No lead change across K=0.5–3.0** for both penalty
settings.

### Source and runtime verification

- Parsed `app/app.R`, `app/R/mod_overview.R`, and
  `app/R/mod_weighting.R` successfully with a temporary plain `Rscript`
  verification script.
- Render-tested all Wave 2 outputs at K=0.5, 1, 1.5, and 3 for both penalty
  settings. `boot_trigger` remained zero.
- The first live browser session exposed a Shiny-only initialization error:
  `state$bundle` was read outside a reactive consumer. Both static bundle reads
  now use `shiny::isolate()`, and all dynamic outputs render live.
- `/`, `/css.css?v=20260811-wave2`, and both player portraits returned HTTP
  200 with expected content types and non-empty bodies.
- At 1919×862, four headline columns, the 8/4 hero split, the 5/7 detail split,
  and all four Plotly charts rendered with zero horizontal overflow and zero
  `.shiny-output-error` elements. The four measured plot sizes were 1042×370,
  640×320, 908×336, and 1592×350 px.
- Visual desktop inspection confirmed readable cards, direct line labels,
  legends, the zero line, and the lower decile/caveat layout.
- Live control checks confirmed K=3 negative values and penalty-excluded values,
  plus the unchanged stability status and updated density/decile subsets.
- The only console error remained the documented `/favicon.ico` 404.

### Final review-gate verification

The original decile trace exposed literal Plotly `customdata` placeholders in
the tooltip. It was replaced with preformatted hover text containing decile,
base-score range, goal count, and share of the player's eligible goals. The
module render test passed after that repair and `app/run.R` was restarted.

The two deferred checks passed on 2026-08-12:

- The live Messi D10 tooltip showed base-score range `0.993 to 1.943`, 99
  goals, and 11.7% of eligible Messi goals with penalties included. With
  penalties excluded it retained the same fixed range and updated to 81 goals
  and 11.0%. No literal `%{customdata[...]}` placeholder appeared.
- At 390×844, the headline, hero, and detail grids each resolved to one
  column. All four headline cards were 343 px wide. The sensitivity, Reality
  Check, density, and decile plots were 329 px wide and respectively 370, 320,
  320, and 350 px high.
- Every Plotly legend remained visible with both player labels. Document,
  body, and navbar scroll widths were all 390 px, so there was no horizontal
  overflow. All four Plotly outputs were visible and there were zero
  `.shiny-output-error` elements.
- A 390×844 screenshot was captured for inspection and removed during final
  cleanup. The only console error remained the documented `/favicon.ico` 404.

No app-code or CSS repair was required during this final recheck.

### Files changed for Wave 2

| Path | Purpose |
|---|---|
| `app/R/mod_weighting.R` | Signed-power grid, stability logic, four Plotly views, accessible summaries, and caveats |
| `app/R/mod_overview.R` | Visible fixed-baseline label |
| `app/app.R` | Analysis-control wording and Wave 2 stylesheet version |
| `app/www/css.css` | Weighting Lab desktop/mobile presentation |
| `.opencode/plans/phase2-plan.md` | Wave 2 status and completed scope |
| `.opencode/plans/phase2-handoff.md` | This implementation and verification record |

No commit, push, deployment, bundle rebuild, dependency installation, or
repository-visibility change was performed.

## Wave 3 — Head-to-Head Implementation Record

### User-visible result

The Head-to-Head tab now provides an age-aligned comparison of career
trajectories, opponent quality, and penalty dependency:

- Four selected-scope cards show Messi and Ronaldo weighted index per 90, the
  Messi−Ronaldo gap, and weighted-goal coverage. A player with no appearances
  displays `N/A`; a player with appearances but no eligible goals displays
  `0.0000`.
- Competition choices are the 31 valid-match labels plus `All competitions`.
  Venue choices are `All venues`, `Home`, `Away`, and `Neutral`. These filters
  are stored in shared reactive state but affect only Head-to-Head in Wave 3.
- The trajectory card switches between cumulative selected-K weighted index
  and rolling 30-filtered-appearance weighted index per 90, and between age
  and calendar-date axes. Birth dates are static display metadata: Messi
  1987-06-24 and Ronaldo 1985-02-05. Rolling values begin at observation 30;
  the age-30 guide appears only on the age axis.
- The opponent-Elo chart uses one unjittered marker per eligible goal. Its
  tooltip discloses player, date, opponent, competition, venue, Elo, base
  score, selected-K contribution, and penalty status. Player-specific LOESS
  curves are descriptive, have no confidence band, and are suppressed below
  10 goals or 5 distinct Elo values.
- The stacked composition chart always shows raw penalty/open-play counts and
  shares. When penalties are excluded, their segment remains visible but is
  muted and labeled as excluded from weighted calculations.

### Preserved analytical contracts

- Goal contributions are joined to all valid appearances by `Player + Date +
  Comp + Round + Opp_clean`. Scoreless appearances receive zero and remain in
  every selected-scope denominator.
- Competition and venue apply consistently to goal numerators and valid-match
  minutes. Penalty exclusion changes goal contributions only.
- Weighted outputs use `sign(Difficulty_Score) ×
  abs(Difficulty_Score)^K`; missing-difficulty goals remain in the raw penalty
  composition but are excluded and disclosed in weighted views.
- Cumulative and rolling trajectories restart within the selected filter
  scope. The rolling denominator is the minutes in the current 30 filtered
  appearances.
- Empty and one-player scopes render explanatory states rather than Shiny
  errors. LOESS is descriptive; Wave 3 adds no bootstrap, confidence interval,
  effect size, p-value, or other Wave 4 inference.
- Overview and Weighting are unchanged by competition/venue changes, and all
  Head-to-Head interactions leave `boot_trigger` unchanged.
- No bundle schema, source data, dependency, FAMD output, or public API changed.

### Exact numerical verification

The unchanged bundle invariants passed: 1,738 goals, 2,201 valid appearances,
181,081 minutes, 1,063 scoreless appearances, and 3 missing difficulty scores.
The match key is unique in the valid appearances. The three goal keys without
a matching appearance are the already documented 2026 World Cup snapshot gap.

At K=1, all competitions, all venues, and penalties included:

| Metric | Messi | Ronaldo |
|---|---:|---:|
| Weighted index / 90 | 0.1337 | 0.0384 |
| Cumulative trajectory endpoint | 126.4402 | 40.9562 |
| Rolling-30 endpoint | −0.0474 | 0.0239 |
| Eligible opponent-Elo markers | 845 | 890 |
| Penalty goals | 106 | 169 |
| Open-play goals | 741 | 722 |

Signed-power outputs remained finite at K=0.5, 1.0, 1.5, and 3.0 with both
penalty settings, both trajectory measures, and both axes.

Representative scopes also passed:

| Scope | Messi | Ronaldo | Expected state |
|---|---:|---:|---|
| Champions Lg + Away | 81 apps / 49 goals | 92 apps / 63 goals | Both players render |
| World Cup + Neutral | 29 apps / 21 goals | 25 apps / 11 goals | Both players render |
| MLS + All venues | 76 apps / 69 goals | 0 apps | Ronaldo displays `N/A` |
| FA Cup + All venues | 0 apps | 1 app / 0 goals | Messi `N/A`; Ronaldo `0.0000` |
| MLS + Neutral | 0 apps | 0 apps | Explanatory empty state |

### Source, HTTP, and browser verification

- Parsed `app/app.R`, `app/R/mod_overview.R`,
  `app/R/mod_weighting.R`, and `app/R/mod_head2head.R` using a plain
  `Rscript` verification script.
- Render-tested every Head-to-Head output over the K, penalty, measure, axis,
  sparse-player, and empty-scope cases above. The only R messages were package
  build-version warnings.
- Launched only through `Rscript app/run.R`. `/`,
  `/css.css?v=20260812-wave3`, and both player portraits returned HTTP 200
  with expected content types and non-empty responses.
- At 1919×862, the four-card row and two-column detail layout rendered with
  document/body widths of 1919 px, zero horizontal overflow, and zero
  `.shiny-output-error` elements.
- At 390×844, headline cards, controls, and charts stacked to one column;
  document/body/viewport widths were all 390 px, with zero horizontal overflow
  and zero `.shiny-output-error` elements. The age-30 label was repositioned
  below the data so it does not collide with the legend.
- Live interaction confirmed penalty-excluded values and labels, Champions Lg
  + Away filtering, rolling/date switching, the conditional age-30 guide, all
  Plotly legends, and a fully formatted goal tooltip. Temporary browser
  screenshots were inspected and removed during cleanup.
- The only console error is the pre-existing `/favicon.ico` 404, deferred to a
  later polish wave.

### Files changed for Wave 3

| Path | Purpose |
|---|---|
| `app/R/mod_head2head.R` | Selected-scope metrics, trajectories, Elo scatter/LOESS, penalty composition, summaries, caveats, caching, and sparse states |
| `app/app.R` | Competition/venue controls, shared state, Wave 3 help text, and stylesheet token |
| `app/www/css.css` | Responsive Head-to-Head presentation for desktop and mobile |
| `.opencode/plans/phase2-plan.md` | Wave 3 completed scope and review status |
| `.opencode/plans/phase2-handoff.md` | This implementation, verification, and resume record |

No commit, push, deployment, bundle rebuild, dependency installation, Wave 4
work, or repository-visibility change was performed.

### Wave 3 study guide delivery

`scripts/build_statistics_guide.py` now verifies and teaches the completed
Wave 3 behavior in addition to the earlier data, FAMD, and Weighting material.
It adds dedicated chapters for age/date trajectories, rolling-30 and
cumulative formulas, unbinned opponent-Elo markers and descriptive LOESS,
penalty dependency, filter scope, `N/A` versus zero, and the Wave 4 boundary.

The updated intermediate Word file was exported to
`output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf` and then deleted at the
user's request. The retained PDF has 23 pages, contains all required Wave 3
sections and exact verified endpoints, and passed text extraction, page-bound,
font, pagination, and rendered visual checks. Temporary render files were also
removed.

## Wave 4 — Inference and Uncertainty Implementation Record

### User-visible result

The Inference tab now runs only from the global `Update analysis` button:

- A click freezes K, penalty inclusion, competition, and venue. Those frozen
  values remain visible above the results.
- Later control changes do not recalculate inference. They display a
  `Controls changed` status while the previous cards, plot, and tables remain
  intact until another click.
- Results are cached per frozen four-control snapshot within the Shiny
  session, so revisiting an already-run combination restores its analysis.
- Four cards report the observed ratio-of-sums weighted-index gap per 90, the
  95% percentile interval, the bootstrap share above zero, and conventional
  match-level Cohen's d.
- The Plotly density shows all 10,000 resampled differences through a density
  curve, shaded percentile band, zero reference, observed-gap line, formatted
  tooltip, and a complete accessible text summary.
- The subgroup selector switches between the five career eras and five
  competition families. Both views are precomputed during the same click.
  Tables use semantic captions, column headers, and row headers.
- Rows with fewer than 30 appearances for either player are marked
  `Sparse`. Descriptive rates display whenever appearances exist; intervals
  and d require at least two appearances for both players.
- Empty and one-player scopes show explanatory states and `N/A`; a genuine
  zero contribution remains `0.0000`.

### Analytical implementation and contracts

- Eligible goals are aggregated and joined to every selected valid appearance
  by `Player + Date + Comp + Round + Opp_clean`. The appearance key is
  unique. Scoreless appearances contribute zero and remain in all
  denominators.
- Each bootstrap replicate independently samples Messi's and Ronaldo's
  appearance rows with replacement, preserving the selected-scope counts for
  both players. The statistic is
  `90 * sum(weighted contributions) / sum(minutes)`; the recorded difference
  is Messi minus Ronaldo.
- Every overall and subgroup bootstrap uses 10,000 resamples and seed
  `20260812`. Exactly 10,000 finite differences are required before results
  render.
- Selected-K contributions use
  `sign(Difficulty_Score) * abs(Difficulty_Score)^K`. Missing-difficulty
  goals add nothing to weighted numerators and remain disclosed. Penalty
  exclusion changes contributions only.
- Cohen's d is independently calculated from appearance-level weighted rates
  using the conventional pooled standard deviation. It complements but does
  not redefine the primary ratio-of-sums estimator.
- Competition family uses the existing bundle mapping. Valid-match
  competition labels without a goal-derived mapping are assigned `Other`,
  matching the bundle builder's fallback.
- No p-values, Bonferroni adjustments, binary significance labels, or winner
  flags were added. No trajectory regression or Wave 5 feature was added.
- The analysis bundle, public data, FAMD artifact, six runtime dependencies,
  and module interfaces remain unchanged.

### Exact default results

At K = 1, penalties included, all competitions, and all venues:

| Result | Value |
|---|---:|
| Messi weighted index / 90 | 0.1336718582 |
| Ronaldo weighted index / 90 | 0.0384164403 |
| Observed Messi-Ronaldo gap / 90 | +0.0952554179 |
| 95% percentile interval | [-0.0119600327, +0.1999414634] |
| Bootstrap P(gap > 0) | 0.9600000000 |
| Match-level Cohen's d | +0.0899711631 |
| Bootstrap differences | 10,000 finite |

The interval crosses zero; this is displayed numerically without turning it
into a binary significance statement.

Default career-era results:

| Era | Messi apps / rate | Ronaldo apps / rate | Gap | 95% interval | d |
|---|---:|---:|---:|---:|---:|
| Rise (2002-08) | 102 / 0.0963 | 274 / 0.0677 | +0.0286 | [-0.1915, +0.2416] | +0.142 |
| Peak (2009-14) | 288 / 0.0005 | 300 / 0.0128 | -0.0124 | [-0.2397, +0.2181] | -0.024 |
| Prime (2015-18) | 248 / 0.1936 | 224 / 0.1344 | +0.0592 | [-0.1890, +0.3123] | +0.042 |
| Transition (2019-22) | 208 / 0.2246 | 207 / 0.0598 | +0.1649 | [-0.0653, +0.3909] | +0.162 |
| Late (2023-26) | 185 / 0.1701 | 165 / -0.1192 | +0.2893 | [+0.0307, +0.5535] | +0.267 |

Default competition-family results:

| Family | Messi apps / rate | Ronaldo apps / rate | Gap | 95% interval | d | Count |
|---|---:|---:|---:|---:|---:|---|
| League | 654 / 0.0013 | 758 / -0.0106 | +0.0120 | [-0.1264, +0.1500] | +0.043 | adequate |
| Continental | 192 / 0.1744 | 198 / 0.0985 | +0.0759 | [-0.1752, +0.3291] | +0.024 | adequate |
| Domestic cup | 36 / 0.6210 | 14 / -0.1330 | +0.7540 | [+0.2088, +1.3315] | +0.756 | sparse |
| International | 137 / 0.5416 | 196 / 0.1662 | +0.3754 | [+0.1174, +0.6423] | +0.330 | adequate |
| Other | 12 / 0.3401 | 4 / 0.4289 | -0.0888 | [-2.0558, +0.5513] | -0.686 | sparse |

### Source and numerical verification

- Reasserted 1,738 goals, 2,201 valid appearances, 181,081 minutes, 1,063
  scoreless appearances, and three missing difficulty scores.
- `tests/wave4_inference_checks.R` verifies deterministic repeated
  distributions, independently preserved player sample sizes (1,031 and
  1,170 at default), finite results, ordered bounds, probability range,
  independent ratio-of-sums and Cohen's d formulas, subgroup membership,
  subgroup denominator totals, and sparse flags.
- Signed-power outputs remain finite at K 0.5, 1.0, 1.5, and 3.0 under both
  penalty settings, while all 181,081 minutes remain in the default-scope
  denominator.
- Representative scopes passed: Champions Lg/Away, World Cup/Neutral, MLS,
  FA Cup, and MLS/Neutral. The last three exercise one-player and empty
  inference suppression. An exact Champions Lg/Away scope contains only the
  Continental family row.
- The module test confirms control changes alone leave results null and
  `boot_trigger` at zero; the click increments the trigger, freezes the
  snapshot, and later control changes make the stale-state comparison false
  without replacing the stored result.
- Modified R files parse under plain `Rscript`; `git diff --check` passes.

### HTTP and rendered browser verification

- Launched only with `Rscript app/run.R`.
- `/`, `/css.css?v=20260812-wave4`, and both player portraits returned
  HTTP 200 with correct non-empty content types.
- At 1919x862, the four cards resolve to four equal columns (395.906 px each),
  the density renders with interval shading and both reference lines, the
  semantic era/family tables render, and document/body widths equal 1919 px.
- At 390x844, cards resolve to one 342.667 px column, document/body widths
  equal the 390 px viewport, the density remains legible, and the 1,040 px
  subgroup table scrolls within its 327 px wrapper without page overflow.
- Live interaction confirmed the native Shiny progress state, exact default
  cards and accessible density summary, stale-state notice, and immediate
  switching to the precomputed competition-family table with correct sparse
  labels.
- There were zero `.shiny-output-error` elements and no Shiny runtime errors.
  The only console error remains the pre-existing `/favicon.ico` 404.
- Temporary Playwright screenshots, snapshots, session files, and app logs
  were removed after inspection.

### Wave 4 study guide

`scripts/build_statistics_guide.py` now extracts and asserts the exact
seeded Wave 4 values. It adds bootstrap formulas, percentile-interval
interpretation, directional probability, Cohen's d, era/family subgroup
tables, sparse-scope cautions, and the Wave 4 stopping point.

The retained
`output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf` has 26 portrait
pages. All required text and exact values were extracted successfully, no
page was empty or out of bounds, fonts and pagination were present, and every
rendered page was visually inspected. The Word intermediate and all temporary
PNG/JPEG render files were deleted.

### Files changed for Wave 4

| Path | Purpose |
|---|---|
| `app/R/mod_inference.R` | Frozen snapshots, match joins, deterministic bootstrap, cards, density, subgroup tables, states, and test hooks |
| `app/app.R` | Wave 4 control copy and stylesheet version |
| `app/www/css.css` | Responsive Inference layout, cards, statuses, plot, and scroll-contained table |
| `tests/wave4_inference_checks.R` | Deterministic numerical, scope, edge-state, and reactive-trigger checks |
| `scripts/build_statistics_guide.py` | Wave 4 facts, formulas, teaching chapters, and document assertions |
| `output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf` | Retained verified 26-page study guide |
| `.opencode/plans/phase2-plan.md` | Wave 4 completed scope and review status |
| `.opencode/plans/phase2-handoff.md` | This implementation and resume record |

No commit, push, deployment, bundle rebuild, dependency installation, or
Wave 5 work was performed during the Wave 4 implementation.

## Wave 5 — Methodology / Summary / Raw Data Implementation Record

### Methodology

- `app/R/mod_methodology.R` now gives a semantic, five-section account of
  collection, the single global FAMD, signed-power weighting, match-level
  bootstrap inference, and limitations.
- Native MathML keeps every formula offline and accessible. The page reports
  the exact 1,738 goals, 2,201 valid appearances, 181,081 minutes, 1,063
  scoreless appearances, three missing difficulty scores, 82.1% direct Elo
  coverage, 90.6% direct-or-league coverage, and 483 xG matches.
- Stored FAMD metadata is presented without recomputation: Dim 1 explains
  25.2968%, with contributions Opponent Elo 0.8013%, Venue 48.6372%,
  Competition Stage 2.2663%, and Is Away 48.2952%.

### Summary

- `app/R/mod_summary.R` provides a fixed K=1, penalties-included,
  all-competition/all-venue reference and a separate live scope that reacts
  immediately to K, penalty, competition, and venue controls.
- Both views use the same 14-row order: overall; five career eras; five
  competition families; and Home, Away, Neutral. Each row includes both
  players' appearances/minutes, weighted index rates and Messi-minus-Ronaldo
  gap, and raw rates and gap.
- The fixed overall values are Messi 0.1337 and Ronaldo 0.0384 weighted index
  units per 90 (gap +0.0953), beside raw 0.8954 and 0.8357 (gap +0.0597).
- Verified venue rows are:

| Venue | Messi apps / min | Ronaldo apps / min | Weighted M / R / gap | Raw M / R / gap |
|---|---:|---:|---:|---:|
| Home | 495 / 40,525 | 572 / 47,198 | 0.9184 / 0.7791 / +0.1393 | 1.0638 / 0.9325 / +0.1313 |
| Away | 461 / 38,180 | 538 / 43,531 | -0.8123 / -0.8450 / +0.0327 | 0.7472 / 0.7588 / -0.0115 |
| Neutral | 75 / 6,426 | 60 / 5,221 | 0.8056 / 0.7080 / +0.0976 | 0.7143 / 0.6033 / +0.1110 |

- One-player and empty scopes show explanatory states. `N/A` is never
  formatted as a genuine zero, and changing live Summary controls does not
  increment or depend on `boot_trigger`.

### Raw Data

- `app/R/mod_data.R` renders all 1,738 × 29 source fields through DT with
  global/per-column search, sorting, pagination, horizontal containment, and
  a source-identical download. The table is deliberately unaffected by every
  sidebar control.
- `app/app.R` loads `app/data/goals_master_final.csv` as character data,
  and `scripts/08_prepare_analysis.R` copies the processed source exactly
  whenever the established bundle builder runs. No bundle schema changed.
- Processed source, app copy, and browser download are all 431,529 bytes with
  MD5 `c43c3f995b1f301b4328c846eab2cf27` and SHA-256
  `983AB33C64E49BD40050E274B2B28B46F35F080116F952F3F5129C57D1459E8E`.

### Verification

- `Rscript tests/wave5_content_checks.R` passed all source/schema, exact
  count, 14-row membership/order, denominator, K, penalty, representative
  scope, N/A/zero, module UI, and server checks.
- `Rscript tests/wave4_inference_checks.R` also passed: default gap
  0.0952554179, seeded interval [-0.0119600327, 0.1999414634],
  P(gap > 0) 0.9600000000, and Cohen's d 0.0899711631.
- The app was launched only through `Rscript app/run.R`. Root, versioned CSS,
  and both portraits return HTTP 200. Desktop 1919×862 and mobile 390×844
  checks found no page overflow or Shiny output errors; wide Summary and Raw
  Data tables scroll inside their containers. The fresh final browser console
  has zero errors and warnings.
- Live browser interaction verified Summary control reactivity and fixed
  baseline isolation; Raw Data global/column search, date sorting, pagination,
  control independence, and byte-identical download; and semantic headings,
  tables, captions, row headers, MathML labels, and status text.

### Wave 5 study guide

`scripts/build_statistics_guide.py` now extracts and asserts Wave 5 Summary
and Raw Data facts and adds three pages for the complete methodology map, the
fixed/venue comparison, and exact source transparency. The retained
`output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf` has 29 portrait
letter pages. All pages have extractable content, no text blocks are out of
bounds, required Wave 5 text and hashes are present, and every page was
rendered and visually inspected. The Word intermediate and temporary render
files were deleted.

### Files changed for Wave 5

| Path | Purpose |
|---|---|
| `app/R/mod_methodology.R` | Full data-backed methodology and accessible offline math |
| `app/R/mod_summary.R` | Fixed and live 14-row weighted/raw comparison tables |
| `app/R/mod_data.R` | Exact-source interactive DT and download |
| `app/app.R` | Raw CSV load/state, Wave 5 control copy, CSS token, offline favicon |
| `app/www/css.css` | Responsive Methodology, Summary, and Raw Data layouts |
| `app/data/goals_master_final.csv` | Exact app copy of the 1,738 × 29 processed source |
| `scripts/08_prepare_analysis.R` | Exact CSV copy step; bundle schema unchanged |
| `tests/wave5_content_checks.R` | Wave 5 numerical, scope, schema, and module regression checks |
| `scripts/build_statistics_guide.py` | Wave 5 facts, pages, assertions, and 29-page pagination |
| `output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf` | Retained verified Wave 5 study guide |
| `.opencode/plans/phase2-plan.md` | Wave 5 completed scope and review status |
| `.opencode/plans/phase2-handoff.md` | This implementation and resume record |

No commit, push, deployment, bundle rebuild, dependency installation, or
Wave 6 work was performed. The app was stopped after final verification.

## Wave 6 — Polish Implementation Record

### Loading, caching, and shell behavior

- `app/app.R` uses native `shiny::busyIndicatorOptions()`: delayed dots on
  recalculating outputs, a restrained fade, and a Messi/teal/Ronaldo page
  pulse. No `waiter` dependency was introduced.
- The sidebar now uses `open = "desktop"`, so it opens at desktop width and
  initializes collapsed at mobile width.
- The Inference density is now wrapped in `shiny::bindCache()`, keyed by
  `bundle$meta$built_at` and the frozen K, penalty, competition, and venue
  snapshot. Together with the existing Weighting and Head-to-Head caches,
  all eight Plotly outputs are cached.
- `app/www/app.js` is local and versioned as
  `app.js?v=20260812-wave6`. It adds a skip link and focusable main target,
  and debounces polite `Updating dashboard…` / `Dashboard updated.`
  announcements around Shiny busy/idle events.

### Visual, responsive, and accessibility polish

- `app/www/css.css` adds explicit `:focus-visible` treatment, safe-area
  spacing, internal scroll containment, tabular numerals, narrower mobile
  formula sizing, compact mobile Plotly controls, balanced headings, and a
  reduced-motion mode that suppresses animated loading treatments.
- The static cache tokens are `css.css?v=20260812-wave6` and
  `app.js?v=20260812-wave6`; the shell also exposes a local theme color and
  keeps the trophy decorative.
- The implementation is deliberately conservative: content, calculations,
  module APIs, bundle schema, source files, global FAMD, and six runtime
  packages are unchanged.

### Automated verification

- Plain-R parsing passed for `app/app.R`, every module, and the Wave 6 test.
  `node --check app/www/app.js` also passed.
- `Rscript tests/wave6_polish_checks.R` passed and proves 8/8 Plotly
  `renderPlotly` outputs are covered by `bindCache`, verifies the shell,
  accessibility, responsive, dependency, interface, schema, and deterministic
  cache-key contracts, and reasserts the default +0.0952554179 gap.
- `Rscript tests/wave5_content_checks.R` passed with the source/app CSV MD5
  `c43c3f995b1f301b4328c846eab2cf27`.
- `Rscript tests/wave4_inference_checks.R` passed: 10,000 finite seeded
  differences, CI [-0.0119600327, +0.1999414634], P(gap > 0) 0.96, and
  Cohen's d +0.0899711631.
- `git diff --check` passed. R emitted only the established harmless package
  build-version warnings (installed packages built under R 4.5.3).

### HTTP and rendered browser verification

- The app was launched only with `Rscript app/run.R`.
- Root, `/css.css?v=20260812-wave6`,
  `/app.js?v=20260812-wave6`, and `/img/messi.jpg` returned HTTP 200.
- Desktop 1919×862 checks exercised every tab. Body width stayed exactly
  1919 px, the sidebar was open, all headings/tables/download controls
  rendered, and the Inference cards showed +0.0953,
  [-0.0120, +0.1999], 0.960, and +0.090.
- The native progress notification exposed the current bootstrap stage while
  the polite live region announced `Updating dashboard…`; it cleared after
  completion. The accessible density summary reported all 10,000 finite
  differences and the exact rounded interval/probability.
- Mobile 390×844, tablet 768×1024, and narrow 320×700 checks had no page
  overflow. At 390 px, the sidebar was about 359 px wide and its signed-power
  formula had no internal overflow. The 1,040 px Inference table scrolled
  inside a 341 px wrapper; the 1,330 px Summary table did likewise.
- Keyboard focus made the skip link visible with a solid focus outline, and
  activation moved focus to `#dashboard-main`. The final browser console
  contained zero warnings and zero errors; no failed HTTP requests or Shiny
  output errors were found.

### Files changed for Wave 6

| Path | Purpose |
|---|---|
| `app/app.R` | Native loading options, desktop/mobile sidebar policy, versioned JS/CSS, live region, shell metadata |
| `app/R/mod_inference.R` | Frozen-snapshot/bundle-stamp density cache key and `bindCache` wrapper |
| `app/www/app.js` | Skip-link/main-focus behavior and debounced polite loading announcements |
| `app/www/css.css` | Focus, responsive, safe-area, scrolling, hierarchy, and reduced-motion polish |
| `tests/wave6_polish_checks.R` | Wave 6 shell, cache, accessibility, schema, API, and baseline regression checks |
| `tests/wave5_content_checks.R` | Current static CSS token expectation for the retained Wave 5 regression |
| `.opencode/plans/phase2-plan.md` | Wave 6 completed scope and review status |
| `.opencode/plans/phase2-handoff.md` | This implementation and resume record |

The original Wave 6 implementation did not require a PDF change because it was
presentation-only. On 2026-08-15, the user explicitly requested a refreshed
plain-language guide through the current checkpoint; that post-gate
documentation work is recorded below. No app calculation changed.

## Post-Wave 6 Documentation and Skill Refresh — 2026-08-15

- `scripts/build_statistics_guide.py` now verifies Wave 6 source contracts
  before writing: native busy feedback, desktop/mobile sidebar policy,
  versioned local CSS/JavaScript, eight cached Plotly outputs, skip-link/live
  announcements, and reduced-motion CSS.
- The guide adds page 30, **How the finished interface supports careful
  reading**, and stops at the Wave 6 review gate. It explicitly separates
  usability/performance work from unchanged data and statistical methods.
- Matching retained outputs are
  `output/word/Messi_vs_Ronaldo_Statistics_Explained.docx` and
  `output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf`.
- LibreOffice produced the PDF from the Word source. The paired validator
  reports 30 PDF pages and 60 real Word headings; all 30 pages have content,
  612×792-point portrait geometry, in-bounds text blocks, page footers,
  matching substantive tokens, and six embedded fonts.
- Every page was rendered locally. Five six-page contact sheets plus detailed
  checks of the changed contents, Raw Data, and Wave 6 pages showed no clipping,
  overlap, broken tables, broken glyphs, empty pages, or inconsistent
  pagination. Temporary renders are removed after verification.
- The reusable `$simple-explanation-docs` package is valid at both
  `.agents/skills/simple-explanation-docs/` and
  `C:/Users/TOSHIBA/.codex/skills/simple-explanation-docs/`. `SKILL.md`, the
  content reference, paired-output validator, and `agents/openai.yaml` have
  identical SHA-256 hashes in both copies.
- Wave 4, Wave 5, and Wave 6 regression suites pass unchanged. The seeded
  default remains gap `+0.0952554179`, interval
  `[-0.0119600327, +0.1999414634]`, probability `0.96`, and Cohen's d
  `+0.0899711631`.
- The local preview was launched only through `Rscript app/run.R`. Root,
  `css.css?v=20260815-review1`, `app.js?v=20260812-wave6`, and both player
  portraits returned HTTP 200 with non-empty expected content types. The
  system default browser was opened to `http://127.0.0.1:3838` for user-led
  navigation and change detection, and the R process was left running.

This refresh does not authorize a commit, push, deployment, bundle rebuild,
dependency change, Docker/Wave 7 work, or source-data change.

## Post-Wave 6 Local Navigation Review Repair — 2026-08-15

- The user screenshot exposed a presentation defect: all seven tab elements
  existed and were clickable, but the brand and inactive tab labels inherited
  white text on the white navbar. Only the active tab was visible.
- `app/www/css.css` now gives the navbar brand, inactive tabs, active tab,
  hover/focus states, and both desktop/mobile navigation controls explicit
  readable colors. `app/app.R` uses `css.css?v=20260815-review1`; the Wave 5,
  Wave 6, and guide source-contract checks expect the same token.
- Desktop 1919×862 computed colors are dark brand `rgb(23, 32, 42)`, inactive
  tabs `rgb(67, 87, 106)`, and active teal `rgb(28, 124, 125)`. All seven tabs
  are visible and the page width is exactly 1919 px.
- Every page was opened successfully with zero Shiny output errors: Overview,
  Weighting, Head-to-Head, Inference, Methodology, Summary, and Raw Data.
- Live controls were exercised and restored to K 1.0, penalties included, all
  competitions, and all venues. Penalty exclusion changed the Weighting gap
  from +0.0953 to +0.0600; Champions Lg/Away updated Head-to-Head immediately.
- `Update analysis` refreshed the frozen default Inference snapshot to 2,201
  appearances and 181,081 minutes with gap +0.0953, interval
  [-0.0120, +0.1999], probability 0.960, and Cohen''s d +0.090. Changing K
  showed the stale-state notice without rerunning; restoring K 1.0 matched the
  clicked snapshot again.
- Summary reproduced the fixed baseline, and Raw Data search reduced 1,738
  rows to 891 Ronaldo goals before clearing back to all 1,738.
- At 390×844, the `Toggle navigation` button opens all seven page links, the
  mobile document width remains 390 px, and the navigation control is dark.
  The final browser console contains zero errors and zero warnings.

This was a Wave 6 review repair only. It did not change data, calculations,
dependencies, module interfaces, the guide contents, or the review gate, and
it does not authorize Wave 7.

## Resolved Environment Decision — No renv

renv was removed on 2026-08-09. `renv.lock`, `renv/`, and `.Rprofile` are gone;
do not recreate them. Wave 7 pins its six runtime packages through a dated
Posit PPM snapshot. The full rationale is in `AGENTS.md` under *On renv*.

## Wave 7 — Docker Implementation and Verification Record

### Container build and runtime contract

- `Dockerfile` is a two-stage build pinned to
  `rocker/shiny-verse:4.5.0@sha256:ccafdf812938dc85891b198f0728c8bf1706f1b0b7558b9fe696e98eb116056a`.
- The package stage installs only `shiny`, `bslib`, `data.table`, `htmltools`,
  `plotly`, and `DT` from the dated 2026-08-09 Posit PPM snapshot.
- `app/Rprofile.container` puts `/opt/messi-library` first only inside the
  image. Local D: launches still use the normal user library and no project
  `.Rprofile` or renv was introduced.
- `app/run.R` accepts validated `SHINY_HOST`/`SHINY_PORT` values, keeps the
  established local defaults, detects occupied port 3838, and emits structured
  JSON startup/failure records. The container sets `0.0.0.0:3838`; local use
  remains `127.0.0.1:3838` through `Rscript app/run.R`.
- `tests/wave7_container_checks.R` verifies the pinned image, app-only context,
  six-package contract, non-root runtime, health check, launch path, unchanged
  bundle schema, source counts, signed power, and all-valid-minute denominator.
  `tests/wave7_runtime_probe.R` verifies the installed package versions and
  exclusion of scraping/FAMD packages inside the running image.

### Exact verified results

- The C: staging context was hash-matched to D: before build: 28 files,
  1,978,126 bytes.
- Final image ID/digest:
  `sha256:7208f22dbc8fe13386977e55c3afd0524c1daea5eabc414bf8159d8b74d9d91f`;
  size 786,851,392 bytes.
- Runtime library order began with `/opt/messi-library`. Loaded versions were
  shiny 1.14.0, bslib 0.12.0, data.table 1.18.4, htmltools 0.5.9,
  plotly 4.12.1, and DT 0.34.0. FactoMineR and worldfootballR were absent.
- The container ran as UID/GID 997 (`shiny`) with 2 GB memory, one CPU,
  `CapDrop=[ALL]`, and `no-new-privileges=true`; its health status was healthy.
- Logs contained one JSON `app_start` record. Root,
  `css.css?v=20260815-review1`, `app.js`, `/img/messi.jpg`, and
  `/img/ronaldo.jpg` returned HTTP 200.
- Desktop 1919×862 and mobile 390×844 browser checks exercised all seven tabs,
  Weighting penalty behavior, Champions Lg/Away Head-to-Head filtering,
  button-triggered and stale-state Inference, Methodology, Summary, and Raw
  Data search (1,738 → 891 → 1,738). Both viewports had exact document width,
  zero Shiny output errors, and zero browser-console warnings/errors.
- The default frozen Inference remained gap +0.0953, interval
  [-0.0120, +0.1999], probability 0.960, and Cohen's d +0.090. The Wave 4–7
  host regression suite passed; the exact source CSV MD5 remains
  `c43c3f995b1f301b4328c846eab2cf27`.
- Docker Scout was not run because its external service could upload the
  private local image. No source, package, or image was transmitted.

### Disposable C: workspace cleanup

The temporary location was
`C:\Users\TOSHIBA\AppData\Local\MessivsRonaldoR\wave7-build-context`.
After verification, the named test container, tagged final image, three exact
untagged earlier Wave 7 image IDs, dedicated `messi-wave7-builder`, temporary
browser artifacts, staging directory, and its empty parent were removed. A
final inventory found no Wave 7 container, image, builder, C: path, or browser
artifact. Only the general Docker Desktop/buildkit installation remains.

After cleanup, the canonical D: app was relaunched only through
`Rscript app/run.R`; `http://127.0.0.1:3838/` returned HTTP 200 and was opened
in the user's default browser for review. Stop that R process when the review
session is finished.

### Wave 7 gate

No commit, push, deployment, renv restoration, source-data change, bundle
rebuild, or Wave 8 work was performed. The next possible wave is Wave 8
(shinyapps.io deployment) and requires a new explicit user instruction.

## Wave 8 — Public Deployment and Verification Record

### Deployment implementation

- `scripts/09_deploy_shinyapps.R` fixes the public app name to
  `messi-vs-ronaldo-r` and the server to `shinyapps.io`.
- Its upload allowlist contains exactly 24 files (1,971,888 bytes after the
  reviewed Head-to-Head copy correction): `app.R`, eight module/theme files,
  13 local assets, and the two required data files. `run.R`,
  `Rprofile.container`, Docker files, analysis scripts, documentation, tests,
  secrets, deployment records, and raw development data are excluded.
- `rsconnect::appDependencies()` discovers the six runtime packages: shiny,
  bslib, data.table, htmltools, plotly, and DT. FactoMineR, worldfootballR,
  chromote, rvest, and RSelenium are absent from the deployment manifest.
- Account credentials are read only from rsconnect's user-level store. Tokens
  and secrets are never accepted by the script or stored in this repository.
- A remote name collision is refused unless the local ignored deployment
  record links this project to the same app. `app/rsconnect/` remains ignored
  so later approved deployments update only the linked application.
- `R/_packages.R` records rsconnect as a local-only deployment dependency; it
  remains outside the six-package application runtime.
- The preflight was hardened for both zero-row data-frame and `NULL` responses
  from `rsconnect::applications()` by using `NROW()`. The initial attempts
  stopped before upload; the corrected preflight is regression-tested.

### Public application

- URL: `https://qqxot9-batest-hommie.shinyapps.io/messi-vs-ronaldo-r/`
- Account: `qqxot9-batest-hommie`
- Content ID: `17705139`
- Final linked bundle: `12413528`
- Deployment command: `Rscript scripts/09_deploy_shinyapps.R`
- The first successful create and the final linked update both completed on
  2026-08-15. The public app remains live for user review.

### Hosted verification

- Root, `css.css?v=20260815-review1`, `app.js?v=20260812-wave6`,
  `/img/messi.jpg`, and `/img/ronaldo.jpg` each return HTTP 200 with non-empty
  expected content types.
- Every page opens on the hosted instance: Overview, Weighting, Head-to-Head,
  Inference, Methodology, Summary, and Raw Data.
- Penalty exclusion changes the live overall weighted rates to Messi `0.0926`,
  Ronaldo `0.0327`, and gap `+0.0600`, then restores cleanly.
- Champions Lg/Away updates Head-to-Head immediately to 81 Messi appearances,
  92 Ronaldo appearances, and gap `+0.0334`; the controls restore to all
  competitions and all venues.
- The default button-triggered Inference returns observed gap `+0.0953`, 95%
  interval `[-0.0120, +0.1999]`, probability `0.960`, and Cohen's d `+0.090`
  from 10,000 finite differences. Moving K to 1.1 leaves those results frozen
  and displays the controls-changed notice; restoring K to 1.0 matches the
  clicked snapshot again.
- Summary exposes the fixed and live semantic tables. Raw Data reports 1,738
  rows and 29 fields; searching Ronaldo returns 891 goals and clearing returns
  all 1,738.
- At desktop 1919x862 and mobile 390x844, document width exactly equals
  viewport width. The mobile navigation exposes all seven tabs, wide tables
  remain internally scrollable, and both viewports have zero Shiny output
  errors. The final browser console reports zero errors and zero warnings.
- A live-review defect in `app/R/mod_head2head.R` was repaired: the obsolete
  future-tense “No uncertainty interval yet / Wave 4” caveat now says where the
  implemented Inference workflow lives. The final linked deployment was
  reloaded and the corrected copy was verified on the public app.
- The transient websocket disconnect observed during the instance roll-forward
  cleared after a fresh reload. The final session reports connected, seven
  navigation tabs, and zero Shiny errors.

### Regression and data contracts

- Wave 4 through Wave 8 regression suites pass after the final copy change.
  Exact seeded values remain gap `0.0952554179`, interval
  `[-0.0119600327, 0.1999414634]`, probability `0.9600000000`, and Cohen's d
  `0.0899711631`.
- The source CSV MD5 remains `c43c3f995b1f301b4328c846eab2cf27`.
- Contracts remain 1,738 goals, 2,201 valid appearances, 181,081 minutes,
  1,063 scoreless appearances, three missing difficulty scores, bundle version
  0.1.0, and finite fractional signed power.

### Wave 8 closure

The public experience was accepted and the user explicitly authorized the
final GitHub documentation commit/push. No source-data change, analysis-bundle
rebuild, renv restoration, repository-visibility change, or next-phase work is
part of this closure. The small rsconnect credential stays in the user profile
on C: and can be deleted later without affecting the canonical project on D:.
The ignored deployment record stays in `app/rsconnect/` to preserve safe linked
updates.

## Final GitHub Documentation — 2026-08-15

- `README.md` is the repository landing page with the live shinyapps.io link,
  verified data/results, dashboard tour, method summary, local setup, tests,
  Docker/deployment workflows, limitations, attribution, and project status.
- `docs/ARCHITECTURE.md` records the collection-to-runtime data flow, FAMD and
  bootstrap contracts, module interfaces, performance/accessibility design,
  delivery boundaries, and layered verification strategy.
- Four reviewed public-app screenshots are retained under `docs/screenshots/`:
  Overview, Weighting, completed Inference, and expanded mobile navigation.
  Desktop captures are 1600x1000; mobile is 390x844.
- README links include the retained editable Word guide, distribution PDF,
  data dictionary, Docker guide, attributions, phase plan, and this handoff.
- GitHub Markdown rendering succeeds, every relative documentation link
  resolves, the live dashboard returns HTTP 200, and the repository scan finds
  no credential-like values. The screenshot console log contained zero
  warnings/errors and its temporary Playwright artifacts were removed.
- The repository is public. Its GitHub homepage is the public dashboard;
  no project-wide license or release tag is invented during closure.
