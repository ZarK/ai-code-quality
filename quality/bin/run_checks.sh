#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

get_stage_name() {
    case "$1" in
    1) echo "lint" ;;
    2) echo "format" ;;
    3) echo "type_check" ;;
    4) echo "unit_test" ;;
    5) echo "sloc" ;;
    6) echo "complexity" ;;
    7) echo "maintainability" ;;
    8) echo "coverage" ;;
    *) echo "unknown" ;;
    esac
}

if "$QUALITY_DIR/bin/phase_checks.sh" "$@" 2>/tmp/failed_stages.txt; then
    exit 0
else
    exit_code=$?

    if [[ -f /tmp/failed_stages.txt ]] && [[ -s /tmp/failed_stages.txt ]]; then
        echo ""
        echo "To debug failed stages, run with verbose output:"
        while read -r stage; do
            stage_name=$(get_stage_name "$stage")
            echo "  $QUALITY_DIR/stages/${stage}-${stage_name}.sh --verbose"
        done </tmp/failed_stages.txt
        rm -f /tmp/failed_stages.txt
    fi

    exit $exit_code
fi
