# Documentation

This repository contains two primary parts:

- quality/: the self-contained, 9-stage quality system (bash-based)
- packages/quality-cli/: the npx-friendly CLI wrapper that runs the staged pipeline with embedded assets and supports --diff-only

Start here
- Repo overview: README.md (root)
- CLI usage: packages/quality-cli/README.md
- Quality stages: see quality/stages/* and quality/lib/_stage_common.sh

Configuration
- .aiq/quality.config.json: thresholds, stage order/disable
- .aiq/progress.json: current_stage and progress state
- Threshold env mapping from CLI: LIZARD_SLOC_LIMIT, LIZARD_CCN_LIMIT, LIZARD_CCN_STRICT, LIZARD_FN_NLOC_LIMIT, LIZARD_PARAM_LIMIT

Modes
- Full run: runs all enabled stages in configured order
- Diff-only mode (aiq run --diff-only):
  - Affects: Stage 1 (lint), 2 (format check), 5/6/7 (sloc/complexity/maintainability)
  - Full runs always: 0 (e2e), 3 (type core), 4 (unit), 8 (coverage), 9 (security)

CI/CD
- GitHub Actions: .github/workflows/quality.yml runs the staged pipeline
- npm publish: .github/workflows/npm-publish.yml publishes @tjalve/aiq on v* tags

Future plan (concise)
- Harden docs and examples, keep package slim
- Optional: add examples/ with 1-2 reference projects per language
- Optional: Add markdown lint (remark) for docs consistency
- Optional: Extend language matrices where useful (Rust/.NET/SQL already sketched)

