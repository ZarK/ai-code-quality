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
        if grep -q '"@playwright/test"' package.json 2>/dev/null; then
            DETECTED_TECHS="${DETECTED_TECHS}playwright,"
        fi
    fi

    # .NET detection
    if find . -maxdepth 3 \( -name "*.sln" -o -name "*.csproj" -o -name "global.json" \) -not -path "./node_modules/*" -type f | head -1 | grep -q .; then
        DETECTED_TECHS="${DETECTED_TECHS}dotnet,"
    fi

    # Java/Kotlin detection (Maven/Gradle)
    if find . -maxdepth 3 \( -name "pom.xml" -o -name "build.gradle" -o -name "build.gradle.kts" \) -not -path "./node_modules/*" -type f | head -1 | grep -q .; then
        DETECTED_TECHS="${DETECTED_TECHS}java,"
        # Check for Kotlin files or Kotlin plugin in Gradle
        if find . -maxdepth 4 -name "*.kt" -not -path "./node_modules/*" -type f | head -1 | grep -q . || grep -q "kotlin" build.gradle* 2>/dev/null; then
            DETECTED_TECHS="${DETECTED_TECHS}kotlin,"
        fi
    fi

    # HCL / Terraform detection
    if find . -maxdepth 4 \( -name "*.tf" -o -name "*.hcl" -o -name "terraform.tfvars" -o -name ".terraform.lock.hcl" \) -not -path "./node_modules/*" -type f | head -1 | grep -q .; then
        DETECTED_TECHS="${DETECTED_TECHS}hcl,"
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
