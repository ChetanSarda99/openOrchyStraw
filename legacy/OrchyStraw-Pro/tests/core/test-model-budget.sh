#!/usr/bin/env bash
# Test: model-budget.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/model-budget.sh"

echo "=== model-budget.sh tests ==="

# ---------------------------------------------------------------------------
# 1. Module loads (guard var set)
# ---------------------------------------------------------------------------
if [[ "${_ORCH_MODEL_BUDGET_LOADED:-}" == "1" ]]; then
    pass "1. Module loads — guard var set"
else
    fail "1. Module loads — guard var set"
fi

# ---------------------------------------------------------------------------
# 2. Double-source guard
# ---------------------------------------------------------------------------
# Sourcing again should be a no-op (return 0, no error)
if source "$PROJECT_ROOT/src/core/model-budget.sh" 2>/dev/null; then
    pass "2. Double-source guard"
else
    fail "2. Double-source guard"
fi

# ---------------------------------------------------------------------------
# 3. orch_budget_init resets state
# ---------------------------------------------------------------------------
# Dirty the state first, then init
_ORCH_MB_GLOBAL_COUNT=99
orch_budget_init
if [[ "$_ORCH_MB_GLOBAL_COUNT" -eq 0 ]] && [[ ${#_ORCH_MB_CHAINS[@]} -eq 0 ]]; then
    pass "3. orch_budget_init resets state"
else
    fail "3. orch_budget_init resets state"
fi

# ---------------------------------------------------------------------------
# 4. Default chain is "claude,codex,gemini"
# ---------------------------------------------------------------------------
if [[ "$_ORCH_MB_DEFAULT_CHAIN" == "claude,codex,gemini" ]]; then
    pass "4. Default chain is claude,codex,gemini"
else
    fail "4. Default chain is claude,codex,gemini (got: $_ORCH_MB_DEFAULT_CHAIN)"
fi

# ---------------------------------------------------------------------------
# 5. orch_budget_set_chain stores chain
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_chain "06-backend" "claude,codex"
if [[ "${_ORCH_MB_CHAINS[06-backend]}" == "claude,codex" ]]; then
    pass "5. orch_budget_set_chain stores chain"
else
    fail "5. orch_budget_set_chain stores chain"
fi

# ---------------------------------------------------------------------------
# 6. orch_budget_get_chain returns chain
# ---------------------------------------------------------------------------
result="$(orch_budget_get_chain "06-backend")"
if [[ "$result" == "claude,codex" ]]; then
    pass "6. orch_budget_get_chain returns chain"
else
    fail "6. orch_budget_get_chain returns chain (got: $result)"
fi

# ---------------------------------------------------------------------------
# 7. orch_budget_get_chain returns default for unknown agent
# ---------------------------------------------------------------------------
result="$(orch_budget_get_chain "99-unknown")"
if [[ "$result" == "claude,codex,gemini" ]]; then
    pass "7. orch_budget_get_chain returns default for unknown agent"
else
    fail "7. orch_budget_get_chain returns default for unknown agent (got: $result)"
fi

# ---------------------------------------------------------------------------
# 8. orch_budget_set_limit stores limit
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_limit "06-backend" 10
if [[ "${_ORCH_MB_LIMITS[06-backend]}" == "10" ]]; then
    pass "8. orch_budget_set_limit stores limit"
else
    fail "8. orch_budget_set_limit stores limit"
fi

# ---------------------------------------------------------------------------
# 9. orch_budget_set_global_limit stores limit
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_global_limit 50
if [[ "$_ORCH_MB_GLOBAL_LIMIT" == "50" ]]; then
    pass "9. orch_budget_set_global_limit stores limit"
else
    fail "9. orch_budget_set_global_limit stores limit (got: $_ORCH_MB_GLOBAL_LIMIT)"
fi

# ---------------------------------------------------------------------------
# 10. orch_budget_remaining returns "unlimited" when no limit
# ---------------------------------------------------------------------------
orch_budget_init
result="$(orch_budget_remaining "06-backend")"
if [[ "$result" == "unlimited" ]]; then
    pass "10. orch_budget_remaining returns unlimited when no limit"
else
    fail "10. orch_budget_remaining returns unlimited when no limit (got: $result)"
fi

# ---------------------------------------------------------------------------
# 11. orch_budget_remaining returns correct number after recording
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_limit "06-backend" 10
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
result="$(orch_budget_remaining "06-backend")"
if [[ "$result" == "7" ]]; then
    pass "11. orch_budget_remaining returns correct number after recording"
else
    fail "11. orch_budget_remaining returns correct number after recording (got: $result)"
fi

# ---------------------------------------------------------------------------
# 12. orch_budget_record increments agent count
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
if [[ "${_ORCH_MB_AGENT_COUNT[06-backend]}" == "2" ]]; then
    pass "12. orch_budget_record increments agent count"
else
    fail "12. orch_budget_record increments agent count (got: ${_ORCH_MB_AGENT_COUNT[06-backend]:-0})"
fi

# ---------------------------------------------------------------------------
# 13. orch_budget_record increments model count
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_record "06-backend" "claude"
orch_budget_record "07-ios" "claude"
orch_budget_record "06-backend" "codex"
if [[ "${_ORCH_MB_MODEL_COUNT[claude]}" == "2" ]] && [[ "${_ORCH_MB_MODEL_COUNT[codex]}" == "1" ]]; then
    pass "13. orch_budget_record increments model count"
else
    fail "13. orch_budget_record increments model count"
fi

# ---------------------------------------------------------------------------
# 14. orch_budget_record increments global count
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_record "06-backend" "claude"
orch_budget_record "07-ios" "codex"
orch_budget_record "08-pixel" "gemini"
if [[ "$_ORCH_MB_GLOBAL_COUNT" == "3" ]]; then
    pass "14. orch_budget_record increments global count"
else
    fail "14. orch_budget_record increments global count (got: $_ORCH_MB_GLOBAL_COUNT)"
fi

# ---------------------------------------------------------------------------
# 15. orch_budget_is_exhausted returns 1 when has budget
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_limit "06-backend" 5
orch_budget_record "06-backend" "claude"
if ! orch_budget_is_exhausted "06-backend"; then
    pass "15. orch_budget_is_exhausted returns 1 when has budget"
else
    fail "15. orch_budget_is_exhausted returns 1 when has budget"
fi

# ---------------------------------------------------------------------------
# 16. orch_budget_is_exhausted returns 0 when exhausted
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_limit "06-backend" 2
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
if orch_budget_is_exhausted "06-backend"; then
    pass "16. orch_budget_is_exhausted returns 0 when exhausted"
else
    fail "16. orch_budget_is_exhausted returns 0 when exhausted"
fi

# ---------------------------------------------------------------------------
# 17. orch_budget_global_remaining returns "unlimited" when no global limit
# ---------------------------------------------------------------------------
orch_budget_init
result="$(orch_budget_global_remaining)"
if [[ "$result" == "unlimited" ]]; then
    pass "17. orch_budget_global_remaining returns unlimited when no global limit"
else
    fail "17. orch_budget_global_remaining returns unlimited when no global limit (got: $result)"
fi

# ---------------------------------------------------------------------------
# 18. orch_budget_global_remaining returns correct number after recording
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_global_limit 20
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
orch_budget_record "06-backend" "claude"
result="$(orch_budget_global_remaining)"
if [[ "$result" == "15" ]]; then
    pass "18. orch_budget_global_remaining returns correct number after recording"
else
    fail "18. orch_budget_global_remaining returns correct number after recording (got: $result)"
fi

# ---------------------------------------------------------------------------
# 19. orch_budget_resolve returns first available model
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_chain "test-agent" "bash,echo,cat"
result="$(orch_budget_resolve "test-agent" 2>/dev/null)"
if [[ "$result" == "bash" ]]; then
    pass "19. orch_budget_resolve returns first available model"
else
    fail "19. orch_budget_resolve returns first available model (got: $result)"
fi

# ---------------------------------------------------------------------------
# 20. orch_budget_resolve returns 1 when all exhausted
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_chain "test-agent" "nonexist1,nonexist2"
if ! orch_budget_resolve "test-agent" 2>/dev/null; then
    pass "20. orch_budget_resolve returns 1 when all exhausted"
else
    fail "20. orch_budget_resolve returns 1 when all exhausted"
fi

# ---------------------------------------------------------------------------
# 21. orch_budget_reset_cycle resets counters but keeps chains
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_chain "06-backend" "claude,codex"
orch_budget_record "06-backend" "claude"
orch_budget_reset_cycle
if [[ "${_ORCH_MB_CHAINS[06-backend]}" == "claude,codex" ]] && [[ "${_ORCH_MB_AGENT_COUNT[06-backend]:-0}" == "0" ]]; then
    pass "21. orch_budget_reset_cycle resets counters but keeps chains"
else
    fail "21. orch_budget_reset_cycle resets counters but keeps chains"
fi

# ---------------------------------------------------------------------------
# 22. orch_budget_reset_cycle resets counters but keeps limits
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_limit "06-backend" 10
orch_budget_record "06-backend" "claude"
orch_budget_reset_cycle
if [[ "${_ORCH_MB_LIMITS[06-backend]}" == "10" ]] && [[ "$_ORCH_MB_GLOBAL_COUNT" -eq 0 ]]; then
    pass "22. orch_budget_reset_cycle resets counters but keeps limits"
else
    fail "22. orch_budget_reset_cycle resets counters but keeps limits"
fi

# ---------------------------------------------------------------------------
# 23. orch_budget_report runs without error
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_chain "06-backend" "claude,codex"
orch_budget_set_limit "06-backend" 10
orch_budget_record "06-backend" "claude"
if orch_budget_report >/dev/null 2>&1; then
    pass "23. orch_budget_report runs without error"
else
    fail "23. orch_budget_report runs without error"
fi

# ---------------------------------------------------------------------------
# 24. Budget exhaustion blocks resolve
# ---------------------------------------------------------------------------
orch_budget_init
orch_budget_set_chain "test-agent" "bash,echo,cat"
orch_budget_set_limit "test-agent" 1
orch_budget_record "test-agent" "bash"
if ! orch_budget_resolve "test-agent" 2>/dev/null; then
    pass "24. Budget exhaustion blocks resolve"
else
    fail "24. Budget exhaustion blocks resolve"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
