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
chmod +x quality/bin/*.sh quality/lib/*.sh quality/hooks/*
echo "0" > quality/.phase_progress
```

### Pre-commit Hook Setup

```bash
# Setup during installation (interactive prompt)
./quality/install.sh

# Setup after installation
./quality/install.sh --setup-hook
```

## Features

- Auto-Detection: Automatically detects Python, JavaScript/TypeScript, HTML/CSS, React
- E2E Integration: Runs E2E tests before all quality stages (Playwright, pytest)
- Staged Rollout: Add quality checks gradually to existing codebases
- No Regression: Previous phases must always pass (prevents quality degradation)
- Self-Contained: All configs and tools live in the quality/ directory
- Pre-commit Ready: Includes Git pre-commit hook integration
- Technology-Aware: Only runs relevant checks for detected technologies
- Opinionated: Sensible defaults that work out of the box

## Usage

### Basic Commands

```bash
# Simple wrapper - run quality checks from any directory
./quality/check.sh

# Run quality checks (auto-detects technology)
./quality/bin/run_checks.sh

# Run specific stage (0=E2E, 1=lint, 2=format, etc.)
./quality/bin/phase_checks.sh 1

# Run E2E tests only (Stage 0)
./quality/bin/phase_checks.sh 0

# Check current stage
./quality/bin/phase_checks.sh --current-stage

# Set current stage (when you complete a stage)
./quality/bin/phase_checks.sh --set-stage 2

# List all available stages
./quality/bin/phase_checks.sh --list-stages
```

### Environment Variables

```bash
# Skip E2E tests
SKIP_E2E=1 ./quality/bin/run_checks.sh

# Full rollout (run all phases, ignore progress)
FULL_ROLLOUT=1 ./quality/bin/run_checks.sh
```

## Stage System

The system uses a 9-stage approach (0-8) with the "no regression" rule:

**Stage 0: E2E Testing** - Runs end-to-end tests before all quality checks
**Stages 1-8: Quality Checks** - Lint, format, type check, unit test, SLOC, complexity, maintainability, coverage

1. Previous stages must always pass (no quality degradation)
2. Current stage can fail (work-in-progress allowed)
3. Future stages are skipped

### For Existing Projects (Staged Rollout)

```bash
# Start with Stage 1 (skip E2E for now)
./quality/bin/phase_checks.sh --set-stage 1
./quality/bin/run_checks.sh  # Fix all issues

# Move to Stage 2 when Stage 1 is clean
./quality/bin/phase_checks.sh --set-stage 2
./quality/bin/run_checks.sh  # Now Stage 1 must pass + work on Stage 2
```

### For New Projects (Full Activation)

```bash
# Run all stages from day one (including E2E)
FULL_ROLLOUT=1 ./quality/bin/run_checks.sh
```
