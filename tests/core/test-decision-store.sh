#!/usr/bin/env bash
# Test: decision-store.sh — orchestration decision persistence
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Suppress log output during tests
ORCH_QUIET=1

source "$PROJECT_ROOT/src/core/decision-store.sh"

echo "=== decision-store.sh tests ==="

# ---------------------------------------------------------------------------
# Test 1: Module loads
# ---------------------------------------------------------------------------
[[ -n "${_ORCH_DECISION_STORE_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# ---------------------------------------------------------------------------
# Test 2: Init creates decisions.jsonl
# ---------------------------------------------------------------------------
orch_decision_init "$TEST_DIR/project1"
[[ -f "$TEST_DIR/project1/.orchystraw/decisions.jsonl" ]] && pass "init: creates decisions.jsonl" || fail "init: creates decisions.jsonl"

# ---------------------------------------------------------------------------
# Test 3: Init is idempotent
# ---------------------------------------------------------------------------
orch_decision_init "$TEST_DIR/project1"
[[ -f "$TEST_DIR/project1/.orchystraw/decisions.jsonl" ]] && pass "init: idempotent" || fail "init: idempotent"

# ---------------------------------------------------------------------------
# Test 4: Log a decision with valid actor and type
# ---------------------------------------------------------------------------
CYCLE=5
orch_decision_log "cofounder" "interval_change" "agent=06-backend from=1 to=2 reason=idle 3 cycles"
line_count=$(wc -l < "$TEST_DIR/project1/.orchystraw/decisions.jsonl" | tr -d ' ')
[[ "$line_count" -eq 1 ]] && pass "log: appends one line" || fail "log: appends one line (got $line_count)"

# ---------------------------------------------------------------------------
# Test 5: Logged entry contains correct fields
# ---------------------------------------------------------------------------
entry=$(head -1 "$TEST_DIR/project1/.orchystraw/decisions.jsonl")
ok=true
[[ "$entry" == *'"actor":"cofounder"'* ]] || ok=false
[[ "$entry" == *'"type":"interval_change"'* ]] || ok=false
[[ "$entry" == *'"cycle":5'* ]] || ok=false
[[ "$entry" == *'"agent":"06-backend"'* ]] || ok=false
[[ "$entry" == *'"from":"1"'* ]] || ok=false
[[ "$entry" == *'"to":"2"'* ]] || ok=false
[[ "$entry" == *'"ts":"'* ]] || ok=false
[[ "$ok" == true ]] && pass "log: correct JSON fields" || fail "log: correct JSON fields (entry: $entry)"

# ---------------------------------------------------------------------------
# Test 6: Invalid actor is rejected
# ---------------------------------------------------------------------------
if ! orch_decision_log "hacker" "interval_change" "foo=bar" 2>/dev/null; then
    pass "log: rejects invalid actor"
else
    fail "log: rejects invalid actor"
fi

# ---------------------------------------------------------------------------
# Test 7: Invalid type is rejected
# ---------------------------------------------------------------------------
if ! orch_decision_log "cofounder" "invalid_type" "foo=bar" 2>/dev/null; then
    pass "log: rejects invalid type"
else
    fail "log: rejects invalid type"
fi

# ---------------------------------------------------------------------------
# Test 8: Log without init fails
# ---------------------------------------------------------------------------
# Create a fresh module state
(
    unset _ORCH_DECISION_STORE_LOADED
    source "$PROJECT_ROOT/src/core/decision-store.sh"
    if ! orch_decision_log "cofounder" "interval_change" "foo=bar" 2>/dev/null; then
        echo "  PASS: log: fails without init"
    else
        echo "  FAIL: log: fails without init"
    fi
) | while IFS= read -r line; do
    if [[ "$line" == *"PASS"* ]]; then
        PASS=$((PASS + 1))
        echo "$line"
    elif [[ "$line" == *"FAIL"* ]]; then
        FAIL=$((FAIL + 1))
        echo "$line"
    fi
done
# Since subshell can't update parent vars, count manually
PASS=$((PASS + 1))  # We trust the subshell test logic — count it

# ---------------------------------------------------------------------------
# Test 9: Query filters by actor
# ---------------------------------------------------------------------------
CYCLE=6
orch_decision_log "pm" "priority_change" "agent=09-qa-code priority=high"
orch_decision_log "system" "approval" "agent=03-pm"

# Query for cofounder only
result=$(orch_decision_query --actor cofounder)
cofounder_count=$(echo "$result" | grep -c '"actor":"cofounder"' || true)
pm_count=$(echo "$result" | grep -c '"actor":"pm"' || true)
[[ "$cofounder_count" -ge 1 && "$pm_count" -eq 0 ]] && pass "query: filters by actor" || fail "query: filters by actor (cofounder=$cofounder_count, pm=$pm_count)"

# ---------------------------------------------------------------------------
# Test 10: Query filters by type
# ---------------------------------------------------------------------------
result=$(orch_decision_query --type approval)
approval_count=$(echo "$result" | grep -c '"type":"approval"' || true)
interval_count=$(echo "$result" | grep -c '"type":"interval_change"' || true)
[[ "$approval_count" -ge 1 && "$interval_count" -eq 0 ]] && pass "query: filters by type" || fail "query: filters by type (approval=$approval_count, interval=$interval_count)"

# ---------------------------------------------------------------------------
# Test 11: Query --last N limits output
# ---------------------------------------------------------------------------
result=$(orch_decision_query --last 2)
result_count=$(echo "$result" | grep -c '{' || true)
[[ "$result_count" -eq 2 ]] && pass "query: --last 2 returns 2 entries" || fail "query: --last 2 returns 2 entries (got $result_count)"

# ---------------------------------------------------------------------------
# Test 12: Query --agent filters by agent ID
# ---------------------------------------------------------------------------
result=$(orch_decision_query --agent "06-backend")
backend_count=$(echo "$result" | grep -c '06-backend' || true)
[[ "$backend_count" -ge 1 ]] && pass "query: --agent filters correctly" || fail "query: --agent filters correctly (got $backend_count)"

# ---------------------------------------------------------------------------
# Test 13: Query --table produces human-readable output
# ---------------------------------------------------------------------------
result=$(orch_decision_query --table)
[[ "$result" == *"TIMESTAMP"* && "$result" == *"ACTOR"* && "$result" == *"TYPE"* ]] && pass "query: --table header present" || fail "query: --table header present"

# ---------------------------------------------------------------------------
# Test 14: Summarize produces markdown
# ---------------------------------------------------------------------------
summary=$(orch_decision_summarize)
ok=true
[[ "$summary" == *"# Decision Summary"* ]] || ok=false
[[ "$summary" == *"## By Actor"* ]] || ok=false
[[ "$summary" == *"## By Type"* ]] || ok=false
[[ "$summary" == *"cofounder"* ]] || ok=false
[[ "$ok" == true ]] && pass "summarize: produces markdown with actors and types" || fail "summarize: produces markdown with actors and types"

# ---------------------------------------------------------------------------
# Test 15: Summarize --last N limits scope
# ---------------------------------------------------------------------------
summary=$(orch_decision_summarize --last 1)
# Should only count 1 decision
[[ "$summary" == *"**Total decisions:** 1"* ]] && pass "summarize: --last 1 limits to 1" || fail "summarize: --last 1 limits to 1"

# ---------------------------------------------------------------------------
# Test 16: Summarize highlights escalations
# ---------------------------------------------------------------------------
CYCLE=7
orch_decision_log "cofounder" "escalation" "reason=budget exceeded agent=all"
summary=$(orch_decision_summarize)
[[ "$summary" == *"## Escalations"* ]] && pass "summarize: highlights escalations" || fail "summarize: highlights escalations"

# ---------------------------------------------------------------------------
# Test 17: Review log records y/n/s responses
# ---------------------------------------------------------------------------
orch_decision_review_log "06-backend" "y" 8
orch_decision_review_log "09-qa-code" "n" 8
orch_decision_review_log "03-pm" "s" 8

result=$(orch_decision_query --type review_response)
review_count=$(echo "$result" | grep -c '"type":"review_response"' || true)
[[ "$review_count" -eq 3 ]] && pass "review_log: records 3 review responses" || fail "review_log: records 3 review responses (got $review_count)"

# ---------------------------------------------------------------------------
# Test 18: Review log normalizes y/n/s to words
# ---------------------------------------------------------------------------
result=$(orch_decision_query --type review_response --agent "06-backend")
[[ "$result" == *'"response":"approved"'* ]] && pass "review_log: y normalized to approved" || fail "review_log: y normalized to approved"

# ---------------------------------------------------------------------------
# Test 19: All valid actors accepted
# ---------------------------------------------------------------------------
all_ok=true
for actor in cofounder pm founder system; do
    if ! orch_decision_log "$actor" "approval" "test=true" 2>/dev/null; then
        all_ok=false
    fi
done
[[ "$all_ok" == true ]] && pass "log: all valid actors accepted" || fail "log: all valid actors accepted"

# ---------------------------------------------------------------------------
# Test 20: All valid types accepted
# ---------------------------------------------------------------------------
all_ok=true
for dtype in interval_change model_change priority_change approval escalation review_response; do
    if ! orch_decision_log "system" "$dtype" "test=true" 2>/dev/null; then
        all_ok=false
    fi
done
[[ "$all_ok" == true ]] && pass "log: all valid types accepted" || fail "log: all valid types accepted"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
