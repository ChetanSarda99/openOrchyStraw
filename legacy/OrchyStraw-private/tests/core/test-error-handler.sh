#!/usr/bin/env bash
# Test: error-handler.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$PROJECT_ROOT/src/core/error-handler.sh"

# Test 1: handle a failure (capture stdout, stderr goes to /dev/null)
output=$(orch_handle_agent_failure "test-agent" 1 "" 2>/dev/null)
echo "$output" | grep -q "agent_id=test-agent" || { echo "failure not recorded"; exit 1; }

# Test 2: should_retry returns 0 for count <= 2
orch_should_retry "test-agent" 1 2>/dev/null || { echo "should allow retry 1"; exit 1; }
orch_should_retry "test-agent" 2 2>/dev/null || { echo "should allow retry 2"; exit 1; }

# Test 3: should_retry returns 1 for count > 2
if orch_should_retry "test-agent" 3 2>/dev/null; then
    echo "should NOT allow retry 3"
    exit 1
fi

# Test 4: failure report runs without error
orch_failure_report 1 > /dev/null

# Test 5: reset clears state
orch_reset_failures 2>/dev/null
report=$(orch_failure_report 1)
echo "$report" | grep -q "No failures" || { echo "reset did not clear"; exit 1; }

echo "error-handler: all tests passed"
