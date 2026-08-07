# Phase 1 (Data Collection) — Session Handoff (MessivsRonaldoR)

_Last updated: end of this session. Re-read this before resuming._

## Status at a glance

| Script | Status |
|---|---|
| Environment (git, renv, chromote, worldfootballR pin) | ✅ Done — wfR loads in 2s from user library |
| `R/politeness.R`, `R/browser_scrape.R`, `R/clubelo_slugs.R` | ✅ Done, verified |
| `02_scrape_fbref.R` | ✅ Done, validated (847 + 891 goals) |
| `03_scrape_understat.R` | ✅ Done (487 goals with per-goal xG) |
| `04_collect_elo_ratings.R` | ✅ Done (national-first, preflight, retries) |
| `05_scrape_transfermarkt.R` | ✅ Done — 20 transfers; bio throttled/empty |
| `07_integrate_data.R` | ✅ **DONE** — goals_master_final.csv, match_context.rds, famd_loadings.rds, quality_report.txt, data_dictionary.md |
| `renv.lock` | ✅ chromote/processx present (via wfR deps) |
| AGENTS.md | ✅ Updated (pipeline + gotchas + methodology) |
| `.opencode/plans/wave-a-handoff.md` | ✅ This file |

## Phase 1 OUTPUT — the deliverable (07)

- `data/processed/goals_master_final.csv` — **1,738 goals** (Messi 847, Ronaldo 891), 29 cols, one row/goal, `goal_id` unique, 0 dup keys.
- `data/processed/match_context.rds` — **2,201 unique matches** (dropped 12 junk + 47 DNP + 3 Nations League dups; **kept all 1,063 scoreless**), with Opponent_Elo, Elo_Source, Venue, Competition_Stage, Is_Away, Difficulty_Score.
- `data/processed/famd_loadings.rds` — FactoMineR FAMD result (global, both players) for Docker.
- `data/processed/quality_report.txt` + `data/data_dictionary.md`.
- **Key numbers:** Elo coverage 82% direct / 90.6% direct-or-league (spec target >90%); xG on 483/1738 (27.8%, 2014+ top-5); 3 goals lack match context (2026 WC knockout — match-log snapshot predates goal-log snapshot); penalty count Messi 106 / Ronaldo 169.
- **Per-90 (weighted / raw):** Messi 0.134 / 0.895; Ronaldo 0.038 / 0.836.
- **Gotchas learned in 07:** xG join must be by goal-rank-within-match (minutes differ: Understat 46 vs FBref 45+2); club Elo join via data.table non-equi `[From<=Date, To>=Date]` (33MB lookup, 26s fread); difficulty oriented so higher=harder (cor with OppElo positive).
- **Remaining known gaps (documented, spec-compliant):** Saudi/MLS/Mexican clubs → 1500 Elo (no ClubElo source); xG only top-5 2014+; 3 WC-knockout goals NA context.

## To resume (if any Phase 1 work remains)

1. If `api.clubelo.com` is back: re-run 04 (fills club gaps from cache + fresh), then re-run 07 (fast) to lift Elo coverage above 90.6%.
2. Optional: re-try Transfermarkt bio (`Remove-Item data/raw/transfermarkt_bio.rds` then re-run 05) — cosmetic only.
3. Next milestone: Phase 2 — Shiny dashboard (uses goals_master_final.csv + famd_loadings.rds). See spec `2. DataAnalysis.txt` tabs/bootstrap/K-slider requirements.

## Locked decisions (don't re-litigate without reason)

1. **All-scraping pipeline — no Kaggle CSVs** (user approved). Kaggle script + report deleted.
2. **FBref via headful Chrome** (user chose browser scraping). Cloudflare blocks all plain-HTTP clients from this IP (verified: real headful Chrome gets the interstitial ~85 s on first visit; it auto-solves and stores `cf_clearance` in the profile).
3. **`worldfootballR@72af453f9eea` pinned** (archived repo — pin forever). **kickR deferred** (imports RSelenium; re-enable only if `fb_*` fails).
4. **Elo sources:** ClubElo API for clubs (`api.clubelo.com/<Slug>`) + **eloratings.net per-team TSV** for national teams (`www.eloratings.net/{Team}.tsv` — each row has both teams' Elo, so Argentina.tsv + Portugal.tsv cover all international opponents). ~~martj42 CSV~~ dropped — it has **no Elo column**.
5. **WhoScored deferred** (needs RSelenium). `player_rating` column stays NA.

## Critical architecture: `R/browser_scrape.R`

- Persistent headful Chrome, port **9333**, profile `%LOCALAPPDATA%\MessivsRonaldo-chrome-profile`.
- `ensure_session()` → `ChromeRemote$new("127.0.0.1", 9333)`; `patch_fbref_load_page()` swaps worldfootballR's internal `.load_page()` for one that fetches via Chrome + caches every page to `data/raw/html_cache/`.
- **First-ever FBref visit ≈ 85 s** (Cloudflare solve); cached profile makes subsequent loads ~3–5 s. If the challenge hangs, just wait — it clears.
- The browser is launched detached (`process$new(..., supervise = FALSE)`) so it survives across Rscript runs and keeps the `cf_clearance` cookie.
- `chromote` + `processx` must be added to `R/_packages.R` and `renv.lock` (still pending).

## Verified data (what 02/03 produced)

- `data/raw/fbref_goal_logs.rds` — **Messi 847** goals (2005-05-01 → 2026-07-07), **Ronaldo 891** (2002-10-07 → 2026-07-02). Columns: `Rk, Date, Comp, Round, Venue, Squad, Opponent, Start, Minute, Score, Goalkeeper, Assist, Notes, Player`. `Notes` carries goal type ("Penalty kick": Messi 106, Ronaldo 169).
- `data/raw/fbref_match_logs.rds` — 2,263 matches (Messi 1,066 / Ronaldo 1,197), two-row-header parsed.
- `data/raw/fbref_season_stats.rds` — 140 rows (`standard` + `shooting` × 2 players).
- `data/raw/understat_goals.rds` — 487 goals with per-goal xG (Messi: 231 La liga + 22 Ligue 1; Ronaldo: 19 EPL + 134 La liga + 81 Serie A). Top-5 leagues 2014+ only — known gap.

## FBref parsing gotchas (hard-won — don't rediscover)

- Goal-log table (`goallogs/all_comps/<Slug>-Goal-Log`): repeats the column-header row every ~56 rows **and** has ~75 fully-empty spacer rows. **Filter on `Date` (not in `""`/`"Date"`/NA), never on `Rk`** — 75 real goals have blank `Rk`.
- Match-log pages: two-row header; **row 2 is the real column names**.
- `fb_player_goal_logs()` etc. use internal `.load_page()` → the Chrome patch covers all of them.
- Understat: the archived package's live-scrape functions (`understat_league_season_shots`) are **broken** ("second argument must be a list") — use `load_understat_league_shots()` (pre-scraped GitHub data) instead. Player-name variants: `Ronaldo` vs `Cristiano Ronaldo`; exclude `Ronaldo Vieira`, `Junior Messias`.

## Methodology note (added this session — user-raised)

**NEVER filter to goal-scoring matches only.** 1,065 of 2,263 appearances are scoreless (~47%); skipping them biases the FAMD (only "successful" contexts), breaks the per-90 denominator, and invalidates the match-level bootstrap. Flow: all match logs → ONE global FAMD on all matches → Difficulty_Score joined to goal rows → per-90 = sum(Weighted Goals)/sum(Minutes over ALL valid matches). Drop only the 12 header-junk rows (Gls == "Gls") and 47 DNP rows (no minutes). Now written into AGENTS.md too.

## ClubElo findings (verified via live API probes this session)

- **The API is flaky/rate-limited** — big clubs like RealMadrid/Liverpool/Roma/Porto returned 200-with-rows in probes but had MISSed in the old run (no retries). The rewritten 04 retries up to 6× with backoff (3/6/12/20/30/40 s) and treats header-only responses as "club not rated" (no retry).
- **Correct slugs differ from naive derivation** — verified: `ParisSG` (not ParisSaintGermain), `RBLeipzig`, `Betis` (Real Betis), `Sociedad` (Real Sociedad), `Celta` (Celta Vigo), `Bilbao` (Athletic Club), `Atletico` (Atletico Madrid), `Sporting` (Sporting CP), `Schalke` (Schalke 04), `Apoel` (APOEL FC). Unverified additions to re-check when API recovers: `DeportivoLaCoruna`, `Omonia`, `ShakhtarDonetsk`, `CSKAMoscow`, `Kobenhavn`.
- **Transliteration**: use `iconv(x, from="UTF-8", to="ASCII//TRANSLIT")` — verified working (`Atlético`→`Atletico`, `Curaçao`→`Curacao`).
- **FBref country prefixes are 2–3 letters**: `it Milan`, `eng Arsenal`, `sct Celtic`, `nir Northern Ireland`, `wls Wales`. Old regex only stripped 2. Now `^[a-z]{2,3} `.
- **National Elo source CHANGED**: `martj42/international_results.csv` has **no Elo column** (only date/teams/scores/tournament). Instead use **eloratings.net per-team TSV** (`https://www.eloratings.net/Argentina.tsv`, `Portugal.tsv`): each row is one national match with BOTH teams' Elo (cols V11/V12), so two files cover every international opponent. Codes resolved via `en.teams.tsv`. Format: `Year Month Day Team1 Team2 G1 G2 Tournament Venue Change Elo1 Elo2`.

## Background job (rewritten 04, PID 11956)

- Rewritten `04_collect_elo_ratings.R` running as **PID 11956** (logs `scrape04.log`/`scrape04.err.log`). At last check **3 OK [cached] / 6 MISS**, but `api.clubelo.com` was **down** (RealMadrid probe → `http=000`/502) — the retries will fill gaps once it recovers. Job is idempotent; safe to kill + re-run anytime.
- **04 verified earlier runs**: the previous (buggy) run had already cached 92 club CSVs (Messi/Argentina/Ronaldo-relevant European clubs mostly fine: Barcelona, Bayern, Juventus, Inter, Milan, RealMadrid→? etc.).
- Once 04 finishes, check the "CLUBS WITHOUT CLUBELO RATING" list — Saudi/MLS/Mexican clubs will legitimately fall back to league-average Elo (spec §1.2 allows).

## Bugs fixed this session (04 rewrite)

1. Accent stripping → transliteration (`iconv` ASCII//TRANSLIT).
2. 2-letter prefix regex → `^[a-z]{2,3} ` (handles eng/sct/nir/wls).
3. Wrong overrides corrected: PSG→ParisSG, RB Leipzig→RBLeipzig, Real Betis→Betis, Real Sociedad→Sociedad, Celta Vigo→Celta, Athletic→Bilbao, Atletico Madrid→Atletico, Sporting CP→Sporting, Schalke 04→Schalke, APOEL FC→Apoel.
4. Added retries (6×, backoff) — the API is flaky; single-attempt runs produce phantom MISSes.
5. Empty/corrupt cache files (`Valladolid.csv` 0 bytes) are deleted and re-fetched.
6. Header-junk `Opponent` row filtered out before building the opponent list.
7. National Elo switched to eloratings.net per-team TSV.

## CRITICAL environment issue discovered (RESOLVED this session)

**Problem:** Loading packages from the renv library path hangs or is very slow; `worldfootballR` only existed there.
- `Rscript` (`.Rprofile` → `renv/activate.R`) hangs forever; `R_LIBS` pointing at `renv/library/windows/R-4.5/x86_64-w64-mingw32` made even tiny loads take 65s+ or hang.
- The **user library** `C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5` is fast and has everything EXCEPT worldfootballR.

**FIX APPLIED:** `worldfootballR` installed into the user library from the pinned GitHub commit:
```r
remotes::install_github("JaseZiv/worldfootballR", ref = "72af453f9eea",
                        lib = "C:/Users/TOSHIBA/AppData/Local/R/win-library/4.5")
```
It now loads in **2 s**. qdapRegex was the only missing dep (auto-installed). **Working runtime = user library via `Rscript --no-init-file --no-restore --no-save`; renv.lock stays the manifest of record for Docker only.** Do NOT fight the renv hang.

## Session 2 progress (what changed today)

| Item | Status |
|---|---|
| worldfootballR load blocker | ✅ RESOLVED (installed into user lib) |
| `04_collect_elo_ratings.R` | ✅ Rewritten (transliteration, retries, eloratings.net). **PID 6656 running in bg** |
| `05_scrape_transfermarkt.R` | ✅ Written + run: **20 transfers** (Messi 8, Ronaldo 12) with fees + market values; bio throttled (optional, empty) |
| `07_integrate_data.R` | ❌ Not yet written — the big one for next session |
| `renv.lock` | chromote/processx already present (via wfR deps) |

### 04 details
- Killed old PID 11956 (ClubElo was down). Restarted as **PID 6656**. At pause time 04 had **finished the club phase** (log ended with MISS list: `YoungBoys`, `Zurich`, etc.) and was in the **National Elo phase** — `en.teams.tsv` downloaded OK. `Argentina.tsv`/`Portugal.tsv` + `data/processed/national_elo_lookup.csv` should land shortly. ClubElo was still down (`http=000`) at last check — retries will fill gaps when it recovers. 101 club CSVs already cached.
- Rewritten script handles: transliteration, `^[a-z]{2,3} ` prefix strip, corrected slug overrides (ParisSG/RBLeipzig/Betis/Sociedad/Celta/Bilbao/Atletico/Sporting/Schalke/Apoel), 6× retry w/ backoff, empty-cache re-fetch, header-junk filter, eloratings.net national Elo.
- Note: `04` will keep retrying dead ClubElo slugs (each ~40s backoff) — it's slow but harmless; a later re-run is fast because everything is cached.

### 05 details (Transfermarkt)
- Outputs: `data/raw/transfermarkt_bio.rds` (EMPTY — throttled), `data/raw/transfermarkt_transfers.rds` (20 rows), `data/processed/transfermarkt_summary.csv`.
- Gotchas learned: `tm_player_bio()` makes a second "rueckennummern" sub-request that breaks when throttled → wrote own `scrape_bio_direct()` using `xml2::read_html` + retries; **Transfermarkt intermittently serves 200-but-empty throttle pages** — treat 0-row result as retryable (`stop("empty bio page")`). Bio is optional; script degrades gracefully (empty bio → summary = transfers only).
- Verified working: `tm_player_transfer_history(get_extra_info=FALSE)` (fast); `get_extra_info=TRUE` times out (>5 min) — avoid.
- Bio fields wanted (if a later run succeeds): player_valuation, max_player_valuation, max_player_valuation_date, current_club, DOB, height, position, foot.
- To retry bio later: `Remove-Item data/raw/transfermarkt_bio.rds` then re-run 05 (it's cached-guarded).

### Facts confirmed this session
- **FactoMineR IS available** in the user library (needed for FAMD in 07); factoextra is NOT (don't use it).
- Spec §3 requires: FAMD inputs = `Opponent_Elo, Venue, Competition_Stage, Is_Away`; global fit both players; exclude goal count + player name + own-team Elo; `Difficulty_Score` = Dim 1; K-slider exponentiates (dashboard, not base); save loadings as `data/famd_loadings.rds` for Docker.

## Next steps (in order)

1. Verify 04 (PID 6656): check `scrape04.log`; confirm `data/processed/national_elo_lookup.csv` + `club_elo_lookup.csv` exist; re-run 04 when ClubElo recovers (fast — cached). Inspect "CLUBS WITHOUT CLUBELO RATING" list (Saudi/MLS/Mexican legitimately fall back to league-avg).
2. Write `scripts/07_integrate_data.R` (the core deliverable):
   - Load goal logs, match logs, understat, Elo lookups, transfermarkt.
   - Clean match logs: drop 12 header-junk (Gls=="Gls") + 47 DNP rows; **keep all 1,065 scoreless** for FAMD/per-90 denominator.
   - Build `Opponent_Elo` per match: club via `club_elo_lookup.csv` (Elo as of match date); national via `national_elo_lookup.csv` by `(national_team, date)`; fallback Elo → league-avg → 1500 (never drop rows).
   - ONE global FAMD (FactoMineR) on match context → `Difficulty_Score` (Dim 1) per match; save `data/famd_loadings.rds`.
   - Join to goal rows; `Weighted_Goal = 1 × Difficulty_Score`; compute `Weighted_Goals_per_90 = sum(Weighted)/sum(Minutes over ALL valid matches)`.
   - Attach xG: Understat per-goal by `(Player, date, minute)` → fallback FBref season xG → flag `xg_source`.
   - Venue: map FBref `Venue` (Home/Away/Neutral); Competition_Stage derived from `Comp`+`Round`.
   - Dedup check `(Player, Date, Opponent, Minute)`; write `data/processed/goals_master_final.csv` + `quality_report.txt` + `data_dictionary.md`.
3. Commit checkpoint (user approved a commit this session).

## Resume commands

```powershell
# check background job / logs
Get-Process -Id 6656 -ErrorAction SilentlyContinue
Get-Content D:\MessivsRonaldoR\scrape04.log -Tail 40

# run scripts (fast user library; NO renv)
Rscript --no-init-file --no-restore --no-save scripts/04_collect_elo_ratings.R
Rscript --no-init-file --no-restore --no-save scripts/05_scrape_transfermarkt.R
Rscript --no-init-file --no-restore --no-save scripts/07_integrate_data.R

# retry transfermarkt bio (optional, throttled last session)
Remove-Item data/raw/transfermarkt_bio.rds
Rscript --no-init-file --no-restore --no-save scripts/05_scrape_transfermarkt.R

# headful Chrome (auto-started by browser_scrape.R if port 9333 is down)
Invoke-RestMethod http://127.0.0.1:9333/json/version
```

## Key numbers for validation (spec §6.1 / real-world)

- Goals: Messi 847 / Ronaldo 891 (FBref, Aug 2026, all comps incl. 2026 WC). Spec targets ~950/~1030 — FBref states records may be incomplete; document, don't force.
- Matches: Messi 1,066 / Ronaldo 1,197.
- Penalties in Notes: Messi 106 / Ronaldo 169.
- Understat xG: 487 goals covered; everything else = documented gap (pre-2014, non-top-5, all internationals).
