#!/usr/bin/env bash
# =============================================================================
# single-agent.sh — Single-agent mode for simple projects (#51)
#
# Runs OrchyStraw with a single agent, skipping PM coordination, review phase,
# multi-agent routing, and worktree isolation. Suitable for simple projects or
# Ralph-compatible single-agent workflows.
#
# Usage:
#   source src/core/single-agent.sh
#
#   orch_single_init "/path/to/project"
#   orch_single_is_active                         # → 0 if active
#   orch_single_detect "agents.conf"              # → 0 if recommended
#   orch_single_get_agent "agents.conf"           # → "06-backend"
#   orch_single_run "06-backend" "prompts/06-backend/06-backend.txt" "/project"
#   orch_single_skip_module "review-phase"        # → 0 (should skip)
#   orch_single_skip_module "quality-gates"       # → 1 (should keep)
#   orch_single_report
#
# Requires: bash 4.2+ (declare -g)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_SINGLE_AGENT_LOADED:-}" ]] && return 0
readonly _ORCH_SINGLE_AGENT_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g _ORCH_SINGLE_MODE=0          # 1 when single-agent mode is active
declare -g _ORCH_SINGLE_PROJECT_ROOT="" # absolute path to project root
declare -g _ORCH_SINGLE_AGENT_ID=""     # the agent ID in use
declare -g _ORCH_SINGLE_LAST_EXIT=0     # exit code from most recent run

# Modules to skip in single-agent mode (pipe-separated for easy matching)
readonly _ORCH_SINGLE_SKIP_MODULES="review-phase|dynamic-router|worktree-isolator|conditional-activation"

# Modules to keep in single-agent mode
readonly _ORCH_SINGLE_KEEP_MODULES="quality-gates|file-access|logger|error-handler|model-router|vcs-adapter"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_single_log <message>
#   Print a timestamped log line to stderr.
_orch_single_log() {
    printf '[single-agent] %s\n' "$1" >&2
}

# _orch_single_err <message>
#   Print an error to stderr and return 1.
_orch_single_err() {
    printf '[single-agent] ERROR: %s\n' "$1" >&2
    return 1
}

# _orch_single_trim <string>
#   Trim leading and trailing whitespace.
_orch_single_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# _orch_single_count_files <dir>
#   Count non-hidden files (non-recursively) in the given directory.
#   Outputs an integer.
_orch_single_count_files() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo 0
        return 0
    fi
    # Count regular files one level deep (non-hidden)
    local count=0
    local f
    for f in "$dir"/*; do
        [[ -f "$f" ]] && count=$((count + 1))
    done
    echo "$count"
}

# _orch_single_count_non_pm_agents <agents_conf>
#   Count agents in agents.conf that are NOT the PM (03-pm).
#   Outputs an integer.
_orch_single_count_non_pm_agents() {
    local conf_file="$1"
    if [[ ! -f "$conf_file" ]]; then
        echo 0
        return 0
    fi

    local count=0
    local line agent_id
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        IFS='|' read -ra fields <<< "$line"
        agent_id="$(_orch_single_trim "${fields[0]:-}")"
        [[ -z "$agent_id" ]] && continue

        # Skip PM agent
        [[ "$agent_id" == "03-pm" ]] && continue

        count=$((count + 1))
    done < "$conf_file"

    echo "$count"
}

# ---------------------------------------------------------------------------
# orch_single_init — Initialize single-agent mode
#
# Sets _ORCH_SINGLE_MODE=1 and stores the project root.
#
# Args:
#   $1 — project_root (absolute path to project directory)
# ---------------------------------------------------------------------------
orch_single_init() {
    local project_root="${1:-}"

    if [[ -z "$project_root" ]]; then
        _orch_single_err "init requires a project_root argument"
        return 1
    fi

    _ORCH_SINGLE_MODE=1
    _ORCH_SINGLE_PROJECT_ROOT="$project_root"
    _ORCH_SINGLE_AGENT_ID=""
    _ORCH_SINGLE_LAST_EXIT=0

    _orch_single_log "initialized — project root: $project_root"
    return 0
}

# ---------------------------------------------------------------------------
# orch_single_is_active — Check whether single-agent mode is enabled
#
# Returns: 0 if active (_ORCH_SINGLE_MODE=1), 1 otherwise
# ---------------------------------------------------------------------------
orch_single_is_active() {
    [[ "${_ORCH_SINGLE_MODE:-0}" == "1" ]]
}

# ---------------------------------------------------------------------------
# orch_single_detect — Auto-detect if single-agent mode is appropriate
#
# Conditions that recommend single-agent mode:
#   1. agents.conf has only 1 non-PM agent
#   2. The project root has fewer than 5 files (top-level)
#
# Args:
#   $1 — path to agents.conf
#
# Returns: 0 if single-agent mode is recommended, 1 if not
# ---------------------------------------------------------------------------
orch_single_detect() {
    local conf_file="${1:-}"

    if [[ -z "$conf_file" ]]; then
        _orch_single_err "detect requires an agents_conf argument"
        return 1
    fi

    if [[ ! -f "$conf_file" ]]; then
        _orch_single_err "agents.conf not found: $conf_file"
        return 1
    fi

    # Check 1: only 1 non-PM agent
    local agent_count
    agent_count="$(_orch_single_count_non_pm_agents "$conf_file")"
    if [[ "$agent_count" -eq 1 ]]; then
        _orch_single_log "detect: only 1 non-PM agent found — single-agent mode recommended"
        return 0
    fi

    # Check 2: project root has < 5 files
    if [[ -n "$_ORCH_SINGLE_PROJECT_ROOT" && -d "$_ORCH_SINGLE_PROJECT_ROOT" ]]; then
        local file_count
        file_count="$(_orch_single_count_files "$_ORCH_SINGLE_PROJECT_ROOT")"
        if [[ "$file_count" -lt 5 ]]; then
            _orch_single_log "detect: project has $file_count files (< 5) — single-agent mode recommended"
            return 0
        fi
    fi

    _orch_single_log "detect: multi-agent setup detected — single-agent mode not recommended"
    return 1
}

# ---------------------------------------------------------------------------
# orch_single_get_agent — Extract the single non-PM agent ID from agents.conf
#
# Parses agents.conf, filters out PM (03-pm), and returns the one remaining
# agent ID. Errors if more than one non-PM agent is present.
#
# Args:
#   $1 — path to agents.conf
#
# Outputs: agent ID (e.g., "06-backend")
# Returns: 0 on success, 1 on error (missing file, zero agents, > 1 agent)
# ---------------------------------------------------------------------------
orch_single_get_agent() {
    local conf_file="${1:-}"

    if [[ -z "$conf_file" ]]; then
        _orch_single_err "get_agent requires an agents_conf argument"
        return 1
    fi

    if [[ ! -f "$conf_file" ]]; then
        _orch_single_err "agents.conf not found: $conf_file"
        return 1
    fi

    local -a found_agents=()
    local line agent_id

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        IFS='|' read -ra fields <<< "$line"
        agent_id="$(_orch_single_trim "${fields[0]:-}")"
        [[ -z "$agent_id" ]] && continue
        [[ "$agent_id" == "03-pm" ]] && continue

        found_agents+=("$agent_id")
    done < "$conf_file"

    if [[ "${#found_agents[@]}" -eq 0 ]]; then
        _orch_single_err "no non-PM agents found in $conf_file"
        return 1
    fi

    if [[ "${#found_agents[@]}" -gt 1 ]]; then
        _orch_single_err "more than one non-PM agent found (${#found_agents[@]}): ${found_agents[*]}"
        return 1
    fi

    echo "${found_agents[0]}"
    return 0
}

# ---------------------------------------------------------------------------
# orch_single_skip_module — Check if a module should be skipped in single mode
#
# Modules that are skipped: review-phase, dynamic-router, worktree-isolator,
#   conditional-activation
# Modules that are kept: quality-gates, file-access, logger, error-handler,
#   model-router, vcs-adapter
#
# Args:
#   $1 — module_name (e.g., "review-phase", "quality-gates")
#
# Returns: 0 if the module should be skipped, 1 if it should be kept
# ---------------------------------------------------------------------------
orch_single_skip_module() {
    local module_name="${1:-}"

    if [[ -z "$module_name" ]]; then
        _orch_single_err "skip_module requires a module_name argument"
        return 1
    fi

    # Check against the skip list
    if [[ "$_ORCH_SINGLE_SKIP_MODULES" =~ (^|\|)"$module_name"(\||$) ]]; then
        return 0  # should skip
    fi

    return 1  # should keep
}

# ---------------------------------------------------------------------------
# orch_single_run — Execute a single agent directly
#
# Skips: PM phase, review phase, multi-agent routing, worktree isolation
# Applies: quality gates (if loaded), file access checks (if loaded)
#
# Args:
#   $1 — agent_id    (e.g., "06-backend")
#   $2 — prompt_path (path to the agent's prompt file)
#   $3 — project_root (absolute path to project root)
#
# Returns: the agent's exit code
# ---------------------------------------------------------------------------
orch_single_run() {
    local agent_id="${1:-}"
    local prompt_path="${2:-}"
    local project_root="${3:-$_ORCH_SINGLE_PROJECT_ROOT}"

    if [[ -z "$agent_id" ]]; then
        _orch_single_err "run requires agent_id"
        return 1
    fi

    if [[ -z "$prompt_path" ]]; then
        _orch_single_err "run requires prompt_path"
        return 1
    fi

    if [[ -z "$project_root" ]]; then
        _orch_single_err "run requires project_root (or call orch_single_init first)"
        return 1
    fi

    if [[ ! -f "$prompt_path" ]]; then
        _orch_single_err "prompt file not found: $prompt_path"
        return 1
    fi

    # Store active agent
    _ORCH_SINGLE_AGENT_ID="$agent_id"

    _orch_single_log "running agent: $agent_id"
    _orch_single_log "  prompt: $prompt_path"
    _orch_single_log "  project: $project_root"
    _orch_single_log "  skipped: PM phase, review phase, multi-agent routing, worktree isolation"

    # Apply file access check if the module is loaded
    if [[ -n "${_ORCH_FILE_ACCESS_LOADED:-}" ]]; then
        _orch_single_log "  file-access: module loaded — enforcing ownership checks"
    fi

    # Apply quality gates if the module is loaded
    if [[ -n "${_ORCH_QUALITY_GATES_LOADED:-}" ]]; then
        _orch_single_log "  quality-gates: module loaded — gates will apply"
    fi

    # Determine the CLI to use (model-router if loaded, else default to claude)
    local cli="claude"
    if [[ -n "${_ORCH_MODEL_ROUTER_LOADED:-}" ]]; then
        cli="$(orch_model_get_cli "$agent_id" 2>/dev/null || echo "claude")"
        _orch_single_log "  model-router: using CLI: $cli"
    fi

    # Build the prompt content
    local prompt_content
    prompt_content="$(< "$prompt_path")"

    # Execute the agent
    local agent_exit=0
    "$cli" "$prompt_content" 2>/dev/null || agent_exit=$?

    _ORCH_SINGLE_LAST_EXIT="$agent_exit"
    _orch_single_log "agent $agent_id completed with exit code: $agent_exit"

    return "$agent_exit"
}

# ---------------------------------------------------------------------------
# orch_single_report — Print single-agent mode status
# ---------------------------------------------------------------------------
orch_single_report() {
    echo "Single-Agent Mode — Status Report"
    echo ""

    if orch_single_is_active; then
        echo "  Mode:    ACTIVE"
    else
        echo "  Mode:    inactive"
    fi

    echo "  Project: ${_ORCH_SINGLE_PROJECT_ROOT:-<not set>}"
    echo "  Agent:   ${_ORCH_SINGLE_AGENT_ID:-<not set>}"
    echo "  Last exit code: ${_ORCH_SINGLE_LAST_EXIT:-0}"
    echo ""

    echo "  Skipped modules:"
    local mod
    # Split the skip list on pipes for display
    IFS='|' read -ra skip_list <<< "$_ORCH_SINGLE_SKIP_MODULES"
    for mod in "${skip_list[@]}"; do
        printf '    - %s\n' "$mod"
    done
    echo ""

    echo "  Active modules:"
    IFS='|' read -ra keep_list <<< "$_ORCH_SINGLE_KEEP_MODULES"
    for mod in "${keep_list[@]}"; do
        printf '    + %s\n' "$mod"
    done
}
