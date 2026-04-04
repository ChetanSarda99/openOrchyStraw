#!/usr/bin/env bash
# Test: worktree.sh — Git worktree isolation (WORKTREE-001)
# Uses real temporary git repos for accurate integration testing.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ── Setup: create a temporary git repo ──

TEST_TMPDIR=$(mktemp -d)
TEST_REPO="$TEST_TMPDIR/repo"

_cleanup() {
    if [[ -d "$TEST_REPO" ]]; then
        git -C "$TEST_REPO" worktree prune 2>/dev/null || true
        local wt
        for wt in "$TEST_TMPDIR"/orchy-*; do
            [[ -d "$wt" ]] && git -C "$TEST_REPO" worktree remove --force "$wt" 2>/dev/null || true
        done
    fi
    rm -rf "$TEST_TMPDIR"
}
trap _cleanup EXIT

mkdir -p "$TEST_REPO"
git -C "$TEST_REPO" init -b main >/dev/null 2>&1
git -C "$TEST_REPO" config user.email "test@test.com"
git -C "$TEST_REPO" config user.name "Test"
echo "initial" > "$TEST_REPO/file.txt"
git -C "$TEST_REPO" add file.txt
git -C "$TEST_REPO" commit -m "initial commit" >/dev/null 2>&1

# Point worktrees into our temp dir
export ORCH_WORKTREE_TMPDIR="$TEST_TMPDIR"
export ORCH_WORKTREE="true"

# Source the module
unset _ORCH_WORKTREE_LOADED
source "$PROJECT_ROOT/src/core/worktree.sh"

PASS=0
FAIL=0

assert_ok() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

assert_fail() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "FAIL: $desc (expected failure)"
        FAIL=$((FAIL + 1))
    else
        PASS=$((PASS + 1))
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_true() {
    local desc="$1"
    shift
    if "$@"; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

assert_false() {
    local desc="$1"
    shift
    if "$@"; then
        echo "FAIL: $desc (expected false)"
        FAIL=$((FAIL + 1))
    else
        PASS=$((PASS + 1))
    fi
}

# ══════════════════════════════════════
# T1-T2: orch_worktree_enabled
# ══════════════════════════════════════
assert_true "T1: enabled when ORCH_WORKTREE=true" orch_worktree_enabled

_ORCH_WORKTREE_ENABLED="false"
assert_false "T2: disabled when false" orch_worktree_enabled
_ORCH_WORKTREE_ENABLED="true"

# ══════════════════════════════════════
# T3-T4: orch_worktree_init
# ══════════════════════════════════════
assert_ok "T3: init succeeds with valid repo" orch_worktree_init "$TEST_REPO"
assert_eq "T4: repo root stored" "$TEST_REPO" "$_ORCH_WORKTREE_REPO_ROOT"

# ══════════════════════════════════════
# T5: init fails on non-repo
# ══════════════════════════════════════
assert_fail "T5: init fails on non-repo dir" orch_worktree_init "$TEST_TMPDIR"
# Restore repo root after failed init
_ORCH_WORKTREE_REPO_ROOT="$TEST_REPO"

# ══════════════════════════════════════
# T6-T7: Path and branch name generation
# ══════════════════════════════════════
wt_path=$(orch_worktree_path "06-backend" "3")
assert_eq "T6: path format" "$TEST_TMPDIR/orchy-3-06-backend" "$wt_path"

wt_branch=$(orch_worktree_branch "06-backend" "3")
assert_eq "T7: branch format" "agent/06-backend/cycle-3" "$wt_branch"

# ══════════════════════════════════════
# T8-T12: Create worktree
# ══════════════════════════════════════
expected_path=$(orch_worktree_path "06-backend" "1")
orch_worktree_create "06-backend" "1" >/dev/null
assert_true "T8: worktree directory exists" test -d "$expected_path"
assert_true "T9: worktree has file.txt" test -f "$expected_path/file.txt"

# Verify the branch was created
assert_ok "T10: branch exists" git -C "$TEST_REPO" rev-parse --verify "agent/06-backend/cycle-1"
assert_eq "T11: 1 active worktree tracked" "1" "${#_ORCH_WORKTREE_ACTIVE[@]}"

# ══════════════════════════════════════
# T12-T14: Create second worktree (different agent)
# ══════════════════════════════════════
expected_path2=$(orch_worktree_path "09-qa" "1")
orch_worktree_create "09-qa" "1" >/dev/null
assert_true "T12: second worktree created" test -d "$expected_path2"
assert_eq "T13: 2 active worktrees tracked" "2" "${#_ORCH_WORKTREE_ACTIVE[@]}"

# ══════════════════════════════════════
# T14: orch_worktree_list
# ══════════════════════════════════════
list_count=$(orch_worktree_list | wc -l)
assert_eq "T14: list shows 2 worktrees" "2" "$list_count"

# ══════════════════════════════════════
# T15-T17: Merge with no changes (skip)
# ══════════════════════════════════════
assert_ok "T15: merge no-change succeeds" orch_worktree_merge "09-qa" "1"
assert_false "T16: worktree removed" test -d "$expected_path2"
assert_eq "T17: 1 active after merge" "1" "${#_ORCH_WORKTREE_ACTIVE[@]}"

# ══════════════════════════════════════
# T18-T23: Merge with changes
# ══════════════════════════════════════
echo "backend work" > "$expected_path/backend.txt"
git -C "$expected_path" add backend.txt
git -C "$expected_path" commit -m "backend: add file" >/dev/null 2>&1

ahead=$(git -C "$TEST_REPO" rev-list HEAD.."agent/06-backend/cycle-1" --count 2>/dev/null)
assert_eq "T18: branch 1 commit ahead" "1" "$ahead"

assert_ok "T19: merge with changes succeeds" orch_worktree_merge "06-backend" "1"
assert_false "T20: worktree removed after merge" test -d "$expected_path"
assert_true "T21: merged file in repo" test -f "$TEST_REPO/backend.txt"

# Branch should be gone
assert_fail "T22: branch deleted" git -C "$TEST_REPO" rev-parse --verify "agent/06-backend/cycle-1"
assert_eq "T23: 0 active worktrees" "0" "${#_ORCH_WORKTREE_ACTIVE[@]}"

# ══════════════════════════════════════
# T24: Merge non-existent worktree (no-op)
# ══════════════════════════════════════
assert_ok "T24: merge non-existent is no-op" orch_worktree_merge "ghost" "99"

# ══════════════════════════════════════
# T25-T27: Input validation
# ══════════════════════════════════════
assert_fail "T25: reject agent_id with .." orch_worktree_create "../evil" "1"
assert_fail "T26: reject agent_id with /" orch_worktree_create "evil/agent" "1"
assert_fail "T27: reject non-numeric cycle" orch_worktree_create "agent" "abc"

# ══════════════════════════════════════
# T28: Create fails without init
# ══════════════════════════════════════
saved_root="$_ORCH_WORKTREE_REPO_ROOT"
_ORCH_WORKTREE_REPO_ROOT=""
assert_fail "T28: create fails without init" orch_worktree_create "agent" "1"
_ORCH_WORKTREE_REPO_ROOT="$saved_root"

# ══════════════════════════════════════
# T29-T31: Cleanup by cycle number
# ══════════════════════════════════════
orch_worktree_create "agent-a" "5" >/dev/null
orch_worktree_create "agent-b" "5" >/dev/null
assert_true "T29: worktrees exist before cleanup" test -d "$TEST_TMPDIR/orchy-5-agent-a"

orch_worktree_cleanup "5"
assert_false "T30a: agent-a cleaned" test -d "$TEST_TMPDIR/orchy-5-agent-a"
assert_false "T30b: agent-b cleaned" test -d "$TEST_TMPDIR/orchy-5-agent-b"

assert_fail "T31: cycle-5 branches deleted" git -C "$TEST_REPO" rev-parse --verify "agent/agent-a/cycle-5"

# ══════════════════════════════════════
# T32-T33: Cleanup all active (no cycle_num)
# ══════════════════════════════════════
orch_worktree_create "agent-x" "7" >/dev/null
orch_worktree_create "agent-y" "8" >/dev/null
assert_eq "T32: 2 active worktrees" "2" "${#_ORCH_WORKTREE_ACTIVE[@]}"

orch_worktree_cleanup
assert_false "T33a: agent-x cleaned" test -d "$TEST_TMPDIR/orchy-7-agent-x"
assert_false "T33b: agent-y cleaned" test -d "$TEST_TMPDIR/orchy-8-agent-y"
assert_eq "T33c: 0 active" "0" "${#_ORCH_WORKTREE_ACTIVE[@]}"

# ══════════════════════════════════════
# T34: Stale worktree auto-cleanup on re-create
# ══════════════════════════════════════
orch_worktree_create "stale-agent" "10" >/dev/null
assert_true "T34a: stale worktree exists" test -d "$TEST_TMPDIR/orchy-10-stale-agent"

# Re-create same agent+cycle — should clean stale first
orch_worktree_create "stale-agent" "10" >/dev/null
assert_true "T34b: re-created worktree exists" test -d "$TEST_TMPDIR/orchy-10-stale-agent"
orch_worktree_cleanup "10"

# ══════════════════════════════════════
# T35: Filesystem isolation between agents
# ══════════════════════════════════════
wt1=$(orch_worktree_path "iso-a" "20")
wt2=$(orch_worktree_path "iso-b" "20")
orch_worktree_create "iso-a" "20" >/dev/null
orch_worktree_create "iso-b" "20" >/dev/null

assert_true "T35a: iso-a has file.txt" test -f "$wt1/file.txt"
assert_true "T35b: iso-b has file.txt" test -f "$wt2/file.txt"

echo "a-only" > "$wt1/a-file.txt"
assert_false "T35c: iso-b does NOT see a-file.txt" test -f "$wt2/a-file.txt"

echo "b-only" > "$wt2/b-file.txt"
assert_false "T35d: iso-a does NOT see b-file.txt" test -f "$wt1/b-file.txt"

orch_worktree_cleanup "20"

# ══════════════════════════════════════
# T36: Merge conflict detection
# ══════════════════════════════════════
wt_c=$(orch_worktree_path "conflict-a" "30")
wt_d=$(orch_worktree_path "conflict-b" "30")
orch_worktree_create "conflict-a" "30" >/dev/null
orch_worktree_create "conflict-b" "30" >/dev/null

echo "version-a" > "$wt_c/file.txt"
git -C "$wt_c" add file.txt
git -C "$wt_c" commit -m "conflict-a: modify" >/dev/null 2>&1

echo "version-b" > "$wt_d/file.txt"
git -C "$wt_d" add file.txt
git -C "$wt_d" commit -m "conflict-b: modify" >/dev/null 2>&1

assert_ok "T36a: first merge succeeds" orch_worktree_merge "conflict-a" "30"
assert_fail "T36b: second merge fails (conflict)" orch_worktree_merge "conflict-b" "30"

# Resolve so git is clean
git -C "$TEST_REPO" merge --abort 2>/dev/null || true
orch_worktree_cleanup "30"

# ══════════════════════════════════════
# T37: Sequential merge preserves both agents' work
# ══════════════════════════════════════
wt_e=$(orch_worktree_path "seq-a" "40")
wt_f=$(orch_worktree_path "seq-b" "40")
orch_worktree_create "seq-a" "40" >/dev/null
orch_worktree_create "seq-b" "40" >/dev/null

# Different files — no conflict
echo "from-a" > "$wt_e/seq-a.txt"
git -C "$wt_e" add seq-a.txt
git -C "$wt_e" commit -m "seq-a work" >/dev/null 2>&1

echo "from-b" > "$wt_f/seq-b.txt"
git -C "$wt_f" add seq-b.txt
git -C "$wt_f" commit -m "seq-b work" >/dev/null 2>&1

assert_ok "T37a: merge seq-a" orch_worktree_merge "seq-a" "40"
assert_ok "T37b: merge seq-b" orch_worktree_merge "seq-b" "40"
assert_true "T37c: seq-a.txt in repo" test -f "$TEST_REPO/seq-a.txt"
assert_true "T37d: seq-b.txt in repo" test -f "$TEST_REPO/seq-b.txt"

# ══════════════════════════════════════
# Results
# ══════════════════════════════════════
TOTAL=$((PASS + FAIL))
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "All $TOTAL tests passed."
else
    echo "$PASS/$TOTAL passed, $FAIL FAILED."
    exit 1
fi
