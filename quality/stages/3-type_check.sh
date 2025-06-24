#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running mypy type check..."
    if ! mypy_check; then
        error "mypy type check failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"ts"* ]]; then
    debug "Running TypeScript type check..."
    if ! tsc_check; then
        error "TypeScript type check failed"
        FAILED=1
    fi
fi

exit $FAILED
