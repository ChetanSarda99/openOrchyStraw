#!/usr/bin/env bash
# Test: conditional-activation.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/conditional-activation.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; exit 1; }

# Create a test config
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/agents.conf" << 'CONF'
# test agents.conf
03-pm        | prompts/03-pm/03-pm.txt             | prompts/ docs/                          | 0 | PM Coordinator
06-backend   | prompts/06-backend/06-backend.txt   | scripts/ src/core/ src/lib/             | 1 | Backend
09-qa        | prompts/09-qa/09-qa.txt             | tests/ reports/                          | 3 | QA
11-web       | prompts/11-web/11-web.txt           | site/                                    | 1 | Web
02-cto       | prompts/02-cto/02-cto.txt           | docs/architecture/                       | 2 | CTO
CONF

# ── Test 1: Init ──
orch_activation_init "$TEST_DIR/agents.conf"
[[ "$_ORCH_ACTIVATION_LOADED" == "true" ]] || fail "T1: not loaded"
pass "T1: init loads config"

# ── Test 2: Coordinator excluded ──
for id in "${_ORCH_ACTIVATION_AGENTS[@]}"; do
    [[ "$id" != "03-pm" ]] || fail "T2: coordinator should be excluded"
done
pass "T2: coordinator (interval=0) excluded"

# ── Test 3: Agent count ──
[[ "${#_ORCH_ACTIVATION_AGENTS[@]}" == "4" ]] || fail "T3: expected 4 agents, got ${#_ORCH_ACTIVATION_AGENTS[@]}"
pass "T3: 4 non-coordinator agents loaded"

# ── Test 4: Ownership parsed ──
[[ "${_ORCH_ACTIVATION_OWNERSHIP[06-backend]}" == *"src/core/"* ]] || fail "T4: backend ownership missing src/core/"
pass "T4: ownership paths parsed"

# ── Test 5: No changes, no context → skip ──
orch_activation_set_changed ""
orch_activation_set_context ""
orch_activation_check "06-backend" && fail "T5: should skip with no changes"
pass "T5: no changes + no context -> skip"

# ── Test 6: Reason recorded for skip ──
reason=$(orch_activation_reason "06-backend")
[[ "$reason" == *"No changes"* ]] || fail "T6: skip reason not recorded (got: $reason)"
pass "T6: skip reason recorded"

# ── Test 7: PM force flag overrides ──
orch_activation_check "06-backend" "1" || fail "T7: PM force should activate"
pass "T7: PM force flag -> activated"

# ── Test 8: Force reason recorded ──
reason=$(orch_activation_reason "06-backend")
[[ "$reason" == *"PM force"* ]] || fail "T8: force reason wrong (got: $reason)"
pass "T8: PM force reason recorded"

# ── Test 9: Changed files in owned path → activate ──
orch_activation_set_changed "src/core/logger.sh
src/core/new-module.sh
README.md"
orch_activation_check "06-backend" || fail "T9: should activate on owned file change"
pass "T9: changed file in owned path -> activated"

# ── Test 10: Changed files NOT in owned path → skip ──
orch_activation_set_changed "site/index.tsx
site/package.json"
orch_activation_check "06-backend" && fail "T10: should skip when no owned files changed"
pass "T10: changes outside owned paths -> skip"

# ── Test 11: Web agent activated by site/ changes ──
orch_activation_check "11-web" || fail "T11: web should activate on site/ changes"
pass "T11: web agent activated by site/ changes"

# ── Test 12: QA activated by tests/ changes ──
orch_activation_set_changed "tests/core/test-new.sh"
orch_activation_check "09-qa" || fail "T12: QA should activate on tests/ changes"
pass "T12: QA activated by tests/ changes"

# ── Test 13: CTO activated by docs/architecture/ changes ──
orch_activation_set_changed "docs/architecture/new-adr.md"
orch_activation_check "02-cto" || fail "T13: CTO should activate on docs/architecture/ changes"
pass "T13: CTO activated by docs/architecture/ changes"

# ── Test 14: CTO NOT activated by docs/strategy/ changes ──
orch_activation_set_changed "docs/strategy/memo.md"
orch_activation_check "02-cto" && fail "T14: CTO should NOT activate on docs/strategy/"
pass "T14: CTO not activated by docs/strategy/"

# ── Test 15: Context mention activates agent ──
orch_activation_set_changed ""
orch_activation_set_context "## Blockers
- NEED: backend to fix the API endpoint
- 06-backend should prioritize this"
orch_activation_check "06-backend" || fail "T15: context mention should activate"
pass "T15: context mention activates agent"

# ── Test 16: Context mention reason ──
reason=$(orch_activation_reason "06-backend")
[[ "$reason" == *"context"* ]] || fail "T16: reason should mention context (got: $reason)"
pass "T16: context mention reason recorded"

# ── Test 17: No mention in context → skip ──
orch_activation_set_context "## Backend Status
- All good, nothing needed"
orch_activation_check "09-qa" && fail "T17: QA should skip with no mention"
pass "T17: no mention in context -> skip"

# ── Test 18: Agent ID in context activates ──
orch_activation_set_context "Waiting for 09-qa to verify the fix"
orch_activation_check "09-qa" || fail "T18: direct agent ID mention should activate"
pass "T18: direct agent ID mention activates"

# ── Test 19: Stats output ──
# Run checks on all agents first
orch_activation_set_changed "src/core/test.sh"
orch_activation_set_context ""
for id in "${_ORCH_ACTIVATION_AGENTS[@]}"; do
    orch_activation_check "$id" 2>/dev/null || true
done
stats=$(orch_activation_stats)
[[ "$stats" == *"conditional-activation summary"* ]] || fail "T19: stats missing header"
[[ "$stats" == *"totals:"* ]] || fail "T19: stats missing totals"
pass "T19: stats output format correct"

# ── Test 20: Init with missing file fails ──
orch_activation_init "$TEST_DIR/nonexistent.conf" 2>/dev/null && fail "T20: should fail on missing file"
pass "T20: missing config file returns error"

# ── Test 21: Multiple changed files, mixed ownership ──
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed "src/core/logger.sh
site/index.tsx
tests/core/test-new.sh
docs/architecture/adr.md
random/file.txt"
orch_activation_set_context ""

orch_activation_check "06-backend" || fail "T21a: backend should activate"
orch_activation_check "11-web" || fail "T21b: web should activate"
orch_activation_check "09-qa" || fail "T21c: QA should activate"
orch_activation_check "02-cto" || fail "T21d: CTO should activate"
pass "T21: multiple agents activated by their owned files"

# ── Test 22: Ownership with exclusions ──
cat > "$TEST_DIR/agents-excl.conf" << 'CONF'
06-backend | prompts/06-backend/06-backend.txt | scripts/ src/core/ !scripts/auto-agent.sh | 1 | Backend
CONF
orch_activation_init "$TEST_DIR/agents-excl.conf"
orch_activation_set_changed "scripts/auto-agent.sh"
orch_activation_set_context ""
orch_activation_check "06-backend" && fail "T22: excluded file should not activate"
pass "T22: excluded path respected"

# ── Test 23: Non-excluded file in same dir activates ──
orch_activation_set_changed "scripts/helper.sh"
orch_activation_check "06-backend" || fail "T23: non-excluded scripts/ file should activate"
pass "T23: non-excluded file in same dir activates"

# ── Test 24: Empty changed files string ──
orch_activation_set_changed ""
orch_activation_set_context ""
orch_activation_check "06-backend" && fail "T24: empty changes should skip"
pass "T24: empty changed files -> skip"

# ── Test 25: Activation decision stored ──
[[ "${_ORCH_ACTIVATION_DECISION[06-backend]}" == "skip" ]] || fail "T25: decision not stored"
pass "T25: decision stored in state"

# ══════════════════════════════════════
# v0.3 Tests: Dependencies, Triggers, Cooldowns
# ══════════════════════════════════════

# Reset state for v0.3 tests
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed ""
orch_activation_set_context ""

# ── Test 26: Dependency activation ──
orch_activation_set_deps "09-qa" "06-backend"
# First activate backend (via file change)
orch_activation_set_changed "src/core/router.sh"
orch_activation_check "06-backend" || fail "T26a: backend should activate"
# Now QA should activate because its dependency (backend) activated
orch_activation_set_changed ""  # no QA files changed
orch_activation_check "09-qa" || fail "T26b: qa should activate (dependency)"
reason=$(orch_activation_reason "09-qa")
[[ "$reason" == *"Dependency"* || "$reason" == *"dependency"* ]] || fail "T26c: reason should mention dependency, got '$reason'"
pass "T26: dependency activation works"

# ── Test 27: No dependency activation when dep not activated ──
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed ""
orch_activation_set_context ""
orch_activation_set_deps "09-qa" "06-backend"
# Don't activate backend
orch_activation_check "09-qa" && fail "T27: qa should skip when dep not activated"
pass "T27: no false dependency activation"

# ── Test 28: Event trigger ──
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed ""
orch_activation_set_context ""
orch_activation_add_trigger "deploy" "06-backend" "09-qa"
orch_activation_fire_event "deploy"
orch_activation_check "06-backend" || fail "T28a: backend should activate on deploy event"
orch_activation_check "09-qa" || fail "T28b: qa should activate on deploy event"
pass "T28: event trigger activates registered agents"

# ── Test 29: Unfired event doesn't activate ──
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed ""
orch_activation_set_context ""
orch_activation_add_trigger "release" "06-backend"
# Don't fire the event
orch_activation_check "06-backend" && fail "T29: should skip when event not fired"
pass "T29: unfired event doesn't activate"

# ── Test 30: Clear events between cycles ──
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed ""
orch_activation_set_context ""
orch_activation_add_trigger "test-event" "06-backend"
orch_activation_fire_event "test-event"
orch_activation_clear_events
orch_activation_check "06-backend" && fail "T30: cleared event should not activate"
pass "T30: clear_events prevents activation"

# ── Test 31: Cooldown blocks activation ──
orch_activation_init "$TEST_DIR/agents.conf"
orch_activation_set_changed "src/core/router.sh"
orch_activation_set_context ""
orch_activation_set_cooldown "06-backend" 3600  # 1 hour cooldown
orch_activation_check "06-backend" && fail "T31: should skip during cooldown"
reason_cd=$(orch_activation_reason "06-backend")
[[ "$reason_cd" == *"cooldown"* || "$reason_cd" == *"Cooldown"* ]] || fail "T31b: reason should mention cooldown, got '$reason_cd'"
pass "T31: cooldown blocks activation"

# ── Test 32: Force overrides cooldown ──
orch_activation_check "06-backend" "1" || fail "T32: PM force should override cooldown"
pass "T32: PM force overrides cooldown"

# ── Test 33: Clear cooldown ──
orch_activation_clear_cooldown "06-backend"
orch_activation_check "06-backend" || fail "T33: should activate after cooldown cleared"
pass "T33: clear_cooldown allows activation"

# ── Test 34: in_cooldown check ──
orch_activation_set_cooldown "09-qa" 3600
orch_activation_in_cooldown "09-qa" || fail "T34a: should be in cooldown"
orch_activation_clear_cooldown "09-qa"
orch_activation_in_cooldown "09-qa" && fail "T34b: should not be in cooldown after clear"
pass "T34: in_cooldown correctly reports state"

# ── Test 35: Activation history tracking ──
count="${_ORCH_ACTIVATION_HISTORY_COUNT[06-backend]:-0}"
[[ "$count" -gt 0 ]] || fail "T35: activation count should be > 0, got $count"
pass "T35: activation history tracked ($count activations)"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════"
echo "  conditional-activation.sh: $PASS PASSED, $FAIL FAILED"
echo "═══════════════════════════════════════"
[[ "$FAIL" -eq 0 ]] || exit 1
