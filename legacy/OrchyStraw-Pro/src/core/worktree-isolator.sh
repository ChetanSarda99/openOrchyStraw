#!/usr/bin/env bash
# worktree-isolator.sh — Git worktree isolation per agent
#
# Gives each agent its own git worktree so parallel agents can work on files
# without conflicting. Worktrees are created per-cycle and cleaned up after
# merging results back to the main branch.
#
# Usage:
#   source src/core/worktree-isolator.sh
#
#   orch_worktree_init "/path/to/project" 4
#   orch_worktree_create "06-backend"
#   path=$(orch_worktree_get_path "06-backend")
#   orch_worktree_merge_all
#   orch_worktree_cleanup_all

# Guard against double-sourcing
[[ -n "${_ORCH_WORKTREE_LOADED:-}" ]] && return 0
readonly _ORCH_WORKTREE_LOADED=1

# ---------------------------------------------------------------------------
# State variables
# ---------------------------------------------------------------------------

declare -gA _ORCH_WORKTREE_PATHS=()          # agent_id -> worktree absolute path
declare -gA _ORCH_WORKTREE_BRANCHES=()       # agent_id -> branch name
declare -gA _ORCH_WORKTREE_MERGE_STATUS=()   # agent_id -> "merged"|"conflict"|"skipped"|"pending"
declare -g  _ORCH_WORKTREE_ROOT=""            # project root (absolute)
declare -g  _ORCH_WORKTREE_CYCLE=0            # current cycle number
declare -g  _ORCH_WORKTREE_DIR=""             # .orchystraw/worktrees/ (absolute)

# ---------------------------------------------------------------------------
# _orch_worktree_log <level> <message>
#   Internal logging helper.
# ---------------------------------------------------------------------------
_orch_worktree_log() {
    local level="$1" msg="$2"
    echo "[worktree] ${level}: ${msg}" >&2
}

# ---------------------------------------------------------------------------
# _orch_worktree_git <args...>
#   Run git rooted at the project root.
# ---------------------------------------------------------------------------
_orch_worktree_git() {
    git -C "${_ORCH_WORKTREE_ROOT}" "$@"
}

# ---------------------------------------------------------------------------
# _orch_worktree_check_support
#   Verify that git worktree is available. Returns 1 if not.
# ---------------------------------------------------------------------------
_orch_worktree_check_support() {
    if ! git worktree list --porcelain &>/dev/null; then
        _orch_worktree_log "ERROR" "git worktree not supported by this git version"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_init "$project_root" "$cycle_num"
#   Initialize the worktree isolator. Sets project root and cycle number.
#   Creates .orchystraw/worktrees/ directory if needed.
# ---------------------------------------------------------------------------
orch_worktree_init() {
    local project_root="${1:?orch_worktree_init requires a project root}"
    local cycle_num="${2:?orch_worktree_init requires a cycle number}"

    # Resolve to absolute path
    if [[ "${project_root}" != /* ]]; then
        project_root="$(cd "${project_root}" && pwd)" || {
            _orch_worktree_log "ERROR" "could not resolve project root: ${project_root}"
            return 1
        }
    fi

    # Verify it is a git repo
    if [[ ! -d "${project_root}/.git" ]]; then
        _orch_worktree_log "ERROR" "not a git repository: ${project_root}"
        return 1
    fi

    _orch_worktree_check_support || return 1

    _ORCH_WORKTREE_ROOT="${project_root}"
    _ORCH_WORKTREE_CYCLE="${cycle_num}"
    _ORCH_WORKTREE_DIR="${project_root}/.orchystraw/worktrees"

    if [[ ! -d "${_ORCH_WORKTREE_DIR}" ]]; then
        mkdir -p "${_ORCH_WORKTREE_DIR}" || {
            _orch_worktree_log "ERROR" "could not create worktree directory: ${_ORCH_WORKTREE_DIR}"
            return 1
        }
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_create "$agent_id"
#   Create a git worktree for the given agent.
#   Branch: auto/agent-${agent_id}-cycle-${cycle_num}
#   Path:   .orchystraw/worktrees/${agent_id}
#   If the worktree already exists, remove and recreate it.
# ---------------------------------------------------------------------------
orch_worktree_create() {
    local agent_id="${1:?orch_worktree_create requires an agent_id}"
    local branch="auto/agent-${agent_id}-cycle-${_ORCH_WORKTREE_CYCLE}"
    local wt_path="${_ORCH_WORKTREE_DIR}/${agent_id}"

    # If worktree already exists for this agent, clean it up first
    if orch_worktree_exists "${agent_id}"; then
        orch_worktree_cleanup "${agent_id}" || {
            _orch_worktree_log "WARNING" "failed to clean up existing worktree for ${agent_id}, forcing removal"
            rm -rf "${wt_path}" 2>/dev/null
            _orch_worktree_git worktree prune 2>/dev/null
            _orch_worktree_git branch -D "${branch}" 2>/dev/null
        }
    fi

    # Delete the branch if it lingers from a previous run
    if _orch_worktree_git rev-parse --verify "${branch}" &>/dev/null; then
        _orch_worktree_git branch -D "${branch}" 2>/dev/null
    fi

    # Create worktree with a new branch from current HEAD
    _orch_worktree_git worktree add -b "${branch}" "${wt_path}" HEAD 2>/dev/null || {
        _orch_worktree_log "ERROR" "failed to create worktree for ${agent_id} at ${wt_path}"
        return 1
    }

    # Store state
    _ORCH_WORKTREE_PATHS["${agent_id}"]="${wt_path}"
    _ORCH_WORKTREE_BRANCHES["${agent_id}"]="${branch}"
    _ORCH_WORKTREE_MERGE_STATUS["${agent_id}"]="pending"

    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_get_path "$agent_id"
#   Print the absolute worktree path for the given agent.
#   Returns 1 if no worktree is registered for this agent.
# ---------------------------------------------------------------------------
orch_worktree_get_path() {
    local agent_id="${1:?orch_worktree_get_path requires an agent_id}"

    if [[ -z "${_ORCH_WORKTREE_PATHS[${agent_id}]:-}" ]]; then
        return 1
    fi

    printf '%s' "${_ORCH_WORKTREE_PATHS[${agent_id}]}"
    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_exists "$agent_id"
#   Check if a worktree exists for the given agent.
#   Returns 0 if the worktree directory exists and is registered.
# ---------------------------------------------------------------------------
orch_worktree_exists() {
    local agent_id="${1:?orch_worktree_exists requires an agent_id}"
    local wt_path="${_ORCH_WORKTREE_PATHS[${agent_id}]:-}"

    # Check both our internal state and the filesystem
    if [[ -n "${wt_path}" && -d "${wt_path}" ]]; then
        return 0
    fi

    # Also check the default path in case state was lost
    local default_path="${_ORCH_WORKTREE_DIR}/${agent_id}"
    if [[ -d "${default_path}/.git" ]]; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# orch_worktree_has_changes "$agent_id"
#   Check if the agent's worktree has uncommitted changes or new commits
#   ahead of the base branch. Returns 0 if changes are found.
# ---------------------------------------------------------------------------
orch_worktree_has_changes() {
    local agent_id="${1:?orch_worktree_has_changes requires an agent_id}"
    local wt_path="${_ORCH_WORKTREE_PATHS[${agent_id}]:-}"
    local branch="${_ORCH_WORKTREE_BRANCHES[${agent_id}]:-}"

    if [[ -z "${wt_path}" || -z "${branch}" ]]; then
        return 1
    fi

    # Check for uncommitted changes (staged or unstaged) in the worktree
    if ! git -C "${wt_path}" diff --quiet 2>/dev/null; then
        return 0
    fi
    if ! git -C "${wt_path}" diff --cached --quiet 2>/dev/null; then
        return 0
    fi

    # Check for untracked files in the worktree
    local untracked
    untracked="$(git -C "${wt_path}" ls-files --others --exclude-standard 2>/dev/null)"
    if [[ -n "${untracked}" ]]; then
        return 0
    fi

    # Check if the branch has commits ahead of the point it was created
    local ahead
    ahead="$(_orch_worktree_git rev-list --count HEAD.."${branch}" 2>/dev/null)"
    if [[ -n "${ahead}" && "${ahead}" -gt 0 ]]; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# orch_worktree_merge "$agent_id"
#   Merge the agent's worktree branch back to the current branch.
#   Only merges if the branch has commits ahead of HEAD.
#   Uses git merge --no-ff with a descriptive message.
#   Returns 0 on success, 1 on conflict or failure.
# ---------------------------------------------------------------------------
orch_worktree_merge() {
    local agent_id="${1:?orch_worktree_merge requires an agent_id}"
    local branch="${_ORCH_WORKTREE_BRANCHES[${agent_id}]:-}"

    if [[ -z "${branch}" ]]; then
        _orch_worktree_log "ERROR" "no branch registered for agent ${agent_id}"
        _ORCH_WORKTREE_MERGE_STATUS["${agent_id}"]="skipped"
        return 1
    fi

    # Check if branch has commits ahead
    local ahead
    ahead="$(_orch_worktree_git rev-list --count HEAD.."${branch}" 2>/dev/null)"
    if [[ -z "${ahead}" || "${ahead}" -eq 0 ]]; then
        _ORCH_WORKTREE_MERGE_STATUS["${agent_id}"]="skipped"
        return 0
    fi

    # Perform the merge
    local merge_msg="Merge agent ${agent_id} (cycle ${_ORCH_WORKTREE_CYCLE}, ${ahead} commit(s))"
    if _orch_worktree_git merge --no-ff -m "${merge_msg}" "${branch}" 2>/dev/null; then
        _ORCH_WORKTREE_MERGE_STATUS["${agent_id}"]="merged"
        return 0
    else
        # Merge failed — likely a conflict
        _orch_worktree_log "ERROR" "merge conflict for agent ${agent_id} on branch ${branch}"
        # Abort the failed merge to leave the repo clean
        _orch_worktree_git merge --abort 2>/dev/null
        _ORCH_WORKTREE_MERGE_STATUS["${agent_id}"]="conflict"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# orch_worktree_cleanup "$agent_id"
#   Remove a single agent's worktree and delete its branch.
#   Clears internal state for this agent.
# ---------------------------------------------------------------------------
orch_worktree_cleanup() {
    local agent_id="${1:?orch_worktree_cleanup requires an agent_id}"
    local wt_path="${_ORCH_WORKTREE_PATHS[${agent_id}]:-}"
    local branch="${_ORCH_WORKTREE_BRANCHES[${agent_id}]:-}"

    # Remove the worktree
    if [[ -n "${wt_path}" && -d "${wt_path}" ]]; then
        _orch_worktree_git worktree remove --force "${wt_path}" 2>/dev/null || {
            # Fallback: manual removal + prune
            rm -rf "${wt_path}" 2>/dev/null
            _orch_worktree_git worktree prune 2>/dev/null
        }
    fi

    # Delete the branch
    if [[ -n "${branch}" ]]; then
        _orch_worktree_git branch -D "${branch}" 2>/dev/null
    fi

    # Clear internal state
    unset '_ORCH_WORKTREE_PATHS['"${agent_id}"']'
    unset '_ORCH_WORKTREE_BRANCHES['"${agent_id}"']'
    unset '_ORCH_WORKTREE_MERGE_STATUS['"${agent_id}"']'

    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_cleanup_all
#   Remove all worktrees created this cycle.
# ---------------------------------------------------------------------------
orch_worktree_cleanup_all() {
    local agent_id

    # Iterate over a copy of keys since cleanup modifies the array
    local agents=("${!_ORCH_WORKTREE_PATHS[@]}")
    for agent_id in "${agents[@]}"; do
        orch_worktree_cleanup "${agent_id}"
    done

    # Prune any orphaned worktree references
    _orch_worktree_git worktree prune 2>/dev/null

    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_merge_all
#   Merge all worktrees that have changes, in registration order.
#   Prints the count of successful merges to stdout.
#   Skips worktrees with no changes.
# ---------------------------------------------------------------------------
orch_worktree_merge_all() {
    local agent_id
    local merged_count=0
    local agents=("${!_ORCH_WORKTREE_PATHS[@]}")

    for agent_id in "${agents[@]}"; do
        if ! orch_worktree_has_changes "${agent_id}"; then
            _ORCH_WORKTREE_MERGE_STATUS["${agent_id}"]="skipped"
            continue
        fi

        if orch_worktree_merge "${agent_id}"; then
            if [[ "${_ORCH_WORKTREE_MERGE_STATUS[${agent_id}]}" == "merged" ]]; then
                (( merged_count++ ))
            fi
        fi
    done

    printf '%d' "${merged_count}"
    return 0
}

# ---------------------------------------------------------------------------
# orch_worktree_list
#   Output list of active worktrees. One line per agent:
#     agent_id  path  branch  has_changes
# ---------------------------------------------------------------------------
orch_worktree_list() {
    local agent_id wt_path branch changes

    if [[ ${#_ORCH_WORKTREE_PATHS[@]} -eq 0 ]]; then
        return 0
    fi

    for agent_id in "${!_ORCH_WORKTREE_PATHS[@]}"; do
        wt_path="${_ORCH_WORKTREE_PATHS[${agent_id}]}"
        branch="${_ORCH_WORKTREE_BRANCHES[${agent_id}]:-unknown}"

        if orch_worktree_has_changes "${agent_id}"; then
            changes="yes"
        else
            changes="no"
        fi

        printf '%s\t%s\t%s\t%s\n' "${agent_id}" "${wt_path}" "${branch}" "${changes}"
    done
}

# ---------------------------------------------------------------------------
# orch_worktree_report
#   Print a formatted summary of worktree status for human consumption.
# ---------------------------------------------------------------------------
orch_worktree_report() {
    local agent_id wt_path branch status changes
    local total=${#_ORCH_WORKTREE_PATHS[@]}

    echo "--- Worktree Report (cycle ${_ORCH_WORKTREE_CYCLE}) ---"
    echo "Root:       ${_ORCH_WORKTREE_ROOT}"
    echo "Worktrees:  ${total}"
    echo ""

    if [[ ${total} -eq 0 ]]; then
        echo "  (no active worktrees)"
        echo "---"
        return 0
    fi

    printf '  %-16s %-10s %-44s %s\n' "AGENT" "STATUS" "BRANCH" "CHANGES"
    printf '  %-16s %-10s %-44s %s\n' "-----" "------" "------" "-------"

    for agent_id in "${!_ORCH_WORKTREE_PATHS[@]}"; do
        wt_path="${_ORCH_WORKTREE_PATHS[${agent_id}]}"
        branch="${_ORCH_WORKTREE_BRANCHES[${agent_id}]:-unknown}"
        status="${_ORCH_WORKTREE_MERGE_STATUS[${agent_id}]:-pending}"

        if orch_worktree_has_changes "${agent_id}"; then
            changes="yes"
        else
            changes="no"
        fi

        printf '  %-16s %-10s %-44s %s\n' "${agent_id}" "${status}" "${branch}" "${changes}"
    done

    echo "---"
    return 0
}
