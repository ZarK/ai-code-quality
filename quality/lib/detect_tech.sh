#!/usr/bin/env bash
set -euo pipefail

OVERRIDES=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --override)
        OVERRIDES="$2"
        shift 2
        ;;
    *)
        shift
        ;;
    esac
done

DETECTED_TECHS=""

if [[ -n "$OVERRIDES" ]]; then
    DETECTED_TECHS="$OVERRIDES"
else
    # Python detection
    if [[ -f "pyproject.toml" || -f "requirements.txt" || -f "setup.py" || -f "Pipfile" ]]; then
        DETECTED_TECHS="${DETECTED_TECHS}python,"
    fi

    # JavaScript/TypeScript detection
    if [[ -f "package.json" ]]; then
        DETECTED_TECHS="${DETECTED_TECHS}js,"
        if grep -q '"typescript"' package.json 2>/dev/null || [[ -f "tsconfig.json" ]]; then
            DETECTED_TECHS="${DETECTED_TECHS}ts,"
        fi
        if grep -q '"react"' package.json 2>/dev/null; then
            DETECTED_TECHS="${DETECTED_TECHS}react,"
        fi
    fi

    # HTML detection
    if find . -maxdepth 3 -name "*.html" -not -path "./node_modules/*" -not -path "./.venv/*" -type f | head -1 | grep -q .; then
        DETECTED_TECHS="${DETECTED_TECHS}html,"
    fi

    # CSS detection
    if find . -maxdepth 3 -name "*.css" -not -path "./node_modules/*" -not -path "./.venv/*" -type f | head -1 | grep -q .; then
        DETECTED_TECHS="${DETECTED_TECHS}css,"
    fi

    # Shell script detection
    if find . -maxdepth 3 -name "*.sh" -type f | head -1 | grep -q .; then
        DETECTED_TECHS="${DETECTED_TECHS}shell,"
    fi
fi

echo "${DETECTED_TECHS%,}"
