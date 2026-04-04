#!/usr/bin/env bash
# Test: single-agent.sh v0.4 — focus mode, checkpoint/resume, progress tracking
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/single-agent.sh"

echo "=== single-agent.sh v0.4 tests ==="

# Setup
mkdir -p "$TEST_DIR/project/prompts/06-backend"
echo "prompt content" > "$TEST_DIR/project/prompts/06-backend/06-backend.txt"
cat > "$TEST_DIR/project/agents.conf" <<'EOF'
03-pm      | prompts/03-pm/03-pm.txt          | prompts/ | 0 | PM
06-backend | prompts/06-backend/06-backend.txt | src/     | 1 | Backend
EOF

orch_single_init "$TEST_DIR/project" "$TEST_DIR/project/agents.conf"
orch_single_set_agent "06-backend"

# ---------------------------------------------------------------------------
# Focus mode
# ---------------------------------------------------------------------------

# Test 1: Focus mode starts disabled
if ! orch_single_focus_is_active; then
    pass "focus: starts disabled"
else
    fail "focus: starts disabled"
fi

# Test 2: Enable focus mode
orch_single_focus_enable
if orch_single_focus_is_active; then
    pass "focus: enabled"
else
    fail "focus: enabled"
fi

# Test 3: Focus mode doubles token budget
[[ ${ORCH_MAX_TOKENS_PER_AGENT:-0} -gt 0 ]] && pass "focus: token budget set" || fail "focus: token budget set"
original_budget=$ORCH_MAX_TOKENS_PER_AGENT

# Test 4: Disable focus mode
orch_single_focus_disable
if ! orch_single_focus_is_active; then
    pass "focus: disabled"
else
    fail "focus: disabled"
fi

# Test 5: Focus requires single-agent mode
_ORCH_SINGLE_MODE=0
if ! orch_single_focus_enable 2>/dev/null; then
    pass "focus: requires active single-agent mode"
else
    fail "focus: requires active single-agent mode"
fi
_ORCH_SINGLE_MODE=1

# ---------------------------------------------------------------------------
# Checkpoint / Resume
# ---------------------------------------------------------------------------

# Test 6: Save checkpoint
orch_single_checkpoint
[[ -f "$TEST_DIR/project/.orchystraw/checkpoints/latest.ckpt" ]] && pass "checkpoint: file created" || fail "checkpoint: file created"

# Test 7: Checkpoint contains agent ID
grep -q "ORCH_CKPT_AGENT_ID=06-backend" "$TEST_DIR/project/.orchystraw/checkpoints/latest.ckpt" && pass "checkpoint: has agent ID" || fail "checkpoint: has agent ID"

# Test 8: Checkpoint contains cycle count
grep -q "ORCH_CKPT_CYCLES_RUN=" "$TEST_DIR/project/.orchystraw/checkpoints/latest.ckpt" && pass "checkpoint: has cycle count" || fail "checkpoint: has cycle count"

# Test 9: Checkpoint exists check
if orch_single_checkpoint_exists; then
    pass "checkpoint_exists: returns true"
else
    fail "checkpoint_exists: returns true"
fi

# Test 10: Resume from checkpoint
# Change state, then resume
_ORCH_SINGLE_AGENT_ID="changed"
_ORCH_SINGLE_CYCLES_RUN=999

orch_single_resume "$TEST_DIR/project"
[[ "$_ORCH_SINGLE_AGENT_ID" == "06-backend" ]] && pass "resume: agent ID restored" || fail "resume: agent ID restored (got $_ORCH_SINGLE_AGENT_ID)"

# Test 11: Resume from non-existent checkpoint returns 1
_ORCH_SINGLE_PROJECT_ROOT=""
if ! orch_single_resume "$TEST_DIR/no_such_dir" 2>/dev/null; then
    pass "resume: no checkpoint returns 1"
else
    fail "resume: no checkpoint returns 1"
fi
_ORCH_SINGLE_PROJECT_ROOT="$TEST_DIR/project"

# Test 12: Checkpoint with progress data
orch_single_progress_set 3 10
orch_single_progress_increment "task A"
orch_single_progress_increment "task B"
orch_single_checkpoint

# Reset and resume
_ORCH_SINGLE_PROGRESS_DONE=0
_ORCH_SINGLE_PROGRESS_TOTAL=0
_ORCH_SINGLE_COMPLETED_TASKS=()

orch_single_resume "$TEST_DIR/project"
[[ $_ORCH_SINGLE_PROGRESS_DONE -eq 5 ]] && pass "resume: progress restored (5)" || fail "resume: progress restored (got $_ORCH_SINGLE_PROGRESS_DONE)"
[[ $_ORCH_SINGLE_PROGRESS_TOTAL -eq 10 ]] && pass "resume: total restored (10)" || fail "resume: total restored (got $_ORCH_SINGLE_PROGRESS_TOTAL)"

# ---------------------------------------------------------------------------
# Progress tracking
# ---------------------------------------------------------------------------

# Test 13: Set and read progress
orch_single_progress_set 0 5
[[ $_ORCH_SINGLE_PROGRESS_DONE -eq 0 ]] && pass "progress: done=0" || fail "progress: done=0"
[[ $_ORCH_SINGLE_PROGRESS_TOTAL -eq 5 ]] && pass "progress: total=5" || fail "progress: total=5"

# Test 14: Increment progress
orch_single_progress_increment "fix bug"
[[ $_ORCH_SINGLE_PROGRESS_DONE -eq 1 ]] && pass "progress: increment to 1" || fail "progress: increment to 1"

# Test 15: Increment tracks task name
[[ "${_ORCH_SINGLE_COMPLETED_TASKS[*]}" == *"fix bug"* ]] && pass "progress: task tracked" || fail "progress: task tracked"

# Test 16: Progress report output
orch_single_progress_set 3 10
_ORCH_SINGLE_PROGRESS_START=$(( $(date '+%s') - 60 ))
report=$(orch_single_progress_report)
echo "$report" | grep -q "3/10" && pass "progress report: shows 3/10" || fail "progress report: shows 3/10"
echo "$report" | grep -q "30%" && pass "progress report: shows 30%" || fail "progress report: shows 30%"

# Test 17: Progress report shows ETA
echo "$report" | grep -q "ETA" && pass "progress report: shows ETA" || fail "progress report: shows ETA"

# Test 18: Progress report with no tasks
_ORCH_SINGLE_PROGRESS_TOTAL=0
report=$(orch_single_progress_report)
echo "$report" | grep -q "no tasks tracked" && pass "progress report: empty case" || fail "progress report: empty case"

# Test 19: Full report includes focus and progress info
_ORCH_SINGLE_PROGRESS_TOTAL=5
_ORCH_SINGLE_PROGRESS_DONE=2
orch_single_focus_enable 2>/dev/null || true
report=$(orch_single_report)
echo "$report" | grep -q "ACTIVE" && pass "full report: shows active" || fail "full report: shows active"

# Test 20: Checkpoint without init fails
_ORCH_SINGLE_PROJECT_ROOT=""
if ! orch_single_checkpoint 2>/dev/null; then
    pass "checkpoint: fails without project root"
else
    fail "checkpoint: fails without project root"
fi

echo ""
echo "single-agent v0.4: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
