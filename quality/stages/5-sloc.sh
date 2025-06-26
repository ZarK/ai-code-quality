#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)
FAILED=0

run_checks() {
    debug "Running SLOC analysis..."

    if command -v scc >/dev/null 2>&1; then
        debug "Using scc for SLOC analysis..."
        scc --exclude-dir .git,node_modules,.venv,venv,__pycache__,.pytest_cache,dist,build,target,bin,obj .
    elif command -v cloc >/dev/null 2>&1; then
        debug "Using cloc for SLOC analysis..."
        cloc . --exclude-dir=node_modules,.venv,venv,.git,__pycache__,.pytest_cache,dist,build,target,bin,obj
    else
        debug "Neither scc nor cloc found, skipping SLOC analysis"
        return 0
    fi

    # Python-specific file size check (keep existing logic)
    if [[ "$TECHS" == *"python"* ]]; then
        debug "Running Python-specific SLOC check..."
        if ! radon_sloc; then
            error "Python SLOC check failed (files >= 350 lines)"
            return 1
        fi
    fi
}

if ! run_checks; then
    FAILED=1
fi

exit $FAILED
