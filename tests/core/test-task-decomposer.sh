#!/usr/bin/env bash
# Test: task-decomposer.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/task-decomposer.sh"

echo "=== task-decomposer.sh tests ==="

# Test 1: Module loads
[[ -n "${_ORCH_TASK_DECOMPOSER_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Double-source guard
source "$PROJECT_ROOT/src/core/task-decomposer.sh"
pass "double-source guard"

# Test 3: Priority extraction
[[ $(_orch_task_priority "P0:fix bug") == "0" ]] && pass "priority P0=0" || fail "priority P0=0"
[[ $(_orch_task_priority "P1:add feature") == "1" ]] && pass "priority P1=1" || fail "priority P1=1"
[[ $(_orch_task_priority "P3:nice to have") == "3" ]] && pass "priority P3=3" || fail "priority P3=3"
[[ $(_orch_task_priority "no prefix") == "2" ]] && pass "priority default=2" || fail "priority default=2"

# Test 4: Description extraction
[[ $(_orch_task_description "P0:fix bug") == "fix bug" ]] && pass "description P0" || fail "description P0"
[[ $(_orch_task_description "no prefix") == "no prefix" ]] && pass "description no prefix" || fail "description no prefix"

# Test 5: Select tasks — all fit
orch_select_tasks 5 "P1:task1" "P2:task2" "P0:critical"
[[ $(orch_selected_count) -eq 3 ]] && pass "all fit: 3 selected" || fail "all fit: 3 selected (got $(orch_selected_count))"
[[ $(orch_deferred_count) -eq 0 ]] && pass "all fit: 0 deferred" || fail "all fit: 0 deferred (got $(orch_deferred_count))"

# Test 6: Select tasks — overflow, P0 always included
orch_select_tasks 2 "P0:critical" "P1:high" "P2:medium" "P3:low"
[[ $(orch_selected_count) -eq 3 ]] && pass "overflow: 3 selected (P0 + 2)" || fail "overflow: 3 selected (got $(orch_selected_count))"
[[ $(orch_deferred_count) -eq 1 ]] && pass "overflow: 1 deferred" || fail "overflow: 1 deferred (got $(orch_deferred_count))"

# Test 7: P0 always first in selected
[[ "${_ORCH_SELECTED_TASKS[0]}" == "critical" ]] && pass "P0 first in selected" || fail "P0 first in selected (got '${_ORCH_SELECTED_TASKS[0]}')"

# Test 8: Deferred is lowest priority
[[ "${_ORCH_DEFERRED_TASKS[0]}" == "low" ]] && pass "P3 in deferred" || fail "P3 in deferred (got '${_ORCH_DEFERRED_TASKS[0]}')"

# Test 9: Empty task list
orch_select_tasks 5
[[ $(orch_selected_count) -eq 0 ]] && pass "empty: 0 selected" || fail "empty: 0 selected"
[[ $(orch_deferred_count) -eq 0 ]] && pass "empty: 0 deferred" || fail "empty: 0 deferred"

# Test 10: Multiple P0s
orch_select_tasks 2 "P0:crit1" "P0:crit2" "P0:crit3" "P1:high"
[[ $(orch_selected_count) -ge 3 ]] && pass "multiple P0: all 3 P0s selected" || fail "multiple P0: all 3 P0s selected (got $(orch_selected_count))"

# Test 11: Extract tasks from markdown file
tmpfile=$(mktemp)
cat > "$tmpfile" <<'EOF'
# Agent Prompt

## Current Tasks

- **P0:** Fix critical eval injection
- P1: Add logging module
- P2: Refactor config parser
- [ ] Write documentation

## Done
- P0: Old task that's done
EOF

tasks_output=$(orch_extract_tasks "$tmpfile")
task_count=$(echo "$tasks_output" | grep -c "^P[0-3]:" || true)
[[ $task_count -eq 4 ]] && pass "extract: 4 tasks from markdown" || fail "extract: 4 tasks from markdown (got $task_count)"
rm -f "$tmpfile"

# Test 12: Extract doesn't capture outside task section
tmpfile=$(mktemp)
cat > "$tmpfile" <<'EOF'
# Agent

## Overview
- P0: this should NOT be captured

## Tasks
- P1: this should be captured

## Other Section
- P0: this should NOT be captured
EOF

tasks_output=$(orch_extract_tasks "$tmpfile")
task_count=$(echo "$tasks_output" | grep -c "^P[0-3]:" || true)
[[ $task_count -eq 1 ]] && pass "extract: only task section" || fail "extract: only task section (got $task_count)"
rm -f "$tmpfile"

# Test 13: decompose_tasks end-to-end
tmpfile=$(mktemp)
cat > "$tmpfile" <<'EOF'
## Current Tasks
- **P0:** Critical fix
- P1: Feature A
- P1: Feature B
- P2: Refactor
- P3: Nice to have
EOF

orch_decompose_tasks "$tmpfile" 3
[[ $(orch_selected_count) -ge 3 ]] && pass "decompose: at least 3 selected" || fail "decompose: at least 3 selected (got $(orch_selected_count))"
[[ $(orch_deferred_count) -ge 1 ]] && pass "decompose: at least 1 deferred" || fail "decompose: at least 1 deferred (got $(orch_deferred_count))"
rm -f "$tmpfile"

# Test 14: Case-insensitive priority
[[ $(_orch_task_priority "p0:lowercase") == "0" ]] && pass "priority p0 lowercase" || fail "priority p0 lowercase"
[[ $(_orch_task_priority "p3:lowercase") == "3" ]] && pass "priority p3 lowercase" || fail "priority p3 lowercase"

# Test 15: Task report output
orch_select_tasks 2 "P0:crit" "P1:high" "P3:low"
report=$(orch_task_report "test-agent")
echo "$report" | grep -q "test-agent" && pass "report contains agent id" || fail "report contains agent id"
echo "$report" | grep -q "Selected" && pass "report contains Selected" || fail "report contains Selected"

# Test 16: Extract with numbered list
tmpfile=$(mktemp)
cat > "$tmpfile" <<'EOF'
## Tasks
1. First task
2. Second task
EOF

tasks_output=$(orch_extract_tasks "$tmpfile")
task_count=$(echo "$tasks_output" | grep -c "^P[0-3]:" || true)
[[ $task_count -eq 2 ]] && pass "extract: numbered list" || fail "extract: numbered list (got $task_count)"
rm -f "$tmpfile"

# Test 17: Extract from non-existent file
if ! orch_extract_tasks "/nonexistent/file.txt" 2>/dev/null; then
    pass "extract: non-existent file returns 1"
else
    fail "extract: non-existent file returns 1"
fi

# Test 18: Max tasks = 1 with multiple P0s
orch_select_tasks 1 "P0:crit1" "P0:crit2" "P1:high" "P2:med"
[[ $(orch_selected_count) -eq 3 ]] && pass "max=1 with 2 P0s: 3 selected (2 P0 + 1)" || fail "max=1 with 2 P0s: 3 selected (got $(orch_selected_count))"
[[ $(orch_deferred_count) -eq 1 ]] && pass "max=1 with 2 P0s: 1 deferred" || fail "max=1 with 2 P0s: 1 deferred (got $(orch_deferred_count))"

# Test 19: All same priority
orch_select_tasks 2 "P2:a" "P2:b" "P2:c" "P2:d"
[[ $(orch_selected_count) -eq 2 ]] && pass "same priority: 2 selected" || fail "same priority: 2 selected (got $(orch_selected_count))"
[[ $(orch_deferred_count) -eq 2 ]] && pass "same priority: 2 deferred" || fail "same priority: 2 deferred (got $(orch_deferred_count))"

# Test 20: Description with colons
[[ $(_orch_task_description "P1:fix: something: here") == "fix: something: here" ]] && pass "description with colons" || fail "description with colons"

echo ""
echo "task-decomposer: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
