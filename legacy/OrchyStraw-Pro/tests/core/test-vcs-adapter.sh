#!/usr/bin/env bash
# Test: vcs-adapter.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/vcs-adapter.sh"

echo "=== vcs-adapter.sh tests ==="

# ---------------------------------------------------------------------------
# Setup: directories used across tests
# ---------------------------------------------------------------------------
GIT_DIR="$TMPDIR_TEST/git-project"
NOGIT_DIR="$TMPDIR_TEST/no-vcs-dir"
SVN_DIR="$TMPDIR_TEST/svn-project"

mkdir -p "$GIT_DIR" "$NOGIT_DIR" "$SVN_DIR"
# Make a fake .svn directory so auto-detect identifies it as svn
mkdir -p "$SVN_DIR/.svn"

# Initialise a real git repo for git-backend tests
git -C "$GIT_DIR" init 2>/dev/null
git -C "$GIT_DIR" config user.email "test@orchystraw.test"
git -C "$GIT_DIR" config user.name "OrchyStraw Test"
git -C "$GIT_DIR" commit --allow-empty -m "Initial commit"

# -----------------------------------------------------------------------
# 1. Module loads — guard var is set
# -----------------------------------------------------------------------
if [[ "${_ORCH_VCS_ADAPTER_LOADED:-}" == "1" ]]; then
    pass "1 - module loads (guard var set)"
else
    fail "1 - module loads (guard var set)"
fi

# -----------------------------------------------------------------------
# 2. Double-source guard — sourcing again succeeds without resetting state
# -----------------------------------------------------------------------
_ORCH_VCS_BACKEND="git"        # set a sentinel value
source "$PROJECT_ROOT/src/core/vcs-adapter.sh"
if [[ "$_ORCH_VCS_BACKEND" == "git" ]]; then
    pass "2 - double-source guard (state preserved)"
else
    fail "2 - double-source guard (state was reset)"
fi

# Reset state for remaining tests
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 3. Auto-detect git backend inside a .git directory
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init
    if [[ "$_ORCH_VCS_BACKEND" == "git" ]]; then
        echo "PASS"
    else
        echo "FAIL:$_ORCH_VCS_BACKEND"
    fi
) > "$TMPDIR_TEST/out3.txt"
result3="$(cat "$TMPDIR_TEST/out3.txt")"
if [[ "$result3" == "PASS" ]]; then
    pass "3 - auto-detect git backend"
else
    fail "3 - auto-detect git backend (got: $result3)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 4. Auto-detect none backend in a non-VCS directory
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init
    if [[ "$_ORCH_VCS_BACKEND" == "none" ]]; then
        echo "PASS"
    else
        echo "FAIL:$_ORCH_VCS_BACKEND"
    fi
) > "$TMPDIR_TEST/out4.txt"
result4="$(cat "$TMPDIR_TEST/out4.txt")"
if [[ "$result4" == "PASS" ]]; then
    pass "4 - auto-detect none backend (non-VCS dir)"
else
    fail "4 - auto-detect none backend (got: $result4)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 5. Manual backend selection — force git
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "git"
    if [[ "$_ORCH_VCS_BACKEND" == "git" ]]; then
        echo "PASS"
    else
        echo "FAIL:$_ORCH_VCS_BACKEND"
    fi
) > "$TMPDIR_TEST/out5.txt"
result5="$(cat "$TMPDIR_TEST/out5.txt")"
if [[ "$result5" == "PASS" ]]; then
    pass "5 - manual backend selection (force git)"
else
    fail "5 - manual backend selection (got: $result5)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 6. orch_vcs_status returns output in git mode
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    out="$(orch_vcs_status 2>/dev/null)"
    # git status always prints something (e.g., "On branch main" or "nothing to commit")
    if [[ -n "$out" ]]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
) > "$TMPDIR_TEST/out6.txt"
result6="$(cat "$TMPDIR_TEST/out6.txt")"
if [[ "$result6" == "PASS" ]]; then
    pass "6 - orch_vcs_status returns output in git mode"
else
    fail "6 - orch_vcs_status returns output in git mode"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 7. orch_vcs_diff works (git mode — empty diff on clean repo)
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    orch_vcs_diff 2>/dev/null
    echo "EXIT:$?"
) > "$TMPDIR_TEST/out7.txt"
result7="$(cat "$TMPDIR_TEST/out7.txt")"
if [[ "$result7" == *"EXIT:0"* ]]; then
    pass "7 - orch_vcs_diff works (git mode)"
else
    fail "7 - orch_vcs_diff works (got: $result7)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 8. orch_vcs_log works (git mode)
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    out="$(orch_vcs_log 5 2>/dev/null)"
    # Log of a repo with at least 1 commit should be non-empty
    if [[ -n "$out" ]]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
) > "$TMPDIR_TEST/out8.txt"
result8="$(cat "$TMPDIR_TEST/out8.txt")"
if [[ "$result8" == "PASS" ]]; then
    pass "8 - orch_vcs_log works (git mode)"
else
    fail "8 - orch_vcs_log works (git mode)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 9. orch_vcs_commit creates a commit in git mode
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    echo "hello" > "$GIT_DIR/test-file.txt"
    git -C "$GIT_DIR" add test-file.txt
    orch_vcs_commit "test: vcs-adapter commit test" >/dev/null 2>&1
    # Verify the commit appears in log
    out="$(git -C "$GIT_DIR" log --oneline -1)"
    if [[ "$out" == *"vcs-adapter commit test"* ]]; then
        echo "PASS"
    else
        echo "FAIL:$out"
    fi
) > "$TMPDIR_TEST/out9.txt"
result9="$(cat "$TMPDIR_TEST/out9.txt")"
if [[ "$result9" == "PASS" ]]; then
    pass "9 - orch_vcs_commit creates a commit (git mode)"
else
    fail "9 - orch_vcs_commit creates a commit (got: $result9)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 10. orch_vcs_branch returns current branch name (git mode)
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    branch="$(orch_vcs_branch 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        echo "PASS:$branch"
    else
        echo "FAIL"
    fi
) > "$TMPDIR_TEST/out10.txt"
result10="$(cat "$TMPDIR_TEST/out10.txt")"
if [[ "$result10" == "PASS:"* ]]; then
    pass "10 - orch_vcs_branch returns branch name (got: ${result10#PASS:})"
else
    fail "10 - orch_vcs_branch returns branch name"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 11. None backend — commit is a no-op (returns 0, no error)
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "none"
    orch_vcs_commit "should be no-op" 2>/dev/null
    echo "EXIT:$?"
) > "$TMPDIR_TEST/out11.txt"
result11="$(cat "$TMPDIR_TEST/out11.txt")"
if [[ "$result11" == "EXIT:0" ]]; then
    pass "11 - none backend commit is no-op (exit 0)"
else
    fail "11 - none backend commit is no-op (got: $result11)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 12. None backend — status returns empty output
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "none"
    out="$(orch_vcs_status 2>/dev/null)"
    if [[ -z "$out" ]]; then
        echo "PASS"
    else
        echo "FAIL:$out"
    fi
) > "$TMPDIR_TEST/out12.txt"
result12="$(cat "$TMPDIR_TEST/out12.txt")"
if [[ "$result12" == "PASS" ]]; then
    pass "12 - none backend status returns empty"
else
    fail "12 - none backend status returns empty (got: $result12)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 13. None backend — diff returns empty output
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "none"
    out="$(orch_vcs_diff 2>/dev/null)"
    if [[ -z "$out" ]]; then
        echo "PASS"
    else
        echo "FAIL:$out"
    fi
) > "$TMPDIR_TEST/out13.txt"
result13="$(cat "$TMPDIR_TEST/out13.txt")"
if [[ "$result13" == "PASS" ]]; then
    pass "13 - none backend diff returns empty"
else
    fail "13 - none backend diff returns empty (got: $result13)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 14. SVN backend — public functions exist and return without error (no svn bin)
#     We test the none path via _orch_vcs_svn_* functions existing as stubs;
#     the public API with backend=svn on a non-svn dir returns 0 for no-op funcs.
# -----------------------------------------------------------------------
if declare -f _orch_vcs_svn_status >/dev/null 2>&1 && \
   declare -f _orch_vcs_svn_diff   >/dev/null 2>&1 && \
   declare -f _orch_vcs_svn_commit >/dev/null 2>&1 && \
   declare -f _orch_vcs_svn_log    >/dev/null 2>&1 && \
   declare -f _orch_vcs_svn_branch >/dev/null 2>&1 && \
   declare -f _orch_vcs_svn_stash  >/dev/null 2>&1 && \
   declare -f _orch_vcs_svn_unstash >/dev/null 2>&1; then
    pass "14 - SVN backend internal functions are all defined"
else
    fail "14 - SVN backend internal functions are all defined"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 15. orch_vcs_report prints active backend
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    out="$(orch_vcs_report 2>/dev/null)"
    if [[ "$out" == *"git"* && "$out" == *"Backend"* ]]; then
        echo "PASS"
    else
        echo "FAIL:$out"
    fi
) > "$TMPDIR_TEST/out15.txt"
result15="$(cat "$TMPDIR_TEST/out15.txt")"
if [[ "$result15" == "PASS" ]]; then
    pass "15 - orch_vcs_report prints active backend"
else
    fail "15 - orch_vcs_report prints active backend (got: $result15)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 16. Re-init switches backend (git → none → git)
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    first="$_ORCH_VCS_BACKEND"
    orch_vcs_init "none"
    second="$_ORCH_VCS_BACKEND"
    orch_vcs_init "git"
    third="$_ORCH_VCS_BACKEND"
    if [[ "$first" == "git" && "$second" == "none" && "$third" == "git" ]]; then
        echo "PASS"
    else
        echo "FAIL:$first/$second/$third"
    fi
) > "$TMPDIR_TEST/out16.txt"
result16="$(cat "$TMPDIR_TEST/out16.txt")"
if [[ "$result16" == "PASS" ]]; then
    pass "16 - re-init switches backend"
else
    fail "16 - re-init switches backend (got: $result16)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 17. orch_vcs_commit without message returns error exit code
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "none"
    # Capture exit code without triggering set -e
    orch_vcs_commit "" 2>/dev/null || echo "EXIT:$?"
) > "$TMPDIR_TEST/out17.txt"
result17="$(cat "$TMPDIR_TEST/out17.txt")"
# An empty message should return exit 1 from the public wrapper
if [[ "$result17" == "EXIT:1" ]]; then
    pass "17 - orch_vcs_commit with empty message returns exit 1"
else
    fail "17 - orch_vcs_commit with empty message returns exit 1 (got: $result17)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 18. Unknown backend override emits warning and falls back to auto-detect
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "fakevcs" 2>/dev/null
    if [[ "$_ORCH_VCS_BACKEND" == "git" ]]; then
        echo "PASS"
    else
        echo "FAIL:$_ORCH_VCS_BACKEND"
    fi
) > "$TMPDIR_TEST/out18.txt"
result18="$(cat "$TMPDIR_TEST/out18.txt")"
if [[ "$result18" == "PASS" ]]; then
    pass "18 - unknown backend falls back to auto-detect"
else
    fail "18 - unknown backend falls back to auto-detect (got: $result18)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 19. _orch_vcs_ensure_init triggers auto-init when not initialised
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    _ORCH_VCS_INITIALIZED=0
    _ORCH_VCS_BACKEND=""
    # Calling a public function without explicit init should auto-init
    orch_vcs_status >/dev/null 2>&1
    if [[ "$_ORCH_VCS_INITIALIZED" == "1" && -n "$_ORCH_VCS_BACKEND" ]]; then
        echo "PASS"
    else
        echo "FAIL:init=$_ORCH_VCS_INITIALIZED backend=$_ORCH_VCS_BACKEND"
    fi
) > "$TMPDIR_TEST/out19.txt"
result19="$(cat "$TMPDIR_TEST/out19.txt")"
if [[ "$result19" == "PASS" ]]; then
    pass "19 - ensure_init auto-initialises when not yet done"
else
    fail "19 - ensure_init auto-initialises (got: $result19)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 20. orch_vcs_stash and orch_vcs_unstash work in git mode
# -----------------------------------------------------------------------
(
    cd "$GIT_DIR"
    orch_vcs_init "git"
    echo "unstaged-change" > "$GIT_DIR/stash-test.txt"
    git -C "$GIT_DIR" add stash-test.txt
    stash_out="$(orch_vcs_stash "test stash" 2>/dev/null)"
    # After stash, the working tree should be clean
    status_out="$(git -C "$GIT_DIR" stash list)"
    if [[ "$status_out" == *"test stash"* ]]; then
        echo "STASH_OK"
    else
        echo "STASH_FAIL:$status_out"
    fi
    # Pop the stash
    orch_vcs_unstash 2>/dev/null
    echo "UNSTASH_EXIT:$?"
) > "$TMPDIR_TEST/out20.txt"
result20="$(cat "$TMPDIR_TEST/out20.txt")"
if [[ "$result20" == *"STASH_OK"* && "$result20" == *"UNSTASH_EXIT:0"* ]]; then
    pass "20 - orch_vcs_stash and orch_vcs_unstash work (git)"
else
    fail "20 - orch_vcs_stash/unstash (got: $result20)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 21. None backend — stash and unstash are no-ops
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "none"
    orch_vcs_stash "irrelevant" 2>/dev/null
    stash_exit=$?
    orch_vcs_unstash 2>/dev/null
    unstash_exit=$?
    if [[ "$stash_exit" == "0" && "$unstash_exit" == "0" ]]; then
        echo "PASS"
    else
        echo "FAIL:stash=$stash_exit unstash=$unstash_exit"
    fi
) > "$TMPDIR_TEST/out21.txt"
result21="$(cat "$TMPDIR_TEST/out21.txt")"
if [[ "$result21" == "PASS" ]]; then
    pass "21 - none backend stash/unstash are no-ops"
else
    fail "21 - none backend stash/unstash are no-ops (got: $result21)"
fi

# Reset
_ORCH_VCS_BACKEND=""
_ORCH_VCS_INITIALIZED=0

# -----------------------------------------------------------------------
# 22. orch_vcs_log with none backend returns empty and exit 0
# -----------------------------------------------------------------------
(
    cd "$NOGIT_DIR"
    orch_vcs_init "none"
    out="$(orch_vcs_log 2>/dev/null)"
    exit_code=$?
    if [[ -z "$out" && "$exit_code" == "0" ]]; then
        echo "PASS"
    else
        echo "FAIL:out=$out exit=$exit_code"
    fi
) > "$TMPDIR_TEST/out22.txt"
result22="$(cat "$TMPDIR_TEST/out22.txt")"
if [[ "$result22" == "PASS" ]]; then
    pass "22 - none backend log returns empty and exit 0"
else
    fail "22 - none backend log returns empty and exit 0 (got: $result22)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
