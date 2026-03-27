#!/usr/bin/env bash
# Test: dry-run.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$PROJECT_ROOT/src/core/dry-run.sh"

# Test 1: default is NOT dry-run
_ORCH_DRY_RUN=0
if orch_is_dry_run; then
    echo "should not be dry-run by default"
    exit 1
fi

# Test 2: --dry-run flag activates
orch_dry_run_init --dry-run
orch_is_dry_run || { echo "--dry-run should activate dry-run"; exit 1; }

# Test 3: dry_exec skips command in dry-run mode
output=$(orch_dry_exec "test action" echo "executed")
echo "$output" | grep -q "Would:" || { echo "dry_exec should print 'Would:'"; exit 1; }

# Test 4: env var activates
_ORCH_DRY_RUN=0
ORCH_DRY_RUN=1 orch_dry_run_init
orch_is_dry_run || { echo "ORCH_DRY_RUN=1 should activate"; exit 1; }

# Test 5: dry_run_report on a test config
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/prompts"
for i in $(seq 1 35); do echo "line $i" >> "$TEST_DIR/prompts/agent.txt"; done
cat > "$TEST_DIR/agents.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test Agent
EOF
report=$(orch_dry_run_report "$TEST_DIR/agents.conf" 1)
echo "$report" | grep -q "01-test" || { echo "report should list agent"; exit 1; }

echo "dry-run: all tests passed"
