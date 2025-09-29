#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

get_stage_name() {
    case "$1" in
    0) echo "e2e" ;;
    1) echo "lint" ;;
    2) echo "format" ;;
    3) echo "type_check" ;;
    4) echo "unit_test" ;;
    5) echo "sloc" ;;
    6) echo "complexity" ;;
    7) echo "maintainability" ;;
    8) echo "coverage" ;;
    9) echo "security" ;;
    *) echo "unknown" ;;
    esac
}

AIQ_DIR="$(cd "$QUALITY_DIR/.." && pwd)/.aiq"
AIQ_TMP_DIR="$AIQ_DIR/tmp"
mkdir -p "$AIQ_TMP_DIR"
FAILED_FILE="$AIQ_TMP_DIR/failed_stages.$$"
export FAILED_STAGES_FILE="$FAILED_FILE"
rm -f "$FAILED_FILE"

if "$QUALITY_DIR/bin/phase_checks.sh" "$@"; then
    exit 0
else
    exit_code=$?

    if [[ -f "$FAILED_FILE" ]] && [[ -s "$FAILED_FILE" ]]; then
        echo ""
        echo "To debug failed stages, run with verbose output:"
        while read -r stage; do
            stage_name=$(get_stage_name "$stage")
            echo "  $QUALITY_DIR/stages/${stage}-${stage_name}.sh --verbose"
        done <"$FAILED_FILE"
        rm -f "$FAILED_FILE"
    fi

    exit $exit_code
fi
