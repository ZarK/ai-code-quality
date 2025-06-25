#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUALITY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$QUALITY_DIR/.." && pwd)"

VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

log() {
    if [[ "$VERBOSE" == true ]]; then
        printf "%s\n" "$*"
    fi
}

detect_e2e_framework() {
    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        if grep -q '"@playwright/test"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            echo "playwright"
            return
        fi
    fi

    if [[ -f "$PROJECT_ROOT/pyproject.toml" ]] || [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
        if grep -q "playwright" "$PROJECT_ROOT/pyproject.toml" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
            echo "playwright-python"
            return
        fi
        if grep -q "pytest" "$PROJECT_ROOT/pyproject.toml" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
            echo "pytest"
            return
        fi
    fi

    echo "none"
}

find_e2e_directory() {
    local default_paths=("tests/e2e" "e2e" "test/e2e")

    for path in "${default_paths[@]}"; do
        if [[ -d "$PROJECT_ROOT/$path" ]]; then
            echo "$PROJECT_ROOT/$path"
            return
        fi
    done

    echo ""
}

run_e2e_tests() {
    local framework
    framework=$(detect_e2e_framework)

    local e2e_dir
    e2e_dir=$(find_e2e_directory)

    if [[ -z "$e2e_dir" ]]; then
        log "No E2E test directory found (checked: tests/e2e, e2e, test/e2e)"
        log "E2E tests skipped"
        return 0
    fi

    log "Found E2E directory: $e2e_dir"
    log "Detected framework: $framework"

    cd "$PROJECT_ROOT"

    case "$framework" in
    playwright)
        log "Running Playwright tests..."
        if command -v npx >/dev/null 2>&1; then
            npx playwright test "$e2e_dir"
        else
            log "npx not found, trying direct playwright command..."
            playwright test "$e2e_dir"
        fi
        ;;
    playwright-python)
        log "Running Python Playwright tests..."
        if command -v uv >/dev/null 2>&1; then
            uv run pytest "$e2e_dir"
        else
            python3 -m pytest "$e2e_dir"
        fi
        ;;
    pytest)
        log "Running pytest E2E tests..."
        if command -v uv >/dev/null 2>&1; then
            uv run pytest "$e2e_dir"
        else
            python3 -m pytest "$e2e_dir"
        fi
        ;;
    none)
        log "No supported E2E framework detected"
        log "Supported frameworks: Playwright (JS/TS), Playwright (Python), pytest"
        log "E2E tests skipped"
        return 0
        ;;
    *)
        log "Unknown E2E framework: $framework"
        return 1
        ;;
    esac
}

main() {
    if ! run_e2e_tests; then
        if [[ "$VERBOSE" == true ]]; then
            printf "E2E tests failed\n" >&2
        fi
        exit 1
    fi

    if [[ "$VERBOSE" == true ]]; then
        printf "E2E tests passed\n"
    fi
}

main "$@"
