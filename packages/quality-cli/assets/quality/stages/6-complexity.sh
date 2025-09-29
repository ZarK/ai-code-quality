#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

if [[ "$TECHS" == *"python"* ]]; then
    debug "Running radon complexity check..."
    if ! radon_complexity; then
        error "radon complexity check failed"
        FAILED=1
    fi
fi

# Lizard-powered complexity for non-Python languages
if [[ "$TECHS" == *"dotnet"* || "$TECHS" == *"java"* || "$TECHS" == *"kotlin"* || "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* || "$TECHS" == *"go"* ]]; then
    debug "Running lizard complexity checks for detected non-Python languages..."
    if ! lizard_complexity_multi; then
        error "lizard complexity check failed"
        FAILED=1
    fi
fi

exit $FAILED
