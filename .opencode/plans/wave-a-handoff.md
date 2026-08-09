# MessivsRonaldoR — Project Handoff & Knowledge Base

_Last updated: 2026-08-07 (after commit `a3c0a7f`). Re-read before resuming._

This is the record of the project's **Phase 1** history, decisions, and gotchas.
**`AGENTS.md` is now the single source of truth** for current operational rules —
where the two disagree, AGENTS.md wins.

> ### Corrections (2026-08-09) — this document is a historical record, left intact
>
> Two claims below have since been superseded. They are **not** edited in place,
> so this file stays a faithful record of what was believed at the time:
>
> - **§9, line ~186 — "K-slider exponentiates (`Score ^ K`)".** Wrong. The
>   transform is a **signed power**, `sign(Score) * abs(Score)^K`. Roughly half
>   the difficulty scores are negative, and a negative base with a fractional
>   exponent returns `NaN`. Correct form is in `AGENTS.md` and
>   `scripts/08_prepare_analysis.R:18-19`.
> - **§3.6 / §5, line ~64 — "renv.lock stays the manifest of record for Docker only".**
>   True in intent, but `renv.lock` was never updated for Phase 2: it holds 69
>   Phase-1 packages and none of `shiny`, `bslib`, `data.table`, `htmltools`,
>   `plotly`, `DT` or `FactoMineR`. As written it cannot serve Docker either.
>   **Resolved by removing renv altogether** — `renv.lock`, `renv/` and `.Rprofile`
>   were deleted on 2026-08-09, so every renv reference below is historical.
>   Commands are now plain `Rscript <script>`; Docker pins by dated Posit PPM
>   snapshot. See *On renv* in `AGENTS.md` before reinstating anything.
>
> Also note §2/§7 use **2,263** for the *raw* match-log row count; the *cleaned*
> appearance count is **2,201**, of which **1,063 (48.3%)** are scoreless. Both
> numbers are correct in context — do not use them interchangeably.

---

## 1. Where the project stands

- **PHASE 1 (data collection) is COMPLETE and committed** as git `a3c0a7f`.
- The **primary deliverable exists**: `data/processed/goals_master_final.csv`
  (1,738 goals, one row per goal) built by `scripts/07_integrate_data.R`.
- **Next milestone: Phase 2 — Shiny dashboard** (spec `2. DataAnalysis.txt`).
  The dashboard consumes `goals_master_final.csv` + `data/processed/famd_loadings.rds`.

### Status at a glance

| Script / item | Status |
|---|---|
| Environment (git, renv, chromote, worldfootballR pin) | ✅ Done — wfR loads in 2 s from user library |
| `R/politeness.R`, `R/browser_scrape.R`, `R/clubelo_slugs.R` | ✅ Done, verified |
| `02_scrape_fbref.R` | ✅ Done, validated (847 + 891 goals) |
| `03_scrape_understat.R` | ✅ Done (487 goals with per-goal xG) |
| `04_collect_elo_ratings.R` | ✅ Done (national-first, preflight, retries) |
| `05_scrape_transfermarkt.R` | ✅ Done — 20 transfers; bio throttled/empty |
| `07_integrate_data.R` | ✅ DONE — goals_master_final.csv, match_context.rds, famd_loadings.rds, quality_report.txt, data_dictionary.md |
| `renv.lock` | ✅ chromote/processx present (via wfR deps) |
| git | ✅ committed `a3c0a7f` (30 files) |

---

## 2. Deliverables (Phase 1 output)

- `data/processed/goals_master_final.csv` — **1,738 goals** (Messi 847, Ronaldo 891),
  29 cols, one row/goal, `goal_id` unique, 0 dup keys. **This is the deliverable.**
- `data/processed/match_context.rds` — **2,201 unique matches** (dropped 12 junk +
  47 DNP + 3 Nations League dups; **kept all 1,063 scoreless**), with Opponent_Elo,
  Elo_Source, Venue, Competition_Stage, Is_Away, Difficulty_Score.
- `data/processed/famd_loadings.rds` — FactoMineR FAMD result (global, both players) for Docker.
- `data/processed/quality_report.txt` + `data/data_dictionary.md`.
- **Key numbers:**
  - Elo coverage 82% direct / **90.6% direct-or-league** (spec §6.1 target >90%).
  - xG on 483/1738 (27.8%, 2014+ top-5 only; documented gap).
  - 3 goals lack match context (2026 WC knockout — match-log snapshot predates goal-log snapshot).
  - Penalty count: Messi 106 / Ronaldo 169.
  - Per-90 (weighted / raw): **Messi 0.134 / 0.895; Ronaldo 0.038 / 0.836**.

---

## 3. Locked decisions (don't re-litigate without reason)

1. **All-scraping pipeline — no Kaggle CSVs** (user approved). Kaggle script + report deleted.
2. **FBref via headful Chrome.** Cloudflare blocks all plain-HTTP clients from this IP;
   real headful Chrome auto-solves ~85 s on first visit and stores `cf_clearance` in the profile.
3. **`worldfootballR@72af453f9eea` pinned** (archived repo — pin forever).
   **kickR deferred** (imports RSelenium; re-enable only if `fb_*` fails).
4. **Elo sources:** ClubElo API for clubs + **eloratings.net per-team TSV** for national
   teams (each row has both teams' Elo, so Argentina.tsv + Portugal.tsv cover all
   international opponents). ~~martj42 CSV~~ dropped — it has **no Elo column**.
5. **WhoScored deferred** (needs RSelenium). `player_rating` column stays NA.
6. **Local dev runtime = the fast user library, NOT renv.** renv.lock is the manifest of
   record for Docker only (see §5).

---

## 4. Phase 1 pipeline

Scripts run in numbered order (WhoScored `06` deferred):

```
02_scrape_fbref.R       -> data/raw/fbref_goal_logs.rds, fbref_match_logs.rds, fbref_season_stats.rds
03_scrape_understat.R   -> data/raw/understat_goals.rds
04_collect_elo_ratings.R-> data/processed/{club_elo_lookup,national_elo_lookup}.csv + caches
05_scrape_transfermarkt.R-> data/raw/transfermarkt_*.rds + data/processed/transfermarkt_summary.csv
07_integrate_data.R     -> data/processed/{goals_master_final.csv, match_context.rds,
                           famd_loadings.rds, quality_report.txt} + data/data_dictionary.md
```

- `R/politeness.R` — paths, User-Agent, robots check, scrape logger (`data/raw/scrape_log.csv`), HTML cache.
- `R/clubelo_slugs.R` — **shared** ClubElo slug derivation (transliterate → override map → strip
  non-alnum), used by BOTH 04 (fetch) and 07 (join). **Vectorized.**
- `R/browser_scrape.R` — FBref requires headful Chrome; see §6.

### 04 (Elo) specifics
- **National FIRST** (independent of ClubElo), club SECOND behind a **preflight probe**:
  if `api.clubelo.com` is unreachable, the club phase is SKIPPED (cached data kept) instead of
  burning retries on an outage. Re-run later; cached clubs load instantly.
- National Elo: eloratings.net `{Team}.tsv` — files keyed by team **CODE** (`AR`/`PT`), resolved
  via `en.teams.tsv`. Format: `Year Month Day Team1 Team2 G1 G2 Tournament Venue Change Elo1 Elo2`.
- ClubElo slug overrides (verified): `ParisSG`, `RBLeipzig`, `Betis` (Real Betis), `Sociedad`
  (Real Sociedad), `Celta` (Celta Vigo), `Bilbao` (Athletic Club), `Atletico` (Atletico Madrid),
  `Sporting` (Sporting CP), `Schalke` (Schalke 04), `Apoel` (APOEL FC). Unverified additions to
  re-check when API recovers: `DeportivoLaCoruna`, `Omonia`, `ShakhtarDonetsk`, `CSKAMoscow`, `Kobenhavn`.
- Transliteration: `iconv(x, from="UTF-8", to="ASCII//TRANSLIT")` (`Atlético`→`Atletico`).

### 05 (Transfermarkt) specifics
- Outputs: `transfermarkt_bio.rds` (EMPTY — throttled), `transfermarkt_transfers.rds` (20 rows),
  `transfermarkt_summary.csv`.
- `tm_player_bio()` makes a second "rueckennummern" sub-request that breaks when throttled →
  custom `scrape_bio_direct()` using `xml2::read_html` + retries.
- **Transfermarkt intermittently serves 200-but-empty throttle pages** — treat 0-row result as
  retryable (`stop("empty bio page")`). Bio is optional; script degrades gracefully.
- Use `tm_player_transfer_history(get_extra_info=FALSE)` (fast). `get_extra_info=TRUE` times out (>5 min) — avoid.

### 07 (integration) specifics
- xG join **must be by goal-rank-within-match** (Understat minutes differ from FBref: 46 vs 45+2).
- Club Elo join via data.table non-equi `[From<=Date, To>=Date]` (33MB lookup, ~26 s fread).
- Difficulty oriented so higher = harder (cor with OppElo kept positive).

---

## 5. Runtime environment gotcha (Win, this machine) — IMPORTANT

- Loading packages from the **renv library path hangs or is extremely slow**
  (`library(worldfootballR)` from `renv/library/windows/...` hung >5 min; even tiny loads ~65 s).
- The **user library** `C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5` is fast and has
  everything the pipeline needs (rvest, dplyr, readr, httr, chromote, data.table, FactoMineR),
  EXCEPT worldfootballR was missing.
- **FIX APPLIED:** worldfootballR installed into the user library from the pinned commit:
  ```r
  remotes::install_github("JaseZiv/worldfootballR", ref = "72af453f9eea",
                          lib = "C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5")
  ```
  (qdapRegex was the only missing dep, auto-installed). Now loads in **2 s**.
- **Working rule:** run scripts as `Rscript --no-init-file --no-restore --no-save` (no renv).
  renv.lock stays the manifest of record for Docker only. Do NOT fight the renv hang.
- `FactoMineR` available; `factoextra` NOT available (don't use it).
- Large-file reads are slow on this machine: use `data.table::fread` (26 s for the 33MB lookup)
  rather than `readr::read_csv` (>2 min).

---

## 6. Critical architecture: `R/browser_scrape.R`

- Persistent headful Chrome, port **9333**, profile `%LOCALAPPDATA%\MessivsRonaldo-chrome-profile`.
- `ensure_session()` → `ChromeRemote$new("127.0.0.1", 9333)`; `patch_fbref_load_page()` swaps
  worldfootballR's internal `.load_page()` for one that fetches via Chrome + caches every page to
  `data/raw/html_cache/`.
- **First-ever FBref visit ≈ 85 s** (Cloudflare solve); cached profile makes subsequent loads ~3–5 s.
- Browser launched detached (`supervise = FALSE`) so it survives across Rscript runs and keeps the
  `cf_clearance` cookie.
- `chromote` + `processx` are runtime deps; already in renv.lock (via wfR deps).

---

## 7. Verified data (what 02/03 produced)

- `data/raw/fbref_goal_logs.rds` — **Messi 847** (2005-05-01 → 2026-07-07), **Ronaldo 891**
  (2002-10-07 → 2026-07-02). Columns: `Rk, Date, Comp, Round, Venue, Squad, Opponent, Start,
  Minute, Score, Goalkeeper, Assist, Notes, Player`. `Notes` carries goal type
  ("Penalty kick": Messi 106, Ronaldo 169).
- `data/raw/fbref_match_logs.rds` — 2,263 matches (Messi 1,066 / Ronaldo 1,197), two-row-header parsed.
- `data/raw/fbref_season_stats.rds` — 140 rows (`standard` + `shooting` × 2 players). **No xG column.**
- `data/raw/understat_goals.rds` — 487 goals with per-goal xG (Messi: 231 La liga + 22 Ligue 1;
  Ronaldo: 19 EPL + 134 La liga + 81 Serie A). Top-5 leagues 2014+ only — known gap.

---

## 8. Hard-won parsing gotchas (don't rediscover)

- Goal-log table (`goallogs/all_comps/<Slug>-Goal-Log`): repeats column-header row every ~56 rows
  AND has ~75 fully-empty spacer rows. **Filter on `Date` (not `""`/`"Date"`/NA), never on `Rk`**
  — 75 real goals have blank `Rk`.
- Match-log pages: two-row header; **row 2 is the real column names**.
- `fb_player_goal_logs()` etc. use internal `.load_page()` → the Chrome patch covers all of them.
- Understat: archived package's live-scrape functions (`understat_league_season_shots`) are **broken**
  ("second argument must be a list") — use `load_understat_league_shots()` (pre-scraped GitHub data).
  Player-name variants: `Ronaldo` vs `Cristiano Ronaldo`; exclude `Ronaldo Vieira`, `Junior Messias`.
- **FBref opponent country prefixes are 2–3 letters** (`it Milan`, `eng Arsenal`, `sct Celtic`,
  `nir Northern Ireland`, `wls Wales`): strip with `^[a-z]{2,3} `.
- 3 Nations League matches appear **twice** in the match logs (exact dups) — dedup on
  `(Player, Date, Opp_clean, Comp, Round)`.

---

## 9. Methodology constraints — do NOT violate (highest-signal)

- **FAMD, not PCA** — data mixes continuous (Opponent Elo) and categorical (Venue, Stage).
- **ONE global FAMD** on the combined dataset of both players. Never per-player FAMDs.
- **FAMD inputs only:** `Opponent_Elo`, `Venue`, `Competition_Stage`, `Is_Away`. Exclude goal count,
  player name, and player's own-team Elo.
- `Difficulty_Score` = standardized Dim 1; `Weighted Goal = 1 × Difficulty_Score`.
  **K-slider (0.5–3.0)** exponentiates (`Score ^ K`) — dashboard sensitivity only, not base weights.
- **Do not z-score** goals before weighting (destroys count nature). Keep raw counts.
- **Do not drop rows** with missing Elo. Impute: Club Elo → league-average → global 1500.
- **Do not bin** continuous Opponent Elo — use scatter + loess.
- **Bootstrap at the MATCH level**, 10,000 resamples, record difference (Messi − Ronaldo) in
  Weighted Goals per 90; CI = 2.5/97.5 percentiles.
- **NEVER filter to goal-scoring matches only** — ~47% of appearances are scoreless. The FAMD, the
  per-90 denominator, and the bootstrap all need the FULL match set. Drop only the 12 header-junk
  rows and 47 DNP rows; keep zero-goal appearances.
- **No p-values as binary flags; no Bonferroni** in the exploratory dashboard — show full bootstrap density.
- **Dashboard default metric = Weighted Goals per 90**, never Raw (Raw is only the "Reality Check").
- **Shiny performance:** pre-computed FAMD scores in a `reactiveVal()`; K-slider only multiplies them;
  bootstrap runs ONLY on explicit "Update Analysis" button click; `shiny::bindCache()` on `renderPlot`.

---

## 10. Docker / deployment (`3. Containerization.txt`)

- Base image `rocker/shiny-verse:4.5.0` **pinned — never `latest`**. Multi-stage; <1.5 GB;
  runs as non-root `shiny` user. Shiny port **3838**.
- **FAMD pre-computed locally** as `data/processed/famd_loadings.rds`; container only loads + multiplies
  — never run FAMD at startup.
- Layer order: base → system deps → R packages (`renv::restore()`) → app code → CMD.
- System libs base lacks: `libssl-dev`, `libcurl4-openssl-dev`, `libxml2-dev`, `libfreetype6-dev`,
  `libharfbuzz-dev`, `libpng-dev`, `libjpeg-dev`.
- `HEALTHCHECK` curls `http://localhost:3838/`. Logs to stdout (JSON). Data <1 MB — embed in image.

---

## 11. Remaining known gaps (documented, spec-compliant)

- Saudi/MLS/Mexican clubs → **1500 Elo** (no ClubElo source; no public Elo for those leagues).
- xG only top-5 leagues 2014+ (483/1738 goals).
- 3 WC-knockout goals (2026) lack match context — match-log snapshot predates goal-log snapshot.
- Transfermarkt player bio empty (throttled) — cosmetic only, not needed by the analysis.

---

## 12. To resume / next steps

1. **If `api.clubelo.com` is back:** re-run `04` (fills club gaps from cache + fresh), then re-run
   `07` (fast) to lift Elo coverage above 90.6%. Both idempotent.
2. Optional: re-try Transfermarkt bio (`Remove-Item data/raw/transfermarkt_bio.rds` then re-run 05).
3. **Phase 2 — Shiny dashboard** (the next milestone): uses `goals_master_final.csv` +
   `data/processed/famd_loadings.rds`. See spec `2. DataAnalysis.txt` for the exact tabs, the
   bootstrap, the K-slider, and §9 methodology above.

### Resume commands

```powershell
# run scripts (fast user library; NO renv)
Rscript --no-init-file --no-restore --no-save scripts/04_collect_elo_ratings.R
Rscript --no-init-file --no-restore --no-save scripts/05_scrape_transfermarkt.R
Rscript --no-init-file --no-restore --no-save scripts/07_integrate_data.R

# headful Chrome (auto-started by browser_scrape.R if port 9333 is down)
Invoke-RestMethod http://127.0.0.1:9333/json/version

# git (note: git ops are SLOW on this drive; use background process + poll)
git -C D:\MessivsRonaldoR status --short
```

---

## 13. Key numbers for validation (spec §6.1 / real-world)

- Goals: Messi 847 / Ronaldo 891 (FBref, Aug 2026, all comps incl. 2026 WC). Spec targets ~950/~1030 —
  FBref states records may be incomplete; document, don't force.
- Matches: Messi 1,066 / Ronaldo 1,197 (raw match logs); 2,201 unique valid appearances after cleaning.
- Penalties: Messi 106 / Ronaldo 169.
- Understat xG: 487 goals covered; 483 joined into master.
- Per-90 weighted: Messi 0.134 / Ronaldo 0.038; raw: 0.895 / 0.836.
