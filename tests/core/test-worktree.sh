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
list_count=$(orch_worktree_list | wc -l | tr -d ' ')
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
# v0.3 Tests: Conflict Detection, Merge Strategies, Cleanup Policies
# ══════════════════════════════════════

# T38-T39: Conflict detection
wt_ca=$(orch_worktree_path "detect-a" "50")
wt_cb=$(orch_worktree_path "detect-b" "50")
orch_worktree_create "detect-a" "50" >/dev/null
orch_worktree_create "detect-b" "50" >/dev/null

echo "conflict-file" > "$wt_ca/shared.txt"
git -C "$wt_ca" add shared.txt
git -C "$wt_ca" commit -m "detect-a: shared" >/dev/null 2>&1

echo "conflict-file-2" > "$wt_cb/shared.txt"
git -C "$wt_cb" add shared.txt
git -C "$wt_cb" commit -m "detect-b: shared" >/dev/null 2>&1

conflicts=$(orch_worktree_detect_conflicts "detect-a" "50" "detect-b" "50" 2>/dev/null)
assert_eq "T38: conflict detected on shared.txt" "shared.txt" "$conflicts"

# Non-conflicting pair
wt_nc=$(orch_worktree_path "noconflict-a" "50")
orch_worktree_create "noconflict-a" "50" >/dev/null
echo "unique" > "$wt_nc/unique-nc.txt"
git -C "$wt_nc" add unique-nc.txt
git -C "$wt_nc" commit -m "noconflict" >/dev/null 2>&1

assert_fail "T39: no conflict for non-overlapping branches" \
    orch_worktree_detect_conflicts "detect-a" "50" "noconflict-a" "50"

orch_worktree_cleanup "50"

# T40-T42: Merge with strategy=theirs
wt_ta=$(orch_worktree_path "strat-a" "60")
wt_tb=$(orch_worktree_path "strat-b" "60")
orch_worktree_create "strat-a" "60" >/dev/null
orch_worktree_create "strat-b" "60" >/dev/null

echo "main-version" > "$wt_ta/strat-file.txt"
git -C "$wt_ta" add strat-file.txt
git -C "$wt_ta" commit -m "strat-a: add" >/dev/null 2>&1

echo "agent-version" > "$wt_tb/strat-file.txt"
git -C "$wt_tb" add strat-file.txt
git -C "$wt_tb" commit -m "strat-b: add" >/dev/null 2>&1

assert_ok "T40: merge strat-a auto" orch_worktree_merge_strategy "strat-a" "60" "auto"
assert_ok "T41: merge strat-b theirs (no conflict with -X theirs)" orch_worktree_merge_strategy "strat-b" "60" "theirs"

strat_content=$(cat "$TEST_REPO/strat-file.txt")
assert_eq "T42: theirs wins" "agent-version" "$strat_content"

# T43: Merge with strategy=ours
wt_oa=$(orch_worktree_path "ours-a" "61")
orch_worktree_create "ours-a" "61" >/dev/null
echo "agent-wants-this" > "$wt_oa/strat-file.txt"
git -C "$wt_oa" add strat-file.txt
git -C "$wt_oa" commit -m "ours-a: modify" >/dev/null 2>&1

assert_ok "T43: merge with strategy=ours succeeds" orch_worktree_merge_strategy "ours-a" "61" "ours"

# T44: Merge strategy=manual detects conflict and aborts
wt_ma=$(orch_worktree_path "manual-a" "62")
wt_mb=$(orch_worktree_path "manual-b" "62")
orch_worktree_create "manual-a" "62" >/dev/null
orch_worktree_create "manual-b" "62" >/dev/null

echo "manual-ver-a" > "$wt_ma/manual.txt"
git -C "$wt_ma" add manual.txt
git -C "$wt_ma" commit -m "manual-a" >/dev/null 2>&1

echo "manual-ver-b" > "$wt_mb/manual.txt"
git -C "$wt_mb" add manual.txt
git -C "$wt_mb" commit -m "manual-b" >/dev/null 2>&1

assert_ok "T44a: first manual merge succeeds" orch_worktree_merge_strategy "manual-a" "62" "manual"
assert_fail "T44b: second manual merge detects conflict" orch_worktree_merge_strategy "manual-b" "62" "manual"

git -C "$TEST_REPO" merge --abort 2>/dev/null || true
orch_worktree_cleanup "62"

# T45: Worktree status doesn't crash
orch_worktree_create "status-test" "70" >/dev/null
status_out=$(orch_worktree_status 2>/dev/null)
assert_true "T45: status output contains agent name" echo "$status_out" | grep -q "status-test"
orch_worktree_cleanup "70"

# T46: Enforce max count
# Note: enforce_max_count modifies global state, so can't capture output in $()
_ORCH_WORKTREE_MAX_COUNT=2
orch_worktree_create "max-a" "80" >/dev/null
_ORCH_WORKTREE_CREATED_AT["$(orch_worktree_path "max-a" "80")"]=$(( $(date +%s) - 100 ))
orch_worktree_create "max-b" "80" >/dev/null
_ORCH_WORKTREE_CREATED_AT["$(orch_worktree_path "max-b" "80")"]=$(( $(date +%s) - 50 ))
orch_worktree_create "max-c" "80" >/dev/null
assert_eq "T46a: 3 active before enforce" "3" "${#_ORCH_WORKTREE_ACTIVE[@]}"
orch_worktree_enforce_max_count >/dev/null
assert_eq "T46b: 2 active after enforce" "2" "${#_ORCH_WORKTREE_ACTIVE[@]}"
_ORCH_WORKTREE_MAX_COUNT=20
orch_worktree_cleanup "80"

# T47: Unknown strategy rejected (needs existing worktree with commits)
orch_worktree_create "yolo-test" "99" >/dev/null
wt_yolo=$(orch_worktree_path "yolo-test" "99")
echo "yolo" > "$wt_yolo/yolo.txt"
git -C "$wt_yolo" add yolo.txt
git -C "$wt_yolo" commit -m "yolo" >/dev/null 2>&1
assert_fail "T47: unknown strategy fails" orch_worktree_merge_strategy "yolo-test" "99" "yolo"
orch_worktree_cleanup "99"

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
