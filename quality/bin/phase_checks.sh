#!/usr/bin/env bash
# shellcheck disable=SC2317
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE_FILE="$QUALITY_DIR/.phase_progress"

# =============================================================================
# TOOL CHECK FUNCTIONS (One-liner wrappers)
# =============================================================================

# Python tools
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

pytest_unit() {
    if command -v pytest >/dev/null 2>&1; then
        pytest
    else
        .venv/bin/pytest
    fi
}

pytest_coverage() {
    if command -v pytest >/dev/null 2>&1; then
        pytest --cov=. --cov-report=term-missing
    else
        .venv/bin/pytest --cov=. --cov-report=term-missing
    fi
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

# JavaScript/TypeScript tools
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

tsc_check() {
    if [[ -f "tsconfig.json" ]]; then
        if command -v bunx >/dev/null 2>&1; then
            bunx tsc --noEmit
        else
            npx tsc --noEmit
        fi
    fi
}

vitest_unit() {
    if command -v bunx >/dev/null 2>&1; then
        bunx vitest run
    else
        npx vitest run
    fi
}

vitest_coverage() {
    if command -v bunx >/dev/null 2>&1; then
        bunx vitest run --coverage
    else
        npx vitest run --coverage
    fi
}

# Shell tools
shellcheck_check() {
    find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print0 | xargs -0 shellcheck
}

shfmt_format() {
    find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print0 | xargs -0 shfmt -i 4 -d
}

# HTML/CSS tools
htmlhint_check() {
    if find . -name "*.html" -not -path "./node_modules/*" -not -path "./.venv/*" | head -1 | grep -q .; then
        if command -v bunx >/dev/null 2>&1; then
            bunx htmlhint "**/*.html"
        else
            npx htmlhint "**/*.html"
        fi
    fi
}

stylelint_check() {
    if find . -name "*.css" -not -path "./node_modules/*" -not -path "./.venv/*" | head -1 | grep -q .; then
        if command -v bunx >/dev/null 2>&1; then
            bunx stylelint "**/*.css"
        else
            npx stylelint "**/*.css"
        fi
    fi
}

# =============================================================================
# 8-STAGE PHASE FUNCTIONS
# =============================================================================

stage_1_lint() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        ruff_check && ran_checks=true
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        biome_check && ran_checks=true
    fi
    if [[ "$techs" == *"shell"* ]]; then
        shellcheck_check && ran_checks=true
    fi
    if [[ "$techs" == *"html"* ]]; then
        htmlhint_check && ran_checks=true
    fi
    if [[ "$techs" == *"css"* ]]; then
        stylelint_check && ran_checks=true
    fi

    $ran_checks
}

stage_2_format() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        ruff_format && ran_checks=true
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        biome_format && ran_checks=true
    fi
    if [[ "$techs" == *"shell"* ]]; then
        shfmt_format && ran_checks=true
    fi

    $ran_checks
}

stage_3_type_check() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        mypy_check && ran_checks=true
    fi
    if [[ "$techs" == *"ts"* ]]; then
        tsc_check && ran_checks=true
    fi

    $ran_checks
}

stage_4_unit_test() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        pytest_unit && ran_checks=true
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        vitest_unit && ran_checks=true
    fi

    $ran_checks
}

stage_5_sloc() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        radon_sloc && ran_checks=true
    fi

    $ran_checks
}

stage_6_complexity() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        radon_complexity && ran_checks=true
    fi

    $ran_checks
}

stage_7_maintainability() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        radon_maintainability && radon_readability && ran_checks=true
    fi

    $ran_checks
}

stage_8_coverage() {
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    local ran_checks=false

    if [[ "$techs" == *"python"* ]]; then
        pytest_coverage && ran_checks=true
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        vitest_coverage && ran_checks=true
    fi

    $ran_checks
}

# =============================================================================
# PHASE MANAGEMENT
# =============================================================================

get_current_stage() {
    if [[ -f "$PHASE_FILE" ]]; then
        head -n1 "$PHASE_FILE" | tr -d '[:space:]'
    else
        echo "1"
    fi
}

set_current_stage() {
    local new_stage=$1
    echo "$new_stage" >"$PHASE_FILE"
}

get_available_stages() {
    echo "1 2 3 4 5 6 7 8"
}

get_stage_name() {
    case "$1" in
    1) echo "lint" ;;
    2) echo "format" ;;
    3) echo "type_check" ;;
    4) echo "unit_test" ;;
    5) echo "sloc" ;;
    6) echo "complexity" ;;
    7) echo "maintainability" ;;
    8) echo "coverage" ;;
    *) echo "unknown" ;;
    esac
}

run_stage() {
    local stage=$1
    local stage_name
    stage_name=$(get_stage_name "$stage")
    local stage_function="stage_${stage}_${stage_name}"

    if declare -F "$stage_function" >/dev/null; then
        printf "Stage %s: " "$stage"
        if "$stage_function" >/dev/null 2>&1; then
            printf "PASSED\n"
        else
            printf "FAILED\n"
            return 1
        fi
    else
        printf "Unknown stage: %s\n" "$stage" >&2
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION LOGIC
# =============================================================================

main() {
    local target_stage="${1:-}"

    if [[ -z "$target_stage" ]]; then
        target_stage=$(get_current_stage)
    fi

    local current_stage
    current_stage=$(get_current_stage)

    local available_stages
    available_stages=$(get_available_stages)

    local failed_stages=()

    # Run all stages up to and including target stage
    for stage in $available_stages; do
        if [[ "$stage" -le "$target_stage" ]]; then
            if ! run_stage "$stage"; then
                failed_stages+=("$stage")

                # If this is a previous stage, it's a regression
                if [[ "$stage" -lt "$target_stage" ]]; then
                    printf "REGRESSION in Stage %s - previous stages must not regress\n" "$stage" >&2
                    exit 1
                fi
            fi
        fi
    done

    if [[ ${#failed_stages[@]} -eq 0 ]]; then
        # Update current stage if target is newer
        if [[ "$current_stage" -lt "$target_stage" ]]; then
            set_current_stage "$target_stage"
        fi
        exit 0
    else
        # Check if only current stage failed (allowed for WIP)
        if [[ ${#failed_stages[@]} -eq 1 && "${failed_stages[0]}" == "$target_stage" ]]; then
            exit 0
        else
            printf "Previous stages failed - regression detected\n" >&2
            exit 1
        fi
    fi
}

# Handle special commands
case "${1:-}" in
--list-stages)
    printf "Available stages:\n"
    for stage in $(get_available_stages); do
        printf "  %s (%s)\n" "$stage" "$(get_stage_name "$stage")"
    done
    exit 0
    ;;
--current-stage)
    get_current_stage
    exit 0
    ;;
--set-stage)
    if [[ -z "${2:-}" ]]; then
        printf "Usage: %s --set-stage <stage>\n" "$0" >&2
        exit 1
    fi
    set_current_stage "$2"
    exit 0
    ;;
--help | -h)
    printf "Usage: %s [stage|command]\n\n" "$0"
    printf "Commands:\n"
    printf "  --list-stages     List all available stages\n"
    printf "  --current-stage   Show current stage\n"
    printf "  --set-stage <s>   Set current stage\n"
    printf "  --help           Show this help\n"
    printf "\nStages:\n"
    for stage in $(get_available_stages); do
        printf "  %s (%s)\n" "$stage" "$(get_stage_name "$stage")"
    done
    exit 0
    ;;
esac

main "$@"
