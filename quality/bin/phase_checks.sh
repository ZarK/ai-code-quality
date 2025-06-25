#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE_FILE="$QUALITY_DIR/.phase_progress"

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
    local stage_script="$QUALITY_DIR/stages/${stage}-${stage_name}.sh"

    if [[ -f "$stage_script" ]]; then
        if bash "$stage_script" --quiet; then
            printf "Stage %s (%s): PASSED\n" "$stage" "$stage_name"
        else
            printf "Stage %s (%s): FAILED\n" "$stage" "$stage_name"
            return 1
        fi
    else
        printf "Unknown stage: %s\n" "$stage" >&2
        return 1
    fi
}

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

    for stage in $available_stages; do
        if [[ "$stage" -le "$target_stage" ]]; then
            if ! run_stage "$stage"; then
                failed_stages+=("$stage")
            fi
        fi
    done

    if [[ ${#failed_stages[@]} -eq 0 ]]; then
        if [[ "$current_stage" -lt "$target_stage" ]]; then
            set_current_stage "$target_stage"
        fi
        exit 0
    else
        printf "%s\n" "${failed_stages[@]}" >&2
        exit 1
    fi
}

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
