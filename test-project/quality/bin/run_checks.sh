#!/usr/bin/env bash

set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$QUALITY_DIR/bin/phase_checks.sh" "$@"
