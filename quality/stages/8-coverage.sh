#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

# If no tests are present across detected technologies, succeed with sentinel
if ! any_tests_present; then
    echo "AIQ_NO_TESTS=1"
    exit 0
fi

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

if [[ "$TECHS" == *"dotnet"* ]]; then
    debug "Running .NET coverage (coverlet if configured)..."
    if ! dotnet_coverage; then
        error ".NET coverage failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"java"* ]]; then
    debug "Running Java coverage (JaCoCo if configured)..."
    if ! java_coverage; then
        error "Java coverage failed"
        FAILED=1
    fi
fi

exit $FAILED
