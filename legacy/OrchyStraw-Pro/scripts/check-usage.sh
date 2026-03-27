#!/bin/bash
# ============================================
# Multi-Model Usage Checker
# Checks rate limits for Claude, Codex, and Gemini CLIs
# Writes per-model status to prompts/00-shared-context/usage.txt
#
# Values written (per model):
#   0   = allowed, under limits
#   80  = using overage / approaching limit
#   90  = overage exhausted / near limit
#   100 = hard rate limited / unavailable
#
# Output format in usage.txt:
#   claude=0
#   codex=0
#   gemini=0
#   overall=0  (max of all three)
#
# Called by: auto-agent.sh (before each cycle)
# Read by:  auto-agent.sh, all agents via shared context
# ============================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USAGE_FILE="$PROJECT_ROOT/prompts/00-shared-context/usage.txt"

mkdir -p "$(dirname "$USAGE_FILE")"

CLAUDE_STATUS=0
CODEX_STATUS=0
GEMINI_STATUS=0

# ── Claude ──────────────────────────────────────────────────────────────
check_claude() {
    local response
    response=$(echo "Reply OK" | claude -p --max-turns 1 --output-format stream-json --verbose 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        CLAUDE_STATUS=100
        echo "  Claude: API FAILED (exit $exit_code) — 100"
        return
    fi

    local rate_event
    rate_event=$(echo "$response" | grep "rate_limit_event")

    if [ -z "$rate_event" ]; then
        CLAUDE_STATUS=0
        echo "  Claude: OK — 0 (no rate event)"
        return
    fi

    local status overage overage_status
    status=$(echo "$rate_event" | grep -oP '"status"\s*:\s*"\K[^"]+')
    overage=$(echo "$rate_event" | grep -oP '"isUsingOverage"\s*:\s*\K(true|false)')
    overage_status=$(echo "$rate_event" | grep -oP '"overageStatus"\s*:\s*"\K[^"]+')

    if [ "$status" = "limited" ]; then
        CLAUDE_STATUS=100
        echo "  Claude: RATE LIMITED — 100"
    elif [ "$overage_status" = "limited" ]; then
        CLAUDE_STATUS=90
        echo "  Claude: OVERAGE EXHAUSTED — 90"
    elif [ "$overage" = "true" ]; then
        CLAUDE_STATUS=80
        echo "  Claude: USING OVERAGE — 80"
    else
        CLAUDE_STATUS=0
        echo "  Claude: OK — 0 (status=$status)"
    fi
}

# ── Codex ───────────────────────────────────────────────────────────────
check_codex() {
    local response
    response=$(codex exec -m gpt-5.4 --full-auto "Reply with just the word OK" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        # Check if it's a rate limit error
        if echo "$response" | grep -qi "rate.limit\|429\|quota\|too many"; then
            CODEX_STATUS=100
            echo "  Codex: RATE LIMITED — 100"
        else
            CODEX_STATUS=100
            echo "  Codex: FAILED (exit $exit_code) — 100"
        fi
        return
    fi

    # Codex doesn't expose granular rate limit events like Claude
    # Check response for rate limit warnings
    if echo "$response" | grep -qi "rate.limit\|throttl\|429"; then
        CODEX_STATUS=80
        echo "  Codex: RATE WARNING — 80"
    else
        CODEX_STATUS=0
        echo "  Codex: OK — 0"
    fi
}

# ── Gemini ──────────────────────────────────────────────────────────────
check_gemini() {
    local response
    response=$(echo "Reply with just the word OK" | gemini --model gemini-3.1-pro-preview -p - 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        # Check specific Gemini error types
        if echo "$response" | grep -qi "RESOURCE_EXHAUSTED\|429\|quota\|rate.limit"; then
            GEMINI_STATUS=100
            echo "  Gemini: RATE LIMITED — 100"
        elif echo "$response" | grep -qi "ModelNotFound\|not found"; then
            GEMINI_STATUS=90
            echo "  Gemini: MODEL UNAVAILABLE — 90"
        else
            GEMINI_STATUS=100
            echo "  Gemini: FAILED (exit $exit_code) — 100"
        fi
        return
    fi

    # Check for quota warnings in response
    if echo "$response" | grep -qi "quota\|rate.limit\|RESOURCE_EXHAUSTED"; then
        GEMINI_STATUS=80
        echo "  Gemini: RATE WARNING — 80"
    else
        GEMINI_STATUS=0
        echo "  Gemini: OK — 0"
    fi
}

# ── Run all checks ─────────────────────────────────────────────────────
echo "Checking model availability..."

check_claude
check_codex
check_gemini

# Calculate overall (worst status wins)
OVERALL=$CLAUDE_STATUS
[ $CODEX_STATUS -gt $OVERALL ] && OVERALL=$CODEX_STATUS
[ $GEMINI_STATUS -gt $OVERALL ] && OVERALL=$GEMINI_STATUS

# Write results
cat > "$USAGE_FILE" <<EOF
claude=$CLAUDE_STATUS
codex=$CODEX_STATUS
gemini=$GEMINI_STATUS
overall=$OVERALL
EOF

echo ""
echo "Results: claude=$CLAUDE_STATUS codex=$CODEX_STATUS gemini=$GEMINI_STATUS overall=$OVERALL"
echo "Written to: $USAGE_FILE"

# Exit with error if ALL models are unavailable
if [ $CLAUDE_STATUS -ge 100 ] && [ $CODEX_STATUS -ge 100 ] && [ $GEMINI_STATUS -ge 100 ]; then
    echo "ERROR: All models unavailable!"
    exit 1
fi

exit 0
