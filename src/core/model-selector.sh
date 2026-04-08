#!/usr/bin/env bash
# =============================================================================
# model-selector.sh — Intelligent model selection per agent per task (#199)
#
# Provides task-aware model routing that goes beyond the basic tier system in
# dynamic-router.sh. Factors in:
#   - Task complexity estimation (prompt size, file count, issue severity)
#   - Per-agent x per-model quality score matrix (from quality-scores.jsonl)
#   - Budget-aware routing (if daily spend > 80%, downgrade non-critical agents)
#   - Fallback chain: opus -> sonnet -> haiku with auto-retry on rate limit
#   - A/B test support: randomly assign models, compare quality scores
#
# Integrates with dynamic-router.sh — call orch_model_select() instead of
# orch_router_model() for intelligent selection.
#
# Usage:
#   source src/core/model-selector.sh
#   orch_model_selector_init
#   model=$(orch_model_select "06-backend" "/path/to/prompt.md")
#
# Requires: bash 5.0+, dynamic-router.sh, quality-scorer.sh
# =============================================================================

[[ -n "${_ORCH_MODEL_SELECTOR_LOADED:-}" ]] && return 0
_ORCH_MODEL_SELECTOR_LOADED=1

# ── Configuration ──

# Complexity thresholds (tokens)
declare -g _MS_COMPLEXITY_LOW=500        # < 500 tokens = simple task
declare -g _MS_COMPLEXITY_HIGH=3000      # > 3000 tokens = complex task

# Budget thresholds (percentage of daily budget used)
declare -g _MS_BUDGET_WARN_PCT=60        # 60% — log warning
declare -g _MS_BUDGET_DOWNGRADE_PCT=80   # 80% — downgrade non-critical agents
declare -g _MS_BUDGET_CRITICAL_PCT=95    # 95% — all agents use haiku

# Daily budget in USD (default $50)
declare -g _MS_DAILY_BUDGET="${ORCH_DAILY_BUDGET:-50}"

# A/B testing
declare -g _MS_AB_ENABLED="${ORCH_AB_TEST:-0}"       # 0 = disabled, 1 = enabled
declare -g _MS_AB_PERCENTAGE="${ORCH_AB_PCT:-20}"     # % of runs assigned to variant

# Critical agents (never downgraded below sonnet even under budget pressure)
declare -g -a _MS_CRITICAL_AGENTS=("06-backend" "09-qa-code" "10-security")

# ── Internal state ──

declare -g -A _MS_QUALITY_MATRIX=()      # "agent:model" -> avg quality score
declare -g -A _MS_QUALITY_COUNT=()       # "agent:model" -> number of samples
declare -g -A _MS_AB_ASSIGNMENT=()       # agent_id -> "control"|"variant"
declare -g -A _MS_AB_MODEL=()            # agent_id -> model assigned by A/B test
declare -g _MS_DAILY_SPEND=0             # estimated daily spend in cents
declare -g _MS_INITIALIZED=false

# Cost per 1M tokens by model (USD, combined input+output estimate)
declare -g -A _MS_MODEL_COST=(
    [opus]=15.00
    [sonnet]=3.00
    [haiku]=0.25
)

# Model capability tiers (higher = more capable)
declare -g -A _MS_MODEL_CAPABILITY=(
    [opus]=3
    [sonnet]=2
    [haiku]=1
)

# ── Logging ──

_ms_log() {
    local level="$1" msg="$2"
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$level" "model-selector" "$msg"
    fi
}

# =============================================================================
# orch_model_selector_init [scores_file]
#
# Initialize the model selector. Loads quality score history from JSONL file
# and builds the agent x model quality matrix.
# =============================================================================
orch_model_selector_init() {
    local scores_file="${1:-}"
    local project_root="${PROJECT_ROOT:-.}"

    if [[ -z "$scores_file" ]]; then
        scores_file="$project_root/.orchystraw/quality-scores.jsonl"
    fi

    _MS_DAILY_SPEND=0
    _MS_QUALITY_MATRIX=()
    _MS_QUALITY_COUNT=()
    _MS_AB_ASSIGNMENT=()
    _MS_AB_MODEL=()

    # Load quality matrix from scores file
    if [[ -f "$scores_file" ]]; then
        _ms_load_quality_matrix "$scores_file"
    fi

    # Load daily spend from cost log if available
    local cost_log="$project_root/.orchystraw/cost-log.jsonl"
    if [[ -f "$cost_log" ]]; then
        _ms_load_daily_spend "$cost_log"
    fi

    _MS_INITIALIZED=true
    _ms_log INFO "Model selector initialized (scores_file=$scores_file, daily_spend=\$$(( _MS_DAILY_SPEND / 100 )).$(printf '%02d' $(( _MS_DAILY_SPEND % 100 ))))"
}

# =============================================================================
# _ms_load_quality_matrix <scores_file>
#
# Parse quality-scores.jsonl and build per-agent x per-model quality averages.
# Format: {"agent":"ID","score":N,"cycle":N,"ts":"...","model":"..."}
# =============================================================================
_ms_load_quality_matrix() {
    local scores_file="$1"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Extract agent, score, model using bash pattern matching
        local agent="" score="" model=""
        if [[ "$line" =~ \"agent\":\"([^\"]+)\" ]]; then
            agent="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ \"score\":([0-9]+) ]]; then
            score="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ \"model\":\"([^\"]+)\" ]]; then
            model="${BASH_REMATCH[1]}"
        fi

        [[ -z "$agent" || -z "$score" ]] && continue
        [[ -z "$model" ]] && model="opus"  # legacy entries without model field

        local key="$agent:$model"
        local prev_total="${_MS_QUALITY_MATRIX[$key]:-0}"
        local prev_count="${_MS_QUALITY_COUNT[$key]:-0}"

        _MS_QUALITY_MATRIX["$key"]=$(( prev_total + score ))
        _MS_QUALITY_COUNT["$key"]=$(( prev_count + 1 ))
    done < "$scores_file"

    # Convert totals to averages
    for key in "${!_MS_QUALITY_MATRIX[@]}"; do
        local total="${_MS_QUALITY_MATRIX[$key]}"
        local count="${_MS_QUALITY_COUNT[$key]}"
        if [[ "$count" -gt 0 ]]; then
            _MS_QUALITY_MATRIX["$key"]=$(( total / count ))
        fi
    done
}

# =============================================================================
# _ms_load_daily_spend <cost_log>
#
# Sum today's token costs from cost-log.jsonl.
# Format: {"agent":"ID","tokens":N,"model":"...","ts":"2026-04-07T..."}
# =============================================================================
_ms_load_daily_spend() {
    local cost_log="$1"
    local today
    today="$(date -u '+%Y-%m-%d')"

    _MS_DAILY_SPEND=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Only count today's entries
        if [[ "$line" == *"$today"* ]]; then
            local tokens="" model=""
            if [[ "$line" =~ \"tokens\":([0-9]+) ]]; then
                tokens="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ \"model\":\"([^\"]+)\" ]]; then
                model="${BASH_REMATCH[1]}"
            fi

            [[ -z "$tokens" ]] && continue
            [[ -z "$model" ]] && model="sonnet"

            # Estimate cost in cents: tokens / 1M * cost_per_M * 100
            local cost_per_m="${_MS_MODEL_COST[$model]:-3.00}"
            local cost_per_m_cents
            cost_per_m_cents=$(printf '%.0f' "$(echo "$cost_per_m * 100" | bc 2>/dev/null || echo "300")")
            local cost_cents=$(( tokens * cost_per_m_cents / 1000000 ))
            _MS_DAILY_SPEND=$(( _MS_DAILY_SPEND + cost_cents ))
        fi
    done < "$cost_log"
}

# =============================================================================
# orch_model_estimate_complexity <prompt_file_or_text>
#
# Estimate task complexity. Returns: low | medium | high
# Factors: prompt size (tokens), file count mentioned, severity keywords.
# =============================================================================
orch_model_estimate_complexity() {
    local input="$1"
    local text=""

    # Read from file or use as text
    if [[ -f "$input" ]]; then
        text="$(cat "$input")"
    else
        text="$input"
    fi

    local char_count=${#text}
    local token_estimate=$(( (char_count + 3) / 4 ))

    # Count file references (paths with extensions)
    local file_count=0
    file_count=$(printf '%s' "$text" | grep -oE '[a-zA-Z0-9_/-]+\.[a-zA-Z]{1,5}' 2>/dev/null | wc -l | tr -d ' ')
    file_count="${file_count:-0}"

    # Check for severity keywords
    local severity_score=0
    if printf '%s' "$text" | grep -qiE 'critical|urgent|blocker|security|vulnerability'; then
        severity_score=3
    elif printf '%s' "$text" | grep -qiE 'important|high.priority|regression|breaking'; then
        severity_score=2
    elif printf '%s' "$text" | grep -qiE 'minor|low.priority|cosmetic|typo'; then
        severity_score=0
    else
        severity_score=1
    fi

    # Composite complexity score
    local complexity_score=0

    # Token-based complexity
    if [[ "$token_estimate" -gt "$_MS_COMPLEXITY_HIGH" ]]; then
        complexity_score=$((complexity_score + 3))
    elif [[ "$token_estimate" -gt "$_MS_COMPLEXITY_LOW" ]]; then
        complexity_score=$((complexity_score + 2))
    else
        complexity_score=$((complexity_score + 1))
    fi

    # File count complexity
    if [[ "$file_count" -gt 20 ]]; then
        complexity_score=$((complexity_score + 3))
    elif [[ "$file_count" -gt 5 ]]; then
        complexity_score=$((complexity_score + 2))
    else
        complexity_score=$((complexity_score + 1))
    fi

    # Severity
    complexity_score=$((complexity_score + severity_score))

    # Map to level
    if [[ "$complexity_score" -ge 7 ]]; then
        printf 'high\n'
    elif [[ "$complexity_score" -ge 4 ]]; then
        printf 'medium\n'
    else
        printf 'low\n'
    fi
}

# =============================================================================
# orch_model_quality_for <agent_id> <model>
#
# Get the average quality score for a specific agent on a specific model.
# Returns the score (0-100) or -1 if no data.
# =============================================================================
orch_model_quality_for() {
    local agent_id="$1"
    local model="$2"
    local key="$agent_id:$model"

    if [[ -n "${_MS_QUALITY_MATRIX[$key]+x}" ]]; then
        printf '%d\n' "${_MS_QUALITY_MATRIX[$key]}"
    else
        printf '%d\n' "-1"
    fi
}

# =============================================================================
# orch_model_budget_pressure
#
# Returns budget pressure level: none | warn | downgrade | critical
# Based on percentage of daily budget consumed.
# =============================================================================
orch_model_budget_pressure() {
    local budget_cents=$(( _MS_DAILY_BUDGET * 100 ))

    [[ "$budget_cents" -le 0 ]] && { printf 'none\n'; return 0; }

    local pct_used=0
    if [[ "$budget_cents" -gt 0 ]]; then
        pct_used=$(( _MS_DAILY_SPEND * 100 / budget_cents ))
    fi

    if [[ "$pct_used" -ge "$_MS_BUDGET_CRITICAL_PCT" ]]; then
        printf 'critical\n'
    elif [[ "$pct_used" -ge "$_MS_BUDGET_DOWNGRADE_PCT" ]]; then
        printf 'downgrade\n'
    elif [[ "$pct_used" -ge "$_MS_BUDGET_WARN_PCT" ]]; then
        printf 'warn\n'
    else
        printf 'none\n'
    fi
}

# =============================================================================
# _ms_is_critical_agent <agent_id>
#
# Returns 0 if agent is critical (should not be downgraded below sonnet).
# =============================================================================
_ms_is_critical_agent() {
    local agent_id="$1"
    for critical in "${_MS_CRITICAL_AGENTS[@]}"; do
        [[ "$agent_id" == "$critical" ]] && return 0
    done
    return 1
}

# =============================================================================
# orch_model_ab_assign <agent_id>
#
# Assign an agent to A/B test group (control or variant).
# Control uses the normally-selected model, variant uses one tier down.
# Returns: control | variant
# =============================================================================
orch_model_ab_assign() {
    local agent_id="$1"

    # Return existing assignment if already assigned
    if [[ -n "${_MS_AB_ASSIGNMENT[$agent_id]+x}" ]]; then
        printf '%s\n' "${_MS_AB_ASSIGNMENT[$agent_id]}"
        return 0
    fi

    # Random assignment based on AB_PERCENTAGE
    local rand=$(( RANDOM % 100 ))
    if [[ "$rand" -lt "$_MS_AB_PERCENTAGE" ]]; then
        _MS_AB_ASSIGNMENT["$agent_id"]="variant"
    else
        _MS_AB_ASSIGNMENT["$agent_id"]="control"
    fi

    printf '%s\n' "${_MS_AB_ASSIGNMENT[$agent_id]}"
}

# =============================================================================
# orch_model_ab_report
#
# Print A/B test comparison report from quality scores.
# =============================================================================
orch_model_ab_report() {
    printf 'A/B Test Report:\n'
    printf '%-15s %-10s %-8s %-8s\n' "AGENT" "GROUP" "MODEL" "AVG_QUAL"

    for agent_id in "${!_MS_AB_ASSIGNMENT[@]}"; do
        local group="${_MS_AB_ASSIGNMENT[$agent_id]}"
        local model="${_MS_AB_MODEL[$agent_id]:-unknown}"
        local qual=-1

        if [[ -n "${_MS_QUALITY_MATRIX[$agent_id:$model]+x}" ]]; then
            qual="${_MS_QUALITY_MATRIX[$agent_id:$model]}"
        fi

        printf '%-15s %-10s %-8s %-8d\n' "$agent_id" "$group" "$model" "$qual"
    done
}

# =============================================================================
# orch_model_record_spend <agent_id> <tokens> <model>
#
# Record token spend for budget tracking. Writes to cost-log.jsonl.
# =============================================================================
orch_model_record_spend() {
    local agent_id="$1"
    local tokens="$2"
    local model="${3:-sonnet}"
    local project_root="${PROJECT_ROOT:-.}"
    local ts
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    mkdir -p "$project_root/.orchystraw"
    local cost_log="$project_root/.orchystraw/cost-log.jsonl"

    echo "{\"agent\":\"$agent_id\",\"tokens\":$tokens,\"model\":\"$model\",\"ts\":\"$ts\"}" >> "$cost_log"

    # Update in-memory spend
    local cost_per_m="${_MS_MODEL_COST[$model]:-3.00}"
    local cost_per_m_cents
    cost_per_m_cents=$(printf '%.0f' "$(echo "$cost_per_m * 100" | bc 2>/dev/null || echo "300")")
    local cost_cents=$(( tokens * cost_per_m_cents / 1000000 ))
    _MS_DAILY_SPEND=$(( _MS_DAILY_SPEND + cost_cents ))
}

# =============================================================================
# orch_model_select <agent_id> [prompt_file]
#
# Intelligent model selection. The main entry point.
#
# Selection logic (in priority order):
#   1. Env var override (ORCH_MODEL_OVERRIDE_<AGENT>) — always respected
#   2. A/B test assignment (if enabled)
#   3. Budget pressure: critical -> haiku, downgrade -> sonnet for non-critical
#   4. Quality matrix: if agent scores well on cheaper model, use it
#   5. Complexity: high -> opus, medium -> sonnet, low -> haiku
#   6. Fall back to dynamic-router's orch_router_model_name
#
# Returns the abstract model name (opus/sonnet/haiku).
# =============================================================================
orch_model_select() {
    local agent_id="${1:?orch_model_select: agent_id required}"
    local prompt_file="${2:-}"

    # Priority 1: Env var override (pass through to router)
    local env_key="${agent_id//-/_}"
    env_key="${env_key^^}"
    local override_var="ORCH_MODEL_OVERRIDE_${env_key}"
    if [[ -n "${!override_var:-}" ]]; then
        printf '%s\n' "${!override_var}"
        return 0
    fi

    # Priority 2: A/B test
    if [[ "$_MS_AB_ENABLED" == "1" ]]; then
        local group
        group=$(orch_model_ab_assign "$agent_id")
        if [[ "$group" == "variant" ]]; then
            # Variant: use one tier cheaper than normal selection
            local normal_model
            normal_model=$(_ms_select_by_quality_and_complexity "$agent_id" "$prompt_file")
            local variant_model
            if [[ "$(type -t orch_router_model_fallback)" == "function" ]]; then
                variant_model=$(orch_router_model_fallback "$normal_model" 2>/dev/null)
            fi
            variant_model="${variant_model:-$normal_model}"
            _MS_AB_MODEL["$agent_id"]="$variant_model"
            _ms_log INFO "A/B variant: $agent_id assigned $variant_model (control would be $normal_model)"
            printf '%s\n' "$variant_model"
            return 0
        fi
    fi

    # Priority 3: Budget pressure
    local pressure
    pressure=$(orch_model_budget_pressure)

    case "$pressure" in
        critical)
            _ms_log WARN "Budget critical — $agent_id forced to haiku"
            printf 'haiku\n'
            return 0
            ;;
        downgrade)
            if ! _ms_is_critical_agent "$agent_id"; then
                _ms_log INFO "Budget pressure — $agent_id downgraded to haiku"
                printf 'haiku\n'
                return 0
            else
                _ms_log INFO "Budget pressure but $agent_id is critical — capped at sonnet"
                printf 'sonnet\n'
                return 0
            fi
            ;;
    esac

    # Priority 4 & 5: Quality matrix + complexity
    local selected
    selected=$(_ms_select_by_quality_and_complexity "$agent_id" "$prompt_file")

    # Record for A/B tracking if enabled
    if [[ "$_MS_AB_ENABLED" == "1" ]]; then
        _MS_AB_MODEL["$agent_id"]="$selected"
    fi

    printf '%s\n' "$selected"
}

# =============================================================================
# _ms_select_by_quality_and_complexity <agent_id> [prompt_file]
#
# Internal: select model based on quality history and task complexity.
# =============================================================================
_ms_select_by_quality_and_complexity() {
    local agent_id="$1"
    local prompt_file="${2:-}"

    # Check quality matrix: can this agent use a cheaper model effectively?
    local sonnet_qual haiku_qual
    sonnet_qual=$(orch_model_quality_for "$agent_id" "sonnet")
    haiku_qual=$(orch_model_quality_for "$agent_id" "haiku")

    # If agent scores 75+ on haiku with 3+ samples, use haiku for simple tasks
    local haiku_count="${_MS_QUALITY_COUNT[$agent_id:haiku]:-0}"
    local sonnet_count="${_MS_QUALITY_COUNT[$agent_id:sonnet]:-0}"

    # Estimate complexity if prompt file available
    local complexity="medium"
    if [[ -n "$prompt_file" && -f "$prompt_file" ]]; then
        complexity=$(orch_model_estimate_complexity "$prompt_file")
    fi

    # Decision matrix
    case "$complexity" in
        low)
            # Simple task: prefer cheapest model with proven quality
            if [[ "$haiku_qual" -ge 75 && "$haiku_count" -ge 3 ]]; then
                printf 'haiku\n'
                return 0
            elif [[ "$sonnet_qual" -ge 70 && "$sonnet_count" -ge 3 ]]; then
                printf 'sonnet\n'
                return 0
            fi
            printf 'sonnet\n'  # default for low complexity
            return 0
            ;;
        medium)
            # Medium task: prefer sonnet if proven, otherwise opus
            if [[ "$sonnet_qual" -ge 70 && "$sonnet_count" -ge 3 ]]; then
                printf 'sonnet\n'
                return 0
            fi
            printf 'opus\n'  # default for medium complexity
            return 0
            ;;
        high)
            # Complex task: use opus unless quality data strongly supports sonnet
            if [[ "$sonnet_qual" -ge 85 && "$sonnet_count" -ge 5 ]]; then
                printf 'sonnet\n'
                return 0
            fi
            printf 'opus\n'
            return 0
            ;;
    esac

    # Fallback: use router's model
    if [[ "$(type -t orch_router_model_name)" == "function" ]]; then
        orch_router_model_name "$agent_id" 2>/dev/null
    else
        printf 'opus\n'
    fi
}

# =============================================================================
# orch_model_select_with_fallback <agent_id> <run_cmd_func> [prompt_file] [log_file]
#
# Select model intelligently, then run with fallback chain on rate limit.
# Wraps orch_router_try_with_fallback with intelligent initial selection.
# =============================================================================
orch_model_select_with_fallback() {
    local agent_id="${1:?orch_model_select_with_fallback: agent_id required}"
    local run_cmd="${2:?orch_model_select_with_fallback: run_cmd required}"
    local prompt_file="${3:-}"
    local log_file="${4:-/dev/null}"

    # Select model intelligently
    local selected_model
    selected_model=$(orch_model_select "$agent_id" "$prompt_file")

    # Override the router's model for this agent temporarily
    _ORCH_ROUTER_MODEL["$agent_id"]="$selected_model"

    # Delegate to router's fallback mechanism
    if [[ "$(type -t orch_router_try_with_fallback)" == "function" ]]; then
        orch_router_try_with_fallback "$agent_id" "$run_cmd" 3 "$log_file"
    else
        # Fallback: just run directly
        local model_flag="${_ORCH_MODEL_FLAGS[$selected_model]:-$selected_model}"
        $run_cmd "$model_flag" "$log_file"
    fi
}

# =============================================================================
# orch_model_selector_report
#
# Print model selector status and quality matrix.
# =============================================================================
orch_model_selector_report() {
    local budget_cents=$(( _MS_DAILY_BUDGET * 100 ))
    local pct_used=0
    [[ "$budget_cents" -gt 0 ]] && pct_used=$(( _MS_DAILY_SPEND * 100 / budget_cents ))

    printf 'Model Selector Report:\n'
    printf '  Daily budget: $%d | Spent: $%d.%02d (%d%%)\n' \
        "$_MS_DAILY_BUDGET" \
        "$(( _MS_DAILY_SPEND / 100 ))" \
        "$(( _MS_DAILY_SPEND % 100 ))" \
        "$pct_used"
    printf '  Budget pressure: %s\n' "$(orch_model_budget_pressure)"
    printf '  A/B testing: %s\n' "$( [[ "$_MS_AB_ENABLED" == "1" ]] && echo "enabled (${_MS_AB_PERCENTAGE}%%)" || echo "disabled" )"
    printf '\n'

    printf 'Quality Matrix (avg score per agent x model):\n'
    printf '  %-15s %-8s %-8s %-8s\n' "AGENT" "OPUS" "SONNET" "HAIKU"

    # Collect unique agents
    local -A seen_agents=()
    for key in "${!_MS_QUALITY_MATRIX[@]}"; do
        local agent="${key%%:*}"
        seen_agents["$agent"]=1
    done

    for agent in "${!seen_agents[@]}"; do
        local opus_q sonnet_q haiku_q
        opus_q="${_MS_QUALITY_MATRIX[$agent:opus]:--}"
        sonnet_q="${_MS_QUALITY_MATRIX[$agent:sonnet]:--}"
        haiku_q="${_MS_QUALITY_MATRIX[$agent:haiku]:--}"
        printf '  %-15s %-8s %-8s %-8s\n' "$agent" "$opus_q" "$sonnet_q" "$haiku_q"
    done
}
