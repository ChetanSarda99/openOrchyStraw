#!/usr/bin/env bash
# =============================================================================
# conditional-activation.sh — Skip idle agents (#32)
#
# Determines which agents should run this cycle based on:
#   1. Interval eligibility (base_interval from agents.conf)
#   2. Change detection in owned paths (git diff --name-only)
#   3. PM force-flag in shared context ("FORCE: <agent_id>")
#   4. Outcome history — agents with 3+ consecutive no-output cycles back off
#
# Usage:
#   source src/core/conditional-activation.sh
#
#   orch_activation_init
#   orch_activation_check "06-backend" 1 5 "src/core/ src/lib/"
#   orch_activation_force "09-qa"
#   orch_activation_record_outcome "06-backend" "active"
#   orch_activation_eligible_list
#   orch_activation_report
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_CONDITIONAL_ACTIVATION_LOADED:-}" ]] && return 0
readonly _ORCH_CONDITIONAL_ACTIVATION_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_ACTIV_STATUS=()       # agent_id → "eligible" | "skipped" | "forced"
declare -gA _ORCH_ACTIV_REASON=()       # agent_id → human-readable skip reason
declare -gA _ORCH_ACTIV_IDLE_STREAK=()  # agent_id → consecutive idle cycles
declare -gA _ORCH_ACTIV_FORCED=()       # agent_id → 1 if PM force-flagged
declare -g  _ORCH_ACTIV_CYCLE=0         # current cycle number
declare -g  _ORCH_ACTIV_PROJECT_ROOT="" # project root for git ops
declare -g  _ORCH_ACTIV_IDLE_THRESHOLD=3 # idle cycles before backoff

# ---------------------------------------------------------------------------
# orch_activation_init — reset state for a new cycle
#
# Args:
#   $1 — current cycle number
#   $2 — project root (optional, defaults to git rev-parse --show-toplevel)
#   $3 — idle threshold (optional, default 3)
# ---------------------------------------------------------------------------
orch_activation_init() {
    _ORCH_ACTIV_CYCLE="${1:-0}"
    _ORCH_ACTIV_PROJECT_ROOT="${2:-}"
    _ORCH_ACTIV_IDLE_THRESHOLD="${3:-3}"

    _ORCH_ACTIV_STATUS=()
    _ORCH_ACTIV_REASON=()
    _ORCH_ACTIV_FORCED=()

    # Resolve project root if not provided
    if [[ -z "$_ORCH_ACTIV_PROJECT_ROOT" ]]; then
        _ORCH_ACTIV_PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    fi
}

# ---------------------------------------------------------------------------
# orch_activation_force — mark an agent as force-run (PM override)
#
# Args: $1 — agent_id
# ---------------------------------------------------------------------------
orch_activation_force() {
    local agent_id="$1"
    [[ -z "$agent_id" ]] && return 1
    _ORCH_ACTIV_FORCED["$agent_id"]=1
}

# ---------------------------------------------------------------------------
# orch_activation_parse_forces — scan shared context for FORCE: directives
#
# Reads context.md and extracts lines matching "FORCE: <agent_id>"
# under the Notes or Blockers sections.
#
# Args: $1 — path to context.md
# ---------------------------------------------------------------------------
orch_activation_parse_forces() {
    local context_file="$1"
    [[ ! -f "$context_file" ]] && return 1

    local line
    while IFS= read -r line; do
        if [[ "$line" =~ FORCE:[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
            _ORCH_ACTIV_FORCED["${BASH_REMATCH[1]}"]=1
        fi
    done < "$context_file"
}

# ---------------------------------------------------------------------------
# _orch_activ_has_changes — check if agent's owned paths have recent changes
#
# Uses git diff to detect modifications in the agent's ownership paths
# since the last commit on the current branch vs the previous cycle.
#
# Args:
#   $1 — space-separated ownership paths (e.g., "src/core/ src/lib/")
#
# Returns: 0 if changes detected, 1 if no changes
# ---------------------------------------------------------------------------
_orch_activ_has_changes() {
    local ownership_paths="$1"
    [[ -z "$ownership_paths" ]] && return 1

    # Check for uncommitted changes in owned paths
    local -a paths=()
    read -ra paths <<< "$ownership_paths"

    local path
    for path in "${paths[@]}"; do
        # Skip negated paths (e.g., !scripts/auto-agent.sh)
        [[ "$path" == !* ]] && continue

        local full_path="${_ORCH_ACTIV_PROJECT_ROOT}/${path}"

        # Check git status for changes in this path
        if git -C "$_ORCH_ACTIV_PROJECT_ROOT" diff --name-only HEAD -- "$path" 2>/dev/null | grep -q .; then
            return 0
        fi

        # Check for untracked files
        if git -C "$_ORCH_ACTIV_PROJECT_ROOT" ls-files --others --exclude-standard -- "$path" 2>/dev/null | grep -q .; then
            return 0
        fi

        # Check staged changes
        if git -C "$_ORCH_ACTIV_PROJECT_ROOT" diff --cached --name-only -- "$path" 2>/dev/null | grep -q .; then
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# orch_activation_check — decide if an agent should run this cycle
#
# Decision logic:
#   1. If PM force-flagged → eligible (always)
#   2. If interval=0 (coordinator) → eligible (always runs last)
#   3. If cycle % interval != 0 → skipped (not scheduled)
#   4. If idle streak >= threshold AND no changes in owned paths → skipped
#   5. Otherwise → eligible
#
# Args:
#   $1 — agent_id
#   $2 — base_interval (from agents.conf)
#   $3 — current cycle number (uses _ORCH_ACTIV_CYCLE if omitted)
#   $4 — ownership paths (space-separated, from agents.conf)
#
# Returns: 0 if eligible, 1 if skipped
# Sets: _ORCH_ACTIV_STATUS[$agent_id], _ORCH_ACTIV_REASON[$agent_id]
# ---------------------------------------------------------------------------
orch_activation_check() {
    local agent_id="$1"
    local interval="${2:-1}"
    local cycle="${3:-$_ORCH_ACTIV_CYCLE}"
    local ownership="${4:-}"

    [[ -z "$agent_id" ]] && return 1

    # 1. Force-flagged agents always run
    if [[ "${_ORCH_ACTIV_FORCED[$agent_id]:-0}" == "1" ]]; then
        _ORCH_ACTIV_STATUS["$agent_id"]="forced"
        _ORCH_ACTIV_REASON["$agent_id"]="PM force-flagged"
        return 0
    fi

    # 2. Coordinators always run
    if [[ "$interval" -eq 0 ]]; then
        _ORCH_ACTIV_STATUS["$agent_id"]="eligible"
        _ORCH_ACTIV_REASON["$agent_id"]="coordinator (interval=0)"
        return 0
    fi

    # 3. Interval check
    if [[ "$cycle" -gt 0 ]] && [[ $(( cycle % interval )) -ne 0 ]]; then
        _ORCH_ACTIV_STATUS["$agent_id"]="skipped"
        _ORCH_ACTIV_REASON["$agent_id"]="not scheduled (cycle $cycle, interval $interval)"
        return 1
    fi

    # 4. Idle backoff — if agent has been idle too long and no changes detected
    local idle_streak="${_ORCH_ACTIV_IDLE_STREAK[$agent_id]:-0}"
    if [[ $idle_streak -ge $_ORCH_ACTIV_IDLE_THRESHOLD ]]; then
        if [[ -n "$ownership" ]] && ! _orch_activ_has_changes "$ownership"; then
            _ORCH_ACTIV_STATUS["$agent_id"]="skipped"
            _ORCH_ACTIV_REASON["$agent_id"]="idle backoff (${idle_streak} idle cycles, no changes in owned paths)"
            return 1
        fi
    fi

    # 5. Default: eligible
    _ORCH_ACTIV_STATUS["$agent_id"]="eligible"
    _ORCH_ACTIV_REASON["$agent_id"]="scheduled and active"
    return 0
}

# ---------------------------------------------------------------------------
# orch_activation_record_outcome — record whether agent produced output
#
# Call after agent completes. Updates idle streak counter.
#
# Args:
#   $1 — agent_id
#   $2 — outcome: "active" (produced changes) or "idle" (no changes)
# ---------------------------------------------------------------------------
orch_activation_record_outcome() {
    local agent_id="$1"
    local outcome="${2:-idle}"

    [[ -z "$agent_id" ]] && return 1

    case "$outcome" in
        active)
            _ORCH_ACTIV_IDLE_STREAK["$agent_id"]=0
            ;;
        idle)
            local current="${_ORCH_ACTIV_IDLE_STREAK[$agent_id]:-0}"
            _ORCH_ACTIV_IDLE_STREAK["$agent_id"]=$(( current + 1 ))
            ;;
    esac
}

# ---------------------------------------------------------------------------
# orch_activation_get_status — get activation status for an agent
#
# Args: $1 — agent_id
# Outputs: "eligible", "skipped", or "forced"
# ---------------------------------------------------------------------------
orch_activation_get_status() {
    local agent_id="$1"
    echo "${_ORCH_ACTIV_STATUS[$agent_id]:-unknown}"
}

# ---------------------------------------------------------------------------
# orch_activation_get_reason — get human-readable reason for status
#
# Args: $1 — agent_id
# ---------------------------------------------------------------------------
orch_activation_get_reason() {
    local agent_id="$1"
    echo "${_ORCH_ACTIV_REASON[$agent_id]:-no check performed}"
}

# ---------------------------------------------------------------------------
# orch_activation_idle_streak — get current idle streak for an agent
#
# Args: $1 — agent_id
# ---------------------------------------------------------------------------
orch_activation_idle_streak() {
    local agent_id="$1"
    echo "${_ORCH_ACTIV_IDLE_STREAK[$agent_id]:-0}"
}

# ---------------------------------------------------------------------------
# orch_activation_eligible_list — output space-separated list of eligible agents
# ---------------------------------------------------------------------------
orch_activation_eligible_list() {
    local -a eligible=()
    local agent_id
    for agent_id in "${!_ORCH_ACTIV_STATUS[@]}"; do
        local status="${_ORCH_ACTIV_STATUS[$agent_id]}"
        if [[ "$status" == "eligible" ]] || [[ "$status" == "forced" ]]; then
            eligible+=("$agent_id")
        fi
    done
    echo "${eligible[*]}"
}

# ---------------------------------------------------------------------------
# orch_activation_skipped_list — output space-separated list of skipped agents
# ---------------------------------------------------------------------------
orch_activation_skipped_list() {
    local -a skipped=()
    local agent_id
    for agent_id in "${!_ORCH_ACTIV_STATUS[@]}"; do
        if [[ "${_ORCH_ACTIV_STATUS[$agent_id]}" == "skipped" ]]; then
            skipped+=("$agent_id")
        fi
    done
    echo "${skipped[*]}"
}

# ---------------------------------------------------------------------------
# orch_activation_eligible_count — count of eligible agents
# ---------------------------------------------------------------------------
orch_activation_eligible_count() {
    local count=0
    local agent_id
    for agent_id in "${!_ORCH_ACTIV_STATUS[@]}"; do
        local status="${_ORCH_ACTIV_STATUS[$agent_id]}"
        if [[ "$status" == "eligible" ]] || [[ "$status" == "forced" ]]; then
            count=$(( count + 1 ))
        fi
    done
    echo "$count"
}

# ---------------------------------------------------------------------------
# orch_activation_report — print activation summary for the cycle
# ---------------------------------------------------------------------------
orch_activation_report() {
    echo "Conditional Activation Report — Cycle $_ORCH_ACTIV_CYCLE"
    echo "  Idle threshold: $_ORCH_ACTIV_IDLE_THRESHOLD consecutive cycles"
    echo ""

    local agent_id
    for agent_id in $(echo "${!_ORCH_ACTIV_STATUS[@]}" | tr ' ' '\n' | sort); do
        local status="${_ORCH_ACTIV_STATUS[$agent_id]}"
        local reason="${_ORCH_ACTIV_REASON[$agent_id]}"
        local idle="${_ORCH_ACTIV_IDLE_STREAK[$agent_id]:-0}"
        local marker="  "
        [[ "$status" == "eligible" || "$status" == "forced" ]] && marker="▶ "
        [[ "$status" == "skipped" ]] && marker="⏸ "
        echo "  ${marker}${agent_id}: ${status} — ${reason} (idle streak: ${idle})"
    done

    echo ""
    echo "  Eligible: $(orch_activation_eligible_count)"
    echo "  Skipped:  $(echo "${!_ORCH_ACTIV_STATUS[@]}" | wc -w) total - $(orch_activation_eligible_count) eligible"
}
