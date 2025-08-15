#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$QUALITY_DIR/lib/_stage_common.sh"

parse_flags "$@"

TECHS=$(detect_tech)

missing=()
notes=()

have() { command -v "$1" >/dev/null 2>&1; }

# Core
for t in shellcheck shfmt python3 uv node bun git; do
    if ! have "$t"; then missing+=("$t"); fi
done

# Python
if [[ "$TECHS" == *"python"* ]]; then
    for m in ruff mypy pytest; do
        if ! python3 -m "$m" --version >/dev/null 2>&1; then missing+=("python:$m"); fi
    done
fi

# JS/TS tools are run via bunx/npx, but bun/node must exist

# .NET
if [[ "$TECHS" == *"dotnet"* ]]; then
    if ! have dotnet; then missing+=("dotnet-sdk"); fi
fi

# Java
if [[ "$TECHS" == *"java"* ]]; then
    if ! have java; then missing+=("java-jdk"); fi
    if ! have mvn && ! have gradle && ! have ./gradlew; then missing+=("maven-or-gradle"); fi
fi

# HCL/Terraform
if [[ "$TECHS" == *"hcl"* ]]; then
    if ! have terraform && ! have hclfmt; then missing+=("terraform-or-hclfmt"); fi
    if ! have tflint; then missing+=("tflint"); fi
    if ! have tfsec; then notes+=("tfsec optional for security stage"); fi
fi

# Security
if ! have gitleaks; then notes+=("gitleaks optional for secrets scanning"); fi
if ! have semgrep; then notes+=("semgrep optional for SAST"); fi

printf "Detected tech: %s\n" "$TECHS"

if [[ ${#missing[@]} -eq 0 ]]; then
    echo "✅ All required tools appear to be installed for detected tech."
else
    echo "❌ Missing tools:"
    for m in "${missing[@]}"; do echo "  - $m"; done
    echo
    echo "Install hints:"
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
    darwin)
        echo "  brew install shellcheck shfmt gitleaks semgrep tflint tfsec"
        echo "  # dotnet: brew install --cask dotnet-sdk"
        echo "  # java: brew install temurin"
        ;;
    linux)
        echo "  sudo apt install -y shellcheck curl git"
        echo "  # shfmt: install via go or download release"
        echo "  # dotnet: https://learn.microsoft.com/dotnet/core/install/linux"
        echo "  # java: apt install temurin-jdk or use sdkman"
        ;;
    *)
        echo "  On Windows, use winget/scoop as printed by install_tools.sh"
        ;;
    esac
fi

if [[ ${#notes[@]} -gt 0 ]]; then
    echo
    echo "Notes:"
    for n in "${notes[@]}"; do echo "  - $n"; done
fi
