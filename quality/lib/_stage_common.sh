#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERBOSE=0
QUIET=0
DRY_RUN=0

# Load config from .aiq/quality.config.json if it exists
load_config_env() {
    local config_file=".aiq/quality.config.json"
    if [[ -f "$config_file" ]] && command -v python3 >/dev/null 2>&1; then
        # Load excludes
        local excludes
        excludes=$(python3 -c "import json, sys; data=json.load(sys.stdin); print(':'.join(data.get('excludes', [])))" <"$config_file" 2>/dev/null || true)
        if [[ -n "$excludes" ]]; then
            export AIQ_EXCLUDES="$excludes"
        fi

        # Load language settings
        local python_enabled
        python_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); langs=data.get('languages', {}); print('1' if langs.get('python', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_PYTHON_ENABLED="$python_enabled"

        local js_enabled
        js_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); langs=data.get('languages', {}); print('1' if langs.get('javascript', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_JAVASCRIPT_ENABLED="$js_enabled"

        local dotnet_enabled
        dotnet_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); langs=data.get('languages', {}); print('1' if langs.get('dotnet', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_DOTNET_ENABLED="$dotnet_enabled"

        local java_enabled
        java_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); langs=data.get('languages', {}); print('1' if langs.get('java', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_JAVA_ENABLED="$java_enabled"

        local go_enabled
        go_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); langs=data.get('languages', {}); print('1' if langs.get('go', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_GO_ENABLED="$go_enabled"

        # Load security settings
        local security_enabled
        security_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); sec=data.get('security', {}); print('1' if sec.get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_SECURITY_ENABLED="$security_enabled"

        local gitleaks_enabled
        gitleaks_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); sec=data.get('security', {}); print('1' if sec.get('gitleaks', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_GITLEAKS_ENABLED="$gitleaks_enabled"

        local semgrep_enabled
        semgrep_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); sec=data.get('security', {}); print('1' if sec.get('semgrep', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_SEMGREP_ENABLED="$semgrep_enabled"

        local tfsec_enabled
        tfsec_enabled=$(python3 -c "import json, sys; data=json.load(sys.stdin); sec=data.get('security', {}); print('1' if sec.get('tfsec', {}).get('enabled', True) else '0')" <"$config_file" 2>/dev/null || echo "1")
        export AIQ_TFSEC_ENABLED="$tfsec_enabled"

        # Load semgrep severity
        local semgrep_severity
        semgrep_severity=$(python3 -c "import json, sys; data=json.load(sys.stdin); sec=data.get('security', {}); semgrep=sec.get('semgrep', {}); print(semgrep.get('severity', 'ERROR'))" <"$config_file" 2>/dev/null || echo "ERROR")
        export AIQ_SEMGREP_SEVERITY="$semgrep_severity"
    fi
}

# Load config on script startup (moved after debug function definition)

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
        --dry-run)
            DRY_RUN=1
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

# Load config on script startup
load_config_env

error() {
    if [[ $QUIET -eq 0 ]]; then
        echo "[ERROR] $*" >&2
    fi
}

detect_tech() {
    "$QUALITY_DIR/lib/detect_tech.sh"
}

# If diff-only is requested, read changed files list
_read_changed_filelist() {
    local list_file="${AIQ_CHANGED_FILELIST:-}"
    if [[ -n "$list_file" && -f "$list_file" ]]; then
        cat "$list_file"
    fi
}

_changed_files_by_ext() {
    local ext_regex="$1" # e.g. '\.py$'
    if [[ "${AIQ_CHANGED_ONLY:-}" != "1" ]]; then
        return 1
    fi
    local list
    list=$(_read_changed_filelist | grep -E "$ext_regex" || true)
    if [[ -n "$list" ]]; then
        printf '%s\n' "$list"
        return 0
    fi
    return 1
}

run_tool() {
    local tool_name="$1"
    shift

    debug "Running: $tool_name $*"

    if [[ $DRY_RUN -eq 1 ]]; then
        # In dry-run, print the command and return success
        echo "[DRY-RUN] $tool_name $*"
        return 0
    fi

    if [[ $VERBOSE -eq 1 ]]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

ruff_check() {
    # Diff-only: limit to changed .py files if provided
    local files
    files=$(_changed_files_by_ext '\.py$') || files=""
    if [[ -n "$files" ]]; then
        if command -v ruff >/dev/null 2>&1; then
            run_tool "ruff" ruff check "$files"
        else
            run_tool "ruff" .venv/bin/ruff check "$files"
        fi
        return $?
    fi
    if command -v ruff >/dev/null 2>&1; then
        run_tool "ruff" ruff check .
    else
        run_tool "ruff" .venv/bin/ruff check .
    fi
}

ruff_format() {
    local files
    files=$(_changed_files_by_ext '\.py$') || files=""
    if [[ -n "$files" ]]; then
        if command -v ruff >/dev/null 2>&1; then
            run_tool "ruff" ruff format --check "$files"
        else
            run_tool "ruff" .venv/bin/ruff format --check "$files"
        fi
        return $?
    fi
    if command -v ruff >/dev/null 2>&1; then
        run_tool "ruff" ruff format --check .
    else
        run_tool "ruff" .venv/bin/ruff format --check .
    fi
}

# Utility: build find exclude args from AIQ_EXCLUDES
_build_exclude_args() {
    local excludes=""
    if [[ -n "${AIQ_EXCLUDES:-}" ]]; then
        IFS=':' read -ra PATTERNS <<<"$AIQ_EXCLUDES"
        for pattern in "${PATTERNS[@]}"; do
            excludes="$excludes -not -path \"$pattern\""
        done
    fi
    echo "$excludes"
}

# Utility: detect python source files (excluding common vendor dirs and config excludes)
python_files_present() {
    local exclude_args
    exclude_args=$(_build_exclude_args)
    eval "find . \
        -type f -name \"*.py\" \
        -not -path \"*/.venv/*\" \
        -not -path \"*/node_modules/*\" \
        -not -path \"*/.git/*\" \
        -not -path \"*/__pycache__/*\" \
        -not -path \"*/.pytest_cache/*\" \
        -not -path \"*/.mypy_cache/*\" \
        $exclude_args | head -1 | grep -q ."
}

# Utility: detect python source files (excluding common vendor dirs and config excludes)
python_source_files_present() {
    local exclude_args
    exclude_args=$(_build_exclude_args)
    eval "find . \
        -type f -name \"*.py\" \
        -not -path \"*/.venv/*\" \
        -not -path \"*/.venv-*/*\" \
        -not -path \"*/.venv*/*\" \
        -not -path \"*/venv/*\" \
        -not -path \"*/.tox/*\" \
        -not -path \"*/.direnv/*\" \
        -not -path \"*/node_modules/*\" \
        -not -path \"*/__pycache__/*\" \
        -not -path \"*/.pytest_cache/*\" \
        -not -path \"*/.mypy_cache/*\" \
        -not -path \"*/test_*\" \
        -not -path \"*/tests/*\" \
        -not -path \"*/test-projects/*\" \
        -not -path \"*/test-aiq/*\" \
        -not -path \"*/test-pure-shell/*\" \
        $exclude_args | head -1 | grep -q ."
}

# Utility: detect python test files
python_tests_present() {
    local exclude_args
    exclude_args=$(_build_exclude_args)
    eval "find . \
        -type f \( -name \"test_*.py\" -o -name \"*_test.py\" \) \
        -not -path \"*/.venv/*\" \
        -not -path \"*/.venv-*/*\" \
        -not -path \"*/.venv*/*\" \
        -not -path \"*/venv/*\" \
        -not -path \"*/.tox/*\" \
        -not -path \"*/.direnv/*\" \
        -not -path \"*/node_modules/*\" \
        -not -path \"*/__pycache__/*\" \
        -not -path \"*/.pytest_cache/*\" \
        -not -path \"*/.mypy_cache/*\" \
        $exclude_args | head -1 | grep -q ."
}

# Utility: detect JS/TS test files (vitest/jest conventions)
js_tests_present() {
    find . \
        \( -path "*/.venv/*" -o -path "*/.venv-*/*" -o -path "*/.venv*/*" -o -path "*/venv/*" -o -path "*/.tox/*" -o -path "*/.direnv/*" -o -path "*/node_modules/*" -o -path "*/dist/*" -o -path "*/build/*" -o -path "*/.git/*" \) -prune -o \
        \( -type f \
        \( -name "*.test.js" -o -name "*.spec.js" -o -name "*.test.jsx" -o -name "*.spec.jsx" \
        -o -name "*.test.ts" -o -name "*.spec.ts" -o -name "*.test.tsx" -o -name "*.spec.tsx" \) \
        -o \( -path "*/__tests__/*" -a -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) \) \) \
        -print -quit | grep -q .
}

detect_js_test_runner() {
    # Check package.json for test script and dependencies
    if [[ -f "package.json" ]]; then
        # Check test script in package.json first (most explicit)
        if grep -q '"test":.*jest' package.json 2>/dev/null; then
            echo "jest"
            return 0
        fi
        if grep -q '"test":.*vitest' package.json 2>/dev/null; then
            echo "vitest"
            return 0
        fi
        if grep -q '"test":.*mocha' package.json 2>/dev/null; then
            echo "mocha"
            return 0
        fi
        if grep -q '"test":.*jasmine' package.json 2>/dev/null; then
            echo "jasmine"
            return 0
        fi
        # Check if jest is in dependencies or devDependencies
        if grep -q '"jest"' package.json 2>/dev/null; then
            echo "jest"
            return 0
        fi
        # Check if vitest is in dependencies or devDependencies
        if grep -q '"vitest"' package.json 2>/dev/null; then
            echo "vitest"
            return 0
        fi
        # Check if mocha is in dependencies or devDependencies
        if grep -q '"mocha"' package.json 2>/dev/null; then
            echo "mocha"
            return 0
        fi
        # Check if jasmine is in dependencies or devDependencies
        if grep -q '"jasmine"' package.json 2>/dev/null; then
            echo "jasmine"
            return 0
        fi
    fi
    # Default to jest if no clear detection (most common)
    echo "jest"
}

# Utility: detect .NET test projects/files
_dotnet_csproj_is_test() {
    local file="$1"
    if grep -qi "<IsTestProject>\s*true\s*</IsTestProject>" "$file" 2>/dev/null; then
        return 0
    fi
    case "$(basename "$file")" in
    *Test*.csproj) return 0 ;;
    esac
    return 1
}

dotnet_tests_present() {
    # Look for test csproj or common test directories
    if find . -maxdepth 5 -type f -name "*.csproj" | while read -r f; do _dotnet_csproj_is_test "$f" && echo yes && break; done | grep -q yes; then
        return 0
    fi
    find . \
        \( -path "*/bin/*" -o -path "*/obj/*" -o -path "*/.git/*" -o -path "*/node_modules/*" \) -prune -o \
        \( -path "*/tests/*" -o -path "*/test/*" \) -type f -name "*Test*.cs" -print -quit | grep -q .
}

# Utility: detect Java test files
java_tests_present() {
    if find . -path "*/src/test/java/*" -type f -name "*.java" -print -quit | grep -q .; then
        return 0
    fi
    find . \
        \( -path "*/.git/*" -o -path "*/build/*" -o -path "*/target/*" -o -path "*/node_modules/*" \) -prune -o \
        -type f \( -name "*Test.java" -o -name "*Tests.java" \) -print -quit | grep -q .
}

# Utility: detect if any tests are present across supported tech
any_tests_present() {
    if python_tests_present; then return 0; fi
    if js_tests_present; then return 0; fi
    if dotnet_tests_present; then return 0; fi
    if java_tests_present; then return 0; fi
    return 1
}

mypy_check() {
    if ! python_source_files_present; then
        debug "No Python source files detected; skipping mypy"
        return 0
    fi
    local config_args=""
    # Check for local mypy config files
    if [[ -f "mypy.ini" || -f ".mypy.ini" || -f "pyproject.toml" || -f "setup.cfg" ]]; then
        debug "Using local mypy config"
    else
        debug "No local mypy config found, using embedded config"
        config_args="--config-file $QUALITY_DIR/configs/python/mypy.ini"
    fi
    if command -v mypy >/dev/null 2>&1; then
        run_tool "mypy" mypy "$config_args" .
    else
        run_tool "mypy" .venv/bin/mypy "$config_args" .
    fi
}

detect_python_test_framework() {
    # Check if pytest is configured or available
    if command -v pytest >/dev/null 2>&1 || [[ -f ".venv/bin/pytest" ]]; then
        # Check for pytest configuration files
        if [[ -f "pytest.ini" || -f "pyproject.toml" || -f "tox.ini" || -f "setup.cfg" ]]; then
            if [[ -f "pyproject.toml" ]] && grep -q "\[tool:pytest\]" pyproject.toml 2>/dev/null; then
                echo "pytest"
                return 0
            fi
            if [[ -f "setup.cfg" ]] && grep -q "\[tool:pytest\]" setup.cfg 2>/dev/null; then
                echo "pytest"
                return 0
            fi
            if [[ -f "pytest.ini" || -f "tox.ini" ]]; then
                echo "pytest"
                return 0
            fi
        fi
        # If pytest is available but no config, still prefer it for its features
        echo "pytest"
        return 0
    fi

    # Fallback to unittest if test files exist
    if python_tests_present; then
        echo "unittest"
        return 0
    fi

    echo "none"
}

pytest_unit() {
    if ! python_tests_present; then
        debug "No Python tests detected; skipping pytest"
        return 0
    fi

    # Check if pytest-xdist is available for parallel execution
    local pytest_cmd=""
    local pytest_args=""

    if command -v pytest >/dev/null 2>&1; then
        pytest_cmd="pytest"
    else
        pytest_cmd=".venv/bin/pytest"
    fi

    # Try to import pytest_xdist to check if parallel execution is available
    if python3 -c "import pytest_xdist" 2>/dev/null; then
        pytest_args="-n auto"
    fi

    # Add timeout to prevent hanging tests (300 seconds = 5 minutes)
    if command -v gtimeout >/dev/null 2>&1; then
        run_tool "pytest" gtimeout 300 "$pytest_cmd" "$pytest_args"
    else
        run_tool "pytest" "$pytest_cmd" "$pytest_args"
    fi
}

unittest_unit() {
    if ! python_tests_present; then
        debug "No Python tests detected; skipping unittest"
        return 0
    fi
    # Use python3 if available, otherwise python
    if command -v python3 >/dev/null 2>&1; then
        run_tool "unittest" python3 -m unittest discover -v
    else
        run_tool "unittest" python -m unittest discover -v
    fi
}

pytest_coverage() {
    if ! python_tests_present; then
        debug "No Python tests detected; skipping pytest coverage"
        return 0
    fi
    local cov_config=""
    if [[ -f ".coveragerc" ]]; then
        debug "Using local .coveragerc"
    else
        debug "No local .coveragerc found, using embedded config: $QUALITY_DIR/configs/python/.coveragerc"
        cov_config="--cov-config $QUALITY_DIR/configs/python/.coveragerc"
    fi
    if command -v pytest >/dev/null 2>&1; then
        if command -v gtimeout >/dev/null 2>&1; then
            # shellcheck disable=SC2086
            gtimeout 300 pytest --rootdir . --cov=. --cov-report=term-missing --disable-warnings $cov_config
            local pytest_exit=$?
            debug "pytest exit code: $pytest_exit"
            return $pytest_exit
        else
            # shellcheck disable=SC2086
            pytest --rootdir . --cov=. --cov-report=term-missing --disable-warnings $cov_config
            local pytest_exit=$?
            debug "pytest exit code: $pytest_exit"
            return $pytest_exit
        fi
    else
        if command -v gtimeout >/dev/null 2>&1; then
            # shellcheck disable=SC2086
            gtimeout 300 .venv/bin/pytest --rootdir . --cov=. --cov-report=term-missing --disable-warnings $cov_config
            local pytest_exit=$?
            debug "pytest exit code: $pytest_exit"
            return $pytest_exit
        else
            # shellcheck disable=SC2086
            .venv/bin/pytest --rootdir . --cov=. --cov-report=term-missing --disable-warnings $cov_config
            local pytest_exit=$?
            debug "pytest exit code: $pytest_exit"
            return $pytest_exit
        fi
    fi
}

unittest_coverage() {
    if ! python_tests_present; then
        debug "No Python tests detected; skipping unittest coverage"
        return 0
    fi
    # Use coverage.py with unittest if available
    if command -v coverage >/dev/null 2>&1; then
        run_tool "coverage" coverage run --source=. -m unittest discover
        run_tool "coverage" coverage report
    elif [[ -f ".venv/bin/coverage" ]]; then
        run_tool "coverage" .venv/bin/coverage run --source=. -m unittest discover
        run_tool "coverage" .venv/bin/coverage report
    else
        debug "coverage.py not available; running unittest without coverage"
        unittest_unit
    fi
}

radon_sloc() {
    local radon_output
    local files
    local exclude_args
    exclude_args=$(_build_exclude_args)
    files=$(eval "find . \
        -type f -name \"*.py\" \
        -not -path \"*/.venv/*\" \
        -not -path \"*/node_modules/*\" \
        -not -path \"*/.git/*\" \
        -not -path \"*/__pycache__/*\" \
        -not -path \"*/.pytest_cache/*\" \
        -not -path \"*/.mypy_cache/*\" \
        $exclude_args -print0")
    if [[ -z "$files" ]]; then
        return 0
    fi
    if command -v radon >/dev/null 2>&1; then
        radon_output=$(printf "%s" "$files" | xargs -0 radon raw)
    else
        radon_output=$(printf "%s" "$files" | xargs -0 .venv/bin/radon raw)
    fi

    if [[ $VERBOSE -eq 1 ]]; then
        echo "$radon_output"
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
    else
        echo "$radon_output" | awk '
            BEGIN { current_file = ""; overall_exit_code = 0; }
            /^[a-zA-Z0-9_\-\/\.]+\.py$/ { current_file = $0; }
            /^[[:space:]]*SLOC:/ {
                if (current_file != "") {
                    sloc_val = $2;
                    if (sloc_val >= 350) {
                        overall_exit_code = 1;
                    }
                    current_file = "";
                }
            }
            END { exit overall_exit_code; }
        ' >/dev/null
    fi
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
        if [[ $VERBOSE -eq 1 ]]; then
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
        if [[ $VERBOSE -eq 1 ]]; then
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
    if any(part in str(f) for part in ['.venv', '__pycache__', '.git', 'node_modules', '.pytest_cache', '.mypy_cache']) or 'test' in str(f) or 'tests' in str(f):
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
    if any(part in str(f) for part in ['.venv', '__pycache__', '.git', 'node_modules', '.pytest_cache', '.mypy_cache']) or 'test' in str(f) or 'tests' in str(f):
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
    # Only run biome if relevant files exist (excluding generated/cache files)
    if ! find . -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.html" -o -name "*.css" -o -name "*.graphql" -o -name "*.gql" \) \
        -not -path "./node_modules/*" \
        -not -path "./.git/*" \
        -not -path "./.mypy_cache/*" \
        -not -path "./__pycache__/*" \
        -not -path "./.pytest_cache/*" \
        -not -path "./.ruff_cache/*" \
        -not -path "./dist/*" \
        -not -path "./build/*" \
        -not -path "./target/*" \
        -not -path "./.next/*" \
        -not -path "./.nuxt/*" \
        -not -path "./.vuepress/*" \
        -not -path "./.cache/*" \
        -not -path "./.parcel-cache/*" \
        -not -path "./.nyc_output/*" \
        -not -path "./coverage/*" |
        head -1 | grep -q .; then
        debug "No JS/TS/JSON/HTML/CSS/GraphQL files found; skipping biome"
        return 0
    fi
    if command -v bunx >/dev/null 2>&1; then
        run_tool "biome" bunx @biomejs/biome check --linter-enabled=true --formatter-enabled=false --reporter=summary .
    else
        run_tool "biome" npx @biomejs/biome check --linter-enabled=true --formatter-enabled=false --reporter=summary .
    fi
}

biome_format() {
    # Only run biome format if relevant files exist
    if ! find . -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.html" -o -name "*.css" -o -name "*.graphql" -o -name "*.gql" \) -not -path "./node_modules/*" -not -path "./.git/*" -not -path "./.mypy_cache/*" -not -path "./__pycache__/*" | head -1 | grep -q .; then
        debug "No JS/TS/JSON/HTML/CSS/GraphQL files found; skipping biome format"
        return 0
    fi
    local files
    files=$(_changed_files_by_ext '\.(js|jsx|ts|tsx|json|html|css|graphql|gql)$') || files=""
    if [[ -n "$files" ]]; then
        if command -v bunx >/dev/null 2>&1; then
            run_tool "biome" bunx @biomejs/biome check --formatter-enabled=true --linter-enabled=false "$files"
        else
            run_tool "biome" npx @biomejs/biome check --formatter-enabled=true --linter-enabled=false "$files"
        fi
    else
        # Full check if not in diff-only mode
        if command -v bunx >/dev/null 2>&1; then
            run_tool "biome" bunx @biomejs/biome check --formatter-enabled=true --linter-enabled=false .
        else
            run_tool "biome" npx @biomejs/biome check --formatter-enabled=true --linter-enabled=false .
        fi
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

js_test_unit() {
    # Skip if no JS/TS tests present
    if ! js_tests_present; then
        debug "No JS/TS tests detected; skipping JS tests"
        return 0
    fi

    local runner
    runner=$(detect_js_test_runner)

    if [[ "$runner" == "vitest" ]]; then
        debug "Running vitest unit tests..."
        if [[ -x "./node_modules/.bin/vitest" ]]; then
            run_tool "vitest" ./node_modules/.bin/vitest run --reporter=verbose
        elif command -v bunx >/dev/null 2>&1; then
            run_tool "vitest" bunx vitest run --reporter=verbose
        else
            run_tool "vitest" npx vitest run --reporter=verbose
        fi
    elif [[ "$runner" == "jest" ]]; then
        debug "Running jest unit tests..."
        if [[ -x "./node_modules/.bin/jest" ]]; then
            run_tool "jest" ./node_modules/.bin/jest --maxWorkers=50%
        elif command -v bunx >/dev/null 2>&1; then
            run_tool "jest" bunx jest --maxWorkers=50%
        else
            run_tool "jest" npx jest --maxWorkers=50%
        fi
    elif [[ "$runner" == "mocha" ]]; then
        debug "Running mocha unit tests..."
        if [[ -x "./node_modules/.bin/mocha" ]]; then
            run_tool "mocha" ./node_modules/.bin/mocha --parallel
        elif command -v bunx >/dev/null 2>&1; then
            run_tool "mocha" bunx mocha --parallel
        else
            run_tool "mocha" npx mocha --parallel
        fi
    elif [[ "$runner" == "jasmine" ]]; then
        debug "Running jasmine unit tests..."
        if [[ -x "./node_modules/.bin/jasmine" ]]; then
            run_tool "jasmine" ./node_modules/.bin/jasmine
        elif command -v bunx >/dev/null 2>&1; then
            run_tool "jasmine" bunx jasmine
        else
            run_tool "jasmine" npx jasmine
        fi
    else
        debug "Unknown test runner: $runner; skipping JS tests"
        return 0
    fi
}

js_test_coverage() {
    # Skip if no JS/TS tests present
    if ! js_tests_present; then
        debug "No JS/TS tests detected; skipping JS test coverage"
        return 0
    fi

    local runner
    runner=$(detect_js_test_runner)

    if [[ "$runner" == "vitest" ]]; then
        debug "Running vitest coverage..."
        if command -v bunx >/dev/null 2>&1; then
            run_tool "vitest" bunx vitest run --coverage
        else
            run_tool "vitest" npx vitest run --coverage
        fi
    elif [[ "$runner" == "jest" ]]; then
        debug "Running jest coverage..."
        if command -v bunx >/dev/null 2>&1; then
            run_tool "jest" bunx jest --coverage
        else
            run_tool "jest" npx jest --coverage
        fi
    elif [[ "$runner" == "mocha" ]]; then
        debug "Mocha coverage not yet supported; skipping"
        return 0
    elif [[ "$runner" == "jasmine" ]]; then
        debug "Jasmine coverage not yet supported; skipping"
        return 0
    else
        debug "Unknown test runner: $runner; skipping JS test coverage"
        return 0
    fi
}

shellcheck_check() {
    local shell_files
    shell_files=$(find . \( -path "*/.venv" -o -path "*/node_modules" -o -path "*/__pycache__" \) -prune -o -name "*.sh" -type f -print)

    if [[ -z "$shell_files" ]]; then
        return 0
    fi

    local shellcheck_config="$QUALITY_DIR/configs/shell/.shellcheckrc"
    local shellcheck_args=()

    # Check if shellcheck supports --rcfile option
    if [[ -f "$shellcheck_config" ]] && shellcheck --help 2>/dev/null | grep -q -- "--rcfile"; then
        shellcheck_args+=("--rcfile=$shellcheck_config")
    elif [[ -f "$shellcheck_config" ]]; then
        # For older versions, use exclude option directly
        shellcheck_args+=("--exclude=SC1091")
    fi

    if [[ $VERBOSE -eq 1 ]]; then
        if [[ ${#shellcheck_args[@]} -eq 0 ]]; then
            echo "$shell_files" | xargs shellcheck
        else
            echo "$shell_files" | xargs shellcheck "${shellcheck_args[@]}"
        fi
    else
        # Non-verbose: suppress shellcheck output; return only exit status
        if [[ ${#shellcheck_args[@]} -eq 0 ]]; then
            echo "$shell_files" | xargs shellcheck >/dev/null 2>&1
        else
            echo "$shell_files" | xargs shellcheck "${shellcheck_args[@]}" >/dev/null 2>&1
        fi
        return $?
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

# --------------------
# .NET helpers
# --------------------

# --------------------
# Lizard integration (multi-language, internal only)
# --------------------
# Uses uvx to avoid global installs, parses JSON to enforce thresholds.
# Supported languages mapped from detect_tech():
#  - dotnet -> csharp
#  - java   -> java
#  - js/ts  -> javascript, typescript
#  - go     -> go
#  - python -> python (we still prefer radon for Python, so default off unless explicitly asked)

LIZARD_EXCLUDES=(
    "*/.git/*"
    "*/node_modules/*"
    "*/.venv/*"
    "*/dist/*"
    "*/build/*"
    "*/target/*"
    "*/bin/*"
    "*/obj/*"
    "*/__pycache__/*"
)

# Thresholds (can later move to configs)
# Stage 5: SLOC (approx via file NLOC aggregate)
LIZARD_SLOC_LIMIT=${LIZARD_SLOC_LIMIT:-350}
# Stage 6: Complexity
LIZARD_CCN_LIMIT=${LIZARD_CCN_LIMIT:-12}
# Stage 7: Stricter maintainability proxy
LIZARD_CCN_STRICT=${LIZARD_CCN_STRICT:-10}
LIZARD_FN_NLOC_LIMIT=${LIZARD_FN_NLOC_LIMIT:-200}
LIZARD_PARAM_LIMIT=${LIZARD_PARAM_LIMIT:-6}

_lizard_uvx() {
    if command -v uvx >/dev/null 2>&1; then
        uvx lizard "$@"
    else
        echo "Lizard requires uv to run (uvx not found). Please install uv from https://astral.sh/uv" >&2
        return 127
    fi
}

# Build -l flags from a TECHS string
_lizard_lang_flags() {
    local techs="$1"
    local flags=()
    if [[ "$techs" == *"dotnet"* ]]; then
        flags+=("-l" "csharp")
    fi
    if [[ "$techs" == *"java"* ]]; then
        flags+=("-l" "java")
    fi
    if [[ "$techs" == *"kotlin"* ]]; then
        flags+=("-l" "kotlin")
    fi
    if [[ "$techs" == *"js"* || "$techs" == *"react"* ]]; then
        flags+=("-l" "javascript")
    fi
    if [[ "$techs" == *"ts"* || "$techs" == *"react"* ]]; then
        flags+=("-l" "typescript")
    fi
    if [[ "$techs" == *"go"* ]]; then
        flags+=("-l" "go")
    fi
    echo "${flags[@]}"
}

# Common runner to emit CSV for selected languages; stdout = CSV
_lizard_run_csv() {
    local techs="$1"
    shift
    local lang_flags
    lang_flags=$(_lizard_lang_flags "$techs")
    # If no supported langs in techs, no-op
    if [[ -z "$lang_flags" ]]; then
        return 0
    fi

    local args=("--csv")
    # Excludes
    for ex in "${LIZARD_EXCLUDES[@]}"; do
        args+=("-x" "$ex")
    done
    # language flags
    # shellcheck disable=SC2206
    args+=($lang_flags)

    # Diff-only: pass changed files instead of '.' when available
    if [[ "${AIQ_CHANGED_ONLY:-}" == "1" ]] && [[ -n "${AIQ_CHANGED_FILELIST:-}" ]] && [[ -f "${AIQ_CHANGED_FILELIST}" ]]; then
        while IFS= read -r f; do
            # include only matching source files for selected languages; let lizard ignore others
            args+=("$f")
        done <"${AIQ_CHANGED_FILELIST}"
    else
        args+=(".")
    fi

    debug "Running Lizard with args: ${args[*]}"
    _lizard_uvx "${args[@]}"
}

# Stage 5: SLOC check via aggregated file NLOC
lizard_sloc_multi() {
    local techs
    if [[ -n "${LIZARD_FORCE_TECHS:-}" ]]; then
        techs="$LIZARD_FORCE_TECHS"
    else
        techs=$(detect_tech)
    fi
    local csv
    if ! csv=$(_lizard_run_csv "$techs"); then
        return 1
    fi
    if [[ -z "$csv" ]]; then
        return 0
    fi
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$csv" | python3 -c '
import csv, sys
sloc_limit = int(sys.argv[1])
reader = csv.reader(sys.stdin)
file_sloc = {}
violations = []
for row in reader:
    if len(row) < 7:
        continue
    try:
        nloc = int(row[0])
        filename = row[6]
        file_sloc[filename] = file_sloc.get(filename, 0) + nloc
    except (ValueError, IndexError):
        continue

for filename, total_sloc in file_sloc.items():
    if total_sloc >= sloc_limit:
        violations.append((filename, total_sloc))

for filename, sloc in violations:
    print(f"{filename}: {sloc} lines >= {sloc_limit}")
if violations:
    sys.exit(1)
' "$LIZARD_SLOC_LIMIT"
    else
        echo "$csv" | python3 -c '
import csv, sys
sloc_limit = int(sys.argv[1])
reader = csv.reader(sys.stdin)
file_sloc = {}
for row in reader:
    if len(row) < 7:
        continue
    try:
        nloc = int(row[0])
        filename = row[6]
        file_sloc[filename] = file_sloc.get(filename, 0) + nloc
    except (ValueError, IndexError):
        continue

for filename, total_sloc in file_sloc.items():
    if total_sloc >= sloc_limit:
        sys.exit(1)
' "$LIZARD_SLOC_LIMIT" >/dev/null
    fi
}

# Stage 6: Cyclomatic complexity per function
lizard_complexity_multi() {
    local techs
    if [[ -n "${LIZARD_FORCE_TECHS:-}" ]]; then
        techs="$LIZARD_FORCE_TECHS"
    else
        techs=$(detect_tech)
    fi
    local csv
    if ! csv=$(_lizard_run_csv "$techs"); then
        return 1
    fi
    if [[ -z "$csv" ]]; then
        return 0
    fi
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$csv" | python3 -c '
import csv, sys
ccn_limit = int(sys.argv[1])
reader = csv.reader(sys.stdin)
violations = []
for row in reader:
    if len(row) < 11:
        continue
    try:
        ccn = int(row[1])
        filename = row[6]
        function_name = row[7]
        start_line = int(row[9])
        if ccn > ccn_limit:
            violations.append((filename, start_line, function_name, ccn))
    except (ValueError, IndexError):
        continue

for filename, start_line, function_name, ccn in violations:
    print(f"{filename}:{start_line} {function_name} CCN={ccn} > {ccn_limit}")
if violations:
    sys.exit(1)
' "$LIZARD_CCN_LIMIT"
    else
        echo "$csv" | python3 -c '
import csv, sys
ccn_limit = int(sys.argv[1])
reader = csv.reader(sys.stdin)
for row in reader:
    if len(row) < 11:
        continue
    try:
        ccn = int(row[1])
        if ccn > ccn_limit:
            sys.exit(1)
    except (ValueError, IndexError):
        continue
' "$LIZARD_CCN_LIMIT" >/dev/null
    fi
}

# Stage 7: Maintainability proxy (stricter CCN + function NLOC + parameters)
lizard_maintainability_multi() {
    local techs
    if [[ -n "${LIZARD_FORCE_TECHS:-}" ]]; then
        techs="$LIZARD_FORCE_TECHS"
    else
        techs=$(detect_tech)
    fi
    local csv
    if ! csv=$(_lizard_run_csv "$techs"); then
        return 1
    fi
    if [[ -z "$csv" ]]; then
        return 0
    fi
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$csv" | python3 -c '
import csv, sys
ccn_limit = int(sys.argv[1])
fn_nloc_limit = int(sys.argv[2])
param_limit = int(sys.argv[3])
reader = csv.reader(sys.stdin)
violations = []
for row in reader:
    if len(row) < 11:
        continue
    try:
        ccn = int(row[1])
        nloc = int(row[0])
        params = int(row[3])
        filename = row[6]
        function_name = row[7]
        start_line = int(row[9])
        if ccn > ccn_limit or nloc > fn_nloc_limit or params > param_limit:
            violations.append((filename, start_line, function_name, ccn, nloc, params))
    except (ValueError, IndexError):
        continue

for filename, start_line, function_name, ccn, nloc, params in violations:
    print(f"{filename}:{start_line} {function_name} CCN={ccn}, NLOC={nloc}, Params={params}")
if violations:
    sys.exit(1)
' "$LIZARD_CCN_STRICT" "$LIZARD_FN_NLOC_LIMIT" "$LIZARD_PARAM_LIMIT"
    else
        echo "$csv" | python3 -c '
import csv, sys
ccn_limit = int(sys.argv[1])
fn_nloc_limit = int(sys.argv[2])
param_limit = int(sys.argv[3])
reader = csv.reader(sys.stdin)
for row in reader:
    if len(row) < 11:
        continue
    try:
        ccn = int(row[1])
        nloc = int(row[0])
        params = int(row[3])
        if ccn > ccn_limit or nloc > fn_nloc_limit or params > param_limit:
            sys.exit(1)
    except (ValueError, IndexError):
        continue
' "$LIZARD_CCN_STRICT" "$LIZARD_FN_NLOC_LIMIT" "$LIZARD_PARAM_LIMIT" >/dev/null
    fi
}

find_dotnet_project_dir() {
    # Find the directory containing a .csproj or .sln file
    local proj_dir
    proj_dir=$(find . -maxdepth 3 -type f \( -name "*.csproj" -o -name "*.sln" \) | head -1 | xargs dirname 2>/dev/null || true)
    if [[ -n "$proj_dir" && -d "$proj_dir" ]]; then
        echo "$proj_dir"
    else
        echo "."
    fi
}

dotnet_format_check() {
    if command -v dotnet >/dev/null 2>&1; then
        local proj_dir
        proj_dir=$(find_dotnet_project_dir)
        run_tool "dotnet-format" dotnet format "$proj_dir" --verify-no-changes
    else
        debug "dotnet not found; skipping dotnet format"
    fi
}

dotnet_lint_check() {
    if command -v dotnet >/dev/null 2>&1; then
        # Use dotnet format to catch both formatting and style issues
        local proj_dir
        proj_dir=$(find_dotnet_project_dir)
        run_tool "dotnet-lint" dotnet format "$proj_dir" --verify-no-changes --severity warn
    else
        debug "dotnet not found; skipping dotnet lint"
    fi
}

dotnet_build_check() {
    if command -v dotnet >/dev/null 2>&1; then
        local proj_dir
        proj_dir=$(find_dotnet_project_dir)
        run_tool "dotnet-build" dotnet build -warnaserror "$proj_dir"
    else
        debug "dotnet not found; skipping dotnet build"
    fi
}

dotnet_test() {
    if command -v dotnet >/dev/null 2>&1; then
        local proj_dir
        proj_dir=$(find_dotnet_project_dir)
        run_tool "dotnet-test" dotnet test --nologo "$proj_dir"
    else
        debug "dotnet not found; skipping dotnet test"
    fi
}

dotnet_coverage() {
    if command -v dotnet >/dev/null 2>&1; then
        local proj_dir
        proj_dir=$(find_dotnet_project_dir)
        # Attempt coverlet via data collector if configured
        if dotnet test "$proj_dir" -l "console;verbosity=minimal" -p:CollectCoverage=true -p:CoverletOutputFormat=cobertura >/dev/null 2>&1; then
            run_tool "dotnet-coverage" dotnet test "$proj_dir" -p:CollectCoverage=true -p:CoverletOutputFormat=cobertura
        else
            debug "Coverlet not configured; running dotnet test without coverage"
            run_tool "dotnet-test" dotnet test --nologo "$proj_dir"
        fi
    else
        debug "dotnet not found; skipping dotnet coverage"
    fi
}

# --------------------
# Java helpers
# --------------------

java_has_maven() { command -v mvn >/dev/null 2>&1; }
java_has_gradle() { command -v gradle >/dev/null 2>&1 || command -v ./gradlew >/dev/null 2>&1; }
java_gradle_cmd() { if command -v ./gradlew >/dev/null 2>&1; then echo "./gradlew"; else echo "gradle"; fi; }

java_checkstyle() {
    # Prefer project-configured plugins; fallback to CLI if checkstyle exists
    if [[ -f "pom.xml" ]] && java_has_maven; then
        run_tool "maven-checkstyle" mvn -q -DskipTests=true checkstyle:check || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && java_has_gradle; then
        run_tool "gradle-checkstyle" "$(java_gradle_cmd)" -q check || return 1
    elif command -v checkstyle >/dev/null 2>&1; then
        # Fallback: run checkstyle on each tracked Java file
        local files
        files=$(git ls-files "**/*.java" 2>/dev/null || true)
        if [[ -z "$files" ]]; then
            debug "No Java files found for checkstyle"
            return 0
        fi
        local f
        for f in $files; do
            run_tool "checkstyle" checkstyle -c /google_checks.xml "$f" || return 1
        done
    else
        debug "No Java linter configured; skipping checkstyle"
    fi
}

java_format_check() {
    # Prefer Spotless if configured in project
    if [[ -f "pom.xml" ]] && java_has_maven; then
        if grep -qi "spotless" pom.xml 2>/dev/null; then
            run_tool "maven-spotless" mvn -q -DskipTests=true spotless:check && return 0
        fi
    fi
    if { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && java_has_gradle; then
        if grep -qi "spotless" build.gradle* 2>/dev/null; then
            run_tool "gradle-spotless" "$(java_gradle_cmd)" -q spotlessCheck && return 0
        fi
    fi
    # Fallback to google-java-format if available
    if command -v google-java-format >/dev/null 2>&1; then
        local files
        files=$(git ls-files "**/*.java" 2>/dev/null || true)
        if [[ -z "$files" ]]; then
            debug "No Java files found for formatting"
            return 0
        fi
        local f
        for f in $files; do
            run_tool "google-java-format" google-java-format --dry-run "$f" || return 1
        done
    else
        debug "No Java formatter configured (Spotless/Google) — skipping format check"
    fi
}

java_build_check() {
    if [[ -f "pom.xml" ]] && java_has_maven; then
        run_tool "maven-verify" mvn -q -DskipTests=true -Dmaven.test.skip=true -DfailOnError=true -e -B -V verify
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && java_has_gradle; then
        run_tool "gradle-build" "$(java_gradle_cmd)" -q build -x test
    else
        debug "No Java build tool detected; skipping type/build check"
    fi
}

java_test() {
    if [[ -f "pom.xml" ]] && java_has_maven; then
        run_tool "maven-test" mvn -q -e -B test
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && java_has_gradle; then
        run_tool "gradle-test" "$(java_gradle_cmd)" -q test
    else
        debug "No Java test tool detected; skipping tests"
    fi
}

java_coverage() {
    # Assume JaCoCo configured in project; run verify/build to produce coverage
    if [[ -f "pom.xml" ]] && java_has_maven; then
        run_tool "maven-verify" mvn -q -e -B verify || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && java_has_gradle; then
        run_tool "gradle-jacoco" "$(java_gradle_cmd)" -q test jacocoTestReport || return 1
    else
        debug "No Java coverage configuration detected; skipping"
    fi
}

# --------------------
# Kotlin helpers
# --------------------

kotlin_format_check() {
    # Prefer ktlint if available
    if command -v ktlint >/dev/null 2>&1; then
        run_tool "ktlint" ktlint --format --log-level=error "**/*.kt" || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v ./gradlew >/dev/null 2>&1; then
        run_tool "gradle-spotless" ./gradlew -q spotlessCheck || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v gradle >/dev/null 2>&1; then
        run_tool "gradle-spotless" gradle -q spotlessCheck || return 1
    else
        debug "No Kotlin formatter configured (ktlint/Spotless) — skipping format check"
    fi
}

kotlin_lint_check() {
    # Prefer ktlint if available
    if command -v ktlint >/dev/null 2>&1; then
        run_tool "ktlint" ktlint --log-level=error "**/*.kt" || return 1
    elif command -v detekt >/dev/null 2>&1; then
        run_tool "detekt" detekt --config detekt-config.yml 2>/dev/null || detekt || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v ./gradlew >/dev/null 2>&1; then
        run_tool "gradle-detekt" ./gradlew -q detekt || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v gradle >/dev/null 2>&1; then
        run_tool "gradle-detekt" gradle -q detekt || return 1
    else
        debug "No Kotlin linter configured (ktlint/detekt) — skipping lint check"
    fi
}

kotlin_build_check() {
    if { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v ./gradlew >/dev/null 2>&1; then
        run_tool "gradle-build" ./gradlew -q compileKotlin compileTestKotlin || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v gradle >/dev/null 2>&1; then
        run_tool "gradle-build" gradle -q compileKotlin compileTestKotlin || return 1
    else
        debug "No Kotlin build tool detected; skipping type/build check"
    fi
}

kotlin_test() {
    if { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v ./gradlew >/dev/null 2>&1; then
        run_tool "gradle-test" ./gradlew -q test || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v gradle >/dev/null 2>&1; then
        run_tool "gradle-test" gradle -q test || return 1
    else
        debug "No Kotlin test tool detected; skipping tests"
    fi
}

kotlin_coverage() {
    # Assume JaCoCo/Kover configured in project
    if { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v ./gradlew >/dev/null 2>&1; then
        run_tool "gradle-coverage" ./gradlew -q test jacocoTestReport || return 1
    elif { [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; } && command -v gradle >/dev/null 2>&1; then
        run_tool "gradle-coverage" gradle -q test jacocoTestReport || return 1
    else
        debug "No Kotlin coverage configuration detected; skipping"
    fi
}

# --------------------
# Security helpers
# --------------------

security_gitleaks() {
    if command -v gitleaks >/dev/null 2>&1; then
        # Avoid overly verbose output by default; use --verbose only when VERBOSE=1
        if [[ $VERBOSE -eq 1 ]]; then
            run_tool "gitleaks" gitleaks detect --no-color --no-banner --redact --verbose
        else
            run_tool "gitleaks" gitleaks detect --no-color --no-banner --redact
        fi
    else
        debug "gitleaks not found; skipping secrets scan"
    fi
}

security_semgrep() {
    if command -v semgrep >/dev/null 2>&1; then
        # Use the default auto rules; users can add a .semgrep.yml to customize
        run_tool "semgrep" semgrep scan --error --severity "${AIQ_SEMGREP_SEVERITY:-ERROR}" || return 1
    else
        debug "semgrep not found; skipping SAST scan"
    fi
}

# --------------------
# HCL / Terraform helpers
# --------------------

hcl_format_check() {
    # Prefer terraform fmt for .tf; fallback to hclfmt for generic .hcl if available
    if command -v terraform >/dev/null 2>&1; then
        # -check ensures non-zero exit if formatting needed; -recursive processes subdirs
        run_tool "terraform-fmt" terraform fmt -check -recursive || return 1
    elif command -v hclfmt >/dev/null 2>&1; then
        # hclfmt formats but may not support a check mode; emulate by diff
        local tmpdir
        tmpdir=$(mktemp -d)
        local changed=0
        while IFS= read -r -d '' f; do
            cp "$f" "$tmpdir/$(basename "$f")"
            hclfmt -w "$tmpdir/$(basename "$f")"
            if ! diff -q "$f" "$tmpdir/$(basename "$f")" >/dev/null; then
                changed=1
                break
            fi
        done < <(find . -type f \( -name "*.hcl" -o -name "*.tf" \) -print0)
        rm -rf "$tmpdir"
        if [[ $changed -eq 1 ]]; then
            return 1
        fi
    else
        debug "terraform/hclfmt not found; skipping HCL format check"
    fi
}

hcl_lint_check() {
    # Terraform lint via tflint if available
    if command -v tflint >/dev/null 2>&1; then
        run_tool "tflint" tflint --no-color || return 1
    else
        debug "tflint not found; skipping Terraform lint"
    fi
}

hcl_security_check() {
    # Terraform security via tfsec if available (complements semgrep)
    if command -v tfsec >/dev/null 2>&1; then
        run_tool "tfsec" tfsec --no-color --soft-fail=false || return 1
    else
        debug "tfsec not found; skipping Terraform security scan"
    fi
}
