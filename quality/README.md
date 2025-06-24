# Quality Module

This directory contains the Universal Code Quality System.

## Prerequisites

This system assumes you have the following modern development tools installed:

### Required Tools
- **asdf** - Version manager for Python and Node.js
  - Install: https://asdf-vm.com/guide/getting-started.html
  - Required plugins: `asdf plugin add python` and `asdf plugin add nodejs`
- **uv** - Fast Python package installer and resolver
  - Install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- **bun** - Fast JavaScript runtime and package manager
  - Install: `curl -fsSL https://bun.sh/install | bash`
- **Homebrew** (macOS/Linux) - Only for shell tools (shellcheck, shfmt)
  - Install: https://brew.sh

### Python Version Support
- Python 3.12+ (managed via asdf)
- The system respects whatever Python version is active in your asdf environment

### Node.js Version Support  
- Node.js 18+ (managed via asdf)
- The system respects whatever Node.js version is active in your asdf environment

### Installation
Run `./bin/install_tools.sh` to install all required quality tools.

## Structure

```
quality/
├── bin/                    # Executable scripts
│   ├── run_checks.sh      # Main entry point
│   └── phase_checks.sh    # Core phase logic
├── configs/               # Configuration files
│   ├── python/           # Python tool configs
│   ├── js/               # JavaScript/TypeScript configs
│   └── html/             # HTML/CSS configs
├── hooks/                # Git hooks
│   └── pre-commit        # Pre-commit hook
├── lib/                  # Library scripts
│   └── detect_tech.sh    # Technology detection
└── .phase_progress       # Current phase tracking
```

## Usage

See the main README.md for usage instructions.

## Adding New Technologies

1. Update `lib/detect_tech.sh` to detect the new technology
2. Add check functions to `bin/phase_checks.sh`
3. Create configuration files in `configs/new-tech/`
4. Register the phases in the `register_phases()` function

## Adding New Phases

1. Create a new check function: `check_N_description()`
2. Add it to the appropriate technology in `register_phases()`
3. The system will automatically discover and use the new phase
