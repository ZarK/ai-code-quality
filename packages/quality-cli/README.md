# @tjalve/aiq (scaffold)

Ephemeral, npx-friendly quality runner for the 9-stage pipeline. No quality/ copy into repos.

Quickstart
- npx @tjalve/aiq run
- npx @tjalve/aiq config --print-config
- npx @tjalve/aiq config --set-stage 6

Commands (initial)
- run: delegates to local quality/ scripts or embedded assets.
  - Supports --diff-only to scope Stages 1,2,5,6,7 to changed files; E2E/Unit/Coverage/Security remain full.
  - Flags: --only N, --up-to N, --verbose, --dry-run
- config: prints/writes .aiq/quality.config.json and .aiq/progress.json

Embedded assets
- The package ships embedded quality assets; on npx runs, they are extracted to a cache (e.g., ~/.cache/aiq-cli/<version>/quality) and executed from there.
- Dev mode: set AIQ_DEV_MODE=1 to warm the cache from ./quality in the current repo (useful when developing aiq itself).

Diff-only mode
- aiq run --diff-only limits:
  - Stage 1 (Lint): Python via ruff, JS/TS via biome (only changed files)
  - Stage 2 (Format check): Python via ruff format --check, JS/TS via biome (only changed files)
  - Stage 5/6/7 (SLOC/Complexity/Maintainability): multi-language via Lizard on changed files
- Stages 0,3,4,8,9 (E2E, type-check core, unit, coverage, security) run fully for safety.

Build & publish
- npm run build (in packages/quality-cli) copies quality/ into assets for packaging.
- On tagged pushes (v*), GitHub Actions publishes @tjalve/aiq to npm. Set NPM_TOKEN in repo secrets.
