#!/usr/bin/env bash
# =============================================================================
# auto-improve.sh — Karpathy-style auto-improvement loop for OrchyStraw
#
# Inspired by karpathy/autoresearch: run cycles, measure quality, keep
# improvements, revert regressions. The agent modifies code/prompts,
# the loop measures a single metric (quality score), and accepts or
# rejects the change.
#
# Usage:
#   source src/core/auto-improve.sh
#   orch_improve_init
#   orch_improve_run 10    # 10 improvement iterations
#
# Requires: quality-scorer.sh, git
# =============================================================================

[[ -n "${_ORCH_AUTO_IMPROVE_LOADED:-}" ]] && return 0
_ORCH_AUTO_IMPROVE_LOADED=1

# ── Configuration ──

# Minimum quality score improvement to accept a change
declare -g _IMPROVE_MIN_DELTA="${ORCH_IMPROVE_MIN_DELTA:-0}"

# Revert if quality drops below this absolute threshold
declare -g _IMPROVE_FLOOR="${ORCH_IMPROVE_FLOOR:-40}"

# Max consecutive rejections before stopping
declare -g _IMPROVE_MAX_REJECTS="${ORCH_IMPROVE_MAX_REJECTS:-5}"

# Log file
declare -g _IMPROVE_LOG=""

# ── Internal state ──

declare -g _IMPROVE_BASELINE_SCORE=0
declare -g _IMPROVE_CURRENT_SCORE=0
declare -g _IMPROVE_ACCEPTS=0
declare -g _IMPROVE_REJECTS=0
declare -g _IMPROVE_CONSECUTIVE_REJECTS=0
declare -g _IMPROVE_INITIALIZED=false

# ── Logging ──

_improve_log() {
    local level="$1" msg="$2"
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$level" "auto-improve" "$msg"
    else
        printf '[%s] [auto-improve] %s\n' "$level" "$msg" >&2
    fi
    if [[ -n "$_IMPROVE_LOG" ]]; then
        printf '[%s] [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$level" "$msg" >> "$_IMPROVE_LOG"
    fi
}

# =============================================================================
# orch_improve_init
#
# Initialize: snapshot current quality score as baseline, create log.
# =============================================================================
orch_improve_init() {
    local project_root="${PROJECT_ROOT:-.}"

    mkdir -p "$project_root/.orchystraw"
    _IMPROVE_LOG="$project_root/.orchystraw/improve.log"

    # Get baseline quality score
    if [[ "$(type -t orch_scorer_run)" == "function" ]]; then
        _IMPROVE_BASELINE_SCORE=$(orch_scorer_run 2>/dev/null | grep -o '"total":[0-9]*' | grep -o '[0-9]*' | head -1)
        _IMPROVE_BASELINE_SCORE="${_IMPROVE_BASELINE_SCORE:-0}"
    else
        # Fallback: run tests and count pass rate
        _IMPROVE_BASELINE_SCORE=$(_improve_test_score)
    fi

    _IMPROVE_CURRENT_SCORE="$_IMPROVE_BASELINE_SCORE"
    _IMPROVE_ACCEPTS=0
    _IMPROVE_REJECTS=0
    _IMPROVE_CONSECUTIVE_REJECTS=0
    _IMPROVE_INITIALIZED=true

    _improve_log "INFO" "Initialized — baseline score: $_IMPROVE_BASELINE_SCORE"
}

# =============================================================================
# _improve_test_score
#
# Fallback quality metric: test pass rate (0-100).
# =============================================================================
_improve_test_score() {
    local project_root="${PROJECT_ROOT:-.}"
    local test_runner=""

    # Find test runner
    if [[ -f "$project_root/tests/core/run-tests.sh" ]]; then
        test_runner="$project_root/tests/core/run-tests.sh"
    elif [[ -f "$project_root/package.json" ]]; then
        # Node project: check for test script
        if grep -q '"test"' "$project_root/package.json" 2>/dev/null; then
            local result
            result=$(cd "$project_root" && npm test 2>&1)
            if [[ $? -eq 0 ]]; then
                printf '100\n'
            else
                printf '50\n'
            fi
            return
        fi
    fi

    if [[ -n "$test_runner" ]]; then
        local output
        output=$(/opt/homebrew/bin/bash "$test_runner" 2>&1 || /usr/bin/bash "$test_runner" 2>&1)
        # Parse "N/M passed" pattern
        local passed total
        passed=$(echo "$output" | grep -oE '[0-9]+/[0-9]+ passed' | head -1 | cut -d'/' -f1)
        total=$(echo "$output" | grep -oE '[0-9]+/[0-9]+ passed' | head -1 | cut -d'/' -f2 | cut -d' ' -f1)
        if [[ -n "$passed" && -n "$total" && "$total" -gt 0 ]]; then
            printf '%d\n' "$(( passed * 100 / total ))"
            return
        fi
    fi

    # No tests found
    printf '0\n'
}

# =============================================================================
# _improve_measure
#
# Measure current quality score after a change.
# =============================================================================
_improve_measure() {
    if [[ "$(type -t orch_scorer_run)" == "function" ]]; then
        local score
        score=$(orch_scorer_run 2>/dev/null | grep -o '"total":[0-9]*' | grep -o '[0-9]*' | head -1)
        printf '%d\n' "${score:-0}"
    else
        _improve_test_score
    fi
}

# =============================================================================
# _improve_snapshot
#
# Create a git snapshot before an improvement attempt.
# Returns the commit hash.
# =============================================================================
_improve_snapshot() {
    local project_root="${PROJECT_ROOT:-.}"
    # Stash any uncommitted changes and record the state
    local hash
    hash=$(git -C "$project_root" rev-parse HEAD 2>/dev/null)
    printf '%s\n' "$hash"
}

# =============================================================================
# _improve_revert
#
# Revert to a previous snapshot.
# =============================================================================
_improve_revert() {
    local snapshot="$1"
    local project_root="${PROJECT_ROOT:-.}"

    if [[ -n "$snapshot" ]]; then
        git -C "$project_root" reset --hard "$snapshot" 2>/dev/null
        _improve_log "WARN" "Reverted to $snapshot"
    fi
}

# =============================================================================
# orch_improve_step
#
# Run one improvement iteration:
#   1. Snapshot current state
#   2. Run one orchestration cycle (agent makes changes)
#   3. Measure new quality score
#   4. Accept if improved, reject (revert) if degraded
#
# Returns: 0 if accepted, 1 if rejected, 2 if stopped
# =============================================================================
orch_improve_step() {
    local agent_id="${1:-}"
    local project_root="${PROJECT_ROOT:-.}"

    # 1. Snapshot
    local snapshot
    snapshot=$(_improve_snapshot)

    # 2. Run cycle (single agent or full cycle)
    _improve_log "INFO" "Step $((1 + _IMPROVE_ACCEPTS + _IMPROVE_REJECTS)): running cycle..."

    if [[ -n "$agent_id" ]]; then
        # Single agent mode
        if [[ "$(type -t run_agent)" == "function" ]]; then
            run_agent "$agent_id" 2>/dev/null
        fi
    else
        # Full cycle — delegate to auto-agent.sh orchestrate
        /opt/homebrew/bin/bash "${ORCH_ROOT:-$project_root}/scripts/auto-agent.sh" orchestrate 1 2>/dev/null || \
        /usr/bin/bash "${ORCH_ROOT:-$project_root}/scripts/auto-agent.sh" orchestrate 1 2>/dev/null
    fi

    # 3. Measure
    local new_score
    new_score=$(_improve_measure)
    local delta=$((new_score - _IMPROVE_CURRENT_SCORE))

    _improve_log "INFO" "Score: $new_score (was $_IMPROVE_CURRENT_SCORE, delta=$delta)"

    # 4. Accept/reject
    if [[ "$new_score" -lt "$_IMPROVE_FLOOR" ]]; then
        # Below absolute floor — always revert
        _improve_log "WARN" "REJECT: score $new_score below floor $_IMPROVE_FLOOR — reverting"
        _improve_revert "$snapshot"
        _IMPROVE_REJECTS=$((_IMPROVE_REJECTS + 1))
        _IMPROVE_CONSECUTIVE_REJECTS=$((_IMPROVE_CONSECUTIVE_REJECTS + 1))
        return 1
    elif [[ "$delta" -ge "$_IMPROVE_MIN_DELTA" ]]; then
        # Improved or maintained — accept
        _improve_log "INFO" "ACCEPT: $new_score (delta=$delta)"
        _IMPROVE_CURRENT_SCORE="$new_score"
        _IMPROVE_ACCEPTS=$((_IMPROVE_ACCEPTS + 1))
        _IMPROVE_CONSECUTIVE_REJECTS=0

        # Record decision
        if [[ "$(type -t orch_decision_log)" == "function" ]]; then
            orch_decision_log "auto-improve" "accept" \
                "score=$new_score delta=$delta baseline=$_IMPROVE_BASELINE_SCORE" 2>/dev/null || true
        fi
        return 0
    else
        # Degraded — revert
        _improve_log "WARN" "REJECT: score dropped to $new_score (delta=$delta) — reverting"
        _improve_revert "$snapshot"
        _IMPROVE_REJECTS=$((_IMPROVE_REJECTS + 1))
        _IMPROVE_CONSECUTIVE_REJECTS=$((_IMPROVE_CONSECUTIVE_REJECTS + 1))
        return 1
    fi
}

# =============================================================================
# orch_improve_run [max_iterations]
#
# Run the full auto-improvement loop.
# Stops when: max iterations reached, or too many consecutive rejections.
# =============================================================================
orch_improve_run() {
    local max_iter="${1:-10}"
    local agent_id="${2:-}"

    if [[ "$_IMPROVE_INITIALIZED" != true ]]; then
        orch_improve_init
    fi

    _improve_log "INFO" "=== Auto-improvement loop starting (max=$max_iter, baseline=$_IMPROVE_BASELINE_SCORE) ==="

    local i
    for ((i = 1; i <= max_iter; i++)); do
        _improve_log "INFO" "--- Iteration $i/$max_iter ---"

        orch_improve_step "$agent_id"
        local rc=$?

        # Check stopping conditions
        if [[ "$_IMPROVE_CONSECUTIVE_REJECTS" -ge "$_IMPROVE_MAX_REJECTS" ]]; then
            _improve_log "WARN" "Stopping: $_IMPROVE_CONSECUTIVE_REJECTS consecutive rejections"
            break
        fi
    done

    _improve_log "INFO" "=== Auto-improvement complete ==="
    orch_improve_report
}

# =============================================================================
# orch_improve_report
#
# Print improvement summary.
# =============================================================================
orch_improve_report() {
    local total=$((_IMPROVE_ACCEPTS + _IMPROVE_REJECTS))
    local improvement=$((_IMPROVE_CURRENT_SCORE - _IMPROVE_BASELINE_SCORE))

    printf 'Auto-Improvement Report:\n'
    printf '  Baseline score:   %d\n' "$_IMPROVE_BASELINE_SCORE"
    printf '  Final score:      %d\n' "$_IMPROVE_CURRENT_SCORE"
    printf '  Improvement:      %+d\n' "$improvement"
    printf '  Iterations:       %d\n' "$total"
    printf '  Accepted:         %d\n' "$_IMPROVE_ACCEPTS"
    printf '  Rejected:         %d\n' "$_IMPROVE_REJECTS"
    printf '  Accept rate:      '
    if [[ "$total" -gt 0 ]]; then
        printf '%d%%\n' "$((_IMPROVE_ACCEPTS * 100 / total))"
    else
        printf 'n/a\n'
    fi
}
