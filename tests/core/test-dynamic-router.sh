#!/usr/bin/env bash
# Test: dynamic-router.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/dynamic-router.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── Helper: create a v1 (5-col) agents.conf ──
create_v1_conf() {
    cat > "$TMPDIR_TEST/agents-v1.conf" << 'EOF'
# v1 format (5 columns)
03-pm        | prompts/03-pm/03-pm.txt       | prompts/ docs/     | 0 | PM Coordinator
06-backend   | prompts/06-backend/06-backend.txt | src/core/       | 1 | Backend
09-qa        | prompts/09-qa/09-qa.txt       | tests/             | 3 | QA
02-cto       | prompts/02-cto/02-cto.txt     | docs/architecture/ | 2 | CTO
01-ceo       | prompts/01-ceo/01-ceo.txt     | docs/strategy/     | 3 | CEO
EOF
}

# ── Helper: create a v2 (8-col) agents.conf with dependencies ──
create_v2_conf() {
    cat > "$TMPDIR_TEST/agents-v2.conf" << 'EOF'
# v2 format (8 columns) — with priority, depends_on, reviews
06-backend   | prompts/06-backend/06-backend.txt | src/core/       | 1 | Backend | 10 | none | none
08-pixel     | prompts/08-pixel/08-pixel.txt     | src/pixel/      | 2 | Pixel   | 6  | none | none
09-qa        | prompts/09-qa/09-qa.txt           | tests/          | 3 | QA      | 5  | 06-backend | 06-backend,08-pixel
02-cto       | prompts/02-cto/02-cto.txt         | docs/           | 2 | CTO     | 7  | 06-backend | 06-backend
03-pm        | prompts/03-pm/03-pm.txt           | prompts/        | 0 | PM      | 0  | all | none
EOF
}

# ── Helper: create a conf with circular deps ──
create_circular_conf() {
    cat > "$TMPDIR_TEST/agents-circular.conf" << 'EOF'
agent-a | p.txt | src/ | 1 | A | 5 | agent-b | none
agent-b | p.txt | lib/ | 1 | B | 5 | agent-c | none
agent-c | p.txt | doc/ | 1 | C | 5 | agent-a | none
EOF
}

# ══════════════════════════════════════
# Test 1: Init with v1 config (backward compat)
# ══════════════════════════════════════
create_v1_conf
orch_router_init "$TMPDIR_TEST/agents-v1.conf"
[[ "${#_ORCH_ROUTER_AGENTS[@]}" -eq 5 ]] || { echo "FAIL: T1 expected 5 agents, got ${#_ORCH_ROUTER_AGENTS[@]}"; exit 1; }

# Test 2: v1 agents get default priority=5
[[ "${_ORCH_ROUTER_PRIORITY[06-backend]}" == "5" ]] || { echo "FAIL: T2 default priority not 5"; exit 1; }

# Test 3: v1 agents get depends_on=none
[[ "${_ORCH_ROUTER_DEPENDS[06-backend]}" == "none" ]] || { echo "FAIL: T3 default depends not none"; exit 1; }

# Test 4: Interval parsed correctly
[[ "${_ORCH_ROUTER_INTERVAL[09-qa]}" == "3" ]] || { echo "FAIL: T4 qa interval not 3"; exit 1; }
[[ "${_ORCH_ROUTER_INTERVAL[03-pm]}" == "0" ]] || { echo "FAIL: T4 pm interval not 0"; exit 1; }

# ══════════════════════════════════════
# Test 5: Init with v2 config
# ══════════════════════════════════════
create_v2_conf
orch_router_init "$TMPDIR_TEST/agents-v2.conf"
[[ "${#_ORCH_ROUTER_AGENTS[@]}" -eq 5 ]] || { echo "FAIL: T5 expected 5 agents"; exit 1; }

# Test 6: v2 priority parsed
[[ "${_ORCH_ROUTER_PRIORITY[06-backend]}" == "10" ]] || { echo "FAIL: T6 backend priority not 10"; exit 1; }
[[ "${_ORCH_ROUTER_PRIORITY[09-qa]}" == "5" ]] || { echo "FAIL: T6 qa priority not 5"; exit 1; }

# Test 7: v2 depends_on parsed
[[ "${_ORCH_ROUTER_DEPENDS[09-qa]}" == "06-backend" ]] || { echo "FAIL: T7 qa deps wrong"; exit 1; }
[[ "${_ORCH_ROUTER_DEPENDS[03-pm]}" == "all" ]] || { echo "FAIL: T7 pm deps wrong"; exit 1; }

# ══════════════════════════════════════
# Test 8: No circular dependency in v2 config
# ══════════════════════════════════════
! orch_router_has_cycle || { echo "FAIL: T8 v2 config should have no cycle"; exit 1; }

# Test 9: Circular dependency detected
create_circular_conf
orch_router_init "$TMPDIR_TEST/agents-circular.conf"
orch_router_has_cycle || { echo "FAIL: T9 circular config should have cycle"; exit 1; }

# ══════════════════════════════════════
# Test 10: Execution groups — v2 config
# ══════════════════════════════════════
create_v2_conf
orch_router_init "$TMPDIR_TEST/agents-v2.conf"
groups_output=$(orch_router_groups)
group_count=$(echo "$groups_output" | wc -l)
group_count=$(_orch_router_trim "$group_count")

# Should have 3 groups: {backend,pixel}, {cto,qa}, {pm}
[[ "$group_count" -eq 3 ]] || { echo "FAIL: T10 expected 3 groups, got $group_count"; exit 1; }

# Test 11: Group 0 contains backend and pixel (no deps)
group0=$(echo "$groups_output" | head -1)
[[ "$group0" == *"06-backend"* ]] || { echo "FAIL: T11 group0 missing backend"; exit 1; }
[[ "$group0" == *"08-pixel"* ]] || { echo "FAIL: T11 group0 missing pixel"; exit 1; }

# Test 12: Group 2 (last) is PM
group_last=$(echo "$groups_output" | tail -1)
[[ "$group_last" == "03-pm" ]] || { echo "FAIL: T12 last group should be pm, got '$group_last'"; exit 1; }

# ══════════════════════════════════════
# Test 13: Eligible — cycle 1 (all non-coordinators eligible)
# ══════════════════════════════════════
eligible=$(orch_router_eligible 1)
[[ "$eligible" == *"06-backend"* ]] || { echo "FAIL: T13 backend should be eligible"; exit 1; }
# Coordinator should NOT be in eligible list
[[ "$eligible" != *"03-pm"* ]] || { echo "FAIL: T13 pm should not be eligible"; exit 1; }

# Test 14: Eligible — cycle 1, agents with interval=2 or 3 are eligible (0 last_run)
[[ "$eligible" == *"08-pixel"* ]] || { echo "FAIL: T14 pixel should be eligible cycle 1"; exit 1; }
[[ "$eligible" == *"09-qa"* ]] || { echo "FAIL: T14 qa should be eligible cycle 1"; exit 1; }

# Test 15: After updating backend ran at cycle 1, check cycle 2
orch_router_update "06-backend" "success" 1
orch_router_update "08-pixel" "success" 1
orch_router_update "09-qa" "success" 1
orch_router_update "02-cto" "success" 1

eligible2=$(orch_router_eligible 2)
[[ "$eligible2" == *"06-backend"* ]] || { echo "FAIL: T15 backend should run cycle 2 (interval=1)"; exit 1; }
# pixel has interval=2, last ran cycle 1 → not eligible at cycle 2
[[ "$eligible2" != *"08-pixel"* ]] || { echo "FAIL: T15 pixel should skip cycle 2 (interval=2)"; exit 1; }

# Test 16: Pixel eligible at cycle 3
eligible3=$(orch_router_eligible 3)
[[ "$eligible3" == *"08-pixel"* ]] || { echo "FAIL: T16 pixel should run cycle 3"; exit 1; }

# ══════════════════════════════════════
# Test 17: Fail halves effective interval
# ══════════════════════════════════════
orch_router_update "09-qa" "fail" 2
[[ "${_ORCH_ROUTER_EFF_INTERVAL[09-qa]}" == "1" ]] || { echo "FAIL: T17 fail should halve interval 3→1, got ${_ORCH_ROUTER_EFF_INTERVAL[09-qa]}"; exit 1; }

# Test 18: Success resets to base interval
orch_router_update "09-qa" "success" 3
[[ "${_ORCH_ROUTER_EFF_INTERVAL[09-qa]}" == "3" ]] || { echo "FAIL: T18 success should reset to base 3"; exit 1; }

# Test 19: Skip backs off after 3 consecutive empties
orch_router_update "08-pixel" "skip" 3
orch_router_update "08-pixel" "skip" 5
orch_router_update "08-pixel" "skip" 7
[[ "${_ORCH_ROUTER_CONSEC_EMPTY[08-pixel]}" == "3" ]] || { echo "FAIL: T19 empty count not 3"; exit 1; }
[[ "${_ORCH_ROUTER_EFF_INTERVAL[08-pixel]}" == "4" ]] || { echo "FAIL: T19 should double interval 2→4, got ${_ORCH_ROUTER_EFF_INTERVAL[08-pixel]}"; exit 1; }

# ══════════════════════════════════════
# Test 20: PM force override
# ══════════════════════════════════════
orch_router_update "09-qa" "success" 3
# QA base=3, last_run=3, so not eligible at cycle 4
eligible4=$(orch_router_eligible 4)
[[ "$eligible4" != *"09-qa"* ]] || { echo "FAIL: T20a qa should not be eligible cycle 4"; exit 1; }

# Force it
orch_router_force_agent "09-qa"
eligible4_forced=$(orch_router_eligible 4)
[[ "$eligible4_forced" == *"09-qa"* ]] || { echo "FAIL: T20b qa should be eligible when forced"; exit 1; }

# Test 21: Force flag clears after update
orch_router_update "09-qa" "success" 4
[[ "${_ORCH_ROUTER_PM_FORCE[09-qa]}" == "0" ]] || { echo "FAIL: T21 force should clear after update"; exit 1; }

# ══════════════════════════════════════
# Test 22: Save and load state
# ══════════════════════════════════════
orch_router_save_state "$TMPDIR_TEST/router-state.txt"
[[ -f "$TMPDIR_TEST/router-state.txt" ]] || { echo "FAIL: T22 state file not created"; exit 1; }

# Re-init and load
create_v2_conf
orch_router_init "$TMPDIR_TEST/agents-v2.conf"
# Before load, all last_run should be 0
[[ "${_ORCH_ROUTER_LAST_RUN[06-backend]}" == "0" ]] || { echo "FAIL: T22a fresh init should have last_run=0"; exit 1; }

orch_router_load_state "$TMPDIR_TEST/router-state.txt"
[[ "${_ORCH_ROUTER_LAST_RUN[06-backend]}" == "1" ]] || { echo "FAIL: T22b last_run not restored"; exit 1; }
[[ "${_ORCH_ROUTER_LAST_OUTCOME[06-backend]}" == "success" ]] || { echo "FAIL: T22c outcome not restored"; exit 1; }

# Test 23: Load state for missing agents is ignored
echo "ghost-agent|99|success|1|0" >> "$TMPDIR_TEST/router-state.txt"
orch_router_load_state "$TMPDIR_TEST/router-state.txt"
# Should not crash, ghost-agent is ignored

# Test 24: Load from nonexistent file is a no-op
orch_router_load_state "$TMPDIR_TEST/nonexistent-file.txt"
# Should return 0 without error

# ══════════════════════════════════════
# Test 25: v1 config → all agents in one group (no deps)
# ══════════════════════════════════════
create_v1_conf
orch_router_init "$TMPDIR_TEST/agents-v1.conf"
v1_groups=$(orch_router_groups)
v1_group_count=$(echo "$v1_groups" | wc -l)
v1_group_count=$(_orch_router_trim "$v1_group_count")
[[ "$v1_group_count" -eq 1 ]] || { echo "FAIL: T25 v1 should have 1 group (no deps), got $v1_group_count"; exit 1; }

# Test 26: Dump doesn't crash
orch_router_dump > /dev/null 2>&1 || { echo "FAIL: T26 dump should not crash"; exit 1; }

# ══════════════════════════════════════
# Test 27-36: Model tiering (#46 MODEL-001)
# ══════════════════════════════════════

# ── Helper: v2+ config with model column (9 cols) ──
create_v2_model_conf() {
    cat > "$TMPDIR_TEST/agents-model.conf" << 'EOF'
# 9-col format: id | prompt | ownership | interval | label | priority | depends_on | reviews | model
06-backend   | prompts/06-backend/06-backend.txt | src/core/       | 1 | Backend | 10 | none | none | sonnet
09-qa        | prompts/09-qa/09-qa.txt           | tests/          | 3 | QA      | 5  | 06-backend | 06-backend | opus
01-ceo       | prompts/01-ceo/01-ceo.txt         | docs/strategy/  | 3 | CEO     | 3  | none | none | opus
03-pm        | prompts/03-pm/03-pm.txt           | prompts/        | 0 | PM      | 0  | all | none | sonnet
13-hr        | prompts/13-hr/13-hr.txt           | docs/team/      | 3 | HR      | 2  | none | none | haiku
EOF
}

# Test 27: v2+ config parses model column
create_v2_model_conf
orch_router_init "$TMPDIR_TEST/agents-model.conf"
[[ "${_ORCH_ROUTER_MODEL[06-backend]}" == "sonnet" ]] || { echo "FAIL: T27 backend model not sonnet, got '${_ORCH_ROUTER_MODEL[06-backend]}'"; exit 1; }
[[ "${_ORCH_ROUTER_MODEL[09-qa]}" == "opus" ]] || { echo "FAIL: T27 qa model not opus"; exit 1; }
[[ "${_ORCH_ROUTER_MODEL[13-hr]}" == "haiku" ]] || { echo "FAIL: T27 hr model not haiku"; exit 1; }

# Test 28: orch_router_model returns correct flag
model_flag=$(orch_router_model "06-backend")
[[ "$model_flag" == "claude-sonnet-4-6" ]] || { echo "FAIL: T28 backend flag wrong: $model_flag"; exit 1; }

model_flag_qa=$(orch_router_model "09-qa")
[[ "$model_flag_qa" == "claude-opus-4-6" ]] || { echo "FAIL: T28 qa flag wrong: $model_flag_qa"; exit 1; }

model_flag_hr=$(orch_router_model "13-hr")
[[ "$model_flag_hr" == "claude-haiku-4-5" ]] || { echo "FAIL: T28 hr flag wrong: $model_flag_hr"; exit 1; }

# Test 29: orch_router_model_name returns abstract name
model_name=$(orch_router_model_name "06-backend")
[[ "$model_name" == "sonnet" ]] || { echo "FAIL: T29 backend model name wrong: $model_name"; exit 1; }

# Test 30: v2 (8-col, no model) defaults to ORCH_DEFAULT_MODEL
create_v2_conf
orch_router_init "$TMPDIR_TEST/agents-v2.conf"
[[ "${_ORCH_ROUTER_MODEL[06-backend]}" == "opus" ]] || { echo "FAIL: T30 default model not opus: ${_ORCH_ROUTER_MODEL[06-backend]}"; exit 1; }

# Test 31: v1 (5-col) also defaults
create_v1_conf
orch_router_init "$TMPDIR_TEST/agents-v1.conf"
[[ "${_ORCH_ROUTER_MODEL[06-backend]}" == "opus" ]] || { echo "FAIL: T31 v1 default model not opus"; exit 1; }

# Test 32: CLI override takes precedence
create_v2_model_conf
orch_router_init "$TMPDIR_TEST/agents-model.conf"
ORCH_MODEL_CLI_OVERRIDE=haiku
resolved=$(orch_router_model "06-backend")
[[ "$resolved" == "claude-haiku-4-5" ]] || { echo "FAIL: T32 CLI override not applied: $resolved"; exit 1; }
unset ORCH_MODEL_CLI_OVERRIDE

# Test 33: Per-agent env var override beats CLI
create_v2_model_conf
orch_router_init "$TMPDIR_TEST/agents-model.conf"
ORCH_MODEL_CLI_OVERRIDE=haiku
ORCH_MODEL_OVERRIDE_06_BACKEND=opus
resolved=$(orch_router_model "06-backend")
[[ "$resolved" == "claude-opus-4-6" ]] || { echo "FAIL: T33 per-agent override not applied: $resolved"; exit 1; }
unset ORCH_MODEL_CLI_OVERRIDE
unset ORCH_MODEL_OVERRIDE_06_BACKEND

# Test 34: Unknown model passes through (forward compat)
cat > "$TMPDIR_TEST/agents-future.conf" << 'EOF'
06-backend | p.txt | src/ | 1 | Backend | 10 | none | none | gemini-pro
EOF
orch_router_init "$TMPDIR_TEST/agents-future.conf"
resolved=$(orch_router_model "06-backend" 2>/dev/null)
[[ "$resolved" == "gemini-pro" ]] || { echo "FAIL: T34 unknown model not passed through: $resolved"; exit 1; }

# Test 35: model_name with env override
create_v2_model_conf
orch_router_init "$TMPDIR_TEST/agents-model.conf"
ORCH_MODEL_OVERRIDE_09_QA=sonnet
resolved_name=$(orch_router_model_name "09-qa")
[[ "$resolved_name" == "sonnet" ]] || { echo "FAIL: T35 override model_name wrong: $resolved_name"; exit 1; }
unset ORCH_MODEL_OVERRIDE_09_QA

# Test 36: Dump includes model column
create_v2_model_conf
orch_router_init "$TMPDIR_TEST/agents-model.conf"
dump_output=$(orch_router_dump)
[[ "$dump_output" == *"MODEL"* ]] || { echo "FAIL: T36 dump missing MODEL header"; exit 1; }
[[ "$dump_output" == *"sonnet"* ]] || { echo "FAIL: T36 dump missing sonnet value"; exit 1; }

# ══════════════════════════════════════
# Test 37: BUG-014 — Duplicate deps don't inflate in-degree
# ══════════════════════════════════════
cat > "$TMPDIR_TEST/agents-dup-deps.conf" << 'EOF'
06-backend | p.txt | src/ | 1 | Backend | 10 | none | none
09-qa      | p.txt | tests/ | 3 | QA | 5 | 06-backend,06-backend,06-backend | none
03-pm      | p.txt | prompts/ | 0 | PM | 0 | all | none
EOF
orch_router_init "$TMPDIR_TEST/agents-dup-deps.conf"
# Should NOT detect a cycle — deduplication keeps graph clean
! orch_router_has_cycle || { echo "FAIL: T37a dup deps should not cause cycle"; exit 1; }
# Groups should still be correct: {backend}, {qa}, {pm}
dup_groups=$(orch_router_groups)
dup_group0=$(echo "$dup_groups" | head -1)
[[ "$dup_group0" == *"06-backend"* ]] || { echo "FAIL: T37b group0 should have backend"; exit 1; }
dup_group1=$(echo "$dup_groups" | sed -n '2p')
[[ "$dup_group1" == *"09-qa"* ]] || { echo "FAIL: T37c group1 should have qa, got '$dup_group1'"; exit 1; }

# ══════════════════════════════════════
# Test 38: BUG-015 — Non-numeric priority defaults to 5
# ══════════════════════════════════════
cat > "$TMPDIR_TEST/agents-bad-pri.conf" << 'EOF'
06-backend | p.txt | src/ | 1 | Backend | high | none | none
09-qa      | p.txt | tests/ | 3 | QA | abc | none | none
01-ceo     | p.txt | docs/ | 3 | CEO | 10 | none | none
EOF
orch_router_init "$TMPDIR_TEST/agents-bad-pri.conf"
[[ "${_ORCH_ROUTER_PRIORITY[06-backend]}" == "5" ]] || { echo "FAIL: T38a 'high' should default to 5, got '${_ORCH_ROUTER_PRIORITY[06-backend]}'"; exit 1; }
[[ "${_ORCH_ROUTER_PRIORITY[09-qa]}" == "5" ]] || { echo "FAIL: T38b 'abc' should default to 5, got '${_ORCH_ROUTER_PRIORITY[09-qa]}'"; exit 1; }
[[ "${_ORCH_ROUTER_PRIORITY[01-ceo]}" == "10" ]] || { echo "FAIL: T38c numeric 10 should stay 10"; exit 1; }

# ══════════════════════════════════════
# Test 39: BUG-016 — Unknown dep emits warning (doesn't crash)
# ══════════════════════════════════════
cat > "$TMPDIR_TEST/agents-unknown-dep.conf" << 'EOF'
06-backend | p.txt | src/ | 1 | Backend | 10 | none | none
09-qa      | p.txt | tests/ | 3 | QA | 5 | 06-backend,ghost-agent | none
EOF
orch_router_init "$TMPDIR_TEST/agents-unknown-dep.conf"
# Should not crash, should not detect cycle
! orch_router_has_cycle || { echo "FAIL: T39a unknown dep should not cause cycle"; exit 1; }
# QA should still depend on backend (unknown dep ignored for graph)
groups_unk=$(orch_router_groups)
unk_group0=$(echo "$groups_unk" | head -1)
[[ "$unk_group0" == "06-backend" ]] || { echo "FAIL: T39b group0 should be backend only, got '$unk_group0'"; exit 1; }
unk_group1=$(echo "$groups_unk" | sed -n '2p')
[[ "$unk_group1" == "09-qa" ]] || { echo "FAIL: T39c group1 should be qa, got '$unk_group1'"; exit 1; }

echo "test-dynamic-router.sh: ALL PASS (39 tests)"
