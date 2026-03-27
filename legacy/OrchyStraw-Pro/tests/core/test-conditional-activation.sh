#!/usr/bin/env bash
# Test: conditional-activation.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# --- Temp fixture setup ---
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/conditional-activation.sh"

echo "=== conditional-activation.sh tests ==="

# 1. Module loads (guard var set)
if [[ "${_ORCH_CONDITIONAL_ACTIVATION_LOADED:-}" == "1" ]]; then
    pass "Module loads (_ORCH_CONDITIONAL_ACTIVATION_LOADED=1)"
else
    fail "Module loads (_ORCH_CONDITIONAL_ACTIVATION_LOADED not set)"
fi

# 2. Double-source guard
_before="$_ORCH_CONDITIONAL_ACTIVATION_LOADED"
source "$PROJECT_ROOT/src/core/conditional-activation.sh"
if [[ "${_ORCH_CONDITIONAL_ACTIVATION_LOADED}" == "$_before" ]]; then
    pass "Double-source guard prevents re-loading"
else
    fail "Double-source guard failed"
fi

# 3. Init resets state
orch_activation_init 5 "/tmp/fake-root" 3
orch_activation_check "06-backend" 1 5 ""
orch_activation_init 6 "/tmp/fake-root" 3
if [[ -z "$(orch_activation_get_status "06-backend" 2>/dev/null | grep -v unknown)" ]]; then
    pass "Init resets state (status cleared)"
else
    fail "Init resets state (status not cleared)"
fi

# 4. Coordinator (interval=0) always eligible
orch_activation_init 5 "/tmp/fake-root" 3
orch_activation_check "03-pm" 0 5 ""
if [[ "$(orch_activation_get_status "03-pm")" == "eligible" ]]; then
    pass "Coordinator (interval=0) always eligible"
else
    fail "Coordinator (interval=0) not eligible: $(orch_activation_get_status "03-pm")"
fi

# 5. Interval check: cycle 3 with interval 2 → skipped
orch_activation_init 3 "/tmp/fake-root" 3
orch_activation_check "01-ceo" 2 3 "" || true
if [[ "$(orch_activation_get_status "01-ceo")" == "skipped" ]]; then
    pass "Interval check: cycle 3 with interval 2 → skipped"
else
    fail "Interval check: cycle 3 with interval 2 → got $(orch_activation_get_status "01-ceo")"
fi

# 6. Interval check: cycle 4 with interval 2 → eligible
orch_activation_init 4 "/tmp/fake-root" 3
orch_activation_check "01-ceo" 2 4 ""
if [[ "$(orch_activation_get_status "01-ceo")" == "eligible" ]]; then
    pass "Interval check: cycle 4 with interval 2 → eligible"
else
    fail "Interval check: cycle 4 with interval 2 → got $(orch_activation_get_status "01-ceo")"
fi

# 7. Force flag overrides skip
orch_activation_init 3 "/tmp/fake-root" 3
orch_activation_force "01-ceo"
orch_activation_check "01-ceo" 2 3 ""
if [[ "$(orch_activation_get_status "01-ceo")" == "forced" ]]; then
    pass "Force flag overrides skip"
else
    fail "Force flag overrides skip: got $(orch_activation_get_status "01-ceo")"
fi

# 8. Parse forces from context file
CTX_FORCE="$TMPDIR_TEST/context-force.md"
cat > "$CTX_FORCE" <<'FIXTURE'
# Shared Context — Cycle 5

## Notes
- FORCE: 09-qa
- FORCE: 10-security

## Blockers
- None
FIXTURE
orch_activation_init 5 "/tmp/fake-root" 3
orch_activation_parse_forces "$CTX_FORCE"
if [[ "${_ORCH_ACTIV_FORCED[09-qa]:-0}" == "1" ]] && \
   [[ "${_ORCH_ACTIV_FORCED[10-security]:-0}" == "1" ]]; then
    pass "Parse forces from context file"
else
    fail "Parse forces from context file"
fi

# 9. Idle streak increments on "idle" outcome
orch_activation_init 5 "/tmp/fake-root" 3
orch_activation_record_outcome "06-backend" "idle"
orch_activation_record_outcome "06-backend" "idle"
orch_activation_record_outcome "06-backend" "idle"
if [[ "$(orch_activation_idle_streak "06-backend")" == "3" ]]; then
    pass "Idle streak increments on idle outcome (3)"
else
    fail "Idle streak increments: got $(orch_activation_idle_streak "06-backend"), expected 3"
fi

# 10. Idle streak resets on "active" outcome
orch_activation_record_outcome "06-backend" "active"
if [[ "$(orch_activation_idle_streak "06-backend")" == "0" ]]; then
    pass "Idle streak resets on active outcome"
else
    fail "Idle streak resets: got $(orch_activation_idle_streak "06-backend"), expected 0"
fi

# 11. Idle backoff: streak >= threshold AND no git changes → skipped
# Use empty ownership path — _orch_activ_has_changes returns 1 for empty paths
orch_activation_init 4 "/tmp/fake-root" 3
_ORCH_ACTIV_IDLE_STREAK["08-pixel"]=5
orch_activation_check "08-pixel" 2 4 "nonexistent-path/" || true
if [[ "$(orch_activation_get_status "08-pixel")" == "skipped" ]]; then
    pass "Idle backoff: streak >= threshold AND no changes → skipped"
else
    fail "Idle backoff: got $(orch_activation_get_status "08-pixel"), expected skipped"
fi

# 12. Idle backoff doesn't trigger when streak < threshold
orch_activation_init 4 "/tmp/fake-root" 3
_ORCH_ACTIV_IDLE_STREAK["07-ios"]=2
orch_activation_check "07-ios" 2 4 "nonexistent-path/"
if [[ "$(orch_activation_get_status "07-ios")" == "eligible" ]]; then
    pass "Idle backoff does not trigger when streak < threshold"
else
    fail "Idle backoff triggered early: got $(orch_activation_get_status "07-ios")"
fi

# 13. Eligible list returns only eligible/forced agents
orch_activation_init 4 "/tmp/fake-root" 3
orch_activation_check "06-backend" 1 4 ""
orch_activation_check "03-pm" 0 4 ""
orch_activation_force "09-qa"
orch_activation_check "09-qa" 3 3 ""
orch_activation_check "01-ceo" 3 4 "" || true
eligible=$(orch_activation_eligible_list)
if echo "$eligible" | grep -q "06-backend" && \
   echo "$eligible" | grep -q "03-pm" && \
   echo "$eligible" | grep -q "09-qa"; then
    pass "Eligible list returns eligible and forced agents"
else
    fail "Eligible list incorrect: $eligible"
fi

# 14. Skipped list returns only skipped agents
skipped=$(orch_activation_skipped_list)
if echo "$skipped" | grep -q "01-ceo"; then
    pass "Skipped list returns skipped agents"
else
    fail "Skipped list incorrect: $skipped"
fi

# 15. Eligible count is correct
count=$(orch_activation_eligible_count)
if [[ "$count" == "3" ]]; then
    pass "Eligible count is correct (3)"
else
    fail "Eligible count incorrect: got $count, expected 3"
fi

# 16. Get status returns correct values
if [[ "$(orch_activation_get_status "06-backend")" == "eligible" ]] && \
   [[ "$(orch_activation_get_status "09-qa")" == "forced" ]] && \
   [[ "$(orch_activation_get_status "01-ceo")" == "skipped" ]]; then
    pass "Get status returns correct values for each agent"
else
    fail "Get status returned unexpected values"
fi

# 17. Get reason returns human-readable string
reason=$(orch_activation_get_reason "01-ceo")
if [[ -n "$reason" ]] && [[ "$reason" != "no check performed" ]]; then
    pass "Get reason returns human-readable string: '$reason'"
else
    fail "Get reason returned empty or default: '$reason'"
fi

# 18. Report outputs something (non-empty)
report=$(orch_activation_report)
if [[ -n "$report" ]] && echo "$report" | grep -q "Conditional Activation Report"; then
    pass "Report outputs non-empty activation summary"
else
    fail "Report output is empty or missing header"
fi

# 19. Empty agent_id returns error
if ! orch_activation_check "" 1 5 "" 2>/dev/null; then
    pass "Empty agent_id returns error (check)"
else
    fail "Empty agent_id did not return error (check)"
fi

# 20. Force parse with missing file returns 1
if ! orch_activation_parse_forces "/nonexistent/context.md" 2>/dev/null; then
    pass "Force parse with missing file returns 1"
else
    fail "Force parse with missing file did not return 1"
fi

# 21. Record outcome with empty agent_id returns error
if ! orch_activation_record_outcome "" "active" 2>/dev/null; then
    pass "Record outcome with empty agent_id returns error"
else
    fail "Record outcome with empty agent_id did not return error"
fi

# 22. Force with empty agent_id returns error
if ! orch_activation_force "" 2>/dev/null; then
    pass "Force with empty agent_id returns error"
else
    fail "Force with empty agent_id did not return error"
fi

# 23. Coordinator reason mentions interval=0
orch_activation_init 1 "/tmp/fake-root" 3
orch_activation_check "03-pm" 0 1 ""
reason=$(orch_activation_get_reason "03-pm")
if echo "$reason" | grep -q "coordinator"; then
    pass "Coordinator reason mentions coordinator"
else
    fail "Coordinator reason missing keyword: '$reason'"
fi

# 24. Unknown agent status returns 'unknown'
status=$(orch_activation_get_status "99-nonexistent")
if [[ "$status" == "unknown" ]]; then
    pass "Unknown agent status returns 'unknown'"
else
    fail "Unknown agent status: got '$status', expected 'unknown'"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed ($(( PASS + FAIL )) total)"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
