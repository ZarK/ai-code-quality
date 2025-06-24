#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running radon SLOC check..."
    if ! radon_sloc; then
        error "radon SLOC check failed"
        FAILED=1
    fi
fi

exit $FAILED
