#!/usr/bin/env bash
# Test: founder-mode.sh — Founder mode triage module
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Test harness ──
PASS=0
FAIL=0

_assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected=%s actual=%s)\n' "$desc" "$expected" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if echo "$actual" | grep -qE "$pattern"; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (pattern=%s actual=%s)\n' "$desc" "$pattern" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file not found: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_file_contains() {
    local desc="$1" path="$2" pattern="$3"
    if [[ -f "$path" ]] && grep -qE "$pattern" "$path"; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file=%s pattern=%s)\n' "$desc" "$path" "$pattern"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_exit_code() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected exit=%s actual exit=%s)\n' "$desc" "$expected" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Setup: temp directory with mock agents.conf ──
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Create a mock project with agents.conf
MOCK_PROJECT="$TEST_TMP/project"
mkdir -p "$MOCK_PROJECT"

cat > "$MOCK_PROJECT/agents.conf" <<'CONF'
# OrchyStraw — agents.conf (test)
# Format: id | prompt_path | ownership | interval | label | model
03-pm        | prompts/03-pm/03-pm.txt               | prompts/ docs/                              | 0 | PM Coordinator      | claude
06-backend   | prompts/06-backend/06-backend.txt     | scripts/ src/core/                          | 1 | Backend Developer   | claude
11-web       | prompts/11-web/11-web.txt             | site/                                       | 1 | Web Developer       | gemini
02-cto       | prompts/02-cto/02-cto.txt             | docs/architecture/                          | 2 | CTO                 | claude
09-qa        | prompts/09-qa/09-qa.txt               | tests/                                      | 3 | QA Engineer         | codex
01-ceo       | prompts/01-ceo/01-ceo.txt             | docs/strategy/                              | 3 | CEO                 | claude
10-security  | prompts/10-security/10-security.txt   | reports/                                    | 5 | Security            | claude
05-tauri-ui  | prompts/05-tauri-ui/05-tauri-ui.txt   | src/components/                             | 1 | Tauri UI            | gemini
07-ios       | prompts/07-ios/07-ios.txt             | ios/                                        | 1 | iOS Developer       | claude
08-pixel     | prompts/08-pixel/08-pixel.txt         | src/pixel/                                  | 2 | Pixel Agents        | gemini
CONF

# ── Source the module ──
source "$PROJECT_ROOT/src/core/founder-mode.sh"

echo "=== test-founder-mode.sh ==="

# ────────────────────────────────────────────
# Group 0: Syntax check
# ────────────────────────────────────────────
echo ""
echo "--- syntax check ---"

if bash -n "$PROJECT_ROOT/src/core/founder-mode.sh" 2>/dev/null; then
    _assert "bash -n syntax check passes" "0" "0"
else
    _assert "bash -n syntax check passes" "0" "1"
fi

# ────────────────────────────────────────────
# Group 1: Initialization
# ────────────────────────────────────────────
echo ""
echo "--- orch_founder_init ---"

orch_founder_init "$MOCK_PROJECT"
_assert "init creates .orchystraw dir" "0" "$([[ -d "$MOCK_PROJECT/.orchystraw" ]] && echo 0 || echo 1)"
_assert_file_exists "init creates delegation log" "$MOCK_PROJECT/.orchystraw/founder-delegations.log"
_assert_file_exists "init creates overrides file" "$MOCK_PROJECT/.orchystraw/founder-overrides.json"
_assert_file_exists "init creates triage state" "$MOCK_PROJECT/.orchystraw/founder-triage.state"
_assert "default founder agent is 01-ceo" "01-ceo" "$_ORCH_FOUNDER_AGENT"

# Check agents were parsed
_assert "parsed 06-backend interval" "1" "${_ORCH_FOUNDER_AGENTS[06-backend]:-}"
_assert "parsed 02-cto interval" "2" "${_ORCH_FOUNDER_AGENTS[02-cto]:-}"
_assert "parsed 03-pm interval (coordinator)" "0" "${_ORCH_FOUNDER_AGENTS[03-pm]:-}"
_assert "parsed 10-security interval" "5" "${_ORCH_FOUNDER_AGENTS[10-security]:-}"

# Idempotent
orch_founder_init "$MOCK_PROJECT"
_assert "init is idempotent" "0" "$?"

# Custom founder agent
FOUNDER_AGENT="02-cto" orch_founder_init "$MOCK_PROJECT"
_assert "custom founder agent via env" "02-cto" "$_ORCH_FOUNDER_AGENT"

# Reset to default
unset FOUNDER_AGENT
orch_founder_init "$MOCK_PROJECT"

# ────────────────────────────────────────────
# Group 2: Triage — task classification
# ────────────────────────────────────────────
echo ""
echo "--- orch_founder_triage ---"

# Bug classification
result=$(orch_founder_triage "Fix crash in backend API handler")
_assert_match "bug: crash routes to bug category" "^bug" "$result"
_assert_match "bug: crash routes to 06-backend" "06-backend" "$result"

result=$(orch_founder_triage "Fix error in QA test suite")
_assert_match "bug: test error routes to 09-qa" "09-qa" "$result"

# Feature classification
result=$(orch_founder_triage "Add new dashboard UI component")
_assert_match "feature: ui routes to feature" "^feature" "$result"
_assert_match "feature: ui routes to 05-tauri-ui" "05-tauri-ui" "$result"

result=$(orch_founder_triage "Implement new API endpoint for backend")
_assert_match "feature: api routes to 06-backend" "06-backend" "$result"

result=$(orch_founder_triage "Build new iOS companion feature")
_assert_match "feature: mobile routes to 07-ios" "07-ios" "$result"

# Refactor classification
result=$(orch_founder_triage "Refactor the architecture design patterns")
_assert_match "refactor: arch routes to 02-cto" "02-cto" "$result"
_assert_match "refactor: category correct" "^refactor" "$result"

result=$(orch_founder_triage "Clean up backend scripts")
_assert_match "refactor: clean routes to 06-backend" "06-backend" "$result"

# Docs classification
result=$(orch_founder_triage "Update the README and docs")
_assert_match "docs: routes to 11-web" "11-web" "$result"
_assert_match "docs: category correct" "^docs" "$result"

# Infra classification
result=$(orch_founder_triage "Fix the CI pipeline deployment")
_assert_match "infra: routes to 06-backend" "06-backend" "$result"
_assert_match "infra: category correct" "^infra" "$result"

# Security classification
result=$(orch_founder_triage "Run security audit for CVE vulnerabilities")
_assert_match "security: routes to 10-security" "10-security" "$result"
_assert_match "security: category correct" "^security" "$result"

# Unknown / fallback
result=$(orch_founder_triage "Something vague and unclear")
_assert_match "unknown: falls back to founder agent" "$_ORCH_FOUNDER_AGENT" "$result"

# Empty task fails
if orch_founder_triage "" 2>/dev/null; then
    _assert "triage with empty task fails" "1" "0"
else
    _assert "triage with empty task fails" "1" "1"
fi

# Triage writes state file
_assert_file_contains "triage state file updated" \
    "$MOCK_PROJECT/.orchystraw/founder-triage.state" "unknown"

# ────────────────────────────────────────────
# Group 3: Delegation
# ────────────────────────────────────────────
echo ""
echo "--- orch_founder_delegate ---"

orch_founder_delegate "Fix crash in backend" "06-backend"
_assert_file_contains "delegation log has entry" \
    "$MOCK_PROJECT/.orchystraw/founder-delegations.log" "06-backend.*Fix crash"

orch_founder_delegate "Add pixel animation" "08-pixel"
_assert_file_contains "delegation log has second entry" \
    "$MOCK_PROJECT/.orchystraw/founder-delegations.log" "08-pixel.*pixel animation"

# Check active task tracking
_assert "06-backend has 1 active task" "1" "${_ORCH_FOUNDER_ACTIVE_TASKS[06-backend]:-0}"
_assert "08-pixel has 1 active task" "1" "${_ORCH_FOUNDER_ACTIVE_TASKS[08-pixel]:-0}"

# Multiple delegations to same agent
orch_founder_delegate "Another backend task" "06-backend"
_assert "06-backend has 2 active tasks" "2" "${_ORCH_FOUNDER_ACTIVE_TASKS[06-backend]:-0}"

# Empty args fail
if orch_founder_delegate "" "06-backend" 2>/dev/null; then
    _assert "delegate with empty task fails" "1" "0"
else
    _assert "delegate with empty task fails" "1" "1"
fi

if orch_founder_delegate "some task" "" 2>/dev/null; then
    _assert "delegate with empty agent fails" "1" "0"
else
    _assert "delegate with empty agent fails" "1" "1"
fi

# ────────────────────────────────────────────
# Group 4: Should Run
# ────────────────────────────────────────────
echo ""
echo "--- orch_founder_should_run ---"

# Reset to clean state for should_run tests
orch_founder_init "$MOCK_PROJECT"

# Coordinator (interval=0) always runs
rc=0; orch_founder_should_run "03-pm" 1 || rc=$?
_assert_exit_code "coordinator always runs (cycle 1)" "0" "$rc"

rc=0; orch_founder_should_run "03-pm" 7 || rc=$?
_assert_exit_code "coordinator always runs (cycle 7)" "0" "$rc"

# Every-cycle agent (interval=1) always runs
rc=0; orch_founder_should_run "06-backend" 1 || rc=$?
_assert_exit_code "interval=1 runs on cycle 1" "0" "$rc"

rc=0; orch_founder_should_run "06-backend" 5 || rc=$?
_assert_exit_code "interval=1 runs on cycle 5" "0" "$rc"

# Every-2nd-cycle agent (interval=2)
rc=0; orch_founder_should_run "02-cto" 2 || rc=$?
_assert_exit_code "interval=2 runs on cycle 2" "0" "$rc"

rc=0; orch_founder_should_run "02-cto" 4 || rc=$?
_assert_exit_code "interval=2 runs on cycle 4" "0" "$rc"

rc=0; orch_founder_should_run "02-cto" 3 || rc=$?
_assert_exit_code "interval=2 skips cycle 3" "1" "$rc"

# Every-3rd-cycle agent (interval=3)
rc=0; orch_founder_should_run "09-qa" 3 || rc=$?
_assert_exit_code "interval=3 runs on cycle 3" "0" "$rc"

rc=0; orch_founder_should_run "09-qa" 4 || rc=$?
_assert_exit_code "interval=3 skips cycle 4" "1" "$rc"

rc=0; orch_founder_should_run "09-qa" 6 || rc=$?
_assert_exit_code "interval=3 runs on cycle 6" "0" "$rc"

# Every-5th-cycle agent (interval=5)
rc=0; orch_founder_should_run "10-security" 5 || rc=$?
_assert_exit_code "interval=5 runs on cycle 5" "0" "$rc"

rc=0; orch_founder_should_run "10-security" 3 || rc=$?
_assert_exit_code "interval=5 skips cycle 3" "1" "$rc"

# Unknown agent → skip
rc=0; orch_founder_should_run "99-ghost" 1 || rc=$?
_assert_exit_code "unknown agent is skipped" "1" "$rc"

# Agent with active delegation always runs
orch_founder_delegate "urgent security task" "10-security"
rc=0; orch_founder_should_run "10-security" 3 || rc=$?
_assert_exit_code "agent with delegation runs even off-cycle" "0" "$rc"

# Agent with override always runs
orch_founder_override_priority "09-qa" "critical"
rc=0; orch_founder_should_run "09-qa" 4 || rc=$?
_assert_exit_code "agent with override runs even off-cycle" "0" "$rc"

# ────────────────────────────────────────────
# Group 5: Override Priority
# ────────────────────────────────────────────
echo ""
echo "--- orch_founder_override_priority ---"

# Reset
orch_founder_init "$MOCK_PROJECT"

orch_founder_override_priority "06-backend" "critical"
_assert "runtime override stored" "critical" "${_ORCH_FOUNDER_OVERRIDES[06-backend]:-}"

_assert_file_contains "override written to JSON file" \
    "$MOCK_PROJECT/.orchystraw/founder-overrides.json" '"06-backend":"critical"'

# Multiple overrides
orch_founder_override_priority "09-qa" "high"
_assert "second override stored" "high" "${_ORCH_FOUNDER_OVERRIDES[09-qa]:-}"
_assert_file_contains "JSON file has both overrides" \
    "$MOCK_PROJECT/.orchystraw/founder-overrides.json" '06-backend'
_assert_file_contains "JSON file has qa override" \
    "$MOCK_PROJECT/.orchystraw/founder-overrides.json" '09-qa'

# Empty args fail
if orch_founder_override_priority "" "high" 2>/dev/null; then
    _assert "override with empty agent fails" "1" "0"
else
    _assert "override with empty agent fails" "1" "1"
fi

if orch_founder_override_priority "06-backend" "" 2>/dev/null; then
    _assert "override with empty priority fails" "1" "0"
else
    _assert "override with empty priority fails" "1" "1"
fi

# ────────────────────────────────────────────
# Group 6: Status output
# ────────────────────────────────────────────
echo ""
echo "--- orch_founder_status ---"

# Set up some state
orch_founder_init "$MOCK_PROJECT"
orch_founder_triage "Fix backend crash" "high" >/dev/null
orch_founder_delegate "Fix backend crash" "06-backend"
orch_founder_override_priority "09-qa" "critical"

status=$(orch_founder_status)
_assert_match "status shows founder agent" "Founder agent:" "$status"
_assert_match "status shows project root" "Project root:" "$status"
_assert_match "status shows known agents" "Known Agents" "$status"
_assert_match "status shows overrides" "Active Overrides" "$status"
_assert_match "status shows delegations" "Active Delegations" "$status"
_assert_match "status shows last triage" "Last Triage" "$status"
_assert_match "status shows delegation log" "Delegation Log" "$status"
_assert_match "status includes 09-qa override" "09-qa" "$status"
_assert_match "status is readable (has agent labels)" "06-backend" "$status"

# ────────────────────────────────────────────
# Group 7: Double-source guard
# ────────────────────────────────────────────
echo ""
echo "--- double-source guard ---"

source "$PROJECT_ROOT/src/core/founder-mode.sh"
_assert "double-source guard works" "1" "$_ORCH_FOUNDER_MODE_LOADED"

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
