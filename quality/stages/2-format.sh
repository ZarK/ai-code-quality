#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running ruff lint checks..."
    if ! ruff_check; then
        error "ruff lint failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then
    debug "Running biome lint checks..."
    if ! biome_check; then
        error "biome lint failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"shell"* ]]; then
    debug "Running shellcheck..."
    if ! shellcheck_check; then
        error "shellcheck failed"
        FAILED=1
    fi
fi

# HTML and CSS linting is handled by biome_check above

if [[ "$TECHS" == *"java"* ]]; then
    debug "Running Java checkstyle..."
    if ! java_checkstyle; then
        error "Java lint (checkstyle) failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"kotlin"* ]]; then
    debug "Running ktlint lint check..."
    if ! kotlin_lint_check; then
        error "Kotlin lint (ktlint) failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"dotnet"* ]]; then
    debug "Running .NET lint check..."
    if ! dotnet_lint_check; then
        error ".NET lint failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"hcl"* ]]; then
    debug "Running Terraform/HCL lint..."
    if ! hcl_lint_check; then
        error "HCL/Terraform lint failed"
        FAILED=1
    fi
fi

if [[ $FAILED -eq 0 ]]; then
    log "All checks passed!"
fi

exit $FAILED