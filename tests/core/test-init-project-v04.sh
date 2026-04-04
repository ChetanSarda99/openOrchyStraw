#!/usr/bin/env bash
# Test: init-project.sh v0.4 — interactive mode, templates, migration, existing detection
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/init-project.sh"

echo "=== init-project.sh v0.4 tests ==="

# ---------------------------------------------------------------------------
# Detect existing OrchyStraw setup
# ---------------------------------------------------------------------------

# Test 1: No existing setup
mkdir -p "$TEST_DIR/fresh-project/src"
echo "console.log('hi')" > "$TEST_DIR/fresh-project/src/index.js"
if ! orch_init_detect_existing "$TEST_DIR/fresh-project"; then
    pass "detect existing: fresh project returns 1"
else
    fail "detect existing: fresh project returns 1"
fi

# Test 2: Existing setup detected
mkdir -p "$TEST_DIR/existing-project/prompts" "$TEST_DIR/existing-project/src/core"
cat > "$TEST_DIR/existing-project/agents.conf" <<'EOF'
03-pm     | prompts/03-pm/03-pm.txt | prompts/ | 0 | PM
06-backend| prompts/06-backend.txt  | src/     | 1 | Backend
EOF
echo "# Guide" > "$TEST_DIR/existing-project/CLAUDE.md"

if orch_init_detect_existing "$TEST_DIR/existing-project"; then
    pass "detect existing: setup found"
else
    fail "detect existing: setup found"
fi

# Test 3: Version detection
ver=$(orch_init_existing_version)
[[ -n "$ver" ]] && pass "detect existing: version=$ver" || fail "detect existing: version empty"

# ---------------------------------------------------------------------------
# Template marketplace
# ---------------------------------------------------------------------------

# Test 4: List templates returns content
templates=$(orch_init_list_templates)
[[ -n "$templates" ]] && pass "list templates: non-empty" || fail "list templates: non-empty"

# Test 5: Templates include known presets
echo "$templates" | grep -q "solo-dev" && pass "template: solo-dev exists" || fail "template: solo-dev exists"
echo "$templates" | grep -q "fullstack-saas" && pass "template: fullstack-saas exists" || fail "template: fullstack-saas exists"
echo "$templates" | grep -q "api-service" && pass "template: api-service exists" || fail "template: api-service exists"
echo "$templates" | grep -q "cli-tool" && pass "template: cli-tool exists" || fail "template: cli-tool exists"

# Test 6: Apply template sets agents
mkdir -p "$TEST_DIR/tpl-project/src"
echo "const x = 1;" > "$TEST_DIR/tpl-project/src/app.ts"
echo '{"name":"test","dependencies":{"react":"18"}}' > "$TEST_DIR/tpl-project/package.json"

orch_init_scan "$TEST_DIR/tpl-project" 2>/dev/null
orch_init_apply_template "solo-dev"
agents=$(orch_init_suggest_agents)
agent_count=$(echo "$agents" | wc -l)
[[ $agent_count -ge 2 ]] && pass "apply template: agents set ($agent_count)" || fail "apply template: agents set ($agent_count)"

# Test 7: Apply invalid template fails
if ! orch_init_apply_template "nonexistent-template" 2>/dev/null; then
    pass "apply invalid template: fails"
else
    fail "apply invalid template: fails"
fi

# Test 8: fullstack-saas template has expected agents
orch_init_apply_template "fullstack-saas"
agents=$(orch_init_suggest_agents)
echo "$agents" | grep -q "backend" && pass "fullstack-saas: has backend" || fail "fullstack-saas: has backend"
echo "$agents" | grep -q "frontend" && pass "fullstack-saas: has frontend" || fail "fullstack-saas: has frontend"
echo "$agents" | grep -q "qa" && pass "fullstack-saas: has qa" || fail "fullstack-saas: has qa"

# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

# Test 9: Migrate 3-column config to 5-column
cat > "$TEST_DIR/old.conf" <<'EOF'
# Old format config
06-backend | prompts/06.txt | src/
11-web     | prompts/11.txt | site/
EOF

migrated=$(orch_init_migrate "$TEST_DIR/old.conf" 2>/dev/null)
echo "$migrated" | grep -q "| 1 |" && pass "migrate: added interval column" || fail "migrate: added interval column"

# Test 10: Migrate already-current config is no-op
cat > "$TEST_DIR/current.conf" <<'EOF'
06-backend | prompts/06.txt | src/ | 1 | Backend
EOF

migrated=$(orch_init_migrate "$TEST_DIR/current.conf" 2>/dev/null)
echo "$migrated" | grep -q "Backend" && pass "migrate: current format preserved" || fail "migrate: current format preserved"

# Test 11: Migrate non-existent file fails
if ! orch_init_migrate "$TEST_DIR/nope.conf" 2>/dev/null; then
    pass "migrate: non-existent file fails"
else
    fail "migrate: non-existent file fails"
fi

# Test 12: Migrate preserves comments
cat > "$TEST_DIR/commented.conf" <<'EOF'
# This is a comment
06-backend | prompts/06.txt | src/ | 1 | Backend
# Another comment
EOF

migrated=$(orch_init_migrate "$TEST_DIR/commented.conf" 2>/dev/null)
echo "$migrated" | grep -q "^# This is a comment" && pass "migrate: comments preserved" || fail "migrate: comments preserved"

# ---------------------------------------------------------------------------
# Interactive mode (non-TTY, auto-detect path)
# ---------------------------------------------------------------------------

# Test 13: Interactive with non-TTY uses auto-detection
mkdir -p "$TEST_DIR/int-project/src"
echo '{"name":"test","dependencies":{"express":"4"}}' > "$TEST_DIR/int-project/package.json"
echo "const app = require('express')()" > "$TEST_DIR/int-project/src/index.js"

# Run interactive in non-TTY mode (stdin from /dev/null)
output=$(orch_init_interactive "$TEST_DIR/int-project" < /dev/null 2>/dev/null)
[[ -n "$output" ]] && pass "interactive: produces output" || fail "interactive: produces output"

# Test 14: Interactive mode flag
[[ $_ORCH_INIT_INTERACTIVE_MODE -eq 0 ]] && pass "interactive: mode reset after" || fail "interactive: mode reset after"

# Test 15: Template count is at least 5
tpl_count=$(orch_init_list_templates | wc -l)
[[ $tpl_count -ge 5 ]] && pass "templates: at least 5 presets ($tpl_count)" || fail "templates: at least 5 presets ($tpl_count)"

echo ""
echo "init-project v0.4: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
