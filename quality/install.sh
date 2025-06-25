#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/your-org/ai-code-quality"
QUALITY_DIR="quality"

printf "🔧 Installing Universal Code Quality System\n"
printf "==========================================\n"

if [[ -d "$QUALITY_DIR" ]]; then
    printf "📁 Existing quality directory found. Backing up...\n"
    mv "$QUALITY_DIR" "${QUALITY_DIR}.backup.$(date +%s)"
fi

printf "📥 Downloading quality system...\n"
if command -v git >/dev/null 2>&1; then
    git clone --depth=1 "$REPO_URL" temp-quality
    mv temp-quality/quality ./
    rm -rf temp-quality
else
    printf "❌ Git not found. Please install git or download manually.\n"
    exit 1
fi

printf "🔧 Setting up permissions...\n"
chmod +x quality/bin/*.sh
chmod +x quality/lib/*.sh
chmod +x quality/hooks/*
chmod +x quality/stages/*.sh
chmod +x quality/check.sh

printf "🔗 Creating root check.sh wrapper...\n"
cat >check.sh <<'EOF'
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
EOF
chmod +x check.sh

printf "🎯 Initializing phase tracking...\n"
echo "0" >quality/.phase_progress

printf "📝 Updating .gitignore...\n"
if [[ -f ".gitignore" ]]; then
    if ! grep -q "^quality/$" .gitignore 2>/dev/null; then
        printf "\n# Code quality system\nquality/\n" >>.gitignore
        printf "✅ Added quality/ to .gitignore\n"
    else
        printf "✅ quality/ already in .gitignore\n"
    fi
else
    printf "# Code quality system\nquality/\n" >.gitignore
    printf "✅ Created .gitignore with quality/ entry\n"
fi

printf "🪝 Installing pre-commit hook (optional)...\n"
if [[ -d ".git" ]]; then
    if [[ ! -f ".git/hooks/pre-commit" ]]; then
        ln -s "../../quality/hooks/pre-commit" ".git/hooks/pre-commit"
        printf "✅ Pre-commit hook installed\n"
    else
        printf "⚠️  Pre-commit hook already exists. Manual setup required.\n"
        printf "   Add this to your existing hook: ./quality/bin/run_checks.sh\n"
    fi
else
    printf "⚠️  Not a git repository. Pre-commit hook skipped.\n"
fi

printf "\n🔧 Installing quality tools...\n"
printf "Would you like to install required quality tools now? (y/N): "
read -r install_tools

if [[ "$install_tools" =~ ^[Yy]$ ]]; then
    ./quality/bin/install_tools.sh
else
    printf "Skipping tool installation.\n"
    printf "You can install tools later with: ./quality/bin/install_tools.sh\n"
fi

printf "\n🎉 Installation complete!\n"
printf "\nNext steps:\n"
printf "1. Install tools (if skipped): ./quality/bin/install_tools.sh\n"
printf "2. Run checks: ./check.sh\n"
printf "3. Check specific path: ./check.sh src/\n"
printf "4. Get help: ./quality/bin/run_checks.sh --help\n"
printf "\nFor more info, see: %s\n" "$REPO_URL"
