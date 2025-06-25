#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERBOSE=0
QUIET=0

if [[ "${ACTIONS_STEP_DEBUG:-}" == "true" ]] || [[ "${ACTIONS_RUNNER_DEBUG:-}" == "true" ]]; then
    VERBOSE=1
    echo "[DEBUG] GitHub Actions verbose logging detected - enabling verbose output" >&2
fi

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -v | --verbose)
            VERBOSE=1
            QUIET=0
            shift
            ;;
        -q | --quiet)
            QUIET=1
            VERBOSE=0
            shift
            ;;
        *)
            break
            ;;
        esac
    done
}

log() {
    if [[ $QUIET -eq 0 ]]; then
        echo "$*"
    fi
}

debug() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

error() {
    if [[ $QUIET -eq 0 ]]; then
        echo "[ERROR] $*" >&2
    fi
}

detect_tech() {
    "$QUALITY_DIR/lib/detect_tech.sh"
}

run_tool() {
    local tool_name="$1"
    shift

    debug "Running: $tool_name $*"

    if [[ $VERBOSE -eq 1 ]]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

ruff_check() {
    if command -v ruff >/dev/null 2>&1; then
        run_tool "ruff" ruff check .
    else
        run_tool "ruff" .venv/bin/ruff check .
    fi
}

ruff_format() {
    if command -v ruff >/dev/null 2>&1; then
        run_tool "ruff" ruff format --check .
    else
        run_tool "ruff" .venv/bin/ruff format --check .
    fi
}

mypy_check() {
    if command -v mypy >/dev/null 2>&1; then
        run_tool "mypy" mypy . --config-file "$QUALITY_DIR/configs/python/mypy.ini"
    else
        run_tool "mypy" .venv/bin/mypy . --config-file "$QUALITY_DIR/configs/python/mypy.ini"
    fi
}

pytest_unit() {
    if command -v pytest >/dev/null 2>&1; then
        run_tool "pytest" pytest
    else
        run_tool "pytest" .venv/bin/pytest
    fi
}

pytest_coverage() {
    if command -v pytest >/dev/null 2>&1; then
        run_tool "pytest" pytest --cov=. --cov-report=term-missing
    else
        run_tool "pytest" .venv/bin/pytest --cov=. --cov-report=term-missing
    fi
}

radon_sloc() {
    local radon_output
    if command -v radon >/dev/null 2>&1; then
        radon_output=$(radon raw .)
    else
        radon_output=$(.venv/bin/radon raw .)
    fi

    if [[ $VERBOSE -eq 1 ]]; then
        echo "$radon_output"
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

    if [[ $VERBOSE -eq 1 ]]; then
        echo "$radon_output"
    fi

    if echo "$radon_output" | grep -qE ' - (C|D|E|F) \('; then
        if [[ $VERBOSE -eq 0 ]]; then
            echo "$radon_output" >&2
        fi
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

    if [[ $VERBOSE -eq 1 ]]; then
        echo "$radon_output"
    fi

    if echo "$radon_output" | grep ' - [A-F] (' | awk -F'[()]' '{if ($2 != "" && $2 < 40) exit 1}'; then
        return 0
    else
        if [[ $VERBOSE -eq 0 ]]; then
            echo "$radon_output" >&2
        fi
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

    if [[ $VERBOSE -eq 1 ]]; then
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

    print(f"{f}: RI {RI:.1f}")
    if RI < TH:
        bad.append((RI, f))

if bad:
    print("\nFailed files:", file=sys.stderr)
    for score, path in sorted(bad):
        print(f"{path}: RI {score:.1f} < {TH}", file=sys.stderr)
    sys.exit(1)
PY
    else
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
    fi
}

biome_check() {
    if command -v bunx >/dev/null 2>&1; then
        run_tool "biome" bunx biome check --reporter=summary .
    else
        run_tool "biome" npx @biomejs/biome check --reporter=summary .
    fi
}

biome_format() {
    if command -v bunx >/dev/null 2>&1; then
        run_tool "biome" bunx @biomejs/biome check --formatter-enabled=true --linter-enabled=false --organize-imports-enabled=false .
    else
        run_tool "biome" npx @biomejs/biome check --formatter-enabled=true --linter-enabled=false --organize-imports-enabled=false .
    fi
}

tsc_check() {
    if [[ -f "tsconfig.json" ]]; then
        if command -v bunx >/dev/null 2>&1; then
            run_tool "tsc" bunx tsc --noEmit
        else
            run_tool "tsc" npx tsc --noEmit
        fi
    fi
}

vitest_unit() {
    if command -v bunx >/dev/null 2>&1; then
        run_tool "vitest" bunx vitest run
    else
        run_tool "vitest" npx vitest run
    fi
}

vitest_coverage() {
    if command -v bunx >/dev/null 2>&1; then
        run_tool "vitest" bunx vitest run --coverage
    else
        run_tool "vitest" npx vitest run --coverage
    fi
}

shellcheck_check() {
    local shell_files
    shell_files=$(find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print)

    if [[ -z "$shell_files" ]]; then
        return 0
    fi

    local shellcheck_config="$QUALITY_DIR/configs/shell/.shellcheckrc"
    local shellcheck_cmd="shellcheck"
    if [[ -f "$shellcheck_config" ]]; then
        shellcheck_cmd="shellcheck --rcfile=$shellcheck_config"
    fi

    if [[ $VERBOSE -eq 1 ]]; then
        echo "$shell_files" | xargs bash -c 'exec '"$shellcheck_cmd"' "$@"' _
    else
        local shellcheck_output
        shellcheck_output=$(echo "$shell_files" | xargs bash -c 'exec '"$shellcheck_cmd"' "$@"' _ 2>&1)
        local exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            echo "$shellcheck_output" >&2
            return $exit_code
        fi
    fi
}

shfmt_format() {
    if [[ $VERBOSE -eq 1 ]]; then
        find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print0 | xargs -0 shfmt -i 4 -d
    else
        find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print0 | xargs -0 shfmt -i 4 -d >/dev/null 2>&1
    fi
}

htmlhint_check() {
    if find . -name "*.html" -not -path "./node_modules/*" -not -path "./.venv/*" | head -1 | grep -q .; then
        if command -v bunx >/dev/null 2>&1; then
            run_tool "htmlhint" bunx htmlhint "**/*.html"
        else
            run_tool "htmlhint" npx htmlhint "**/*.html"
        fi
    fi
}

stylelint_check() {
    if find . -name "*.css" -not -path "./node_modules/*" -not -path "./.venv/*" | head -1 | grep -q .; then
        if command -v bunx >/dev/null 2>&1; then
            run_tool "stylelint" bunx stylelint "**/*.css"
        else
            run_tool "stylelint" npx stylelint "**/*.css"
        fi
    fi
}
