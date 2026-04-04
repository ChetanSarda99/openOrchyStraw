#!/usr/bin/env bash
# cycle-metrics.sh — Append one JSONL record per cycle for trending
# Called by auto-agent.sh after each cycle completes.
#
# Usage: bash scripts/cycle-metrics.sh <cycle_num> <commits> [project_root]
# Output: Appends to .orchystraw/metrics.jsonl

set -euo pipefail

CYCLE="${1:?Usage: cycle-metrics.sh <cycle_num> <commits>}"
COMMITS="${2:-0}"
PROJECT_ROOT="${3:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
METRICS_FILE="$PROJECT_ROOT/.orchystraw/metrics.jsonl"

mkdir -p "$(dirname "$METRICS_FILE")"

agents_total=0
agents_active=0
agents_skipped=0

while IFS='|' read -r id prompt ownership interval label; do
    [[ "$id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${id// /}" ]] && continue
    id=$(echo "$id" | xargs)
    interval=$(echo "$interval" | xargs)
    [[ "$interval" == "0" ]] && continue
    agents_total=$((agents_total + 1))
    if [[ $((CYCLE % interval)) -eq 0 ]] || [[ "$CYCLE" -eq 1 ]]; then
        agents_active=$((agents_active + 1))
    else
        agents_skipped=$((agents_skipped + 1))
    fi
done < "$CONF_FILE"

test_count=0
if [[ -f "$PROJECT_ROOT/tests/core/run-tests.sh" ]]; then
    test_count=$(ls "$PROJECT_ROOT/tests/core/test-"*.sh 2>/dev/null | wc -l | tr -d ' ') || test_count=0
fi

module_count=$(ls "$PROJECT_ROOT/src/core/"*.sh 2>/dev/null | wc -l | tr -d ' ') || module_count=0

issues_open="?"
if command -v gh &>/dev/null; then
    issues_open=$(gh issue list --repo ChetanSarda99/openOrchyStraw --state open --limit 200 --json number -q 'length' 2>/dev/null || echo "?")
fi

script_count=$(ls "$PROJECT_ROOT/scripts/"*.sh 2>/dev/null | wc -l | tr -d ' ') || script_count=0

printf '{"ts":"%s","cycle":%d,"commits":%d,"agents_total":%d,"agents_active":%d,"agents_skipped":%d,"tests":%d,"modules":%d,"scripts":%d,"issues_open":"%s"}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$CYCLE" "$COMMITS" "$agents_total" "$agents_active" "$agents_skipped" \
    "$test_count" "$module_count" "$script_count" "$issues_open" \
    >> "$METRICS_FILE"

echo "Metrics recorded: cycle=$CYCLE commits=$COMMITS agents=$agents_active/$agents_total tests=$test_count modules=$module_count issues=$issues_open"
