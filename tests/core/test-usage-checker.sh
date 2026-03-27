#!/usr/bin/env bash
# Test: usage-checker.sh — unit tests for the usage/rate-limit module
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# ---------------------------------------------------------------------------
# Source the module
# ---------------------------------------------------------------------------
source "$PROJECT_ROOT/src/core/usage-checker.sh"

echo "=== usage-checker.sh tests ==="

# Test 1: Module loads (guard variable set)
[[ -n "${_ORCH_USAGE_CHECKER_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Double-source guard
source "$PROJECT_ROOT/src/core/usage-checker.sh"  # should be a no-op
pass "double-source guard"

# Test 3: Default thresholds
[[ "$_ORCH_PAUSE_THRESHOLD" -eq 80 ]] && pass "default pause threshold = 80" || fail "default pause threshold = 80 (got $_ORCH_PAUSE_THRESHOLD)"
[[ "$_ORCH_WARN_THRESHOLD" -eq 70 ]] && pass "default warn threshold = 70" || fail "default warn threshold = 70 (got $_ORCH_WARN_THRESHOLD)"

# Test 4: _orch_extract_field parses JSON-like strings
result=$(_orch_extract_field "status" '"status": "limited", "other": "val"')
[[ "$result" == "limited" ]] && pass "extract_field status=limited" || fail "extract_field status=limited (got '$result')"

# Test 5: _orch_extract_field with spaces
result=$(_orch_extract_field "overageStatus" '"overageStatus" : "exhausted"')
[[ "$result" == "exhausted" ]] && pass "extract_field with spaces" || fail "extract_field with spaces (got '$result')"

# Test 6: _orch_extract_bool parses boolean
result=$(_orch_extract_bool "isUsingOverage" '"isUsingOverage": true')
[[ "$result" == "true" ]] && pass "extract_bool true" || fail "extract_bool true (got '$result')"

result=$(_orch_extract_bool "isUsingOverage" '"isUsingOverage": false')
[[ "$result" == "false" ]] && pass "extract_bool false" || fail "extract_bool false (got '$result')"

# Test 7: orch_model_status returns 0 for unchecked model
result=$(orch_model_status "claude")
[[ "$result" == "0" ]] && pass "unchecked model returns 0" || fail "unchecked model returns 0 (got '$result')"

# Test 8: orch_get_backoff_seconds returns 0 initially
result=$(orch_get_backoff_seconds)
[[ "$result" == "0" ]] && pass "initial backoff = 0" || fail "initial backoff = 0 (got '$result')"

# Test 9: orch_should_pause — false when all models at 0
_ORCH_MODEL_STATUS[claude]=0
if orch_should_pause; then
    fail "should_pause false when claude=0"
else
    pass "should_pause false when claude=0"
fi

# Test 10: orch_should_pause — true when claude at 80
_ORCH_MODEL_STATUS[claude]=80
if orch_should_pause; then
    pass "should_pause true when claude=80"
else
    fail "should_pause true when claude=80"
fi

# Test 11: orch_should_pause — true when claude at 100
_ORCH_MODEL_STATUS[claude]=100
if orch_should_pause; then
    pass "should_pause true when claude=100"
else
    fail "should_pause true when claude=100"
fi

# Test 12: orch_all_models_down — false when some up
_ORCH_MODEL_STATUS[claude]=100
_ORCH_MODEL_STATUS[codex]=0
_ORCH_MODEL_STATUS[gemini]=0
if orch_all_models_down; then
    fail "all_models_down false when codex/gemini up"
else
    pass "all_models_down false when codex/gemini up"
fi

# Test 13: orch_all_models_down — true when all down
_ORCH_MODEL_STATUS[claude]=100
_ORCH_MODEL_STATUS[codex]=100
_ORCH_MODEL_STATUS[gemini]=100
if orch_all_models_down; then
    pass "all_models_down true when all 100"
else
    fail "all_models_down true when all 100"
fi

# Test 14: Custom threshold via env
_ORCH_PAUSE_THRESHOLD=90
_ORCH_MODEL_STATUS[claude]=80
if orch_should_pause; then
    fail "custom threshold 90: should_pause false when claude=80"
else
    pass "custom threshold 90: should_pause false when claude=80"
fi

_ORCH_MODEL_STATUS[claude]=90
if orch_should_pause; then
    pass "custom threshold 90: should_pause true when claude=90"
else
    fail "custom threshold 90: should_pause true when claude=90"
fi

# Reset
_ORCH_PAUSE_THRESHOLD=80

# ---------------------------------------------------------------------------
echo ""
echo "usage-checker: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
