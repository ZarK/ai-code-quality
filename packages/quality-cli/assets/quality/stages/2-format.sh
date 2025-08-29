#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running ruff format check..."
    if ! ruff_format; then
        error "ruff format failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then
    debug "Running biome format check..."
    if ! biome_format; then
        error "biome format failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"shell"* ]]; then
    debug "Running shfmt format check..."
    if ! shfmt_format; then
        error "shfmt format failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"dotnet"* ]]; then
    debug "Running dotnet format check..."
    if ! dotnet_format_check; then
        error ".NET format check failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"java"* ]]; then
    debug "Running google-java-format check..."
    if ! java_format_check; then
        error "Java format check failed"
        FAILED=1
    fi
fi

if [[ "$TECHS" == *"hcl"* ]]; then
    debug "Running HCL/Terraform format check..."
    if ! hcl_format_check; then
        error "HCL/Terraform format check failed"
        FAILED=1
    fi
fi

exit $FAILED
