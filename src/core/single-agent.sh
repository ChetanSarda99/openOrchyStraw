#!/usr/bin/env bash
# =============================================================================
# single-agent.sh — Single-agent mode for OrchyStraw (#10)
#
# Ralph-compatible single-agent runner. Skips PM coordination, review phase,
# multi-agent routing, worktree isolation, conditional activation, and
# differential context. Keeps logging, error handling, timeouts, cycle state,
# prompt compression, session tracking.
#
# v0.4.0 additions:
#   - Focus mode (one agent gets all resources, boosted token budget)
#   - Checkpoint/resume (save state mid-cycle, resume after crash)
#   - Progress tracking (task completion percentage, ETA)
#
# Usage:
#   source src/core/single-agent.sh
#
#   orch_single_init "/path/to/project" "agents.conf"
#   orch_single_is_active                         # → 0 if active
#   orch_single_detect "agents.conf"              # → 0 if recommended
#   orch_single_get_agent "agents.conf"           # → "06-backend" (auto)
#   orch_single_get_agent "agents.conf" "11-web"  # → "11-web" (explicit)
#   orch_single_get_config "agents.conf" "06-backend"  # prints prompt|ownership|label|model
#   orch_single_skip_module "review-phase"        # → 0 (should skip)
#   orch_single_skip_module "logger"              # → 1 (should keep)
#   orch_single_report
#
#   # v0.4 features:
#   orch_single_focus_enable                      # enter focus mode
#   orch_single_checkpoint                        # save checkpoint
#   orch_single_resume                            # resume from last checkpoint
#   orch_single_progress_set 5 12                 # 5 of 12 tasks done
#   orch_single_progress_report                   # show progress bar
#
# Requires: bash 5.0+ (per BASH-001 ADR)
# =============================================================================

[[ -n "${_ORCH_SINGLE_AGENT_LOADED:-}" ]] && return 0
readonly _ORCH_SINGLE_AGENT_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g _ORCH_SINGLE_MODE=0
declare -g _ORCH_SINGLE_PROJECT_ROOT=""
declare -g _ORCH_SINGLE_CONF_FILE=""
declare -g _ORCH_SINGLE_AGENT_ID=""
declare -g _ORCH_SINGLE_CYCLES_RUN=0

# v0.4: Focus mode, checkpoints, progress
declare -g _ORCH_SINGLE_FOCUS=0
declare -g _ORCH_SINGLE_CHECKPOINT_DIR=""
declare -g _ORCH_SINGLE_PROGRESS_DONE=0
declare -g _ORCH_SINGLE_PROGRESS_TOTAL=0
declare -g _ORCH_SINGLE_PROGRESS_START=0
declare -g -a _ORCH_SINGLE_COMPLETED_TASKS=()

readonly _ORCH_SINGLE_SKIP_MODULES="review-phase|dynamic-router|worktree|conditional-activation|differential-context"
readonly _ORCH_SINGLE_KEEP_MODULES="logger|error-handler|cycle-state|agent-timeout|dry-run|config-validator|lock-file|signal-handler|cycle-tracker|prompt-compression|session-tracker|bash-version"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_orch_single_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log INFO single-agent "$1"
    else
        printf '[%s] [INFO ] [single-agent] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
    fi
}

_orch_single_warn() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log WARN single-agent "$1"
    else
        printf '[%s] [WARN ] [single-agent] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
    fi
}

_orch_single_err() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log ERROR single-agent "$1"
    else
        printf '[%s] [ERROR] [single-agent] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
    fi
    return 1
}

_orch_single_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# orch_single_init — Initialize single-agent mode
#
# Args:
#   $1 — project_root (absolute path)
#   $2 — agents_conf path (optional, defaults to $project_root/agents.conf)
# ---------------------------------------------------------------------------
orch_single_init() {
    local project_root="${1:-}"
    local conf_file="${2:-}"

    if [[ -z "$project_root" ]]; then
        _orch_single_err "init requires project_root"
        return 1
    fi

    if [[ ! -d "$project_root" ]]; then
        _orch_single_err "project root not found: $project_root"
        return 1
    fi

    if [[ -z "$conf_file" ]]; then
        conf_file="$project_root/agents.conf"
    fi

    _ORCH_SINGLE_MODE=1
    _ORCH_SINGLE_PROJECT_ROOT="$project_root"
    _ORCH_SINGLE_CONF_FILE="$conf_file"
    _ORCH_SINGLE_AGENT_ID=""
    _ORCH_SINGLE_CYCLES_RUN=0

    _orch_single_log "initialized — project: $project_root"
    return 0
}

# ---------------------------------------------------------------------------
# orch_single_is_active — Check if single-agent mode is enabled
#
# Returns: 0 if active, 1 otherwise
# ---------------------------------------------------------------------------
orch_single_is_active() {
    [[ "${_ORCH_SINGLE_MODE:-0}" == "1" ]]
}

# ---------------------------------------------------------------------------
# orch_single_detect — Auto-detect if single-agent mode is recommended
#
# Recommended when agents.conf has exactly 1 non-PM agent (interval > 0).
#
# Args:
#   $1 — path to agents.conf
#
# Returns: 0 if recommended, 1 if multi-agent setup detected
# ---------------------------------------------------------------------------
orch_single_detect() {
    local conf_file="${1:-$_ORCH_SINGLE_CONF_FILE}"

    if [[ -z "$conf_file" || ! -f "$conf_file" ]]; then
        _orch_single_err "detect: agents.conf not found: ${conf_file:-<empty>}"
        return 1
    fi

    local count=0
    local line agent_id interval

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        IFS='|' read -ra fields <<< "$line"
        agent_id="$(_orch_single_trim "${fields[0]:-}")"
        [[ -z "$agent_id" ]] && continue

        interval="$(_orch_single_trim "${fields[3]:-1}")"
        # interval=0 means coordinator (PM) — skip
        [[ "$interval" == "0" ]] && continue

        count=$((count + 1))
    done < "$conf_file"

    if [[ "$count" -eq 1 ]]; then
        _orch_single_log "detect: 1 worker agent — single-agent mode recommended"
        return 0
    fi

    _orch_single_log "detect: $count worker agents — multi-agent mode recommended"
    return 1
}

# ---------------------------------------------------------------------------
# orch_single_get_agent — Resolve the single agent to run
#
# If agent_id is provided, validates it exists in agents.conf.
# If not provided, auto-selects the first non-PM agent with interval > 0.
# Errors if agents.conf has > 1 non-PM agent and no agent_id specified.
#
# Args:
#   $1 — path to agents.conf
#   $2 — agent_id (optional — explicit selection)
#
# Outputs: agent ID to stdout
# Returns: 0 on success, 1 on error
# ---------------------------------------------------------------------------
orch_single_get_agent() {
    local conf_file="${1:-$_ORCH_SINGLE_CONF_FILE}"
    local requested_id="${2:-}"

    if [[ -z "$conf_file" || ! -f "$conf_file" ]]; then
        _orch_single_err "get_agent: agents.conf not found: ${conf_file:-<empty>}"
        return 1
    fi

    local -a workers=()
    local line agent_id interval

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        IFS='|' read -ra fields <<< "$line"
        agent_id="$(_orch_single_trim "${fields[0]:-}")"
        [[ -z "$agent_id" ]] && continue

        interval="$(_orch_single_trim "${fields[3]:-1}")"
        [[ "$interval" == "0" ]] && continue

        workers+=("$agent_id")
    done < "$conf_file"

    if [[ "${#workers[@]}" -eq 0 ]]; then
        _orch_single_err "get_agent: no worker agents found in $conf_file"
        return 1
    fi

    # Explicit selection — validate it exists
    if [[ -n "$requested_id" ]]; then
        local found=false
        for w in "${workers[@]}"; do
            if [[ "$w" == "$requested_id" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            _orch_single_err "get_agent: agent '$requested_id' not found in $conf_file"
            return 1
        fi
        echo "$requested_id"
        return 0
    fi

    # Auto-select: must have exactly 1 worker
    if [[ "${#workers[@]}" -gt 1 ]]; then
        _orch_single_err "get_agent: ${#workers[@]} worker agents found — specify one: ${workers[*]}"
        return 1
    fi

    echo "${workers[0]}"
    return 0
}

# ---------------------------------------------------------------------------
# orch_single_get_config — Get full config for an agent
#
# Args:
#   $1 — path to agents.conf
#   $2 — agent_id
#
# Outputs: pipe-delimited string: prompt_path|ownership|label|model
# Returns: 0 on success, 1 if agent not found
# ---------------------------------------------------------------------------
orch_single_get_config() {
    local conf_file="${1:-$_ORCH_SINGLE_CONF_FILE}"
    local target_id="${2:-}"

    if [[ -z "$target_id" ]]; then
        _orch_single_err "get_config: agent_id required"
        return 1
    fi

    if [[ -z "$conf_file" || ! -f "$conf_file" ]]; then
        _orch_single_err "get_config: agents.conf not found: ${conf_file:-<empty>}"
        return 1
    fi

    local line agent_id

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        IFS='|' read -ra fields <<< "$line"
        agent_id="$(_orch_single_trim "${fields[0]:-}")"

        if [[ "$agent_id" == "$target_id" ]]; then
            local prompt ownership label model
            prompt="$(_orch_single_trim "${fields[1]:-}")"
            ownership="$(_orch_single_trim "${fields[2]:-}")"
            label="$(_orch_single_trim "${fields[4]:-}")"
            model="$(_orch_single_trim "${fields[5]:-opus}")"
            echo "${prompt}|${ownership}|${label}|${model}"
            return 0
        fi
    done < "$conf_file"

    _orch_single_err "get_config: agent '$target_id' not found in $conf_file"
    return 1
}

# ---------------------------------------------------------------------------
# orch_single_skip_module — Check if a module should be skipped
#
# Skipped:  review-phase, dynamic-router, worktree, conditional-activation,
#           differential-context
# Kept:     logger, error-handler, cycle-state, agent-timeout, dry-run,
#           config-validator, lock-file, signal-handler, cycle-tracker,
#           prompt-compression, session-tracker, bash-version
#
# Args:
#   $1 — module name
#
# Returns: 0 if skip, 1 if keep
# ---------------------------------------------------------------------------
orch_single_skip_module() {
    local module_name="${1:-}"

    if [[ -z "$module_name" ]]; then
        _orch_single_err "skip_module: module_name required"
        return 1
    fi

    if [[ "|${_ORCH_SINGLE_SKIP_MODULES}|" == *"|${module_name}|"* ]]; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# orch_single_increment_cycle — Track cycle completion
# ---------------------------------------------------------------------------
orch_single_increment_cycle() {
    _ORCH_SINGLE_CYCLES_RUN=$((_ORCH_SINGLE_CYCLES_RUN + 1))
}

# ---------------------------------------------------------------------------
# orch_single_set_agent — Set the active agent ID (called by orchestrator)
#
# Args:
#   $1 — agent_id
# ---------------------------------------------------------------------------
orch_single_set_agent() {
    local agent_id="${1:-}"
    if [[ -z "$agent_id" ]]; then
        _orch_single_err "set_agent: agent_id required"
        return 1
    fi
    _ORCH_SINGLE_AGENT_ID="$agent_id"
    return 0
}

# ---------------------------------------------------------------------------
# orch_single_report — Print status summary
#
# Outputs: human-readable status to stdout
# ---------------------------------------------------------------------------
orch_single_report() {
    echo "=== Single-Agent Mode ==="
    echo ""

    if orch_single_is_active; then
        echo "  Status:  ACTIVE"
    else
        echo "  Status:  inactive"
    fi

    echo "  Project: ${_ORCH_SINGLE_PROJECT_ROOT:-<not set>}"
    echo "  Config:  ${_ORCH_SINGLE_CONF_FILE:-<not set>}"
    echo "  Agent:   ${_ORCH_SINGLE_AGENT_ID:-<not set>}"
    echo "  Cycles:  ${_ORCH_SINGLE_CYCLES_RUN:-0}"
    echo ""

    echo "  Skipped modules:"
    local IFS='|'
    local -a skip_arr
    read -ra skip_arr <<< "$_ORCH_SINGLE_SKIP_MODULES"
    for mod in "${skip_arr[@]}"; do
        printf '    - %s\n' "$mod"
    done
    echo ""

    echo "  Active modules:"
    local -a keep_arr
    read -ra keep_arr <<< "$_ORCH_SINGLE_KEEP_MODULES"
    for mod in "${keep_arr[@]}"; do
        printf '    + %s\n' "$mod"
    done

    if [[ $_ORCH_SINGLE_FOCUS -eq 1 ]]; then
        echo ""
        echo "  Focus mode: ACTIVE (boosted resources)"
    fi

    if [[ $_ORCH_SINGLE_PROGRESS_TOTAL -gt 0 ]]; then
        echo ""
        orch_single_progress_report
    fi
}

# ===========================================================================
# v0.4.0 — Focus Mode, Checkpoint/Resume, Progress Tracking
# ===========================================================================

# ---------------------------------------------------------------------------
# orch_single_focus_enable — enter focus mode (one agent gets all resources)
#
# In focus mode:
#   - Token budget is doubled (ORCH_MAX_TOKENS_PER_AGENT * 2)
#   - All other agents are suspended
#   - Quality gates are relaxed (warn instead of fail)
# ---------------------------------------------------------------------------
orch_single_focus_enable() {
    if ! orch_single_is_active; then
        _orch_single_err "focus mode requires single-agent mode to be active"
        return 1
    fi

    _ORCH_SINGLE_FOCUS=1
    _orch_single_log "focus mode ENABLED — all resources allocated to ${_ORCH_SINGLE_AGENT_ID:-agent}"

    # Export boosted token budget
    local current_budget="${ORCH_MAX_TOKENS_PER_AGENT:-100000}"
    export ORCH_MAX_TOKENS_PER_AGENT=$(( current_budget * 2 ))
    _orch_single_log "token budget boosted to ${ORCH_MAX_TOKENS_PER_AGENT}"
}

# ---------------------------------------------------------------------------
# orch_single_focus_disable — exit focus mode
# ---------------------------------------------------------------------------
orch_single_focus_disable() {
    _ORCH_SINGLE_FOCUS=0
    local current_budget="${ORCH_MAX_TOKENS_PER_AGENT:-200000}"
    export ORCH_MAX_TOKENS_PER_AGENT=$(( current_budget / 2 ))
    _orch_single_log "focus mode DISABLED — normal resource allocation"
}

# ---------------------------------------------------------------------------
# orch_single_focus_is_active — check if focus mode is on
# ---------------------------------------------------------------------------
orch_single_focus_is_active() {
    [[ "${_ORCH_SINGLE_FOCUS:-0}" == "1" ]]
}

# ---------------------------------------------------------------------------
# orch_single_checkpoint — save current state to disk for crash recovery
#
# Saves: agent ID, cycle count, progress, completed tasks
# Checkpoint dir: $PROJECT_ROOT/.orchystraw/checkpoints/
# ---------------------------------------------------------------------------
orch_single_checkpoint() {
    local project_root="${_ORCH_SINGLE_PROJECT_ROOT:-}"
    if [[ -z "$project_root" ]]; then
        _orch_single_err "checkpoint: project root not set"
        return 1
    fi

    _ORCH_SINGLE_CHECKPOINT_DIR="${project_root}/.orchystraw/checkpoints"
    mkdir -p "$_ORCH_SINGLE_CHECKPOINT_DIR" || {
        _orch_single_err "checkpoint: cannot create directory"
        return 1
    }

    local ckpt_file="${_ORCH_SINGLE_CHECKPOINT_DIR}/latest.ckpt"

    {
        printf 'ORCH_CKPT_VERSION=1\n'
        printf 'ORCH_CKPT_TIMESTAMP=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')"
        printf 'ORCH_CKPT_AGENT_ID=%s\n' "${_ORCH_SINGLE_AGENT_ID:-}"
        printf 'ORCH_CKPT_CYCLES_RUN=%d\n' "${_ORCH_SINGLE_CYCLES_RUN:-0}"
        printf 'ORCH_CKPT_FOCUS=%d\n' "${_ORCH_SINGLE_FOCUS:-0}"
        printf 'ORCH_CKPT_PROGRESS_DONE=%d\n' "${_ORCH_SINGLE_PROGRESS_DONE:-0}"
        printf 'ORCH_CKPT_PROGRESS_TOTAL=%d\n' "${_ORCH_SINGLE_PROGRESS_TOTAL:-0}"

        if [[ ${#_ORCH_SINGLE_COMPLETED_TASKS[@]} -gt 0 ]]; then
            local IFS='|'
            printf 'ORCH_CKPT_COMPLETED=%s\n' "${_ORCH_SINGLE_COMPLETED_TASKS[*]}"
        fi
    } > "$ckpt_file" || {
        _orch_single_err "checkpoint: cannot write checkpoint file"
        return 1
    }

    _orch_single_log "checkpoint saved: ${ckpt_file}"
    return 0
}

# ---------------------------------------------------------------------------
# orch_single_resume — resume from last checkpoint
#
# Restores state from the latest checkpoint file.
# Returns: 0 if resumed, 1 if no checkpoint found
# ---------------------------------------------------------------------------
orch_single_resume() {
    local project_root="${_ORCH_SINGLE_PROJECT_ROOT:-${1:-}}"
    if [[ -z "$project_root" ]]; then
        _orch_single_err "resume: project root not set"
        return 1
    fi

    local ckpt_file="${project_root}/.orchystraw/checkpoints/latest.ckpt"
    if [[ ! -f "$ckpt_file" ]]; then
        _orch_single_log "resume: no checkpoint found"
        return 1
    fi

    # Source the checkpoint file safely (only ORCH_CKPT_* vars)
    local line key val
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
            ORCH_CKPT_AGENT_ID)      _ORCH_SINGLE_AGENT_ID="$val" ;;
            ORCH_CKPT_CYCLES_RUN)    _ORCH_SINGLE_CYCLES_RUN="$val" ;;
            ORCH_CKPT_FOCUS)         _ORCH_SINGLE_FOCUS="$val" ;;
            ORCH_CKPT_PROGRESS_DONE) _ORCH_SINGLE_PROGRESS_DONE="$val" ;;
            ORCH_CKPT_PROGRESS_TOTAL) _ORCH_SINGLE_PROGRESS_TOTAL="$val" ;;
            ORCH_CKPT_COMPLETED)
                _ORCH_SINGLE_COMPLETED_TASKS=()
                local IFS='|'
                read -ra _ORCH_SINGLE_COMPLETED_TASKS <<< "$val"
                ;;
        esac
    done < "$ckpt_file"

    _ORCH_SINGLE_MODE=1
    _ORCH_SINGLE_PROJECT_ROOT="$project_root"
    _orch_single_log "resumed from checkpoint: agent=${_ORCH_SINGLE_AGENT_ID} cycle=${_ORCH_SINGLE_CYCLES_RUN} progress=${_ORCH_SINGLE_PROGRESS_DONE}/${_ORCH_SINGLE_PROGRESS_TOTAL}"

    return 0
}

# ---------------------------------------------------------------------------
# orch_single_checkpoint_exists — check if a checkpoint exists
# ---------------------------------------------------------------------------
orch_single_checkpoint_exists() {
    local project_root="${_ORCH_SINGLE_PROJECT_ROOT:-${1:-}}"
    [[ -f "${project_root}/.orchystraw/checkpoints/latest.ckpt" ]]
}

# ---------------------------------------------------------------------------
# orch_single_progress_set — set progress (done/total)
# Args: $1 — tasks done, $2 — total tasks
# ---------------------------------------------------------------------------
orch_single_progress_set() {
    local done="${1:-0}"
    local total="${2:-0}"

    _ORCH_SINGLE_PROGRESS_DONE=$done
    _ORCH_SINGLE_PROGRESS_TOTAL=$total

    if [[ $_ORCH_SINGLE_PROGRESS_START -eq 0 ]]; then
        _ORCH_SINGLE_PROGRESS_START=$(date '+%s')
    fi
}

# ---------------------------------------------------------------------------
# orch_single_progress_increment — mark one more task as done
# Args: $1 — task description (optional)
# ---------------------------------------------------------------------------
orch_single_progress_increment() {
    local task_desc="${1:-}"
    _ORCH_SINGLE_PROGRESS_DONE=$((_ORCH_SINGLE_PROGRESS_DONE + 1))

    if [[ -n "$task_desc" ]]; then
        _ORCH_SINGLE_COMPLETED_TASKS+=("$task_desc")
    fi
}

# ---------------------------------------------------------------------------
# orch_single_progress_report — print progress bar and ETA
# ---------------------------------------------------------------------------
orch_single_progress_report() {
    local done=$_ORCH_SINGLE_PROGRESS_DONE
    local total=$_ORCH_SINGLE_PROGRESS_TOTAL

    if [[ $total -eq 0 ]]; then
        echo "  Progress: no tasks tracked"
        return 0
    fi

    local pct=$(( done * 100 / total ))

    # Build progress bar (20 chars wide)
    local bar_width=20
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done

    printf '  Progress: [%s] %d/%d (%d%%)\n' "$bar" "$done" "$total" "$pct"

    # ETA calculation
    if [[ $done -gt 0 && $_ORCH_SINGLE_PROGRESS_START -gt 0 ]]; then
        local now
        now=$(date '+%s')
        local elapsed=$(( now - _ORCH_SINGLE_PROGRESS_START ))
        local remaining_tasks=$(( total - done ))
        local secs_per_task=$(( elapsed / done ))
        local eta_secs=$(( remaining_tasks * secs_per_task ))

        if [[ $eta_secs -gt 3600 ]]; then
            printf '  ETA: ~%dh %dm\n' $(( eta_secs / 3600 )) $(( (eta_secs % 3600) / 60 ))
        elif [[ $eta_secs -gt 60 ]]; then
            printf '  ETA: ~%dm\n' $(( eta_secs / 60 ))
        else
            printf '  ETA: ~%ds\n' "$eta_secs"
        fi
    fi

    # Show completed tasks
    if [[ ${#_ORCH_SINGLE_COMPLETED_TASKS[@]} -gt 0 ]]; then
        echo "  Completed:"
        for task in "${_ORCH_SINGLE_COMPLETED_TASKS[@]}"; do
            printf '    [x] %s\n' "$task"
        done
    fi
}
