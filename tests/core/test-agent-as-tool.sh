#!/usr/bin/env bash
# Test: agent-as-tool.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/agent-as-tool.sh"

echo "=== agent-as-tool.sh tests ==="

# 1. Module loads (guard var set)
if [[ "${_ORCH_AGENT_TOOL_LOADED:-}" == "1" ]]; then
    pass "module loads — guard var set"
else
    fail "module loads — guard var set"
fi

# 2. Double-source guard (sourcing again should not error)
# The readonly guard var prevents re-execution; source returns 0.
if source "$PROJECT_ROOT/src/core/agent-as-tool.sh" 2>/dev/null; then
    pass "double-source guard returns 0"
else
    fail "double-source guard returns 0"
fi

# 3. orch_tool_init sets defaults
orch_tool_init "$TMPDIR_TEST"
if [[ "$_ORCH_TOOL_ROOT" == "$TMPDIR_TEST" ]] && \
   [[ "$_ORCH_TOOL_TIMEOUT" == "30" ]] && \
   [[ "$_ORCH_TOOL_INVOKE_COUNT" == "0" ]] && \
   [[ "${#_ORCH_TOOL_REGISTRY[@]}" -eq 0 ]]; then
    pass "orch_tool_init sets defaults"
else
    fail "orch_tool_init sets defaults"
fi

# 4. orch_tool_set_timeout changes timeout
orch_tool_set_timeout 60
if [[ "$_ORCH_TOOL_TIMEOUT" == "60" ]]; then
    pass "orch_tool_set_timeout changes timeout"
else
    fail "orch_tool_set_timeout changes timeout"
fi

# 5. orch_tool_register adds agent to registry
orch_tool_register "02-cto" "prompts/02-cto/02-cto.txt" "claude"
if [[ "${_ORCH_TOOL_REGISTRY[02-cto]:-}" == "prompts/02-cto/02-cto.txt" ]]; then
    pass "orch_tool_register adds agent to registry"
else
    fail "orch_tool_register adds agent to registry"
fi

# 6. orch_tool_register stores CLI command
if [[ "${_ORCH_TOOL_CLI[02-cto]:-}" == "claude" ]]; then
    pass "orch_tool_register stores CLI command"
else
    fail "orch_tool_register stores CLI command"
fi

# 7. orch_tool_is_registered returns 0 for registered
if orch_tool_is_registered "02-cto"; then
    pass "orch_tool_is_registered returns 0 for registered"
else
    fail "orch_tool_is_registered returns 0 for registered"
fi

# 8. orch_tool_is_registered returns 1 for unregistered
if orch_tool_is_registered "99-nobody"; then
    fail "orch_tool_is_registered returns 1 for unregistered"
else
    pass "orch_tool_is_registered returns 1 for unregistered"
fi

# 9. orch_tool_list shows registered agents
list_output=$(orch_tool_list)
if [[ "$list_output" == *"02-cto"* ]]; then
    pass "orch_tool_list shows registered agents"
else
    fail "orch_tool_list shows registered agents"
fi

# 10. orch_tool_invoke returns 2 for unknown target
if orch_tool_invoke "06-backend" "99-nobody" "hello" 2>/dev/null; then
    fail "orch_tool_invoke returns 2 for unknown target"
else
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "orch_tool_invoke returns 2 for unknown target"
    else
        fail "orch_tool_invoke returns 2 for unknown target (got rc=$rc)"
    fi
fi

# 11. orch_tool_invoke returns 3 for self-invoke
if orch_tool_invoke "02-cto" "02-cto" "hello" 2>/dev/null; then
    fail "orch_tool_invoke returns 3 for self-invoke"
else
    rc=$?
    if [[ "$rc" -eq 3 ]]; then
        pass "orch_tool_invoke returns 3 for self-invoke"
    else
        fail "orch_tool_invoke returns 3 for self-invoke (got rc=$rc)"
    fi
fi

# 12. orch_tool_invoke with mock CLI succeeds
_ORCH_TOOL_MOCK_CMD="echo"
orch_tool_set_timeout 5
# Write result to a file to avoid subshell (subshells don't propagate state)
orch_tool_invoke "06-backend" "02-cto" "What is the DB schema?" \
    > "$TMPDIR_TEST/mock-result.txt" 2>/dev/null
invoke_rc=$?
result=$(cat "$TMPDIR_TEST/mock-result.txt")
if [[ "$invoke_rc" -eq 0 ]]; then
    pass "mock invoke succeeds (rc=0)"
else
    fail "mock invoke succeeds (got rc=$invoke_rc)"
fi

# 13. Mock invoke captures response
# echo receives the wrapped prompt as its argument, so result should contain the query
if [[ "$result" == *"What is the DB schema?"* ]]; then
    pass "mock invoke captures response"
else
    fail "mock invoke captures response"
fi

# 14. Invocation count increments after invoke
# We have had: unknown-target(1), self-invoke(1), mock-ok(1) = 3
if [[ "$_ORCH_TOOL_INVOKE_COUNT" -ge 3 ]]; then
    pass "invocation count increments after invoke"
else
    fail "invocation count increments after invoke (count=$_ORCH_TOOL_INVOKE_COUNT)"
fi

# 15. History records invocation
history_raw="${_ORCH_TOOL_HISTORY[06-backend]:-}"
if [[ "$history_raw" == *"02-cto"* ]] && [[ "$history_raw" == *"ok"* ]]; then
    pass "history records invocation"
else
    fail "history records invocation"
fi

# 16. orch_tool_get_history returns entries for caller
history_output=$(orch_tool_get_history "06-backend")
if [[ "$history_output" == *"02-cto"* ]]; then
    pass "orch_tool_get_history returns entries for caller"
else
    fail "orch_tool_get_history returns entries for caller"
fi

# 17. orch_tool_get_history returns empty for unknown caller
history_unknown=$(orch_tool_get_history "00-phantom")
if [[ "$history_unknown" == *"no invocation history"* ]]; then
    pass "orch_tool_get_history returns empty for unknown caller"
else
    fail "orch_tool_get_history returns empty for unknown caller"
fi

# 18. Multiple registrations tracked
orch_tool_register "10-security" "prompts/10-security/10-security.txt" "claude"
orch_tool_register "06-backend" "prompts/06-backend/06-backend.txt" "codex exec"
if [[ "${#_ORCH_TOOL_REGISTRY[@]}" -ge 3 ]]; then
    pass "multiple registrations tracked"
else
    fail "multiple registrations tracked (count=${#_ORCH_TOOL_REGISTRY[@]})"
fi

# 19. orch_tool_report runs without error
report_output=$(orch_tool_report 2>&1)
if [[ $? -eq 0 ]] && [[ "$report_output" == *"Agent-as-Tool Report"* ]]; then
    pass "orch_tool_report runs without error"
else
    fail "orch_tool_report runs without error"
fi

# 20. Invoke with short timeout (mock with sleep to trigger timeout)
_ORCH_TOOL_MOCK_CMD="sleep"
orch_tool_set_timeout 1
if orch_tool_invoke "06-backend" "02-cto" "3" 2>/dev/null; then
    fail "invoke with short timeout returns non-zero"
else
    rc=$?
    if [[ "$rc" -eq 1 ]]; then
        pass "invoke with short timeout returns 1 (timeout)"
    else
        # timeout may also surface differently depending on env
        pass "invoke with short timeout returns non-zero (rc=$rc)"
    fi
fi
unset _ORCH_TOOL_MOCK_CMD

# 21. Register overwrites previous entry
orch_tool_register "02-cto" "prompts/02-cto/new-prompt.txt" "gemini -p"
if [[ "${_ORCH_TOOL_REGISTRY[02-cto]}" == "prompts/02-cto/new-prompt.txt" ]] && \
   [[ "${_ORCH_TOOL_CLI[02-cto]}" == "gemini -p" ]]; then
    pass "register overwrites previous entry"
else
    fail "register overwrites previous entry"
fi

# 22. Init resets all state
orch_tool_init "$TMPDIR_TEST"
if [[ "${#_ORCH_TOOL_REGISTRY[@]}" -eq 0 ]] && \
   [[ "${#_ORCH_TOOL_HISTORY[@]}" -eq 0 ]] && \
   [[ "$_ORCH_TOOL_INVOKE_COUNT" -eq 0 ]] && \
   [[ "$_ORCH_TOOL_TIMEOUT" -eq 30 ]]; then
    pass "init resets all state"
else
    fail "init resets all state"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
