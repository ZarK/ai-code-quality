#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_PATH="${1:-$(pwd)}"

if [[ ! -d "$TARGET_PATH" ]]; then
    echo "Error: Target path '$TARGET_PATH' does not exist"
    exit 1
fi

cd "$TARGET_PATH"

exec "$SCRIPT_DIR/bin/run_checks.sh" "${@:2}"
