# E2E Test Integration Guide

E2E tests run as **Stage 0** before all other quality stages.

## Directory Structure

The system automatically detects E2E tests in these locations (in order):
- `tests/e2e/`
- `e2e/`
- `test/e2e/`

## Supported Frameworks

### Playwright (JavaScript/TypeScript)
- Detected when `@playwright/test` is in `package.json`
- Runs: `npx playwright test <e2e-directory>`

### Playwright (Python)
- Detected when `playwright` is in `requirements.txt` or `pyproject.toml`
- Runs: `uv run pytest <e2e-directory>` or `python -m pytest <e2e-directory>`

### pytest (Python)
- Detected when `pytest` is in `requirements.txt` or `pyproject.toml`
- Runs: `uv run pytest <e2e-directory>` or `python -m pytest <e2e-directory>`

## Usage

Run E2E tests only:
```bash
./quality/bin/phase_checks.sh 0
```

Run all stages including E2E:
```bash
./quality/bin/run_checks.sh
```

## Behavior

- E2E tests run before all other quality stages
- If E2E tests fail, all subsequent stages still run but are marked as failed
- If no E2E directory is found, E2E stage is skipped
- If no supported framework is detected, E2E stage is skipped
