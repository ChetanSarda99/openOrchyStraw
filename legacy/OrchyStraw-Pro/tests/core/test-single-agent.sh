#!/usr/bin/env bash
# Test: single-agent.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/single-agent.sh"

echo "=== single-agent.sh tests ==="

# --- Setup: temp project structures ---
TEST_ROOT="$TMPDIR_TEST/test-project"
mkdir -p "$TEST_ROOT/prompts/06-backend"
echo "You are the backend agent. Build the API." > "$TEST_ROOT/prompts/06-backend/06-backend.txt"

# Small project (< 5 files at root)
SMALL_PROJECT="$TMPDIR_TEST/small-project"
mkdir -p "$SMALL_PROJECT"
touch "$SMALL_PROJECT/README.md"
touch "$SMALL_PROJECT/main.sh"
# 2 files — qualifies as small

# Large project (>= 5 files at root)
LARGE_PROJECT="$TMPDIR_TEST/large-project"
mkdir -p "$LARGE_PROJECT"
for i in 1 2 3 4 5 6; do
    touch "$LARGE_PROJECT/file${i}.sh"
done

# agents.conf with one non-PM agent
CONF_SINGLE="$TMPDIR_TEST/agents-single.conf"
cat > "$CONF_SINGLE" <<'CONF'
# id | prompt_path | ownership | interval | label | model
03-pm       | prompts/03-pm/03-pm.txt         | prompts/                | 0 | PM Coordinator | claude
06-backend  | prompts/06-backend/06-backend.txt | src/core/ scripts/    | 1 | Backend Dev    | claude
CONF

# agents.conf with multiple non-PM agents
CONF_MULTI="$TMPDIR_TEST/agents-multi.conf"
cat > "$CONF_MULTI" <<'CONF'
# id | prompt_path | ownership | interval | label | model
03-pm       | prompts/03-pm/03-pm.txt         | prompts/                | 0 | PM Coordinator | claude
06-backend  | prompts/06-backend/06-backend.txt | src/core/ scripts/    | 1 | Backend Dev    | claude
11-web      | prompts/11-web/11-web.txt         | site/                 | 1 | Web Dev        | gemini
CONF

# agents.conf with no non-PM agents (PM only)
CONF_PM_ONLY="$TMPDIR_TEST/agents-pm-only.conf"
cat > "$CONF_PM_ONLY" <<'CONF'
# id | prompt_path | ownership | interval | label | model
03-pm | prompts/03-pm/03-pm.txt | prompts/ | 0 | PM Coordinator | claude
CONF

# -----------------------------------------------------------------------
# 1. Module loads (guard var set)
# -----------------------------------------------------------------------
if [[ "${_ORCH_SINGLE_AGENT_LOADED:-}" == "1" ]]; then
    pass "1 - module loads (guard var set)"
else
    fail "1 - module loads (guard var set)"
fi

# -----------------------------------------------------------------------
# 2. Double-source guard
# -----------------------------------------------------------------------
if source "$PROJECT_ROOT/src/core/single-agent.sh"; then
    pass "2 - double-source guard (no-op re-source)"
else
    fail "2 - double-source guard"
fi

# -----------------------------------------------------------------------
# 3. Initial state: mode is off
# -----------------------------------------------------------------------
# Reset state manually for a clean check
_ORCH_SINGLE_MODE=0
if ! orch_single_is_active; then
    pass "3 - initial mode is inactive"
else
    fail "3 - initial mode is inactive (expected inactive)"
fi

# -----------------------------------------------------------------------
# 4. orch_single_init sets mode to active
# -----------------------------------------------------------------------
orch_single_init "$TEST_ROOT"
if orch_single_is_active; then
    pass "4 - init activates single-agent mode"
else
    fail "4 - init activates single-agent mode"
fi

# -----------------------------------------------------------------------
# 5. orch_single_init stores project root
# -----------------------------------------------------------------------
if [[ "$_ORCH_SINGLE_PROJECT_ROOT" == "$TEST_ROOT" ]]; then
    pass "5 - init stores project root"
else
    fail "5 - init stores project root (got: $_ORCH_SINGLE_PROJECT_ROOT)"
fi

# -----------------------------------------------------------------------
# 6. orch_single_init — missing argument returns error
# -----------------------------------------------------------------------
if orch_single_init "" 2>/dev/null; then
    fail "6 - init rejects empty project_root"
else
    pass "6 - init rejects empty project_root"
fi

# Restore active state for subsequent tests
orch_single_init "$TEST_ROOT"

# -----------------------------------------------------------------------
# 7. orch_single_is_active returns 0 when active
# -----------------------------------------------------------------------
_ORCH_SINGLE_MODE=1
if orch_single_is_active; then
    pass "7 - is_active returns 0 when mode=1"
else
    fail "7 - is_active returns 0 when mode=1"
fi

# -----------------------------------------------------------------------
# 8. orch_single_is_active returns 1 when inactive
# -----------------------------------------------------------------------
_ORCH_SINGLE_MODE=0
if orch_single_is_active; then
    fail "8 - is_active returns 1 when mode=0"
else
    pass "8 - is_active returns 1 when mode=0"
fi
_ORCH_SINGLE_MODE=1  # restore

# -----------------------------------------------------------------------
# 9. orch_single_detect — recommends single mode for 1 non-PM agent
# -----------------------------------------------------------------------
orch_single_init "$TEST_ROOT" 2>/dev/null
if orch_single_detect "$CONF_SINGLE" 2>/dev/null; then
    pass "9 - detect recommends single mode (1 non-PM agent)"
else
    fail "9 - detect recommends single mode (1 non-PM agent)"
fi

# -----------------------------------------------------------------------
# 10. orch_single_detect — does NOT recommend for multiple agents
# -----------------------------------------------------------------------
orch_single_init "$LARGE_PROJECT" 2>/dev/null
if orch_single_detect "$CONF_MULTI" 2>/dev/null; then
    fail "10 - detect does NOT recommend for multiple agents"
else
    pass "10 - detect does NOT recommend for multiple agents"
fi

# -----------------------------------------------------------------------
# 11. orch_single_detect — recommends single mode for small project (< 5 files)
# -----------------------------------------------------------------------
orch_single_init "$SMALL_PROJECT" 2>/dev/null
if orch_single_detect "$CONF_MULTI" 2>/dev/null; then
    pass "11 - detect recommends single mode for small project (< 5 files)"
else
    fail "11 - detect recommends single mode for small project (< 5 files)"
fi

# -----------------------------------------------------------------------
# 12. orch_single_detect — does NOT recommend for large project + multi agents
# -----------------------------------------------------------------------
orch_single_init "$LARGE_PROJECT" 2>/dev/null
if orch_single_detect "$CONF_MULTI" 2>/dev/null; then
    fail "12 - detect does not recommend for large project + multi agents"
else
    pass "12 - detect does not recommend for large project + multi agents"
fi

# -----------------------------------------------------------------------
# 13. orch_single_detect — missing agents.conf returns error
# -----------------------------------------------------------------------
if orch_single_detect "$TMPDIR_TEST/nonexistent.conf" 2>/dev/null; then
    fail "13 - detect errors on missing agents.conf"
else
    pass "13 - detect errors on missing agents.conf"
fi

# -----------------------------------------------------------------------
# 14. orch_single_get_agent — returns single non-PM agent
# -----------------------------------------------------------------------
result=$(orch_single_get_agent "$CONF_SINGLE" 2>/dev/null)
if [[ "$result" == "06-backend" ]]; then
    pass "14 - get_agent returns single non-PM agent"
else
    fail "14 - get_agent returns single non-PM agent (got: $result)"
fi

# -----------------------------------------------------------------------
# 15. orch_single_get_agent — errors on multiple non-PM agents
# -----------------------------------------------------------------------
if orch_single_get_agent "$CONF_MULTI" 2>/dev/null; then
    fail "15 - get_agent errors on multiple non-PM agents"
else
    pass "15 - get_agent errors on multiple non-PM agents"
fi

# -----------------------------------------------------------------------
# 16. orch_single_get_agent — errors on PM-only config
# -----------------------------------------------------------------------
if orch_single_get_agent "$CONF_PM_ONLY" 2>/dev/null; then
    fail "16 - get_agent errors on PM-only config"
else
    pass "16 - get_agent errors on PM-only config"
fi

# -----------------------------------------------------------------------
# 17. orch_single_get_agent — errors on missing config file
# -----------------------------------------------------------------------
if orch_single_get_agent "$TMPDIR_TEST/no-such-file.conf" 2>/dev/null; then
    fail "17 - get_agent errors on missing config file"
else
    pass "17 - get_agent errors on missing config file"
fi

# -----------------------------------------------------------------------
# 18. orch_single_skip_module — review-phase should be skipped
# -----------------------------------------------------------------------
if orch_single_skip_module "review-phase"; then
    pass "18 - skip_module: review-phase should skip"
else
    fail "18 - skip_module: review-phase should skip"
fi

# -----------------------------------------------------------------------
# 19. orch_single_skip_module — dynamic-router should be skipped
# -----------------------------------------------------------------------
if orch_single_skip_module "dynamic-router"; then
    pass "19 - skip_module: dynamic-router should skip"
else
    fail "19 - skip_module: dynamic-router should skip"
fi

# -----------------------------------------------------------------------
# 20. orch_single_skip_module — worktree-isolator should be skipped
# -----------------------------------------------------------------------
if orch_single_skip_module "worktree-isolator"; then
    pass "20 - skip_module: worktree-isolator should skip"
else
    fail "20 - skip_module: worktree-isolator should skip"
fi

# -----------------------------------------------------------------------
# 21. orch_single_skip_module — conditional-activation should be skipped
# -----------------------------------------------------------------------
if orch_single_skip_module "conditional-activation"; then
    pass "21 - skip_module: conditional-activation should skip"
else
    fail "21 - skip_module: conditional-activation should skip"
fi

# -----------------------------------------------------------------------
# 22. orch_single_skip_module — quality-gates should be kept
# -----------------------------------------------------------------------
if orch_single_skip_module "quality-gates"; then
    fail "22 - skip_module: quality-gates should be kept"
else
    pass "22 - skip_module: quality-gates should be kept"
fi

# -----------------------------------------------------------------------
# 23. orch_single_skip_module — file-access should be kept
# -----------------------------------------------------------------------
if orch_single_skip_module "file-access"; then
    fail "23 - skip_module: file-access should be kept"
else
    pass "23 - skip_module: file-access should be kept"
fi

# -----------------------------------------------------------------------
# 24. orch_single_skip_module — logger should be kept
# -----------------------------------------------------------------------
if orch_single_skip_module "logger"; then
    fail "24 - skip_module: logger should be kept"
else
    pass "24 - skip_module: logger should be kept"
fi

# -----------------------------------------------------------------------
# 25. orch_single_skip_module — model-router should be kept
# -----------------------------------------------------------------------
if orch_single_skip_module "model-router"; then
    fail "25 - skip_module: model-router should be kept"
else
    pass "25 - skip_module: model-router should be kept"
fi

# -----------------------------------------------------------------------
# 26. orch_single_skip_module — unknown module should be kept (not skipped)
# -----------------------------------------------------------------------
if orch_single_skip_module "some-unknown-module"; then
    fail "26 - skip_module: unknown module should be kept"
else
    pass "26 - skip_module: unknown module should be kept"
fi

# -----------------------------------------------------------------------
# 27. orch_single_skip_module — empty name returns error
# -----------------------------------------------------------------------
if orch_single_skip_module "" 2>/dev/null; then
    fail "27 - skip_module: empty name returns error"
else
    pass "27 - skip_module: empty name returns error"
fi

# -----------------------------------------------------------------------
# 28. orch_single_run — errors on missing agent_id
# -----------------------------------------------------------------------
orch_single_init "$TEST_ROOT" 2>/dev/null
if orch_single_run "" "$TEST_ROOT/prompts/06-backend/06-backend.txt" "$TEST_ROOT" 2>/dev/null; then
    fail "28 - run rejects missing agent_id"
else
    pass "28 - run rejects missing agent_id"
fi

# -----------------------------------------------------------------------
# 29. orch_single_run — errors on missing prompt_path
# -----------------------------------------------------------------------
if orch_single_run "06-backend" "" "$TEST_ROOT" 2>/dev/null; then
    fail "29 - run rejects missing prompt_path"
else
    pass "29 - run rejects missing prompt_path"
fi

# -----------------------------------------------------------------------
# 30. orch_single_run — errors on non-existent prompt file
# -----------------------------------------------------------------------
if orch_single_run "06-backend" "$TMPDIR_TEST/no-such-prompt.txt" "$TEST_ROOT" 2>/dev/null; then
    fail "30 - run rejects non-existent prompt file"
else
    pass "30 - run rejects non-existent prompt file"
fi

# -----------------------------------------------------------------------
# 31. orch_single_run — sets _ORCH_SINGLE_AGENT_ID on valid call
#     (We can't actually invoke the claude CLI in tests, so we test the
#     run path up to the exec by mocking claude as a noop in PATH.)
# -----------------------------------------------------------------------
MOCK_BIN="$TMPDIR_TEST/mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/claude" <<'MOCK'
#!/usr/bin/env bash
# Mock claude: accept any args, exit 0
exit 0
MOCK
chmod +x "$MOCK_BIN/claude"

# Temporarily prepend mock bin to PATH
OLD_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

orch_single_init "$TEST_ROOT" 2>/dev/null
orch_single_run "06-backend" "$TEST_ROOT/prompts/06-backend/06-backend.txt" "$TEST_ROOT" 2>/dev/null || true

if [[ "$_ORCH_SINGLE_AGENT_ID" == "06-backend" ]]; then
    pass "31 - run sets agent ID"
else
    fail "31 - run sets agent ID (got: $_ORCH_SINGLE_AGENT_ID)"
fi

# -----------------------------------------------------------------------
# 32. orch_single_run — exit code 0 from mock agent is captured
# -----------------------------------------------------------------------
orch_single_run "06-backend" "$TEST_ROOT/prompts/06-backend/06-backend.txt" "$TEST_ROOT" 2>/dev/null
if [[ "$_ORCH_SINGLE_LAST_EXIT" == "0" ]]; then
    pass "32 - run captures exit code 0"
else
    fail "32 - run captures exit code 0 (got: $_ORCH_SINGLE_LAST_EXIT)"
fi

# -----------------------------------------------------------------------
# 33. orch_single_run — non-zero exit code is captured
# -----------------------------------------------------------------------
cat > "$MOCK_BIN/claude" <<'MOCK'
#!/usr/bin/env bash
exit 42
MOCK

orch_single_run "06-backend" "$TEST_ROOT/prompts/06-backend/06-backend.txt" "$TEST_ROOT" 2>/dev/null || true
if [[ "$_ORCH_SINGLE_LAST_EXIT" == "42" ]]; then
    pass "33 - run captures non-zero exit code"
else
    fail "33 - run captures non-zero exit code (got: $_ORCH_SINGLE_LAST_EXIT)"
fi

# Restore PATH
export PATH="$OLD_PATH"

# -----------------------------------------------------------------------
# 34. orch_single_report — runs without error
# -----------------------------------------------------------------------
orch_single_init "$TEST_ROOT" 2>/dev/null
report_output=$(orch_single_report 2>/dev/null) || true
if [[ -n "$report_output" ]]; then
    pass "34 - report runs without error"
else
    fail "34 - report runs without error"
fi

# -----------------------------------------------------------------------
# 35. orch_single_report — contains mode status
# -----------------------------------------------------------------------
if [[ "$report_output" == *"ACTIVE"* ]]; then
    pass "35 - report contains ACTIVE status"
else
    fail "35 - report contains ACTIVE status (got: $report_output)"
fi

# -----------------------------------------------------------------------
# 36. orch_single_report — contains project root
# -----------------------------------------------------------------------
if [[ "$report_output" == *"$TEST_ROOT"* ]]; then
    pass "36 - report contains project root"
else
    fail "36 - report contains project root"
fi

# -----------------------------------------------------------------------
# 37. orch_single_report — lists skipped modules
# -----------------------------------------------------------------------
if [[ "$report_output" == *"review-phase"* && "$report_output" == *"dynamic-router"* ]]; then
    pass "37 - report lists skipped modules"
else
    fail "37 - report lists skipped modules"
fi

# -----------------------------------------------------------------------
# 38. orch_single_report — lists kept modules
# -----------------------------------------------------------------------
if [[ "$report_output" == *"quality-gates"* && "$report_output" == *"file-access"* ]]; then
    pass "38 - report lists kept modules"
else
    fail "38 - report lists kept modules"
fi

# -----------------------------------------------------------------------
# 39. orch_single_report — shows inactive when mode=0
# -----------------------------------------------------------------------
_ORCH_SINGLE_MODE=0
report_inactive=$(orch_single_report 2>/dev/null) || true
if [[ "$report_inactive" == *"inactive"* ]]; then
    pass "39 - report shows inactive when mode=0"
else
    fail "39 - report shows inactive when mode=0 (got: $report_inactive)"
fi
_ORCH_SINGLE_MODE=1  # restore

# -----------------------------------------------------------------------
# 40. orch_single_get_agent — ignores comment-only lines and blank lines
# -----------------------------------------------------------------------
CONF_COMMENTS="$TMPDIR_TEST/agents-comments.conf"
cat > "$CONF_COMMENTS" <<'CONF'
# This is a comment
# Another comment

03-pm       | prompts/03-pm/03-pm.txt  | prompts/ | 0 | PM | claude

# Mid-file comment
06-backend  | prompts/06-backend/06-backend.txt | src/ | 1 | Backend | claude
CONF

result=$(orch_single_get_agent "$CONF_COMMENTS" 2>/dev/null)
if [[ "$result" == "06-backend" ]]; then
    pass "40 - get_agent handles comment and blank lines"
else
    fail "40 - get_agent handles comment and blank lines (got: $result)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
