# @tjalve/aiq

A CLI tool for running comprehensive code quality checks across 9 stages: E2E → Lint → Format → Type Check → Unit Test → SLOC → Complexity → Maintainability → Coverage → Security.

## ⚠️ AI Agent Context

This CLI is designed for human users. **For AI agents implementing quality systems, see the main repository** at https://github.com/tjalve/ai-code-quality

## Quick Start

```bash
# Install globally
npm install -g @tjalve/aiq

# Or use with npx (no installation needed)
npx @tjalve/aiq run

# Run all quality checks
aiq run

# Run specific stage
aiq run --only 8

# Run up to specific stage
aiq run --up-to 5

# Run with verbose output
aiq run --verbose

# Dry run (show what would be done)
aiq run --dry-run

# Check configuration
aiq config --print-config

# Setup pre-commit hook
aiq hook install

# Get help
aiq --help
```

## Features

- **9 Quality Stages**: Comprehensive pipeline from E2E testing to security scanning
- **Auto-Detection**: Python, JavaScript/TypeScript, HTML/CSS, Shell, .NET, Java, Go, HCL/Terraform
- **Staged Adoption**: Start with basic checks, gradually enable more stages
- **No Regressions**: Previous phases must always pass (progress tracking)
- **Self-Contained**: All configs and tools bundled - no external dependencies
- **Pre-commit Ready**: Includes Git pre-commit hook integration
- **Configurable**: JSON-based configuration for exclusions, language enable/disable, and thresholds
- **Diff-Only Mode**: Run checks only on changed files for faster feedback

## Commands

### run
Run quality checks with various options:

```bash
aiq run [options]
```

Options:
- `--only N`: Run only stage N
- `--up-to N`: Run stages 0 through N
- `--verbose`: Show detailed output
- `--dry-run`: Show what would be done without executing
- `--diff-only`: Run checks only on changed files (faster for incremental work)

### config
Manage configuration:

```bash
aiq config --print-config    # Show current configuration
aiq config --set-stage N     # Set current progress stage
```

### hook
Manage pre-commit hooks:

```bash
aiq hook install    # Install pre-commit hook
aiq hook remove     # Remove pre-commit hook
```

## Configuration

Create `.aiq/quality.config.json` in your project root:

```json
{
  "excludes": [
    "test-projects/*",
    "node_modules/*",
    "dist/*",
    "build/*"
  ],
  "languages": {
    "python": { "enabled": true },
    "javascript": { "enabled": true },
    "dotnet": { "enabled": false }
  },
  "overrides": {
    "6": { "ccn_limit": 15 },
    "9": {
      "semgrep": { "severity": "ERROR" }
    }
  }
}
```

## Quality Stages

0. **E2E**: End-to-end testing
1. **Lint**: Code linting
2. **Format**: Code formatting
3. **Type Check**: Static type checking
4. **Unit Test**: Unit testing
5. **SLOC**: Source lines of code analysis
6. **Complexity**: Cyclomatic complexity analysis
7. **Maintainability**: Code maintainability metrics
8. **Coverage**: Test coverage analysis
9. **Security**: Secrets scanning and SAST

## License

MIT
