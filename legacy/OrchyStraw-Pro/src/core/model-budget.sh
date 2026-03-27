#!/usr/bin/env bash
# =============================================================================
# model-budget.sh — Fallback chains & budget controls (#69)
#
# Companion module to model-router.sh. Layers fallback chain resolution and
# per-agent / global invocation budgets on top of the model routing system.
# Operates independently — does NOT source model-router.sh.
#
# Usage:
#   source src/core/model-budget.sh
#
#   orch_budget_init
#   orch_budget_set_chain "06-backend" "claude,codex,gemini"
#   orch_budget_set_limit "06-backend" 10
#   orch_budget_set_global_limit 50
#   model="$(orch_budget_resolve "06-backend")"
#   orch_budget_record "06-backend" "$model"
#   orch_budget_report
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_MODEL_BUDGET_LOADED:-}" ]] && return 0
readonly _ORCH_MODEL_BUDGET_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_MB_CHAINS=()         # agent_id → "model1,model2,model3"
declare -gA _ORCH_MB_LIMITS=()         # agent_id → max_invocations (integer)
declare -g  _ORCH_MB_GLOBAL_LIMIT=0    # 0 = unlimited
declare -gA _ORCH_MB_AGENT_COUNT=()    # agent_id → current cycle invocations
declare -gA _ORCH_MB_MODEL_COUNT=()    # model_name → total invocations
declare -g  _ORCH_MB_GLOBAL_COUNT=0    # total invocations this cycle
declare -g  _ORCH_MB_DEFAULT_CHAIN="claude,codex,gemini"

# ---------------------------------------------------------------------------
# orch_budget_init — Initialize budget tracking, reset all state
#
# Clears all chains, limits, and counters. Safe to call multiple times.
# ---------------------------------------------------------------------------
orch_budget_init() {
    _ORCH_MB_CHAINS=()
    _ORCH_MB_LIMITS=()
    _ORCH_MB_GLOBAL_LIMIT=0
    _ORCH_MB_AGENT_COUNT=()
    _ORCH_MB_MODEL_COUNT=()
    _ORCH_MB_GLOBAL_COUNT=0
    _ORCH_MB_DEFAULT_CHAIN="claude,codex,gemini"
}

# ---------------------------------------------------------------------------
# orch_budget_set_chain — Set ordered fallback chain for an agent
#
# First model is preferred, second is fallback, etc.
#
# Args:
#   $1 — agent_id  (e.g., "06-backend")
#   $2 — chain     (comma-separated: "claude,codex,gemini")
# ---------------------------------------------------------------------------
orch_budget_set_chain() {
    local agent_id="$1"
    local chain="$2"

    if [[ -z "$agent_id" ]] || [[ -z "$chain" ]]; then
        printf '[model-budget] ERROR: set_chain requires agent_id and chain\n' >&2
        return 1
    fi

    _ORCH_MB_CHAINS["$agent_id"]="$chain"
}

# ---------------------------------------------------------------------------
# orch_budget_get_chain — Return the fallback chain for an agent
#
# Falls back to the default chain if no explicit chain is set.
#
# Args:
#   $1 — agent_id
#
# Outputs: comma-separated chain (e.g., "claude,codex,gemini")
# ---------------------------------------------------------------------------
orch_budget_get_chain() {
    local agent_id="$1"

    if [[ -z "$agent_id" ]]; then
        printf '[model-budget] ERROR: get_chain requires agent_id\n' >&2
        return 1
    fi

    echo "${_ORCH_MB_CHAINS[$agent_id]:-$_ORCH_MB_DEFAULT_CHAIN}"
}

# ---------------------------------------------------------------------------
# orch_budget_set_limit — Set per-agent invocation budget per cycle
#
# Args:
#   $1 — agent_id
#   $2 — max_invocations (integer, 0 = unlimited)
# ---------------------------------------------------------------------------
orch_budget_set_limit() {
    local agent_id="$1"
    local max_invocations="$2"

    if [[ -z "$agent_id" ]] || [[ -z "$max_invocations" ]]; then
        printf '[model-budget] ERROR: set_limit requires agent_id and max_invocations\n' >&2
        return 1
    fi

    if ! [[ "$max_invocations" =~ ^[0-9]+$ ]]; then
        printf '[model-budget] ERROR: max_invocations must be a non-negative integer\n' >&2
        return 1
    fi

    _ORCH_MB_LIMITS["$agent_id"]="$max_invocations"
}

# ---------------------------------------------------------------------------
# orch_budget_set_global_limit — Set global invocation limit across all agents
#
# Args:
#   $1 — max_invocations (integer, 0 = unlimited)
# ---------------------------------------------------------------------------
orch_budget_set_global_limit() {
    local max_invocations="$1"

    if [[ -z "$max_invocations" ]]; then
        printf '[model-budget] ERROR: set_global_limit requires max_invocations\n' >&2
        return 1
    fi

    if ! [[ "$max_invocations" =~ ^[0-9]+$ ]]; then
        printf '[model-budget] ERROR: max_invocations must be a non-negative integer\n' >&2
        return 1
    fi

    _ORCH_MB_GLOBAL_LIMIT="$max_invocations"
}

# ---------------------------------------------------------------------------
# orch_budget_record — Record an invocation (increments counters)
#
# Args:
#   $1 — agent_id
#   $2 — model_name
# ---------------------------------------------------------------------------
orch_budget_record() {
    local agent_id="$1"
    local model_name="$2"

    if [[ -z "$agent_id" ]] || [[ -z "$model_name" ]]; then
        printf '[model-budget] ERROR: record requires agent_id and model_name\n' >&2
        return 1
    fi

    # Increment agent counter
    local current="${_ORCH_MB_AGENT_COUNT[$agent_id]:-0}"
    _ORCH_MB_AGENT_COUNT["$agent_id"]=$(( current + 1 ))

    # Increment model counter
    local model_current="${_ORCH_MB_MODEL_COUNT[$model_name]:-0}"
    _ORCH_MB_MODEL_COUNT["$model_name"]=$(( model_current + 1 ))

    # Increment global counter
    _ORCH_MB_GLOBAL_COUNT=$(( _ORCH_MB_GLOBAL_COUNT + 1 ))
}

# ---------------------------------------------------------------------------
# orch_budget_remaining — Print remaining budget for an agent
#
# Args:
#   $1 — agent_id
#
# Outputs: remaining count (integer) or "unlimited"
# ---------------------------------------------------------------------------
orch_budget_remaining() {
    local agent_id="$1"

    if [[ -z "$agent_id" ]]; then
        printf '[model-budget] ERROR: remaining requires agent_id\n' >&2
        return 1
    fi

    local limit="${_ORCH_MB_LIMITS[$agent_id]:-0}"

    if [[ "$limit" -eq 0 ]]; then
        echo "unlimited"
        return 0
    fi

    local used="${_ORCH_MB_AGENT_COUNT[$agent_id]:-0}"
    local remaining=$(( limit - used ))

    if [[ "$remaining" -lt 0 ]]; then
        remaining=0
    fi

    echo "$remaining"
}

# ---------------------------------------------------------------------------
# orch_budget_is_exhausted — Check if agent's budget is exhausted
#
# Args:
#   $1 — agent_id
#
# Returns: 0 if exhausted, 1 if still has budget
# ---------------------------------------------------------------------------
orch_budget_is_exhausted() {
    local agent_id="$1"

    if [[ -z "$agent_id" ]]; then
        printf '[model-budget] ERROR: is_exhausted requires agent_id\n' >&2
        return 1
    fi

    local limit="${_ORCH_MB_LIMITS[$agent_id]:-0}"

    # 0 = unlimited → never exhausted
    if [[ "$limit" -eq 0 ]]; then
        return 1
    fi

    local used="${_ORCH_MB_AGENT_COUNT[$agent_id]:-0}"

    if [[ "$used" -ge "$limit" ]]; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# orch_budget_global_remaining — Print remaining global budget
#
# Outputs: remaining count (integer) or "unlimited"
# ---------------------------------------------------------------------------
orch_budget_global_remaining() {
    if [[ "$_ORCH_MB_GLOBAL_LIMIT" -eq 0 ]]; then
        echo "unlimited"
        return 0
    fi

    local remaining=$(( _ORCH_MB_GLOBAL_LIMIT - _ORCH_MB_GLOBAL_COUNT ))

    if [[ "$remaining" -lt 0 ]]; then
        remaining=0
    fi

    echo "$remaining"
}

# ---------------------------------------------------------------------------
# orch_budget_resolve — Resolve which model to use for an agent
#
# Walks the agent's fallback chain, skipping models whose CLI binary is
# not found in PATH. Respects both per-agent and global budget limits.
# Prints the resolved model name.
#
# Args:
#   $1 — agent_id
#
# Outputs: model name (e.g., "claude")
# Returns: 0 on success, 1 if all options exhausted
# ---------------------------------------------------------------------------
orch_budget_resolve() {
    local agent_id="$1"

    if [[ -z "$agent_id" ]]; then
        printf '[model-budget] ERROR: resolve requires agent_id\n' >&2
        return 1
    fi

    local chain="${_ORCH_MB_CHAINS[$agent_id]:-$_ORCH_MB_DEFAULT_CHAIN}"

    # Parse chain into array
    IFS=',' read -ra models <<< "$chain"

    local model
    for model in "${models[@]}"; do
        # Trim whitespace
        model="$(_orch_mb_trim "$model")"
        [[ -z "$model" ]] && continue

        # Check CLI availability
        if ! command -v "$model" &>/dev/null; then
            printf '[model-budget] WARN: %s CLI not found in PATH, skipping\n' "$model" >&2
            continue
        fi

        # Check agent budget
        if orch_budget_is_exhausted "$agent_id"; then
            printf '[model-budget] WARN: agent %s budget exhausted\n' "$agent_id" >&2
            return 1
        fi

        # Check global budget
        if _orch_mb_global_exhausted; then
            printf '[model-budget] WARN: global budget exhausted\n' >&2
            return 1
        fi

        echo "$model"
        return 0
    done

    printf '[model-budget] ERROR: no available model in chain for agent %s\n' "$agent_id" >&2
    return 1
}

# ---------------------------------------------------------------------------
# orch_budget_reset_cycle — Reset per-cycle counters (called at cycle start)
#
# Clears agent invocation counts, model counts, and global count.
# Does NOT reset chains or limits — those persist across cycles.
# ---------------------------------------------------------------------------
orch_budget_reset_cycle() {
    _ORCH_MB_AGENT_COUNT=()
    _ORCH_MB_MODEL_COUNT=()
    _ORCH_MB_GLOBAL_COUNT=0
}

# ---------------------------------------------------------------------------
# orch_budget_report — Print formatted budget summary
# ---------------------------------------------------------------------------
orch_budget_report() {
    echo "Model Budget — Summary Report"
    echo "  Default chain: $_ORCH_MB_DEFAULT_CHAIN"
    echo "  Global limit:  $(_orch_mb_fmt_limit "$_ORCH_MB_GLOBAL_LIMIT")"
    echo "  Global used:   $_ORCH_MB_GLOBAL_COUNT"
    echo ""

    # Agent chains & budgets
    echo "  Agent Chains & Budgets:"

    # Collect all known agent IDs from chains, limits, and counts
    local -A all_agents=()
    local key
    for key in "${!_ORCH_MB_CHAINS[@]}"; do all_agents["$key"]=1; done
    for key in "${!_ORCH_MB_LIMITS[@]}"; do all_agents["$key"]=1; done
    for key in "${!_ORCH_MB_AGENT_COUNT[@]}"; do all_agents["$key"]=1; done

    if [[ ${#all_agents[@]} -eq 0 ]]; then
        echo "    (none)"
    else
        local agent_id
        for agent_id in $(echo "${!all_agents[@]}" | tr ' ' '\n' | sort); do
            local chain="${_ORCH_MB_CHAINS[$agent_id]:-$_ORCH_MB_DEFAULT_CHAIN}"
            local limit="${_ORCH_MB_LIMITS[$agent_id]:-0}"
            local used="${_ORCH_MB_AGENT_COUNT[$agent_id]:-0}"
            local remaining
            remaining="$(orch_budget_remaining "$agent_id")"

            printf '    %-16s  chain=%-24s  used=%d  remaining=%s\n' \
                "$agent_id" "$chain" "$used" "$remaining"
        done
    fi
    echo ""

    # Model invocation counts
    echo "  Model Invocations:"
    if [[ ${#_ORCH_MB_MODEL_COUNT[@]} -eq 0 ]]; then
        echo "    (none)"
    else
        local model_name
        for model_name in $(echo "${!_ORCH_MB_MODEL_COUNT[@]}" | tr ' ' '\n' | sort); do
            printf '    %-10s : %d\n' "$model_name" "${_ORCH_MB_MODEL_COUNT[$model_name]}"
        done
    fi
}

# ---------------------------------------------------------------------------
# Internal helpers — prefixed with _orch_mb_
# ---------------------------------------------------------------------------

# Trim leading/trailing whitespace
_orch_mb_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Check if global budget is exhausted (0 = unlimited → never exhausted)
_orch_mb_global_exhausted() {
    if [[ "$_ORCH_MB_GLOBAL_LIMIT" -eq 0 ]]; then
        return 1
    fi
    if [[ "$_ORCH_MB_GLOBAL_COUNT" -ge "$_ORCH_MB_GLOBAL_LIMIT" ]]; then
        return 0
    fi
    return 1
}

# Format a limit value for display
_orch_mb_fmt_limit() {
    local limit="$1"
    if [[ "$limit" -eq 0 ]]; then
        echo "unlimited"
    else
        echo "$limit"
    fi
}
