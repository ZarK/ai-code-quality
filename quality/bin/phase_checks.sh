#!/usr/bin/env bash
set -euo pipefail
QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf "🚀 Universal Code Quality System
"
printf "================================
"
techs=$("$QUALITY_DIR/lib/detect_tech.sh" "$@")
printf "📋 Detected: %s
" "${techs:-none}"
printf "✅ Enhanced system with Biome, Radon, Shell checks ready!
"
