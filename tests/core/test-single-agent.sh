#!/usr/bin/env bash
# Test: single-agent.sh — Single-agent mode module (#10)
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

source "$PROJECT_ROOT/src/core/single-agent.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# ---------------------------------------------------------------------------
# Setup: create test configs and prompts
# ---------------------------------------------------------------------------
mkdir -p "$TEST_DIR/prompts/06-backend" "$TEST_DIR/prompts/03-pm"
for i in $(seq 1 35); do echo "line $i" >> "$TEST_DIR/prompts/06-backend/06-backend.txt"; done
for i in $(seq 1 35); do echo "line $i" >> "$TEST_DIR/prompts/03-pm/03-pm.txt"; done

# Single-agent config (1 worker + PM)
cat > "$TEST_DIR/single.conf" <<'EOF'
03-pm     | prompts/03-pm/03-pm.txt         | prompts/ docs/ | 0 | PM Coordinator
06-backend| prompts/06-backend/06-backend.txt| scripts/ src/  | 1 | Backend Developer
EOF

# Multi-agent config (3 workers + PM)
mkdir -p "$TEST_DIR/prompts/11-web" "$TEST_DIR/prompts/09-qa"
for i in $(seq 1 35); do echo "line $i" >> "$TEST_DIR/prompts/11-web/11-web.txt"; done
for i in $(seq 1 35); do echo "line $i" >> "$TEST_DIR/prompts/09-qa/09-qa.txt"; done
cat > "$TEST_DIR/multi.conf" <<'EOF'
03-pm     | prompts/03-pm/03-pm.txt         | prompts/ docs/ | 0 | PM Coordinator
06-backend| prompts/06-backend/06-backend.txt| scripts/ src/  | 1 | Backend Developer
11-web    | prompts/11-web/11-web.txt        | site/          | 1 | Web Developer
09-qa     | prompts/09-qa/09-qa.txt          | tests/         | 3 | QA Engineer
EOF

# PM-only config (no workers)
cat > "$TEST_DIR/pm-only.conf" <<'EOF'
03-pm | prompts/03-pm/03-pm.txt | prompts/ docs/ | 0 | PM Coordinator
EOF

# v3 format config (7 columns)
cat > "$TEST_DIR/v3.conf" <<'EOF'
03-pm     | prompts/03-pm/03-pm.txt         | prompts/ docs/ | 0 | PM Coordinator | opus | 200000
06-backend| prompts/06-backend/06-backend.txt| scripts/ src/  | 1 | Backend Developer | sonnet | 100000
EOF

echo "=== test-single-agent.sh ==="

# ---------------------------------------------------------------------------
# Test 1: init requires project_root
# ---------------------------------------------------------------------------
if orch_single_init "" 2>/dev/null; then
    fail "Test 1: init with empty root should fail"
else
    pass "Test 1: init rejects empty project_root"
fi

# ---------------------------------------------------------------------------
# Test 2: init with nonexistent directory fails
# ---------------------------------------------------------------------------
if orch_single_init "/tmp/nonexistent-$RANDOM-$$" 2>/dev/null; then
    fail "Test 2: init with nonexistent dir should fail"
else
    pass "Test 2: init rejects nonexistent directory"
fi

# ---------------------------------------------------------------------------
# Test 3: init succeeds with valid directory
# ---------------------------------------------------------------------------
# Reset state for fresh init
_ORCH_SINGLE_MODE=0
if orch_single_init "$TEST_DIR" "$TEST_DIR/single.conf" 2>/dev/null; then
    pass "Test 3: init succeeds with valid directory"
else
    fail "Test 3: init should succeed"
fi

# ---------------------------------------------------------------------------
# Test 4: is_active returns true after init
# ---------------------------------------------------------------------------
if orch_single_is_active; then
    pass "Test 4: is_active true after init"
else
    fail "Test 4: should be active after init"
fi

# ---------------------------------------------------------------------------
# Test 5: is_active returns false before init
# ---------------------------------------------------------------------------
_ORCH_SINGLE_MODE=0
if orch_single_is_active; then
    fail "Test 5: should be inactive when mode=0"
else
    pass "Test 5: is_active false when mode=0"
fi
_ORCH_SINGLE_MODE=1  # restore

# ---------------------------------------------------------------------------
# Test 6: detect recommends single-agent for 1 worker
# ---------------------------------------------------------------------------
if orch_single_detect "$TEST_DIR/single.conf" 2>/dev/null; then
    pass "Test 6: detect recommends single-agent (1 worker)"
else
    fail "Test 6: should recommend single-agent for 1 worker config"
fi

# ---------------------------------------------------------------------------
# Test 7: detect recommends multi-agent for 3 workers
# ---------------------------------------------------------------------------
if orch_single_detect "$TEST_DIR/multi.conf" 2>/dev/null; then
    fail "Test 7: should NOT recommend single-agent for 3 workers"
else
    pass "Test 7: detect recommends multi-agent (3 workers)"
fi

# ---------------------------------------------------------------------------
# Test 8: detect fails on missing file
# ---------------------------------------------------------------------------
if orch_single_detect "/tmp/no-such-file-$RANDOM" 2>/dev/null; then
    fail "Test 8: detect should fail on missing file"
else
    pass "Test 8: detect fails on missing agents.conf"
fi

# ---------------------------------------------------------------------------
# Test 9: get_agent auto-selects single worker
# ---------------------------------------------------------------------------
result=$(orch_single_get_agent "$TEST_DIR/single.conf" 2>/dev/null)
if [[ "$result" == "06-backend" ]]; then
    pass "Test 9: get_agent auto-selects 06-backend"
else
    fail "Test 9: expected '06-backend', got '$result'"
fi

# ---------------------------------------------------------------------------
# Test 10: get_agent fails with multiple workers (no explicit ID)
# ---------------------------------------------------------------------------
if result=$(orch_single_get_agent "$TEST_DIR/multi.conf" 2>/dev/null); then
    fail "Test 10: get_agent should fail with 3 workers and no ID"
else
    pass "Test 10: get_agent requires explicit ID for multi-agent config"
fi

# ---------------------------------------------------------------------------
# Test 11: get_agent accepts explicit valid ID
# ---------------------------------------------------------------------------
result=$(orch_single_get_agent "$TEST_DIR/multi.conf" "11-web" 2>/dev/null)
if [[ "$result" == "11-web" ]]; then
    pass "Test 11: get_agent accepts explicit '11-web'"
else
    fail "Test 11: expected '11-web', got '$result'"
fi

# ---------------------------------------------------------------------------
# Test 12: get_agent rejects nonexistent agent ID
# ---------------------------------------------------------------------------
if result=$(orch_single_get_agent "$TEST_DIR/multi.conf" "99-fake" 2>/dev/null); then
    fail "Test 12: get_agent should reject nonexistent ID"
else
    pass "Test 12: get_agent rejects nonexistent agent '99-fake'"
fi

# ---------------------------------------------------------------------------
# Test 13: get_agent fails with PM-only config (no workers)
# ---------------------------------------------------------------------------
if result=$(orch_single_get_agent "$TEST_DIR/pm-only.conf" 2>/dev/null); then
    fail "Test 13: get_agent should fail with no workers"
else
    pass "Test 13: get_agent fails on PM-only config"
fi

# ---------------------------------------------------------------------------
# Test 14: get_agent skips PM (interval=0 agents not selectable)
# ---------------------------------------------------------------------------
if result=$(orch_single_get_agent "$TEST_DIR/single.conf" "03-pm" 2>/dev/null); then
    fail "Test 14: get_agent should reject PM (interval=0)"
else
    pass "Test 14: get_agent rejects PM agent"
fi

# ---------------------------------------------------------------------------
# Test 15: get_config returns correct fields
# ---------------------------------------------------------------------------
config=$(orch_single_get_config "$TEST_DIR/single.conf" "06-backend" 2>/dev/null)
IFS='|' read -r prompt ownership label model <<< "$config"
if [[ "$prompt" == *"06-backend.txt"* && "$ownership" == *"scripts/"* && "$label" == *"Backend"* ]]; then
    pass "Test 15: get_config returns correct prompt/ownership/label"
else
    fail "Test 15: unexpected config: '$config'"
fi

# ---------------------------------------------------------------------------
# Test 16: get_config fails for nonexistent agent
# ---------------------------------------------------------------------------
if orch_single_get_config "$TEST_DIR/single.conf" "99-fake" 2>/dev/null; then
    fail "Test 16: get_config should fail for nonexistent agent"
else
    pass "Test 16: get_config rejects nonexistent agent"
fi

# ---------------------------------------------------------------------------
# Test 17: get_config requires agent_id
# ---------------------------------------------------------------------------
if orch_single_get_config "$TEST_DIR/single.conf" "" 2>/dev/null; then
    fail "Test 17: get_config should require agent_id"
else
    pass "Test 17: get_config rejects empty agent_id"
fi

# ---------------------------------------------------------------------------
# Test 18: skip_module — review-phase should be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "review-phase"; then
    pass "Test 18: review-phase is skipped"
else
    fail "Test 18: review-phase should be skipped"
fi

# ---------------------------------------------------------------------------
# Test 19: skip_module — dynamic-router should be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "dynamic-router"; then
    pass "Test 19: dynamic-router is skipped"
else
    fail "Test 19: dynamic-router should be skipped"
fi

# ---------------------------------------------------------------------------
# Test 20: skip_module — worktree should be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "worktree"; then
    pass "Test 20: worktree is skipped"
else
    fail "Test 20: worktree should be skipped"
fi

# ---------------------------------------------------------------------------
# Test 21: skip_module — conditional-activation should be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "conditional-activation"; then
    pass "Test 21: conditional-activation is skipped"
else
    fail "Test 21: conditional-activation should be skipped"
fi

# ---------------------------------------------------------------------------
# Test 22: skip_module — differential-context should be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "differential-context"; then
    pass "Test 22: differential-context is skipped"
else
    fail "Test 22: differential-context should be skipped"
fi

# ---------------------------------------------------------------------------
# Test 23: skip_module — logger should NOT be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "logger"; then
    fail "Test 23: logger should NOT be skipped"
else
    pass "Test 23: logger is kept"
fi

# ---------------------------------------------------------------------------
# Test 24: skip_module — error-handler should NOT be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "error-handler"; then
    fail "Test 24: error-handler should NOT be skipped"
else
    pass "Test 24: error-handler is kept"
fi

# ---------------------------------------------------------------------------
# Test 25: skip_module — cycle-tracker should NOT be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "cycle-tracker"; then
    fail "Test 25: cycle-tracker should NOT be skipped"
else
    pass "Test 25: cycle-tracker is kept"
fi

# ---------------------------------------------------------------------------
# Test 26: skip_module — prompt-compression should NOT be skipped
# ---------------------------------------------------------------------------
if orch_single_skip_module "prompt-compression"; then
    fail "Test 26: prompt-compression should NOT be skipped"
else
    pass "Test 26: prompt-compression is kept"
fi

# ---------------------------------------------------------------------------
# Test 27: skip_module rejects empty argument
# ---------------------------------------------------------------------------
if orch_single_skip_module "" 2>/dev/null; then
    fail "Test 27: skip_module should reject empty arg"
else
    pass "Test 27: skip_module rejects empty argument"
fi

# ---------------------------------------------------------------------------
# Test 28: skip_module — unknown module is NOT skipped (fail-open)
# ---------------------------------------------------------------------------
if orch_single_skip_module "some-future-module"; then
    fail "Test 28: unknown module should not be skipped"
else
    pass "Test 28: unknown module is kept (fail-open)"
fi

# ---------------------------------------------------------------------------
# Test 29: increment_cycle tracks correctly
# ---------------------------------------------------------------------------
_ORCH_SINGLE_CYCLES_RUN=0
orch_single_increment_cycle
orch_single_increment_cycle
orch_single_increment_cycle
if [[ "$_ORCH_SINGLE_CYCLES_RUN" -eq 3 ]]; then
    pass "Test 29: increment_cycle counts 3 cycles"
else
    fail "Test 29: expected 3, got $_ORCH_SINGLE_CYCLES_RUN"
fi

# ---------------------------------------------------------------------------
# Test 30: set_agent stores agent ID
# ---------------------------------------------------------------------------
orch_single_set_agent "06-backend" 2>/dev/null
if [[ "$_ORCH_SINGLE_AGENT_ID" == "06-backend" ]]; then
    pass "Test 30: set_agent stores ID"
else
    fail "Test 30: expected '06-backend', got '$_ORCH_SINGLE_AGENT_ID'"
fi

# ---------------------------------------------------------------------------
# Test 31: set_agent rejects empty
# ---------------------------------------------------------------------------
if orch_single_set_agent "" 2>/dev/null; then
    fail "Test 31: set_agent should reject empty"
else
    pass "Test 31: set_agent rejects empty ID"
fi

# ---------------------------------------------------------------------------
# Test 32: report outputs status
# ---------------------------------------------------------------------------
report=$(orch_single_report 2>/dev/null)
if echo "$report" | grep -q "ACTIVE" && echo "$report" | grep -q "Skipped" && echo "$report" | grep -q "Active"; then
    pass "Test 32: report shows status, skipped, and active modules"
else
    fail "Test 32: report output incomplete"
fi

# ---------------------------------------------------------------------------
# Test 33: detect with v3 format (7 columns)
# ---------------------------------------------------------------------------
if orch_single_detect "$TEST_DIR/v3.conf" 2>/dev/null; then
    pass "Test 33: detect works with v3 format (7 columns)"
else
    fail "Test 33: detect should work with v3 config"
fi

# ---------------------------------------------------------------------------
# Test 34: get_config with v3 format returns model field
# ---------------------------------------------------------------------------
config=$(orch_single_get_config "$TEST_DIR/v3.conf" "06-backend" 2>/dev/null)
IFS='|' read -r prompt ownership label model <<< "$config"
if [[ "$model" == "sonnet" ]]; then
    pass "Test 34: get_config returns model from v3 format"
else
    fail "Test 34: expected model 'sonnet', got '$model'"
fi

# ---------------------------------------------------------------------------
# Test 35: detect ignores comments and blank lines
# ---------------------------------------------------------------------------
cat > "$TEST_DIR/comments.conf" <<'EOF'
# This is a comment

   # Another comment
03-pm  | prompts/03-pm/03-pm.txt | prompts/ | 0 | PM

06-backend | prompts/06-backend/06-backend.txt | scripts/ | 1 | Backend
EOF
if orch_single_detect "$TEST_DIR/comments.conf" 2>/dev/null; then
    pass "Test 35: detect skips comments and blank lines"
else
    fail "Test 35: detect should find 1 worker ignoring comments"
fi

# ---------------------------------------------------------------------------
# Test 36: double-source guard
# ---------------------------------------------------------------------------
source "$PROJECT_ROOT/src/core/single-agent.sh"
if [[ "$_ORCH_SINGLE_MODE" -eq 1 ]]; then
    pass "Test 36: double-source preserves state"
else
    fail "Test 36: double-source should not reset state"
fi

# ---------------------------------------------------------------------------
# Test 37: get_agent fails when no stored conf and explicit path missing
# ---------------------------------------------------------------------------
_ORCH_SINGLE_CONF_FILE=""
if orch_single_get_agent "" 2>/dev/null; then
    fail "Test 37: get_agent should fail with no conf"
else
    pass "Test 37: get_agent fails when no config available"
fi
_ORCH_SINGLE_CONF_FILE="$TEST_DIR/single.conf"  # restore

# ---------------------------------------------------------------------------
# Test 38: init stores config file path
# ---------------------------------------------------------------------------
_ORCH_SINGLE_MODE=0
orch_single_init "$TEST_DIR" "$TEST_DIR/single.conf" 2>/dev/null
if [[ "$_ORCH_SINGLE_CONF_FILE" == "$TEST_DIR/single.conf" ]]; then
    pass "Test 38: init stores config file path"
else
    fail "Test 38: config path not stored"
fi

# ---------------------------------------------------------------------------
# Test 39: init defaults config to project_root/agents.conf
# ---------------------------------------------------------------------------
_ORCH_SINGLE_MODE=0
orch_single_init "$TEST_DIR" 2>/dev/null
if [[ "$_ORCH_SINGLE_CONF_FILE" == "$TEST_DIR/agents.conf" ]]; then
    pass "Test 39: init defaults config to agents.conf"
else
    fail "Test 39: expected '$TEST_DIR/agents.conf', got '$_ORCH_SINGLE_CONF_FILE'"
fi

# ---------------------------------------------------------------------------
# Test 40: get_agent uses stored conf when no arg
# ---------------------------------------------------------------------------
_ORCH_SINGLE_CONF_FILE="$TEST_DIR/single.conf"
result=$(orch_single_get_agent "" "" 2>/dev/null || true)
# Should use stored conf and find 06-backend
result2=$(orch_single_get_agent 2>/dev/null || true)
if [[ "$result2" == "06-backend" ]]; then
    pass "Test 40: get_agent uses stored conf file"
else
    fail "Test 40: expected '06-backend' from stored conf, got '$result2'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
echo "ALL PASS"
