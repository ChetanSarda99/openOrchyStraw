#!/usr/bin/env bash
# =============================================================================
# token-budget.sh — Per-agent output budgets for OrchyStraw (#35)
#
# Estimates and enforces token budgets for agent invocations.
# Prevents one agent from consuming disproportionate resources.
#
# Usage:
#   source src/core/token-budget.sh
#
#   orch_token_budget_init 500000           # Total budget pool (tokens)
#   orch_token_budget_allocate "06-backend" 3  # Allocate for 3 agents total
#   orch_token_budget_get "06-backend"      # Returns allocated tokens
#   orch_token_budget_record "06-backend" 45000  # Record actual usage
#   orch_token_budget_report                # Print usage summary
#
# Budget strategy:
#   - Total pool divided equally among active agents
#   - P0 agents get 1.5x base allocation
#   - Agents that used <50% last cycle get reduced allocation next cycle
#   - Hard cap prevents any agent from exceeding 2x base
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_TOKEN_BUDGET_LOADED:-}" ]] && return 0
readonly _ORCH_TOKEN_BUDGET_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_BUDGET_ALLOCATED=()   # agent_id → allocated tokens
declare -gA _ORCH_BUDGET_USED=()        # agent_id → actual tokens used
declare -gA _ORCH_BUDGET_HISTORY_USED=()      # agent_id → last cycle's usage
declare -gA _ORCH_BUDGET_HISTORY_ALLOCATED=() # agent_id → last cycle's allocation
declare -g  _ORCH_BUDGET_TOTAL=0        # Total token pool
declare -g  _ORCH_BUDGET_REMAINING=0    # Unallocated tokens

# Default total budget (configurable via env)
declare -g _ORCH_DEFAULT_BUDGET="${ORCH_TOKEN_BUDGET:-500000}"

# ---------------------------------------------------------------------------
# orch_token_budget_init — set total token pool for the cycle
#
# Args: $1 — total tokens (optional, defaults to ORCH_TOKEN_BUDGET or 500000)
# ---------------------------------------------------------------------------
orch_token_budget_init() {
    _ORCH_BUDGET_TOTAL="${1:-$_ORCH_DEFAULT_BUDGET}"
    _ORCH_BUDGET_REMAINING="$_ORCH_BUDGET_TOTAL"
    _ORCH_BUDGET_ALLOCATED=()
    _ORCH_BUDGET_USED=()
}

# ---------------------------------------------------------------------------
# orch_token_budget_allocate — allocate tokens for an agent
#
# Args:
#   $1 — agent_id
#   $2 — total number of active agents this cycle
#   $3 — priority multiplier (optional, default 1.0 = "1")
#         Use "15" for 1.5x (P0 agents), "10" for normal
#
# The base allocation = total / agent_count.
# Priority agents get multiplier applied.
# Hard cap = 2x base allocation.
# ---------------------------------------------------------------------------
orch_token_budget_allocate() {
    local agent_id="$1"
    local agent_count="${2:-1}"
    local priority_mult="${3:-10}"  # x10 scale: 10=1.0x, 15=1.5x, 20=2.0x

    [[ $agent_count -lt 1 ]] && agent_count=1

    local base=$(( _ORCH_BUDGET_TOTAL / agent_count ))
    local allocated=$(( base * priority_mult / 10 ))

    # Hard cap: no agent gets more than 2x base
    local hard_cap=$(( base * 2 ))
    [[ $allocated -gt $hard_cap ]] && allocated=$hard_cap

    # Adjust based on history: if agent used <50% last cycle, reduce by 25%
    local last_used="${_ORCH_BUDGET_HISTORY_USED[$agent_id]:-0}"
    local last_alloc="${_ORCH_BUDGET_HISTORY_ALLOCATED[$agent_id]:-0}"
    if [[ $last_alloc -gt 0 ]] && [[ $last_used -gt 0 ]]; then
        local usage_pct=$(( last_used * 100 / last_alloc ))
        if [[ $usage_pct -lt 50 ]]; then
            allocated=$(( allocated * 75 / 100 ))
        fi
    fi

    _ORCH_BUDGET_ALLOCATED["$agent_id"]=$allocated
    _ORCH_BUDGET_REMAINING=$(( _ORCH_BUDGET_REMAINING - allocated ))

    echo "$allocated"
}

# ---------------------------------------------------------------------------
# orch_token_budget_get — get allocated tokens for an agent
# ---------------------------------------------------------------------------
orch_token_budget_get() {
    local agent_id="$1"
    echo "${_ORCH_BUDGET_ALLOCATED[$agent_id]:-0}"
}

# ---------------------------------------------------------------------------
# orch_token_budget_record — record actual token usage after agent completes
#
# Args: $1 — agent_id, $2 — tokens used
# ---------------------------------------------------------------------------
orch_token_budget_record() {
    local agent_id="$1"
    local used="${2:-0}"
    _ORCH_BUDGET_USED["$agent_id"]=$used
}

# ---------------------------------------------------------------------------
# orch_token_budget_exceeded — check if agent exceeded its allocation
#
# Returns 0 (true) if exceeded, 1 (false) if within budget
# ---------------------------------------------------------------------------
orch_token_budget_exceeded() {
    local agent_id="$1"
    local allocated="${_ORCH_BUDGET_ALLOCATED[$agent_id]:-0}"
    local used="${_ORCH_BUDGET_USED[$agent_id]:-0}"
    [[ $used -gt $allocated ]]
}

# ---------------------------------------------------------------------------
# orch_token_budget_save_history — save current cycle's usage as history
# Call this at end of cycle so next cycle can adjust allocations.
# ---------------------------------------------------------------------------
orch_token_budget_save_history() {
    local agent_id
    for agent_id in "${!_ORCH_BUDGET_USED[@]}"; do
        _ORCH_BUDGET_HISTORY_USED["$agent_id"]="${_ORCH_BUDGET_USED[$agent_id]}"
    done
    for agent_id in "${!_ORCH_BUDGET_ALLOCATED[@]}"; do
        _ORCH_BUDGET_HISTORY_ALLOCATED["$agent_id"]="${_ORCH_BUDGET_ALLOCATED[$agent_id]}"
    done
}

# ---------------------------------------------------------------------------
# orch_token_budget_total_used — sum of all agents' actual usage
# ---------------------------------------------------------------------------
orch_token_budget_total_used() {
    local total=0
    local agent_id
    for agent_id in "${!_ORCH_BUDGET_USED[@]}"; do
        total=$(( total + _ORCH_BUDGET_USED[$agent_id] ))
    done
    echo "$total"
}

# ---------------------------------------------------------------------------
# orch_token_budget_report — print budget summary for the cycle
# ---------------------------------------------------------------------------
orch_token_budget_report() {
    local total_used
    total_used=$(orch_token_budget_total_used)
    local pct=0
    [[ $_ORCH_BUDGET_TOTAL -gt 0 ]] && pct=$(( total_used * 100 / _ORCH_BUDGET_TOTAL ))

    echo "Token Budget Report"
    echo "  Total pool: $_ORCH_BUDGET_TOTAL"
    echo "  Total used: $total_used ($pct%)"
    echo "  Remaining:  $_ORCH_BUDGET_REMAINING"
    echo ""

    local agent_id
    for agent_id in "${!_ORCH_BUDGET_ALLOCATED[@]}"; do
        local alloc="${_ORCH_BUDGET_ALLOCATED[$agent_id]}"
        local used="${_ORCH_BUDGET_USED[$agent_id]:-0}"
        local agent_pct=0
        [[ $alloc -gt 0 ]] && agent_pct=$(( used * 100 / alloc ))
        local status="OK"
        [[ $used -gt $alloc ]] && status="OVER"
        echo "  $agent_id: $used / $alloc ($agent_pct%) [$status]"
    done
}

# ---------------------------------------------------------------------------
# orch_token_budget_to_max_tokens — convert token budget to --max-tokens CLI flag
#
# Returns a reasonable --max-tokens value based on allocation.
# Output tokens are typically ~30% of total tokens for an agent invocation
# (the rest is input: prompt + context).
#
# Args: $1 — agent_id
# Returns: suggested max output tokens
# ---------------------------------------------------------------------------
orch_token_budget_to_max_tokens() {
    local agent_id="$1"
    local allocated="${_ORCH_BUDGET_ALLOCATED[$agent_id]:-100000}"
    # Output is ~30% of total budget, with a floor of 4096
    local max_output=$(( allocated * 30 / 100 ))
    [[ $max_output -lt 4096 ]] && max_output=4096
    echo "$max_output"
}
