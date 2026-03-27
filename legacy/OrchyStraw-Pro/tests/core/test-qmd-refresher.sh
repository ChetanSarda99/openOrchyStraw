#!/usr/bin/env bash
# Test: qmd-refresher.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Set up temp state dir so tests don't touch real project state
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

export ORCH_STATE_DIR="$TEST_TMPDIR/state"

source "$PROJECT_ROOT/src/core/qmd-refresher.sh"

echo "=== qmd-refresher.sh tests ==="

# Test 1: Module loads
[[ -n "${_ORCH_QMD_REFRESHER_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Double-source guard
source "$PROJECT_ROOT/src/core/qmd-refresher.sh"
pass "double-source guard"

# Test 3: orch_qmd_available returns 1 when qmd is not installed
if ! command -v qmd &>/dev/null; then
    orch_qmd_available && fail "qmd_available returns 0 without qmd" || pass "qmd_available returns 1 without qmd"
else
    pass "qmd_available (qmd is installed, skipping negative test)"
fi

# Test 4: State directory creation
_orch_qmd_ensure_state_dir
[[ -d "$ORCH_STATE_DIR" ]] && pass "state dir created" || fail "state dir created"

# Test 5: Timestamp write/read
_orch_qmd_write_timestamp "test-file"
ts=$(_orch_qmd_read_timestamp "test-file")
now=$(date +%s)
diff=$(( now - ts ))
(( diff >= 0 && diff <= 5 )) && pass "timestamp write/read" || fail "timestamp write/read (diff=$diff)"

# Test 6: Timestamp read for missing file returns "0"
ts=$(_orch_qmd_read_timestamp "nonexistent-file")
[[ "$ts" == "0" ]] && pass "missing timestamp returns 0" || fail "missing timestamp returns 0 (got '$ts')"

# Test 7: orch_qmd_status output format
status_output=$(orch_qmd_status)
echo "$status_output" | grep -q "^qmd=" && pass "status contains qmd=" || fail "status contains qmd="
echo "$status_output" | grep -q "^last_update=" && pass "status contains last_update=" || fail "status contains last_update="
echo "$status_output" | grep -q "^last_embed=" && pass "status contains last_embed=" || fail "status contains last_embed="

# Test 8: orch_qmd_collections_exist returns 1 for missing dir
orch_qmd_collections_exist "$TEST_TMPDIR/no-such-project" && fail "collections_exist missing dir" || pass "collections_exist returns 1 for missing dir"

# Test 9: orch_qmd_collections_exist returns 0 for existing .qmd/ dir
mkdir -p "$TEST_TMPDIR/proj/.qmd"
orch_qmd_collections_exist "$TEST_TMPDIR/proj" && pass "collections_exist returns 0 for existing dir" || fail "collections_exist returns 0 for existing dir"

# Test 10: orch_qmd_refresh returns 1 when qmd unavailable
if ! command -v qmd &>/dev/null; then
    orch_qmd_refresh "." 2>/dev/null && fail "refresh succeeds without qmd" || pass "refresh returns 1 without qmd"
else
    pass "refresh without qmd (skipped, qmd installed)"
fi

# Test 11: orch_qmd_embed returns 1 when qmd unavailable
if ! command -v qmd &>/dev/null; then
    orch_qmd_embed "." 2>/dev/null && fail "embed succeeds without qmd" || pass "embed returns 1 without qmd"
else
    pass "embed without qmd (skipped, qmd installed)"
fi

# Test 12: orch_qmd_auto_refresh returns 1 when qmd unavailable
if ! command -v qmd &>/dev/null; then
    orch_qmd_auto_refresh "false" "." 2>/dev/null && fail "auto_refresh succeeds without qmd" || pass "auto_refresh returns 1 without qmd"
else
    pass "auto_refresh without qmd (skipped, qmd installed)"
fi

# ---------------------------------------------------------------------------
# Mock qmd: override as a bash function that always succeeds
# ---------------------------------------------------------------------------
qmd() { return 0; }
export -f qmd

# Test 13: Mock qmd — orch_qmd_refresh writes timestamp
# Clear any existing update timestamp
rm -f "$ORCH_STATE_DIR/$_ORCH_QMD_UPDATE_STATE_FILE"
orch_qmd_refresh "$TEST_TMPDIR" 2>/dev/null
ts=$(_orch_qmd_read_timestamp "$_ORCH_QMD_UPDATE_STATE_FILE")
[[ "$ts" != "0" ]] && pass "refresh writes update timestamp" || fail "refresh writes update timestamp"

# Test 14: Mock qmd — orch_qmd_auto_refresh with force_embed=true embeds
rm -f "$ORCH_STATE_DIR/$_ORCH_QMD_EMBED_STATE_FILE"
orch_qmd_auto_refresh "true" "$TEST_TMPDIR" 2>/dev/null
ts=$(_orch_qmd_read_timestamp "$_ORCH_QMD_EMBED_STATE_FILE")
[[ "$ts" != "0" ]] && pass "auto_refresh force_embed writes embed timestamp" || fail "auto_refresh force_embed writes embed timestamp"

# Test 15: Mock qmd — orch_qmd_auto_refresh with recent embed skips embed
# Write a very recent embed timestamp so interval hasn't elapsed
printf '%s\n' "$(date +%s)" > "$ORCH_STATE_DIR/$_ORCH_QMD_EMBED_STATE_FILE"
old_ts=$(_orch_qmd_read_timestamp "$_ORCH_QMD_EMBED_STATE_FILE")
sleep 1
orch_qmd_auto_refresh "false" "$TEST_TMPDIR" 2>/dev/null
new_ts=$(_orch_qmd_read_timestamp "$_ORCH_QMD_EMBED_STATE_FILE")
[[ "$new_ts" == "$old_ts" ]] && pass "auto_refresh skips embed when recent" || fail "auto_refresh skips embed when recent (old=$old_ts new=$new_ts)"

# Clean up mock
unset -f qmd

echo ""
echo "qmd-refresher: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
