# 8-Stage Code Quality System

## Overview
The code quality system has been restructured into 8 focused stages that run across all detected technologies. Each stage can be run independently and focuses on a single quality aspect.

## Stages

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

### Stage 6: Complexity
**Purpose**: Cyclomatic complexity analysis (only A/B grades allowed)
**Tools**:
- Python: `radon cc` (fails on C/D/E/F grades)

### Stage 7: Maintainability
**Purpose**: Maintainability and readability metrics
**Tools**:
- Python: `radon mi` (maintainability index ≥40) + custom readability index (≥85)

### Stage 8: Coverage
**Purpose**: Test coverage analysis
**Tools**:
- Python: `pytest --cov`
- JavaScript/TypeScript: `vitest run --coverage`

## Usage

```bash
# List all available stages
quality/bin/phase_checks.sh --list-stages

# Run specific stage
quality/bin/phase_checks.sh 1

# Run all stages up to stage N
quality/bin/phase_checks.sh 5

# Show current stage
quality/bin/phase_checks.sh --current-stage

# Set current stage
quality/bin/phase_checks.sh --set-stage 3
```

## Key Features

1. **Incremental**: Each stage builds on the previous ones
2. **Technology Agnostic**: Automatically detects and runs appropriate tools
3. **Regression Protection**: Previous stages must not regress
4. **Clean Output**: Simple "PASSED/FAILED" output without emojis
5. **Focused**: Each stage has a single responsibility
6. **Overcomable**: Each stage can be tackled independently

## Technology Detection

The system automatically detects technologies based on:
- Python: `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`
- JavaScript/TypeScript: `package.json`, `tsconfig.json`
- HTML: `*.html` files
- CSS: `*.css` files  
- Shell: `*.sh` files

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
