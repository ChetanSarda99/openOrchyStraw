#!/usr/bin/env bash
# Test: signal-handler.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/signal-handler.sh"

# Test 1: Not shutting down initially
[[ "$_ORCH_SHUTTING_DOWN" == "false" ]] || { echo "FAIL: should not be shutting down initially"; exit 1; }
! orch_is_shutting_down || { echo "FAIL: orch_is_shutting_down should return false"; exit 1; }

# Test 2: orch_signal_init sets timeout
orch_signal_init 15
[[ "$_ORCH_KILL_TIMEOUT" == "15" ]] || { echo "FAIL: kill timeout not set to 15"; exit 1; }

# Test 3: Register agent PID
orch_register_agent_pid 12345
[[ "${#_ORCH_AGENT_PIDS[@]}" -eq 1 ]] || { echo "FAIL: expected 1 PID"; exit 1; }

# Test 4: Register multiple PIDs
orch_register_agent_pid 67890
[[ "${#_ORCH_AGENT_PIDS[@]}" -eq 2 ]] || { echo "FAIL: expected 2 PIDs"; exit 1; }

# Test 5: Unregister agent PID
orch_unregister_agent_pid 12345
[[ "${#_ORCH_AGENT_PIDS[@]}" -eq 1 ]] || { echo "FAIL: expected 1 PID after unregister"; exit 1; }
[[ "${_ORCH_AGENT_PIDS[0]}" == "67890" ]] || { echo "FAIL: wrong PID remaining"; exit 1; }

# Test 6: Unregister last PID
orch_unregister_agent_pid 67890
[[ "${#_ORCH_AGENT_PIDS[@]}" -eq 0 ]] || { echo "FAIL: expected 0 PIDs"; exit 1; }

# Test 7: Shutdown flag
_ORCH_SHUTTING_DOWN=true
orch_is_shutting_down || { echo "FAIL: should be shutting down"; exit 1; }
_ORCH_SHUTTING_DOWN=false

# Test 8: Kill agents with no PIDs (no-op)
orch_kill_agents 1
# If we got here without error, it passed

# Test 9: Kill real background process
sleep 300 &
local_pid=$!
disown "$local_pid" 2>/dev/null || true
orch_register_agent_pid "$local_pid"
orch_kill_agents 2
# Verify process is dead
! kill -0 "$local_pid" 2>/dev/null || { echo "FAIL: process should be dead"; exit 1; }

# Clean up: reset traps installed by orch_signal_init
trap - INT TERM EXIT
_ORCH_AGENT_PIDS=()

echo "test-signal-handler.sh: ALL PASS (9 tests)"
