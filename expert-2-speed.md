Here’s a tight, practical plan to make your pipeline feel instant—without losing any guardrails.

# TL;DR: Speed Principles

1. **Run only what matters** (strict tech & file detection, diff-only by default locally).
2. **Run it once** (cache and reuse expensive scans—especially Lizard & Radon).
3. **Run in parallel** (within a stage, per-language tools can run concurrently).
4. **Lighten CI installs** (only install what you actually use).

---

## 1) Tighten detection so nothing “extra” runs

* **Gate security IaC scans by tech detection.** In `quality/stages/9-security.sh`, `hcl_security_check` runs unconditionally today. Change it to only run when HCL/Terraform is detected—same pattern you already use in Stages 1–2.

  ```bash
  # 9-security.sh
  TECHS=$(detect_tech)
  ...
  if [[ "$TECHS" == *"hcl"* ]]; then
    if ! hcl_security_check; then
      error "Terraform security (tfsec) failed"
      FAILED=1
    fi
  fi
  ```

* **“Presence” checks for every tool.** You already do this for Python (e.g., `python_files_present`). Mirror for JS/TS, Java, .NET, HCL to skip type/test/format steps when no files exist:

  * Add helpers like `js_files_present`, `ts_files_present`, `dotnet_files_present` (look for `*.csproj` or `*.sln`), `java_files_present` (use `git ls-files` or `find`), `hcl_files_present` etc., and short-circuit early.

* **Use `git ls-files` where possible.** It’s faster and respects the repo (no vendor/ignored surprises). Example: replace `find . -name "*.java"` with `git ls-files "**/*.java"`; same for `*.tf`, `*.cs`, `*.html`, `*.css`.

---

## 2) Diff-only by default (local) + smarter file scoping

You’ve wired diff-only env (`AIQ_CHANGED_ONLY`, `AIQ_CHANGED_FILELIST`) but Python/Radon doesn’t leverage it yet.

* **Make Radon respect diff-only (Stages 5/6/7).**
  Use your existing `_changed_files_by_ext` helper:

  ```bash
  # _stage_common.sh (examples)

  radon_sloc() {
    local files
    files=$(_changed_files_by_ext '\.py$') || files=""
    if [[ -n "$files" ]]; then
      echo "$files" | xargs -r radon raw
      return $?
    fi
    # fallback: current full-scan code...
  }

  radon_complexity() {
    local files
    files=$(_changed_files_by_ext '\.py$') || files=""
    if [[ -n "$files" ]]; then
      echo "$files" | xargs -r radon cc -s -na
      return $?
    fi
    # fallback...
  }

  radon_maintainability() {
    local files
    files=$(_changed_files_by_ext '\.py$') || files=""
    if [[ -n "$files" ]]; then
      echo "$files" | xargs -r radon mi -s
      return $?
    fi
    # fallback...
  }
  ```

* **Make the pre-commit hook supply changed files.**
  Limit local runs to staged changes:

  ```bash
  # quality/hooks/pre-commit
  CHANGED_FILELIST="$(mktemp)"
  git diff --cached --name-only --diff-filter=ACMRT > "$CHANGED_FILELIST"
  export AIQ_CHANGED_ONLY=1
  export AIQ_CHANGED_FILELIST="$CHANGED_FILELIST"
  exec "$QUALITY_DIR/bin/run_checks.sh"
  ```

* **Security (fast mode).** For local hooks, consider limiting `gitleaks`/`semgrep` to changed files (still high signal, huge speedup). If you want to keep CI full-scan: make it conditional on `AIQ_CHANGED_ONLY`.

---

## 3) Lizard: the big win = **scan once, reuse everywhere**

Right now Lizard runs **three** full scans (SLOC, CCN, maintainability proxy). Avoid the triple walk:

* **Add a tiny JSON cache between stages.**

  ```bash
  # _stage_common.sh
  _lizard_run_json_cached() {
    local techs="$1"
    local cache="${AIQ_LIZARD_JSON:-.aiq/lizard.json}"
    if [[ -f "$cache" ]]; then
      cat "$cache"
      return 0
    fi
    local json
    json=$(_lizard_run_json "$techs") || return 1
    mkdir -p "$(dirname "$cache")"
    printf '%s' "$json" > "$cache"
    echo "$json"
  }

  # then in lizard_* functions replace:
  #   json=$(_lizard_run_json "$techs")
  # with:
  #   json=$(_lizard_run_json_cached "$techs")
  ```

* **Prefer a locally installed lizard over `uvx`.**
  `uvx` is great, but its cold-start resolve can be the bottleneck. Add to `quality/requirements.txt`:

  ```
  lizard>=1.17.10
  ```

  Then use:

  ```bash
  _lizard_uvx() {
    if command -v lizard >/dev/null 2>&1; then
      lizard "$@"
    elif [[ -x ".venv/bin/lizard" ]]; then
      .venv/bin/lizard "$@"
    elif command -v uvx >/dev/null 2>&1; then
      uvx lizard "$@"
    else
      echo "Lizard not available (install via pip/uv)."; return 127
    fi
  }
  ```

* **Scope inputs aggressively.**
  You already:

  * map languages from detected techs,
  * exclude vendor dirs,
  * honor diff-only by passing changed files.

  Keep that, and **don’t** pass `.` when you have a changed-file list—only give Lizard the files you need.

> Net effect: 1 Lizard pass per run instead of 3, and often **only** on changed files. This is usually the single largest speedup in mixed-lang repos.

---

## 4) Parallelize within stages (safe & easy wins)

Run independent checks concurrently and aggregate exit codes.

Example for **Stage 1 (lint)**:

```bash
# 1-lint.sh (sketch)
pids=()
fail=0

if [[ "$TECHS" == *"python"* ]]; then ruff_check || fail=1 & pids+=($!); fi
if [[ "$TECHS" == *"js"* || "$TECHS" == *"ts"* || "$TECHS" == *"react"* ]]; then biome_check || fail=1 & pids+=($!); fi
if [[ "$TECHS" == *"shell"* ]]; then shellcheck_check || fail=1 & pids+=($!); fi
if [[ "$TECHS" == *"html"* ]]; then htmlhint_check || fail=1 & pids+=($!); fi
if [[ "$TECHS" == *"css"* ]]; then stylelint_check || fail=1 & pids+=($!); fi
if [[ "$TECHS" == *"java"* ]]; then java_checkstyle || fail=1 & pids+=($!); fi
if [[ "$TECHS" == *"hcl"* ]]; then hcl_lint_check || fail=1 & pids+=($!); fi

for pid in "${pids[@]}"; do wait "$pid" || fail=1; done
exit $fail
```

Do similar for Stage 2 (format checks) and Stage 4 (unit tests across languages).

---

## 5) Faster tool invocations & caches

* **Prefer `bunx` over `npx`** (you already do; keep it). Ensure bun is available in CI to avoid npm’s global installs.
* **Type tooling:**

  * **TypeScript**: enable incremental build (`"incremental": true`) and prefer `tsc --build --incremental` locally. In CI, you can keep `--noEmit`, but locally the `.tsbuildinfo` cache cuts re-check time dramatically.
  * **.NET**: `dotnet build --no-restore -warnaserror -maxcpucount` after a separate cached `dotnet restore`. Cache `~/.nuget/packages`.
  * **Java**: cache Maven/Gradle (`~/.m2/repository`, `~/.gradle/caches`).
  * **mypy**: consider `dmypy` for local runs (daemonized), keep plain `mypy` in CI.
* **Tests:**

  * **pytest**: optional `pytest-xdist -n auto` for parallel; consider `pytest-testmon` locally for impacted tests only.
  * **vitest**: it’s already fast; keep `vitest run` (you can tune pool via `--pool=threads` if needed).
* **Security (CI vs local):**

  * `semgrep`: use `--timeout 120 --max-target-bytes 100MB` in CI; use a “changed-only” mode locally (pre-filter via `AIQ_CHANGED_FILELIST`).
  * `gitleaks`: local fast path = only staged files; CI = full repo.

---

## 6) CI cleanup (cuts minutes)

Your workflow installs tools you don’t actually use at runtime:

* **Drop global ESLint/Jest** (you’re using Biome & Vitest). Keep only what’s needed: shellcheck, shfmt, Python deps, and bun (or node) for `bunx`/`npx` runners, plus any security tools you actually call.
* **Add caches.**

  * `actions/cache` for:

    * Python: `~/.cache/pip` and (if you adopt `uv`) `~/.cache/uv`.
    * Node: npm/bun cache.
    * dotnet: `~/.nuget/packages`.
    * Maven/Gradle caches if applicable.
* **Optional “fail fast” on PRs** (surface first error quickly), keep “full picture” on merges to main. Implement via env:

  * `AIQ_FAIL_FAST=1` → your `run_checks.sh` breaks on first failing stage locally/PR.

---

## 7) Small but impactful code tweaks

* **One-shot Radon (optional advanced).** You already have a custom Python `radon_readability` runner. You could extend that script to compute **MI + CC + raw** in one pass and emit a JSON file under `.aiq/radon.json`, then let Stages 5/6/7 read from it (same idea as the Lizard cache). This removes 3 file-tree walks in Python projects.
* **Ripgrep/Fd for discovery (if present).** Prefer `rg --files`/`fd` over `find` when available; fall back to `find`. This speeds file listing on large repos.

---

## 8) “Fast mode” knobs (developer happiness)

* **Local default**: fast path on changed files.

  * Pre-commit sets `AIQ_CHANGED_ONLY=1`.
  * Add `AIQ_FAST=1` to also skip E2E & coverage locally.
* **CI default**: full scans on main; on PR use diff-only for the “expensive” stages (1/2/5/6/7), full for 0/3/4/8/9.

---

## 9) Is Lizard the bottleneck?

Often, yes—**when** it scans the whole repo more than once or resolves via `uvx` each time.

* Biggest wins (in order):

  1. **Single pass + JSON cache** across stages.
  2. **Diff-only inputs** for PR/local runs.
  3. **Local binary/venv** (avoid repeated `uvx` cold starts).
  4. **Tighter language mapping** (don’t enable `-l` for langs not present).

Do those, and Lizard becomes a negligible part of your runtime.

---

## Bonus: two tiny fixes you’ll thank yourself for

* In `install.sh`, the line that writes `.aiq/progress.json` contains a stray control char:
  `printf '%s\n' '{"current_stage":0,...}' e .aiq/progress.json`
  → should be:

  ```bash
  printf '%s\n' '{"current_stage":0,"disabled":[],"order":[0,1,2,3,4,5,6,7,8,9]}' > .aiq/progress.json
  ```
* Align docs/CI to Biome/Vitest (since ESLint/Jest are no longer used).

---

### Expected impact (realistic ballpark)

* **Pre-commit (diff-only)**: seconds, not minutes.
* **CI on PRs**: typically **30–70% faster**, depending on repo size, once Lizard/Radon stop rescanning multiple times and global npm installs are removed.
* **Full CI (main)**: still faster via parallel stage work + lean installs + caches.

If you want, I can draft the exact diffs for:

* `9-security.sh` gating,
* Radon diff-only support,
* Lizard JSON cache,
* Pre-commit changed-file wiring,
* CI workflow slimming & caches.
