#!/usr/bin/env bash
# stall-detector.sh — Detects when the orchestrator is running idle cycles
# and signals for auto-pause.
#
# A "stall" is N consecutive cycles with no meaningful commits (lint-only,
# prompt updates, zero-diff merges). Tracks state in .stall-state.
#
# Usage:
#   source stall-detector.sh
#   stall_check_cycle "$CYCLE_NUM"       # Run after each cycle's commits
#   stall_should_pause && exit_orchestrator

set -euo pipefail

STALL_STATE_DIR="${STALL_STATE_DIR:-prompts/00-session-tracker}"
STALL_STATE_FILE="${STALL_STATE_DIR}/.stall-state"
STALL_MAX_IDLE="${STALL_MAX_IDLE:-3}"   # Pause after 3 idle cycles
STALL_MIN_LINES="${STALL_MIN_LINES:-20}" # Commits <20 lines are "lint-only"

_stall_meaningful_commits_since() {
    local since_ref="$1"
    local total=0
    local sha
    for sha in $(git log "${since_ref}..HEAD" --format=%H 2>/dev/null); do
        local msg
        msg=$(git log -1 --format=%s "$sha")
        # Skip lint-only / backup / auto-update commits
        if echo "$msg" | grep -qiE '(lint-only|auto-update all prompts|chore: cycle .* backup|zero-commit)'; then
            continue
        fi
        local lines
        lines=$(git show --stat --format="" "$sha" 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
        if [[ "$lines" -ge "$STALL_MIN_LINES" ]]; then
            total=$((total + 1))
        fi
    done
    echo "$total"
}

stall_check_cycle() {
    local cycle_num="$1"
    mkdir -p "$STALL_STATE_DIR"

    # Find the commit at cycle start (tagged or use previous state)
    local since_ref="HEAD~5"
    if [[ -f "$STALL_STATE_FILE" ]]; then
        since_ref=$(grep -oP '^last_ref=\K.*' "$STALL_STATE_FILE" 2>/dev/null || echo "HEAD~5")
    fi

    local meaningful
    meaningful=$(_stall_meaningful_commits_since "$since_ref")

    local current_idle=0
    if [[ -f "$STALL_STATE_FILE" ]]; then
        current_idle=$(grep -oP '^idle_count=\K[0-9]+' "$STALL_STATE_FILE" 2>/dev/null || echo "0")
    fi

    if [[ "$meaningful" -eq 0 ]]; then
        current_idle=$((current_idle + 1))
        echo "[stall] Cycle $cycle_num: IDLE (idle count: $current_idle/$STALL_MAX_IDLE)"
    else
        current_idle=0
        echo "[stall] Cycle $cycle_num: $meaningful meaningful commits — reset"
    fi

    cat > "$STALL_STATE_FILE" <<EOF
cycle=$cycle_num
idle_count=$current_idle
last_ref=$(git rev-parse HEAD)
last_check=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    return 0
}

stall_should_pause() {
    [[ -f "$STALL_STATE_FILE" ]] || return 1
    local idle
    idle=$(grep -oP '^idle_count=\K[0-9]+' "$STALL_STATE_FILE" 2>/dev/null || echo "0")
    [[ "$idle" -ge "$STALL_MAX_IDLE" ]]
}

stall_reset() {
    rm -f "$STALL_STATE_FILE"
}

stall_status() {
    if [[ -f "$STALL_STATE_FILE" ]]; then
        cat "$STALL_STATE_FILE"
    else
        echo "No stall state — fresh."
    fi
}

# CLI mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        check) stall_check_cycle "${2:-0}" ;;
        should-pause) stall_should_pause && echo "PAUSE" || echo "CONTINUE" ;;
        reset) stall_reset ;;
        status) stall_status ;;
        *) echo "Usage: stall-detector.sh {check N|should-pause|reset|status}"; exit 1 ;;
    esac
fi
