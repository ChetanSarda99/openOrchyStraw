#!/usr/bin/env bash
# agent-health-report.sh — Track agent efficiency over time
# Analyzes last N cycles of agent logs + git history to identify idle/overloaded agents.
#
# Usage: bash scripts/agent-health-report.sh [cycles=10] [project_root]
# Output: Markdown report to stdout

set -uo pipefail

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
    commits=$(git -C "$PROJECT_ROOT" log --oneline --all --grep="feat($id)" -n 100 2>/dev/null | wc -l | tr -d ' ')

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
            errors=$(grep -c -iE "error|fatal|panic|exception" "$logfile" 2>/dev/null | tr -d '[:space:]')
            errors="${errors:-0}"
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

# ── Consistency check ──
echo "## Consistency"
echo ""

orphan_prompts=0
for id in "${AGENT_IDS[@]}"; do
    prompt_path=$(grep "^${id}" "$CONF_FILE" 2>/dev/null | head -1 | cut -d'|' -f2 | xargs)
    if [ -n "$prompt_path" ] && [ ! -f "$PROJECT_ROOT/$prompt_path" ]; then
        echo "- **MISSING PROMPT:** $id → $prompt_path"
        orphan_prompts=$((orphan_prompts + 1))
    fi
done

if [[ $orphan_prompts -eq 0 ]]; then
    echo "- All agent prompts exist"
fi
