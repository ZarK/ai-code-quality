#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"



if "$QUALITY_DIR/bin/phase_checks.sh" "$@"; then
    exit 0
else
    exit_code=$?
    
    # Extract failed stage from phase_checks output if possible
    # For now, provide general debugging help
    echo ""
    echo "To debug a specific stage, run it with verbose output:"
    echo "  ./quality/stages/1-lint.sh --verbose"
    echo "  ./quality/stages/2-format.sh --verbose"
    echo "  ./quality/stages/3-type_check.sh --verbose"
    echo "  ./quality/stages/4-unit_test.sh --verbose"
    echo "  ./quality/stages/5-sloc.sh --verbose"
    echo "  ./quality/stages/6-complexity.sh --verbose"
    echo "  ./quality/stages/7-maintainability.sh --verbose"
    echo "  ./quality/stages/8-coverage.sh --verbose"
    
    exit $exit_code
fi
