#!/usr/bin/env bash
# ============================================
# agent-timeout.sh — Per-agent timeout library
# Source this file: source src/core/agent-timeout.sh
#
# Public API:
#   orch_run_with_timeout <timeout_seconds> <command...>
#   orch_get_agent_timeout <agent_id>
#   orch_timeout_report
#   orch_reset_timeouts
#
# Environment:
#   ORCH_TIMEOUT_<AGENT_ID>   — per-agent override (e.g. ORCH_TIMEOUT_06_BACKEND=600)
#   ORCH_DEFAULT_TIMEOUT      — fallback default (default: 300)
#
# Requires: bash 5.x
# ============================================

# Guard against double-sourcing
[[ -n "${_ORCH_AGENT_TIMEOUT_LOADED:-}" ]] && return 0
readonly _ORCH_AGENT_TIMEOUT_LOADED=1

# Tracked timeouts for this cycle: each entry is "<agent_id>:<timestamp>"
declare -a _ORCH_TIMEOUTS=()

# ---------------------------------------------------------------------------
# orch_run_with_timeout <timeout_seconds> <command...>
#
# Runs <command...> in the background, then monitors it with a watchdog.
# Kill sequence on timeout:
#   1. SIGTERM  — graceful shutdown
#   2. wait 10s
#   3. SIGKILL  — force kill if still alive
#
# Returns:
#   Exit code of the command on normal completion.
#   124 if the command was killed by timeout.
# ---------------------------------------------------------------------------
orch_run_with_timeout() {
    local timeout_secs="$1"
    shift
    local cmd=("$@")

    if [[ -z "$timeout_secs" || "$timeout_secs" -lt 1 ]]; then
        echo "[agent-timeout] ERROR: timeout_seconds must be a positive integer (got '${timeout_secs}')" >&2
        return 1
    fi

    # Launch command in background, redirect its stdio to our stdio
    "${cmd[@]}" &
    local cmd_pid=$!

    # Watchdog: sleeps for timeout, then kills the command process group
    (
        local elapsed=0
        while (( elapsed < timeout_secs )); do
            sleep 1
            (( elapsed++ ))
            # Exit watchdog if the main command is no longer running
            kill -0 "$cmd_pid" 2>/dev/null || exit 0
        done

        # Timeout reached — escalating kill sequence
        if kill -0 "$cmd_pid" 2>/dev/null; then
            kill -TERM "$cmd_pid" 2>/dev/null

            local grace=10
            local waited=0
            while (( waited < grace )); do
                sleep 1
                (( waited++ ))
                kill -0 "$cmd_pid" 2>/dev/null || exit 0
            done

            # Still alive after grace period — force kill
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null
            fi
        fi
    ) &
    local watchdog_pid=$!

    # Wait for the command to finish
    wait "$cmd_pid" 2>/dev/null
    local exit_code=$?

    # Tear down the watchdog (no-op if it already exited)
    kill "$watchdog_pid" 2>/dev/null
    wait "$watchdog_pid" 2>/dev/null

    # Detect whether we were killed by the watchdog.
    # SIGTERM → 128+15=143, SIGKILL → 128+9=137
    if [[ $exit_code -eq 143 || $exit_code -eq 137 ]]; then
        return 124
    fi

    return "$exit_code"
}

# ---------------------------------------------------------------------------
# orch_get_agent_timeout <agent_id>
#
# Prints the effective timeout (in seconds) for the given agent.
# Resolution order:
#   1. ORCH_TIMEOUT_<AGENT_ID_UPPERCASED>  env var
#   2. ORCH_DEFAULT_TIMEOUT                env var
#   3. Hard-coded default: 300 seconds
#
# Agent ID normalisation: lowercase, hyphens/spaces → underscores, then uppercased.
# Examples:
#   orch_get_agent_timeout 06-backend   → reads ORCH_TIMEOUT_06_BACKEND
#   orch_get_agent_timeout "07 iOS"     → reads ORCH_TIMEOUT_07_IOS
# ---------------------------------------------------------------------------
orch_get_agent_timeout() {
    local agent_id="${1:-}"

    if [[ -z "$agent_id" ]]; then
        echo "[agent-timeout] ERROR: orch_get_agent_timeout requires an agent_id argument" >&2
        return 1
    fi

    # Normalise in two passes: hyphens/spaces → underscores, then lowercase → uppercase.
    # Two separate tr calls avoids portability issues with '- ' as a character set.
    local env_key
    env_key="ORCH_TIMEOUT_$(echo "$agent_id" | tr ' -' '_' | tr '[:lower:]' '[:upper:]')"

    local timeout
    # Check per-agent env var
    if [[ -n "${!env_key:-}" ]]; then
        timeout="${!env_key}"
    # Check global default env var
    elif [[ -n "${ORCH_DEFAULT_TIMEOUT:-}" ]]; then
        timeout="$ORCH_DEFAULT_TIMEOUT"
    else
        timeout=300
    fi

    echo "$timeout"
}

# ---------------------------------------------------------------------------
# _orch_record_timeout <agent_id>
#
# Internal helper — call this when an agent is killed by timeout.
# Appends "<agent_id>:<epoch_timestamp>" to _ORCH_TIMEOUTS.
# ---------------------------------------------------------------------------
_orch_record_timeout() {
    local agent_id="${1:-unknown}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    _ORCH_TIMEOUTS+=("${agent_id}:${ts}")
}

# ---------------------------------------------------------------------------
# orch_timeout_report
#
# Prints a human-readable summary of all agents killed by timeout this cycle.
# Outputs nothing (with a note) when no timeouts occurred.
# ---------------------------------------------------------------------------
orch_timeout_report() {
    if [[ ${#_ORCH_TIMEOUTS[@]} -eq 0 ]]; then
        echo "[agent-timeout] No agent timeouts recorded this cycle."
        return 0
    fi

    echo "[agent-timeout] Agents killed by timeout this cycle (${#_ORCH_TIMEOUTS[@]} total):"
    local entry
    for entry in "${_ORCH_TIMEOUTS[@]}"; do
        local agent_id="${entry%%:*}"
        local ts="${entry#*:}"
        printf "  %-20s  killed at %s\n" "$agent_id" "$ts"
    done
}

# ---------------------------------------------------------------------------
# orch_reset_timeouts
#
# Clears the timeout tracking array. Call at the start of each orchestrator
# cycle so that orch_timeout_report only reflects the current cycle.
# ---------------------------------------------------------------------------
orch_reset_timeouts() {
    _ORCH_TIMEOUTS=()
}
