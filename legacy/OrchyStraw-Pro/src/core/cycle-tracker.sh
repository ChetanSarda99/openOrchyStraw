#!/usr/bin/env bash
# cycle-tracker.sh — Smart empty cycle detection
# Fixes P1: "Empty Cycle Detection is Too Aggressive"
#
# Tracks agent outcomes separately from commit counts.
# A cycle where agents ran successfully but produced no commits is NOT empty.
# Only cycles where ALL agents failed/errored count toward the empty threshold.
#
# Provides:
#   orch_tracker_init            — reset for new cycle
#   orch_tracker_record          — record agent outcome (success|fail|skip|timeout)
#   orch_tracker_set_commits     — record commit count
#   orch_tracker_is_empty        — true only if all agents failed AND no commits
#   orch_tracker_is_productive   — true if any agent succeeded OR commits > 0
#   orch_tracker_summary         — print cycle summary line

[[ -n "${_ORCH_CYCLE_TRACKER_LOADED:-}" ]] && return 0
_ORCH_CYCLE_TRACKER_LOADED=1

# ── State ──
declare -g _ORCH_TRACKER_CYCLE=0
declare -g _ORCH_TRACKER_COMMITS=0
declare -g -A _ORCH_TRACKER_OUTCOMES=()
declare -g _ORCH_TRACKER_AGENTS_RUN=0
declare -g _ORCH_TRACKER_AGENTS_OK=0
declare -g _ORCH_TRACKER_AGENTS_FAIL=0
declare -g _ORCH_TRACKER_EMPTY_STREAK=0

orch_tracker_init() {
    local cycle_num="${1:-0}"
    _ORCH_TRACKER_CYCLE="$cycle_num"
    _ORCH_TRACKER_COMMITS=0
    _ORCH_TRACKER_OUTCOMES=()
    _ORCH_TRACKER_AGENTS_RUN=0
    _ORCH_TRACKER_AGENTS_OK=0
    _ORCH_TRACKER_AGENTS_FAIL=0
}

orch_tracker_record() {
    local agent_id="$1"
    local outcome="$2"  # success, fail, skip, timeout

    _ORCH_TRACKER_OUTCOMES["$agent_id"]="$outcome"

    case "$outcome" in
        success)
            _ORCH_TRACKER_AGENTS_RUN=$((_ORCH_TRACKER_AGENTS_RUN + 1))
            _ORCH_TRACKER_AGENTS_OK=$((_ORCH_TRACKER_AGENTS_OK + 1))
            ;;
        fail|timeout)
            _ORCH_TRACKER_AGENTS_RUN=$((_ORCH_TRACKER_AGENTS_RUN + 1))
            _ORCH_TRACKER_AGENTS_FAIL=$((_ORCH_TRACKER_AGENTS_FAIL + 1))
            ;;
        skip)
            ;; # Not counted as run
    esac
}

orch_tracker_set_commits() {
    _ORCH_TRACKER_COMMITS="${1:-0}"
}

orch_tracker_is_empty() {
    # Empty = all agents that ran failed AND no commits
    # If no agents ran at all, also empty
    [[ $_ORCH_TRACKER_AGENTS_RUN -eq 0 ]] && return 0
    [[ $_ORCH_TRACKER_AGENTS_OK -eq 0 && $_ORCH_TRACKER_COMMITS -eq 0 ]]
}

orch_tracker_is_productive() {
    # Productive = at least one agent succeeded OR at least one commit
    [[ $_ORCH_TRACKER_AGENTS_OK -gt 0 || $_ORCH_TRACKER_COMMITS -gt 0 ]]
}

orch_tracker_update_streak() {
    if orch_tracker_is_empty; then
        _ORCH_TRACKER_EMPTY_STREAK=$((_ORCH_TRACKER_EMPTY_STREAK + 1))
    else
        _ORCH_TRACKER_EMPTY_STREAK=0
    fi
}

orch_tracker_empty_streak() {
    echo "$_ORCH_TRACKER_EMPTY_STREAK"
}

orch_tracker_should_stop() {
    local max_empty="${1:-3}"
    [[ $_ORCH_TRACKER_EMPTY_STREAK -ge $max_empty ]]
}

orch_tracker_summary() {
    local status="PRODUCTIVE"
    orch_tracker_is_empty && status="EMPTY"

    echo "Cycle $_ORCH_TRACKER_CYCLE: $status — ${_ORCH_TRACKER_AGENTS_OK}/${_ORCH_TRACKER_AGENTS_RUN} agents OK, ${_ORCH_TRACKER_COMMITS} commits, streak=${_ORCH_TRACKER_EMPTY_STREAK}"
}
