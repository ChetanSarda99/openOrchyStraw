#!/usr/bin/env bash
# Test: model-router.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/model-router.sh"

echo "=== model-router.sh tests ==="

# 1. Module loads (guard var set)
if [[ "${_ORCH_MODEL_ROUTER_LOADED:-}" == "1" ]]; then
    pass "Module loads (_ORCH_MODEL_ROUTER_LOADED=1)"
else
    fail "Module loads (_ORCH_MODEL_ROUTER_LOADED not set)"
fi

# 2. Double-source guard
_before="$_ORCH_MODEL_ROUTER_LOADED"
source "$PROJECT_ROOT/src/core/model-router.sh"
if [[ "$_ORCH_MODEL_ROUTER_LOADED" == "$_before" ]]; then
    pass "Double-source guard prevents re-loading"
else
    fail "Double-source guard failed"
fi

# 3. Init registers defaults — after orch_model_init, default is "claude"
orch_model_init
if [[ "$_ORCH_MODEL_DEFAULT" == "claude" ]]; then
    pass "Init registers defaults (default=claude)"
else
    fail "Init registers defaults (expected claude, got $_ORCH_MODEL_DEFAULT)"
fi

# 4. Default model CLI — unassigned agent gets "claude"
orch_model_init
result="$(orch_model_get_cli "99-unknown")"
if [[ "$result" == "claude" ]]; then
    pass "Default model CLI for unassigned agent is 'claude'"
else
    fail "Default model CLI (expected 'claude', got '$result')"
fi

# 5. Register custom model
orch_model_init
orch_model_register "ollama" "ollama" "run"
if [[ "${_ORCH_MODEL_CLI[ollama]}" == "ollama" ]] && [[ "${_ORCH_MODEL_ARGS[ollama]}" == "run" ]]; then
    pass "Register custom model (ollama → ollama run)"
else
    fail "Register custom model failed"
fi

# 6. Assign model to agent
orch_model_init
orch_model_assign "05-tauri-ui" "gemini"
result="$(orch_model_get_name "05-tauri-ui")"
if [[ "$result" == "gemini" ]]; then
    pass "Assign model to agent (05-tauri-ui → gemini)"
else
    fail "Assign model to agent (expected 'gemini', got '$result')"
fi

# 7. Get CLI for gemini agent
orch_model_init
orch_model_assign "05-tauri-ui" "gemini"
result="$(orch_model_get_cli "05-tauri-ui")"
if [[ "$result" == "gemini -p" ]]; then
    pass "Get CLI for gemini agent returns 'gemini -p'"
else
    fail "Get CLI for gemini agent (expected 'gemini -p', got '$result')"
fi

# 8. Get CLI for codex agent
orch_model_init
orch_model_assign "09-qa" "codex"
result="$(orch_model_get_cli "09-qa")"
if [[ "$result" == "codex exec" ]]; then
    pass "Get CLI for codex agent returns 'codex exec'"
else
    fail "Get CLI for codex agent (expected 'codex exec', got '$result')"
fi

# 9. Get CLI for unassigned agent — should return default "claude"
orch_model_init
result="$(orch_model_get_cli "99-nobody")"
if [[ "$result" == "claude" ]]; then
    pass "Get CLI for unassigned agent returns default 'claude'"
else
    fail "Get CLI for unassigned agent (expected 'claude', got '$result')"
fi

# 10. Set different default
orch_model_init
orch_model_set_default "gemini"
result="$(orch_model_get_cli "99-nobody")"
if [[ "$result" == "gemini -p" ]]; then
    pass "Set different default (unassigned agents now get 'gemini -p')"
else
    fail "Set different default (expected 'gemini -p', got '$result')"
fi

# 11. List agents by model
orch_model_init
orch_model_assign "01-ceo" "claude"
orch_model_assign "02-cto" "claude"
orch_model_assign "06-backend" "claude"
result="$(orch_model_list_agents "claude")"
count=$(echo "$result" | wc -w)
if [[ "$count" -eq 3 ]]; then
    pass "List agents by model (3 agents assigned to claude)"
else
    fail "List agents by model (expected 3, got $count: '$result')"
fi

# 12. Is available — test with "bash" (always available)
orch_model_init
orch_model_register "bash-model" "bash" ""
if orch_model_is_available "bash-model"; then
    pass "Is available returns 0 for 'bash' binary"
else
    fail "Is available should return 0 for 'bash' binary"
fi

# 13. Is unavailable — test with nonexistent binary
orch_model_init
orch_model_register "fake-model" "nonexistent_binary_xyz" ""
if ! orch_model_is_available "fake-model"; then
    pass "Is unavailable returns 1 for nonexistent binary"
else
    fail "Is unavailable should return 1 for nonexistent binary"
fi

# 14. Fallback for unavailable model — assign unavailable, verify fallback returns default CLI
orch_model_init
orch_model_register "unavail" "nonexistent_binary_xyz" "--flag"
orch_model_assign "99-test" "unavail"
result="$(orch_model_fallback "99-test" 2>/dev/null)" || true
if [[ "$result" == "claude" ]]; then
    pass "Fallback for unavailable model returns default CLI 'claude'"
else
    fail "Fallback for unavailable model (expected 'claude', got '$result')"
fi

# 15. Parse agents.conf (5-col) — all agents get default
orch_model_init
cat > "$TMPDIR_TEST/agents-5col.conf" <<'CONF'
# comment line
01-ceo | prompts/01-ceo/01-ceo.txt | docs/strategy/ | 3 | CEO
06-backend | prompts/06-backend/06-backend.txt | src/core/ | 1 | Backend
CONF
orch_model_parse_config "$TMPDIR_TEST/agents-5col.conf"
r1="$(orch_model_get_name "01-ceo")"
r2="$(orch_model_get_name "06-backend")"
if [[ "$r1" == "claude" ]] && [[ "$r2" == "claude" ]]; then
    pass "Parse agents.conf (5-col) — agents get default 'claude'"
else
    fail "Parse agents.conf (5-col) (expected claude/claude, got $r1/$r2)"
fi

# 16. Parse agents.conf (6-col with model) — verify assignments
orch_model_init
cat > "$TMPDIR_TEST/agents-6col.conf" <<'CONF'
# 6-column format with model
05-tauri-ui | prompts/05-tauri-ui/05-tauri-ui.txt | src/ | 1 | Tauri UI | gemini
09-qa | prompts/09-qa/09-qa.txt | tests/ | 3 | QA | codex
06-backend | prompts/06-backend/06-backend.txt | src/core/ | 1 | Backend |
CONF
orch_model_parse_config "$TMPDIR_TEST/agents-6col.conf"
r1="$(orch_model_get_name "05-tauri-ui")"
r2="$(orch_model_get_name "09-qa")"
r3="$(orch_model_get_name "06-backend")"
if [[ "$r1" == "gemini" ]] && [[ "$r2" == "codex" ]] && [[ "$r3" == "claude" ]]; then
    pass "Parse agents.conf (6-col) — model assignments correct"
else
    fail "Parse agents.conf (6-col) (expected gemini/codex/claude, got $r1/$r2/$r3)"
fi

# 17. Report runs without error
orch_model_init
orch_model_assign "01-ceo" "claude"
orch_model_assign "05-tauri-ui" "gemini"
if orch_model_report &>/dev/null; then
    pass "Report runs without error"
else
    fail "Report returned non-zero exit code"
fi

# 18. Init resets state — assign some models, init again, verify clean
orch_model_init
orch_model_assign "01-ceo" "gemini"
orch_model_assign "09-qa" "codex"
orch_model_init
r1="$(orch_model_get_name "01-ceo")"
r2="$(orch_model_get_name "09-qa")"
if [[ "$r1" == "claude" ]] && [[ "$r2" == "claude" ]]; then
    pass "Init resets state (assignments cleared, defaults restored)"
else
    fail "Init resets state (expected claude/claude, got $r1/$r2)"
fi

# 19. Get name for unassigned — returns default model name
orch_model_init
result="$(orch_model_get_name "99-nonexistent")"
if [[ "$result" == "claude" ]]; then
    pass "Get name for unassigned returns default model name 'claude'"
else
    fail "Get name for unassigned (expected 'claude', got '$result')"
fi

# 20. Multiple agents same model — assign 3 to claude, 2 to gemini, verify counts
orch_model_init
orch_model_assign "01-ceo" "claude"
orch_model_assign "02-cto" "claude"
orch_model_assign "06-backend" "claude"
orch_model_assign "05-tauri-ui" "gemini"
orch_model_assign "08-pixel" "gemini"
claude_agents="$(orch_model_list_agents "claude")"
gemini_agents="$(orch_model_list_agents "gemini")"
claude_count=$(echo "$claude_agents" | wc -w)
gemini_count=$(echo "$gemini_agents" | wc -w)
if [[ "$claude_count" -eq 3 ]] && [[ "$gemini_count" -eq 2 ]]; then
    pass "Multiple agents same model (claude=3, gemini=2)"
else
    fail "Multiple agents same model (expected 3/2, got $claude_count/$gemini_count)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
