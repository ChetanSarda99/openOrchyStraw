#!/usr/bin/env bash
# Test: prompt-template.sh v0.4 — conditionals, defaults, mixins
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/prompt-template.sh"

echo "=== prompt-template.sh v0.4 tests ==="

# Setup template directory — resolve to real path to avoid Windows/MSYS2 path mismatches
mkdir -p "$TEST_DIR/templates"
TPL_DIR="$(cd "$TEST_DIR/templates" && pwd)"
orch_tpl_init "$TPL_DIR"

# ---------------------------------------------------------------------------
# Default values — {{VAR|default}}
# ---------------------------------------------------------------------------

# Test 1: Default value used when var not set
_ORCH_TPL_VARS=()
result=$(orch_tpl_resolve_defaults "Hello {{NAME|World}}")
[[ "$result" == "Hello World" ]] && pass "default: unset var uses default" || fail "default: unset var uses default (got '$result')"

# Test 2: Set var overrides default
_ORCH_TPL_VARS=()
orch_tpl_set "NAME" "Alice"
result=$(orch_tpl_resolve_defaults "Hello {{NAME|World}}")
[[ "$result" == "Hello Alice" ]] && pass "default: set var overrides default" || fail "default: set var overrides default (got '$result')"

# Test 3: Multiple defaults in one line
_ORCH_TPL_VARS=()
result=$(orch_tpl_resolve_defaults "{{A|foo}} and {{B|bar}}")
[[ "$result" == "foo and bar" ]] && pass "default: multiple defaults" || fail "default: multiple defaults (got '$result')"

# Test 4: Empty default value
_ORCH_TPL_VARS=()
result=$(orch_tpl_resolve_defaults "start{{X|}}end")
[[ "$result" == "startend" ]] && pass "default: empty default" || fail "default: empty default (got '$result')"

# ---------------------------------------------------------------------------
# Conditionals — {% if VAR %}...{% endif %}
# ---------------------------------------------------------------------------

# Test 5: Truthy condition includes content
_ORCH_TPL_VARS=()
orch_tpl_set "HAS_TESTS" "yes"
input=$'{% if HAS_TESTS %}\nRun the test suite.\n{% endif %}'
result=$(orch_tpl_resolve_conditionals "$input")
echo "$result" | grep -q "Run the test suite" && pass "conditional: truthy includes" || fail "conditional: truthy includes"

# Test 6: Falsy condition excludes content
_ORCH_TPL_VARS=()
input=$'{% if HAS_TESTS %}\nRun the test suite.\n{% endif %}'
result=$(orch_tpl_resolve_conditionals "$input")
if echo "$result" | grep -q "Run the test suite"; then
    fail "conditional: falsy excludes"
else
    pass "conditional: falsy excludes"
fi

# Test 7: If/else — truthy branch
_ORCH_TPL_VARS=()
orch_tpl_set "LANG" "python"
input=$'{% if LANG %}\nUse Python.\n{% else %}\nUse default.\n{% endif %}'
result=$(orch_tpl_resolve_conditionals "$input")
echo "$result" | grep -q "Use Python" && pass "if/else: truthy branch" || fail "if/else: truthy branch"

# Test 8: If/else — falsy branch
_ORCH_TPL_VARS=()
input=$'{% if LANG %}\nUse Python.\n{% else %}\nUse default.\n{% endif %}'
result=$(orch_tpl_resolve_conditionals "$input")
echo "$result" | grep -q "Use default" && pass "if/else: falsy branch" || fail "if/else: falsy branch"

# Test 9: Negated condition
_ORCH_TPL_VARS=()
input=$'{% if !DEBUG %}\nProduction mode.\n{% endif %}'
result=$(orch_tpl_resolve_conditionals "$input")
echo "$result" | grep -q "Production mode" && pass "conditional: negation works" || fail "conditional: negation works"

# Test 10: Negated condition — var is set
_ORCH_TPL_VARS=()
orch_tpl_set "DEBUG" "true"
input=$'{% if !DEBUG %}\nProduction mode.\n{% endif %}'
result=$(orch_tpl_resolve_conditionals "$input")
if echo "$result" | grep -q "Production mode"; then
    fail "conditional: negation excludes when set"
else
    pass "conditional: negation excludes when set"
fi

# Test 11: Content outside conditionals preserved
_ORCH_TPL_VARS=()
orch_tpl_set "X" "1"
input=$'Before\n{% if X %}\nInside\n{% endif %}\nAfter'
result=$(orch_tpl_resolve_conditionals "$input")
echo "$result" | grep -q "Before" && pass "conditional: before preserved" || fail "conditional: before preserved"
echo "$result" | grep -q "After" && pass "conditional: after preserved" || fail "conditional: after preserved"

# ---------------------------------------------------------------------------
# Mixins — <!-- mixin: name -->
# ---------------------------------------------------------------------------

# Test 12: Register and resolve mixin
cat > "$TPL_DIR/safety.md" <<'EOF'
## Safety Rules
Do not modify protected files.
EOF

orch_tpl_add_mixin "safety" "$TPL_DIR/safety.md"
input="Header
<!-- mixin: safety -->
Footer"
result=$(orch_tpl_resolve_mixins "$input")
echo "$result" | grep -q "Safety Rules" && pass "mixin: resolved" || fail "mixin: resolved"
echo "$result" | grep -q "Header" && pass "mixin: header preserved" || fail "mixin: header preserved"
echo "$result" | grep -q "Footer" && pass "mixin: footer preserved" || fail "mixin: footer preserved"

# Test 13: Unregistered mixin produces error comment
input="<!-- mixin: nonexistent -->"
result=$(orch_tpl_resolve_mixins "$input")
echo "$result" | grep -q "ERROR" && pass "mixin: unregistered produces error" || fail "mixin: unregistered produces error"

# Test 14: Mixin with variable substitution
cat > "$TPL_DIR/greeting.md" <<'EOF'
Hello {{AGENT_NAME}}, welcome to the team.
EOF

_ORCH_TPL_VARS=()
orch_tpl_set "AGENT_NAME" "Backend"
orch_tpl_add_mixin "greeting" "$TPL_DIR/greeting.md"
input="<!-- mixin: greeting -->"
result=$(orch_tpl_resolve_mixins "$input")
echo "$result" | grep -q "Hello Backend" && pass "mixin: vars substituted" || fail "mixin: vars substituted"

# ---------------------------------------------------------------------------
# orch_tpl_render_v2 — full pipeline
# ---------------------------------------------------------------------------

# Test 15: render_v2 processes conditionals + defaults + mixins
cat > "$TPL_DIR/base.md" <<'EOF'
# Agent: {{ROLE|Unknown Role}}

{% if HAS_TESTS %}
## Testing
Run tests before committing.
{% endif %}

<!-- begin: TASKS -->
Default tasks here.
<!-- end: TASKS -->

<!-- mixin: safety -->
EOF

cat > "$TPL_DIR/overlay.md" <<'EOF'
ROLE=Backend Developer
HAS_TESTS=yes
<!-- begin: TASKS -->
1. Fix the bug
2. Add logging
<!-- end: TASKS -->
EOF

orch_tpl_init "$TEST_DIR/templates"
_ORCH_TPL_VARS=()
orch_tpl_add_mixin "safety" "$TPL_DIR/safety.md"

result=$(orch_tpl_render_v2 "base.md" "overlay.md")
echo "$result" | grep -q "Backend Developer" && pass "render_v2: var substituted" || fail "render_v2: var substituted"
echo "$result" | grep -q "Run tests" && pass "render_v2: conditional included" || fail "render_v2: conditional included"
echo "$result" | grep -q "Fix the bug" && pass "render_v2: block overridden" || fail "render_v2: block overridden"
echo "$result" | grep -q "Safety Rules" && pass "render_v2: mixin included" || fail "render_v2: mixin included"

# Test 16: render_v2 without overlay
_ORCH_TPL_VARS=()
result=$(orch_tpl_render_v2 "base.md")
echo "$result" | grep -q "Unknown Role" && pass "render_v2: default used without overlay" || fail "render_v2: default used without overlay"
echo "$result" | grep -q "Default tasks" && pass "render_v2: default block kept" || fail "render_v2: default block kept"

# Test 17: render_v2 non-existent base fails
if ! orch_tpl_render_v2 "nonexistent.md" 2>/dev/null; then
    pass "render_v2: missing base fails"
else
    fail "render_v2: missing base fails"
fi

# Test 18: Add mixin with non-existent file fails
if ! orch_tpl_add_mixin "bad" "$TPL_DIR/nope.md" 2>/dev/null; then
    pass "add_mixin: non-existent file fails"
else
    fail "add_mixin: non-existent file fails"
fi

echo ""
echo "prompt-template v0.4: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
