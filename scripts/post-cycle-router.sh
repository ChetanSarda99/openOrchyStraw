#!/usr/bin/env bash
# post-cycle-router.sh — Wire dynamic-router interval adjustment after each cycle
# Calls orch_router_update for each agent based on commit activity, then saves state.
#
# Usage: bash scripts/post-cycle-router.sh <cycle_num> [project_root]
# Requires: src/core/dynamic-router.sh, src/core/logger.sh sourced

set -uo pipefail

CYCLE_NUM="${1:?Usage: post-cycle-router.sh <cycle_num> [project_root]}"
PROJECT_ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
STATE_DIR="$PROJECT_ROOT/.orchystraw"
STATE_FILE="$STATE_DIR/router-state.txt"

# Source required modules
for mod in logger dynamic-router; do
    if [ -f "$PROJECT_ROOT/src/core/${mod}.sh" ]; then
        source "$PROJECT_ROOT/src/core/${mod}.sh"
    else
        echo "ERROR: Required module not found: src/core/${mod}.sh" >&2
        exit 1
    fi
done

# Init logger (quiet mode — this is a background script)
ORCH_QUIET=1
if [[ "$(type -t orch_log_init)" == "function" ]]; then
    orch_log_init "$PROJECT_ROOT/logs" 2>/dev/null || true
fi

# Init router from agents.conf
orch_router_init "$CONF_FILE"

# Load previous state if exists
if [ -f "$STATE_FILE" ]; then
    orch_router_load_state "$STATE_FILE"
fi

# ── Parse agents.conf for ownership ──
declare -A AGENT_OWNERSHIP=()

while IFS='|' read -r id prompt ownership interval label; do
    [[ "$id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${id// /}" ]] && continue
    id=$(echo "$id" | xargs)
    ownership=$(echo "$ownership" | xargs)
    AGENT_OWNERSHIP["$id"]="$ownership"
done < "$CONF_FILE"

# ── Determine outcome for each agent ──
echo "# Post-Cycle Router Adjustment — Cycle $CYCLE_NUM"
echo "> $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
    ownership="${AGENT_OWNERSHIP[$id]:-}"
    [[ -z "$ownership" ]] && continue

    # Check if agent produced changes in owned paths
    IFS=' ' read -ra paths <<< "$ownership"
    local_include=()
    for path in "${paths[@]}"; do
        [[ "$path" == !* ]] && continue
        local_include+=("$path")
    done

    outcome="skip"
    if [[ ${#local_include[@]} -gt 0 ]]; then
        changes=$(git -C "$PROJECT_ROOT" diff --name-only HEAD~1..HEAD -- "${local_include[@]}" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$changes" -gt 0 ]]; then
            outcome="success"
        fi
    fi

    # Check agent log for errors
    log_dir="$PROJECT_ROOT/prompts/$id/logs"
    if [ -d "$log_dir" ]; then
        latest_log=$(ls -t "$log_dir/"*.log 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            log_size=$(wc -c < "$latest_log" 2>/dev/null || echo 0)
            if [[ "$log_size" -lt 100 ]]; then
                outcome="fail"
            else
                errors=$(grep -c -i "fatal\|panic\|traceback" "$latest_log" 2>/dev/null) || errors=0
                [[ "$errors" -gt 0 ]] && outcome="fail"
            fi
        fi
    fi

    prev_interval="${_ORCH_ROUTER_EFF_INTERVAL[$id]:-${_ORCH_ROUTER_INTERVAL[$id]:-1}}"
    orch_router_update "$id" "$outcome" "$CYCLE_NUM"
    new_interval="${_ORCH_ROUTER_EFF_INTERVAL[$id]:-${_ORCH_ROUTER_INTERVAL[$id]:-1}}"

    change=""
    if [[ "$new_interval" != "$prev_interval" ]]; then
        change=" (interval: $prev_interval → $new_interval)"
    fi

    echo "- $id: $outcome$change"
done

# ── Save state ──
mkdir -p "$STATE_DIR"
orch_router_save_state "$STATE_FILE"
echo ""
echo "State saved to $STATE_FILE"
