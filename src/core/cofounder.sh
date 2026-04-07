#!/usr/bin/env bash
# =============================================================================
# cofounder.sh — Co-Founder operational module for OrchyStraw
#
# Provides functions for the Co-Founder agent's autonomous operational loop:
#   - Agent health review and flagging
#   - Interval adjustment based on activity data
#   - Budget monitoring and alerting
#   - Escalation to Founder via Telegram
#
# Sourceable module — integrates into auto-agent.sh.
#
# Usage:
#   source src/core/cofounder.sh
#   orch_cofounder_review_health
#   orch_cofounder_adjust_intervals
#   orch_cofounder_check_budget
#   orch_cofounder_escalate "budget" "Daily spend $52, limit $50"
#
# Requires: bash 5.0+, logger.sh (for orch_log), auto-agent.sh globals
# =============================================================================

[[ -n "${_ORCH_COFOUNDER_LOADED:-}" ]] && return 0
readonly _ORCH_COFOUNDER_LOADED=1

# ── Configuration ──

# Budget thresholds in microdollars (1 dollar = 1000000 microdollars)
COFOUNDER_BUDGET_WARN=20000000      # $20/day — log warning
COFOUNDER_BUDGET_HIGH=35000000      # $35/day — downgrade models
COFOUNDER_BUDGET_CRITICAL=50000000  # $50/day — escalate to Founder

# Interval adjustment limits
COFOUNDER_MIN_INTERVAL=1
COFOUNDER_MAX_INTERVAL=10
COFOUNDER_IDLE_THRESHOLD=3          # consecutive idle runs before increasing interval
COFOUNDER_MAX_ADJUSTMENTS=2         # max agents to adjust per cycle

# ── Internal state ──

declare -g -A _COFOUNDER_HEALTH_FLAGS=()   # agent_id -> "ok"|"idle"|"failing"|"overbudget"
declare -g _COFOUNDER_DAILY_COST=0         # microdollars
declare -g -a _COFOUNDER_ADJUSTMENTS=()    # log of adjustments made this cycle

# ── Logging helper ──

_cofounder_log() {
    local level="$1" msg="$2"
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$level" "cofounder" "$msg"
    else
        printf '[%s] [%s] [cofounder] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >&2
    fi
}

# =============================================================================
# orch_cofounder_review_health
#
# Reads the latest agent health data from .orchystraw/audit.jsonl and
# router-state.txt. Flags agents as idle, failing, or overbudget.
#
# Sets: _COFOUNDER_HEALTH_FLAGS associative array
# Returns: 0 on success, 1 if no data available
# =============================================================================

orch_cofounder_review_health() {
    local project_root="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    local audit_file="$project_root/.orchystraw/audit.jsonl"
    local router_state="$project_root/.orchystraw/router-state.txt"
    local conf_file="$project_root/agents.conf"

    # Fallback conf location
    [[ ! -f "$conf_file" ]] && conf_file="$project_root/scripts/agents.conf"

    _COFOUNDER_HEALTH_FLAGS=()

    # ── Parse agent list from config ──
    local -a agent_ids=()
    while IFS='|' read -r id prompt ownership interval label; do
        [[ "$id" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${id// /}" ]] && continue
        id=$(echo "$id" | xargs)
        agent_ids+=("$id")
        _COFOUNDER_HEALTH_FLAGS["$id"]="ok"
    done < "$conf_file"

    if [[ ${#agent_ids[@]} -eq 0 ]]; then
        _cofounder_log "WARN" "No agents found in config"
        return 1
    fi

    # ── Check audit.jsonl for per-agent cost and invocation counts ──
    local -A agent_invocations=()
    local -A agent_cost=()
    local -A agent_errors=()

    if [[ -f "$audit_file" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local agent="" cost="" outcome="" prev=""
            for field in $(echo "$line" | tr '{},:"' ' '); do
                case "$prev" in
                    agent) agent="$field" ;;
                    cost_estimate) cost="$field" ;;
                    outcome) outcome="$field" ;;
                esac
                prev="$field"
            done
            if [[ -n "$agent" ]]; then
                agent_invocations["$agent"]=$(( ${agent_invocations["$agent"]:-0} + 1 ))
                if [[ -n "$cost" ]]; then
                    local cost_num="${cost//[^0-9]/}"
                    cost_num="${cost_num:-0}"
                    cost_num=$(( 10#$cost_num ))
                    agent_cost["$agent"]=$(( ${agent_cost["$agent"]:-0} + cost_num ))
                fi
                if [[ "$outcome" == "error" || "$outcome" == "failed" ]]; then
                    agent_errors["$agent"]=$(( ${agent_errors["$agent"]:-0} + 1 ))
                fi
            fi
        done < "$audit_file"
    fi

    # ── Check router state for empty streaks ──
    local -A agent_empty_streak=()
    if [[ -f "$router_state" ]]; then
        while IFS='|' read -r id last_run outcome eff_interval empty_streak; do
            [[ "$id" =~ ^# ]] && continue
            [[ -z "$id" ]] && continue
            id=$(echo "$id" | xargs)
            empty_streak=$(echo "$empty_streak" | xargs)
            agent_empty_streak["$id"]="${empty_streak:-0}"
        done < "$router_state"
    fi

    # ── Compute average cost across all agents ──
    local total_cost=0
    local cost_count=0
    for id in "${agent_ids[@]}"; do
        local c="${agent_cost[$id]:-0}"
        if [[ "$c" -gt 0 ]]; then
            total_cost=$(( total_cost + c ))
            cost_count=$(( cost_count + 1 ))
        fi
    done
    local avg_cost=0
    [[ $cost_count -gt 0 ]] && avg_cost=$(( total_cost / cost_count ))

    # ── Flag each agent ──
    local flagged=0
    for id in "${agent_ids[@]}"; do
        local inv="${agent_invocations[$id]:-0}"
        local err="${agent_errors[$id]:-0}"
        local streak="${agent_empty_streak[$id]:-0}"
        local cost="${agent_cost[$id]:-0}"

        # Check for idle: empty streak exceeds threshold
        if [[ "$streak" -ge "$COFOUNDER_IDLE_THRESHOLD" ]]; then
            _COFOUNDER_HEALTH_FLAGS["$id"]="idle"
            _cofounder_log "WARN" "Agent $id flagged IDLE (empty streak: $streak)"
            flagged=$((flagged + 1))
            continue
        fi

        # Check for failing: more than half of invocations errored
        if [[ "$inv" -gt 2 && "$err" -gt $(( inv / 2 )) ]]; then
            _COFOUNDER_HEALTH_FLAGS["$id"]="failing"
            _cofounder_log "WARN" "Agent $id flagged FAILING ($err/$inv errors)"
            flagged=$((flagged + 1))
            continue
        fi

        # Check for overbudget: cost > 2x average with low output
        if [[ "$avg_cost" -gt 0 && "$cost" -gt $(( avg_cost * 2 )) ]]; then
            if [[ "$streak" -gt 0 ]]; then
                _COFOUNDER_HEALTH_FLAGS["$id"]="overbudget"
                _cofounder_log "WARN" "Agent $id flagged OVERBUDGET (cost $cost vs avg $avg_cost, streak $streak)"
                flagged=$((flagged + 1))
                continue
            fi
        fi
    done

    _cofounder_log "INFO" "Health review complete: ${#agent_ids[@]} agents, $flagged flagged"
    return 0
}

# =============================================================================
# orch_cofounder_adjust_intervals
#
# Reads _COFOUNDER_HEALTH_FLAGS and adjusts agent intervals in agents.conf.
# Idle/overbudget agents get higher intervals; productive agents get lower.
# Maximum COFOUNDER_MAX_ADJUSTMENTS changes per invocation.
#
# Returns: 0 on success, 1 if no adjustments needed
# =============================================================================

orch_cofounder_adjust_intervals() {
    local project_root="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    local conf_file="$project_root/agents.conf"
    [[ ! -f "$conf_file" ]] && conf_file="$project_root/scripts/agents.conf"

    if [[ ${#_COFOUNDER_HEALTH_FLAGS[@]} -eq 0 ]]; then
        _cofounder_log "INFO" "No health data — run orch_cofounder_review_health first"
        return 1
    fi

    _COFOUNDER_ADJUSTMENTS=()
    local adjustments_made=0
    local today
    today=$(date '+%Y-%m-%d')

    for id in "${!_COFOUNDER_HEALTH_FLAGS[@]}"; do
        [[ $adjustments_made -ge $COFOUNDER_MAX_ADJUSTMENTS ]] && break

        local flag="${_COFOUNDER_HEALTH_FLAGS[$id]}"
        [[ "$flag" == "ok" ]] && continue

        # Read current interval from conf
        local current_interval
        current_interval=$(grep -E "^${id}[[:space:]]*\|" "$conf_file" | head -1 | cut -d'|' -f4 | xargs)
        [[ -z "$current_interval" ]] && continue

        # Skip coordinator (interval 0) and self
        [[ "$current_interval" == "0" ]] && continue
        [[ "$id" == "00-cofounder" ]] && continue

        local new_interval="$current_interval"

        case "$flag" in
            idle|overbudget)
                # Increase interval (slow down)
                new_interval=$(( current_interval + 1 ))
                [[ $new_interval -gt $COFOUNDER_MAX_INTERVAL ]] && new_interval=$COFOUNDER_MAX_INTERVAL
                ;;
            failing)
                # Don't change interval for failing agents — they need investigation, not throttling
                _cofounder_log "WARN" "Agent $id is failing — investigate prompt/deps, not adjusting interval"
                continue
                ;;
        esac

        if [[ "$new_interval" != "$current_interval" ]]; then
            # Replace interval in agents.conf
            # Format: id | prompt | ownership | interval | label
            local escaped_id
            escaped_id=$(printf '%s' "$id" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
            local old_line
            old_line=$(grep -E "^${escaped_id}[[:space:]]*\|" "$conf_file" | head -1)
            if [[ -n "$old_line" ]]; then
                # Build new line by replacing the interval field
                local new_line
                new_line=$(echo "$old_line" | awk -F'|' -v new_int="$new_interval" -v date="$today" -v flag="$flag" '{
                    OFS="|"
                    # Trim and rebuild interval field
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)
                    $4 = " " new_int " "
                    # Append comment about adjustment
                    gsub(/[[:space:]]+$/, "", $5)
                    $5 = $5 " # cofounder " date ": " flag
                    print
                }')
                # Use sed to replace the line
                sed -i.bak "s|^${escaped_id}[[:space:]]*|.*|${new_line}|" "$conf_file" 2>/dev/null || {
                    # Fallback: write entire file with replacement
                    local tmp_file
                    tmp_file=$(mktemp)
                    while IFS= read -r line; do
                        if [[ "$line" =~ ^${id}[[:space:]]*\| ]]; then
                            echo "$new_line"
                        else
                            echo "$line"
                        fi
                    done < "$conf_file" > "$tmp_file"
                    mv "$tmp_file" "$conf_file"
                }
                rm -f "${conf_file}.bak"

                _COFOUNDER_ADJUSTMENTS+=("$id: $current_interval → $new_interval ($flag)")
                _cofounder_log "INFO" "Adjusted $id interval: $current_interval → $new_interval (reason: $flag)"
                adjustments_made=$((adjustments_made + 1))
            fi
        fi
    done

    if [[ $adjustments_made -eq 0 ]]; then
        _cofounder_log "INFO" "No interval adjustments needed this cycle"
        return 1
    fi

    _cofounder_log "INFO" "Made $adjustments_made interval adjustment(s) this cycle"
    return 0
}

# =============================================================================
# orch_cofounder_check_budget
#
# Reads cost data from .orchystraw/audit.jsonl, computes daily spend,
# and returns status based on thresholds.
#
# Sets: _COFOUNDER_DAILY_COST (microdollars)
# Returns: 0=ok, 1=warn, 2=high, 3=critical
# Outputs: budget status to stdout
# =============================================================================

orch_cofounder_check_budget() {
    local project_root="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    local audit_file="$project_root/.orchystraw/audit.jsonl"

    _COFOUNDER_DAILY_COST=0

    if [[ ! -f "$audit_file" ]]; then
        _cofounder_log "INFO" "No audit data — budget check skipped"
        echo "no-data"
        return 0
    fi

    # Sum cost from today's entries
    local today
    today=$(date '+%Y-%m-%d')
    local total_cost=0
    local entry_count=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Check if this entry is from today
        if [[ "$line" == *"$today"* ]]; then
            local cost="" prev=""
            for field in $(echo "$line" | tr '{},:"' ' '); do
                case "$prev" in
                    cost_estimate) cost="$field" ;;
                esac
                prev="$field"
            done
            if [[ -n "$cost" ]]; then
                local cost_num="${cost//[^0-9]/}"
                cost_num="${cost_num:-0}"
                cost_num=$(( 10#$cost_num ))
                total_cost=$(( total_cost + cost_num ))
                entry_count=$((entry_count + 1))
            fi
        fi
    done < "$audit_file"

    _COFOUNDER_DAILY_COST=$total_cost

    # Convert microdollars to display
    local dollars=$(( total_cost / 1000000 ))
    local cents=$(( (total_cost % 1000000) / 10000 ))
    local display
    display=$(printf '$%d.%02d' "$dollars" "$cents")

    if [[ $total_cost -ge $COFOUNDER_BUDGET_CRITICAL ]]; then
        _cofounder_log "ERROR" "BUDGET CRITICAL: $display today ($entry_count entries) — ESCALATING"
        echo "critical:$display"
        return 3
    elif [[ $total_cost -ge $COFOUNDER_BUDGET_HIGH ]]; then
        _cofounder_log "WARN" "BUDGET HIGH: $display today — downgrading non-critical agents"
        echo "high:$display"
        return 2
    elif [[ $total_cost -ge $COFOUNDER_BUDGET_WARN ]]; then
        _cofounder_log "WARN" "BUDGET WARNING: $display today — monitoring"
        echo "warn:$display"
        return 1
    else
        _cofounder_log "INFO" "Budget OK: $display today ($entry_count entries)"
        echo "ok:$display"
        return 0
    fi
}

# =============================================================================
# orch_cofounder_escalate
#
# Sends an escalation message to the Founder via Telegram.
# Only use for threshold-exceeding events.
#
# Arguments:
#   $1 — escalation type: budget|strategy|new-agent|failure|security
#   $2 — summary message
#
# Returns: 0 if sent, 1 if Telegram unavailable
# =============================================================================

orch_cofounder_escalate() {
    local esc_type="${1:?Usage: orch_cofounder_escalate <type> <summary>}"
    local summary="${2:?Usage: orch_cofounder_escalate <type> <summary>}"

    local message
    message=$(printf 'ORCHYSTRAW ESCALATION\nType: %s\nSummary: %s\nTime: %s\nAction needed: Review and respond' \
        "$esc_type" "$summary" "$(date '+%Y-%m-%d %H:%M')")

    _cofounder_log "WARN" "ESCALATION ($esc_type): $summary"

    # Try orch_shared_send_telegram (loaded from auto-agent.sh)
    if [[ "$(type -t orch_shared_send_telegram)" == "function" ]]; then
        orch_shared_send_telegram "$message" && return 0
    fi

    # Fallback: write to escalation file
    local project_root="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    local esc_dir="$project_root/docs/operations"
    mkdir -p "$esc_dir"
    local esc_file="$esc_dir/escalations.log"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$esc_type" "$summary" >> "$esc_file"
    _cofounder_log "INFO" "Escalation logged to $esc_file (Telegram unavailable)"
    return 1
}

# =============================================================================
# orch_cofounder_write_decision
#
# Writes a decision record to shared context for other agents to see.
#
# Arguments:
#   $1 — action description
#   $2 — rationale
#   $3 — impacted agents (comma-separated)
# =============================================================================

orch_cofounder_write_decision() {
    local action="${1:?}"
    local rationale="${2:?}"
    local impacted="${3:-all}"
    local project_root="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    local context_file="$project_root/prompts/00-shared-context/context.md"

    if [[ ! -f "$context_file" ]]; then
        _cofounder_log "WARN" "Shared context file not found: $context_file"
        return 1
    fi

    local ts
    ts=$(date '+%Y-%m-%d %H:%M')

    # Append decision block to shared context
    {
        echo ""
        echo "## [COFOUNDER] Decision — $ts"
        echo ""
        echo "**Action:** $action"
        echo "**Rationale:** $rationale"
        echo "**Impact:** $impacted"
        echo "**Reversible:** yes"
    } >> "$context_file"

    _cofounder_log "INFO" "Decision written to shared context: $action"
    return 0
}

# =============================================================================
# orch_cofounder_run — Full operational cycle
#
# Convenience function that runs all phases in sequence:
#   1. Review health
#   2. Check budget
#   3. Adjust intervals (if health flags warrant it)
#   4. Escalate if budget is critical
#   5. Document decisions
#
# Returns: 0 on success
# =============================================================================

orch_cofounder_run() {
    _cofounder_log "INFO" "=== Co-Founder operational cycle starting ==="

    # Phase 1: Health review
    orch_cofounder_review_health || true

    # Phase 2: Budget check
    local budget_status
    budget_status=$(orch_cofounder_check_budget)
    local budget_rc=$?

    # Phase 3: Interval adjustments
    orch_cofounder_adjust_intervals || true

    # Phase 4: Escalate if critical
    if [[ $budget_rc -ge 3 ]]; then
        local spend="${budget_status#*:}"
        orch_cofounder_escalate "budget" "Daily spend $spend exceeds \$50 limit"
    fi

    # Phase 5: Document
    if [[ ${#_COFOUNDER_ADJUSTMENTS[@]} -gt 0 ]]; then
        local adj_summary
        adj_summary=$(printf '%s; ' "${_COFOUNDER_ADJUSTMENTS[@]}")
        orch_cofounder_write_decision \
            "Interval adjustments: $adj_summary" \
            "Based on health review — idle/overbudget agents throttled" \
            "$(printf '%s, ' "${!_COFOUNDER_HEALTH_FLAGS[@]}")"
    fi

    _cofounder_log "INFO" "=== Co-Founder operational cycle complete ==="
    return 0
}
