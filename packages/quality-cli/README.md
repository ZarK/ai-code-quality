# @tjalve/aiq (scaffold)

Ephemeral, npx-friendly quality runner for the 9-stage pipeline. No quality/ copy into repos.

Quickstart
- npx @tjalve/aiq run
- npx @tjalve/aiq config --print-config
- npx @tjalve/aiq config --set-stage 6

Commands (initial)
- run: delegates to local quality/ scripts for now. In npx, will run embedded stages from cache.
- config: prints/writes .aiq/quality.config.json and .aiq/progress.json

Embedded assets
- The package will ship embedded quality assets; on npx runs, they are extracted to a cache (e.g., ~/.cache/aiq-cli/<version>/quality) and executed from there.

Planned
- hook install, ci setup, ignore write, doctor, report, changed-only optimization.
