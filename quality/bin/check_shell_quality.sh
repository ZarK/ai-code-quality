#!/usr/bin/env bash

set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "🐚 Shell Script Quality Checker\n"
printf "===============================\n"

find_shell_scripts() {
    local search_dir="${1:-.}"
    find "$search_dir" \
        \( -path "*/.venv" -o \
        -path "*/node_modules" -o \
        -path "*/__pycache__" -o \
        -path "*/.pytest_cache" -o \
        -path "*/reports" -o \
        -path "*/.build" -o \
        -path "*/.cache" -o \
        -path "*/quality" \) -prune -o \
        -name "*.sh" -type f -print
}

check_tool() {
    local tool=$1
    if command -v "$tool" >/dev/null 2>&1; then
        printf "✅ %s is available\n" "$tool"
        return 0
    else
        printf "❌ %s is not available\n" "$tool"
        return 1
    fi
}

printf "\n🔍 Checking for shell quality tools...\n"
TOOLS_AVAILABLE=true

if ! check_tool shellcheck; then
    printf "   Install with: brew install shellcheck (macOS) or apt install shellcheck (Linux)\n"
    TOOLS_AVAILABLE=false
fi

if ! check_tool shfmt; then
    printf "   Install with: brew install shfmt (macOS) or go install mvdan.cc/sh/v3/cmd/shfmt@latest\n"
    TOOLS_AVAILABLE=false
fi

if [[ "$TOOLS_AVAILABLE" == "false" ]]; then
    printf "\n⚠️  Some tools are missing. Skipping shell quality checks.\n"
    exit 0
fi

printf "\n🔍 Finding shell scripts...\n"
mapfile -t SHELL_SCRIPTS < <(find_shell_scripts)

if [[ ${#SHELL_SCRIPTS[@]} -eq 0 ]]; then
    printf "📄 No shell scripts found.\n"
    exit 0
fi

printf "📄 Found %d shell scripts\n" "${#SHELL_SCRIPTS[@]}"

OVERALL_EXIT_CODE=0

for script in "${SHELL_SCRIPTS[@]}"; do
    printf "\n📄 Checking %s...\n" "$script"

    printf "  🔍 Running shellcheck...\n"
    if shellcheck "$script"; then
        printf "  ✅ shellcheck passed\n"
    else
        printf "  ❌ shellcheck failed\n"
        OVERALL_EXIT_CODE=1
    fi

    printf "  🎨 Checking formatting with shfmt...\n"
    if shfmt -i 4 -d "$script" >/dev/null; then
        printf "  ✅ shfmt formatting is correct\n"
    else
        printf "  ❌ shfmt formatting issues found\n"
        printf "     Run: shfmt -i 4 -w %s\n" "$script"
        OVERALL_EXIT_CODE=1
    fi
done

printf "\n=== SHELL QUALITY SUMMARY ===\n"
if [[ $OVERALL_EXIT_CODE -eq 0 ]]; then
    printf "✅ All shell scripts passed quality checks!\n"
else
    printf "❌ Some shell scripts have quality issues\n"
    printf "🔧 Run the suggested commands above to fix formatting issues\n"
fi

exit $OVERALL_EXIT_CODE
