#!/usr/bin/env bash
# Test: quality-gates.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/quality-gates.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PASS=0
FAIL=0
assert() {
    local desc="$1"
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $desc"
    fi
}

create_conf() {
    cat > "$TMPDIR_TEST/agents.conf" << 'EOF'
06-backend | prompts/06-backend/06-backend.txt | src/core/ scripts/ | 1 | Backend
09-qa      | prompts/09-qa/09-qa.txt           | tests/             | 3 | QA
03-pm      | prompts/03-pm/03-pm.txt           | prompts/ docs/     | 0 | PM
EOF
}

# ── Test: init without conf ──
orch_quality_init "$TMPDIR_TEST"
assert "init without conf succeeds" "true"

# ── Test: init with conf ──
create_conf
orch_quality_init "$TMPDIR_TEST" "$TMPDIR_TEST/agents.conf"
assert "init with conf succeeds" "true"

# ── Test: check passes for good output ──
good_log="$TMPDIR_TEST/good.log"
dd if=/dev/urandom bs=1 count=500 of="$good_log" 2>/dev/null
assert "good output passes quality gate" "orch_quality_check 06-backend '$good_log'"

# ── Test: check fails for tiny output ──
tiny_log="$TMPDIR_TEST/tiny.log"
echo "hi" > "$tiny_log"
assert "tiny output fails quality gate" "! orch_quality_check 06-backend '$tiny_log'"

# ── Test: check fails for huge output ──
ORCH_QUALITY_MAX_OUTPUT=1000 orch_quality_init "$TMPDIR_TEST"
huge_log="$TMPDIR_TEST/huge.log"
dd if=/dev/urandom bs=1 count=2000 of="$huge_log" 2>/dev/null
_ORCH_QUALITY_MAX_OUTPUT=1000
assert "huge output fails quality gate" "! orch_quality_check 06-backend '$huge_log'"

# ── Test: check passes with no log file ──
_ORCH_QUALITY_MAX_OUTPUT=5000000
assert "no log file passes quality gate" "orch_quality_check 06-backend ''"

# ── Test: check passes for agent with no ownership ──
orch_quality_init "$TMPDIR_TEST" "$TMPDIR_TEST/agents.conf"
assert "unknown agent passes (no ownership)" "orch_quality_check unknown-agent '$good_log'"

# ── Results ──
echo ""
echo "quality-gates: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
