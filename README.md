# Universal Code Quality System

A self-contained, technology-aware code quality system that can be easily added to any repository. Supports staged rollout to existing projects and full activation for new projects.

## ⚠️ AI Agent Context

This repository is designed for AI agents to understand and implement code quality systems. **For human users, use the `aiq` CLI instead:**

```bash
npm install -g @tjalve/aiq
aiq run
```

The repository structure and documentation are optimized for AI comprehension rather than human readability.

## Quick Reference

- **9 Quality Stages**: E2E → Lint → Format → Type Check → Unit Test → SLOC → Complexity → Maintainability → Coverage → Security
- **Auto-Detection**: Python, JavaScript/TypeScript, HTML/CSS, Shell, .NET, Java, Go, HCL/Terraform
- **Staged Adoption**: Start with basic checks, gradually enable more stages
- **CI/CD Ready**: Pre-commit hooks + GitHub Actions integration
- **Configurable**: JSON-based configuration for exclusions, language enable/disable, and thresholds

## Quick Start

### AIQ CLI (Recommended)

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

### Manual Installation (Alternative)

```bash
curl -sSL https://raw.githubusercontent.com/tjalve/ai-code-quality/main/quality/install.sh | bash
```

Or clone and copy manually:

```bash
git clone https://github.com/tjalve/ai-code-quality.git
cp -r ai-code-quality/quality ./
chmod +x quality/bin/*.sh quality/lib/*.sh quality/hooks/* quality/stages/*.sh quality/check.sh
echo "0" > quality/.phase_progress
```

## Overview

The system runs 9 quality stages in order:
- **0. E2E**: End-to-end testing
- **1. Lint**: Code linting  
- **2. Format**: Code formatting
- **3. Type Check**: Static type checking
- **4. Unit Test**: Unit testing
- **5. SLOC**: Source lines of code analysis
- **6. Complexity**: Cyclomatic complexity analysis
- **7. Maintainability**: Code maintainability metrics
- **8. Coverage**: Test coverage analysis
- **9. Security**: Secrets scanning and SAST

**Key Features:**
- Auto-detects technologies: Python, JavaScript/TypeScript, HTML/CSS, Shell, .NET, Java, Go, HCL/Terraform
- Staged adoption: Start with basic checks, gradually enable more stages
- Self-contained: All configs and tools bundled
- Existing project friendly: Works with your current tools and configurations
- CI/CD ready: Pre-commit hooks + GitHub Actions integration

## Quality Stages

The system runs 9 stages in order (0-8):

0. **E2E**: End-to-end testing (Playwright, pytest)
1. **Lint**: Code linting (ESLint, Ruff, HTMLHint)
2. **Format**: Code formatting (Prettier, Ruff format, shfmt)
3. **Type Check**: Static type checking (TypeScript, mypy)
4. **Unit Test**: Unit testing (Jest, pytest)
5. **SLOC**: Source lines of code analysis
6. **Complexity**: Cyclomatic complexity analysis (Radon for Python; Lizard for .NET/Java/JS/TS/Go)
7. **Maintainability**: Code maintainability metrics (Radon for Python; Lizard proxy for .NET/Java/JS/TS/Go)
8. **Coverage**: Test coverage analysis (Jest, pytest-cov)

## Tool Matrix

The quality system automatically detects technologies in your project and runs appropriate tools for each stage. Here's the complete tool matrix:

| Stage | Technology | Tools Used | Notes |
|-------|------------|------------|-------|
| **0. E2E** | Python | pytest | Runs E2E tests with pytest |
| | JavaScript/TypeScript | Playwright | Runs E2E tests with Playwright |
| **1. Lint** | Python | Ruff | Fast Python linter |
| | JavaScript/TypeScript | Biome, ESLint | Biome primary, ESLint fallback |
| | HTML | HTMLHint | HTML validation and accessibility |
| | CSS | Stylelint | CSS linting and best practices |
| | Shell | shellcheck | Shell script static analysis |
| | .NET | dotnet format (check) | Code style validation |
| | Java | Checkstyle | Java code style and conventions |
| | HCL/Terraform | tflint | Terraform/HCL validation |
| **2. Format** | Python | Ruff format | Python code formatting |
| | JavaScript/TypeScript | Biome, Prettier | Biome primary, Prettier fallback |
| | HTML/CSS | Prettier | HTML/CSS formatting |
| | Shell | shfmt | Shell script formatting |
| | .NET | dotnet format | .NET code formatting |
| | Java | google-java-format | Java code formatting |
| | HCL/Terraform | terraform fmt, hclfmt | Terraform/HCL formatting |
| **3. Type Check** | Python | mypy | Static type checking |
| | JavaScript/TypeScript | TypeScript | TypeScript compiler |
| | .NET | dotnet build | C# compilation with type checking |
| | Java | Maven/Gradle build | Java compilation |
| **4. Unit Test** | Python | pytest | Unit test execution |
| | JavaScript/TypeScript | Vitest, Jest | Vitest primary, Jest fallback |
| | .NET | dotnet test | .NET test execution |
| | Java | Maven/Gradle test | Java test execution |
| **5. SLOC** | Python | radon | Source lines of code analysis |
| | All others | Lizard | Cross-language SLOC counting |
| **6. Complexity** | Python | radon | Cyclomatic complexity analysis |
| | All others | Lizard | Cross-language complexity analysis |
| **7. Maintainability** | Python | radon | Maintainability index |
| | All others | Lizard | Maintainability proxy metrics |
| **8. Coverage** | Python | pytest-cov | Test coverage with pytest |
| | JavaScript/TypeScript | Vitest/Jest coverage | Built-in coverage reporting |
| | .NET | Coverlet | .NET coverage if configured |
| | Java | JaCoCo | Java coverage if configured |
| **9. Security** | All | gitleaks | Secrets scanning |
| | All | semgrep | Static application security testing |
| | HCL/Terraform | tfsec | Infrastructure security scanning |

### Tool Detection and Versions

The system automatically detects technologies by scanning for common project files:

- **Python**: `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`
- **JavaScript/TypeScript**: `package.json` (checks for TypeScript dependencies)
- **HTML/CSS**: `*.html`, `*.css` files
- **Shell**: `*.sh` files
- **.NET**: `*.sln`, `*.csproj`, `global.json`
- **Java**: `pom.xml`, `build.gradle`, `build.gradle.kts`
- **Go**: `go.mod`, `*.go` files
- **HCL/Terraform**: `*.tf`, `*.hcl`, `terraform.tfvars`

**Tool Priority**: The system prefers locally installed tools in this order:
1. Project-local virtual environment (`.venv/bin/`)
2. Globally installed tools (system PATH)
3. uvx-managed tools (if available)
4. Auto-downloaded tools (for some tools like shfmt, shellcheck)

**Version Compatibility**: Tools are tested with recent versions. For existing projects, the system respects your current tool versions and configurations.

## Integration with Development Workflows

### Pre-commit Hooks

The pre-commit hook ensures quality checks run before commits, preventing quality regressions:

```bash
# Setup pre-commit hook
aiq hook install
# or manually:
./quality/install.sh --setup-hook

# The hook runs all stages up to your current progress
# Customize which stages run by setting the current stage:
aiq run --set-stage 5  # Run stages 0-5 on commit
```

### GitHub Actions Integration

The system includes a pre-configured GitHub Actions workflow that runs all quality checks on pull requests and pushes to main/develop branches. The workflow:

- Automatically detects verbose mode when GitHub Actions debug logging is enabled
- Installs all required tools (shellcheck, shfmt, Python packages, Node.js packages)
- Runs all 8 quality stages with proper error reporting
- Provides detailed debug information for failed stages
- Respects your `.aiq/quality.config.json` configuration

#### Installation

```bash
# Install GitHub Actions workflow
aiq ci setup
# or manually:
./quality/install.sh --setup-workflow

# Install both pre-commit hook and GitHub Actions (recommended)
./quality/install.sh --setup-hook --setup-workflow
```

The workflow will be installed at `.github/workflows/quality.yml` and will automatically run on:
- Push to `main` or `develop` branches
- Pull requests targeting `main` or `develop` branches

#### Removal

```bash
# Remove GitHub Actions workflow
rm .github/workflows/quality.yml
```

### Staged Rollout for Existing Projects

The system supports gradual adoption to minimize disruption:

1. **Start with basic checks**: Enable stages 0-2 (E2E, Lint, Format)
2. **Add type checking**: Enable stage 3 when your project has type annotations
3. **Add testing**: Enable stages 4-8 as you improve test coverage
4. **Enable security**: Add stage 9 when ready for security scanning

Set your current stage to control what runs:

```bash
# Start with stages 0-3
aiq run --set-stage 3

# Progress to stages 0-5
aiq run --set-stage 5
```

### Working with Existing Tool Configurations

The system integrates seamlessly with your existing development setup:

- **ESLint/Prettier**: Uses your `.eslintrc.js`, `prettier.config.js`
- **TypeScript**: Respects `tsconfig.json` compiler options
- **Python**: Uses `mypy.ini`, `pyproject.toml` configurations
- **Package managers**: Works with npm, yarn, pnpm, pip, poetry
- **Virtual environments**: Auto-detects `.venv`, `venv`, conda environments
- **CI/CD**: Compatible with GitHub Actions, GitLab CI, Jenkins, etc.

The system never overwrites your configurations - it enhances them with additional quality checks.

## Configuration

The quality system can be configured via `.aiq/quality.config.json` in your project root. This allows you to customize language detection, directory exclusions, security settings, and CI behavior.

### Example Configuration

```json
{
  "excludes": [
    "test-projects/*",
    "node_modules/*",
    "dist/*",
    "build/*"
  ],
  "languages": {
    "python": {
      "enabled": true
    },
    "javascript": {
      "enabled": true
    },
    "dotnet": {
      "enabled": false
    },
    "java": {
      "enabled": false
    },
    "go": {
      "enabled": false
    }
  },

   "ci": {
    "github_actions": {
      "enabled": true
    }
  },
  "overrides": {
    "5": {
      "sloc_limit": 1000
    },
    "6": {
      "ccn_limit": 15
    },
    "7": {
      "ccn_strict": true,
      "fn_nloc_limit": 50,
      "param_limit": 8
    },
    "9": {
      "gitleaks": {
        "enabled": true
      },
      "semgrep": {
        "enabled": true,
        "severity": "ERROR"
      },
      "tfsec": {
        "enabled": true
      }
    }
  }
}
```

### Configuration Options

#### Global Settings
- `excludes`: Array of glob patterns for directories to exclude from quality checks
- `ci.github_actions.enabled`: Enable/disable GitHub Actions integration (default: true)

#### Language Detection
- `languages.{language}.enabled`: Enable/disable specific language detection (default: true)
  - Supported languages: `python`, `javascript`, `dotnet`, `java`, `go`

#### Stage Overrides
- `overrides.{stage}`: Override default thresholds for specific stages

**Stage 5 (SLOC)**: `sloc_limit` - Maximum source lines of code per file

**Stage 6 (Complexity)**: `ccn_limit` - Maximum cyclomatic complexity

**Stage 7 (Maintainability)**:
- `ccn_strict` - Enable strict complexity checking (boolean)
- `fn_nloc_limit` - Maximum lines of code per function
- `param_limit` - Maximum function parameters

**Stage 9 (Security)**:
- `gitleaks.enabled` - Enable/disable secrets scanning (default: true)
- `semgrep.enabled` - Enable/disable SAST scanning (default: true)
- `semgrep.severity` - Set semgrep severity level (default: "ERROR", options: "INFO", "WARNING", "ERROR")
- `tfsec.enabled` - Enable/disable IaC security scanning (default: true)

### Working with Existing Tool Configurations

The system integrates seamlessly with your existing development setup:

- **ESLint/Prettier**: Uses your `.eslintrc.js`, `prettier.config.js`
- **TypeScript**: Respects `tsconfig.json` compiler options
- **Python**: Uses `mypy.ini`, `pyproject.toml` configurations
- **Package managers**: Works with npm, yarn, pnpm, pip, poetry
- **Virtual environments**: Auto-detects `.venv`, `venv`, conda environments
- **CI/CD**: Compatible with GitHub Actions, GitLab CI, Jenkins, etc.

## Troubleshooting

### Common Issues

**"Command not found" errors**
- Run `./quality/bin/check_dependencies.sh` to see what's missing
- Use `./quality/bin/install_tools.sh` to install required tools
- For Node.js projects, ensure dependencies are installed: `npm install`

**Tests failing in CI but passing locally**
- Check if your CI environment has all required dependencies
- Ensure test databases/services are available in CI
- Use `--verbose` flag for detailed error information

**Pre-commit hook running slowly**
- The hook runs all stages up to your current progress level
- Reduce the stage level with `aiq run --set-stage N` where N is lower
- Exclude unnecessary directories in `.aiq/quality.config.json`

**Tool version conflicts**
- The system uses your existing tool versions when possible
- For conflicts, you can disable specific languages in config
- Check tool compatibility in the matrix above

**Coverage reports showing unexpected results**
- Ensure test files aren't excluded from coverage
- Check `.coveragerc` or coverage configuration in your test framework
- Use `--verbose` to see which coverage tool is being used

### Getting Help

- Run `aiq --help` or `./quality/check.sh --help` for command options
- Use `--verbose` flag for detailed output: `aiq run --verbose`
- Check failed stages with: `aiq run --only N --verbose`

## Documentation

- Start here: docs/README.md
- Stage System Details: docs/stage_system.md
- E2E Integration Guide: docs/e2e_integration.md
- Security and IaC: Secrets scanning (gitleaks), SAST (semgrep), Terraform (tflint/tfsec)
- Cross-platform setup: macOS (brew), Linux (apt/yum), Windows (winget/scoop guidance)

## Project Structure

After installation, your project will have these quality-related files:

```
your-project/
├── .aiq/                          # Configuration directory
│   ├── quality.config.json        # User configuration (optional)
│   └── progress.json              # Current stage progress
├── .git/
│   └── hooks/
│       └── pre-commit             # Quality checks on commit
├── .github/
│   └── workflows/
│       └── quality.yml            # GitHub Actions CI
└── quality/                       # Quality system (manual install)
    ├── bin/                       # Internal scripts
    ├── configs/                   # Tool configurations
    ├── hooks/                     # Git hooks
    ├── lib/                       # Shared libraries
    ├── stages/                    # Individual stage scripts
    ├── check.sh                   # Main entry point
    └── install.sh                 # Installation script
```

### File Descriptions

- **`.aiq/quality.config.json`**: Optional configuration file for customizing behavior
- **`.aiq/progress.json`**: Tracks which quality stages you've enabled (staged rollout)
- **`quality/`**: The complete quality system (created by manual installation)
- **`.git/hooks/pre-commit`**: Runs quality checks before commits
- **`.github/workflows/quality.yml`**: Runs quality checks in CI/CD

## License

MIT License - see LICENSE file for details.
