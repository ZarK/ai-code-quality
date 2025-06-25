#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUALITY_DIR="$SCRIPT_DIR/quality"

if [[ ! -d "$QUALITY_DIR" ]]; then
    echo "Error: quality directory not found at $QUALITY_DIR"
    echo "Make sure you're running this from a project with the quality system installed."
    exit 1
fi

TARGET_PATH="${1:-$(pwd)}"

if [[ ! -d "$TARGET_PATH" ]]; then
    echo "Error: Target path '$TARGET_PATH' does not exist"
    exit 1
fi

cd "$TARGET_PATH"

exec "$QUALITY_DIR/bin/run_checks.sh" "${@:2}"
