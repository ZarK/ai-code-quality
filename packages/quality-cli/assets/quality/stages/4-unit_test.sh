#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then
    if ! js_test_unit; then
        error "JS/TS unit tests failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"python"* ]]; then
    TEST_FRAMEWORK=$(detect_python_test_framework)
    if [[ "$TEST_FRAMEWORK" == "pytest" ]]; then
        debug "Running pytest unit tests..."
        if ! pytest_unit; then
            error "pytest unit tests failed"
            FAILED=1
        fi
    elif [[ "$TEST_FRAMEWORK" == "unittest" ]]; then
        debug "Running unittest unit tests..."
        if ! unittest_unit; then
            error "unittest unit tests failed"
            FAILED=1
        fi
    else
        debug "No Python test framework detected"
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

if [[ "$TECHS" == *"kotlin"* ]]; then
    debug "Running Kotlin unit tests..."
    if ! kotlin_test; then
        error "Kotlin unit tests failed"
        FAILED=1
    fi
fi

exit $FAILED
