#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running radon maintainability check..."
    if ! radon_maintainability; then
        error "radon maintainability check failed"
        FAILED=1
    fi

    debug "Running radon readability check..."
    if ! radon_readability; then
        error "radon readability check failed"
        FAILED=1
    fi
fi

exit $FAILED
