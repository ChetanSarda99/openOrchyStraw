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

# --- New tests for upgraded features ---

# Test 6: Error categorization
cat_general=$(orch_categorize_error 1)
[[ "$cat_general" == "general" ]] || { echo "exit 1 should be 'general', got '$cat_general'"; exit 1; }

cat_timeout=$(orch_categorize_error 124)
[[ "$cat_timeout" == "timeout" ]] || { echo "exit 124 should be 'timeout', got '$cat_timeout'"; exit 1; }

cat_killed=$(orch_categorize_error 137)
[[ "$cat_killed" == "killed" ]] || { echo "exit 137 should be 'killed', got '$cat_killed'"; exit 1; }

cat_perm=$(orch_categorize_error 126)
[[ "$cat_perm" == "permission" ]] || { echo "exit 126 should be 'permission', got '$cat_perm'"; exit 1; }

cat_notfound=$(orch_categorize_error 127)
[[ "$cat_notfound" == "not_found" ]] || { echo "exit 127 should be 'not_found', got '$cat_notfound'"; exit 1; }

# Test 7: Signal range categorization
cat_sig=$(orch_categorize_error 130)  # 128 + 2 = SIGINT
[[ "$cat_sig" == "signal_2" ]] || { echo "exit 130 should be 'signal_2', got '$cat_sig'"; exit 1; }

# Test 8: Unknown exit code
cat_unknown=$(orch_categorize_error 42)
[[ "$cat_unknown" == "unknown" ]] || { echo "exit 42 should be 'unknown', got '$cat_unknown'"; exit 1; }

# Test 9: Failure report includes category
orch_reset_failures 2>/dev/null
orch_handle_agent_failure "cat-agent" 137 "" 2>/dev/null > /dev/null
report=$(orch_failure_report 1)
echo "$report" | grep -q "killed" || { echo "report should include error category 'killed'"; exit 1; }

# Test 10: Stack trace capture
test_stack_func_inner() {
    orch_stack_trace 1 2>/dev/null
}
test_stack_func_outer() {
    test_stack_func_inner
}
test_stack_func_outer
[[ -n "$_ORCH_LAST_STACK_TRACE" ]] || { echo "stack trace should be captured"; exit 1; }
echo "$_ORCH_LAST_STACK_TRACE" | grep -q "test_stack_func_outer" || { echo "stack trace should include outer function"; exit 1; }

# Test 11: Failure with stack trace stored
orch_reset_failures 2>/dev/null
_ORCH_LAST_STACK_TRACE="mock stack trace line 1"
output=$(orch_handle_agent_failure "stack-agent" 1 "" 2>/dev/null)
echo "$output" | grep -q "category=general" || { echo "output should include category"; exit 1; }
echo "$output" | grep -q "stack_trace" || { echo "output should include stack_trace field"; exit 1; }

# Test 12: Retry with backoff — succeeds on first try
ORCH_BACKOFF_BASE=1
ORCH_BACKOFF_JITTER=0
orch_retry_with_backoff 3 true 2>/dev/null || { echo "retry should succeed for 'true'"; exit 1; }

# Test 13: Retry with backoff — fails after max retries
ORCH_BACKOFF_BASE=0
ORCH_BACKOFF_JITTER=0
if orch_retry_with_backoff 2 false 2>/dev/null; then
    echo "retry should fail for 'false'"
    exit 1
fi

# Test 14: Retry with backoff — command that eventually succeeds
ATTEMPT_FILE=$(mktemp)
echo "0" > "$ATTEMPT_FILE"
succeeds_on_second() {
    local count
    count=$(cat "$ATTEMPT_FILE")
    count=$((count + 1))
    echo "$count" > "$ATTEMPT_FILE"
    [[ "$count" -ge 2 ]]
}
ORCH_BACKOFF_BASE=0
orch_retry_with_backoff 3 succeeds_on_second 2>/dev/null || { echo "should succeed on retry"; exit 1; }
rm -f "$ATTEMPT_FILE"

# Test 15: Error handler trap can be installed
orch_set_error_handler 2>/dev/null
# Verify the trap is set (just check it doesn't error)
trap -p ERR | grep -q "_orch_err_trap_handler" || { echo "ERR trap should be installed"; exit 1; }
# Remove trap for remaining tests
trap - ERR

# Reset backoff settings
ORCH_BACKOFF_BASE=1
ORCH_BACKOFF_JITTER=1

echo "error-handler: all tests passed"
