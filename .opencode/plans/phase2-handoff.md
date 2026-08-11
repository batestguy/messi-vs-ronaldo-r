# Phase 2 Handoff

Date: 2026-08-11
Status: **Wave 1 revision complete; paused at the review gate before Wave 2**

## Resume Point

Wave 1 now includes the original Overview plus the country-and-club identity
revision and the signed-power equation panel. The user asked to document the
state and return to the next wave later. **Do not begin Wave 2 without a new
user instruction.**

- Wave 0 is committed as `92271d9`.
- The original Wave 1 implementation is committed as `4450c03`.
- The 2026-08-11 Wave 1 revision is currently in the working tree.
- Phase 1 remains complete at `a3c0a7f` (pipeline) + `016ff08` (docs).
- The dashboard is running at `http://127.0.0.1:3838` for review.

## Launch and Refresh Contract

Always launch from the repository root with:

```powershell
Rscript app/run.R
```

Do not run `Rscript app/app.R`; that launch path does not serve `app/www/`
reliably. There is no renv and there are no command flags.

Restart the R process after source changes. The custom stylesheet is linked as
`css.css?v=20260811-wave1b` in `app/app.R`. If future work changes CSS and a
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

## Next Step — Deferred

When the user returns and approves proceeding, begin **Wave 2 — Weighting** and
stop again after its review gate. Its planned scope is:

1. Live K-sensitivity chart using
   `sign(Difficulty_Score) * abs(Difficulty_Score)^K`.
2. Reality Check comparison of raw versus weighted per-90 rates.
3. Difficulty distribution and goal-count-by-difficulty view.

Do not add Wave 2 behavior during Wave 1 cleanup. In particular, keep the
bootstrap bound to the explicit `Update analysis` action and do not change the
analysis bundle merely to support presentation.

## Resolved Environment Decision — No renv

renv was removed on 2026-08-09. `renv.lock`, `renv/`, and `.Rprofile` are gone;
do not recreate them. Wave 7 will pin its six runtime packages through a dated
Posit PPM snapshot. The full rationale is in `AGENTS.md` under *On renv*.
