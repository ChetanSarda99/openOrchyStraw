#!/usr/bin/env bash
# agent-health-report.sh — Track agent efficiency over time
# Analyzes last N cycles of agent logs + git history to identify idle/overloaded agents.
#
# Usage: bash scripts/agent-health-report.sh [cycles=10] [project_root]
# Output: Markdown report to stdout

set -euo pipefail

LOOKBACK="${1:-10}"
PROJECT_ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
PROMPTS_DIR="$PROJECT_ROOT/prompts"
STATE_FILE="$PROJECT_ROOT/.orchystraw/router-state.txt"

# ── Parse agents.conf ──
declare -a AGENT_IDS=()
declare -A AGENT_OWNERSHIP=()
declare -A AGENT_LABELS=()
declare -A AGENT_INTERVALS=()

while IFS='|' read -r id prompt ownership interval label; do
    [[ "$id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${id// /}" ]] && continue
    id=$(echo "$id" | xargs)
    ownership=$(echo "$ownership" | xargs)
    label=$(echo "$label" | xargs)
    interval=$(echo "$interval" | xargs)
    AGENT_IDS+=("$id")
    AGENT_OWNERSHIP["$id"]="$ownership"
    AGENT_LABELS["$id"]="$label"
    AGENT_INTERVALS["$id"]="$interval"
done < "$CONF_FILE"

AUDIT_FILE="$PROJECT_ROOT/.orchystraw/audit.jsonl"

declare -A AUDIT_INVOCATIONS=()
declare -A AUDIT_DURATION=()
declare -A AUDIT_TOKENS=()
declare -A AUDIT_COST=()
declare -A AUDIT_MODEL=()

if [[ -f "$AUDIT_FILE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        agent=""
        dur=0
        tok=0
        cost=""
        model=""
        prev=""
        for field in $(echo "$line" | tr '{},:"' ' '); do
            case "$prev" in
                agent) agent="$field" ;;
                duration_s) dur="$field" ;;
                tokens_est) tok="$field" ;;
                cost_estimate) cost="$field" ;;
                model) model="$field" ;;
            esac
            prev="$field"
        done
        if [[ -n "$agent" ]]; then
            AUDIT_INVOCATIONS["$agent"]=$(( ${AUDIT_INVOCATIONS["$agent"]:-0} + 1 ))
            AUDIT_DURATION["$agent"]=$(( ${AUDIT_DURATION["$agent"]:-0} + dur ))
            AUDIT_TOKENS["$agent"]=$(( ${AUDIT_TOKENS["$agent"]:-0} + tok ))
            # Accumulate cost (strip leading 0. and treat as microdollars)
            if [[ -n "$cost" ]]; then
                cost_num="${cost//[^0-9]/}"
                cost_num="${cost_num:-0}"
                # Remove leading zeros for arithmetic
                cost_num=$(( 10#$cost_num ))
                AUDIT_COST["$agent"]=$(( ${AUDIT_COST["$agent"]:-0} + cost_num ))
            fi
            [[ -n "$model" ]] && AUDIT_MODEL["$agent"]="$model"
        fi
    done < "$AUDIT_FILE"
fi

echo "# Agent Health Report"
echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S') | Lookback: $LOOKBACK cycles"
echo ""

echo "## Efficiency Matrix"
echo ""
echo "| Agent | Label | Interval | Runs (est) | Commits | Avg Output (KB) | Success Rate | Status |"
echo "|-------|-------|----------|------------|---------|-----------------|--------------|--------|"

declare -A RECOMMENDATIONS=()

for id in "${AGENT_IDS[@]}"; do
    interval="${AGENT_INTERVALS[$id]}"
    label="${AGENT_LABELS[$id]}"

    # Estimate runs in lookback window
    if [[ "$interval" -eq 0 ]]; then
        est_runs="$LOOKBACK"
    elif [[ "$interval" -gt 0 ]]; then
        est_runs=$(( LOOKBACK / interval ))
        [[ $est_runs -eq 0 ]] && est_runs=1
    else
        est_runs=0
    fi

    # Count commits by this agent
    commits=$(git -C "$PROJECT_ROOT" log --oneline --all --grep="feat($id)" -n 100 2>/dev/null | wc -l | tr -d ' ') || commits=0

    # Analyze logs
    log_dir="$PROMPTS_DIR/$id/logs"
    total_size=0
    log_count=0
    error_count=0
    success_count=0

    if [ -d "$log_dir" ]; then
        while IFS= read -r logfile; do
            [ -z "$logfile" ] && continue
            log_count=$((log_count + 1))
            size=$(wc -c < "$logfile" 2>/dev/null | tr -d '[:space:]')
            size="${size:-0}"
            total_size=$((total_size + size))
            errors=$(grep -c -iE "error|fatal|panic|exception" "$logfile" 2>/dev/null | tr -d '[:space:]') || errors=0
            if [[ "$errors" -gt 0 ]]; then
                error_count=$((error_count + 1))
            else
                success_count=$((success_count + 1))
            fi
        done < <(ls -t "$log_dir/"*.log 2>/dev/null | head -"$LOOKBACK")
    fi

    # Avg output size in KB
    avg_kb=0
    if [[ $log_count -gt 0 ]]; then
        avg_kb=$(( total_size / log_count / 1024 ))
    fi

    # Success rate
    success_rate="—"
    if [[ $log_count -gt 0 ]]; then
        success_rate="$(( success_count * 100 / log_count ))%"
    fi

    # Determine status + recommendation
    status="OK"
    rec=""
    if [[ $commits -eq 0 && $log_count -ge 3 ]]; then
        status="**IDLE**"
        rec="INCREASE interval (currently $interval) — $log_count runs, 0 commits"
    elif [[ $log_count -gt 0 && $error_count -gt $(( log_count / 2 )) ]]; then
        status="**FAILING**"
        rec="CHECK prompt/deps — $error_count/$log_count runs had errors"
    elif [[ $commits -gt $(( est_runs * 2 )) ]]; then
        status="**ACTIVE**"
        rec="CONSIDER decreasing interval (currently $interval) — high output"
    fi

    echo "| $id | $label | $interval | $est_runs | $commits | $avg_kb | $success_rate | $status |"

    [[ -n "$rec" ]] && RECOMMENDATIONS["$id"]="$rec"
done

echo ""

# ── Router state (if available) ──
if [ -f "$STATE_FILE" ]; then
    echo "## Router State"
    echo ""
    echo "| Agent | Last Run | Last Outcome | Eff. Interval | Empty Streak |"
    echo "|-------|----------|-------------|---------------|--------------|"
    while IFS='|' read -r id last_run outcome eff_interval empty_streak; do
        [[ "$id" =~ ^# ]] && continue
        [[ -z "$id" ]] && continue
        echo "| $id | $last_run | $outcome | $eff_interval | $empty_streak |"
    done < "$STATE_FILE"
    echo ""
fi

# ── Recommendations ──
echo "## Recommendations"
echo ""

if [[ ${#RECOMMENDATIONS[@]} -eq 0 ]]; then
    echo "- All agents within normal parameters"
else
    for id in "${!RECOMMENDATIONS[@]}"; do
        echo "- **$id:** ${RECOMMENDATIONS[$id]}"
    done
fi
echo ""

# ── Cost Tracking (from audit.jsonl) ──
echo "## Cost Tracking"
echo ""

if [[ ${#AUDIT_INVOCATIONS[@]} -eq 0 ]]; then
    echo "- No audit data available (run cycles to populate .orchystraw/audit.jsonl)"
else
    echo "| Agent | Model | Invocations | Wall-Clock (s) | Est. Tokens | Avg Tokens/Run | Est. Cost |"
    echo "|-------|-------|------------|----------------|-------------|----------------|-----------|"
    total_cost=0
    for id in "${AGENT_IDS[@]}"; do
        inv="${AUDIT_INVOCATIONS[$id]:-0}"
        dur="${AUDIT_DURATION[$id]:-0}"
        tok="${AUDIT_TOKENS[$id]:-0}"
        cost_micro="${AUDIT_COST[$id]:-0}"
        model="${AUDIT_MODEL[$id]:-—}"
        avg_tok=0
        if [[ $inv -gt 0 ]]; then
            avg_tok=$(( tok / inv ))
        fi
        cost_display="\$0.$(printf '%06d' "$cost_micro")"
        total_cost=$(( total_cost + cost_micro ))
        echo "| $id | $model | $inv | $dur | $tok | $avg_tok | $cost_display |"
    done
    echo ""
    echo "**Total estimated cost:** \$0.$(printf '%06d' "$total_cost")"
fi
echo ""

# ── Consistency check ──
echo "## Consistency"
echo ""

orphan_prompts=0
for id in "${AGENT_IDS[@]}"; do
    prompt_path=$(grep "^${id}" "$CONF_FILE" 2>/dev/null | head -1 | cut -d'|' -f2 | xargs) || prompt_path=""
    if [ -n "$prompt_path" ] && [ ! -f "$PROJECT_ROOT/$prompt_path" ]; then
        echo "- **MISSING PROMPT:** $id → $prompt_path"
        orphan_prompts=$((orphan_prompts + 1))
    fi
done

if [[ $orphan_prompts -eq 0 ]]; then
    echo "- All agent prompts exist"
fi

# ── Trend Analysis (compare last 5 cycles) ──
echo ""
echo "## Trend Analysis (Last 5 Cycles)"
echo ""

METRICS_FILE="$PROJECT_ROOT/.orchystraw/metrics.jsonl"
if [[ -f "$METRICS_FILE" ]]; then
    declare -a TREND_CYCLES=()
    declare -a TREND_COMMITS=()
    declare -a TREND_ISSUES=()
    declare -a TREND_TS=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        cycle=0 commits=0 issues=0 ts=""
        prev=""
        for field in $(echo "$line" | tr '{},:"' ' '); do
            case "$prev" in
                cycle) cycle="$field" ;;
                commits) commits="$field" ;;
                issues_open) issues="$field" ;;
                ts) ts="$field" ;;
            esac
            prev="$field"
        done
        TREND_CYCLES+=("$cycle")
        TREND_COMMITS+=("$commits")
        TREND_ISSUES+=("${issues//[^0-9]/}")
        TREND_TS+=("$ts")
    done < "$METRICS_FILE"

    total_entries=${#TREND_CYCLES[@]}
    start_idx=0
    if [[ $total_entries -gt 5 ]]; then
        start_idx=$((total_entries - 5))
    fi

    if [[ $total_entries -ge 2 ]]; then
        echo "| Cycle | Commits | Issues | Trend (Commits) | Trend (Issues) |"
        echo "|-------|---------|--------|-----------------|----------------|"

        prev_commits=0
        prev_issues=0
        first=true
        for (( i=start_idx; i<total_entries; i++ )); do
            c="${TREND_CYCLES[$i]}"
            cm="${TREND_COMMITS[$i]}"
            is="${TREND_ISSUES[$i]:-0}"
            cm="${cm:-0}"
            is="${is:-0}"

            commit_trend="—"
            issue_trend="—"
            if [[ "$first" == false ]]; then
                if [[ "$cm" -gt "$prev_commits" ]]; then
                    commit_trend="**UP** (+$((cm - prev_commits)))"
                elif [[ "$cm" -lt "$prev_commits" ]]; then
                    commit_trend="DOWN (-$((prev_commits - cm)))"
                else
                    commit_trend="FLAT"
                fi
                if [[ "$is" -gt "$prev_issues" ]]; then
                    issue_trend="**UP** (+$((is - prev_issues)))"
                elif [[ "$is" -lt "$prev_issues" ]]; then
                    issue_trend="DOWN (-$((prev_issues - is)))"
                else
                    issue_trend="FLAT"
                fi
            fi
            first=false
            prev_commits="$cm"
            prev_issues="$is"
            echo "| $c | $cm | $is | $commit_trend | $issue_trend |"
        done
        echo ""

        # Summary stats
        sum_commits=0
        sum_issues=0
        count=0
        for (( i=start_idx; i<total_entries; i++ )); do
            cm="${TREND_COMMITS[$i]:-0}"
            is="${TREND_ISSUES[$i]:-0}"
            sum_commits=$((sum_commits + cm))
            sum_issues=$((sum_issues + is))
            count=$((count + 1))
        done
        if [[ $count -gt 0 ]]; then
            avg_commits=$((sum_commits / count))
            avg_issues=$((sum_issues / count))
            echo "**5-cycle averages:** $avg_commits commits/cycle, $avg_issues open issues/cycle"
        fi

        # Velocity direction
        oldest_commits="${TREND_COMMITS[$start_idx]:-0}"
        newest_commits="${TREND_COMMITS[$((total_entries - 1))]:-0}"
        if [[ "$newest_commits" -gt "$oldest_commits" ]]; then
            echo ""
            echo "**Velocity: ACCELERATING** — commit rate increasing over last 5 cycles"
        elif [[ "$newest_commits" -lt "$oldest_commits" ]]; then
            echo ""
            echo "**Velocity: DECELERATING** — commit rate decreasing (check agent health)"
        else
            echo ""
            echo "**Velocity: STABLE** — commit rate consistent"
        fi
    else
        echo "- Not enough cycle data for trend analysis (need >= 2 cycles)"
    fi
else
    echo "- No metrics data available (run cycles to populate .orchystraw/metrics.jsonl)"
fi
