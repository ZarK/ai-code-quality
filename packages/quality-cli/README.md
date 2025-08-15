# @tjalve/quality (scaffold)

Ephemeral, npx-friendly quality runner for the 9-stage pipeline. No quality/ copy into repos.

Quickstart
- npx @tjalve/quality run
- npx @tjalve/quality config --print-config
- npx @tjalve/quality config --set-stage 6

Commands (initial)
- run: delegates to local quality/ scripts for now. In npx, will run embedded stages from cache.
- config: prints/writes .aiq/quality.config.json and .aiq/progress.json

Planned
- hook install, ci setup, ignore write, doctor, report, changed-only optimization.
