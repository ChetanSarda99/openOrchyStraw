#!/usr/bin/env bash
# Test: prompt-template.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# --- Temp file cleanup ---
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# read -r -d '' heredocs return 1 under set -e; disable temporarily
set +e
source "$PROJECT_ROOT/src/core/prompt-template.sh"
set -e

echo "=== prompt-template.sh tests ==="

# 1. Module loads (_ORCH_PROMPT_TEMPLATE_LOADED is set)
if [[ "${_ORCH_PROMPT_TEMPLATE_LOADED:-}" == "1" ]]; then
    pass "module loads (_ORCH_PROMPT_TEMPLATE_LOADED is set)"
else
    fail "module loads (_ORCH_PROMPT_TEMPLATE_LOADED is set)"
fi

# 2. Double-source guard (sourcing again should not error)
set +e
source "$PROJECT_ROOT/src/core/prompt-template.sh"
set -e
if [[ "${_ORCH_PROMPT_TEMPLATE_LOADED:-}" == "1" ]]; then
    pass "double-source guard"
else
    fail "double-source guard"
fi

# 3. orch_template_init clears existing vars
orch_template_set "LEFTOVER" "should_be_cleared"
orch_template_init "$PROJECT_ROOT"
local_result=$(orch_template_get "LEFTOVER")
if [[ -z "$local_result" ]]; then
    pass "orch_template_init clears existing vars"
else
    fail "orch_template_init clears existing vars (got: '$local_result')"
fi

# 4. orch_template_set stores a variable
orch_template_set "MY_VAR" "hello_world"
if [[ "${_ORCH_TEMPLATE_VARS[MY_VAR]:-}" == "hello_world" ]]; then
    pass "orch_template_set stores a variable"
else
    fail "orch_template_set stores a variable"
fi

# 5. orch_template_get retrieves the variable
got=$(orch_template_get "MY_VAR")
if [[ "$got" == "hello_world" ]]; then
    pass "orch_template_get retrieves the variable"
else
    fail "orch_template_get retrieves the variable (got: '$got')"
fi

# 6. orch_template_get returns empty for unknown var
got=$(orch_template_get "NO_SUCH_VAR")
if [[ -z "$got" ]]; then
    pass "orch_template_get returns empty for unknown var"
else
    fail "orch_template_get returns empty for unknown var (got: '$got')"
fi

# 7. orch_template_set_defaults sets DATE (contains current year)
orch_template_init "$PROJECT_ROOT"
orch_template_set_defaults
got=$(orch_template_get "DATE")
current_year=$(date '+%Y')
if [[ "$got" == *"$current_year"* ]]; then
    pass "orch_template_set_defaults sets DATE (contains current year)"
else
    fail "orch_template_set_defaults sets DATE (got: '$got')"
fi

# 8. orch_template_set_defaults sets GIT_RULES (contains "NEVER")
got=$(orch_template_get "GIT_RULES")
if [[ "$got" == *"NEVER"* ]]; then
    pass "orch_template_set_defaults sets GIT_RULES (contains NEVER)"
else
    fail "orch_template_set_defaults sets GIT_RULES (got: '$got')"
fi

# 9. orch_template_set_defaults sets PROTECTED_FILES (contains "CLAUDE.md")
got=$(orch_template_get "PROTECTED_FILES")
if [[ "$got" == *"CLAUDE.md"* ]]; then
    pass "orch_template_set_defaults sets PROTECTED_FILES (contains CLAUDE.md)"
else
    fail "orch_template_set_defaults sets PROTECTED_FILES (got: '$got')"
fi

# 10. orch_template_set_defaults sets AUTO_CYCLE_RULES (contains "auto")
got=$(orch_template_get "AUTO_CYCLE_RULES")
if [[ "$got" == *"auto"* ]]; then
    pass "orch_template_set_defaults sets AUTO_CYCLE_RULES (contains auto)"
else
    fail "orch_template_set_defaults sets AUTO_CYCLE_RULES (got: '$got')"
fi

# 11. orch_template_list_vars lists set vars
orch_template_init "$PROJECT_ROOT"
orch_template_set "ALPHA" "a"
orch_template_set "BETA" "b"
listed=$(orch_template_list_vars)
if [[ "$listed" == *"ALPHA"* ]] && [[ "$listed" == *"BETA"* ]]; then
    pass "orch_template_list_vars lists set vars"
else
    fail "orch_template_list_vars lists set vars (got: '$listed')"
fi

# --- Create temp template files for render tests ---
TEMPLATE_FILE="$TMPDIR_TEST/template.txt"
cat > "$TEMPLATE_FILE" << 'EOF'
Agent: {{AGENT_NAME}}
Date: {{DATE}}
{{GIT_RULES}}
Tasks: {{TASKS}}
Unknown: {{UNKNOWN_VAR}}
EOF

# 12. orch_template_render replaces {{VAR}} in file
orch_template_init "$PROJECT_ROOT"
orch_template_set "AGENT_NAME" "06-Backend"
rendered=$(orch_template_render "$TEMPLATE_FILE")
if [[ "$rendered" == *"Agent: 06-Backend"* ]]; then
    pass "orch_template_render replaces {{VAR}} in file"
else
    fail "orch_template_render replaces {{VAR}} in file (got: '$rendered')"
fi

# 13. orch_template_render leaves {{UNKNOWN}} as-is
if [[ "$rendered" == *"{{UNKNOWN_VAR}}"* ]]; then
    pass "orch_template_render leaves {{UNKNOWN}} as-is"
else
    fail "orch_template_render leaves {{UNKNOWN}} as-is"
fi

# 14. orch_template_render handles multiple vars in one file
orch_template_set "TASKS" "build stuff"
orch_template_set "DATE" "2026-03-20"
rendered=$(orch_template_render "$TEMPLATE_FILE")
if [[ "$rendered" == *"Agent: 06-Backend"* ]] && \
   [[ "$rendered" == *"Date: 2026-03-20"* ]] && \
   [[ "$rendered" == *"Tasks: build stuff"* ]]; then
    pass "orch_template_render handles multiple vars in one file"
else
    fail "orch_template_render handles multiple vars in one file"
fi

# 15. orch_template_render_to_file creates output file
OUTPUT_FILE="$TMPDIR_TEST/rendered-output.txt"
orch_template_render_to_file "$TEMPLATE_FILE" "$OUTPUT_FILE"
if [[ -f "$OUTPUT_FILE" ]] && [[ -s "$OUTPUT_FILE" ]]; then
    pass "orch_template_render_to_file creates output file"
else
    fail "orch_template_render_to_file creates output file"
fi

# 16. orch_template_render returns 1 for missing file
if ! orch_template_render "$TMPDIR_TEST/nonexistent.txt" 2>/dev/null; then
    pass "orch_template_render returns 1 for missing file"
else
    fail "orch_template_render returns 1 for missing file"
fi

# 17. orch_template_estimate_savings returns 3 values
orch_template_init "$PROJECT_ROOT"
orch_template_set_defaults
orch_template_set "AGENT_NAME" "06-Backend"
orch_template_set "TASKS" "build stuff"
savings=$(orch_template_estimate_savings "$TEMPLATE_FILE")
word_count=$(echo "$savings" | wc -w)
if [[ "$word_count" -eq 3 ]]; then
    pass "orch_template_estimate_savings returns 3 values"
else
    fail "orch_template_estimate_savings returns 3 values (got $word_count words: '$savings')"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed ($(( PASS + FAIL )) total)"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
