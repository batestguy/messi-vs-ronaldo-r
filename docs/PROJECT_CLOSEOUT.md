# Project Closeout and Reusable Skills

Date: 2026-08-15
Status: **Complete, public, deployed, documented, and locally closed**

## Final deliverables

- Public dashboard: <https://qqxot9-batest-hommie.shinyapps.io/messi-vs-ronaldo-r/>
- Public source repository: <https://github.com/batestguy/messi-vs-ronaldo-r>
- Beginner study guide:
  [PDF](../output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf) and
  [editable Word](../output/word/Messi_vs_Ronaldo_Statistics_Explained.docx)
- Technical design: [Architecture and methodology](ARCHITECTURE.md)
- Container instructions: [Docker guide](../DOCKER.md)

Phase 1 data collection and Phase 2 dashboard Waves 0–8 are finished. The
hosted application is independent of the stopped local R and Docker processes.
No later phase is planned or authorized by this closeout.

## Reusable agent skills created during the project

### Shiny dashboard wave builder

Invoke as `$shiny-dashboard-wave-builder`.

Machine-global location:

```text
C:/Users/TOSHIBA/.codex/skills/shiny-dashboard-wave-builder/
```

This skill captures the review-gated workflow used here: read the repository
contract first, lock one wave, preserve analytical invariants, keep the UI
modular and data-backed, use local accessible assets, test the rendered app at
desktop and mobile sizes, update the handoff, and stop at the review gate.

The most important reusable rules are:

- launch through the repository's official entry point rather than guessing a
  generic Shiny command;
- preserve expensive precomputed analysis and transform stored results in the
  reactive layer;
- calculate displayed totals from authoritative data instead of duplicating
  them in UI metadata;
- version CSS/JavaScript URLs when stale browser assets can mismatch new HTML;
- treat HTTP success as only one check—also inspect layout, overflow,
  accessibility, Shiny errors, and the browser console;
- commit, publish, deploy, or change repository visibility only after explicit
  authorization.

This skill is machine-global and intentionally is not duplicated in the
repository.

### Simple explanation documents

Invoke as `$simple-explanation-docs`.

Tracked project copy:

```text
.agents/skills/simple-explanation-docs/
```

Machine-global copy:

```text
C:/Users/TOSHIBA/.codex/skills/simple-explanation-docs/
```

This skill turns technical or statistical material into matching Word and PDF
documents for a curious beginner without weakening the evidence. It requires
layered explanations, definitions beside formulas, worked examples using
verified values, nearby cautions, Word as the editable source, PDF as the
distribution copy, and text plus visual validation of both outputs.

For this repository, rebuild and validate the guide with:

```powershell
python scripts/build_statistics_guide.py
python .agents/skills/simple-explanation-docs/scripts/validate_outputs.py `
  --docx output/word/Messi_vs_Ronaldo_Statistics_Explained.docx `
  --pdf output/pdf/Messi_vs_Ronaldo_Statistics_Explained.pdf
```

The tracked skill also includes
`references/content-patterns.md`, reusable UI metadata, and the paired-output
validator. Both retained guide formats are final project artifacts; neither is
an intermediate file.

## Technical skills worth carrying forward

### Preserve the statistical grain

The primary rate is a ratio of sums over every valid appearance:

```text
90 × sum(weighted goal contributions) / sum(all valid appearance minutes)
```

Scoreless appearances contribute zero to the numerator but remain in the
denominator. The uncertainty analysis resamples whole matches independently
within each player, preserves the selected-scope appearance counts, and reports
the full 10,000-replicate Messi-minus-Ronaldo distribution. This avoids the
false precision caused by treating goals from the same match as independent.

### Preserve sign during sensitivity transforms

Difficulty scores are centred and can be negative. The K sensitivity control
therefore uses:

```r
sign(score) * abs(score)^K
```

Using `score^K` would produce `NaN` for negative scores at fractional K values.

### Separate reactive and button-triggered work

Lightweight descriptive views react immediately to the sidebar. Bootstrap
inference freezes K, penalty, competition, and venue only when **Update
analysis** is clicked. Changing a control marks results stale but does not rerun
10,000 resamples. This keeps the interface responsive and makes the settings
behind every inference result explicit.

### Deploy the smallest runtime

The dashboard runtime needs only `shiny`, `bslib`, `data.table`, `htmltools`,
`plotly`, and `DT`. FAMD and scraping are build-time work; the deployed app
loads a precomputed bundle. The Docker image uses a dated package snapshot, and
shinyapps.io receives a strict source allowlist. No `renv`, scraper, credential,
or analysis-only package belongs in the runtime deployment.

### Clean Docker without disturbing development environments

Before cleanup, inventory containers, images, volumes, and build cache. Remove
only verified disposable Docker resources, then use Docker Desktop's WSL data
cleanup—not factory reset—when the local Linux disk itself must be recreated.
Verify Docker afterward, and stop it if it is not needed.

For this closeout, the Docker disk fell from 8.54 GiB to its clean 1.50 GiB
baseline. C: finished with 87.64 GiB free. Docker Desktop remains installed;
Ubuntu WSL, the R 4.5 user library, and Python were not moved or modified.

## Closed local state

- Canonical source remains at `D:\MessivsRonaldoR`.
- GitHub visibility is public and `main` tracks `origin/main`.
- The local Shiny process is stopped and port 3838 is closed.
- Docker Desktop is installed and stopped; its engine can be restarted for a
  future project.
- Docker contains zero images, containers, volumes, and build cache entries.
- There is no temporary C: project copy and no project `renv`.
- User-level R packages, Python installations, Ubuntu WSL, rsconnect
  credentials, and the live shinyapps.io deployment are retained.

If the project is ever reopened, read `AGENTS.md` first and launch locally only
with:

```powershell
Rscript app/run.R
```
