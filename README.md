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

## Features

- Auto-Detection: Automatically detects Python, JavaScript/TypeScript, HTML/CSS, React
- Staged Rollout: Add quality checks gradually to existing codebases
- No Regression: Previous phases must always pass (prevents quality degradation)
- Self-Contained: All configs and tools live in the quality/ directory
- Pre-commit Ready: Includes Git pre-commit hook integration
- Technology-Aware: Only runs relevant checks for detected technologies
- Opinionated: Sensible defaults that work out of the box

## Usage

### Basic Commands

```bash
# Run quality checks (auto-detects technology)
./quality/bin/run_checks.sh

# Override technology detection
./quality/bin/run_checks.sh --override python,js

# Check current phase
./quality/bin/run_checks.sh --current-phase

# Set current phase (when you complete a phase)
./quality/bin/run_checks.sh --set-phase 2
```

### Environment Variables

```bash
# Skip E2E tests
SKIP_E2E=1 ./quality/bin/run_checks.sh

# Full rollout (run all phases, ignore progress)
FULL_ROLLOUT=1 ./quality/bin/run_checks.sh
```

## Phase System

The system uses a phase-based approach with the "no regression" rule:

1. Previous phases must always pass (no quality degradation)
2. Current phase can fail (work-in-progress allowed)
3. Future phases are skipped

### For Existing Projects (Staged Rollout)

```bash
# Start with Phase 1
./quality/bin/run_checks.sh --set-phase 1
./quality/bin/run_checks.sh  # Fix all issues

# Move to Phase 2 when Phase 1 is clean
./quality/bin/run_checks.sh --set-phase 2
./quality/bin/run_checks.sh  # Now Phase 1 must pass + work on Phase 2
```

### For New Projects (Full Activation)

```bash
# Run all phases from day one
FULL_ROLLOUT=1 ./quality/bin/run_checks.sh
```
