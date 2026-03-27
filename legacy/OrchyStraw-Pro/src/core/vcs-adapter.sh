#!/usr/bin/env bash
# =============================================================================
# vcs-adapter.sh — VCS adapter layer (git/svn/none) (#59)
#
# Abstracts VCS operations behind a uniform interface so the orchestrator
# is portable across git repos, svn repos, and non-VCS directories.
#
# Usage:
#   source src/core/vcs-adapter.sh
#
#   orch_vcs_init               # auto-detect backend
#   orch_vcs_init git           # force git backend
#   orch_vcs_init svn           # force svn backend
#   orch_vcs_init none          # force no-op backend
#
#   orch_vcs_status             # show working-tree status
#   orch_vcs_diff               # show unstaged diff
#   orch_vcs_log [n]            # show last n log entries (default 10)
#   orch_vcs_commit "msg"       # commit staged/tracked changes
#   orch_vcs_branch             # print current branch name
#   orch_vcs_stash              # stash uncommitted changes
#   orch_vcs_unstash            # pop most recent stash
#   orch_vcs_report             # print active backend + detected info
#
# Requires: bash 4.2+
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_VCS_ADAPTER_LOADED:-}" ]] && return 0
readonly _ORCH_VCS_ADAPTER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g _ORCH_VCS_BACKEND=""          # active backend: git | svn | none
declare -g _ORCH_VCS_ROOT=""             # detected/used VCS root directory
declare -g _ORCH_VCS_INITIALIZED=0      # 1 after orch_vcs_init has run

# ---------------------------------------------------------------------------
# orch_vcs_init — Initialise the adapter, detect or set backend
#
# Args:
#   $1 (optional) — backend override: "git" | "svn" | "none"
#                   If omitted, auto-detect by inspecting the current directory
#                   hierarchy for .git (→ git), .svn (→ svn), or fallback none.
#
# Outputs: none (sets module state)
# Returns: 0 always
# ---------------------------------------------------------------------------
orch_vcs_init() {
    local requested_backend="${1:-}"

    if [[ -n "$requested_backend" ]]; then
        case "$requested_backend" in
            git|svn|none)
                _ORCH_VCS_BACKEND="$requested_backend"
                ;;
            *)
                printf '[vcs-adapter] WARN: unknown backend "%s", falling back to auto-detect\n' \
                    "$requested_backend" >&2
                _ORCH_VCS_BACKEND="$(_orch_vcs_detect)"
                ;;
        esac
    else
        _ORCH_VCS_BACKEND="$(_orch_vcs_detect)"
    fi

    _ORCH_VCS_ROOT="$(pwd)"
    _ORCH_VCS_INITIALIZED=1
}

# ---------------------------------------------------------------------------
# orch_vcs_status — Show working-tree / checkout status
#
# Args: none
#
# Outputs: backend-specific status text to stdout
# Returns: 0 on success, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_status() {
    _orch_vcs_ensure_init
    "_orch_vcs_${_ORCH_VCS_BACKEND}_status" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_diff — Show uncommitted differences
#
# Args:
#   $@ (optional) — paths to restrict the diff to
#
# Outputs: diff text to stdout
# Returns: 0 on success, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_diff() {
    _orch_vcs_ensure_init
    "_orch_vcs_${_ORCH_VCS_BACKEND}_diff" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_log — Show commit/revision history
#
# Args:
#   $1 (optional) — number of entries to show (default: 10)
#
# Outputs: log text to stdout
# Returns: 0 on success, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_log() {
    _orch_vcs_ensure_init
    "_orch_vcs_${_ORCH_VCS_BACKEND}_log" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_commit — Record a new commit / revision
#
# Args:
#   $1 — commit message (required)
#   $2 (optional) — additional files/paths to include (git: added to stage)
#
# Outputs: backend output to stdout
# Returns: 0 on success, 1 on missing message, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_commit() {
    _orch_vcs_ensure_init
    local msg="${1:-}"
    if [[ -z "$msg" ]]; then
        printf '[vcs-adapter] ERROR: commit requires a message\n' >&2
        return 1
    fi
    "_orch_vcs_${_ORCH_VCS_BACKEND}_commit" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_branch — Print the current branch / working-copy URL leaf
#
# Args: none
#
# Outputs: branch name string to stdout
# Returns: 0 on success, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_branch() {
    _orch_vcs_ensure_init
    "_orch_vcs_${_ORCH_VCS_BACKEND}_branch" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_stash — Save uncommitted changes for later
#
# Args:
#   $1 (optional) — stash description/message
#
# Outputs: backend output to stdout
# Returns: 0 on success, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_stash() {
    _orch_vcs_ensure_init
    "_orch_vcs_${_ORCH_VCS_BACKEND}_stash" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_unstash — Restore most-recently stashed changes
#
# Args: none
#
# Outputs: backend output to stdout
# Returns: 0 on success, non-zero on backend error
# ---------------------------------------------------------------------------
orch_vcs_unstash() {
    _orch_vcs_ensure_init
    "_orch_vcs_${_ORCH_VCS_BACKEND}_unstash" "$@"
}

# ---------------------------------------------------------------------------
# orch_vcs_report — Print a summary of the active VCS adapter state
#
# Args: none
#
# Outputs: human-readable report to stdout
# ---------------------------------------------------------------------------
orch_vcs_report() {
    echo "VCS Adapter — Active Backend Report"
    printf '  Backend     : %s\n' "${_ORCH_VCS_BACKEND:-<not initialised>}"
    printf '  Root (cwd)  : %s\n' "${_ORCH_VCS_ROOT:-<not initialised>}"
    printf '  Initialized : %s\n' "${_ORCH_VCS_INITIALIZED}"

    if [[ "$_ORCH_VCS_INITIALIZED" == "1" && "$_ORCH_VCS_BACKEND" != "none" ]]; then
        local branch
        branch="$(orch_vcs_branch 2>/dev/null || echo "n/a")"
        printf '  Branch/Rev  : %s\n' "$branch"
    fi
}

# ===========================================================================
# INTERNAL HELPERS
# ===========================================================================

# ---------------------------------------------------------------------------
# _orch_vcs_detect — Auto-detect VCS type by walking directory parents
#
# Outputs: "git" | "svn" | "none"
# ---------------------------------------------------------------------------
_orch_vcs_detect() {
    local dir
    dir="$(pwd)"

    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            echo "git"
            return 0
        fi
        if [[ -d "$dir/.svn" ]]; then
            echo "svn"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    echo "none"
}

# ---------------------------------------------------------------------------
# _orch_vcs_ensure_init — Verify orch_vcs_init was called; auto-init if not
# ---------------------------------------------------------------------------
_orch_vcs_ensure_init() {
    if [[ "$_ORCH_VCS_INITIALIZED" != "1" ]]; then
        printf '[vcs-adapter] WARN: orch_vcs_init not called — auto-detecting backend\n' >&2
        orch_vcs_init
    fi
}

# ===========================================================================
# GIT BACKEND
# ===========================================================================

_orch_vcs_git_status() {
    git status "$@"
}

_orch_vcs_git_diff() {
    git diff "$@"
}

_orch_vcs_git_log() {
    local n="${1:-10}"
    git log --oneline -n "$n"
}

_orch_vcs_git_commit() {
    local msg="$1"
    shift || true
    if [[ $# -gt 0 ]]; then
        git add -- "$@"
    fi
    git commit -m "$msg"
}

_orch_vcs_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD"
}

_orch_vcs_git_stash() {
    local desc="${1:-}"
    if [[ -n "$desc" ]]; then
        git stash push -m "$desc"
    else
        git stash push
    fi
}

_orch_vcs_git_unstash() {
    git stash pop
}

# ===========================================================================
# SVN BACKEND
# ===========================================================================

_orch_vcs_svn_status() {
    svn status "$@"
}

_orch_vcs_svn_diff() {
    svn diff "$@"
}

_orch_vcs_svn_log() {
    local n="${1:-10}"
    svn log --limit "$n" "$@"
}

_orch_vcs_svn_commit() {
    local msg="$1"
    shift || true
    if [[ $# -gt 0 ]]; then
        svn commit -m "$msg" -- "$@"
    else
        svn commit -m "$msg"
    fi
}

_orch_vcs_svn_branch() {
    # SVN does not have a native branch concept in the same way; return the
    # working-copy URL or the path leaf (trunk / branches/foo / tags/bar).
    local url
    url="$(svn info --show-item url 2>/dev/null)" || url="unknown"
    # Extract last meaningful path segment after trunk|branches|tags
    echo "$url" | sed -E 's|.*/((trunk|branches/[^/]+|tags/[^/]+)).*|\1|; t; s|.*/([^/]+)$|\1|'
}

_orch_vcs_svn_stash() {
    # SVN has no native stash; create a diff patch file as best-effort stash.
    local desc="${1:-stash}"
    local patch_file
    patch_file="${TMPDIR:-/tmp}/orch-svn-stash-$(date +%s).patch"
    svn diff > "$patch_file"
    printf '[vcs-adapter] SVN stash saved to: %s\n' "$patch_file"
    echo "$patch_file"
}

_orch_vcs_svn_unstash() {
    # Best-effort: apply the most recent patch file, then remove it.
    local patch_file
    patch_file="$(ls -t "${TMPDIR:-/tmp}"/orch-svn-stash-*.patch 2>/dev/null | head -1)"
    if [[ -z "$patch_file" ]]; then
        printf '[vcs-adapter] SVN unstash: no stash patch found\n' >&2
        return 1
    fi
    patch -p0 < "$patch_file"
    rm -f "$patch_file"
}

# ===========================================================================
# NONE BACKEND (no-op — for non-VCS projects)
# ===========================================================================

_orch_vcs_none_status() {
    return 0
}

_orch_vcs_none_diff() {
    return 0
}

_orch_vcs_none_log() {
    return 0
}

_orch_vcs_none_commit() {
    return 0
}

_orch_vcs_none_branch() {
    return 0
}

_orch_vcs_none_stash() {
    return 0
}

_orch_vcs_none_unstash() {
    return 0
}
