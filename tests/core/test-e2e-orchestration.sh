#!/usr/bin/env bash
# test-e2e-orchestration.sh — E2E tests for orchestration flows with mocked agents
# Tests config parsing, agent routing, audit logging, health reporting, and dashboard
# generation as an integrated pipeline. No actual Claude calls.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_contains() {
    local desc="$1" pattern="$2" text="$3"
    if echo "$text" | grep -qE "$pattern"; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (pattern "%s" not found)\n' "$desc" "$pattern" >&2
        (( FAIL++ )) || true
    fi
}

assert_not_contains() {
    local desc="$1" pattern="$2" text="$3"
    if ! echo "$text" | grep -qE "$pattern"; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (pattern "%s" should NOT be present)\n' "$desc" "$pattern" >&2
        (( FAIL++ )) || true
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected "%s", got "%s")\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

assert_gt() {
    local desc="$1" threshold="$2" actual="$3"
    if [[ "$actual" -gt "$threshold" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected > %s, got %s)\n' "$desc" "$threshold" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

# ── Setup mock project ──
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/scripts" "$TMPDIR/src/core" "$TMPDIR/.orchystraw"
mkdir -p "$TMPDIR/prompts/00-shared-context" "$TMPDIR/prompts/00-session-tracker"
mkdir -p "$TMPDIR/prompts/06-backend" "$TMPDIR/prompts/03-pm" "$TMPDIR/prompts/09-qa"
git init -q "$TMPDIR"
(cd "$TMPDIR" && git add -A && git commit -q -m "init" --allow-empty)

# Create agents.conf
cat > "$TMPDIR/scripts/agents.conf" << 'CONF'
# id | prompt | ownership | interval | label
03-pm      | prompts/03-pm/03-pm.txt         | prompts/ | 0 | PM Coordinator
06-backend | prompts/06-backend/06-backend.txt | scripts/ src/core/ | 1 | Backend Developer
09-qa      | prompts/09-qa/09-qa.txt          | tests/   | 3 | QA Engineer
CONF

# ══════════════════════════════════════════
# TEST 1: Dynamic router parses config and routes correctly
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 1 — Dynamic router integration\n'

source "$PROJECT_ROOT/src/core/dynamic-router.sh"

orch_router_init "$TMPDIR/scripts/agents.conf"

# Eligible at cycle 1: backend (interval=1) and qa (interval=3, never run = eligible)
eligible_c1=$(orch_router_eligible 1)
assert_contains "backend eligible cycle 1" "06-backend" "$eligible_c1"
assert_contains "qa eligible cycle 1" "09-qa" "$eligible_c1"
assert_not_contains "pm excluded (coordinator)" "03-pm" "$eligible_c1"

# After running backend at cycle 1, check cycle 2
orch_router_update "06-backend" "success" 1
orch_router_update "09-qa" "success" 1
eligible_c2=$(orch_router_eligible 2)
assert_contains "backend eligible cycle 2" "06-backend" "$eligible_c2"
assert_not_contains "qa not eligible cycle 2 (interval=3)" "09-qa" "$eligible_c2"

# QA should be eligible at cycle 4 (1 + 3)
eligible_c4=$(orch_router_eligible 4)
assert_contains "qa eligible cycle 4" "09-qa" "$eligible_c4"

# ══════════════════════════════════════════
# TEST 2: Model fallback chain
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 2 — Model fallback chain\n'

fb1=$(orch_router_model_fallback "opus")
assert_eq "opus falls back to sonnet" "sonnet" "$fb1"

fb2=$(orch_router_model_fallback "sonnet")
assert_eq "sonnet falls back to haiku" "haiku" "$fb2"

fb3=$(orch_router_model_fallback "haiku")
assert_eq "haiku has no fallback" "" "$fb3"

# ══════════════════════════════════════════
# TEST 3: Router state persistence round-trip
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 3 — Router state persistence\n'

STATE_FILE="$TMPDIR/.orchystraw/router-state.txt"
orch_router_save_state "$STATE_FILE"

if [[ -f "$STATE_FILE" ]]; then
    (( PASS++ )) || true
else
    printf '  FAIL: state file not created\n' >&2
    (( FAIL++ )) || true
fi

state_content=$(cat "$STATE_FILE")
assert_contains "state has backend" "06-backend" "$state_content"
assert_contains "state has qa" "09-qa" "$state_content"
assert_contains "state has pm" "03-pm" "$state_content"

# Reinit and reload — verify state survives
_ORCH_DYNAMIC_ROUTER_LOADED=""
source "$PROJECT_ROOT/src/core/dynamic-router.sh"
orch_router_init "$TMPDIR/scripts/agents.conf"
orch_router_load_state "$STATE_FILE"

# Backend should show last_run=1 after reload
eligible_after_reload=$(orch_router_eligible 2)
assert_contains "backend eligible after reload" "06-backend" "$eligible_after_reload"

# ══════════════════════════════════════════
# TEST 4: Audit log pipeline (log → health report → dashboard)
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 4 — Audit pipeline integration\n'

# Create prompt files for audit-log
for agent in 06-backend 09-qa 03-pm; do
    for i in $(seq 1 50); do echo "line $i"; done > "$TMPDIR/prompts/$agent/$agent.txt"
done

# Simulate 3 cycles of agent runs
bash "$PROJECT_ROOT/scripts/audit-log.sh" "06-backend" 1 "success" 5 120 "$TMPDIR/prompts/06-backend/06-backend.txt" "opus" "$TMPDIR"
bash "$PROJECT_ROOT/scripts/audit-log.sh" "09-qa" 1 "success" 2 60 "$TMPDIR/prompts/09-qa/09-qa.txt" "sonnet" "$TMPDIR"
bash "$PROJECT_ROOT/scripts/audit-log.sh" "06-backend" 2 "success" 3 90 "$TMPDIR/prompts/06-backend/06-backend.txt" "opus" "$TMPDIR"
bash "$PROJECT_ROOT/scripts/audit-log.sh" "03-pm" 2 "success" 1 45 "$TMPDIR/prompts/03-pm/03-pm.txt" "haiku" "$TMPDIR"
bash "$PROJECT_ROOT/scripts/audit-log.sh" "06-backend" 3 "fail" 0 30 "$TMPDIR/prompts/06-backend/06-backend.txt" "opus" "$TMPDIR"

AUDIT_FILE="$TMPDIR/.orchystraw/audit.jsonl"
line_count=$(wc -l < "$AUDIT_FILE" | tr -d '[:space:]')
assert_eq "audit has 5 entries" "5" "$line_count"

# Verify cost field present on all lines
cost_lines=$(grep -c "cost_estimate" "$AUDIT_FILE")
assert_eq "all lines have cost_estimate" "5" "$cost_lines"

# Verify different models recorded
assert_contains "opus model recorded" '"model":"opus"' "$(cat "$AUDIT_FILE")"
assert_contains "sonnet model recorded" '"model":"sonnet"' "$(cat "$AUDIT_FILE")"
assert_contains "haiku model recorded" '"model":"haiku"' "$(cat "$AUDIT_FILE")"

# ══════════════════════════════════════════
# TEST 5: Health report reads audit data
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 5 — Health report with audit data\n'

report=$(bash "$PROJECT_ROOT/scripts/agent-health-report.sh" 10 "$TMPDIR" 2>/dev/null)
assert_contains "report has efficiency matrix" "Efficiency Matrix" "$report"
assert_contains "report has cost section" "Cost Tracking" "$report"
assert_contains "report has backend in costs" "06-backend" "$report"
assert_contains "report has model column" "Model" "$report"
assert_contains "report shows total cost" "Total estimated cost" "$report"

# ══════════════════════════════════════════
# TEST 6: Dashboard generates valid HTML from audit data
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 6 — Dashboard HTML generation\n'

# Add metrics.jsonl for dashboard
cat > "$TMPDIR/.orchystraw/metrics.jsonl" << 'METRICS'
{"ts":"2026-04-04T10:00:00Z","cycle":1,"commits":5,"issues_open":22}
{"ts":"2026-04-04T11:00:00Z","cycle":2,"commits":3,"issues_open":20}
{"ts":"2026-04-04T12:00:00Z","cycle":3,"commits":1,"issues_open":19}
METRICS

DASH_OUTPUT="$TMPDIR/.orchystraw/dashboard.html"
bash "$PROJECT_ROOT/scripts/health-dashboard.sh" "$TMPDIR" "$DASH_OUTPUT"

if [[ -f "$DASH_OUTPUT" ]]; then
    (( PASS++ )) || true
else
    printf '  FAIL: dashboard HTML not created\n' >&2
    (( FAIL++ )) || true
fi

html=$(cat "$DASH_OUTPUT")
assert_contains "html has doctype" "DOCTYPE html" "$html"
assert_contains "html has agent grid" "Agent Status Grid" "$html"
assert_contains "html has 06-backend" "06-backend" "$html"
assert_contains "html has cost column" "Est. Cost" "$html"
assert_contains "html has velocity chart" "velocityChart" "$html"

# ══════════════════════════════════════════
# TEST 7: Execution groups (topological sort)
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 7 — Execution groups\n'

groups=$(orch_router_groups)
group_count=$(echo "$groups" | wc -l | tr -d '[:space:]')
assert_gt "at least 1 execution group" 0 "$group_count"

# ══════════════════════════════════════════
# TEST 8: Cycle backoff on empty runs
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 8 — Cycle backoff\n'

# Simulate 4 skip outcomes for qa
orch_router_update "09-qa" "skip" 4
orch_router_update "09-qa" "skip" 7
orch_router_update "09-qa" "skip" 10
orch_router_update "09-qa" "skip" 13

# After 4 skips, effective interval should be > base interval (3)
eligible_c14=$(orch_router_eligible 14)
assert_not_contains "qa backed off after 4 skips" "09-qa" "$eligible_c14"

# ══════════════════════════════════════════
# TEST 9: auto-agent.sh list command
# ══════════════════════════════════════════
printf 'test-e2e-orchestration: Test 9 — List command\n'

list_output=$(ORCH_ROOT="$PROJECT_ROOT" PROJECT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/scripts/auto-agent.sh" list 2>&1) || true
assert_contains "list shows agents" "06-backend" "$list_output"

# ── Results ──
printf '\ntest-e2e-orchestration: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
