#!/usr/bin/env bash
# Test: global CLI two-root separation (ORCH_ROOT vs PROJECT_ROOT)
set -euo pipefail

ORCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== global-cli two-root tests ==="

# ---------------------------------------------------------------------------
# Test 1: ORCH_ROOT resolves correctly
# ---------------------------------------------------------------------------
[[ -d "$ORCH_ROOT/src/core" ]] && pass "ORCH_ROOT has src/core" || fail "ORCH_ROOT has src/core"

# ---------------------------------------------------------------------------
# Test 2: bin/orchystraw exists and is executable
# ---------------------------------------------------------------------------
[[ -x "$ORCH_ROOT/bin/orchystraw" ]] && pass "bin/orchystraw is executable" || fail "bin/orchystraw is executable"

# ---------------------------------------------------------------------------
# Test 3: auto-agent.sh rejects direct execution (no ORCH_ROOT/PROJECT_ROOT)
# ---------------------------------------------------------------------------
output=$(env -u ORCH_ROOT -u PROJECT_ROOT bash "$ORCH_ROOT/scripts/auto-agent.sh" 2>&1 || true)
if echo "$output" | grep -q "Run via 'orchystraw' CLI"; then
    pass "auto-agent.sh rejects direct execution"
else
    fail "auto-agent.sh rejects direct execution (got: $output)"
fi

# ---------------------------------------------------------------------------
# Test 4: orchystraw help works
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" help 2>&1 || true)
if echo "$output" | grep -q "Multi-agent AI orchestration CLI"; then
    pass "orchystraw help shows usage"
else
    fail "orchystraw help shows usage"
fi

# ---------------------------------------------------------------------------
# Test 5: orchystraw doctor runs
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" doctor 2>&1 || true)
if echo "$output" | grep -q "environment check"; then
    pass "orchystraw doctor runs"
else
    fail "orchystraw doctor runs"
fi

# ---------------------------------------------------------------------------
# Test 6: orchystraw run without args shows usage
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" run 2>&1 || true)
if echo "$output" | grep -q "Usage:"; then
    pass "orchystraw run without args shows usage"
else
    fail "orchystraw run without args shows usage"
fi

# ---------------------------------------------------------------------------
# Test 7: orchystraw run with invalid path shows error
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" run "/nonexistent/path" 2>&1 || true)
if echo "$output" | grep -qE "ERROR|Cannot resolve"; then
    pass "orchystraw run with invalid path errors"
else
    fail "orchystraw run with invalid path errors"
fi

# ---------------------------------------------------------------------------
# Test 8: orchystraw run validates agents.conf presence
# ---------------------------------------------------------------------------
mkdir -p "$TEST_DIR/empty-project"
output=$("$ORCH_ROOT/bin/orchystraw" run "$TEST_DIR/empty-project" 2>&1 || true)
if echo "$output" | grep -q "No agents.conf"; then
    pass "orchystraw run validates agents.conf"
else
    fail "orchystraw run validates agents.conf"
fi

# ---------------------------------------------------------------------------
# Test 9: orchystraw list works (may be empty)
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" list 2>&1 || true)
if echo "$output" | grep -qE "Registered|No projects"; then
    pass "orchystraw list works"
else
    fail "orchystraw list works"
fi

# ---------------------------------------------------------------------------
# Test 10: ORCH_ROOT is set in help output
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" help 2>&1 || true)
if echo "$output" | grep -q "ORCH_ROOT"; then
    pass "help shows ORCH_ROOT"
else
    fail "help shows ORCH_ROOT"
fi

# ---------------------------------------------------------------------------
# Test 11: orchystraw unknown command errors
# ---------------------------------------------------------------------------
output=$("$ORCH_ROOT/bin/orchystraw" bogus 2>&1 || true)
if echo "$output" | grep -q "Unknown command"; then
    pass "unknown command shows error"
else
    fail "unknown command shows error"
fi

# ---------------------------------------------------------------------------
# Test 12: auto-agent.sh sources modules from ORCH_ROOT not PROJECT_ROOT
# ---------------------------------------------------------------------------
if grep -q 'ORCH_ROOT/src/core' "$ORCH_ROOT/scripts/auto-agent.sh"; then
    pass "auto-agent.sh sources from ORCH_ROOT"
else
    fail "auto-agent.sh sources from ORCH_ROOT"
fi

# ---------------------------------------------------------------------------
# Test 13: CONF_FILE cascade checks PROJECT_ROOT
# ---------------------------------------------------------------------------
if grep -q 'PROJECT_ROOT/agents.conf' "$ORCH_ROOT/scripts/auto-agent.sh" && \
   grep -q 'PROJECT_ROOT/scripts/agents.conf' "$ORCH_ROOT/scripts/auto-agent.sh"; then
    pass "CONF_FILE cascade checks both locations"
else
    fail "CONF_FILE cascade checks both locations"
fi

# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS pass, $FAIL fail ($(( PASS + FAIL )) total)"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
