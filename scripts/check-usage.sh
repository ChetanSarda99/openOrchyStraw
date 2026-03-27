#!/bin/bash
# ============================================
# Claude Code Usage Checker
# Parses rate_limit_event from stream-json API response
# Writes to prompts/00-shared-context/usage.txt
#
# Values written:
#   0   = allowed, under limits
#   80  = using overage (approaching limit)
#   90  = overage exhausted
#   100 = hard rate limited
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
    echo "API FAILED (exit $exit_code) — 100"
    exit 1
fi

# Extract rate_limit_event fields
rate_event=$(echo "$response" | grep "rate_limit_event")

if [ -z "$rate_event" ]; then
    # No rate event — assume OK
    echo "0" > "$USAGE_FILE"
    echo "OK — 0 (no rate event)"
    exit 0
fi

status=$(echo "$rate_event" | grep -oP '"status"\s*:\s*"\K[^"]+')
overage=$(echo "$rate_event" | grep -oP '"isUsingOverage"\s*:\s*\K(true|false)')
overage_status=$(echo "$rate_event" | grep -oP '"overageStatus"\s*:\s*"\K[^"]+')

if [ "$status" = "limited" ]; then
    echo "100" > "$USAGE_FILE"
    echo "RATE LIMITED — 100"
    exit 1
elif [ "$overage_status" = "limited" ]; then
    echo "90" > "$USAGE_FILE"
    echo "OVERAGE EXHAUSTED — 90"
    exit 1
elif [ "$overage" = "true" ]; then
    echo "80" > "$USAGE_FILE"
    echo "USING OVERAGE — 80"
    exit 0
else
    echo "0" > "$USAGE_FILE"
    echo "OK — 0 (status=$status)"
    exit 0
fi
