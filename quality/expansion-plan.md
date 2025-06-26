<details><summary>Thinking</summary>

The user wants me to create a developer project plan to expand and modify their existing code quality system with the modern, lean tools I suggested. Let me first look at the current implementation to understand what needs to be changed.

Let me examine the key files to understand the current structure:

1. First, let me look at the main entry point and installation files
2. Then examine the technology detection
3. Look at how stages are currently implemented
4. Understand the tool installation process

This will help me create a comprehensive project plan that builds on their existing architecture.

</details>

I'll analyze the current implementation and create a comprehensive project plan. Let me first examine the key files to understand the current structure.

<contemplator>
I need to understand the current implementation before creating a project plan. Let me look at the main files to see how the system is structured.

First, let me check the main entry point to understand the overall flow.

Then I'll look at the technology detection to see how it currently works.

After that, I'll examine the installation process to understand how tools are currently managed.

Finally, I'll look at a few stage implementations to see the current patterns.
</contemplator>

Let me examine the current implementation to create an informed project plan:

```python
# First, let's look at the main check.sh file
with open('check.sh', 'r') as f:
    check_content = f.read()
    print("=== check.sh structure ===")
    print(check_content[:1000])  # First 1000 chars to understand structure
```

```python
# Now let's examine the technology detection
with open('detect_tech.sh', 'r') as f:
    detect_content = f.read()
    print("\n=== Current technology detection ===")
    print(detect_content)
```

```python
# Let's look at the install process
with open('install.sh', 'r') as f:
    install_content = f.read()
    print("\n=== Installation script structure ===")
    print(install_content[:1000])
```

```python
# Check current tool installation
with open('install_tools.sh', 'r') as f:
    tools_content = f.read()
    print("\n=== Current tools being installed ===")
    print(tools_content[:1500])
```

```python
# Let's examine a couple of stage implementations
with open('1-lint.sh', 'r') as f:
    lint_content = f.read()
    print("\n=== Current lint stage ===")
    print(lint_content)
```

```python
# And the complexity stage since we're replacing radon with lizard
with open('6-complexity.sh', 'r') as f:
    complexity_content = f.read()
    print("\n=== Current complexity stage ===")
    print(complexity_content)
```

Now, based on my analysis, here's a comprehensive developer project plan:

# Developer Project Plan: Universal Code Quality System Expansion

## Executive Summary
Expand the Universal Code Quality System to support additional technologies (Java, .NET, Kubernetes, Docker, SQL, Go, Rust) while modernizing the toolchain to use fewer, more efficient multi-language tools.

## Project Goals
1. **Minimize tool footprint** - Replace multiple single-purpose tools with modern multi-language alternatives
2. **Maintain backward compatibility** - Ensure existing Python/JS/TS/HTML/CSS projects continue working
3. **Improve performance** - Use Rust-based tools where possible for speed improvements
4. **Add modular installation** - Only install tools needed for detected languages

## Phase 1: Core Infrastructure Updates (Week 1)

### 1.1 Enhanced Technology Detection
**File:** ```quality/lib/detect_tech.sh```

```bash
# Expand detection patterns
declare -A LANG_PATTERNS=(
    # Existing
    ["python"]="*.py,requirements.txt,setup.py,pyproject.toml,Pipfile"
    ["javascript"]="*.js,*.mjs,*.cjs"
    ["typescript"]="*.ts,*.tsx,tsconfig.json"
    ["react"]="package.json:react"
    ["html"]="*.html,*.htm"
    ["css"]="*.css,*.scss,*.sass,*.less"
    
    # New additions
    ["java"]="*.java,pom.xml,build.gradle,build.gradle.kts"
    ["dotnet"]="*.cs,*.fs,*.vb,*.csproj,*.fsproj,*.vbproj,*.sln"
    ["go"]="*.go,go.mod,go.sum"
    ["rust"]="*.rs,Cargo.toml,Cargo.lock"
    ["sql"]="*.sql,*.psql,*.mysql,*.tsql"
    ["docker"]="Dockerfile,Dockerfile.*,docker-compose.yml,docker-compose.yaml"
    ["kubernetes"]="*.k8s.yml,*.k8s.yaml,*-deployment.yaml,*-service.yaml,*-configmap.yaml"
    ["terraform"]="*.tf,*.tfvars,terraform.tfstate"
    ["tailwind"]="tailwind.config.js,tailwind.config.ts"
)
```

### 1.2 Modular Tool Management
**New File:** ```quality/lib/tool_manager.sh```

```bash
#!/bin/bash

# Tool definitions with metadata
declare -A TOOLS=(
    ["biome"]="rust|npm|lint,format|js,ts,jsx,tsx,json,css"
    ["ruff"]="python|pip|lint,format|python"
    ["lizard"]="python|pip|complexity,maintainability|multi"
    ["scc"]="go|binary|sloc|multi"
    ["prettier"]="node|npm|format|html,md,yaml,yml"
    ["sqlfluff"]="python|pip|lint,format|sql"
    ["trivy"]="go|binary|security|docker,k8s"
    ["kubeconform"]="go|binary|validate|k8s"
    ["hadolint"]="haskell|binary|lint|docker"
    ["semgrep"]="python|pip|lint,security|multi"
)

# Get required tools for detected languages
get_required_tools() {
    local detected_langs=("$@")
    local required_tools=()
    
    # Always include multi-language tools
    required_tools+=("scc" "lizard")
    
    # Add language-specific tools
    for lang in "${detected_langs[@]}"; do
        case "$lang" in
            javascript|typescript|react|css)
                required_tools+=("biome" "prettier")
                ;;
            python)
                required_tools+=("ruff")
                ;;
            java)
                required_tools+=("google-java-format" "checkstyle")
                ;;
            dotnet)
                # Built-in tools, no additional needed
                ;;
            go)
                # gofmt is built-in
                ;;
            rust)
                # rustfmt and clippy are built-in
                ;;
            sql)
                required_tools+=("sqlfluff")
                ;;
            docker)
                required_tools+=("hadolint" "trivy")
                ;;
            kubernetes)
                required_tools+=("kubeconform" "trivy")
                ;;
        esac
    done
    
    # Remove duplicates
    printf '%s\n' "${required_tools[@]}" | sort -u
}
```

## Phase 2: Tool Migration (Week 2)

### 2.1 Replace Existing Tools

| Current Tool | Replacement | Benefits |
|--------------|-------------|----------|
| ESLint + Prettier (JS) | Biome | 10-20x faster, single config |
| Ruff (keep) | Ruff | Already optimal |
| HTMLHint | Biome (for HTML in JSX) + Prettier | Fewer tools |
| cloc | scc | 10x faster, more features |
| Radon | lizard | Multi-language support |

### 2.2 Update Installation Script
**File:** ```quality/lib/install_tools.sh```

```bash
install_biome() {
    echo "Installing Biome..."
    local version="1.5.3"  # Pin version for stability
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    if [[ "$arch" == "x86_64" ]]; then
        arch="x64"
    fi
    
    local url="https://github.com/biomejs/biome/releases/download/v${version}/biome-${os}-${arch}"
    curl -L "$url" -o "$QUALITY_DIR/bin/biome"
    chmod +x "$QUALITY_DIR/bin/biome"
}

install_lizard() {
    echo "Installing lizard..."
    pip install --target="$QUALITY_DIR/lib/python" lizard
}

install_scc() {
    echo "Installing scc..."
    local version="3.1.0"
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    local url="https://github.com/boyter/scc/releases/download/v${version}/scc-${os}-${arch}"
    curl -L "$url" -o "$QUALITY_DIR/bin/scc"
    chmod +x "$QUALITY_DIR/bin/scc"
}
```

## Phase 3: Stage Updates (Week 3)

### 3.1 Update Lint Stage
**File:** ```quality/stages/1-lint.sh```

```bash
run_checks() {
    local any_failed=0
    
    # JavaScript/TypeScript/CSS - Use Biome
    if has_any_file "*.js" "*.ts" "*.jsx" "*.tsx" "*.mjs" "*.cjs" "*.json" "*.css"; then
        log_verbose "Running Biome linter..."
        if command -v "$QUALITY_DIR/bin/biome" >/dev/null 2>&1; then
            "$QUALITY_DIR/bin/biome" check . || any_failed=1
        else
            log_verbose "Biome not found, skipping JS/TS/CSS linting"
        fi
    fi
    
    # Python - Keep Ruff
    if has_any_file "*.py"; then
        log_verbose "Running Ruff linter..."
        run_python_tool "ruff" "check" "." || any_failed=1
    fi
    
    # SQL - Add SQLFluff
    if has_any_file "*.sql"; then
        log_verbose "Running SQLFluff linter..."
        run_python_tool "sqlfluff" "lint" "." || any_failed=1
    fi
    
    # Docker - Add Hadolint
    if has_any_file "Dockerfile" "Dockerfile.*"; then
        log_verbose "Running Hadolint..."
        find . -name "Dockerfile*" -exec "$QUALITY_DIR/bin/hadolint" {} \; || any_failed=1
    fi
    
    # Kubernetes - Add Kubeconform
    if has_any_file "*.yaml" "*.yml" | grep -E "(kind:|apiVersion:)"; then
        log_verbose "Running Kubeconform..."
        "$QUALITY_DIR/bin/kubeconform" -summary -output json . || any_failed=1
    fi
    
    return $any_failed
}
```

### 3.2 Update Complexity Stage
**File:** ```quality/stages/6-complexity.sh```

```bash
run_checks() {
    log_verbose "Running complexity analysis with lizard..."
    
    # Lizard automatically detects languages
    local lizard_args=(
        "-C" "10"  # Complexity threshold
        "-L" "100" # Length threshold
        "-a" "5"   # Argument threshold
        "--exclude" "*/node_modules/*"
        "--exclude" "*/.venv/*"
        "--exclude" "*/vendor/*"
        "--exclude" "*/target/*"  # Rust
        "--exclude" "*/bin/*"
        "--exclude" "*/obj/*"     # .NET
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        lizard_args+=("-V")
    fi
    
    run_python_tool "lizard" "${lizard_args[@]}" "."
}
```

### 3.3 Update SLOC Stage
**File:** ```quality/stages/5-sloc.sh```

```bash
run_checks() {
    log_verbose "Running SLOC analysis with scc..."
    
    local scc_args=(
        "--format" "wide"
        "--exclude-dir" ".git,node_modules,.venv,vendor,target,bin,obj"
        "--sort" "code"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        scc_args+=("--debug")
    fi
    
    "$QUALITY_DIR/bin/scc" "${scc_args[@]}" .
}
```

## Phase 4: Configuration Management (Week 4)

### 4.1 Unified Configuration Structure
```
quality/
├── configs/
│   ├── biome.json           # Biome config (JS/TS/CSS)
│   ├── ruff.toml           # Ruff config (Python)
│   ├── .sqlfluff           # SQLFluff config
│   ├── .hadolint.yaml      # Hadolint config
│   └── prettier.config.js   # Prettier for remaining formats
```

### 4.2 Biome Configuration
**File:** ```quality/configs/biome.json```

```json
{
  "$schema": "https://biomejs.dev/schemas/1.5.3/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "complexity": {
        "noBannedTypes": "error",
        "noExtraBooleanCast": "error",
        "noMultipleSpacesInRegularExpressionLiterals": "error"
      }
    }
  },
  "formatter": {
    "enabled": true,
    "formatWithErrors": false,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 80
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "single",
      "trailingComma": "es5"
    }
  }
}
```

## Phase 5: Testing & Documentation (Week 5)

### 5.1 Test Matrix

Create test projects for each supported technology:
```
tests/
├── python-project/
├── javascript-project/
├── typescript-react-project/
├── java-maven-project/
├── dotnet-project/
├── go-project/
├── rust-project/
├── sql-project/
├── docker-k8s-project/
└── mixed-tech-project/
```

### 5.2 Performance Benchmarks

Compare before/after metrics:
- Tool installation time
- Check execution time per stage
- Memory usage
- Disk space for tools

### 5.3 Updated Documentation

1. **README.md** - Update supported technologies
2. **TOOLS.md** - Document each tool and its purpose
3. **CONFIGURATION.md** - Explain configuration options
4. **MIGRATION.md** - Guide for migrating existing projects

## Implementation Timeline

| Week | Phase | Deliverables |
|------|-------|-------------|
| 1 | Infrastructure | Enhanced detection, modular tool management |
| 2 | Tool Migration | Install new tools, update installation scripts |
| 3 | Stage Updates | Modify all stages to use new tools |
| 4 | Configuration | Create unified config structure |
| 5 | Testing & Docs | Test suite, benchmarks, documentation |

## Success Metrics

1. **Tool Reduction**: From ~15 tools to ~7-10 tools
2. **Performance**: 2-5x faster execution for most stages
3. **Coverage**: Support for 10+ additional technologies
4. **Modularity**: Only required tools installed per project
5. **Compatibility**: All existing projects continue to work

## Risk Mitigation

1. **Backward Compatibility**: Keep fallbacks for old tools during transition
2. **Version Pinning**: Pin tool versions to avoid breaking changes
3. **Gradual Rollout**: Test on sample projects before full deployment
4. **Rollback Plan**: Keep old scripts in ```quality/legacy/``` during transition


