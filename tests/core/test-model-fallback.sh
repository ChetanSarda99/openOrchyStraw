#!/usr/bin/env bash
# test-model-fallback.sh — Test model fallback routing in dynamic-router.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected "%s", got "%s")\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

assert_exit() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" -eq "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create minimal agents.conf
mkdir -p "$TMPDIR/scripts"
cat > "$TMPDIR/scripts/agents.conf" << 'CONF'
06-backend | prompts/06-backend.txt | scripts/ | 1 | Backend Developer
CONF

# Source the router
source "$PROJECT_ROOT/src/core/dynamic-router.sh"
orch_router_init "$TMPDIR/scripts/agents.conf"

# ── Test 1: Fallback chain ──
fb_opus=$(orch_router_model_fallback "opus")
assert_eq "opus -> sonnet" "sonnet" "$fb_opus"

fb_sonnet=$(orch_router_model_fallback "sonnet")
assert_eq "sonnet -> haiku" "haiku" "$fb_sonnet"

fb_haiku=$(orch_router_model_fallback "haiku")
assert_eq "haiku -> empty" "" "$fb_haiku"

# ── Test 2: Fallback with full flag names ──
fb_opus_flag=$(orch_router_model_fallback "claude-opus-4-6")
assert_eq "claude-opus-4-6 -> sonnet" "sonnet" "$fb_opus_flag"

fb_sonnet_flag=$(orch_router_model_fallback "claude-sonnet-4-6")
assert_eq "claude-sonnet-4-6 -> haiku" "haiku" "$fb_sonnet_flag"

# ── Test 3: Rate-limit detection ──
RATE_LOG="$TMPDIR/rate-limited.log"
echo "Error: 429 Too Many Requests - rate limit exceeded" > "$RATE_LOG"
orch_router_is_rate_limited "$RATE_LOG"
assert_exit "detects 429 rate limit" 0 $?

echo "Error: overloaded_error - model is at capacity" > "$RATE_LOG"
orch_router_is_rate_limited "$RATE_LOG"
assert_exit "detects overloaded error" 0 $?

echo "Error: quota exceeded for this billing period" > "$RATE_LOG"
orch_router_is_rate_limited "$RATE_LOG"
assert_exit "detects quota exceeded" 0 $?

# ── Test 4: Non-rate-limit errors not detected ──
NORMAL_LOG="$TMPDIR/normal-error.log"
echo "Error: invalid_request - prompt too long" > "$NORMAL_LOG"
if orch_router_is_rate_limited "$NORMAL_LOG"; then
    printf '  FAIL: false positive on normal error\n' >&2
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# ── Test 5: Empty/missing log file ──
if orch_router_is_rate_limited ""; then
    printf '  FAIL: empty path should not be rate-limited\n' >&2
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

if orch_router_is_rate_limited "$TMPDIR/nonexistent.log"; then
    printf '  FAIL: missing file should not be rate-limited\n' >&2
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# ── Test 6: orch_router_fallback_flag ──
flag_opus=$(orch_router_fallback_flag "opus")
assert_eq "opus flag" "claude-opus-4-6" "$flag_opus"

flag_sonnet=$(orch_router_fallback_flag "sonnet")
assert_eq "sonnet flag" "claude-sonnet-4-6" "$flag_sonnet"

flag_haiku=$(orch_router_fallback_flag "haiku")
assert_eq "haiku flag" "claude-haiku-4-5" "$flag_haiku"

flag_unknown=$(orch_router_fallback_flag "gpt-4o")
assert_eq "unknown model passes through" "gpt-4o" "$flag_unknown"

# ── Test 7: try_with_fallback function ──
CALL_LOG="$TMPDIR/calls.log"
> "$CALL_LOG"

# Mock command that fails with rate limit on first call, succeeds on second
ATTEMPT=0
mock_run_rate_limit() {
    local model_flag="$1"
    local log_file="$2"
    ATTEMPT=$((ATTEMPT + 1))
    echo "attempt=$ATTEMPT model=$model_flag" >> "$CALL_LOG"
    if [[ $ATTEMPT -eq 1 ]]; then
        echo "Error: 429 rate limit exceeded" > "$log_file"
        return 1
    fi
    echo "Success" > "$log_file"
    return 0
}

FALLBACK_LOG="$TMPDIR/fallback-run.log"
orch_router_try_with_fallback "06-backend" "mock_run_rate_limit" 3 "$FALLBACK_LOG"
exit_code=$?
assert_exit "try_with_fallback succeeds on second attempt" 0 "$exit_code"
assert_eq "fallback used sonnet" "sonnet" "$ORCH_FALLBACK_MODEL"

# Verify two calls were made
call_count=$(wc -l < "$CALL_LOG" | tr -d '[:space:]')
assert_eq "two attempts made" "2" "$call_count"

printf 'test-model-fallback: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
