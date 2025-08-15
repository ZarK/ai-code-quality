#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERBOSE=0
QUIET=0
DRY_RUN=0

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
    local files
    files=$(find . \
        -type f -name "*.py" \
        -not -path "*/.venv/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/.pytest_cache/*" \
        -not -path "*/.mypy_cache/*" -print0)
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
        local shellcheck_output
        if [[ ${#shellcheck_args[@]} -eq 0 ]]; then
            shellcheck_output=$(echo "$shell_files" | xargs shellcheck 2>&1)
        else
            shellcheck_output=$(echo "$shell_files" | xargs shellcheck "${shellcheck_args[@]}" 2>&1)
        fi
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

# Common runner to emit JSON for selected languages; stdout = JSON
_lizard_run_json() {
    local techs="$1"
    shift
    lang_flags=$(_lizard_lang_flags "$techs")
    # If no supported langs in techs, no-op
    if [[ -z "$lang_flags" ]]; then
        return 0
    fi

    local args=("-j")
    # Excludes
    for ex in "${LIZARD_EXCLUDES[@]}"; do
        args+=("-x" "$ex")
    done
    # language flags
    # shellcheck disable=SC2206
    args+=($lang_flags)
    args+=(".")

    debug "Running Lizard JSON with args: ${args[*]}"
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
    local json
    if ! json=$(_lizard_run_json "$techs"); then
        return 1
    fi
    if [[ -z "$json" ]]; then
        # Nothing to check
        return 0
    fi

    if [[ $VERBOSE -eq 1 ]]; then
        echo "$json" | python3 -c '
import json, sys, collections
limit = int(sys.argv[1])
data = json.load(sys.stdin)
by_file = collections.defaultdict(int)
for item in data:
    fn = item.get("filename") or item.get("path")
    nloc = item.get("nloc") or 0
    if fn:
        by_file[fn] += int(nloc)
failed = []
for fn, total in sorted(by_file.items()):
    print(f"{fn}: total NLOC ~ {total}")
    if total >= limit:
        failed.append((fn, total))
if failed:
    print("\nFiles exceeding SLOC limit:", file=sys.stderr)
    for fn, total in failed:
        print(f"{fn}: {total} >= {limit}", file=sys.stderr)
    sys.exit(1)
' "$LIZARD_SLOC_LIMIT"
    else
        echo "$json" | python3 -c '
import json, sys, collections
limit = int(sys.argv[1])
data = json.load(sys.stdin)
by_file = collections.defaultdict(int)
for item in data:
    fn = item.get("filename") or item.get("path")
    nloc = item.get("nloc") or 0
    if fn:
        by_file[fn] += int(nloc)
failed = [(fn, n) for fn, n in by_file.items() if n >= limit]
if failed:
    for fn, total in failed:
        print(f"{fn}: {total} >= {limit}", file=sys.stderr)
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
    local json
    if ! json=$(_lizard_run_json "$techs"); then
        return 1
    fi
    if [[ -z "$json" ]]; then
        return 0
    fi
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$json" | python3 -c '
import json, sys
ccn_limit = int(sys.argv[1])
data = json.load(sys.stdin)
viol = []
for i in data:
    ccn = i.get("cyclomatic_complexity") or i.get("ccn")
    if ccn is None:
        continue
    try:
        ccn = int(ccn)
    except Exception:
        continue
    if ccn > ccn_limit:
        viol.append(i)
for v in viol:
    print(f"{v.get(\"filename\")}:{v.get(\"start_line\")} {v.get(\"name\")} CCN={v.get(\"cyclomatic_complexity\") or v.get(\"ccn\")} \u003e {ccn_limit}")
if viol:
    sys.exit(1)
' "$LIZARD_CCN_LIMIT"
    else
        echo "$json" | python3 -c '
import json, sys
ccn_limit = int(sys.argv[1])
data = json.load(sys.stdin)
for i in data:
    ccn = i.get("cyclomatic_complexity") or i.get("ccn")
    if ccn is None:
        continue
    try:
        ccn = int(ccn)
    except Exception:
        continue
    if ccn > ccn_limit:
        sys.exit(1)
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
    local json
    if ! json=$(_lizard_run_json "$techs"); then
        return 1
    fi
    if [[ -z "$json" ]]; then
        return 0
    fi
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$json" | python3 -c '
import json, sys
ccn_limit = int(sys.argv[1])
fn_nloc_limit = int(sys.argv[2])
param_limit = int(sys.argv[3])
data = json.load(sys.stdin)
viol = []
for i in data:
    ccn = i.get("cyclomatic_complexity") or i.get("ccn") or 0
    nloc = i.get("nloc") or 0
    params = i.get("parameters") or i.get("parameter_count") or 0
    try:
        ccn = int(ccn)
        nloc = int(nloc)
        params = int(params)
    except Exception:
        continue
    if ccn > ccn_limit or nloc > fn_nloc_limit or params > param_limit:
        viol.append(i)
for v in viol:
    print(f"{v.get(\"filename\")}:{v.get(\"start_line\")} {v.get(\"name\")} CCN={v.get(\"cyclomatic_complexity\") or v.get(\"ccn\")}, NLOC={v.get(\"nloc\")}, Params={v.get(\"parameters\") or v.get(\"parameter_count\")}")
if viol:
    sys.exit(1)
' "$LIZARD_CCN_STRICT" "$LIZARD_FN_NLOC_LIMIT" "$LIZARD_PARAM_LIMIT"
    else
        echo "$json" | python3 -c '
import json, sys
ccn_limit = int(sys.argv[1])
fn_nloc_limit = int(sys.argv[2])
param_limit = int(sys.argv[3])
data = json.load(sys.stdin)
for i in data:
    ccn = i.get("cyclomatic_complexity") or i.get("ccn") or 0
    nloc = i.get("nloc") or 0
    params = i.get("parameters") or i.get("parameter_count") or 0
    try:
        ccn = int(ccn)
        nloc = int(nloc)
        params = int(params)
    except Exception:
        continue
    if ccn > ccn_limit or nloc > fn_nloc_limit or params > param_limit:
        sys.exit(1)
' "$LIZARD_CCN_STRICT" "$LIZARD_FN_NLOC_LIMIT" "$LIZARD_PARAM_LIMIT" >/dev/null
    fi
}

dotnet_format_check() {
    if command -v dotnet >/dev/null 2>&1; then
        run_tool "dotnet-format" dotnet format --verify-no-changes
    else
        debug "dotnet not found; skipping dotnet format"
    fi
}

dotnet_build_check() {
    if command -v dotnet >/dev/null 2>&1; then
        run_tool "dotnet-build" dotnet build -warnaserror
    else
        debug "dotnet not found; skipping dotnet build"
    fi
}

dotnet_test() {
    if command -v dotnet >/dev/null 2>&1; then
        run_tool "dotnet-test" dotnet test --nologo
    else
        debug "dotnet not found; skipping dotnet test"
    fi
}

dotnet_coverage() {
    if command -v dotnet >/dev/null 2>&1; then
        # Attempt coverlet via data collector if configured
        if dotnet test -l "console;verbosity=minimal" -p:CollectCoverage=true -p:CoverletOutputFormat=cobertura >/dev/null 2>&1; then
            run_tool "dotnet-coverage" dotnet test -p:CollectCoverage=true -p:CoverletOutputFormat=cobertura
        else
            debug "Coverlet not configured; running dotnet test without coverage"
            run_tool "dotnet-test" dotnet test --nologo
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
# Security helpers
# --------------------

security_gitleaks() {
    if command -v gitleaks >/dev/null 2>&1; then
        run_tool "gitleaks" gitleaks detect --no-color --no-banner --redact --verbose
    else
        debug "gitleaks not found; skipping secrets scan"
    fi
}

security_semgrep() {
    if command -v semgrep >/dev/null 2>&1; then
        # Use the default auto rules; users can add a .semgrep.yml to customize
        run_tool "semgrep" semgrep scan --error --severity high,critical || return 1
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
