#!/usr/bin/env bash
# Test: token-budget.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/token-budget.sh"

echo "=== token-budget.sh tests ==="

# Test 1: Module loads
[[ -n "${_ORCH_TOKEN_BUDGET_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Init sets total
orch_token_budget_init 100000
[[ $_ORCH_BUDGET_TOTAL -eq 100000 ]] && pass "init total=100000" || fail "init total=100000"
[[ $_ORCH_BUDGET_REMAINING -eq 100000 ]] && pass "init remaining=100000" || fail "init remaining=100000"

# Test 3: Equal allocation for 4 agents
orch_token_budget_init 100000
alloc=$(orch_token_budget_allocate "agent-1" 4)
[[ $alloc -eq 25000 ]] && pass "equal alloc: 25000" || fail "equal alloc: 25000 (got $alloc)"

# Test 4: Priority allocation (1.5x)
orch_token_budget_init 100000
alloc=$(orch_token_budget_allocate "agent-p0" 4 15)
[[ $alloc -eq 37500 ]] && pass "1.5x alloc: 37500" || fail "1.5x alloc: 37500 (got $alloc)"

# Test 5: Hard cap at 2x base
orch_token_budget_init 100000
alloc=$(orch_token_budget_allocate "agent-big" 4 30)  # 3x would be 75000, cap at 50000
[[ $alloc -eq 50000 ]] && pass "hard cap: 50000" || fail "hard cap: 50000 (got $alloc)"

# Test 6: Record usage
orch_token_budget_init 100000
orch_token_budget_allocate "agent-1" 2 > /dev/null
orch_token_budget_record "agent-1" 30000
result=$(orch_token_budget_get "agent-1")
[[ $result -eq 50000 ]] && pass "get allocated: 50000" || fail "get allocated: 50000 (got $result)"

# Test 7: Budget exceeded
orch_token_budget_init 100000
orch_token_budget_allocate "agent-1" 4 > /dev/null  # 25000
orch_token_budget_record "agent-1" 30000
if orch_token_budget_exceeded "agent-1"; then
    pass "exceeded: 30000 > 25000"
else
    fail "exceeded: 30000 > 25000"
fi

# Test 8: Budget not exceeded
orch_token_budget_init 100000
orch_token_budget_allocate "agent-2" 2 > /dev/null  # 50000
orch_token_budget_record "agent-2" 20000
if orch_token_budget_exceeded "agent-2"; then
    fail "not exceeded: 20000 < 50000"
else
    pass "not exceeded: 20000 < 50000"
fi

# Test 9: Total used
orch_token_budget_init 100000
orch_token_budget_allocate "a" 2 > /dev/null
orch_token_budget_allocate "b" 2 > /dev/null
orch_token_budget_record "a" 15000
orch_token_budget_record "b" 25000
total=$(orch_token_budget_total_used)
[[ $total -eq 40000 ]] && pass "total used: 40000" || fail "total used: 40000 (got $total)"

# Test 10: Max tokens calculation
orch_token_budget_init 100000
orch_token_budget_allocate "agent-1" 2 > /dev/null  # 50000 allocated
max_tok=$(orch_token_budget_to_max_tokens "agent-1")
# 50000 * 30% = 15000
[[ $max_tok -eq 15000 ]] && pass "max_tokens: 15000" || fail "max_tokens: 15000 (got $max_tok)"

# Test 11: Max tokens floor (small budget)
orch_token_budget_init 10000
orch_token_budget_allocate "small" 10 > /dev/null  # 1000 allocated
max_tok=$(orch_token_budget_to_max_tokens "small")
# 1000 * 30% = 300, but floor is 4096
[[ $max_tok -eq 4096 ]] && pass "max_tokens floor: 4096" || fail "max_tokens floor: 4096 (got $max_tok)"

# Test 12: History-based reduction
orch_token_budget_init 100000
orch_token_budget_allocate "lazy" 2 > /dev/null  # 50000
orch_token_budget_record "lazy" 10000             # Used only 20%
orch_token_budget_save_history
# Re-init and re-allocate — should get 75% of base due to low usage
orch_token_budget_init 100000
alloc=$(orch_token_budget_allocate "lazy" 2)
# 50000 * 75% = 37500
[[ $alloc -eq 37500 ]] && pass "history reduction: 37500" || fail "history reduction: 37500 (got $alloc)"

# Test 13: Report runs without error
orch_token_budget_init 50000
orch_token_budget_allocate "test-a" 2 > /dev/null
orch_token_budget_record "test-a" 10000
output=$(orch_token_budget_report)
echo "$output" | grep -q "Token Budget Report" && pass "report header" || fail "report header"
echo "$output" | grep -q "test-a" && pass "report agent entry" || fail "report agent entry"

echo ""
echo "token-budget: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
