# Universal Code Quality System

A self-contained, technology-aware code quality system that can be easily added to any repository. Supports staged rollout to existing projects and full activation for new projects.

## Quick Start

### One-Line Installation

```bash
curl -sSL https://raw.githubusercontent.com/your-org/ai-code-quality/main/quality/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/your-org/ai-code-quality.git
cp -r ai-code-quality/quality ./
chmod +x quality/bin/*.sh quality/lib/*.sh quality/hooks/* quality/stages/*.sh quality/check.sh
echo "0" > quality/.phase_progress
```

## Features

- **Auto-Detection**: Automatically detects Python, JavaScript/TypeScript, HTML/CSS, React
- **E2E First**: Runs E2E tests before all quality stages (Playwright, pytest)
- **Staged Rollout**: Add quality checks gradually to existing codebases
- **No Regression**: Previous phases must always pass (prevents quality degradation)
- **Self-Contained**: All configs and tools live in the quality/ directory
- **Pre-commit Ready**: Includes Git pre-commit hook integration
- **Technology-Aware**: Only runs relevant checks for detected technologies
- **Opinionated**: Sensible defaults that work out of the box

## Usage

### Basic Commands

```bash
# Run all quality checks
./quality/check.sh

# Check specific directory
./quality/check.sh src/

# Check specific stage
./quality/check.sh . 3

# Get help
./quality/check.sh --help
```

### Pre-commit Hook Setup

```bash
# Setup pre-commit hook only
./quality/install.sh --setup-hook

# Setup GitHub Actions workflow only
./quality/install.sh --setup-workflow

# Setup both pre-commit hook and GitHub Actions (recommended)
./quality/install.sh --setup-hook --setup-workflow

# Remove pre-commit hook
rm .git/hooks/pre-commit

# Remove GitHub Actions workflow
rm .github/workflows/quality.yml
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

## Supported Technologies

- **Python**: Ruff (lint/format), mypy (types), pytest (test), radon (metrics)
- **JavaScript/TypeScript**: ESLint (lint), Prettier (format), TypeScript (types), Jest (test)
- **HTML/CSS**: HTMLHint (lint), Stylelint (lint), Prettier (format)
- **Shell**: shellcheck (lint), shfmt (format)
- **E2E Testing**: Playwright (JS/TS), pytest (Python)

## GitHub Actions Integration

The system includes a pre-configured GitHub Actions workflow that runs all quality checks on pull requests and pushes to main/develop branches. The workflow:

- Automatically detects verbose mode when GitHub Actions debug logging is enabled
- Installs all required tools (shellcheck, shfmt, Python packages, Node.js packages)
- Runs all 8 quality stages with proper error reporting
- Provides detailed debug information for failed stages

### Installation

```bash
# Install GitHub Actions workflow
./quality/install.sh --setup-workflow

# Install both pre-commit hook and GitHub Actions (recommended)
./quality/install.sh --setup-hook --setup-workflow
```

The workflow will be installed at `.github/workflows/quality.yml` and will automatically run on:
- Push to `main` or `develop` branches
- Pull requests targeting `main` or `develop` branches

### Removal

```bash
# Remove GitHub Actions workflow
rm .github/workflows/quality.yml
```

## Documentation

- [Stage System Details](docs/STAGE_SYSTEM.md)
- [E2E Integration Guide](docs/E2E_INTEGRATION.md)

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

## License

MIT License - see LICENSE file for details.
