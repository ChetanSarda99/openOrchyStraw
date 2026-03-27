#!/usr/bin/env bash
# Test: quality-gates.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/quality-gates.sh"

echo "=== quality-gates.sh tests ==="

# -----------------------------------------------------------------------
# 1. Module loads (guard var set)
# -----------------------------------------------------------------------
if [[ "${_ORCH_QUALITY_GATES_LOADED:-}" == "1" ]]; then
    pass "1 - module loads (guard var set)"
else
    fail "1 - module loads (guard var set)"
fi

# -----------------------------------------------------------------------
# 2. Double-source guard
# -----------------------------------------------------------------------
if source "$PROJECT_ROOT/src/core/quality-gates.sh"; then
    pass "2 - double-source guard"
else
    fail "2 - double-source guard"
fi

# -----------------------------------------------------------------------
# 3. Init sets project root
# -----------------------------------------------------------------------
orch_gate_init "$PROJECT_ROOT" 2>/dev/null
if [[ "${_ORCH_GATE_ROOT:-}" == "$PROJECT_ROOT" ]]; then
    pass "3 - init sets project root"
else
    fail "3 - init sets project root (got: ${_ORCH_GATE_ROOT:-UNSET})"
fi

# -----------------------------------------------------------------------
# 4. Register a gate
# -----------------------------------------------------------------------
orch_gate_register "echo-gate" "echo hello" "warning" 2>/dev/null
if [[ "${_ORCH_GATE_SEVERITY[echo-gate]:-}" == "warning" ]]; then
    pass "4 - register gate with severity"
else
    fail "4 - register gate with severity"
fi

# -----------------------------------------------------------------------
# 5. Register gate stores command
# -----------------------------------------------------------------------
if [[ "${_ORCH_GATE_COMMANDS[echo-gate]:-}" == "echo hello" ]]; then
    pass "5 - register gate stores command"
else
    fail "5 - register gate stores command (got: ${_ORCH_GATE_COMMANDS[echo-gate]:-UNSET})"
fi

# -----------------------------------------------------------------------
# 6. Run a passing gate
# -----------------------------------------------------------------------
if orch_gate_run "echo-gate" 2>/dev/null; then
    pass "6 - run passing gate returns 0"
else
    fail "6 - run passing gate returns 0"
fi

# -----------------------------------------------------------------------
# 7. Gate result is pass
# -----------------------------------------------------------------------
result=$(orch_gate_result "echo-gate" 2>/dev/null)
if [[ "$result" == "pass" ]]; then
    pass "7 - gate result is pass"
else
    fail "7 - gate result is pass (got: $result)"
fi

# -----------------------------------------------------------------------
# 8. Register and run a failing gate
# -----------------------------------------------------------------------
orch_gate_register "fail-gate" "exit 1" "blocking" 2>/dev/null
if ! orch_gate_run "fail-gate" 2>/dev/null; then
    pass "8 - run failing gate returns 1"
else
    fail "8 - run failing gate should return 1"
fi

# -----------------------------------------------------------------------
# 9. Failed gate result
# -----------------------------------------------------------------------
result=$(orch_gate_result "fail-gate" 2>/dev/null)
if [[ "$result" == "fail" ]]; then
    pass "9 - failed gate result is fail"
else
    fail "9 - failed gate result (got: $result)"
fi

# -----------------------------------------------------------------------
# 10. passed_all returns 1 when blocking gate failed
# -----------------------------------------------------------------------
if ! orch_gate_passed_all 2>/dev/null; then
    pass "10 - passed_all returns 1 (blocking gate failed)"
else
    fail "10 - passed_all should return 1"
fi

# -----------------------------------------------------------------------
# 11. Skip a gate — sets the skipped flag
# -----------------------------------------------------------------------
orch_gate_skip "fail-gate" 2>/dev/null
if [[ "${_ORCH_GATE_SKIPPED[fail-gate]:-}" == "1" ]]; then
    pass "11 - skip sets skipped flag"
else
    fail "11 - skip sets skipped flag"
fi

# -----------------------------------------------------------------------
# 12. Reset clears results but keeps registrations
# -----------------------------------------------------------------------
orch_gate_reset 2>/dev/null
if [[ -z "${_ORCH_GATE_RESULTS[echo-gate]:-}" ]] && [[ -n "${_ORCH_GATE_COMMANDS[echo-gate]:-}" ]]; then
    pass "12 - reset clears results, keeps registrations"
else
    fail "12 - reset clears results (result=${_ORCH_GATE_RESULTS[echo-gate]:-EMPTY}, cmd=${_ORCH_GATE_COMMANDS[echo-gate]:-EMPTY})"
fi

# -----------------------------------------------------------------------
# 13. Register defaults
# -----------------------------------------------------------------------
orch_gate_register_defaults 2>/dev/null
if [[ -n "${_ORCH_GATE_COMMANDS[syntax]:-}" ]]; then
    pass "13 - register_defaults adds syntax gate"
else
    fail "13 - register_defaults should add syntax gate"
fi

# -----------------------------------------------------------------------
# 14. Syntax gate severity is blocking
# -----------------------------------------------------------------------
if [[ "${_ORCH_GATE_SEVERITY[syntax]:-}" == "blocking" ]]; then
    pass "14 - syntax gate is blocking"
else
    fail "14 - syntax gate severity (got: ${_ORCH_GATE_SEVERITY[syntax]:-UNSET})"
fi

# -----------------------------------------------------------------------
# 15. Run syntax gate (should pass — all src/core/*.sh are valid)
# -----------------------------------------------------------------------
if orch_gate_run "syntax" 2>/dev/null; then
    pass "15 - syntax gate passes on src/core/"
else
    fail "15 - syntax gate should pass"
fi

# -----------------------------------------------------------------------
# 16. Report produces output
# -----------------------------------------------------------------------
report_output=$(orch_gate_report 2>/dev/null)
if [[ -n "$report_output" ]]; then
    pass "16 - report produces output"
else
    fail "16 - report produces output"
fi

# -----------------------------------------------------------------------
# 17. Add custom function gate
# -----------------------------------------------------------------------
my_custom_check() {
    echo "custom check ran for $1"
    return 0
}
orch_gate_add_custom "custom-fn" "my_custom_check" "warning" 2>/dev/null
if [[ "${_ORCH_GATE_TYPE[custom-fn]:-}" == "function" ]]; then
    pass "17 - add_custom registers function gate"
else
    fail "17 - add_custom should set type=function (got: ${_ORCH_GATE_TYPE[custom-fn]:-UNSET})"
fi

# -----------------------------------------------------------------------
# 18. Run custom function gate
# -----------------------------------------------------------------------
if orch_gate_run "custom-fn" "06-backend" 2>/dev/null; then
    pass "18 - custom function gate passes"
else
    fail "18 - custom function gate should pass"
fi

# -----------------------------------------------------------------------
# 19. Ownership check — setup git repo
# -----------------------------------------------------------------------
OWN_PROJECT="$TMPDIR_TEST/own-project"
mkdir -p "$OWN_PROJECT/src/core" "$OWN_PROJECT/src/other"
cd "$OWN_PROJECT"
git init 2>/dev/null
git config user.email "test@test.com"
git config user.name "Test"
echo "initial" > "$OWN_PROJECT/src/core/foo.sh"
git add -A && git commit -m "initial" 2>/dev/null

# Make a change within ownership
echo "modified" > "$OWN_PROJECT/src/core/foo.sh"
git add -A && git commit -m "in-lane change" 2>/dev/null

orch_gate_init "$OWN_PROJECT" 2>/dev/null
if orch_gate_check_ownership "06-backend" "src/core/" 2>/dev/null; then
    pass "19 - ownership check passes for in-lane changes"
else
    fail "19 - ownership check should pass for in-lane changes"
fi

# -----------------------------------------------------------------------
# 20. Ownership check — rogue write detected
# -----------------------------------------------------------------------
echo "rogue" > "$OWN_PROJECT/src/other/rogue.txt"
git add -A && git commit -m "rogue write" 2>/dev/null

rogue_output=$(orch_gate_check_ownership "06-backend" "src/core/" 2>/dev/null) && rogue_exit=0 || rogue_exit=$?
if [[ $rogue_exit -ne 0 ]]; then
    pass "20 - ownership check detects rogue write"
else
    fail "20 - ownership check should detect rogue write (exit=$rogue_exit)"
fi

cd "$PROJECT_ROOT"

# -----------------------------------------------------------------------
# 21. run_all with only passing gates
# -----------------------------------------------------------------------
orch_gate_reset 2>/dev/null
_ORCH_GATE_COMMANDS=()
_ORCH_GATE_SEVERITY=()
_ORCH_GATE_TYPE=()
_ORCH_GATE_ORDER=()
orch_gate_init "$PROJECT_ROOT" 2>/dev/null
orch_gate_register "pass1" "echo ok1" "blocking" 2>/dev/null
orch_gate_register "pass2" "echo ok2" "blocking" 2>/dev/null
if orch_gate_run_all 2>/dev/null; then
    pass "21 - run_all passes when all gates pass"
else
    fail "21 - run_all should pass"
fi

# -----------------------------------------------------------------------
# 22. run_all with a warning failure still passes
# -----------------------------------------------------------------------
orch_gate_reset 2>/dev/null
orch_gate_register "warn-fail" "exit 1" "warning" 2>/dev/null
if orch_gate_run_all 2>/dev/null; then
    pass "22 - run_all passes despite warning failure"
else
    fail "22 - run_all should pass (warning only)"
fi

# -----------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed (total: $((PASS + FAIL)))"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
