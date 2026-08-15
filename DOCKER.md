# Docker — Wave 7 Reproducibility Build

The canonical project remains at `D:\MessivsRonaldoR`. Never edit a copied
file on C:. Wave 7 uses C: only as a disposable build context because Docker
context scanning and package layers are slow on D:.

## Temporary locations and names

- Build context: `C:\Users\TOSHIBA\AppData\Local\MessivsRonaldoR\wave7-build-context`
- Dedicated builder: `messi-wave7-builder`
- Image tag: `messi-vs-ronaldo:wave7`
- Test container: `messi-vs-ronaldo-wave7`

Only `Dockerfile`, `.dockerignore`, and `app/` belong in the temporary context.
Before a build, recreate that directory from D: and compare SHA-256 manifests.
If a source change is needed, make it on D: and stage again.

## Container contract

- Base: `rocker/shiny-verse:4.5.0`, pinned to the verified Linux/AMD64 digest.
- Packages: `shiny`, `bslib`, `data.table`, `htmltools`, `plotly`, and `DT`
  from the dated `2026-08-09` Posit Package Manager snapshot.
- Entrypoint: `Rscript /opt/messi-vs-ronaldo/app/run.R`.
- Network: `0.0.0.0:3838` in the container; publish host port 3838.
- Security: non-root `shiny` user, dropped capabilities, and
  `no-new-privileges` during verification.
- Health: HTTP request to `http://127.0.0.1:3838/` inside the container.
- Data: the precomputed bundle and exact Raw Data CSV under `app/data/`; no
  FAMD, scraping, external volume, or startup download.

## Cleanup contract

After Wave 7 verification, stop and remove only the named test container,
remove only the `messi-vs-ronaldo:wave7` image, remove the dedicated
`messi-wave7-builder`, and then delete the exact temporary context after
confirming it resolves beneath
`C:\Users\TOSHIBA\AppData\Local\MessivsRonaldoR`.

Do not run `docker system prune`, do not remove unrelated images, and never
delete Docker Desktop's `docker_data.vhdx` directly. The app is relaunched from
D: with `Rscript app/run.R` after cleanup.

## Verified Wave 7 checkpoint — 2026-08-15

- The staged C: context contained 28 source-identical files (1,978,126 bytes);
  its SHA-256 manifest matched the canonical D: source before the build.
- The final image was
  `sha256:7208f22dbc8fe13386977e55c3afd0524c1daea5eabc414bf8159d8b74d9d91f`
  and 786,851,392 bytes, below the 1.5 GB target.
- The container became healthy within the launch polling window, emitted one
  JSON `app_start` record, and served root, CSS, JavaScript, and both portraits
  with HTTP 200 responses.
- Runtime package resolution began at `/opt/messi-library` and loaded exactly
  `shiny 1.14.0`, `bslib 0.12.0`, `data.table 1.18.4`, `htmltools 0.5.9`,
  `plotly 4.12.1`, and `DT 0.34.0`. `FactoMineR` and `worldfootballR` were
  absent.
- The runtime used UID/GID 997 (`shiny`), a 2 GB memory limit, one CPU, all
  capabilities dropped, and `no-new-privileges=true`.
- The complete desktop/mobile browser walkthrough passed with all seven pages,
  reactive controls, button-frozen Inference, no document overflow, no Shiny
  output errors, and no console warnings or errors.
- An external Docker Scout upload was not authorized for this private local
  image, so no cloud vulnerability scan was performed.
- Cleanup was completed after verification: the named container, current and
  three identified earlier Wave 7 image IDs, dedicated builder, browser
  artifacts, C: build context, and its now-empty parent directory were removed.
  The general Docker Desktop/buildkit installation was left intact.
