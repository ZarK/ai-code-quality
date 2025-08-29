#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

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

if [[ "$TECHS" == *"dotnet"* ]]; then
    debug "Running .NET build as type check..."
    if ! dotnet_build_check; then
        error ".NET build failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"java"* ]]; then
    debug "Running Java build as type check..."
    if ! java_build_check; then
        error "Java build/type check failed"
        FAILED=1
    fi
fi

exit $FAILED
