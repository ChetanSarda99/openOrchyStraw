#!/usr/bin/env bash
# Test: differential-context.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/differential-context.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; exit 1; }

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Create test context file
cat > "$TEST_DIR/context.md" << 'CTX'
# Shared Context — Cycle 8 — 2026-03-29
> Agents: read before starting, append before finishing.

## Usage
- API status: 0

## Progress (last cycle → this cycle)
- Previous cycle: 7 (0 backend, 0 frontend, 2 commits)

## Backend Status
- NEW: src/core/prompt-compression.sh — tiered prompt loading
- Full test suite: 16/16 pass

## iOS Status
- Swift UI migration in progress
- Core Data schema updated

## Design Status
- 11-Web: Terminal animation added to hero
- 08-Pixel: Character sprites completed

## QA Findings
- BUG-018: flaky test in cycle-tracker
- All 203 tests pass

## Blockers
- v0.1.0 STILL UNTAGGED

## Notes
- [PM] CTO has 3 module reviews queued
CTX

# Create test agents.conf with v2+ format (7 columns)
cat > "$TEST_DIR/agents-v2.conf" << 'CONF'
# test agents.conf v2
03-pm        | prompts/03-pm/03-pm.txt             | prompts/ docs/               | 0 | PM         | 0  | all
06-backend   | prompts/06-backend/06-backend.txt   | scripts/ src/core/ src/lib/  | 1 | Backend    | 10 | none
09-qa        | prompts/09-qa/09-qa.txt             | tests/ reports/              | 3 | QA         | 5  | 06-backend
11-web       | prompts/11-web/11-web.txt           | site/                        | 1 | Web        | 8  | none
02-cto       | prompts/02-cto/02-cto.txt           | docs/architecture/           | 2 | CTO        | 7  | none
07-ios       | prompts/07-ios/07-ios.txt           | ios/                         | 1 | iOS        | 8  | none
CONF

# Simple v1 config for basic tests
cat > "$TEST_DIR/agents-v1.conf" << 'CONF'
03-pm        | prompts/03-pm/03-pm.txt             | prompts/ docs/               | 0 | PM
06-backend   | prompts/06-backend/06-backend.txt   | scripts/ src/core/ src/lib/  | 1 | Backend
09-qa        | prompts/09-qa/09-qa.txt             | tests/ reports/              | 3 | QA
CONF

# ── Test 1: Init with defaults ──
orch_diffctx_init
[[ "$_ORCH_DIFFCTX_INITIALIZED" == "true" ]] || fail "T1: not initialized"
pass "T1: init sets up default mappings"

# ── Test 2: Default mappings present ──
[[ "${_ORCH_DIFFCTX_MAPPINGS[blockers]}" == "*" ]] || fail "T2: blockers not universal"
[[ "${_ORCH_DIFFCTX_MAPPINGS[notes]}" == "*" ]] || fail "T2: notes not universal"
[[ "${_ORCH_DIFFCTX_MAPPINGS[backend-status]}" == *"06-backend"* ]] || fail "T2: backend-status missing 06-backend"
pass "T2: default mappings correct"

# ── Test 3: Init with v2 config parses deps ──
orch_diffctx_init "$TEST_DIR/agents-v2.conf"
[[ "${_ORCH_DIFFCTX_DEPS[09-qa]:-}" == *"06-backend"* ]] || fail "T3: qa deps not parsed (got: ${_ORCH_DIFFCTX_DEPS[09-qa]:-empty})"
pass "T3: v2 config dependencies parsed"

# ── Test 4: Init with v1 config (no deps) ──
orch_diffctx_init "$TEST_DIR/agents-v1.conf"
[[ -z "${_ORCH_DIFFCTX_DEPS[09-qa]:-}" ]] || fail "T4: v1 should have no deps"
pass "T4: v1 config works without deps"

# ── Test 5: Parse context file ──
orch_diffctx_init
orch_diffctx_parse "$TEST_DIR/context.md"
[[ "$_ORCH_DIFFCTX_SEC_COUNT" -gt 0 ]] || fail "T5: no sections parsed"
pass "T5: context file parsed ($_ORCH_DIFFCTX_SEC_COUNT sections)"

# ── Test 6: Section count ──
# Expected: preamble + Usage + Progress + Backend Status + iOS Status + Design Status + QA Findings + Blockers + Notes = 9
[[ "$_ORCH_DIFFCTX_SEC_COUNT" -eq 9 ]] || fail "T6: expected 9 sections, got $_ORCH_DIFFCTX_SEC_COUNT"
pass "T6: correct section count (9)"

# ── Test 7: Section keys normalized ──
found_backend=false
for ((i = 0; i < _ORCH_DIFFCTX_SEC_COUNT; i++)); do
    if [[ "${_ORCH_DIFFCTX_SEC_KEYS[$i]}" == "backend-status" ]]; then
        found_backend=true
    fi
done
[[ "$found_backend" == "true" ]] || fail "T7: backend-status key not found"
pass "T7: section keys normalized correctly"

# ── Test 8: Filter for backend agent ──
output=$(orch_diffctx_filter "06-backend")
[[ "$output" == *"Backend Status"* ]] || fail "T8: backend should see Backend Status"
[[ "$output" == *"Blockers"* ]] || fail "T8: backend should see Blockers"
pass "T8: backend sees relevant sections"

# ── Test 9: Backend doesn't see iOS Status ──
output=$(orch_diffctx_filter "06-backend")
[[ "$output" != *"iOS Status"* ]] || fail "T9: backend should NOT see iOS Status"
pass "T9: backend excluded from iOS Status"

# ── Test 10: Backend doesn't see Design Status ──
[[ "$output" != *"Design Status"* ]] || fail "T10: backend should NOT see Design Status"
pass "T10: backend excluded from Design Status"

# ── Test 11: PM gets everything ──
pm_output=$(orch_diffctx_filter "03-pm")
[[ "$pm_output" == *"Backend Status"* ]] || fail "T11: PM should see Backend Status"
[[ "$pm_output" == *"iOS Status"* ]] || fail "T11: PM should see iOS Status"
[[ "$pm_output" == *"Design Status"* ]] || fail "T11: PM should see Design Status"
pass "T11: PM gets all sections"

# ── Test 12: Universal sections reach everyone ──
for agent in "06-backend" "09-qa" "11-web" "02-cto"; do
    out=$(orch_diffctx_filter "$agent")
    [[ "$out" == *"Blockers"* ]] || fail "T12: $agent should see Blockers"
    [[ "$out" == *"Notes"* ]] || fail "T12: $agent should see Notes"
    [[ "$out" == *"Usage"* ]] || fail "T12: $agent should see Usage"
done
pass "T12: universal sections reach all agents"

# ── Test 13: QA Findings is universal ──
for agent in "06-backend" "11-web"; do
    out=$(orch_diffctx_filter "$agent")
    [[ "$out" == *"QA Findings"* ]] || fail "T13: $agent should see QA Findings"
done
pass "T13: QA Findings is universal"

# ── Test 14: CTO sees Backend Status ──
cto_output=$(orch_diffctx_filter "02-cto")
[[ "$cto_output" == *"Backend Status"* ]] || fail "T14: CTO should see Backend Status"
pass "T14: CTO sees Backend Status"

# ── Test 15: Web agent sees Design Status but not Backend/iOS ──
web_output=$(orch_diffctx_filter "11-web")
[[ "$web_output" == *"Design Status"* ]] || fail "T15: web should see Design Status"
[[ "$web_output" != *"Backend Status"* ]] || fail "T15: web should NOT see Backend Status"
[[ "$web_output" != *"iOS Status"* ]] || fail "T15: web should NOT see iOS Status"
pass "T15: web gets Design but not Backend/iOS"

# ── Test 16: Custom mapping override ──
orch_diffctx_add_mapping "ios-status" "*"
ios_out=$(orch_diffctx_filter "06-backend")
[[ "$ios_out" == *"iOS Status"* ]] || fail "T16: after override, backend should see iOS Status"
# Restore
orch_diffctx_add_mapping "ios-status" "07-ios 02-cto 09-qa 03-pm"
pass "T16: custom mapping override works"

# ── Test 17: Parse missing file returns error ──
orch_diffctx_parse "/nonexistent/file.md" 2>/dev/null && fail "T17: should fail on missing file"
pass "T17: missing file returns error"

# ── Test 18: Filter before parse returns error ──
_ORCH_DIFFCTX_SEC_COUNT=0
orch_diffctx_filter "06-backend" 2>/dev/null && fail "T18: should fail before parse"
# Re-parse for remaining tests
orch_diffctx_parse "$TEST_DIR/context.md"
pass "T18: filter before parse returns error"

# ── Test 19: Filter before init returns error ──
_ORCH_DIFFCTX_INITIALIZED=false
orch_diffctx_filter "06-backend" 2>/dev/null && fail "T19: should fail before init"
orch_diffctx_init
orch_diffctx_parse "$TEST_DIR/context.md"
pass "T19: filter before init returns error"

# ── Test 20: Stats output ──
stats_output=$(orch_diffctx_stats "06-backend")
[[ "$stats_output" == *"savings"* ]] || fail "T20: stats should show savings"
[[ "$stats_output" == *"06-backend"* ]] || fail "T20: stats should show agent ID"
pass "T20: stats output correct"

# ── Test 21: Stats shows non-zero savings for non-PM agent ──
savings_line=$(echo "$stats_output" | grep "savings:")
[[ "$savings_line" =~ [1-9] ]] || fail "T21: backend should have >0% savings"
pass "T21: non-PM agent has positive savings"

# ── Test 22: PM has 0% savings ──
pm_stats=$(orch_diffctx_stats "03-pm")
pm_savings=$(echo "$pm_stats" | grep "savings:" | grep -o '[0-9]*')
[[ "$pm_savings" == "0" ]] || fail "T22: PM should have 0% savings (got: $pm_savings)"
pass "T22: PM has 0% savings"

# ── Cross-cycle history filtering ──

HISTORY_CONTENT="## WHAT SHIPPED — Cycle 7

### 06-Backend
- Built prompt-compression.sh
- Built conditional-activation.sh

### 11-Web
- Terminal animation added
- Docs format fixed

### 03-PM (this cycle)
- Updated all prompts
- Session tracker updated

### All Other Agents
- STANDBY

---

## WHAT SHIPPED — Cycle 6

### 06-Backend
- BUG-014 through BUG-017 fixed

### 09-QA
- Full QA pass on all modules
- 77/77 tests pass

### 10-Security
- Security review of review-phase.sh
- HIGH-03 and HIGH-04 applied by CS

---"

# ── Test 23: History filter — backend sees own entries ──
orch_diffctx_init "$TEST_DIR/agents-v2.conf"
filtered=$(orch_diffctx_filter_history "06-backend" "$HISTORY_CONTENT")
[[ "$filtered" == *"Built prompt-compression.sh"* ]] || fail "T23: backend should see own C7 entry"
[[ "$filtered" == *"BUG-014"* ]] || fail "T23: backend should see own C6 entry"
pass "T23: backend sees own history entries"

# ── Test 24: Backend doesn't see unrelated entries ──
[[ "$filtered" != *"Terminal animation"* ]] || fail "T24: backend should NOT see web entries"
pass "T24: backend excluded from unrelated history"

# ── Test 25: Backend sees PM entries ──
[[ "$filtered" == *"Updated all prompts"* ]] || fail "T25: backend should see PM entries"
pass "T25: backend sees PM entries"

# ── Test 26: Backend sees "All" entries ──
[[ "$filtered" == *"STANDBY"* ]] || fail "T26: backend should see 'All Other Agents' entries"
pass "T26: backend sees 'All' entries"

# ── Test 27: QA sees backend entries (dependency) ──
qa_filtered=$(orch_diffctx_filter_history "09-qa" "$HISTORY_CONTENT")
[[ "$qa_filtered" == *"Built prompt-compression.sh"* ]] || fail "T27: qa should see backend (dependency)"
pass "T27: QA sees dependency (backend) entries"

# ── Test 28: QA sees own entries ──
[[ "$qa_filtered" == *"77/77 tests pass"* ]] || fail "T28: qa should see own entries"
pass "T28: QA sees own entries"

# ── Test 29: PM sees everything in history ──
pm_filtered=$(orch_diffctx_filter_history "03-pm" "$HISTORY_CONTENT")
[[ "$pm_filtered" == *"Built prompt-compression.sh"* ]] || fail "T29: PM should see backend"
[[ "$pm_filtered" == *"Terminal animation"* ]] || fail "T29: PM should see web"
[[ "$pm_filtered" == *"77/77 tests pass"* ]] || fail "T29: PM should see qa"
pass "T29: PM sees all history"

# ── Test 30: Empty history returns empty ──
empty_out=$(orch_diffctx_filter_history "06-backend" "")
[[ -z "$empty_out" ]] || fail "T30: empty history should return empty"
pass "T30: empty history handled"

# ── Test 31: Web agent doesn't see backend or QA history ──
web_filtered=$(orch_diffctx_filter_history "11-web" "$HISTORY_CONTENT")
[[ "$web_filtered" == *"Terminal animation"* ]] || fail "T31: web should see own entries"
[[ "$web_filtered" != *"Built prompt-compression.sh"* ]] || fail "T31: web should NOT see backend entries"
[[ "$web_filtered" != *"77/77 tests pass"* ]] || fail "T31: web should NOT see QA entries"
pass "T31: web agent gets only relevant history"

# ── Test 32: Cycle separator lines preserved ──
[[ "$filtered" == *"## WHAT SHIPPED"* ]] || fail "T32: cycle headers should be preserved"
[[ "$filtered" == *"---"* ]] || fail "T32: separator lines should be preserved"
pass "T32: structural elements preserved in filtered history"

# ── Test 33: Cross-reference mention detection ──
CROSS_REF_HISTORY="### 10-Security
- HIGH-03 in auto-agent.sh affecting 06-backend ownership loops"

cross_filtered=$(orch_diffctx_filter_history "06-backend" "$CROSS_REF_HISTORY")
[[ "$cross_filtered" == *"HIGH-03"* ]] || fail "T33: backend should see cross-reference mention"
pass "T33: cross-reference mentions detected"

# ── Test 34: Normalize key handles emoji and special chars ──
key=$(_orch_diffctx_normalize_key "🚫 PROTECTED FILES — Never Touch")
[[ "$key" == *"protected"* ]] || fail "T34: key should contain 'protected' (got: $key)"
[[ "$key" != *"🚫"* ]] || fail "T34: key should not contain emoji"
pass "T34: key normalization strips emoji/special"

# ── Test 35: Normalize key handles regular headers ──
key=$(_orch_diffctx_normalize_key "Backend Status")
[[ "$key" == "backend-status" ]] || fail "T35: expected 'backend-status', got '$key'"
pass "T35: regular header normalized correctly"

# ── Test 36: Agent label extraction ──
label=$(_orch_diffctx_agent_label "06-backend")
[[ "$label" == "backend" ]] || fail "T36: expected 'backend', got '$label'"
label=$(_orch_diffctx_agent_label "09-qa")
[[ "$label" == "qa" ]] || fail "T36: expected 'qa', got '$label'"
pass "T36: agent label extraction correct"

# ── Test 37: In-list matching by ID ──
_orch_diffctx_in_list "06-backend" "06-backend 02-cto 09-qa" || fail "T37: should match by ID"
pass "T37: in-list matching by full ID"

# ── Test 38: In-list matching by label ──
_orch_diffctx_in_list "06-backend" "backend cto qa" || fail "T38: should match by label"
pass "T38: in-list matching by label"

# ── Test 39: In-list universal wildcard ──
_orch_diffctx_in_list "06-backend" "*" || fail "T39: wildcard should match"
_orch_diffctx_in_list "99-unknown" "*" || fail "T39: wildcard should match any"
pass "T39: universal wildcard matches all"

# ── Test 40: In-list no match ──
_orch_diffctx_in_list "06-backend" "07-ios 11-web" && fail "T40: should not match"
pass "T40: in-list correctly rejects non-members"

# ── Test 41: Unmapped sections included (fail-open) ──
# Add a section with an unmapped key
cat > "$TEST_DIR/context-extra.md" << 'CTX'
## Usage
- API status: 0

## Custom New Section
- Something totally new that has no mapping

## Backend Status
- Module built
CTX
orch_diffctx_parse "$TEST_DIR/context-extra.md"
extra_out=$(orch_diffctx_filter "11-web")
[[ "$extra_out" == *"Custom New Section"* ]] || fail "T41: unmapped sections should be included (fail-open)"
pass "T41: unmapped sections included (fail-open)"

# ── Test 42: list_mappings output ──
mappings_out=$(orch_diffctx_list_mappings)
[[ "$mappings_out" == *"backend-status"* ]] || fail "T42: mappings should list backend-status"
[[ "$mappings_out" == *"*"* ]] || fail "T42: mappings should show universal (*)"
pass "T42: list_mappings output correct"

# ── Summary ──
echo ""
echo "================================"
echo "differential-context.sh: $PASS passed, $FAIL failed"
echo "================================"

[[ "$FAIL" -eq 0 ]] || exit 1
