#!/usr/bin/env bash
# worktree.sh — Git worktree isolation per agent (WORKTREE-001)
# v0.2.0 Phase 2: #44 (Git Worktree Isolation)
#
# Creates one git worktree per agent before execution, providing filesystem
# isolation. Agents can't see or conflict with each other's in-progress changes.
# Composes with EXEC-001 execution groups: group 0 worktrees run and merge
# before group 1 worktrees are created.
#
# Provides:
#   orch_worktree_init       — prune orphans, validate git version, set repo root
#   orch_worktree_enabled    — returns 0 if worktree mode is active
#   orch_worktree_create     — create worktree + branch for an agent
#   orch_worktree_path       — return worktree path for agent/cycle
#   orch_worktree_branch     — return branch name for agent/cycle
#   orch_worktree_merge      — merge agent branch back + remove worktree
#   orch_worktree_cleanup    — remove all cycle worktrees (crash recovery)
#   orch_worktree_list       — list active worktrees

[[ -n "${_ORCH_WORKTREE_LOADED:-}" ]] && return 0
_ORCH_WORKTREE_LOADED=1

# ── State ──
declare -g _ORCH_WORKTREE_ENABLED="${ORCH_WORKTREE:-false}"
declare -g _ORCH_WORKTREE_TMPDIR="${ORCH_WORKTREE_TMPDIR:-/tmp}"
declare -g _ORCH_WORKTREE_PREFIX="orchy"
declare -g -a _ORCH_WORKTREE_ACTIVE=()
declare -g _ORCH_WORKTREE_REPO_ROOT=""

# ── Helpers ──

_orch_worktree_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "worktree" "$2"
    fi
}

# ── Public API ──

orch_worktree_enabled() {
    [[ "$_ORCH_WORKTREE_ENABLED" == "true" ]]
}

# orch_worktree_init <repo_root>
#   Initialize worktree manager. Prunes orphaned worktrees from previous
#   crashes. Validates git version (requires 2.15+).
orch_worktree_init() {
    local repo_root="${1:?orch_worktree_init: repo_root required}"

    if [[ ! -d "$repo_root/.git" && ! -f "$repo_root/.git" ]]; then
        _orch_worktree_log ERROR "Not a git repository: $repo_root"
        return 1
    fi

    _ORCH_WORKTREE_REPO_ROOT="$repo_root"
    _ORCH_WORKTREE_ACTIVE=()

    # Check git version (need 2.15+ for worktree improvements)
    local git_ver_str
    git_ver_str=$(git --version 2>/dev/null) || {
        _orch_worktree_log ERROR "git not found"
        return 1
    }

    local major=0 minor=0
    if [[ "$git_ver_str" =~ ([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
    fi

    if [[ "$major" -lt 2 || ( "$major" -eq 2 && "$minor" -lt 15 ) ]]; then
        _orch_worktree_log ERROR "Git 2.15+ required for worktree support (found ${major}.${minor})"
        return 1
    fi

    # Prune orphaned worktrees from previous crashes
    git -C "$repo_root" worktree prune 2>/dev/null

    _orch_worktree_log INFO "Worktree manager initialized (repo: $repo_root)"
    return 0
}

# orch_worktree_path <agent_id> <cycle_num>
#   Return the filesystem path for an agent's worktree.
orch_worktree_path() {
    local agent_id="${1:?orch_worktree_path: agent_id required}"
    local cycle_num="${2:?orch_worktree_path: cycle_num required}"
    printf '%s/%s-%s-%s\n' "$_ORCH_WORKTREE_TMPDIR" "$_ORCH_WORKTREE_PREFIX" "$cycle_num" "$agent_id"
}

# orch_worktree_branch <agent_id> <cycle_num>
#   Return the git branch name for an agent's worktree.
orch_worktree_branch() {
    local agent_id="${1:?orch_worktree_branch: agent_id required}"
    local cycle_num="${2:?orch_worktree_branch: cycle_num required}"
    printf 'agent/%s/cycle-%s\n' "$agent_id" "$cycle_num"
}

# orch_worktree_create <agent_id> <cycle_num>
#   Create an isolated worktree + branch for an agent. Prints the worktree
#   path to stdout on success. The worktree is a full checkout branched from
#   the current HEAD — the agent works here instead of the main repo.
orch_worktree_create() {
    local agent_id="${1:?orch_worktree_create: agent_id required}"
    local cycle_num="${2:?orch_worktree_create: cycle_num required}"

    [[ -z "$_ORCH_WORKTREE_REPO_ROOT" ]] && {
        _orch_worktree_log ERROR "Worktree manager not initialized — call orch_worktree_init first"
        return 1
    }

    # Validate inputs — prevent path traversal
    if [[ "$agent_id" == *".."* || "$agent_id" == *"/"* ]]; then
        _orch_worktree_log ERROR "Invalid agent_id (path traversal rejected): $agent_id"
        return 1
    fi
    if [[ ! "$cycle_num" =~ ^[0-9]+$ ]]; then
        _orch_worktree_log ERROR "Invalid cycle_num (not numeric): $cycle_num"
        return 1
    fi

    local wt_path branch
    wt_path=$(orch_worktree_path "$agent_id" "$cycle_num")
    branch=$(orch_worktree_branch "$agent_id" "$cycle_num")

    # If worktree already exists (stale from crash), clean it up first
    if [[ -d "$wt_path" ]]; then
        _orch_worktree_log WARN "Stale worktree exists: $wt_path — removing"
        git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$wt_path" &>/dev/null
        git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null
    fi

    # Delete branch if it exists but worktree doesn't (leftover from failed merge)
    if git -C "$_ORCH_WORKTREE_REPO_ROOT" rev-parse --verify "$branch" &>/dev/null; then
        git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null
    fi

    # Create worktree + new branch from current HEAD
    if ! git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree add "$wt_path" -b "$branch" >/dev/null 2>&1; then
        _orch_worktree_log ERROR "Failed to create worktree at $wt_path (branch: $branch)"
        return 1
    fi

    _ORCH_WORKTREE_ACTIVE+=("$wt_path")
    _orch_worktree_log INFO "Created worktree for $agent_id at $wt_path (branch: $branch)"

    printf '%s\n' "$wt_path"
    return 0
}

# orch_worktree_merge <agent_id> <cycle_num>
#   Merge the agent's worktree branch back to the current branch, then remove
#   the worktree and delete the branch. Returns 0 on success, 1 on merge
#   conflict (caller should handle — e.g., ownership-based resolution).
#   If the agent made no changes, the merge is skipped.
orch_worktree_merge() {
    local agent_id="${1:?orch_worktree_merge: agent_id required}"
    local cycle_num="${2:?orch_worktree_merge: cycle_num required}"

    [[ -z "$_ORCH_WORKTREE_REPO_ROOT" ]] && {
        _orch_worktree_log ERROR "Worktree manager not initialized"
        return 1
    }

    # Validate inputs — prevent path traversal (WT-SEC-01)
    if [[ "$agent_id" == *".."* || "$agent_id" == *"/"* ]]; then
        _orch_worktree_log ERROR "Invalid agent_id (path traversal rejected): $agent_id"
        return 1
    fi
    if [[ ! "$cycle_num" =~ ^[0-9]+$ ]]; then
        _orch_worktree_log ERROR "Invalid cycle_num (not numeric): $cycle_num"
        return 1
    fi

    local wt_path branch
    wt_path=$(orch_worktree_path "$agent_id" "$cycle_num")
    branch=$(orch_worktree_branch "$agent_id" "$cycle_num")

    if [[ ! -d "$wt_path" ]]; then
        _orch_worktree_log WARN "Worktree does not exist: $wt_path — nothing to merge"
        return 0
    fi

    # Check if the branch has commits ahead of base
    local ahead
    ahead=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" rev-list HEAD.."$branch" --count 2>/dev/null || echo "0")

    if [[ "$ahead" -eq 0 ]]; then
        _orch_worktree_log INFO "Agent $agent_id produced no changes — skip merge"
    else
        # Merge with --no-ff for clear per-agent attribution in history
        if ! git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --no-ff "$branch" \
            -m "feat(${agent_id}): cycle ${cycle_num} work" 2>/dev/null; then
            _orch_worktree_log ERROR "Merge conflict for $agent_id (branch: $branch)"
            # Don't clean up — caller needs to resolve the conflict
            return 1
        fi
        _orch_worktree_log INFO "Merged $agent_id ($ahead commits from branch $branch)"
    fi

    # Remove worktree + delete branch
    git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$wt_path" &>/dev/null
    git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null

    # Remove from active tracking
    local -a new_active=()
    for p in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
        [[ "$p" != "$wt_path" ]] && new_active+=("$p")
    done
    _ORCH_WORKTREE_ACTIVE=("${new_active[@]+"${new_active[@]}"}")

    return 0
}

# orch_worktree_cleanup [cycle_num]
#   Crash recovery: remove all worktrees and branches.
#   If cycle_num is given, only clean that cycle's worktrees.
#   If omitted, clean all tracked active worktrees.
#   Call at orchestrator startup and in SIGTERM handler.
orch_worktree_cleanup() {
    local cycle_num="${1:-}"

    [[ -z "$_ORCH_WORKTREE_REPO_ROOT" ]] && return 0

    if [[ -n "$cycle_num" ]]; then
        # Clean a specific cycle's worktrees by glob
        local pattern="${_ORCH_WORKTREE_TMPDIR}/${_ORCH_WORKTREE_PREFIX}-${cycle_num}-"
        local wt
        for wt in "${pattern}"*; do
            [[ -d "$wt" ]] || continue
            git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$wt" &>/dev/null
            _orch_worktree_log INFO "Cleaned up worktree: $wt"
        done

        # Clean matching branches
        local branches
        branches=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" branch --list "agent/*/cycle-${cycle_num}" 2>/dev/null)
        while IFS= read -r branch; do
            branch="${branch#"${branch%%[![:space:]]*}"}"
            [[ -z "$branch" ]] && continue
            git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null
        done <<< "$branches"
    else
        # Clean all tracked active worktrees
        for wt in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
            [[ -d "$wt" ]] || continue
            git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$wt" &>/dev/null
            _orch_worktree_log INFO "Cleaned up worktree: $wt"
        done
    fi

    # Prune any orphaned worktrees git doesn't know about
    git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree prune 2>/dev/null

    _ORCH_WORKTREE_ACTIVE=()
    return 0
}

# orch_worktree_list
#   Print all active worktree paths (one per line).
orch_worktree_list() {
    for wt in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
        printf '%s\n' "$wt"
    done
}
