#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/your-org/ai-code-quality"
QUALITY_DIR="quality"

setup_pre_commit_hook() {
    printf "Setting up pre-commit hook...\n"

    if [[ ! -d ".git" ]]; then
        printf "Error: Not a git repository. Pre-commit hook cannot be installed.\n"
        return 1
    fi

    if [[ -f ".git/hooks/pre-commit" ]]; then
        mv ".git/hooks/pre-commit" ".git/hooks/pre-commit.backup.$(date +%s)"
        printf "Existing hook backed up\n"
    fi

    if [[ ! -f "quality/hooks/pre-commit" ]]; then
        printf "Error: Quality system pre-commit hook not found.\n"
        printf "Make sure the quality system is properly installed.\n"
        return 1
    fi

    ln -s "../../quality/hooks/pre-commit" ".git/hooks/pre-commit"
    printf "Pre-commit hook installed successfully\n"
    printf "Quality checks will now run automatically before each commit\n"
    printf "To disable: rm .git/hooks/pre-commit\n"
    return 0
}

setup_github_workflow() {
    printf "Setting up GitHub Actions workflow...\n"

    if [[ ! -d ".git" ]]; then
        printf "Error: Not a git repository. GitHub Actions workflow cannot be installed.\n"
        return 1
    fi

    local workflow_dir=".github/workflows"
    local workflow_file="quality.yml"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_workflow="$script_dir/.github/workflows/quality.yml"

    mkdir -p "$workflow_dir"

    if [[ -f "$workflow_dir/$workflow_file" ]]; then
        mv "$workflow_dir/$workflow_file" "$workflow_dir/$workflow_file.backup.$(date +%s)"
        printf "Existing workflow backed up\n"
    fi

    if [[ ! -f "$source_workflow" ]]; then
        printf "Error: Quality system workflow template not found at %s\n" "$source_workflow"
        printf "Make sure the quality system is properly installed.\n"
        return 1
    fi

    cp "$source_workflow" "$workflow_dir/$workflow_file"
    printf "GitHub Actions workflow installed successfully\n"
    printf "Quality checks will now run automatically on push/PR to main/develop branches\n"
    printf "To disable: rm %s/%s\n" "$workflow_dir" "$workflow_file"
    return 0
}

SETUP_HOOK=false
SETUP_WORKFLOW=false
INSTALL_SYSTEM=true

while [[ $# -gt 0 ]]; do
    case $1 in
    --setup-hook)
        SETUP_HOOK=true
        shift
        ;;
    --setup-workflow)
        SETUP_WORKFLOW=true
        shift
        ;;
    *)
        printf "Unknown option: %s\n" "$1"
        printf "Usage: %s [--setup-hook] [--setup-workflow]\n" "$0"
        exit 1
        ;;
    esac
done

if [[ "$SETUP_HOOK" == true || "$SETUP_WORKFLOW" == true ]]; then
    INSTALL_SYSTEM=false
fi

if [[ "$INSTALL_SYSTEM" == true ]]; then
    printf "Installing Universal Code Quality System\n"
    printf "=======================================\n"

    if [[ -d "$QUALITY_DIR" ]]; then
        printf "Existing quality directory found. Backing up...\n"
        mv "$QUALITY_DIR" "${QUALITY_DIR}.backup.$(date +%s)"
    fi
else
    printf "Running setup commands only...\n"
    printf "==============================\n"
fi

if [[ "$INSTALL_SYSTEM" == true ]]; then
    printf "Downloading quality system...\n"
    if command -v git >/dev/null 2>&1; then
        git clone --depth=1 "$REPO_URL" temp-quality
        mv temp-quality/quality ./
        rm -rf temp-quality
    else
        printf "Error: Git not found. Please install git or download manually.\n"
        exit 1
    fi

    printf "Setting up permissions...\n"
    chmod +x quality/bin/*.sh
    chmod +x quality/lib/*.sh
    chmod +x quality/hooks/*
    chmod +x quality/stages/*.sh
    chmod +x quality/check.sh

    printf "Creating root check.sh wrapper...\n"
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

    printf "Initializing phase tracking...\n"
    echo "0" >quality/.phase_progress

    printf "Updating .gitignore...\n"
    if [[ -f ".gitignore" ]]; then
        if ! grep -q "^quality/$" .gitignore 2>/dev/null; then
            printf "\n# Code quality system\nquality/\n" >>.gitignore
            printf "Added quality/ to .gitignore\n"
        else
            printf "quality/ already in .gitignore\n"
        fi
    else
        printf "# Code quality system\nquality/\n" >.gitignore
        printf "Created .gitignore with quality/ entry\n"
    fi

    printf "\nInstalling quality tools...\n"
    ./quality/bin/install_tools.sh
fi

if [[ "$SETUP_HOOK" == true ]]; then
    printf "\nSetting up pre-commit hook...\n"
    setup_pre_commit_hook
fi

if [[ "$SETUP_WORKFLOW" == true ]]; then
    printf "\nSetting up GitHub Actions workflow...\n"
    setup_github_workflow
fi

if [[ "$INSTALL_SYSTEM" == true ]]; then
    printf "\nInstallation complete!\n"
    printf "\nNext steps:\n"
    printf "1. Run checks: ./quality/check.sh\n"
    printf "2. Check specific path: ./quality/check.sh src/\n"
    printf "3. Setup pre-commit hook: ./quality/install.sh --setup-hook\n"
    printf "4. Setup GitHub Actions: ./quality/install.sh --setup-workflow\n"
    printf "5. Setup both: ./quality/install.sh --setup-hook --setup-workflow\n"
    printf "6. Get help: ./quality/check.sh --help\n"
    printf "\nFor more info, see: %s\n" "$REPO_URL"
else
    printf "\nSetup complete!\n"
    if [[ "$SETUP_HOOK" == true ]]; then
        printf "✅ Pre-commit hook installed\n"
    fi
    if [[ "$SETUP_WORKFLOW" == true ]]; then
        printf "✅ GitHub Actions workflow installed\n"
    fi
fi
