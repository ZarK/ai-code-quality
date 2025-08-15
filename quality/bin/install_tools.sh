#!/usr/bin/env bash
set -euo pipefail

QUALITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "Tool Installation Helper\n"
printf "========================\n"

DRY_RUN=0
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=1
    fi
done

detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* || "$OS" == "Windows_NT" ]]; then
        echo "windows"
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
    printf "\nInstalling Homebrew tools (shellcheck, shfmt, gitleaks, semgrep)...\n"
    if check_command brew; then
        if [[ -f "$QUALITY_DIR/Brewfile" ]]; then
            printf "Running: brew bundle --file=%s/Brewfile\n" "$QUALITY_DIR"
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] brew bundle --file=$QUALITY_DIR/Brewfile"
            else
                brew bundle --file="$QUALITY_DIR/Brewfile"
            fi
        else
            printf "Brewfile not found, installing individual tools...\n"
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] brew install shellcheck shfmt gitleaks semgrep tflint tfsec"
            else
                brew install shellcheck shfmt gitleaks semgrep tflint tfsec || true
            fi
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
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] uv pip install --system -r requirements.txt"
            else
                uv pip install --system -r requirements.txt
            fi
            cd - >/dev/null
        else
            printf "requirements.txt not found, installing individual tools...\n"
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] uv pip install --system ruff mypy pytest coverage black isort radon"
            else
                uv pip install --system ruff mypy pytest coverage black isort radon
            fi
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
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] (cd $QUALITY_DIR && bun install)"
            else
                bun install
            fi
            cd - >/dev/null
        else
            printf "package.json not found, installing individual tools...\n"
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] bun add -g @biomejs/biome eslint prettier typescript htmlhint stylelint"
            else
                bun add -g @biomejs/biome eslint prettier typescript htmlhint stylelint
            fi
        fi

        # Check if Playwright is needed in the project
        if [[ -f "../package.json" ]] && grep -q '"@playwright/test"' "../package.json" 2>/dev/null; then
            printf "Playwright detected, installing Playwright...\n"
            cd ..
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] bun add -D @playwright/test"
                echo "[DRY-RUN] npx playwright install --with-deps"
            else
                bun add -D @playwright/test
                npx playwright install --with-deps
            fi
            cd - >/dev/null
        fi
    else
        printf "bun not found. Install bun: curl -fsSL https://bun.sh/install | bash\n"
        return 1
    fi
}

install_linux_tools() {
    printf "\nInstalling Linux tools (shellcheck, shfmt, gitleaks, semgrep, tflint, tfsec)...\n"
    if check_command apt; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[DRY-RUN] sudo apt update"
        else
            sudo apt update
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[DRY-RUN] sudo apt install -y shellcheck curl git"
        else
            sudo apt install -y shellcheck curl git
        fi

        printf "Installing shfmt...\n"
        if check_command go; then
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] go install mvdan.cc/sh/v3/cmd/shfmt@latest"
            else
                go install mvdan.cc/sh/v3/cmd/shfmt@latest
            fi
        else
            printf "Go not found. Installing shfmt manually...\n"
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] curl -L https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.7.0_linux_amd64 -o /tmp/shfmt"
                echo "[DRY-RUN] chmod +x /tmp/shfmt"
                echo "[DRY-RUN] sudo mv /tmp/shfmt /usr/local/bin/shfmt"
            else
                curl -L https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.7.0_linux_amd64 -o /tmp/shfmt
                chmod +x /tmp/shfmt
                sudo mv /tmp/shfmt /usr/local/bin/shfmt
            fi
        fi

        # gitleaks
        if ! check_command gitleaks; then
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] install gitleaks (download, extract, move to /usr/local/bin)"
            else
                curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep "browser_download_url.*linux_x64.tar.gz" | cut -d '"' -f 4 | xargs curl -L -o /tmp/gitleaks.tar.gz || true
                tar -xzf /tmp/gitleaks.tar.gz -C /tmp 2>/dev/null || true
                sudo mv /tmp/gitleaks /usr/local/bin/gitleaks 2>/dev/null || true
            fi
        fi
        # semgrep
        if ! check_command semgrep; then
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] curl -sL https://semgrep.dev/install.sh | sudo bash"
            else
                curl -sL https://semgrep.dev/install.sh | sudo bash || true
            fi
        fi
        # tflint
        if ! check_command tflint; then
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
                echo "[DRY-RUN] sudo mv ./tflint /usr/local/bin/tflint"
            else
                curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash || true
                sudo mv ./tflint /usr/local/bin/tflint 2>/dev/null || true
            fi
        fi
        # tfsec
        if ! check_command tfsec; then
            if [[ $DRY_RUN -eq 1 ]]; then
                echo "[DRY-RUN] curl -s -L https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64 -o /tmp/tfsec"
                echo "[DRY-RUN] chmod +x /tmp/tfsec"
                echo "[DRY-RUN] sudo mv /tmp/tfsec /usr/local/bin/tfsec"
            else
                curl -s -L https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64 -o /tmp/tfsec
                chmod +x /tmp/tfsec
                sudo mv /tmp/tfsec /usr/local/bin/tfsec
            fi
        fi
    elif check_command yum; then
        sudo yum install -y ShellCheck curl git || true
        # Similar manual installs as above can be added
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
        windows)
            printf "\nWindows detected. Please install tools using winget/scoop or manual installers:\n"
            printf "- Install git, curl: winget install Git.Git; winget install GnuWin32.curl (or use Git Bash/WSL)\n"
            printf "- Install shellcheck: winget install koalaman.shellcheck\n"
            printf "- Install shfmt: scoop install shfmt (or download releases)\n"
            printf "- Install bun: powershell -c \"irm bun.sh/install.ps1 | iex\"\n"
            printf "- Install uv: https://github.com/astral-sh/uv#installation\n"
            printf "- Install gitleaks: winget install zricethezav.gitleaks\n"
            printf "- Install semgrep: winget install Semgrep.Semgrep\n"
            printf "- Install .NET SDK: winget install Microsoft.DotNet.SDK.8\n"
            printf "- Install Java (Temurin): winget install EclipseAdoptium.Temurin.21.JDK\n"
            printf "\nThen rerun this installer to re-check status.\n"
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
