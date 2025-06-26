#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "Tool Installation Helper\n"
printf "========================\n"

detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_python_module() {
    python3 -m "$1" --version >/dev/null 2>&1
}

install_brew_tools() {
    printf "\nInstalling Homebrew tools (shellcheck, shfmt only)...\n"
    if check_command brew; then
        if [[ -f "$QUALITY_DIR/Brewfile" ]]; then
            printf "Running: brew bundle --file=%s/Brewfile\n" "$QUALITY_DIR"
            brew bundle --file="$QUALITY_DIR/Brewfile"
        else
            printf "Brewfile not found, installing individual tools...\n"
            brew install shellcheck shfmt
        fi
    else
        printf "Homebrew not found. Install from: https://brew.sh\n"
        return 1
    fi
}

install_python_tools() {
    printf "\nInstalling Python tools via uv (uses asdf's active Python)...\n"
    if check_command uv; then
        if [[ -f "$QUALITY_DIR/requirements.txt" ]]; then
            printf "Installing from requirements.txt using uv...\n"
            cd "$QUALITY_DIR"
            uv pip install --system -r requirements.txt
            cd - >/dev/null
        else
            printf "requirements.txt not found, installing individual tools...\n"
            uv pip install --system ruff mypy pytest coverage black isort radon
        fi
    else
        printf "uv not found. Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh\n"
        return 1
    fi
}

install_node_tools() {
    printf "\nInstalling Node.js tools via bun (uses asdf's active Node)...\n"
    if check_command bun; then
        if [[ -f "$QUALITY_DIR/package.json" ]]; then
            printf "Installing from package.json using bun...\n"
            cd "$QUALITY_DIR"
            bun install
            cd - >/dev/null
        else
            printf "package.json not found, installing individual tools...\n"
            bun add -g @biomejs/biome eslint prettier typescript htmlhint stylelint
        fi
    else
        printf "bun not found. Install bun: curl -fsSL https://bun.sh/install | bash\n"
        return 1
    fi
}

install_linux_tools() {
    printf "\nInstalling Linux tools (shellcheck, shfmt only)...\n"
    if check_command apt; then
        sudo apt update
        sudo apt install -y shellcheck

        printf "Installing shfmt...\n"
        if check_command go; then
            go install mvdan.cc/sh/v3/cmd/shfmt@latest
        else
            printf "Go not found. Installing shfmt manually...\n"
            curl -L https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.7.0_linux_amd64 -o /tmp/shfmt
            chmod +x /tmp/shfmt
            sudo mv /tmp/shfmt /usr/local/bin/shfmt
        fi
    elif check_command yum; then
        sudo yum install -y ShellCheck
    else
        printf "Package manager not found. Please install tools manually.\n"
        return 1
    fi
}

show_status() {
    printf "\nTool Status:\n"
    printf "============\n"

    # Check command-line tools
    cmd_tools=("shellcheck" "shfmt" "node" "bun" "python3" "uv")
    for tool in "${cmd_tools[@]}"; do
        if check_command "$tool"; then
            printf "✅ %s\n" "$tool"
        else
            printf "❌ %s\n" "$tool"
        fi
    done

    # Check Python modules
    python_modules=("ruff" "mypy")
    for module in "${python_modules[@]}"; do
        if check_python_module "$module"; then
            printf "✅ %s (python -m %s)\n" "$module" "$module"
        else
            printf "❌ %s\n" "$module"
        fi
    done
}

main() {
    local platform
    platform=$(detect_platform)

    printf "Detected platform: %s\n" "$platform"

    show_status

    printf "\nWould you like to install missing tools? (y/N): "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        case "$platform" in
        macos)
            install_brew_tools
            install_python_tools
            install_node_tools
            ;;
        linux)
            install_linux_tools
            install_python_tools
            install_node_tools
            ;;
        *)
            printf "Unsupported platform. Please install tools manually:\n"
            printf "- shellcheck: https://github.com/koalaman/shellcheck\n"
            printf "- shfmt: https://github.com/mvdan/sh\n"
            printf "- asdf with Node.js plugin: https://asdf-vm.com\n"
            printf "- asdf with Python plugin: https://asdf-vm.com\n"
            printf "- uv: https://astral.sh/uv\n"
            printf "- bun: https://bun.sh\n"
            exit 1
            ;;
        esac

        printf "\nInstallation complete!\n"
        show_status
    else
        printf "Skipping tool installation.\n"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
