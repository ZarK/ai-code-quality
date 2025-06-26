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

if [[ "$TECHS" == *"html"* ]]; then
    debug "Running htmlhint..."
    if ! htmlhint_check; then
        error "htmlhint failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"css"* ]]; then
    debug "Running stylelint..."
    if ! stylelint_check; then
        error "stylelint failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"docker"* ]]; then
    debug "Running hadolint..."
    if ! hadolint_check; then
        error "hadolint failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"kubernetes"* ]]; then
    debug "Running kubeconform..."
    if ! kubeconform_check; then
        error "kubeconform failed"
        FAILED=1
    fi
fi

if [[ $FAILED -eq 0 ]]; then
    log "All checks passed!"
fi

exit $FAILED
