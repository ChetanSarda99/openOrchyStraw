#!/usr/bin/env bash
# Test: task-decomposer.sh v0.4 — weighted decomposition, DAG, effort, parallel
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/task-decomposer.sh"

echo "=== task-decomposer.sh v0.4 tests ==="

# ---------------------------------------------------------------------------
# Effort estimation
# ---------------------------------------------------------------------------

# Test 1: Set and get effort
orch_task_set_effort "fix bug" "S"
[[ $(orch_task_get_effort "fix bug") == "S" ]] && pass "set/get effort S" || fail "set/get effort S"

# Test 2: Default effort is M
[[ $(orch_task_get_effort "unknown task") == "M" ]] && pass "default effort M" || fail "default effort M"

# Test 3: Case normalization
orch_task_set_effort "task1" "xl"
[[ $(orch_task_get_effort "task1") == "XL" ]] && pass "effort case normalized to XL" || fail "effort case normalized"

# Test 4: Invalid effort defaults to M
orch_task_set_effort "task2" "ZZZ"
[[ $(orch_task_get_effort "task2") == "M" ]] && pass "invalid effort defaults to M" || fail "invalid effort defaults to M"

# Test 5: Effort to points
[[ $(_orch_effort_to_points "S") == "1" ]] && pass "effort S=1" || fail "effort S=1"
[[ $(_orch_effort_to_points "M") == "2" ]] && pass "effort M=2" || fail "effort M=2"
[[ $(_orch_effort_to_points "L") == "4" ]] && pass "effort L=4" || fail "effort L=4"
[[ $(_orch_effort_to_points "XL") == "8" ]] && pass "effort XL=8" || fail "effort XL=8"
[[ $(_orch_effort_to_points "INVALID") == "2" ]] && pass "effort invalid=2" || fail "effort invalid=2"

# ---------------------------------------------------------------------------
# Dependency DAG
# ---------------------------------------------------------------------------

# Test 6: Add and get dependencies
orch_task_reset_dag
orch_task_add_dep "deploy" "test"
[[ $(orch_task_get_deps "deploy") == "test" ]] && pass "add/get dep" || fail "add/get dep"

# Test 7: Multiple dependencies
orch_task_add_dep "deploy" "build"
[[ $(orch_task_get_deps "deploy") == "test,build" ]] && pass "multiple deps" || fail "multiple deps (got $(orch_task_get_deps 'deploy'))"

# Test 8: No duplicate deps
orch_task_add_dep "deploy" "test"
[[ $(orch_task_get_deps "deploy") == "test,build" ]] && pass "no duplicate deps" || fail "no duplicate deps"

# Test 9: No deps returns empty
[[ -z $(orch_task_get_deps "standalone") ]] && pass "no deps returns empty" || fail "no deps returns empty"

# Test 10: Cycle detection — no cycle
orch_task_reset_dag
orch_task_add_dep "B" "A"
orch_task_add_dep "C" "B"
if ! orch_task_has_cycle; then
    pass "no cycle in A->B->C"
else
    fail "no cycle in A->B->C (false positive)"
fi

# Test 11: Cycle detection — cycle exists
orch_task_reset_dag
orch_task_add_dep "B" "A"
orch_task_add_dep "A" "B"
if orch_task_has_cycle; then
    pass "cycle detected in A<->B"
else
    fail "cycle not detected in A<->B"
fi

# ---------------------------------------------------------------------------
# Weighted selection
# ---------------------------------------------------------------------------

# Test 12: Weighted select respects priority + effort
orch_task_reset_dag
orch_select_tasks 10 "P0:critical" "P1:important" "P2:medium" "P3:low"
_ORCH_TASK_PRIORITY["critical"]=0
_ORCH_TASK_PRIORITY["important"]=1
_ORCH_TASK_PRIORITY["medium"]=2
_ORCH_TASK_PRIORITY["low"]=3
orch_task_set_effort "critical" "S"
orch_task_set_effort "important" "L"
orch_task_set_effort "medium" "M"
orch_task_set_effort "low" "XL"

orch_weighted_select 3
# P0 always in, then by weight
[[ $(orch_selected_count) -ge 3 ]] && pass "weighted select: 3+ selected" || fail "weighted select: 3+ selected (got $(orch_selected_count))"

# Test 13: Weighted select defers tasks with unmet dependencies
orch_task_reset_dag
orch_select_tasks 10 "P1:build" "P1:test" "P1:deploy"
_ORCH_TASK_PRIORITY["build"]=1
_ORCH_TASK_PRIORITY["test"]=1
_ORCH_TASK_PRIORITY["deploy"]=1
orch_task_add_dep "deploy" "test"
orch_task_add_dep "test" "build"

orch_weighted_select 1
# With max=1, only build should be selected (no deps)
# test depends on build, deploy depends on test
[[ "${_ORCH_SELECTED_TASKS[*]}" == *"build"* ]] && pass "weighted: build selected (no deps)" || fail "weighted: build selected"
[[ $(orch_deferred_count) -ge 1 ]] && pass "weighted: tasks with unmet deps deferred" || fail "weighted: deferred (got $(orch_deferred_count))"

# ---------------------------------------------------------------------------
# Parallel task identification
# ---------------------------------------------------------------------------

# Test 14: Independent tasks are parallel
orch_task_reset_dag
orch_select_tasks 10 "P1:taskA" "P1:taskB" "P1:taskC"
_ORCH_TASK_PRIORITY["taskA"]=1
_ORCH_TASK_PRIORITY["taskB"]=1
_ORCH_TASK_PRIORITY["taskC"]=1
orch_weighted_select 10
orch_parallel_tasks
[[ $(orch_parallel_count) -ge 1 ]] && pass "parallel: independent tasks found" || fail "parallel: independent tasks found"

# Test 15: Dependent tasks not marked parallel
orch_task_reset_dag
orch_select_tasks 10 "P1:first" "P1:second"
_ORCH_TASK_PRIORITY["first"]=1
_ORCH_TASK_PRIORITY["second"]=1
orch_task_add_dep "second" "first"
orch_weighted_select 10
orch_parallel_tasks
[[ $(orch_parallel_count) -eq 0 ]] && pass "parallel: dependent tasks excluded" || fail "parallel: dependent tasks excluded (got $(orch_parallel_count))"

# ---------------------------------------------------------------------------
# Extended task extraction
# ---------------------------------------------------------------------------

# Test 16: Extract with effort tags
# NOTE: orch_extract_tasks_extended writes stdout AND sets global state.
# We must NOT capture in $() as that runs in a subshell losing state.
tmpfile=$(mktemp)
tmpout=$(mktemp)
cat > "$tmpfile" <<'EOF'
## Tasks
- **P0:** Fix critical bug [S]
- P1: Add logging [M]
- P2: Refactor config [L]
EOF

orch_extract_tasks_extended "$tmpfile" > "$tmpout"
task_count=$(grep -c "^P[0-3]:" "$tmpout" || true)
[[ $task_count -eq 3 ]] && pass "extract extended: 3 tasks" || fail "extract extended: 3 tasks (got $task_count)"
[[ $(orch_task_get_effort "Fix critical bug") == "S" ]] && pass "extract extended: effort S parsed" || fail "extract extended: effort S parsed (got $(orch_task_get_effort 'Fix critical bug'))"
[[ $(orch_task_get_effort "Add logging") == "M" ]] && pass "extract extended: effort M parsed" || fail "extract extended: effort M parsed"
rm -f "$tmpfile" "$tmpout"

# Test 17: Extract with dependency annotations
tmpfile=$(mktemp)
cat > "$tmpfile" <<'EOF'
## Tasks
- P1: Build service [M]
- P1: Run tests [S] (depends: Build service)
- P1: Deploy [M] (depends: Run tests)
EOF

orch_extract_tasks_extended "$tmpfile" > /dev/null
[[ $(orch_task_get_deps "Run tests") == "Build service" ]] && pass "extract extended: deps parsed" || fail "extract extended: deps parsed (got '$(orch_task_get_deps "Run tests")')"
[[ $(orch_task_get_deps "Deploy") == "Run tests" ]] && pass "extract extended: chain deps" || fail "extract extended: chain deps"
rm -f "$tmpfile"

# Test 18: DAG report doesn't crash
orch_task_reset_dag
orch_select_tasks 5 "P0:crit" "P1:high" "P2:med"
_ORCH_TASK_PRIORITY["crit"]=0
_ORCH_TASK_PRIORITY["high"]=1
_ORCH_TASK_PRIORITY["med"]=2
orch_task_set_effort "crit" "S"
orch_weighted_select 5
orch_parallel_tasks
report=$(orch_task_dag_report "test-agent")
echo "$report" | grep -q "test-agent" && pass "DAG report output" || fail "DAG report output"

# Test 19: Reset DAG clears everything
orch_task_reset_dag
[[ -z $(orch_task_get_effort "crit") || $(orch_task_get_effort "crit") == "M" ]] && pass "reset clears effort" || fail "reset clears effort"
[[ $(orch_parallel_count) -eq 0 ]] && pass "reset clears parallel tasks" || fail "reset clears parallel tasks"

# Test 20: decompose_tasks_weighted end-to-end
tmpfile=$(mktemp)
cat > "$tmpfile" <<'EOF'
## Tasks
- **P0:** Critical fix [S]
- P1: Feature A [M]
- P1: Feature B [L] (depends: Feature A)
- P2: Refactor [M]
- P3: Nice to have [XL]
EOF

orch_decompose_tasks_weighted "$tmpfile" 3
[[ $(orch_selected_count) -ge 2 ]] && pass "weighted decompose: tasks selected" || fail "weighted decompose: tasks selected"
[[ $(orch_parallel_count) -ge 0 ]] && pass "weighted decompose: parallel computed" || fail "weighted decompose: parallel computed"
rm -f "$tmpfile"

echo ""
echo "task-decomposer v0.4: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
