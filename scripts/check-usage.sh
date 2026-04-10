#!/usr/bin/env bash
# ============================================
# Claude Code Usage Checker
# Parses rate_limit_event from stream-json API response
# Writes to prompts/00-shared-context/usage.txt
#
# Values written: 0–100 (percent used)
# Exit codes: 0=ok, 1=warning (70%+), 2=blocked (90%+)
#
# Caches result for 5 minutes to avoid wasting API calls.
# Called by: auto-agent.sh (before each cycle)
# ============================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
USAGE_FILE="$PROJECT_ROOT/prompts/00-shared-context/usage.txt"
CACHE_FILE="$PROJECT_ROOT/.orchystraw/usage-cache"
CACHE_TTL=300  # 5 minutes

mkdir -p "$(dirname "$USAGE_FILE")" "$PROJECT_ROOT/.orchystraw"

# ── Check cache first ──
if [[ -f "$CACHE_FILE" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [[ "$cache_age" -lt "$CACHE_TTL" ]]; then
        # Cache is fresh — use cached value
        cached=$(cat "$CACHE_FILE")
        cp "$CACHE_FILE" "$USAGE_FILE" 2>/dev/null
        usage=$(grep -o '[0-9]*' "$CACHE_FILE" | head -1)
        usage="${usage:-0}"
        if [[ "$usage" -ge 90 ]]; then
            echo "BLOCKED — $usage (cached)"
            exit 2
        elif [[ "$usage" -ge 70 ]]; then
            echo "WARNING — $usage (cached)"
            exit 1
        else
            echo "OK — $usage (cached)"
            exit 0
        fi
    fi
fi

# ── Fresh check via Claude CLI ──
if ! command -v claude &>/dev/null; then
    echo "0" > "$USAGE_FILE"
    echo "0" > "$CACHE_FILE"
    echo "OK — 0 (claude CLI not found, skipping check)"
    exit 0
fi

response=$(echo "Reply OK" | claude -p --max-turns 1 --output-format stream-json --verbose 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "100" > "$USAGE_FILE"
    echo "100" > "$CACHE_FILE"
    echo "BLOCKED — 100 (API failed, exit $exit_code)"
    exit 2
fi

# Extract rate_limit_event fields (macOS-compatible, no grep -P)
rate_event=$(echo "$response" | grep "rate_limit_event")

if [ -z "$rate_event" ]; then
    echo "0" > "$USAGE_FILE"
    echo "0" > "$CACHE_FILE"
    echo "OK — 0 (no rate event)"
    exit 0
fi

status=$(echo "$rate_event" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
overage=$(echo "$rate_event" | sed -n 's/.*"isUsingOverage"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p')
overage_status=$(echo "$rate_event" | sed -n 's/.*"overageStatus"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
percent_used=$(echo "$rate_event" | sed -n 's/.*"percentUsed"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p')

if [ "$status" = "limited" ]; then
    echo "100" > "$USAGE_FILE"
    echo "100" > "$CACHE_FILE"
    echo "BLOCKED — 100 (rate limited)"
    exit 2
fi

if [ "$overage_status" = "limited" ]; then
    echo "95" > "$USAGE_FILE"
    echo "95" > "$CACHE_FILE"
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
echo "$usage" > "$CACHE_FILE"

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
