# Phase 2 Handoff

Date: 2026-08-08
Status: **Wave 1 complete; stop for user review**

## Current State

- Wave 0 committed as `92271d9`.
- Wave 1 Overview implemented in `app/R/mod_overview.R`.
- Dashboard launcher/static asset fix implemented:
  - Start with `Rscript app/run.R` from the repository root (no flags — renv removed 2026-08-09).
  - Do not launch with `app/app.R` directly; Shiny then cannot reliably serve `app/www/`.
- Navbar stylesheet moved into the `header` slot so it does not create an empty navigation item.
- Navbar colors explicitly set in `app/R/theme.R`.
- App is currently running at `http://127.0.0.1:3838` for browser review.

## Browser Verification

Validated with Playwright at the local URL:

- Page title: `Messi vs Ronaldo — The Weighted Case`.
- All seven tabs visible.
- Sidebar controls visible and functional at the UI level.
- Messi and Ronaldo portraits load.
- `/css.css`, `/img/messi.jpg`, and `/img/ronaldo.jpg` return HTTP 200.
- Overview KPI output renders:
  - Weighted Goals per 90: Messi `0.1337`, Ronaldo `0.0384`.
  - Raw Goals per 90: Messi `0.8954`, Ronaldo `0.8357`.
  - Total Goals: Messi `847`, Ronaldo `891`.
  - Appearances: Messi `1031`, Ronaldo `1170`.
- Only browser console issue observed: missing `/favicon.ico`; non-functional and can be addressed during polish.

## Visual Review Notes

- Current desktop layout: navbar, left global-controls sidebar, two portrait headers, four comparison KPI cards, then two explanatory cards.
- Portrait crop works well in circular frames.
- The four KPI cards fit across the desktop content area; leader values are bold and player-colored.
- The Overview is intentionally compact and dashboard-first. Longer methodological explanation belongs in later tabs.
- Mobile layout still needs review during Wave 6 polish.

## Files Changed Since Wave 0

- `app/R/mod_overview.R` — Overview content and KPI rendering.
- `app/R/theme.R` — navbar color tokens and visual identity.
- `app/app.R` — stylesheet header and launcher documentation.
- `app/run.R` — correct Shiny application-directory launcher.
- `.opencode/plans/phase2-plan.md` — progress status.

## Next Step

After user approval, begin **Wave 2 — Weighting**:

1. Live K-sensitivity chart using the signed-power transform `sign(x) * abs(x)^K`. **Not `x^K`** — that returns `NaN` on the negative difficulty scores. Several docs previously stated the wrong form; corrected 2026-08-09.
2. Reality Check comparison of raw vs weighted per-90 rates.
3. Difficulty distribution and goal-count-by-difficulty view.

## Resolved — renv removed (2026-08-09)

The Phase-1-only lockfile (69 packages, no `shiny`, no `FactoMineR`) was not repaired —
**renv was removed from the project.** `renv.lock`, `renv/` and `.Rprofile` are gone, so
every command is now plain `Rscript <script>` with no flags. Wave 7 pins its Docker layer
with a dated Posit PPM snapshot instead; Wave 7 is no longer blocked.

Full rationale in `AGENTS.md` under *On renv* — this diverges from
`3. Containerization.txt:57`, which marks renv "Non-Negotiable", so read that note before
reinstating anything. **Do not re-add renv.**

Keep the app running for review. Restart after code changes with `app/run.R`, then refresh the browser.
