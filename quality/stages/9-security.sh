#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/_stage_common.sh"

parse_flags "$@"

FAILED=0

# Always run security scans if tools are present
if ! security_gitleaks; then
    error "gitleaks scan failed"
    FAILED=1
fi

if ! security_semgrep; then
    error "semgrep scan failed"
    FAILED=1
fi

# Terraform security (if IaC present and tool available)
if ! hcl_security_check; then
    error "Terraform security (tfsec) failed"
    FAILED=1
fi

exit $FAILED
