#!/usr/bin/env bash
# =============================================================================
# usage-checker.sh — Model usage/rate-limit checker for OrchyStraw
#
# Replaces scripts/check-usage.sh with a sourceable module.
# Fixes #73: 70% threshold didn't prevent hitting 98%.
#
# Changes from old check-usage.sh:
#   - Pause threshold lowered from 90 → 80 (catch overages early)
#   - Added graduated backoff: 80=30s, 90=120s, 100=300s
#   - Replaced non-portable grep -oP with POSIX-compatible grep -o + sed
#   - Sourceable module (double-source guarded)
#   - Returns backoff duration for the orchestrator to sleep
#
# Usage:
#   source src/core/usage-checker.sh
#   orch_check_usage                    # writes usage.txt, prints results
#   orch_get_backoff_seconds            # returns recommended sleep time (0=none)
#   orch_should_pause                   # returns 0 if cycle should be paused
#   orch_model_status "claude"          # returns status for a specific model
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_USAGE_CHECKER_LOADED:-}" ]] && return 0
readonly _ORCH_USAGE_CHECKER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_MODEL_STATUS=()
declare -g  _ORCH_USAGE_BACKOFF=0

# Thresholds (configurable via env)
declare -g _ORCH_PAUSE_THRESHOLD="${ORCH_PAUSE_THRESHOLD:-80}"
declare -g _ORCH_WARN_THRESHOLD="${ORCH_WARN_THRESHOLD:-70}"

# ---------------------------------------------------------------------------
# Portable JSON-ish field extraction (replaces grep -oP)
# Extracts value for a given key from a JSON-like string.
# Usage: _orch_extract_field "key" "$json_string"
# ---------------------------------------------------------------------------
_orch_extract_field() {
    local key="$1"
    local text="$2"
    # Match "key": "value" or "key": true/false/number
    echo "$text" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//'
}

_orch_extract_bool() {
    local key="$1"
    local text="$2"
    echo "$text" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[a-z]*" | head -1 | sed 's/.*:[[:space:]]*//'
}

# ---------------------------------------------------------------------------
# check_claude — probe Claude CLI for rate limit status
# ---------------------------------------------------------------------------
_orch_check_claude() {
    local response exit_code
    response=$(echo "Reply OK" | claude -p --max-turns 1 --output-format stream-json --verbose 2>&1) || true
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        _ORCH_MODEL_STATUS[claude]=100
        return
    fi

    local rate_event
    rate_event=$(echo "$response" | grep "rate_limit_event" || true)

    if [[ -z "$rate_event" ]]; then
        _ORCH_MODEL_STATUS[claude]=0
        return
    fi

    local status overage overage_status
    status=$(_orch_extract_field "status" "$rate_event")
    overage=$(_orch_extract_bool "isUsingOverage" "$rate_event")
    overage_status=$(_orch_extract_field "overageStatus" "$rate_event")

    if [[ "$status" == "limited" ]]; then
        _ORCH_MODEL_STATUS[claude]=100
    elif [[ "$overage_status" == "limited" ]]; then
        _ORCH_MODEL_STATUS[claude]=90
    elif [[ "$overage" == "true" ]]; then
        _ORCH_MODEL_STATUS[claude]=80
    else
        _ORCH_MODEL_STATUS[claude]=0
    fi
}

# ---------------------------------------------------------------------------
# check_codex — probe Codex CLI for rate limit status
# ---------------------------------------------------------------------------
_orch_check_codex() {
    local response exit_code
    response=$(codex exec -m gpt-5.4 --full-auto "Reply with just the word OK" 2>&1) || true
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        if echo "$response" | grep -qi "rate.limit\|429\|quota\|too many"; then
            _ORCH_MODEL_STATUS[codex]=100
        else
            _ORCH_MODEL_STATUS[codex]=100
        fi
        return
    fi

    if echo "$response" | grep -qi "rate.limit\|throttl\|429"; then
        _ORCH_MODEL_STATUS[codex]=80
    else
        _ORCH_MODEL_STATUS[codex]=0
    fi
}

# ---------------------------------------------------------------------------
# check_gemini — probe Gemini CLI for rate limit status
# ---------------------------------------------------------------------------
_orch_check_gemini() {
    local response exit_code
    response=$(echo "Reply with just the word OK" | gemini --model gemini-3.1-pro-preview -p - 2>&1) || true
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        if echo "$response" | grep -qi "RESOURCE_EXHAUSTED\|429\|quota\|rate.limit"; then
            _ORCH_MODEL_STATUS[gemini]=100
        elif echo "$response" | grep -qi "ModelNotFound\|not found"; then
            _ORCH_MODEL_STATUS[gemini]=90
        else
            _ORCH_MODEL_STATUS[gemini]=100
        fi
        return
    fi

    if echo "$response" | grep -qi "quota\|rate.limit\|RESOURCE_EXHAUSTED"; then
        _ORCH_MODEL_STATUS[gemini]=80
    else
        _ORCH_MODEL_STATUS[gemini]=0
    fi
}

# ---------------------------------------------------------------------------
# orch_check_usage — run all model checks, write usage.txt, compute backoff
# ---------------------------------------------------------------------------
orch_check_usage() {
    local project_root="${1:-.}"
    local usage_file="${project_root}/prompts/00-shared-context/usage.txt"
    mkdir -p "$(dirname "$usage_file")"

    echo "Checking model availability..."

    _orch_check_claude
    echo "  Claude: ${_ORCH_MODEL_STATUS[claude]}"

    _orch_check_codex
    echo "  Codex: ${_ORCH_MODEL_STATUS[codex]}"

    _orch_check_gemini
    echo "  Gemini: ${_ORCH_MODEL_STATUS[gemini]}"

    # Overall = max of all three
    local overall=${_ORCH_MODEL_STATUS[claude]:-0}
    [[ ${_ORCH_MODEL_STATUS[codex]:-0} -gt $overall ]] && overall=${_ORCH_MODEL_STATUS[codex]}
    [[ ${_ORCH_MODEL_STATUS[gemini]:-0} -gt $overall ]] && overall=${_ORCH_MODEL_STATUS[gemini]}
    _ORCH_MODEL_STATUS[overall]=$overall

    # Write results
    cat > "$usage_file" <<EOF
claude=${_ORCH_MODEL_STATUS[claude]:-0}
codex=${_ORCH_MODEL_STATUS[codex]:-0}
gemini=${_ORCH_MODEL_STATUS[gemini]:-0}
overall=$overall
EOF

    # Compute graduated backoff based on Claude status (primary model)
    local claude_status=${_ORCH_MODEL_STATUS[claude]:-0}
    if [[ $claude_status -ge 100 ]]; then
        _ORCH_USAGE_BACKOFF=300   # 5 minutes — hard rate limited
    elif [[ $claude_status -ge 90 ]]; then
        _ORCH_USAGE_BACKOFF=120   # 2 minutes — overage exhausted
    elif [[ $claude_status -ge 80 ]]; then
        _ORCH_USAGE_BACKOFF=30    # 30 seconds — using overage, slow down
    elif [[ $claude_status -ge 70 ]]; then
        _ORCH_USAGE_BACKOFF=10    # 10 seconds — approaching limit
    else
        _ORCH_USAGE_BACKOFF=0     # All clear
    fi

    echo ""
    echo "Results: claude=${_ORCH_MODEL_STATUS[claude]} codex=${_ORCH_MODEL_STATUS[codex]} gemini=${_ORCH_MODEL_STATUS[gemini]} overall=$overall"
    if [[ $_ORCH_USAGE_BACKOFF -gt 0 ]]; then
        echo "Backoff: ${_ORCH_USAGE_BACKOFF}s (claude at ${claude_status})"
    fi
    echo "Written to: $usage_file"
}

# ---------------------------------------------------------------------------
# orch_should_pause — returns 0 (true) if orchestrator should pause
# ---------------------------------------------------------------------------
orch_should_pause() {
    local claude_status=${_ORCH_MODEL_STATUS[claude]:-0}
    [[ $claude_status -ge $_ORCH_PAUSE_THRESHOLD ]]
}

# ---------------------------------------------------------------------------
# orch_get_backoff_seconds — returns recommended sleep duration
# ---------------------------------------------------------------------------
orch_get_backoff_seconds() {
    echo "$_ORCH_USAGE_BACKOFF"
}

# ---------------------------------------------------------------------------
# orch_model_status — returns status for a specific model
# Usage: orch_model_status "claude"  # prints 0/80/90/100
# ---------------------------------------------------------------------------
orch_model_status() {
    local model="${1:-claude}"
    echo "${_ORCH_MODEL_STATUS[$model]:-0}"
}

# ---------------------------------------------------------------------------
# orch_all_models_down — returns 0 (true) if all models are unavailable
# ---------------------------------------------------------------------------
orch_all_models_down() {
    [[ ${_ORCH_MODEL_STATUS[claude]:-0} -ge 100 ]] && \
    [[ ${_ORCH_MODEL_STATUS[codex]:-0} -ge 100 ]] && \
    [[ ${_ORCH_MODEL_STATUS[gemini]:-0} -ge 100 ]]
}
