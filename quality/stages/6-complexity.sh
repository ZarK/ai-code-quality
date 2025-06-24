#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running radon complexity check..."
    if ! radon_complexity; then
        error "radon complexity check failed"
        FAILED=1
    fi
fi

exit $FAILED
