#!/bin/bash
# ============================================
# Claude Code Usage Checker
# Parses rate_limit_event from stream-json API response
# Writes to prompts/00-shared-context/usage.txt
#
# Values written: 0–100 (percent used)
# Exit codes: 0=ok, 1=warning (70%+), 2=blocked (90%+)
#
# Called by: auto-agent.sh (before each cycle)
# Read by:  auto-agent.sh, all agents via shared context
# ============================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USAGE_FILE="$PROJECT_ROOT/prompts/00-shared-context/usage.txt"

mkdir -p "$(dirname "$USAGE_FILE")"

# Tiny API call — capture stream-json for rate_limit_event
response=$(echo "Reply OK" | claude -p --max-turns 1 --output-format stream-json --verbose 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "100" > "$USAGE_FILE"
    echo "BLOCKED — 100 (API failed, exit $exit_code)"
    exit 2
fi

# Extract rate_limit_event fields
rate_event=$(echo "$response" | grep "rate_limit_event")

if [ -z "$rate_event" ]; then
    echo "0" > "$USAGE_FILE"
    echo "OK — 0 (no rate event)"
    exit 0
fi

status=$(echo "$rate_event" | grep -oP '"status"\s*:\s*"\K[^"]+')
overage=$(echo "$rate_event" | grep -oP '"isUsingOverage"\s*:\s*\K(true|false)')
overage_status=$(echo "$rate_event" | grep -oP '"overageStatus"\s*:\s*"\K[^"]+')
percent_used=$(echo "$rate_event" | grep -oP '"percentUsed"\s*:\s*\K[0-9.]+')

if [ "$status" = "limited" ]; then
    echo "100" > "$USAGE_FILE"
    echo "BLOCKED — 100 (rate limited)"
    exit 2
fi

if [ "$overage_status" = "limited" ]; then
    echo "95" > "$USAGE_FILE"
    echo "BLOCKED — 95 (overage exhausted)"
    exit 2
fi

usage=0
if [ -n "$percent_used" ]; then
    usage=$(printf "%.0f" "$percent_used")
elif [ "$overage" = "true" ]; then
    usage=85
fi

echo "$usage" > "$USAGE_FILE"

if [ "$usage" -ge 90 ]; then
    echo "BLOCKED — $usage"
    exit 2
elif [ "$usage" -ge 70 ]; then
    echo "WARNING — $usage"
    exit 1
else
    echo "OK — $usage"
    exit 0
fi
