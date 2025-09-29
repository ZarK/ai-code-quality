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
    TEST_FRAMEWORK=$(detect_python_test_framework)
    if [[ "$TEST_FRAMEWORK" == "pytest" ]]; then
        debug "Running pytest coverage..."
        if ! pytest_coverage; then
            error "pytest coverage failed"
            FAILED=1
        fi
    elif [[ "$TEST_FRAMEWORK" == "unittest" ]]; then
        debug "Running unittest coverage..."
        if ! unittest_coverage; then
            error "unittest coverage failed"
            FAILED=1
        fi
    else
        debug "No Python test framework detected for coverage"
    fi
fi

if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then
    if ! js_test_coverage; then
        error "JS/TS test coverage failed"
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

if [[ "$TECHS" == *"kotlin"* ]]; then
    debug "Running Kotlin coverage (JaCoCo/Kover if configured)..."
    if ! kotlin_coverage; then
        error "Kotlin coverage failed"
        FAILED=1
    fi
fi

exit $FAILED
