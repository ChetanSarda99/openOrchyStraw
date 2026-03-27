#!/usr/bin/env bash
# Test: agent-timeout.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$PROJECT_ROOT/src/core/agent-timeout.sh"

# Test 1: default timeout is 300
timeout=$(orch_get_agent_timeout "06-backend")
[[ "$timeout" == "300" ]] || { echo "default should be 300, got '$timeout'"; exit 1; }

# Test 2: per-agent env override
export ORCH_TIMEOUT_06_BACKEND=600
timeout=$(orch_get_agent_timeout "06-backend")
[[ "$timeout" == "600" ]] || { echo "env override should be 600, got '$timeout'"; exit 1; }
unset ORCH_TIMEOUT_06_BACKEND

# Test 3: global default override
export ORCH_DEFAULT_TIMEOUT=120
timeout=$(orch_get_agent_timeout "99-unknown")
[[ "$timeout" == "120" ]] || { echo "global default should be 120, got '$timeout'"; exit 1; }
unset ORCH_DEFAULT_TIMEOUT

# Test 4: run_with_timeout — fast command succeeds
orch_run_with_timeout 5 true || { echo "fast command should succeed"; exit 1; }

# Test 5: run_with_timeout — failing command returns its exit code
if orch_run_with_timeout 5 false; then
    echo "failing command should return non-zero"
    exit 1
fi

# Test 6: timeout report with no timeouts
report=$(orch_timeout_report)
echo "$report" | grep -q "No agent timeouts" || { echo "should report no timeouts"; exit 1; }

# Test 7: record + report
_orch_record_timeout "test-agent"
report=$(orch_timeout_report)
echo "$report" | grep -q "test-agent" || { echo "should show timed-out agent"; exit 1; }

# Test 8: reset clears timeouts
orch_reset_timeouts
report=$(orch_timeout_report)
echo "$report" | grep -q "No agent timeouts" || { echo "reset should clear timeouts"; exit 1; }

echo "agent-timeout: all tests passed"
