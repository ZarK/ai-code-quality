#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIQ_DIR="$(pwd)/.aiq"
PHASE_FILE="$QUALITY_DIR/.phase_progress"
PROGRESS_JSON="$AIQ_DIR/progress.json"

# Extract first integer from a string; defaults to 0 if none
parse_stage_from_string() {
    local s="$1"
    local n
    n=$(printf "%s" "$s" | grep -oE '[0-9]+' | head -1 || true)
    if [[ -n "${n:-}" ]]; then
        echo "$n"
    else
        echo "0"
    fi
}

get_current_stage() {
    # Prefer .aiq/progress.json if present; fallback to legacy .phase_progress; default 1
    if [[ -f "$PROGRESS_JSON" ]]; then
        # Try to extract current_stage number without jq (portable whitespace class)
        local val
        val=$(grep -E '"current_stage"[[:space:]]*:' "$PROGRESS_JSON" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/') || true
        if [[ -n "${val:-}" ]]; then
            echo "$val"
            return 0
        fi
        # Fallback: parse first integer from entire file
        parse_stage_from_string "$(cat "$PROGRESS_JSON" 2>/dev/null || true)"
        return 0
    fi
    if [[ -f "$PHASE_FILE" ]]; then
        # Handle both plain number and JSON accidentally written here
        parse_stage_from_string "$(head -n1 "$PHASE_FILE" 2>/dev/null || true)"
        return 0
    fi
    echo "1"
}

set_current_stage() {
    local new_stage=$1
    mkdir -p "$AIQ_DIR"
    # Write minimal JSON, preserve other fields if exist
    if [[ -f "$PROGRESS_JSON" ]]; then
        # naive replace current_stage value
        if grep -q '"current_stage"' "$PROGRESS_JSON"; then
            sed -E "s/(\"current_stage\"[[:space:]]*:[[:space:]]*)[0-9]+/\1${new_stage}/" "$PROGRESS_JSON" >"$PROGRESS_JSON.tmp" && mv "$PROGRESS_JSON.tmp" "$PROGRESS_JSON"
        else
            # insert field
            echo "{ \"current_stage\": ${new_stage} }" >"$PROGRESS_JSON"
        fi
    else
        echo "{ \"current_stage\": ${new_stage} }" >"$PROGRESS_JSON"
    fi
    # Maintain legacy file for backward compatibility
    echo "$new_stage" >"$PHASE_FILE"
}

get_available_stages() {
    echo "0 1 2 3 4 5 6 7 8 9"
}

get_stage_name() {
    case "$1" in
    0) echo "e2e" ;;
    1) echo "lint" ;;
    2) echo "format" ;;
    3) echo "type_check" ;;
    4) echo "unit_test" ;;
    5) echo "sloc" ;;
    6) echo "complexity" ;;
    7) echo "maintainability" ;;
    8) echo "coverage" ;;
    9) echo "security" ;;
    *) echo "unknown" ;;
    esac
}

run_stage() {
    local stage=$1
    local stage_name
    stage_name=$(get_stage_name "$stage")
    local stage_script="$QUALITY_DIR/stages/${stage}-${stage_name}.sh"

    if [[ -f "$stage_script" ]]; then
        local _out
        if _out=$(bash "$stage_script" --quiet 2>/dev/null); then
            if echo "$_out" | grep -q "AIQ_NO_TESTS=1"; then
                printf "Stage %s (%s): WARNING (zero tests detected)\n" "$stage" "$stage_name"
            else
                printf "Stage %s (%s): PASSED\n" "$stage" "$stage_name"
            fi
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

    # Normalize to integers to avoid [[ ]] numeric comparison errors
    target_stage=$(parse_stage_from_string "$target_stage")
    current_stage=$(parse_stage_from_string "$current_stage")

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
        if [[ -n "${FAILED_STAGES_FILE:-}" ]]; then
            printf "%s\n" "${failed_stages[@]}" >"$FAILED_STAGES_FILE"
        else
            printf "%s\n" "${failed_stages[@]}" 1>&2
        fi
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
