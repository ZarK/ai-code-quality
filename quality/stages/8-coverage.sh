#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running pytest coverage..."
    if ! pytest_coverage; then
        error "pytest coverage failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then
    debug "Running vitest coverage..."
    if ! vitest_coverage; then
        error "vitest coverage failed"
        FAILED=1
    fi
fi

exit $FAILED
