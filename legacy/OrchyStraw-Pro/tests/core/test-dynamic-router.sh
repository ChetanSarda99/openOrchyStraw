#!/usr/bin/env bash
# Test: dynamic-router.sh
# Note: set -e is intentionally omitted. dynamic-router.sh has a set -e
# incompatibility in orch_router_build_groups (the cycle_output subshell
# returns non-zero when no cycle is found). The test framework uses explicit
# pass/fail checks instead.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/dynamic-router.sh"

echo "=== dynamic-router.sh tests ==="

# --------------------------------------------------------------------------
# 1. Module loads (guard var set)
# --------------------------------------------------------------------------
if [[ "${_ORCH_DYNAMIC_ROUTER_LOADED}" == "1" ]]; then
    pass "1. Module loads — guard var set"
else
    fail "1. Module loads — guard var set"
fi

# --------------------------------------------------------------------------
# 2. Double-source guard — source again, verify no error
# --------------------------------------------------------------------------
if source "$PROJECT_ROOT/src/core/dynamic-router.sh" 2>/dev/null; then
    pass "2. Double-source guard — no error on re-source"
else
    fail "2. Double-source guard — no error on re-source"
fi

# --------------------------------------------------------------------------
# 3. Init resets state
# --------------------------------------------------------------------------
orch_router_add_agent "dummy" "none" 5
orch_router_init
if [[ "$(orch_router_group_count)" == "0" && "$(orch_router_get_deps "dummy")" == "none" ]]; then
    pass "3. Init resets state"
else
    fail "3. Init resets state"
fi

# --------------------------------------------------------------------------
# 4. Add agent with deps
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "09-qa" "06-backend" 5
deps=$(orch_router_get_deps "09-qa")
pri=$(orch_router_get_priority "09-qa")
if [[ "$deps" == "06-backend" && "$pri" == "5" ]]; then
    pass "4. Add agent with deps — deps and priority correct"
else
    fail "4. Add agent with deps — got deps='$deps' pri='$pri'"
fi

# --------------------------------------------------------------------------
# 5. Add agent with no deps
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "06-backend" "none" 10
deps=$(orch_router_get_deps "06-backend")
pri=$(orch_router_get_priority "06-backend")
if [[ "$deps" == "none" && "$pri" == "10" ]]; then
    pass "5. Add agent with no deps"
else
    fail "5. Add agent with no deps — got deps='$deps' pri='$pri'"
fi

# --------------------------------------------------------------------------
# 6. Build groups — simple chain: backend(none) -> qa(backend) -> pm(all)
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "06-backend" "none" 10
orch_router_add_agent "09-qa" "06-backend" 5
orch_router_add_agent "03-pm" "all" 8
orch_router_build_groups
count=$(orch_router_group_count)
if [[ "$count" == "3" ]]; then
    pass "6. Build groups — 3 groups for chain"
else
    fail "6. Build groups — expected 3 groups, got $count"
fi

# --------------------------------------------------------------------------
# 7. Group contents — backend in 0, qa in 1, pm in 2
# --------------------------------------------------------------------------
group0=$(orch_router_get_group "06-backend")
group1=$(orch_router_get_group "09-qa")
group2=$(orch_router_get_group "03-pm")
if [[ "$group0" == "0" && "$group1" == "1" && "$group2" == "2" ]]; then
    pass "7. Group contents — correct group assignments"
else
    fail "7. Group contents — got backend=$group0 qa=$group1 pm=$group2"
fi

# --------------------------------------------------------------------------
# 8. Priority ordering within group
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "a" "none" 3
orch_router_add_agent "b" "none" 10
orch_router_build_groups
groups_output=$(orch_router_get_groups)
first_line=$(echo "$groups_output" | head -n1)
# b (priority 10) should come before a (priority 3) in group 0
if [[ "$first_line" == "b,a" ]]; then
    pass "8. Priority ordering within group — higher priority first"
else
    fail "8. Priority ordering within group — expected 'b,a', got '$first_line'"
fi

# --------------------------------------------------------------------------
# 9. Circular dependency detection
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "a" "b" 5
orch_router_add_agent "b" "c" 5
orch_router_add_agent "c" "a" 5
if orch_router_has_cycle > /dev/null 2>&1; then
    pass "9. Circular dependency detection — cycle found"
else
    fail "9. Circular dependency detection — no cycle detected"
fi

# --------------------------------------------------------------------------
# 10. No false cycle detection
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "a" "b" 5
orch_router_add_agent "b" "c" 5
orch_router_add_agent "c" "none" 5
if orch_router_has_cycle > /dev/null 2>&1; then
    fail "10. No false cycle detection — incorrectly reported cycle"
else
    pass "10. No false cycle detection — clean graph"
fi

# --------------------------------------------------------------------------
# 11. Group count
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "x" "none" 5
orch_router_add_agent "y" "x" 5
orch_router_build_groups
count=$(orch_router_group_count)
if [[ "$count" == "2" ]]; then
    pass "11. Group count — returns correct number"
else
    fail "11. Group count — expected 2, got $count"
fi

# --------------------------------------------------------------------------
# 12. Get group for agent
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "06-backend" "none" 10
orch_router_add_agent "09-qa" "06-backend" 5
orch_router_build_groups
grp=$(orch_router_get_group "06-backend")
if [[ "$grp" == "0" ]]; then
    pass "12. Get group for agent — 06-backend in group 0"
else
    fail "12. Get group for agent — expected 0, got $grp"
fi

# --------------------------------------------------------------------------
# 13. Get deps for agent
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "09-qa" "06-backend,02-cto" 5
deps=$(orch_router_get_deps "09-qa")
if [[ "$deps" == "06-backend,02-cto" ]]; then
    pass "13. Get deps for agent — returns correct string"
else
    fail "13. Get deps for agent — expected '06-backend,02-cto', got '$deps'"
fi

# --------------------------------------------------------------------------
# 14. Get priority for agent
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "06-backend" "none" 42
pri=$(orch_router_get_priority "06-backend")
if [[ "$pri" == "42" ]]; then
    pass "14. Get priority for agent — returns correct number"
else
    fail "14. Get priority for agent — expected 42, got $pri"
fi

# --------------------------------------------------------------------------
# 15. Get groups output format — newline-separated, comma-separated within
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "a" "none" 5
orch_router_add_agent "b" "a" 5
orch_router_add_agent "c" "a" 5
orch_router_build_groups
output=$(orch_router_get_groups)
line_count=$(echo "$output" | wc -l)
if [[ "$line_count" == "2" ]]; then
    second_line=$(echo "$output" | sed -n '2p')
    # b and c should both be in group 1, comma-separated
    if [[ "$second_line" == *","* ]]; then
        pass "15. Get groups output format — newline-separated, comma within groups"
    else
        fail "15. Get groups output format — no comma in group 1: '$second_line'"
    fi
else
    fail "15. Get groups output format — expected 2 lines, got $line_count"
fi

# --------------------------------------------------------------------------
# 16. Parse agents.conf — 5-column format
# --------------------------------------------------------------------------
orch_router_init
cat > "$TMPDIR_TEST/agents-5col.conf" <<'CONF'
# comment line
01-ceo | prompts/01-ceo/01-ceo.txt | docs/strategy | 3 | CEO
06-backend | prompts/06-backend/06-backend.txt | src/core,scripts | 1 | Backend
09-qa | prompts/09-qa/09-qa.txt | tests | 3 | QA
CONF
orch_router_parse_config "$TMPDIR_TEST/agents-5col.conf"
d1=$(orch_router_get_deps "01-ceo")
d2=$(orch_router_get_deps "06-backend")
d3=$(orch_router_get_deps "09-qa")
p1=$(orch_router_get_priority "01-ceo")
if [[ "$d1" == "none" && "$d2" == "none" && "$d3" == "none" && "$p1" == "5" ]]; then
    pass "16. Parse agents.conf — 5-column format with defaults"
else
    fail "16. Parse agents.conf — deps='$d1,$d2,$d3' pri='$p1'"
fi

# --------------------------------------------------------------------------
# 17. Parse agents.conf with extra columns (7-column: priority + depends_on)
# --------------------------------------------------------------------------
orch_router_init
cat > "$TMPDIR_TEST/agents-7col.conf" <<'CONF'
01-ceo | prompts/01-ceo/01-ceo.txt | docs/strategy | 3 | CEO | claude | 8 | none
06-backend | prompts/06-backend/06-backend.txt | src/core | 1 | Backend | claude | 10 | none
09-qa | prompts/09-qa/09-qa.txt | tests | 3 | QA | claude | 3 | 06-backend
03-pm | prompts/03-pm/03-pm.txt | prompts/03-pm | 1 | PM | claude | 7 | all
CONF
orch_router_parse_config "$TMPDIR_TEST/agents-7col.conf"
d_qa=$(orch_router_get_deps "09-qa")
p_be=$(orch_router_get_priority "06-backend")
d_pm=$(orch_router_get_deps "03-pm")
if [[ "$d_qa" == "06-backend" && "$p_be" == "10" && "$d_pm" == "all" ]]; then
    pass "17. Parse agents.conf with extra columns — priority and depends_on parsed"
else
    fail "17. Parse agents.conf with extra columns — qa_deps='$d_qa' be_pri='$p_be' pm_deps='$d_pm'"
fi

# --------------------------------------------------------------------------
# 18. "all" dependency — agent goes in last group
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "a" "none" 5
orch_router_add_agent "b" "none" 5
orch_router_add_agent "coord" "all" 5
orch_router_build_groups
count=$(orch_router_group_count)
grp_coord=$(orch_router_get_group "coord")
expected_last=$(( count - 1 ))
if [[ "$grp_coord" == "$expected_last" ]]; then
    pass "18. 'all' dependency — coordinator in last group"
else
    fail "18. 'all' dependency — expected group $expected_last, got $grp_coord"
fi

# --------------------------------------------------------------------------
# 19. Multiple deps — agent placed in correct group
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "a" "none" 5
orch_router_add_agent "b" "none" 5
orch_router_add_agent "c" "a,b" 5
orch_router_build_groups
grp_a=$(orch_router_get_group "a")
grp_b=$(orch_router_get_group "b")
grp_c=$(orch_router_get_group "c")
if [[ "$grp_a" == "0" && "$grp_b" == "0" && "$grp_c" == "1" ]]; then
    pass "19. Multiple deps — c after both a and b"
else
    fail "19. Multiple deps — a=$grp_a b=$grp_b c=$grp_c"
fi

# --------------------------------------------------------------------------
# 20. Report runs without error
# --------------------------------------------------------------------------
orch_router_init
orch_router_add_agent "06-backend" "none" 10
orch_router_add_agent "09-qa" "06-backend" 5
orch_router_add_agent "03-pm" "all" 8
orch_router_build_groups
if orch_router_report > /dev/null 2>&1; then
    pass "20. Report runs without error"
else
    fail "20. Report runs without error"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
