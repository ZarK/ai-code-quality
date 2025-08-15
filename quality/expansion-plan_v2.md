# Quality System Expansion Plan 🚀

## Overview

This document outlines the phased expansion of our standardized code‑quality system. We start with high‑impact, low‑risk improvements, then add high‑value language support and security scanning, and finally round out enterprise features.

---

## Phase 1 ✅ COMPLETED

*Implemented and merged*

| Key Win | Result |
|---------|--------|
| **scc Integration** | 10× faster SLOC analysis vs cloc |
| **Biome Enhancement** | 10‑20× faster JS/TS lint + format |
| **Expanded Tech Detection** | Docker/K8s foundation |
| **Docker / K8s Support** | Hadolint + kubeconform |

---

## Phase 2 🎯 IN FLIGHT

*Focus – High‑value languages & early security*   *Target — Next iteration cycle*

### 1. Rust Support 🦀

| Stage | Tool | CLI Example | Fail‑When |
|-------|------|-------------|-----------|
| **Detection** | `detect_rust()` | `[[ -f Cargo.toml ]] \|\| find . -name "*.rs" | head -n1` | — |
| **0 E2E** | (opt) `cargo nextest` | `cargo nextest run` | exit ≠ 0 |
| **1 Lint** | `cargo clippy` *(pedantic+nursery+restriction)* | `cargo clippy --all-targets --all-features -- -D warnings` | any warning |
| **2 Format** | `cargo fmt` | `cargo fmt --check` | diff ≠ 0 |
| **3 Type Check / Build** | `cargo check` | `cargo check --all-targets --all-features` | exit ≠ 0 |
| **4 Unit Test** | `cargo test` | `cargo test --all-features` | exit ≠ 0 |
| **5 SLOC** | `cargo count` *(fallback scc)* | `cargo count --unsafe-statistics` | any file ≥ 350 SLOC |
| **6 Complexity** | `rust-code-analysis` | `rust-code-analysis-cli --metrics --output-format json -o rca.json src/` | *Cyclomatic Complexity* ≥ 11 |
| **7 Maintainability / Readability** | `rust-code-analysis` MI + Halstead | Parse `rca.json`; MI < 85 or Cognitive >15 | threshold hit |
| **8 Coverage** | `cargo tarpaulin` | `cargo tarpaulin --workspace --fail-under 85` | coverage < 85 % |

*Config files added*
- `clippy.toml` – custom thresholds (`cognitive-complexity-threshold = 10`, `type-complexity-threshold = 500`, etc.)
- `rust-code-analysis.toml` – optional per‑file overrides

*Installation*
```bash
cargo install rust-code-analysis-cli cargo-count cargo-tarpaulin
```
(Add to `install_tools.sh` & `Brewfile` for Homebrew Linux/macOS users.)

---

### 2. .NET /C# Support 🔷

| Stage | Tool | CLI Example | Fail‑When |
|-------|------|-------------|-----------|
| **Detection** | `detect_dotnet()` | `find . \( -name "*.csproj" -o -name "*.sln" \) | head -n1` | — |
| **0 E2E** | *(none by default)* | — | — |
| **1 Lint** | Roslyn Analyzers + naming rules | `dotnet build -warnaserror` | any warning |
| **2 Format** | `dotnet format` | `dotnet format --verify-no-changes` | diff ≠ 0 |
| **3 Type Check / Build** | `dotnet build` | `dotnet build -c Release /v:q` | exit ≠ 0 |
| **4 Unit Test** | `dotnet test` | `dotnet test -c Release --no-build` | tests fail |
| **5 SLOC** | `Microsoft.CodeAnalysis.Metrics` | `dotnet build -t:Metrics -p:MetricsOutputFile=metrics.xml` | any file ≥ 350 SLOC |
| **6 Complexity** | Code Metrics XML – `CyclomaticComplexity` | parse `metrics.xml` | CC ≥ 25 |
| **7 Maintainability / Coupling** | Code Metrics – `MaintainabilityIndex` & `ClassCoupling` | parse `metrics.xml` | MI < 40 or Coupling > 50 |
| **8 Coverage** | `coverlet` (cross‑platform) | `dotnet test --collect:"XPlat Code Coverage"` | coverage < 85 % |

*Additional enforcement*
- `.editorconfig` naming conventions (`dotnet_naming_rule.short_names`) → flags long identifiers.
- `CodeMetricsConfig.txt` committed with thresholds to drive CA1502/CA1505/CA1506.
- NuGet refs added automatically in `install_tools.sh`:
```xml
<ItemGroup>
  <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="latest" PrivateAssets="all" />
  <PackageReference Include="Microsoft.CodeAnalysis.Metrics" Version="latest" PrivateAssets="all" />
</ItemGroup>
```

*Installation*
```bash
dotnet tool install --global dotnet-format
# Metrics and analyzers pulled via NuGet restore
```

---

### 3. SQL Support 🗄️ *(unchanged)*

- **Detection** `detect_sql()` …
- **Stage 1** `sqlfluff lint`
- **Stage 2** `sqlfluff format --check`

### 4. Security Scanning 🔒 *(new Stage 9)*

| Stage 9 | Tool | Purpose |
|---------|------|---------|
| **Security** | `trivy fs .` | Dependency & filesystem CVEs |
|             | `semgrep --config=auto` | Taint & vuln static analysis |

Fail build when CVE‑critical or semgrep error level > 0.

---

## Phase 3 🏢 ENTERPRISE *(unchanged)*
Java ☕ – Go 🐹 …

---

## Implementation Checklist 📋

1. **Detection** – update `detect_tech.sh` for `rust` & `dotnet` keys.
2. **Tool install** – append cargo & dotnet tools to `install_tools.sh`/`Brewfile`.
3. **Stage scripts** –
   - Stage 1 → add `clippy` + `dotnet build -warnaserror`.
   - Stage 2 → add `cargo fmt` & `dotnet format`.
   - Stage 5‑7 → add metric parsers (`parse_rca_json.py`, `parse_dotnet_metrics.py`).
   - Stage 8 → integrate tarpaulin + coverlet parsing.
4. **Docs** – update README ➜ supported tech matrices.
5. **CI** – expand `quality.yml` job matrix for Rust + .NET toolchain set‑up.
6. **Samples** – add reference projects for CI regression.

### Success Criteria
- CI runtime Δ ≤ +10 % vs current.
- ≥ 85 % coverage for new languages’ public repos in org.
- Zero false positives on sample projects.

---

## Risks & Mitigations 🛡️ *(updated)*

| Risk | Mitigation |
|------|------------|
| Cargo tool install latency | Cache `$HOME/.cargo` in CI |
| dotnet‑format/Linux FIPS bug | Pin CLI version tested on Ubuntu‑latest |
| Metric parsers drift | Unit‑test parse scripts against upstream sample XML/JSON |
| False positives in clippy’s restriction set | Exclude lints via `allow` comment + CI diff check |

---

## Conclusion 🎯

With Rust & .NET fully mapped onto **all nine stages**—from lint to maintainability and coverage—we preserve the system’s *fast‑by‑default* philosophy while giving teams Radon‑grade insight in modern stacks.  Phase 2 will ship a truly universal quality pipeline.

