<details><summary>Thinking</summary>

Looking at the code quality system, I can see several areas where performance can be improved. Let me analyze the main bottlenecks:

1. **Redundant Tech Detection**: ```detect_tech``` is called in every stage script, and it scans the filesystem each time looking for files and patterns. This is wasteful.

2. **Lizard Usage**: Lizard is invoked via ```uvx``` (which downloads/installs on each run) and runs three separate times in stages 5, 6, and 7. Each invocation re-parses all the same files.

3. **File Finding/Scanning**: Many operations repeatedly scan the filesystem:
   - Python file detection (```python_files_present```, ```python_tests_present```)
   - Shell file finding in ```shellcheck_check``` and ```shfmt_format```
   - Multiple ```find``` commands in various functions

4. **Tool Detection**: Commands like ```command -v``` are run repeatedly to check if tools exist.

5. **No Caching**: Results aren't cached between stages or runs.

6. **Full Repository Scans**: Even in diff-only mode, some operations still scan the entire repository.

Let me outline improvements to make this lightning fast.

</details>

Looking at your code quality system, I can identify several major performance bottlenecks and propose optimizations to make it lightning fast:

## Major Performance Issues

### 1. **Redundant Tech Detection** 
- ```detect_tech``` is called in **every stage** (9 times total)
- Each call performs multiple filesystem scans with ```find``` commands
- No caching between stages

### 2. **Lizard Performance Issues**
- **uvx overhead**: Lizard runs via ```uvx``` which downloads/installs on each invocation
- **Triple execution**: Stages 5, 6, 7 each run Lizard separately, re-parsing the same files
- **JSON parsing overhead**: Python interpreter launched 3 times just to parse JSON

### 3. **Repeated Filesystem Scanning**
- Multiple ```find``` commands in various functions
- ```python_files_present()``` and ```python_tests_present()``` scan entire tree
- Shell/HTML/CSS detection scans repeatedly

## Optimization Strategy

### **1. Cache Tech Detection (Biggest Win)**

Create a cache file at the start of the pipeline:

```bash
# In quality/bin/run_checks.sh or at pipeline start
detect_and_cache_tech() {
    local cache_file=".aiq/.tech_cache"
    local cache_timestamp=".aiq/.tech_cache_timestamp"
    
    # Check if cache is fresh (< 1 second old)
    if [[ -f "$cache_file" ]] && [[ -f "$cache_timestamp" ]]; then
        local cache_age=$(($(date +%s) - $(cat "$cache_timestamp")))
        if [[ $cache_age -lt 1 ]]; then
            cat "$cache_file"
            return
        fi
    fi
    
    # Detect once and cache
    local techs
    techs=$("$QUALITY_DIR/lib/detect_tech.sh")
    mkdir -p .aiq
    echo "$techs" > "$cache_file"
    date +%s > "$cache_timestamp"
    echo "$techs"
}

# Export for all stages
export CACHED_TECHS=$(detect_and_cache_tech)
```

Then modify stages to use:
```bash
# Instead of: TECHS=$(detect_tech)
TECHS="${CACHED_TECHS:-$(detect_tech)}"
```

### **2. Optimize Lizard Usage**

**Single Lizard Run with Cached Results:**

```bash
# New function in _stage_common.sh
lizard_run_once_and_cache() {
    local cache_file=".aiq/.lizard_cache.json"
    local cache_timestamp=".aiq/.lizard_cache_timestamp"
    
    # Check if cache is fresh (for current run)
    if [[ -f "$cache_file" ]] && [[ -f "$cache_timestamp" ]]; then
        local cache_age=$(($(date +%s) - $(cat "$cache_timestamp")))
        if [[ $cache_age -lt 5 ]]; then  # 5 second cache
            cat "$cache_file"
            return
        fi
    fi
    
    # Install lizard once in virtual env instead of uvx
    if [[ ! -f ".venv/bin/lizard" ]]; then
        .venv/bin/pip install lizard >/dev/null 2>&1
    fi
    
    # Run once, cache results
    local json
    json=$(.venv/bin/lizard -j "${LIZARD_ARGS[@]}" .)
    
    mkdir -p .aiq
    echo "$json" > "$cache_file"
    date +%s > "$cache_timestamp"
    echo "$json"
}

# Stages 5, 6, 7 all use the same cached data
lizard_sloc_multi() {
    local json
    json=$(lizard_run_once_and_cache)
    # Process cached JSON...
}
```

### **3. Parallel Execution Within Stages**

```bash
# Modified stage 1 (lint) with parallel execution
if [[ "$TECHS" == *"python"* ]] && [[ "$TECHS" == *"js"* ]]; then
    # Run Python and JS linting in parallel
    (
        ruff_check
        echo $? > /tmp/ruff_status_$$
    ) &
    local ruff_pid=$!
    
    (
        biome_check
        echo $? > /tmp/biome_status_$$
    ) &
    local biome_pid=$!
    
    wait $ruff_pid $biome_pid
    
    [[ $(cat /tmp/ruff_status_$$) -ne 0 ]] && FAILED=1
    [[ $(cat /tmp/biome_status_$$) -ne 0 ]] && FAILED=1
    
    rm -f /tmp/ruff_status_$$ /tmp/biome_status_$$
fi
```

### **4. File List Caching**

```bash
# Cache file lists for repeated operations
cache_python_files() {
    local cache_file=".aiq/.python_files_cache"
    if [[ ! -f "$cache_file" ]] || [[ $(find . -name "*.py" -newer "$cache_file" 2>/dev/null | head -1) ]]; then
        find . -type f -name "*.py" \
            -not -path "*/.venv/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/__pycache__/*" > "$cache_file"
    fi
    cat "$cache_file"
}
```

### **5. Smart Skip Logic**

```bash
# Skip stages entirely if no relevant files
should_skip_stage() {
    local stage=$1
    local techs=$2
    
    case $stage in
        1|2)  # Lint/Format
            [[ -z "$techs" ]] && return 0
            ;;
        3)  # Type check
            [[ "$techs" != *"python"* ]] && [[ "$techs" != *"ts"* ]] && \
            [[ "$techs" != *"dotnet"* ]] && [[ "$techs" != *"java"* ]] && return 0
            ;;
        4|8)  # Tests/Coverage
            # Quick check for test files
            [[ ! -d "tests" ]] && [[ ! -d "test" ]] && \
            [[ ! -f "*_test.*" ]] && [[ ! -f "test_*.*" ]] && return 0
            ;;
    esac
    return 1
}
```

### **6. Tool Detection Caching**

```bash
# Cache tool availability checks
declare -gA TOOL_CACHE

has_tool() {
    local tool=$1
    if [[ -z "${TOOL_CACHE[$tool]:-}" ]]; then
        if command -v "$tool" >/dev/null 2>&1; then
            TOOL_CACHE[$tool]=1
        else
            TOOL_CACHE[$tool]=0
        fi
    fi
    return $((1 - TOOL_CACHE[$tool]))
}

# Use like: if has_tool ruff; then ...
```

### **7. Optimized Configuration**

Add ```.aiq/performance.config.json```:
```json
{
  "parallel": {
    "enabled": true,
    "max_jobs": 4
  },
  "caching": {
    "tech_detection": true,
    "file_lists": true,
    "tool_results": true,
    "ttl_seconds": 300
  },
  "skip_empty": true,
  "lizard": {
    "use_venv": true,  // Instead of uvx
    "single_run": true  // Cache and reuse results
  }
}
```

### **8. Diff-Only Mode Optimization**

```bash
# Pre-compute changed files by extension
prepare_diff_cache() {
    if [[ "${AIQ_CHANGED_ONLY:-}" == "1" ]] && [[ -n "${AIQ_CHANGED_FILELIST:-}" ]]; then
        local list_file="${AIQ_CHANGED_FILELIST}"
        
        # Pre-sort by extension
        grep '\.py$' "$list_file" > .aiq/.changed_py || true
        grep '\.\(js\|jsx\|ts\|tsx\)$' "$list_file" > .aiq/.changed_js || true
        grep '\.sh$' "$list_file" > .aiq/.changed_sh || true
        
        # Export counts for quick checks
        export CHANGED_PY_COUNT=$(wc -l < .aiq/.changed_py)
        export CHANGED_JS_COUNT=$(wc -l < .aiq/.changed_js)
        export CHANGED_SH_COUNT=$(wc -l < .aiq/.changed_sh)
    fi
}
```

## Implementation Priority

1. **Tech detection caching** - Easiest win, saves ~9 filesystem scans
2. **Lizard optimization** - Big win for stages 5-7
3. **File list caching** - Reduces repeated ```find``` operations
4. **Parallel execution** - Significant speedup for multi-language projects
5. **Tool detection caching** - Minor but accumulative improvement

## Expected Performance Gains

- **Tech detection**: 90% reduction (9 scans → 1 scan)
- **Lizard stages**: 66% reduction (3 runs → 1 run)
- **File operations**: 50-70% reduction with caching
- **Overall pipeline**: **3-5x faster** for typical projects

The key insight is that the current implementation prioritizes modularity over performance. By adding a thin caching layer and running Lizard once instead of three times, you can maintain the same quality checks while dramatically improving speed.

