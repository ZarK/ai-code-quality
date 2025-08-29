#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running radon SLOC check..."
    if ! radon_sloc; then
        error "radon SLOC check failed"
        FAILED=1
    fi
fi

# Lizard-powered SLOC for non-Python languages
if [[ "$TECHS" == *"dotnet"* || "$TECHS" == *"java"* || "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* || "$TECHS" == *"go"* ]]; then
    debug "Running lizard SLOC checks for detected non-Python languages..."
    if ! lizard_sloc_multi; then
        error "lizard SLOC check failed"
        FAILED=1
    fi
fi

exit $FAILED
