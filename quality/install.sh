#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/your-org/ai-code-quality"
QUALITY_DIR="quality"

setup_pre_commit_hook() {
    printf "🪝 Setting up pre-commit hook...\n"

    if [[ ! -d ".git" ]]; then
        printf "❌ Not a git repository. Pre-commit hook cannot be installed.\n"
        return 1
    fi

    if [[ -f ".git/hooks/pre-commit" ]]; then
        printf "⚠️  Pre-commit hook already exists.\n"
        printf "   Current hook content:\n"
        printf "   %s\n" "$(head -3 .git/hooks/pre-commit)"
        printf "   ...\n"
        printf "\nWould you like to backup and replace it? (y/N): "
        read -r replace_hook

        if [[ "$replace_hook" =~ ^[Yy]$ ]]; then
            mv ".git/hooks/pre-commit" ".git/hooks/pre-commit.backup.$(date +%s)"
            printf "✅ Existing hook backed up\n"
        else
            printf "❌ Pre-commit hook setup cancelled.\n"
            printf "   To manually integrate, add this to your existing hook:\n"
            printf "   ./quality/bin/run_checks.sh\n"
            return 1
        fi
    fi

    if [[ ! -f "quality/hooks/pre-commit" ]]; then
        printf "❌ Quality system pre-commit hook not found.\n"
        printf "   Make sure the quality system is properly installed.\n"
        return 1
    fi

    ln -s "../../quality/hooks/pre-commit" ".git/hooks/pre-commit"
    printf "✅ Pre-commit hook installed successfully\n"
    printf "   Quality checks will now run automatically before each commit\n"
    printf "   To disable: rm .git/hooks/pre-commit\n"
    return 0
}

if [[ "${1:-}" == "--setup-hook" ]]; then
    setup_pre_commit_hook
    exit $?
fi

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

printf "\n🔧 Installing quality tools...\n"
printf "Would you like to install required quality tools now? (y/N): "
read -r install_tools

if [[ "$install_tools" =~ ^[Yy]$ ]]; then
    ./quality/bin/install_tools.sh
else
    printf "Skipping tool installation.\n"
    printf "You can install tools later with: ./quality/bin/install_tools.sh\n"
fi

printf "\n🪝 Setting up pre-commit hook...\n"
printf "Would you like to set up the pre-commit hook to run quality checks? (y/N): "
read -r setup_hook

if [[ "$setup_hook" =~ ^[Yy]$ ]]; then
    setup_pre_commit_hook
else
    printf "Skipping pre-commit hook setup.\n"
    printf "You can set it up later by running: ./quality/install.sh --setup-hook\n"
fi

printf "\n🎉 Installation complete!\n"
printf "\nNext steps:\n"
printf "1. Install tools (if skipped): ./quality/bin/install_tools.sh\n"
printf "2. Setup pre-commit hook (if skipped): ./quality/install.sh --setup-hook\n"
printf "3. Run checks: ./check.sh\n"
printf "4. Check specific path: ./check.sh src/\n"
printf "5. Get help: ./quality/bin/run_checks.sh --help\n"
printf "\nFor more info, see: %s\n" "$REPO_URL"
