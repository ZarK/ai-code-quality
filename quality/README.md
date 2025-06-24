# Quality Module

This directory contains the Universal Code Quality System.

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
