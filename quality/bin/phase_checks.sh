#!/usr/bin/env bash

set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE_FILE="$QUALITY_DIR/.phase_progress"

printf "🚀 Phase Checks System
"
printf "======================
"

techs=$("$QUALITY_DIR/lib/detect_tech.sh" "$@")
printf "📋 Detected: %s
" "${techs:-none}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    printf "
Usage: %s [options]

" "$0"
    printf "Options:
"
    printf "  --override <tech> Override technology detection
"
    exit 0
fi
