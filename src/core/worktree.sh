#!/usr/bin/env bash
# worktree.sh — Git worktree isolation per agent (WORKTREE-001)
# v0.3.0 Phase 2: #44 (Git Worktree Isolation)
#         v0.3 adds: cleanup policies (age/stale/max), conflict detection before merge,
#         automatic merge strategies (ours/theirs/manual), pre-merge diff analysis
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
#   orch_worktree_detect_conflicts — check if two branches would conflict
#   orch_worktree_merge_strategy   — merge with configurable strategy
#   orch_worktree_cleanup_stale    — remove worktrees older than max age
#   orch_worktree_status           — show status of all active worktrees

[[ -n "${_ORCH_WORKTREE_LOADED:-}" ]] && return 0
_ORCH_WORKTREE_LOADED=1

# ── State ──
declare -g _ORCH_WORKTREE_ENABLED="${ORCH_WORKTREE:-false}"
declare -g _ORCH_WORKTREE_TMPDIR="${ORCH_WORKTREE_TMPDIR:-/tmp}"
declare -g _ORCH_WORKTREE_PREFIX="orchy"
declare -g -a _ORCH_WORKTREE_ACTIVE=()
declare -g _ORCH_WORKTREE_REPO_ROOT=""

# v0.3 Cleanup policy state
declare -g _ORCH_WORKTREE_MAX_AGE="${ORCH_WORKTREE_MAX_AGE:-3600}"         # seconds before stale (default 1h)
declare -g _ORCH_WORKTREE_MAX_COUNT="${ORCH_WORKTREE_MAX_COUNT:-20}"       # max concurrent worktrees
declare -g -A _ORCH_WORKTREE_CREATED_AT=()  # wt_path -> epoch timestamp
declare -g -A _ORCH_WORKTREE_AGENT_MAP=()   # wt_path -> agent_id
declare -g -A _ORCH_WORKTREE_CYCLE_MAP=()   # wt_path -> cycle_num

# v0.3 Merge strategy: auto | ours | theirs | manual
declare -g _ORCH_WORKTREE_MERGE_STRATEGY="${ORCH_WORKTREE_MERGE_STRATEGY:-auto}"

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
    _ORCH_WORKTREE_CREATED_AT["$wt_path"]=$(date +%s)
    _ORCH_WORKTREE_AGENT_MAP["$wt_path"]="$agent_id"
    _ORCH_WORKTREE_CYCLE_MAP["$wt_path"]="$cycle_num"
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

# ══════════════════════════════════════════════════
# v0.3 Conflict Detection
# ══════════════════════════════════════════════════

# orch_worktree_detect_conflicts <agent_id_a> <cycle_a> <agent_id_b> <cycle_b>
#   Check if two worktree branches would conflict when merged sequentially.
#   Returns 0 if conflict detected, 1 if clean.
#   Prints conflicting file paths to stdout (one per line).
orch_worktree_detect_conflicts() {
    local agent_a="${1:?detect_conflicts: agent_id_a required}"
    local cycle_a="${2:?detect_conflicts: cycle_a required}"
    local agent_b="${3:?detect_conflicts: agent_id_b required}"
    local cycle_b="${4:?detect_conflicts: cycle_b required}"

    [[ -z "$_ORCH_WORKTREE_REPO_ROOT" ]] && return 1

    local branch_a branch_b
    branch_a=$(orch_worktree_branch "$agent_a" "$cycle_a")
    branch_b=$(orch_worktree_branch "$agent_b" "$cycle_b")

    # Get files changed by each branch relative to their merge base
    local files_a files_b
    files_a=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" diff --name-only HEAD..."$branch_a" 2>/dev/null) || return 1
    files_b=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" diff --name-only HEAD..."$branch_b" 2>/dev/null) || return 1

    [[ -z "$files_a" || -z "$files_b" ]] && return 1

    # Find overlapping files
    local has_conflict=false
    local file_a
    while IFS= read -r file_a; do
        [[ -z "$file_a" ]] && continue
        if echo "$files_b" | grep -qxF "$file_a"; then
            printf '%s\n' "$file_a"
            has_conflict=true
        fi
    done <<< "$files_a"

    [[ "$has_conflict" == true ]] && return 0
    return 1
}

# orch_worktree_merge_strategy <agent_id> <cycle_num> [strategy]
#   Merge with a specific strategy. Strategies:
#     auto    — try merge, fail on conflict (default, same as orch_worktree_merge)
#     ours    — on conflict, keep the main branch version
#     theirs  — on conflict, keep the agent branch version
#     manual  — detect conflict, skip merge, return 1 for caller to handle
#   Returns 0 on success, 1 on conflict/failure.
orch_worktree_merge_strategy() {
    local agent_id="${1:?merge_strategy: agent_id required}"
    local cycle_num="${2:?merge_strategy: cycle_num required}"
    local strategy="${3:-$_ORCH_WORKTREE_MERGE_STRATEGY}"

    [[ -z "$_ORCH_WORKTREE_REPO_ROOT" ]] && {
        _orch_worktree_log ERROR "Worktree manager not initialized"
        return 1
    }

    if [[ "$agent_id" == *".."* || "$agent_id" == *"/"* ]]; then
        _orch_worktree_log ERROR "Invalid agent_id: $agent_id"
        return 1
    fi
    [[ ! "$cycle_num" =~ ^[0-9]+$ ]] && {
        _orch_worktree_log ERROR "Invalid cycle_num: $cycle_num"
        return 1
    }

    local wt_path branch
    wt_path=$(orch_worktree_path "$agent_id" "$cycle_num")
    branch=$(orch_worktree_branch "$agent_id" "$cycle_num")

    if [[ ! -d "$wt_path" ]]; then
        _orch_worktree_log WARN "Worktree does not exist: $wt_path"
        return 0
    fi

    local ahead
    ahead=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" rev-list HEAD.."$branch" --count 2>/dev/null || echo "0")

    if [[ "$ahead" -eq 0 ]]; then
        _orch_worktree_log INFO "Agent $agent_id produced no changes — skip merge"
        _orch_worktree_remove_tracking "$wt_path" "$branch"
        return 0
    fi

    case "$strategy" in
        auto)
            if ! git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --no-ff "$branch" \
                -m "feat(${agent_id}): cycle ${cycle_num} work" 2>/dev/null; then
                _orch_worktree_log ERROR "Merge conflict for $agent_id (strategy=auto)"
                return 1
            fi
            ;;
        ours)
            if ! git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --no-ff "$branch" \
                -X ours -m "feat(${agent_id}): cycle ${cycle_num} work (ours)" 2>/dev/null; then
                _orch_worktree_log ERROR "Merge failed for $agent_id even with strategy=ours"
                return 1
            fi
            _orch_worktree_log INFO "Merged $agent_id with strategy=ours (main wins on conflict)"
            ;;
        theirs)
            if ! git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --no-ff "$branch" \
                -X theirs -m "feat(${agent_id}): cycle ${cycle_num} work (theirs)" 2>/dev/null; then
                _orch_worktree_log ERROR "Merge failed for $agent_id even with strategy=theirs"
                return 1
            fi
            _orch_worktree_log INFO "Merged $agent_id with strategy=theirs (agent wins on conflict)"
            ;;
        manual)
            # Check if it would conflict without actually merging
            local merge_test
            merge_test=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --no-commit --no-ff "$branch" 2>&1) || {
                git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --abort 2>/dev/null
                _orch_worktree_log WARN "Conflict detected for $agent_id (strategy=manual) — caller must resolve"
                return 1
            }
            # No conflict — commit
            git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --abort 2>/dev/null
            git -C "$_ORCH_WORKTREE_REPO_ROOT" merge --no-ff "$branch" \
                -m "feat(${agent_id}): cycle ${cycle_num} work" 2>/dev/null
            ;;
        *)
            _orch_worktree_log ERROR "Unknown merge strategy: $strategy"
            return 1
            ;;
    esac

    _orch_worktree_log INFO "Merged $agent_id ($ahead commits from branch $branch)"
    _orch_worktree_remove_tracking "$wt_path" "$branch"
    return 0
}

# Internal: remove worktree + branch + tracking
_orch_worktree_remove_tracking() {
    local wt_path="$1"
    local branch="$2"

    git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$wt_path" &>/dev/null
    git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null

    local -a new_active=()
    for p in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
        [[ "$p" != "$wt_path" ]] && new_active+=("$p")
    done
    _ORCH_WORKTREE_ACTIVE=("${new_active[@]+"${new_active[@]}"}")

    unset "_ORCH_WORKTREE_CREATED_AT[$wt_path]"
    unset "_ORCH_WORKTREE_AGENT_MAP[$wt_path]"
    unset "_ORCH_WORKTREE_CYCLE_MAP[$wt_path]"
}

# ══════════════════════════════════════════════════
# v0.3 Cleanup Policies
# ══════════════════════════════════════════════════

# orch_worktree_cleanup_stale [max_age_seconds]
#   Remove worktrees older than max_age seconds. Defaults to _ORCH_WORKTREE_MAX_AGE.
#   Returns the number of stale worktrees removed.
orch_worktree_cleanup_stale() {
    local max_age="${1:-$_ORCH_WORKTREE_MAX_AGE}"
    local now
    now=$(date +%s)
    local removed=0

    local -a stale_paths=()
    for wt in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
        local created="${_ORCH_WORKTREE_CREATED_AT[$wt]:-0}"
        local age=$(( now - created ))
        if [[ "$age" -gt "$max_age" ]]; then
            stale_paths+=("$wt")
        fi
    done

    for wt in "${stale_paths[@]}"; do
        local agent="${_ORCH_WORKTREE_AGENT_MAP[$wt]:-unknown}"
        local cycle="${_ORCH_WORKTREE_CYCLE_MAP[$wt]:-0}"
        local branch
        branch=$(orch_worktree_branch "$agent" "$cycle")

        _orch_worktree_log WARN "Removing stale worktree: $wt (agent=$agent, age > ${max_age}s)"

        [[ -d "$wt" ]] && git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$wt" &>/dev/null
        git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null

        local -a new_active=()
        for p in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
            [[ "$p" != "$wt" ]] && new_active+=("$p")
        done
        _ORCH_WORKTREE_ACTIVE=("${new_active[@]+"${new_active[@]}"}")

        unset "_ORCH_WORKTREE_CREATED_AT[$wt]"
        unset "_ORCH_WORKTREE_AGENT_MAP[$wt]"
        unset "_ORCH_WORKTREE_CYCLE_MAP[$wt]"

        removed=$((removed + 1))
    done

    printf '%d\n' "$removed"
    return 0
}

# orch_worktree_enforce_max_count
#   If active worktree count exceeds MAX_COUNT, remove oldest first.
#   Returns count of removed worktrees.
orch_worktree_enforce_max_count() {
    local max_count="${_ORCH_WORKTREE_MAX_COUNT}"
    local removed=0

    while [[ "${#_ORCH_WORKTREE_ACTIVE[@]}" -gt "$max_count" ]]; do
        # Find oldest by creation timestamp
        local oldest_wt=""
        local oldest_time=999999999999
        local wt
        for wt in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
            local created="${_ORCH_WORKTREE_CREATED_AT[$wt]:-0}"
            if [[ "$created" -lt "$oldest_time" ]]; then
                oldest_time="$created"
                oldest_wt="$wt"
            fi
        done

        [[ -z "$oldest_wt" ]] && break

        local agent="${_ORCH_WORKTREE_AGENT_MAP[$oldest_wt]:-unknown}"
        local cycle="${_ORCH_WORKTREE_CYCLE_MAP[$oldest_wt]:-0}"
        local branch
        branch=$(orch_worktree_branch "$agent" "$cycle")

        _orch_worktree_log WARN "Max count ($max_count) exceeded — removing oldest: $oldest_wt"

        [[ -d "$oldest_wt" ]] && git -C "$_ORCH_WORKTREE_REPO_ROOT" worktree remove --force "$oldest_wt" &>/dev/null
        git -C "$_ORCH_WORKTREE_REPO_ROOT" branch -D "$branch" &>/dev/null

        # Rebuild active array without the removed entry
        local _tmp_active=()
        local p
        for p in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
            [[ "$p" != "$oldest_wt" ]] && _tmp_active+=("$p")
        done
        _ORCH_WORKTREE_ACTIVE=("${_tmp_active[@]+"${_tmp_active[@]}"}")

        unset "_ORCH_WORKTREE_CREATED_AT[$oldest_wt]"
        unset "_ORCH_WORKTREE_AGENT_MAP[$oldest_wt]"
        unset "_ORCH_WORKTREE_CYCLE_MAP[$oldest_wt]"

        removed=$((removed + 1))
    done

    printf '%d\n' "$removed"
    return 0
}

# orch_worktree_status
#   Print status of all active worktrees (path, agent, cycle, age, branch changes).
orch_worktree_status() {
    local now
    now=$(date +%s)

    printf 'worktree status (%d active, max %d):\n' "${#_ORCH_WORKTREE_ACTIVE[@]}" "$_ORCH_WORKTREE_MAX_COUNT"
    printf '%-40s %-12s %-6s %-8s %s\n' "PATH" "AGENT" "CYCLE" "AGE" "COMMITS"

    for wt in "${_ORCH_WORKTREE_ACTIVE[@]}"; do
        local agent="${_ORCH_WORKTREE_AGENT_MAP[$wt]:-unknown}"
        local cycle="${_ORCH_WORKTREE_CYCLE_MAP[$wt]:-?}"
        local created="${_ORCH_WORKTREE_CREATED_AT[$wt]:-0}"
        local age=$(( now - created ))
        local branch
        branch=$(orch_worktree_branch "$agent" "$cycle")

        local commits="0"
        if [[ -d "$wt" ]]; then
            commits=$(git -C "$_ORCH_WORKTREE_REPO_ROOT" rev-list HEAD.."$branch" --count 2>/dev/null || echo "?")
        else
            commits="(missing)"
        fi

        printf '%-40s %-12s %-6s %-8s %s\n' "$wt" "$agent" "$cycle" "${age}s" "$commits"
    done
}
