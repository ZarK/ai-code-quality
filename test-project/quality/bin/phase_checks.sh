#!/usr/bin/env bash
# shellcheck disable=SC2317
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE_FILE="$QUALITY_DIR/.phase_progress"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

find_shell_scripts() {
    local search_dir="${1:-.}"
    find "$search_dir" \
        \( -path "*/.venv" -o \
        -path "*/node_modules" -o \
        -path "*/__pycache__" -o \
        -path "*/.pytest_cache" -o \
        -path "*/reports" -o \
        -path "*/.build" -o \
        -path "*/.cache" \) -prune -o \
        -name "*.sh" -type f -print
}

find_python_files() {
    local search_dir="${1:-.}"
    find "$search_dir" \
        \( -path "*/.venv" -o \
        -path "*/node_modules" -o \
        -path "*/__pycache__" -o \
        -path "*/.pytest_cache" -o \
        -path "*/reports" -o \
        -path "*/.build" -o \
        -path "*/.cache" \) -prune -o \
        -name "*.py" -type f -print
}

# =============================================================================
# MODULAR CHECK FUNCTIONS
# =============================================================================

# Shell Quality Checks
shellcheck_check() {
    printf "\n🔍 Running ShellCheck...\n"
    local shell_files
    shell_files=$(find_shell_scripts .)

    if [[ -z "$shell_files" ]]; then
        printf "⚠️  No shell scripts found\n"
        return 0
    fi

    printf "📋 Found shell scripts:\n"
    while IFS= read -r file; do
        printf "  %s\n" "$file"
    done <<<"$shell_files"

    if ! echo "$shell_files" | xargs shellcheck; then
        printf "❌ ShellCheck found issues\n" >&2
        return 1
    fi

    printf "✅ ShellCheck passed\n"
}

shfmt_check() {
    printf "\n🎨 Running shfmt formatting check...\n"
    local shell_files
    shell_files=$(find_shell_scripts .)

    if [[ -z "$shell_files" ]]; then
        printf "⚠️  No shell scripts found\n"
        return 0
    fi

    if ! echo "$shell_files" | xargs shfmt -i 4 -d; then
        printf "❌ shfmt found formatting issues\n" >&2
        return 1
    fi

    printf "✅ shfmt formatting check passed\n"
}

# Python Quality Checks
ruff_check() {
    printf "\n🔍 Running ruff check...\n"
    local python_files
    python_files=$(find_python_files .)

    if [[ -z "$python_files" ]]; then
        printf "⚠️  No Python files found\n"
        return 0
    fi

    if command -v ruff >/dev/null 2>&1; then
        ruff check .
    elif [[ -f ".venv/bin/ruff" ]]; then
        .venv/bin/ruff check .
    else
        printf "⚠️  ruff not found - install with: pip install ruff\n"
        return 1
    fi
}

ruff_format() {
    printf "\n🎨 Running ruff format check...\n"
    local python_files
    python_files=$(find_python_files .)

    if [[ -z "$python_files" ]]; then
        printf "⚠️  No Python files found\n"
        return 0
    fi

    if command -v ruff >/dev/null 2>&1; then
        ruff format --check .
    elif [[ -f ".venv/bin/ruff" ]]; then
        .venv/bin/ruff format --check .
    else
        printf "⚠️  ruff not found - install with: pip install ruff\n"
        return 1
    fi
}

mypy_check() {
    printf "\n🔬 Running mypy...\n"
    local python_files
    python_files=$(find_python_files .)

    if [[ -z "$python_files" ]]; then
        printf "⚠️  No Python files found\n"
        return 0
    fi

    if command -v mypy >/dev/null 2>&1; then
        mypy .
    elif [[ -f ".venv/bin/mypy" ]]; then
        .venv/bin/mypy .
    else
        printf "⚠️  mypy not found - install with: pip install mypy\n"
        return 1
    fi
}

pytest_check() {
    printf "\n🧪 Running pytest...\n"
    if [[ ! -d "tests" ]]; then
        printf "⚠️  No tests directory found\n"
        return 0
    fi

    if command -v pytest >/dev/null 2>&1; then
        pytest
    elif [[ -f ".venv/bin/pytest" ]]; then
        .venv/bin/pytest
    else
        printf "⚠️  pytest not found - install with: pip install pytest\n"
        return 1
    fi
}

# JavaScript/TypeScript Quality Checks
bun_install() {
    printf "\n📦 Running bun install...\n"
    if [[ ! -f "package.json" ]]; then
        printf "⚠️  No package.json found\n"
        return 0
    fi

    if command -v bun >/dev/null 2>&1; then
        bun install
    else
        printf "⚠️  bun not found - install from https://bun.sh\n"
        return 1
    fi
}

biome_check() {
    printf "\n🌿 Running Biome checks...\n"
    if [[ ! -f "package.json" ]]; then
        printf "⚠️  No package.json found\n"
        return 0
    fi

    if command -v bunx >/dev/null 2>&1; then
        bunx biome check --reporter=summary .
    elif command -v npx >/dev/null 2>&1; then
        npx @biomejs/biome check --reporter=summary .
    else
        printf "⚠️  biome not found - install with: bun add -D @biomejs/biome\n"
        return 1
    fi
}

biome_format() {
    printf "\n🎨 Running Biome format check...\n"
    if [[ ! -f "package.json" ]]; then
        printf "⚠️  No package.json found\n"
        return 0
    fi

    if command -v bunx >/dev/null 2>&1; then
        bunx biome format --write .
    elif command -v npx >/dev/null 2>&1; then
        npx @biomejs/biome format --write .
    else
        printf "⚠️  biome not found - install with: bun add -D @biomejs/biome\n"
        return 1
    fi
}

vitest_check() {
    printf "\n🧪 Running Vitest tests...\n"
    if [[ ! -f "package.json" ]]; then
        printf "⚠️  No package.json found\n"
        return 0
    fi

    if command -v bunx >/dev/null 2>&1; then
        bunx vitest run
    elif command -v npx >/dev/null 2>&1; then
        npx vitest run
    else
        printf "⚠️  vitest not found - install with: bun add -D vitest\n"
        return 1
    fi
}

# =============================================================================
# PHASE FUNCTIONS (Composable from modular checks)
# =============================================================================

check_1() {
    printf "\n=== Phase 1: Basic Formatting & Linting ===\n"
    local exit_code=0

    # Detect technologies and run appropriate checks
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")
    printf "🔍 Detected technologies: %s\n" "${techs:-none}"

    if [[ "$techs" == *"shell"* ]]; then
        if ! (shellcheck_check && shfmt_check); then
            exit_code=1
        fi
    fi

    if [[ "$techs" == *"python"* ]]; then
        if ! (ruff_check && ruff_format); then
            exit_code=1
        fi
    fi

    if [[ "$techs" == *"js"* ]] || [[ "$techs" == *"ts"* ]] || [[ "$techs" == *"react"* ]]; then
        if ! (bun_install && biome_check); then
            exit_code=1
        fi
    fi

    return "$exit_code"
}

check_2() {
    printf "\n=== Phase 2: Type Checking & Advanced Linting ===\n"
    local exit_code=0

    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    if [[ "$techs" == *"python"* ]]; then
        if ! mypy_check; then
            exit_code=1
        fi
    fi

    if [[ "$techs" == *"js"* ]] || [[ "$techs" == *"ts"* ]] || [[ "$techs" == *"react"* ]]; then
        if ! biome_format; then
            exit_code=1
        fi
    fi

    return "$exit_code"
}

check_3() {
    printf "\n=== Phase 3: Testing ===\n"
    local exit_code=0

    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")

    if [[ "$techs" == *"python"* ]]; then
        if ! pytest_check; then
            exit_code=1
        fi
    fi

    if [[ "$techs" == *"js"* ]] || [[ "$techs" == *"ts"* ]] || [[ "$techs" == *"react"* ]]; then
        if ! vitest_check; then
            exit_code=1
        fi
    fi

    return "$exit_code"
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
    printf "📝 Updated current phase to %s\n" "$new_phase"
}

get_available_phases() {
    declare -F | grep "declare -f check_" | sed 's/declare -f check_//' | sort -n
}

run_phase() {
    local phase=$1
    local check_function="check_$phase"

    if declare -F "$check_function" >/dev/null; then
        "$check_function"
    else
        printf "❌ Unknown phase: %s\n" "$phase" >&2
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION LOGIC
# =============================================================================

main() {
    local target_phase="${1:-}"

    printf "Universal Code Quality System\n"
    printf "================================\n"

    if [[ -z "$target_phase" ]]; then
        target_phase=$(get_current_phase)
        printf "📋 Using current phase: %s\n" "$target_phase"
    else
        printf "📋 Target phase: %s\n" "$target_phase"
    fi

    local current_phase
    current_phase=$(get_current_phase)

    local available_phases
    available_phases=$(get_available_phases)
    printf "📋 Available phases: %s\n" "$available_phases"

    local phases_run=0
    local failed_phases=()

    # Run all phases up to and including target phase
    for phase in $available_phases; do
        if [[ "$phase" -le "$target_phase" ]]; then
            printf "\n🔄 Running Phase %s...\n" "$phase"
            if run_phase "$phase"; then
                printf "✅ Phase %s passed\n" "$phase"
                phases_run=$((phases_run + 1))
            else
                printf "❌ Phase %s failed\n" "$phase"
                failed_phases+=("$phase")

                # If this is a previous phase, it's a regression
                if [[ "$phase" -lt "$target_phase" ]]; then
                    printf "\n🚨 REGRESSION in Phase %s!\n" "$phase" >&2
                    printf "🛑 Previous phases must not regress!\n" >&2
                    exit 1
                fi
            fi
        else
            printf "⏭️  Skipping future Phase %s\n" "$phase"
        fi
    done

    # Summary
    printf "\n=== SUMMARY ===\n"
    printf "🔄 Phases run: %d\n" "$phases_run"

    if [[ ${#failed_phases[@]} -eq 0 ]]; then
        printf "✅ All phases passed!\n"

        # Update current phase if target is newer
        if [[ "$current_phase" -lt "$target_phase" ]]; then
            set_current_phase "$target_phase"
        fi

        exit 0
    else
        printf "❌ Failed phases: %s\n" "${failed_phases[*]}"

        # Check if only current phase failed (allowed for WIP)
        if [[ ${#failed_phases[@]} -eq 1 && "${failed_phases[0]}" == "$target_phase" ]]; then
            printf "🔄 Only current phase failed - this is allowed for WIP\n"
            exit 0
        else
            printf "🛑 Previous phases failed - this indicates regression!\n" >&2
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
