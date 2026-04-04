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

# --- New tests for upgraded features ---

# Test 9: record timeout with reason
_orch_record_timeout "mem-agent" "memory_exceeded"
report=$(orch_timeout_report)
echo "$report" | grep -q "memory_exceeded" || { echo "report should include reason"; exit 1; }
orch_reset_timeouts

# Test 10: process group kill helper (on non-existent PID)
if _orch_kill_process_group 99999 1 2>/dev/null; then
    echo "kill_process_group should return 1 for non-existent PID"
    exit 1
fi

# Test 11: run_with_limits — fast command succeeds with no limits
orch_run_with_limits 5 0 0 true || { echo "run_with_limits should succeed for 'true'"; exit 1; }

# Test 12: run_with_limits — failing command returns exit code
if orch_run_with_limits 5 0 0 false; then
    echo "run_with_limits failing command should return non-zero"
    exit 1
fi

# Test 13: run_with_limits — with memory limit (command completes fast, within limit)
orch_run_with_limits 5 1024 0 true || { echo "run_with_limits with memory limit should succeed"; exit 1; }

# Test 14: run_with_limits invalid args
if orch_run_with_limits 5 0 0 2>/dev/null; then
    echo "run_with_limits with no command should fail"
    exit 1
fi

# Test 15: _orch_apply_ulimits runs without error (just check it doesn't crash)
( _orch_apply_ulimits 0 ) || { echo "_orch_apply_ulimits 0 should not fail"; exit 1; }
( _orch_apply_ulimits 512 ) || { echo "_orch_apply_ulimits 512 should not fail"; exit 1; }

# Test 16: timeout report format with reason
_orch_record_timeout "agent-a" "timeout"
_orch_record_timeout "agent-b" "memory_exceeded"
_orch_record_timeout "agent-c" "cpu_exceeded"
report=$(orch_timeout_report)
echo "$report" | grep -q "agent-a" || { echo "report should list agent-a"; exit 1; }
echo "$report" | grep -q "agent-b" || { echo "report should list agent-b"; exit 1; }
echo "$report" | grep -q "cpu_exceeded" || { echo "report should show cpu reason"; exit 1; }
echo "$report" | grep -q "3 total" || { echo "report should show total count"; exit 1; }
orch_reset_timeouts

echo "agent-timeout: all tests passed"
