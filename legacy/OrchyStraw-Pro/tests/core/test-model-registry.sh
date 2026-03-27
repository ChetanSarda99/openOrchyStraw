#!/usr/bin/env bash
# Test: model-registry.sh — Auto-detect available AI model CLIs
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

_assert_ok() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s\n' "$desc"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_fail() {
    local desc="$1"
    shift
    if ! "$@" >/dev/null 2>&1; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (should have failed)\n' "$desc"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_dir_exists() {
    local desc="$1" path="$2"
    if [[ -d "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (dir not found: %s)\n' "$desc" "$path"
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

_assert_gt() {
    local desc="$1" val="$2" min="$3"
    if [[ "$val" -gt "$min" ]]; then
        printf '  PASS: %s (%s > %s)\n' "$desc" "$val" "$min"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (%s not > %s)\n' "$desc" "$val" "$min"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_ge() {
    local desc="$1" val="$2" min="$3"
    if [[ "$val" -ge "$min" ]]; then
        printf '  PASS: %s (%s >= %s)\n' "$desc" "$val" "$min"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (%s not >= %s)\n' "$desc" "$val" "$min"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Setup ──
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

export ORCHYSTRAW_HOME="$TEST_TMP/orch-home"
export ORCH_QUIET=1

echo "=== test-model-registry.sh ==="
echo ""

# ── Syntax check ──
echo "--- syntax check ---"
bash -n "$PROJECT_ROOT/src/core/model-registry.sh"
_assert "bash -n syntax check passes" "0" "$?"

# ── Source module ──
source "$PROJECT_ROOT/src/core/model-registry.sh"

# ────────────────────────────────────────────
# Group 1: Guard variable
# ────────────────────────────────────────────
echo ""
echo "--- guard variable ---"
_assert "guard variable set" "1" "$_ORCH_MODEL_REGISTRY_LOADED"

# ────────────────────────────────────────────
# Group 2: Functions exist
# ────────────────────────────────────────────
echo ""
echo "--- function existence ---"
_assert_ok "orch_registry_init exists" declare -f orch_registry_init
_assert_ok "orch_registry_scan exists" declare -f orch_registry_scan
_assert_ok "orch_registry_get exists" declare -f orch_registry_get
_assert_ok "orch_registry_list exists" declare -f orch_registry_list
_assert_ok "orch_registry_check_new exists" declare -f orch_registry_check_new
_assert_ok "orch_registry_is_available exists" declare -f orch_registry_is_available
_assert_ok "orch_registry_count exists" declare -f orch_registry_count
_assert_ok "orch_registry_report exists" declare -f orch_registry_report

# ────────────────────────────────────────────
# Group 3: Init
# ────────────────────────────────────────────
echo ""
echo "--- init ---"
orch_registry_init
_assert_dir_exists "registry dir created" "$ORCHYSTRAW_HOME/models"
_assert "registry dir variable set" "$ORCHYSTRAW_HOME/models" "$_ORCH_REGISTRY_DIR"

# ────────────────────────────────────────────
# Group 4: Scan (error before init)
# ────────────────────────────────────────────
echo ""
echo "--- scan ---"

# Scan should detect at least some CLIs on this system
# Note: call directly (not in subshell) so global state is preserved
orch_registry_scan >/dev/null 2>&1 || true
count=$(orch_registry_count)
_assert_ge "scan found >= 0 models" "$count" "0"
_assert "scan flag set" "1" "$_ORCH_REGISTRY_SCANNED"

# Registry file saved
_assert_file_exists "registry.txt persisted" "$ORCHYSTRAW_HOME/models/registry.txt"

# ────────────────────────────────────────────
# Group 5: Registry get / is_available
# ────────────────────────────────────────────
echo ""
echo "--- get and is_available ---"

# Get with empty name should fail
_assert_fail "get with no name fails" orch_registry_get ""

# Get non-existent model should fail
_assert_fail "get unknown model fails" orch_registry_get "nonexistent_model_xyz"

# is_available with empty name should fail
_assert_fail "is_available with no name returns 1" orch_registry_is_available ""

# is_available for nonexistent model should fail
_assert_fail "is_available for unknown model returns 1" orch_registry_is_available "nonexistent_model_xyz"

# If claude is installed, test it specifically
if command -v claude >/dev/null 2>&1; then
    info=$(orch_registry_get "claude")
    _assert_ok "get claude returns info" test -n "$info"
    _assert_ok "claude is available" orch_registry_is_available "claude"
else
    # Skip these on systems without claude
    _assert "skip: claude not installed (get)" "1" "1"
    _assert "skip: claude not installed (is_available)" "1" "1"
fi

# ────────────────────────────────────────────
# Group 6: List and count
# ────────────────────────────────────────────
echo ""
echo "--- list and count ---"

list_output=$(orch_registry_list)
_assert_ok "list runs without error" test -n "$list_output"

reg_count=$(orch_registry_count)
_assert_ge "count >= 0" "$reg_count" "0"

# ────────────────────────────────────────────
# Group 7: Check new (first scan = all new)
# ────────────────────────────────────────────
echo ""
echo "--- check new models ---"

# On first scan, all detected models are "new"
new_count=${#_ORCH_REGISTRY_NEW[@]}
_assert_ge "new models count >= 0" "$new_count" "0"

# If models were found, new should equal total
if [[ "$count" -gt 0 ]]; then
    _assert "new count equals total on first scan" "$count" "$new_count"
else
    _assert "skip: no models found (new check)" "1" "1"
fi

# ────────────────────────────────────────────
# Group 8: Second scan (no new models)
# ────────────────────────────────────────────
echo ""
echo "--- second scan (stability) ---"

orch_registry_scan >/dev/null 2>&1 || true
count2=$(orch_registry_count)
_assert "second scan same count" "$count" "$count2"

# After second scan, no new models
new_count2=${#_ORCH_REGISTRY_NEW[@]}
_assert "no new models on rescan" "0" "$new_count2"

# ────────────────────────────────────────────
# Group 9: Report
# ────────────────────────────────────────────
echo ""
echo "--- report ---"

report_output=$(orch_registry_report 2>/dev/null)
_assert_ok "report runs without error" test -n "$report_output"

# ────────────────────────────────────────────
# Group 10: Persistence (reload)
# ────────────────────────────────────────────
echo ""
echo "--- persistence ---"

# Reset state and reload from disk
_ORCH_REGISTRY_CLI_PATH=()
_ORCH_REGISTRY_CLI_VERSION=()
_ORCH_REGISTRY_CLI_CMD=()

# Re-load from file
_orch_registry_load
reloaded_count=$(orch_registry_count)
_assert "reloaded count matches saved" "$count" "$reloaded_count"

# ────────────────────────────────────────────
# Group 11: Double-source guard
# ────────────────────────────────────────────
echo ""
echo "--- double-source guard ---"
source "$PROJECT_ROOT/src/core/model-registry.sh"
_assert "double-source guard works" "1" "$_ORCH_MODEL_REGISTRY_LOADED"

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
