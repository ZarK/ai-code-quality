### Optimizing the Code Quality System for Speed Without Compromising Quality

Your code quality system is already well-structured: it's technology-aware (via `detect_tech.sh`), modular (stages run conditionally based on detected techs), and partially incremental (with support for diff-only mode via `AIQ_CHANGED_ONLY` and `_changed_files_by_ext`). This means it inherently avoids running checks for undetected technologies (e.g., no Python checks if no `pyproject.toml` or similar files are found), which is a good foundation for efficiency. However, some stages can still be slow on large codebases due to tool invocations, full-repo scans, and isolated environment overhead (e.g., `uvx` for Lizard).

Below, I'll outline potential bottlenecks, then propose optimizations to make the system "lightning fast" (aiming for sub-second to a few seconds per stage on medium-sized repos, assuming incremental mode). Importantly, these suggestions **do not compromise quality**—they focus on caching, incremental execution, parallelization, and tool optimizations while preserving thoroughness, accuracy, and coverage. If a suggestion risks quality (e.g., approximating metrics), I'll flag it as a trade-off and explain why it's avoidable.

#### 1. **Current Bottlenecks Analysis**
   - **Tech Detection Overhead**: Minimal—`detect_tech.sh` uses fast file existence checks (`-f`) and `find` with limited depth (`-maxdepth 3`). No slowdown here.
   - **Irrelevant Checks**: Already avoided via conditional execution based on `$TECHS` (e.g., no `ruff_check` if no Python detected). This is efficient and doesn't need changes.
   - **Full-Repo Scans**: Stages like 5 (SLOC), 6 (Complexity), and 7 (Maintainability) scan the entire codebase by default, which scales poorly on large repos (e.g., 10k+ files).
   - **Tool Invocation Overhead**:
     - Python tools (Ruff, mypy, pytest, Radon): Fast once installed; Ruff is especially quick (~ms per file).
     - JS/TS tools (Biome, tsc, Vitest): Biome is fast; tsc can be slow on large TS projects but is incremental via `--incremental`.
     - Shell/HTML/CSS: `shellcheck`, `shfmt`, `htmlhint`, `stylelint` are file-based and quick.
     - .NET/Java/HCL: Build/test tools (dotnet, Maven/Gradle, tflint) can be slow if rebuilding everything; they often support incremental modes.
     - Security (Stage 9): `gitleaks` and `semgrep` scan the repo/history; can be slow but support incremental options.
   - **Lizard-Specific Slowdowns** (Major Contributor):
     - Used in Stages 5-7 for non-Python langs (.NET, Java, JS/TS, Go).
     - Invoked via `uvx lizard` (isolated env), which may download/install Lizard each run if uv's cache misses (though uv caches venvs, first-run overhead is ~5-10s).
     - Runs `lizard -j` (JSON output) on the full repo (or changed files in diff-only), parsing JSON with Python/awk. On large repos, parsing/metrics computation can take seconds to minutes.
     - Multi-invocation: Called separately per stage (3x if multiple non-Py langs), re-scanning the codebase each time—redundant work.
     - Why it's a major slowdown: Lizard parses ASTs for multiple languages, which is CPU-intensive. On a 100k LOC repo with JS/TS/Java, a single run might take 5-30s; multiplied by stages, it adds up. Diff-only helps but isn't always enabled.
   - **E2E/Unit/Coverage (Stages 0,4,8)**: Test runs can be slow but are necessary for quality; optimization focuses on incremental testing.
   - **Overall**: On a medium repo (5k files), full run might take 30-60s; Lizard could account for 20-40% if non-Py langs are present.

The system **can be made lightning fast without compromising quality** by emphasizing incremental execution, caching, single-pass analysis, and parallelization. Quality is preserved because we don't skip checks or reduce thoroughness—we just avoid redundant work.

#### 2. **General Optimizations (Applicable to All Stages)**
   These build on your existing diff-only support and tech detection.

   - **Enable Incremental Mode by Default (Diff-Only Where Safe)**:
     - **How**: Make `AIQ_CHANGED_ONLY=1` the default (via env or CLI flag in `check.sh`). Use Git to detect changed files (e.g., `git diff --name-only HEAD` or against a base branch in CI/PRs).
     - **Impact**: Limits scans to changed files in Stages 1 (Lint), 2 (Format), 5 (SLOC), 6 (Complexity), 7 (Maintainability). Full runs for Stages 0 (E2E), 3 (Type Check), 4 (Unit), 8 (Coverage), 9 (Security) to ensure no regressions.
     - **Speed Gain**: 5-10x on large repos (e.g., check 10 files vs. 10k).
     - **No Quality Compromise**: Changed files get full checks; unchanged code is assumed passing from prior runs (enforced by CI gates).
     - **Implementation**:
       - Expand `_changed_files_by_ext` to more extensions (e.g., '\.cs$' for .NET, '\.java$' for Java).
       - In CI (e.g., GitHub Actions), fetch base branch and compute diff: `git fetch origin $BASE_BRANCH && git diff --name-only origin/$BASE_BRANCH`.

   - **Caching Tool Results**:
     - **How**: Use a cache directory (e.g., `.aiq/cache/`) with hash-based keys (file content + tool version). Store JSON outputs (e.g., Lizard/Radon) and reuse if unchanged.
     - **Impact**: Skip re-running tools if inputs match (e.g., cache mypy results per file).
     - **Speed Gain**: Near-instant for unchanged files.
     - **No Quality Compromise**: Invalidate cache on file changes or tool updates.
     - **Tools Supporting This**: Ruff/mypy (incremental via cache files), tsc (`--incremental`), Lizard (cache JSON output).

   - **Parallelization**:
     - **How**: Run independent checks within a stage in parallel (e.g., using `xargs -P` or `parallel` tool). For example, in Stage 1, parallelize Ruff, Biome, shellcheck if multiple techs detected.
     - **Impact**: Stages with multiple techs (e.g., Python + JS + Shell) run concurrently.
     - **Speed Gain**: 2-3x on multi-core machines.
     - **No Quality Compromise**: Results are aggregated; failures still halt.
     - **Implementation**: Wrap tool calls in a function that spawns background jobs and waits with `wait`.

   - **Pre-Install Tools in CI/Setup**:
     - **How**: In `install.sh` or CI workflow, install all possible tools upfront (e.g., `uv tool install lizard`, `npm i -g biome`). Avoid per-run `uvx`/`npx`/`bunx`.
     - **Impact**: Eliminates resolution/install overhead.
     - **Speed Gain**: 5-10s saved per run.
     - **No Quality Compromise**: Tools run identically.

   - **Verbose/Quiet Modes for Faster Output**:
     - Already supported; ensure `--quiet` suppresses all non-error output to reduce I/O overhead.

#### 3. **Lizard-Specific Optimizations (Addressing the Major Slowdown)**
Lizard is indeed a potential bottleneck due to its parsing overhead and multi-invocation. However, we can optimize without replacing it or reducing quality.

   - **Single-Pass Execution**:
     - **How**: Run `lizard -j` once at the start of the run (if non-Py langs detected), cache the JSON in a temp file, and parse it in Stages 5-7. Delete after.
     - **Impact**: Avoids 3x invocations; parses the same JSON multiple ways.
     - **Speed Gain**: 3x for Lizard-heavy runs (e.g., 10s → 3s).
     - **No Quality Compromise**: Exact same metrics.
     - **Implementation**: In `check.sh`, add:
       ```shell
       if [[ "$TECHS" =~ (dotnet|java|js|ts|react|go) ]]; then
         LIZARD_JSON=$(_lizard_run_json "$TECHS" > /tmp/lizard.json)
       fi
       ```
       Then in lizard_*_multi functions, read from `/tmp/lizard.json` instead of re-running.

   - **Switch to Faster Invocation**:
     - **How**: Install Lizard globally/permanently (via `pip install lizard` in `install.sh`) and call directly instead of `uvx`. Fall back to uvx if not installed.
     - **Impact**: Bypasses uv's isolation overhead.
     - **Speed Gain**: 2-5s per invocation.
     - **No Quality Compromise**: Same tool.

   - **Incremental Lizard via Diff-Only**:
     - **How**: Always pass changed files (extend your existing diff-only support). Lizard ignores non-source files, so it's safe.
     - **Impact**: Scans only deltas.
     - **Speed Gain**: Massive (e.g., 30s → 1s for small changes).
     - **No Quality Compromise**: Full metrics on changes; assumes prior code passed (CI enforces).

   - **Alternative Tools if Lizard Remains Slow**:
     - **Without Compromise**: Use language-specific faster tools (e.g., `eslint-plugin-complexity` for JS/TS, `pmd` for Java). Detect tech and switch.
       - Speed Gain: 2-5x (these are optimized per lang).
       - But: Increases complexity; Lizard's multi-lang is a strength—only switch if benchmarks show >20% slowdown.
     - **With Minor Trade-Off (Avoid if Possible)**: Approximate SLOC with `tokei` (Rust-based, blazing fast) for Stage 5. For complexity/maintainability, sample functions instead of full scan—but this risks missing issues, compromising quality.

   - **Benchmark and Profile**: Add timing to `_lizard_run_json` (e.g., `time lizard ...`) and log in verbose mode. If parsing is the bottleneck, optimize Python/awk scripts (e.g., use `jq` for JSON).

#### 4. **Implementation Roadmap**
   - **Short-Term (1-2 days)**: Enable diff-only by default, single-pass Lizard, pre-install tools.
   - **Medium-Term (3-5 days)**: Add result caching, parallelization.
   - **Testing**: Benchmark on sample repos (e.g., your examples/ if added). Aim for <10s full run on 5k LOC repo.
   - **CI Integration**: Update `.github/workflows/quality.yml` to compute diffs and warm caches.

With these changes, the system can be 5-10x faster while maintaining full quality. If Lizard still bottlenecks after single-pass/incremental, consider per-lang alternatives—but your current setup is solid and optimizable as-is. If you provide benchmarks or a sample repo, I can refine further!