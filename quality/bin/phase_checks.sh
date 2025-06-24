#!/usr/bin/env bash
# shellcheck disable=SC2317
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE_FILE="$QUALITY_DIR/.phase_progress"

# =============================================================================
# MODULAR CHECK FUNCTIONS
# =============================================================================

shellcheck_check() {
    find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print0 | xargs -0 shellcheck
}

shfmt_check() {
    find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print0 | xargs -0 shfmt -i 4 -d
}

ruff_check() {
    if command -v ruff >/dev/null 2>&1; then
        ruff check .
    else
        .venv/bin/ruff check .
    fi
}

ruff_format() {
    if command -v ruff >/dev/null 2>&1; then
        ruff format --check .
    else
        .venv/bin/ruff format --check .
    fi
}

mypy_check() {
    if command -v mypy >/dev/null 2>&1; then
        mypy . --config-file "$QUALITY_DIR/configs/python/mypy.ini"
    else
        .venv/bin/mypy . --config-file "$QUALITY_DIR/configs/python/mypy.ini"
    fi
}

pytest_check() {
    if command -v pytest >/dev/null 2>&1; then
        pytest
    else
        .venv/bin/pytest
    fi
}

radon_complexity() {
    local radon_output
    if command -v radon >/dev/null 2>&1; then
        radon_output=$(radon cc . -s -na)
    else
        radon_output=$(.venv/bin/radon cc . -s -na)
    fi

    if echo "$radon_output" | grep -qE ' - (C|D|E|F) \('; then
        echo "$radon_output" >&2
        return 1
    fi
}

radon_maintainability() {
    local radon_output
    if command -v radon >/dev/null 2>&1; then
        radon_output=$(radon mi . -s)
    else
        radon_output=$(.venv/bin/radon mi . -s)
    fi

    if echo "$radon_output" | grep ' - [A-F] (' | awk -F'[()]' '{if ($2 != "" && $2 < 40) exit 1}'; then
        return 0
    else
        echo "$radon_output" >&2
        return 1
    fi
}

radon_readability() {
    local python_cmd=""
    if command -v python3 >/dev/null 2>&1; then
        python_cmd="python3"
    else
        python_cmd=".venv/bin/python"
    fi

    $python_cmd - <<'PY'
import re, sys, math
from pathlib import Path
from radon.metrics import h_visit
from radon.complexity import cc_visit
from radon.raw import analyze

TH = 85
bad = []

for f in Path(".").rglob("*.py"):
    if any(part in str(f) for part in ['.venv', '__pycache__', '.git', 'node_modules', '.pytest_cache', '.mypy_cache']):
        continue
        
    try:
        code = f.read_text()
    except:
        continue

    h_tot = h_visit(code).total
    V = h_tot.volume
    D = h_tot.difficulty
    CC = [b.complexity for b in cc_visit(code)]
    avg_CC = sum(CC) / len(CC) if CC else 0
    raw = analyze(code)
    SLOC = raw.sloc
    C_pct = raw.comments / SLOC if SLOC else 0

    long_names = len([n for n in re.findall(r'\b[_a-zA-Z]\w*\b', code) if len(n) > 20])
    vague_names = len(re.findall(r'\b(data|info|item|obj|temp|tmp|val|var|thing|stuff|helper|util|manager|handler|service|processor|controller)\b', code, re.IGNORECASE))
    redundant_prefixes = len(re.findall(r'\b(current_|new_|old_|temp_|tmp_|get_|set_|do_|make_|create_|build_)\w+\b', code))

    unique_ratio = h_tot.h1 / max(h_tot.N1, 1) if h_tot.N1 > 0 else 1
    vocab_density = (h_tot.h1 + h_tot.h2) / max(SLOC, 1)

    RI = (
        100
        - 1.5 * math.log10(max(V, 1))
        - 1.2 * D
        - 0.6 * avg_CC
        - 0.05 * SLOC
        - 30 * max(C_pct - 0.25, 0)
        - 2 * long_names
        - 3 * vague_names
        - 2 * redundant_prefixes
        - 10 * max(vocab_density - 2, 0)
    )

    if RI < TH:
        bad.append((RI, f))

if bad:
    for score, path in sorted(bad):
        print(f"{path}: RI {score:.1f} < {TH}", file=sys.stderr)
    sys.exit(1)
PY
}

radon_sloc() {
    local radon_output
    if command -v radon >/dev/null 2>&1; then
        radon_output=$(radon raw .)
    else
        radon_output=$(.venv/bin/radon raw .)
    fi

    echo "$radon_output" | awk '
        BEGIN { current_file = ""; overall_exit_code = 0; }
        /^[a-zA-Z0-9_\-\/\.]+\.py$/ { current_file = $0; }
        /^[[:space:]]*SLOC:/ {
            if (current_file != "") {
                sloc_val = $2;
                if (sloc_val >= 350) {
                    printf "%s: %d lines >= 350\n", current_file, sloc_val > "/dev/stderr";
                    overall_exit_code = 1;
                }
                current_file = "";
            }
        }
        END { exit overall_exit_code; }
    '
}

biome_check() {
    if command -v bunx >/dev/null 2>&1; then
        bunx biome check --reporter=summary .
    else
        npx @biomejs/biome check --reporter=summary .
    fi
}

biome_format() {
    if command -v bunx >/dev/null 2>&1; then
        bunx biome format --check .
    else
        npx @biomejs/biome format --check .
    fi
}

vitest_check() {
    if command -v bunx >/dev/null 2>&1; then
        bunx vitest run
    else
        npx vitest run
    fi
}

# =============================================================================
# PHASE FUNCTIONS (Composable from modular checks)
# =============================================================================

check_1() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    if [[ "$techs" == *"shell"* ]]; then
        shellcheck_check && shfmt_check
    fi
    if [[ "$techs" == *"python"* ]]; then
        ruff_check && ruff_format
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        biome_check
    fi
}

check_2() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    if [[ "$techs" == *"python"* ]]; then
        mypy_check
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        biome_format
    fi
}

check_3() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    if [[ "$techs" == *"python"* ]]; then
        pytest_check
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        vitest_check
    fi
}

check_4() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    if [[ "$techs" == *"python"* ]]; then
        radon_complexity && radon_maintainability && radon_readability && radon_sloc
    fi
}

# =============================================================================
# PHASE MANAGEMENT
# =============================================================================

get_current_phase() {
    if [[ -f "$PHASE_FILE" ]]; then
        head -n1 "$PHASE_FILE" | tr -d '[:space:]'
    else
        echo "1"
    fi
}

set_current_phase() {
    local new_phase=$1
    echo "$new_phase" >"$PHASE_FILE"
}

get_available_phases() {
    declare -F | grep "declare -f check_" | sed 's/declare -f check_//' | sort -n
}

run_phase() {
    local phase=$1
    local check_function="check_$phase"

    if declare -F "$check_function" >/dev/null; then
        printf "Running Phase %s: " "$phase"
        if "$check_function"; then
            printf "PASSED\n"
        else
            printf "FAILED\n"
            return 1
        fi
    else
        printf "Unknown phase: %s\n" "$phase" >&2
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION LOGIC
# =============================================================================

main() {
    local target_phase="${1:-}"

    if [[ -z "$target_phase" ]]; then
        target_phase=$(get_current_phase)
    fi

    local current_phase
    current_phase=$(get_current_phase)

    local available_phases
    available_phases=$(get_available_phases)

    local failed_phases=()

    # Run all phases up to and including target phase
    for phase in $available_phases; do
        if [[ "$phase" -le "$target_phase" ]]; then
            if ! run_phase "$phase"; then
                failed_phases+=("$phase")

                # If this is a previous phase, it's a regression
                if [[ "$phase" -lt "$target_phase" ]]; then
                    printf "REGRESSION in Phase %s - previous phases must not regress\n" "$phase" >&2
                    exit 1
                fi
            fi
        fi
    done

    if [[ ${#failed_phases[@]} -eq 0 ]]; then
        # Update current phase if target is newer
        if [[ "$current_phase" -lt "$target_phase" ]]; then
            set_current_phase "$target_phase"
        fi
        exit 0
    else
        # Check if only current phase failed (allowed for WIP)
        if [[ ${#failed_phases[@]} -eq 1 && "${failed_phases[0]}" == "$target_phase" ]]; then
            exit 0
        else
            printf "Previous phases failed - regression detected\n" >&2
            exit 1
        fi
    fi
}

# Handle special commands
case "${1:-}" in
--list-phases)
    printf "Available phases:\n"
    get_available_phases | sed 's/^/  /'
    exit 0
    ;;
--current-phase)
    get_current_phase
    exit 0
    ;;
--set-phase)
    if [[ -z "${2:-}" ]]; then
        printf "Usage: %s --set-phase <phase>\n" "$0" >&2
        exit 1
    fi
    set_current_phase "$2"
    exit 0
    ;;
--help | -h)
    printf "Usage: %s [phase|command]\n\n" "$0"
    printf "Commands:\n"
    printf "  --list-phases     List all available phases\n"
    printf "  --current-phase   Show current phase\n"
    printf "  --set-phase <p>   Set current phase\n"
    printf "  --help           Show this help\n"
    printf "\nPhases:\n"
    get_available_phases | sed 's/^/  /'
    exit 0
    ;;
esac

main "$@"
