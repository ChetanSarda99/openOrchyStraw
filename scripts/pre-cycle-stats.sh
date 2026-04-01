#!/usr/bin/env bash
# pre-cycle-stats.sh — Gather stats BEFORE agents run
# Injects structured JSON into shared context so agents skip redundant git/gh calls.
#
# Usage: bash scripts/pre-cycle-stats.sh [project_root]
# Output: JSON to stdout + injects summary into shared context

set -euo pipefail

PROJECT_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
CONTEXT_FILE="$PROJECT_ROOT/prompts/00-shared-context/context.md"

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

# ── Helpers ──
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    printf '%s' "$s"
}

# ── Gather project-wide stats ──
total_open_issues="?"
build_status="unknown"
recent_activity=0

if command -v gh &>/dev/null; then
    total_open_issues=$(gh issue list --state open --limit 500 --json number -q 'length' 2>/dev/null || echo "?")
fi

recent_activity=$(git log --oneline --since="24 hours ago" 2>/dev/null | wc -l | tr -d ' ') || recent_activity=0

# Check if site builds (quick)
if [ -f "$PROJECT_ROOT/site/package.json" ]; then
    if [ -d "$PROJECT_ROOT/site/node_modules" ]; then
        build_status="ready"
    else
        build_status="deps-missing"
    fi
else
    build_status="n/a"
fi

# ── Per-agent stats ──
printf '{\n'
printf '  "generated": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '  "project": {\n'
printf '    "open_issues": %s,\n' "${total_open_issues//[!0-9?]/}"
printf '    "recent_commits_24h": %d,\n' "$recent_activity"
printf '    "build_status": "%s"\n' "$build_status"
printf '  },\n'
printf '  "agents": {\n'

first=true
for id in "${AGENT_IDS[@]}"; do
    $first || printf ',\n'
    first=false

    # Recent commits in owned paths
    IFS=' ' read -ra paths <<< "${AGENT_OWNERSHIP[$id]}"
    commits_7d=0
    last_commit_date="never"
    for path in "${paths[@]}"; do
        [[ "$path" == !* ]] && continue
        [ -d "$PROJECT_ROOT/$path" ] || [ -f "$PROJECT_ROOT/$path" ] || continue
        c=$(git -C "$PROJECT_ROOT" log --oneline --since="7 days ago" -- "$path" 2>/dev/null | wc -l | tr -d ' ') || c=0
        commits_7d=$((commits_7d + c))
    done

    # Last commit date in owned paths
    for path in "${paths[@]}"; do
        [[ "$path" == !* ]] && continue
        d=$(git -C "$PROJECT_ROOT" log -1 --format='%ci' -- "$path" 2>/dev/null || true)
        if [ -n "$d" ]; then
            last_commit_date="$d"
            break
        fi
    done

    # Open issues assigned (by agent label in title/body)
    open_assigned=0
    if command -v gh &>/dev/null; then
        open_assigned=$(gh issue list --state open --search "$id" --limit 50 --json number -q 'length' 2>/dev/null || echo 0)
    fi

    printf '    "%s": {\n' "$id"
    printf '      "label": "%s",\n' "$(json_escape "${AGENT_LABELS[$id]}")"
    printf '      "interval": %s,\n' "${AGENT_INTERVALS[$id]}"
    printf '      "commits_7d": %d,\n' "$commits_7d"
    printf '      "last_commit": "%s",\n' "$(json_escape "$last_commit_date")"
    printf '      "open_issues": %d\n' "$open_assigned"
    printf '    }'
done

printf '\n  }\n'
printf '}\n'
