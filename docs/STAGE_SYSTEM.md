# 9-Stage Code Quality System

## Overview
The code quality system has been restructured into 9 focused stages (0-8) that run across all detected technologies. Each stage can be run independently and focuses on a single quality aspect.

## Stages

### Stage 0: E2E Testing
**Purpose**: End-to-end testing before all quality checks
**Tools**:
- JavaScript/TypeScript: `playwright test`
- Python: `pytest` (E2E tests in tests/e2e/, e2e/, or test/e2e/)
**Behavior**: Automatically detects E2E tests and frameworks, skips if none found

### Stage 1: Lint
**Purpose**: Basic code checks and linting
**Tools**:
- Python: `ruff check`
- JavaScript/TypeScript: `biome check`
- Shell: `shellcheck`
- HTML: `htmlhint`
- CSS: `stylelint`

### Stage 2: Format
**Purpose**: Code formatting checks
**Tools**:
- Python: `ruff format --check`
- JavaScript/TypeScript: `biome format --check`
- Shell: `shfmt -d`

### Stage 3: Type Check
**Purpose**: Static type checking
**Tools**:
- Python: `mypy`
- TypeScript: `tsc --noEmit`

### Stage 4: Unit Test
**Purpose**: Run unit tests
**Tools**:
- Python: `pytest`
- JavaScript/TypeScript: `vitest run`

### Stage 5: SLOC
**Purpose**: Source Lines of Code limits (files must be < 350 lines)
**Tools**:
- Python: `radon raw` with SLOC analysis
- .NET/Java/JS/TS/Go: `lizard -j` (aggregated per-file NLOC)

### Stage 6: Complexity
**Purpose**: Cyclomatic complexity analysis (only A/B grades allowed)
**Tools**:
- Python: `radon cc` (fails on C/D/E/F grades)
- .NET/Java/JS/TS/Go: `lizard -j` (fails if function CCN > threshold; default 12)

### Stage 7: Maintainability
**Purpose**: Maintainability and readability metrics
**Tools**:
- Python: `radon mi` (maintainability index ≥40) + custom readability index (≥85)
- .NET/Java/JS/TS/Go: Lizard proxy (CCN ≤10, function NLOC ≤200, params ≤6 by default)

### Stage 8: Coverage
**Purpose**: Test coverage analysis
**Tools**:
- Python: `pytest --cov`
- JavaScript/TypeScript: `vitest run --coverage`

## Usage

```bash
# Simple wrapper - run from any directory
./quality/check.sh

# List all available stages (0-8)
./quality/bin/phase_checks.sh --list-stages

# Run specific stage
./quality/bin/phase_checks.sh 1

# Run E2E tests only (Stage 0)
./quality/bin/phase_checks.sh 0

# Run all stages up to stage N
./quality/bin/phase_checks.sh 5

# Show current stage
./quality/bin/phase_checks.sh --current-stage

# Set current stage
./quality/bin/phase_checks.sh --set-stage 3

# Run all quality checks (respects current stage)
./quality/bin/run_checks.sh
```

## Key Features

1. **E2E First**: Stage 0 runs E2E tests before all quality checks
2. **Incremental**: Each stage builds on the previous ones
3. **Technology Agnostic**: Automatically detects and runs appropriate tools
4. **Regression Protection**: Previous stages must not regress
5. **Clean Output**: Simple "PASSED/FAILED" output without emojis
6. **Focused**: Each stage has a single responsibility
7. **Overcomable**: Each stage can be tackled independently
8. **Pre-commit Ready**: Includes optional Git pre-commit hook integration

## Technology Detection

The system automatically detects technologies based on:
- Python: `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`
- JavaScript/TypeScript: `package.json`, `tsconfig.json`
- HTML: `*.html` files
- CSS: `*.css` files  
- Shell: `*.sh` files
- E2E Tests: `tests/e2e/`, `e2e/`, `test/e2e/` directories

## Dependencies

### Python
- ruff (linting + formatting)
- mypy (type checking)
- pytest + pytest-cov (testing + coverage)
- radon (complexity/maintainability/SLOC)

### JavaScript/TypeScript
- @biomejs/biome (linting + formatting)
- typescript (type checking)
- vitest + @vitest/coverage-v8 (testing + coverage)
- htmlhint (HTML linting)
- stylelint (CSS linting)
- @playwright/test (E2E testing, installed when detected)

### Shell
- shellcheck (linting)
- shfmt (formatting)

## Pre-commit Hook

```bash
# Setup during installation
./quality/install.sh

# Setup after installation
./quality/install.sh --setup-hook
```

The pre-commit hook runs all quality stages before each commit, preventing code that fails quality checks from being committed.
