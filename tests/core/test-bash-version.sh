#!/usr/bin/env bash
# Test: bash-version.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Test 1: sourcing succeeds on bash 5+
source "$PROJECT_ROOT/src/core/bash-version.sh"

# Test 2: orch_check_bash_version returns 0
orch_check_bash_version

# Test 3: guard variable is set
[[ -n "${_ORCH_BASH_VERSION_LOADED:-}" ]] || { echo "guard var not set"; exit 1; }

echo "bash-version: all tests passed"
