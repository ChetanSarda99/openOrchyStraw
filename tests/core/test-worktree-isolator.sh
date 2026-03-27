#!/usr/bin/env bash
# Test: worktree-isolator.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/worktree-isolator.sh"

echo "=== worktree-isolator.sh tests ==="

# Setup temp git repo
TEST_REPO="$TMPDIR_TEST/test-repo"
mkdir -p "$TEST_REPO"
git -C "$TEST_REPO" init
git -C "$TEST_REPO" config user.email "test@test.com"
git -C "$TEST_REPO" config user.name "Test"
git -C "$TEST_REPO" commit --allow-empty -m "Initial commit"

# ── Test 1: Module loads (guard var set) ──
if [[ "${_ORCH_WORKTREE_LOADED:-}" == "1" ]]; then
    pass "module loads — guard var set"
else
    fail "module loads — guard var not set"
fi

# ── Test 2: Double-source guard ──
# Sourcing again should not error (returns early)
source "$PROJECT_ROOT/src/core/worktree-isolator.sh"
if [[ $? -eq 0 ]]; then
    pass "double-source guard works"
else
    fail "double-source guard failed"
fi

# ── Test 3: Init with valid git repo ──
if orch_worktree_init "$TEST_REPO" 1 2>/dev/null; then
    pass "init with valid git repo"
else
    fail "init with valid git repo"
fi

# ── Test 4: Create worktree ──
if orch_worktree_create "06-backend" 2>/dev/null; then
    wt_path=$(orch_worktree_get_path "06-backend")
    if [[ -d "$wt_path" ]]; then
        pass "create worktree — path exists and is a directory"
    else
        fail "create worktree — path does not exist"
    fi
else
    fail "create worktree — command failed"
fi

# ── Test 5: Worktree exists check ──
if orch_worktree_exists "06-backend"; then
    pass "worktree exists check returns 0 for existing worktree"
else
    fail "worktree exists check returned non-zero for existing worktree"
fi

# ── Test 6: Non-existent worktree ──
if orch_worktree_exists "99-fake" 2>/dev/null; then
    fail "non-existent worktree returned 0"
else
    pass "non-existent worktree returns 1"
fi

# ── Test 7: Get path ──
path_out=$(orch_worktree_get_path "06-backend")
if [[ -n "$path_out" ]]; then
    pass "get path returns non-empty string"
else
    fail "get path returned empty string"
fi

# ── Test 8: Worktree has no changes initially ──
if orch_worktree_has_changes "06-backend" 2>/dev/null; then
    fail "has_changes should return 1 (no changes) on fresh worktree"
else
    pass "has_changes returns 1 (no changes) on fresh worktree"
fi

# ── Test 9: Worktree detects changes ──
wt_path=$(orch_worktree_get_path "06-backend")
echo "test content" > "$wt_path/testfile.txt"
git -C "$wt_path" add .
if orch_worktree_has_changes "06-backend" 2>/dev/null; then
    pass "has_changes detects staged changes"
else
    fail "has_changes did not detect staged changes"
fi

# ── Test 10: Cleanup single worktree ──
orch_worktree_cleanup "06-backend" 2>/dev/null || true
if [[ -d "$wt_path" ]]; then
    fail "cleanup single worktree — path still exists"
else
    pass "cleanup single worktree — path removed"
fi

# ── Test 11: Create multiple worktrees ──
orch_worktree_create "06-backend" 2>/dev/null
orch_worktree_create "08-pixel" 2>/dev/null
backend_exists=false
pixel_exists=false
orch_worktree_exists "06-backend" && backend_exists=true
orch_worktree_exists "08-pixel" && pixel_exists=true
if $backend_exists && $pixel_exists; then
    pass "create multiple worktrees — both exist"
else
    fail "create multiple worktrees — missing one or both"
fi

# ── Test 12: Cleanup all ──
orch_worktree_cleanup_all 2>/dev/null
backend_gone=true
pixel_gone=true
orch_worktree_exists "06-backend" 2>/dev/null && backend_gone=false
orch_worktree_exists "08-pixel" 2>/dev/null && pixel_gone=false
if $backend_gone && $pixel_gone; then
    pass "cleanup all — all worktrees removed"
else
    fail "cleanup all — some worktrees remain"
fi

# ── Test 13: List worktrees ──
orch_worktree_create "06-backend" 2>/dev/null
orch_worktree_create "08-pixel" 2>/dev/null
list_output=$(orch_worktree_list 2>/dev/null)
has_backend=false
has_pixel=false
echo "$list_output" | grep -q "06-backend" && has_backend=true
echo "$list_output" | grep -q "08-pixel" && has_pixel=true
if $has_backend && $has_pixel; then
    pass "list worktrees — both agents listed"
else
    fail "list worktrees — missing agent(s) in output"
fi

# Cleanup for next tests
orch_worktree_cleanup_all 2>/dev/null

# ── Test 14: Report runs without error ──
orch_worktree_create "06-backend" 2>/dev/null
if orch_worktree_report >/dev/null 2>&1; then
    pass "report runs without error"
else
    fail "report returned non-zero"
fi

# Cleanup for next tests
orch_worktree_cleanup_all 2>/dev/null

# ── Test 15: Merge with no changes — should skip ──
orch_worktree_create "06-backend" 2>/dev/null
if orch_worktree_merge "06-backend" 2>/dev/null; then
    pass "merge with no changes — returns 0 (skipped)"
else
    fail "merge with no changes — should have returned 0"
fi

# Cleanup for next tests
orch_worktree_cleanup_all 2>/dev/null

# ── Test 16: Merge with changes ──
orch_worktree_create "06-backend" 2>/dev/null
wt_path=$(orch_worktree_get_path "06-backend")
echo "new feature" > "$wt_path/feature.txt"
git -C "$wt_path" add .
git -C "$wt_path" commit -m "Add feature" 2>/dev/null
if orch_worktree_merge "06-backend" 2>/dev/null; then
    pass "merge with changes — merge succeeds"
else
    fail "merge with changes — merge failed"
fi

# Cleanup for next tests
orch_worktree_cleanup_all 2>/dev/null

# ── Test 17: Merge all — one modified, one clean ──
orch_worktree_create "06-backend" 2>/dev/null
orch_worktree_create "08-pixel" 2>/dev/null
wt_path_backend=$(orch_worktree_get_path "06-backend")
echo "backend work" > "$wt_path_backend/work.txt"
git -C "$wt_path_backend" add .
git -C "$wt_path_backend" commit -m "Backend work" 2>/dev/null
merge_count=$(orch_worktree_merge_all 2>/dev/null | tail -c 1)
if [[ "$merge_count" -eq 1 ]]; then
    pass "merge all — returns 1 (one merge)"
else
    fail "merge all — expected 1 merge, got ${merge_count}"
fi

# Final cleanup
orch_worktree_cleanup_all 2>/dev/null

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
