#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running pytest unit tests..."
    if ! pytest_unit; then
        error "pytest unit tests failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then
    debug "Running vitest unit tests..."
    if ! vitest_unit; then
        error "vitest unit tests failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"dotnet"* ]]; then
    debug "Running .NET unit tests..."
    if ! dotnet_test; then
        error ".NET unit tests failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"java"* ]]; then
    debug "Running Java unit tests..."
    if ! java_test; then
        error "Java unit tests failed"
        FAILED=1
    fi
fi

exit $FAILED
