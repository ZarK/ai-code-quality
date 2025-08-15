# Universal Code Quality System

A self-contained, technology-aware code quality system that can be easily added to any repository.

## Usage

### Basic Commands

```bash
# Run all quality checks
./check.sh

# Check specific directory
./check.sh ../src/

# Check specific stage
./check.sh . 3

# Get help
./check.sh --help
```

### Pre-commit Hook Setup

```bash
# Setup pre-commit hook
./install.sh --setup-hook

# Remove pre-commit hook
rm ../.git/hooks/pre-commit
```

## Quality Stages

The system runs 9 stages in order (0-8):

0. **E2E**: End-to-end testing (Playwright, pytest)
1. **Lint**: Code linting (ESLint, Ruff, HTMLHint)
2. **Format**: Code formatting (Prettier, Ruff format, shfmt)
3. **Type Check**: Static type checking (TypeScript, mypy)
4. **Unit Test**: Unit testing (Jest, pytest)
5. **SLOC**: Source lines of code analysis
6. **Complexity**: Cyclomatic complexity analysis (Radon)
7. **Maintainability**: Code maintainability metrics (Radon)
8. **Coverage**: Test coverage analysis (Jest, pytest-cov)

## Prerequisites

### Required Tools
- **asdf** - Version manager for Python and Node.js
- **uv** - Fast Python package installer and resolver
- **bun** - Fast JavaScript runtime and package manager
- **Homebrew** (macOS/Linux) - For shell tools (shellcheck, shfmt)

### Installation
Run `./bin/install_tools.sh` to install all required quality tools.

## Supported Technologies

- Python: Ruff (lint/format), mypy (types), pytest (test), radon (metrics)
- JavaScript/TypeScript: Biome/ESLint (lint), Biome/Prettier (format), TypeScript (types), Vitest/Jest (test)
- HTML/CSS: HTMLHint (lint), Stylelint (lint), Prettier (format)
- Shell: shellcheck (lint), shfmt (format)
- .NET: dotnet format (format), dotnet build (types), dotnet test (+ Coverlet if configured)
- Java (Maven/Gradle): Checkstyle (lint), google-java-format (format check), build (types), test (+ JaCoCo if configured)
- HCL/Terraform: terraform fmt/hclfmt (format check), tflint (lint)
- Security: gitleaks (secrets), semgrep (SAST), tfsec (Terraform security) if installed
- E2E Testing: Playwright (JS/TS), pytest (Python)

## Documentation

- Start here: ../docs/README.md
- Stage System Details: ../docs/stage_system.md
- E2E Integration Guide: ../docs/e2e_integration.md

## Project Structure

```
quality/
├── bin/           # Internal scripts (don't use directly)
├── configs/       # Tool configurations
├── hooks/         # Git hooks
├── lib/           # Shared libraries
├── stages/        # Individual stage scripts
├── check.sh       # Main entry point
└── install.sh     # Installation script
```
