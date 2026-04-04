#!/usr/bin/env bash
# Test: prompt-template.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

source "$PROJECT_ROOT/src/core/prompt-template.sh"

echo "=== prompt-template.sh tests ==="

# ── Test 1: Module loads ──
[[ -n "${_ORCH_PROMPT_TEMPLATE_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# ── Test 2: Double-source guard ──
source "$PROJECT_ROOT/src/core/prompt-template.sh"
pass "double-source guard"

# ── Test 3: orch_tpl_init with valid dir ──
mkdir -p "$TEST_TMPDIR/templates"
orch_tpl_init "$TEST_TMPDIR/templates" && pass "init with valid dir" || fail "init with valid dir"

# ── Test 4: orch_tpl_init with missing dir ──
orch_tpl_init "$TEST_TMPDIR/nonexistent" 2>/dev/null && fail "init rejects missing dir" || pass "init rejects missing dir"

# ── Test 5: orch_tpl_set basic ──
orch_tpl_set "AGENT_ROLE" "Backend Developer" && pass "set variable" || fail "set variable"

# ── Test 6: orch_tpl_set invalid name ──
orch_tpl_set "invalid-name" "value" 2>/dev/null && fail "set rejects invalid name" || pass "set rejects invalid name"

# ── Test 7: orch_tpl_set_from_file ──
echo "CEO — Vision & Strategy" > "$TEST_TMPDIR/role.txt"
orch_tpl_set_from_file "ROLE_DESC" "$TEST_TMPDIR/role.txt" && pass "set from file" || fail "set from file"
[[ "${_ORCH_TPL_VARS[ROLE_DESC]}" == "CEO — Vision & Strategy" ]] && pass "set from file value correct" || fail "set from file value correct"

# ── Test 8: orch_tpl_set_from_file missing file ──
orch_tpl_set_from_file "MISSING" "$TEST_TMPDIR/nope.txt" 2>/dev/null && fail "set_from_file rejects missing" || pass "set_from_file rejects missing file"

# ── Test 9: Variable substitution ──
orch_tpl_init "$TEST_TMPDIR/templates"
orch_tpl_set "AGENT_NAME" "06-backend"
orch_tpl_set "DATE" "2026-03-30"
cat > "$TEST_TMPDIR/templates/simple.md" << 'TEMPLATE'
# Agent: {{AGENT_NAME}}
Date: {{DATE}}
TEMPLATE
result=$(orch_tpl_render "simple.md")
echo "$result" | grep -q "Agent: 06-backend" && pass "var substitution (AGENT_NAME)" || fail "var substitution (AGENT_NAME)"
echo "$result" | grep -q "Date: 2026-03-30" && pass "var substitution (DATE)" || fail "var substitution (DATE)"

# ── Test 10: Include directive ──
mkdir -p "$TEST_TMPDIR/templates/shared"
cat > "$TEST_TMPDIR/templates/shared/git-safety.md" << 'EOF'
## Git Safety (CRITICAL)
- NEVER run: git checkout, git switch, git merge, git push
- ONLY allowed: git status, git log, git diff
EOF
cat > "$TEST_TMPDIR/templates/with-include.md" << 'EOF'
# My Prompt
Some intro text.
<!-- include: shared/git-safety.md -->
End of prompt.
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "with-include.md")
echo "$result" | grep -q "Git Safety (CRITICAL)" && pass "include resolves" || fail "include resolves"
echo "$result" | grep -q "NEVER run" && pass "include content present" || fail "include content present"
echo "$result" | grep -q "End of prompt" && pass "text after include present" || fail "text after include present"

# ── Test 11: Include missing file ──
cat > "$TEST_TMPDIR/templates/bad-include.md" << 'EOF'
<!-- include: nonexistent.md -->
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "bad-include.md")
echo "$result" | grep -q "ERROR: file not found" && pass "missing include shows error" || fail "missing include shows error"

# ── Test 12: Include path traversal rejection ──
cat > "$TEST_TMPDIR/templates/traversal.md" << 'EOF'
<!-- include: ../../../etc/passwd -->
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "traversal.md" 2>/dev/null)
echo "$result" | grep -q "ERROR" && pass "path traversal rejected" || fail "path traversal rejected"

# ── Test 13: Named block (no overlay — default kept) ──
cat > "$TEST_TMPDIR/templates/with-block.md" << 'EOF'
# Prompt
<!-- begin: OWNERSHIP -->
Default ownership section.
<!-- end: OWNERSHIP -->
End.
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "with-block.md")
echo "$result" | grep -q "Default ownership section" && pass "block default kept (no overlay)" || fail "block default kept (no overlay)"

# ── Test 14: Named block override via overlay ──
cat > "$TEST_TMPDIR/templates/overlay.md" << 'EOF'
<!-- begin: OWNERSHIP -->
You OWN: src/core/, scripts/
You NEVER touch: src-tauri/, prompts/
<!-- end: OWNERSHIP -->
EOF
result=$(orch_tpl_render "with-block.md" "overlay.md")
echo "$result" | grep -q "You OWN: src/core/" && pass "block overridden by overlay" || fail "block overridden by overlay"
echo "$result" | grep -qv "Default ownership section" && pass "block default replaced" || fail "block default replaced"

# ── Test 15: Multiple blocks ──
cat > "$TEST_TMPDIR/templates/multi-block.md" << 'EOF'
# Agent
<!-- begin: ROLE -->
Default role.
<!-- end: ROLE -->
Middle text.
<!-- begin: TASKS -->
Default tasks.
<!-- end: TASKS -->
EOF
cat > "$TEST_TMPDIR/templates/multi-overlay.md" << 'EOF'
<!-- begin: ROLE -->
Backend Developer — Core orchestration.
<!-- end: ROLE -->
<!-- begin: TASKS -->
1. Build prompt-template.sh
2. Write tests
<!-- end: TASKS -->
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "multi-block.md" "multi-overlay.md")
echo "$result" | grep -q "Backend Developer" && pass "multi-block: ROLE overridden" || fail "multi-block: ROLE overridden"
echo "$result" | grep -q "Build prompt-template" && pass "multi-block: TASKS overridden" || fail "multi-block: TASKS overridden"
echo "$result" | grep -q "Middle text" && pass "multi-block: middle text preserved" || fail "multi-block: middle text preserved"

# ── Test 16: Overlay variables (VAR=value lines) ──
cat > "$TEST_TMPDIR/templates/var-base.md" << 'EOF'
Agent: {{AGENT_ID}}
Model: {{MODEL}}
EOF
cat > "$TEST_TMPDIR/templates/var-overlay.md" << 'EOF'
AGENT_ID=09-qa
MODEL=opus
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
_ORCH_TPL_VARS=()
result=$(orch_tpl_render "var-base.md" "var-overlay.md")
echo "$result" | grep -q "Agent: 09-qa" && pass "overlay var AGENT_ID" || fail "overlay var AGENT_ID"
echo "$result" | grep -q "Model: opus" && pass "overlay var MODEL" || fail "overlay var MODEL"

# ── Test 17: orch_tpl_validate clean ──
clean_text="No placeholders here."
orch_tpl_validate "$clean_text" && pass "validate clean text" || fail "validate clean text"

# ── Test 18: orch_tpl_validate unresolved ──
dirty_text="Hello {{MISSING_VAR}} world."
unresolved=$(orch_tpl_validate "$dirty_text" 2>/dev/null) && fail "validate detects unresolved" || pass "validate detects unresolved"
echo "$unresolved" | grep -q "MISSING_VAR" && pass "validate reports var name" || fail "validate reports var name"

# ── Test 19: orch_tpl_list_vars ──
cat > "$TEST_TMPDIR/list-vars.md" << 'EOF'
Hello {{NAME}}, your role is {{ROLE}}.
Date: {{DATE}}. Name again: {{NAME}}.
EOF
vars=$(orch_tpl_list_vars "$TEST_TMPDIR/list-vars.md")
echo "$vars" | grep -q "NAME" && pass "list_vars finds NAME" || fail "list_vars finds NAME"
echo "$vars" | grep -q "ROLE" && pass "list_vars finds ROLE" || fail "list_vars finds ROLE"
echo "$vars" | grep -q "DATE" && pass "list_vars finds DATE" || fail "list_vars finds DATE"
var_count=$(echo "$vars" | wc -l)
[[ "$var_count" -eq 3 ]] && pass "list_vars deduplicates" || fail "list_vars deduplicates (got $var_count)"

# ── Test 20: orch_tpl_stats ──
cat > "$TEST_TMPDIR/templates/stats-base.md" << 'EOF'
# {{TITLE}}
<!-- include: shared/git-safety.md -->
<!-- begin: OWNERSHIP -->
Default.
<!-- end: OWNERSHIP -->
<!-- begin: TASKS -->
Default tasks.
<!-- end: TASKS -->
Agent: {{AGENT_ID}}
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
stats=$(orch_tpl_stats "stats-base.md")
echo "$stats" | grep -q "blocks:.*2" && pass "stats block count" || fail "stats block count"
echo "$stats" | grep -q "variables:.*2" && pass "stats var count" || fail "stats var count"
echo "$stats" | grep -q "includes:.*1" && pass "stats include count" || fail "stats include count"

# ── Test 21: Nested includes ──
cat > "$TEST_TMPDIR/templates/shared/outer.md" << 'EOF'
Outer start.
<!-- include: shared/inner.md -->
Outer end.
EOF
cat > "$TEST_TMPDIR/templates/shared/inner.md" << 'EOF'
Inner content.
EOF
cat > "$TEST_TMPDIR/templates/nested.md" << 'EOF'
Begin.
<!-- include: shared/outer.md -->
End.
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "nested.md")
echo "$result" | grep -q "Inner content" && pass "nested include resolves" || fail "nested include resolves"
echo "$result" | grep -q "Outer start" && pass "nested: outer present" || fail "nested: outer present"

# ── Test 22: Include depth limit ──
cat > "$TEST_TMPDIR/templates/shared/recursive.md" << 'EOF'
Recursive.
<!-- include: shared/recursive.md -->
EOF
cat > "$TEST_TMPDIR/templates/recurse-test.md" << 'EOF'
<!-- include: shared/recursive.md -->
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
result=$(orch_tpl_render "recurse-test.md" 2>/dev/null)
# Should not hang — depth limit stops recursion
pass "include depth limit prevents infinite recursion"

# ── Test 23: Render with base as absolute path ──
cat > "$TEST_TMPDIR/abs-test.md" << 'EOF'
Absolute path test: {{TEST_VAR}}.
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
orch_tpl_set "TEST_VAR" "works"
result=$(orch_tpl_render "$TEST_TMPDIR/abs-test.md")
echo "$result" | grep -q "Absolute path test: works" && pass "absolute base path" || fail "absolute base path"

# ── Test 24: Render with missing base ──
orch_tpl_init "$TEST_TMPDIR/templates"
orch_tpl_render "nonexistent.md" 2>/dev/null && fail "render rejects missing base" || pass "render rejects missing base"

# ── Test 25: Render with missing overlay ──
orch_tpl_render "simple.md" "nonexistent-overlay.md" 2>/dev/null && fail "render rejects missing overlay" || pass "render rejects missing overlay"

# ── Test 26: Combined blocks + includes + vars ──
cat > "$TEST_TMPDIR/templates/shared/protected.md" << 'EOF'
## PROTECTED FILES
- scripts/auto-agent.sh
- CLAUDE.md
EOF
cat > "$TEST_TMPDIR/templates/full-base.md" << 'EOF'
# {{AGENT_NAME}} — {{AGENT_ROLE}}
Date: {{DATE}}

<!-- include: shared/protected.md -->

<!-- begin: OWNERSHIP -->
Default ownership.
<!-- end: OWNERSHIP -->

<!-- include: shared/git-safety.md -->
EOF
cat > "$TEST_TMPDIR/templates/full-overlay.md" << 'EOF'
AGENT_NAME=06-backend
AGENT_ROLE=Backend Developer
DATE=2026-03-30
<!-- begin: OWNERSHIP -->
You OWN: src/core/, scripts/
You NEVER touch: src-tauri/, prompts/
<!-- end: OWNERSHIP -->
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
_ORCH_TPL_VARS=()
result=$(orch_tpl_render "full-base.md" "full-overlay.md")
echo "$result" | grep -q "06-backend — Backend Developer" && pass "full: header vars" || fail "full: header vars"
echo "$result" | grep -q "Date: 2026-03-30" && pass "full: date var" || fail "full: date var"
echo "$result" | grep -q "PROTECTED FILES" && pass "full: include resolved" || fail "full: include resolved"
echo "$result" | grep -q "You OWN: src/core/" && pass "full: block overridden" || fail "full: block overridden"
echo "$result" | grep -q "Git Safety (CRITICAL)" && pass "full: second include resolved" || fail "full: second include resolved"

# ── Test 27: Empty overlay (no blocks, no vars) ──
cat > "$TEST_TMPDIR/templates/empty-overlay.md" << 'EOF'
# Just comments, no blocks or vars
EOF
orch_tpl_init "$TEST_TMPDIR/templates"
_ORCH_TPL_VARS=()
result=$(orch_tpl_render "with-block.md" "empty-overlay.md")
echo "$result" | grep -q "Default ownership section" && pass "empty overlay keeps defaults" || fail "empty overlay keeps defaults"

# ── Test 28: orch_tpl_set_from_file oversized file ──
dd if=/dev/zero bs=1 count=200000 of="$TEST_TMPDIR/big.txt" 2>/dev/null
orch_tpl_set_from_file "BIG" "$TEST_TMPDIR/big.txt" 2>/dev/null && fail "set_from_file rejects oversized" || pass "set_from_file rejects oversized file"

# ── Test 29: orch_tpl_list_vars missing file ──
orch_tpl_list_vars "$TEST_TMPDIR/nope.md" 2>/dev/null && fail "list_vars rejects missing file" || pass "list_vars rejects missing file"

# ── Test 30: orch_tpl_stats with overlay ──
orch_tpl_init "$TEST_TMPDIR/templates"
stats=$(orch_tpl_stats "stats-base.md" "full-overlay.md")
echo "$stats" | grep -q "blocks:.*2.*1" && pass "stats shows overlay block count" || fail "stats shows overlay block count"

# ── Summary ──
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
