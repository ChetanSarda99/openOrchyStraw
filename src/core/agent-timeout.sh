#!/usr/bin/env bash
# ============================================
# agent-timeout.sh — Per-agent timeout library
# Source this file: source src/core/agent-timeout.sh
#
# Public API:
#   orch_run_with_timeout <timeout_seconds> <command...>
#   orch_run_with_limits  <timeout_seconds> <memory_mb> <cpu_percent> <command...>
#   orch_get_agent_timeout <agent_id>
#   orch_timeout_report
#   orch_reset_timeouts
#
# Environment:
#   ORCH_TIMEOUT_<AGENT_ID>   — per-agent override (e.g. ORCH_TIMEOUT_06_BACKEND=600)
#   ORCH_DEFAULT_TIMEOUT      — fallback default (default: 300)
#   ORCH_MEMORY_LIMIT_MB      — default memory limit in MB (default: 0 = unlimited)
#   ORCH_CPU_LIMIT_PERCENT    — default CPU limit as percentage (default: 0 = unlimited)
#
# Requires: bash 5.x
# ============================================

# Guard against double-sourcing
[[ -n "${_ORCH_AGENT_TIMEOUT_LOADED:-}" ]] && return 0
readonly _ORCH_AGENT_TIMEOUT_LOADED=1

# Tracked timeouts for this cycle: each entry is "<agent_id>:<timestamp>:<reason>"
declare -a _ORCH_TIMEOUTS=()

# Resource limit defaults
ORCH_MEMORY_LIMIT_MB="${ORCH_MEMORY_LIMIT_MB:-0}"
ORCH_CPU_LIMIT_PERCENT="${ORCH_CPU_LIMIT_PERCENT:-0}"

# ---------------------------------------------------------------------------
# _orch_kill_process_group <pid> [grace_seconds]
#
# Kill a process and all its children (process group).
# Sends SIGTERM first, waits grace period, then SIGKILL if needed.
# Returns 0 if process was killed, 1 if it wasn't running.
# ---------------------------------------------------------------------------
_orch_kill_process_group() {
    local pid="$1"
    local grace="${2:-10}"

    # Check if process exists
    kill -0 "$pid" 2>/dev/null || return 1

    # Try SIGTERM on the process group (negative PID)
    # Fall back to single process if group kill fails
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true

    # Wait for grace period
    local waited=0
    while (( waited < grace )); do
        sleep 1
        (( waited++ ))
        kill -0 "$pid" 2>/dev/null || return 0
    done

    # Force kill the process group
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true

    # Brief wait for SIGKILL to take effect
    sleep 1
    kill -0 "$pid" 2>/dev/null && return 1
    return 0
}

# ---------------------------------------------------------------------------
# _orch_apply_ulimits <memory_mb>
#
# Apply resource limits using ulimit (works without root).
# This should be called in the subshell before exec'ing the command.
# ---------------------------------------------------------------------------
_orch_apply_ulimits() {
    local memory_mb="$1"

    if [[ "$memory_mb" -gt 0 ]]; then
        # Convert MB to KB for ulimit -v (virtual memory)
        local memory_kb=$(( memory_mb * 1024 ))
        ulimit -v "$memory_kb" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# _orch_monitor_resources <pid> <memory_mb> <cpu_percent> <timeout_secs>
#
# Monitor a process for resource usage. Kill if limits exceeded.
# Returns:
#   0 — process exited normally or was already dead
#   1 — killed for memory limit
#   2 — killed for CPU limit
#   3 — killed for timeout
# ---------------------------------------------------------------------------
_orch_monitor_resources() {
    local pid="$1"
    local memory_mb="$2"
    local cpu_percent="$3"
    local timeout_secs="$4"

    local elapsed=0
    local check_interval=2  # Check every 2 seconds

    while (( elapsed < timeout_secs )); do
        sleep "$check_interval"
        (( elapsed += check_interval ))

        # Exit if process is gone
        kill -0 "$pid" 2>/dev/null || return 0

        # Check memory usage (RSS in KB from /proc or ps)
        if [[ "$memory_mb" -gt 0 ]]; then
            local rss_kb=0
            if [[ -f "/proc/$pid/status" ]]; then
                rss_kb=$(grep -i 'VmRSS' "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo 0)
            else
                # Fallback to ps (works on macOS/BSD too)
                rss_kb=$(ps -o rss= -p "$pid" 2>/dev/null || echo 0)
            fi
            rss_kb="${rss_kb//[[:space:]]/}"
            rss_kb="${rss_kb:-0}"

            local rss_mb=$(( rss_kb / 1024 ))
            if [[ "$rss_mb" -gt "$memory_mb" ]]; then
                printf '[agent-timeout] Process %d exceeded memory limit (%dMB > %dMB) — killing\n' \
                    "$pid" "$rss_mb" "$memory_mb" >&2
                _orch_kill_process_group "$pid" 5
                return 1
            fi
        fi

        # Check CPU usage (cumulative percentage)
        if [[ "$cpu_percent" -gt 0 ]]; then
            local cpu=0
            if command -v ps >/dev/null 2>&1; then
                cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo 0)
                cpu="${cpu//[[:space:]]/}"
                cpu="${cpu%.*}"  # Truncate to integer
                cpu="${cpu:-0}"
            fi

            if [[ "$cpu" -gt "$cpu_percent" ]]; then
                printf '[agent-timeout] Process %d exceeded CPU limit (%d%% > %d%%) — killing\n' \
                    "$pid" "$cpu" "$cpu_percent" >&2
                _orch_kill_process_group "$pid" 5
                return 2
            fi
        fi
    done

    # Timeout reached
    if kill -0 "$pid" 2>/dev/null; then
        printf '[agent-timeout] Process %d timed out after %ds — killing\n' \
            "$pid" "$timeout_secs" >&2
        _orch_kill_process_group "$pid" 10
        return 3
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_run_with_timeout <timeout_seconds> <command...>
#
# Runs <command...> in the background, then monitors it with a watchdog.
# Kill sequence on timeout:
#   1. SIGTERM to process group — graceful shutdown
#   2. wait 10s
#   3. SIGKILL to process group — force kill if still alive
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

    # Launch command in a new process group (setsid if available)
    if command -v setsid >/dev/null 2>&1; then
        setsid "${cmd[@]}" &
    else
        "${cmd[@]}" &
    fi
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

        # Timeout reached — escalating kill via process group
        if kill -0 "$cmd_pid" 2>/dev/null; then
            _orch_kill_process_group "$cmd_pid" 10
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
    # SIGTERM -> 128+15=143, SIGKILL -> 128+9=137
    if [[ $exit_code -eq 143 || $exit_code -eq 137 ]]; then
        return 124
    fi

    return "$exit_code"
}

# ---------------------------------------------------------------------------
# orch_run_with_limits <timeout_seconds> <memory_mb> <cpu_percent> <command...>
#
# Run a command with timeout AND resource limits (memory, CPU).
# Monitors the process periodically and kills it if limits are exceeded.
#
# Parameters:
#   timeout_seconds — max wall-clock time (0 = use ORCH_DEFAULT_TIMEOUT)
#   memory_mb       — max RSS in MB (0 = no memory limit)
#   cpu_percent     — max CPU usage percentage (0 = no CPU limit)
#   command...      — command and arguments to execute
#
# Returns:
#   Exit code of the command on normal completion.
#   124 if killed by timeout.
#   125 if killed for exceeding memory limit.
#   126 if killed for exceeding CPU limit.
# ---------------------------------------------------------------------------
orch_run_with_limits() {
    local timeout_secs="${1:?orch_run_with_limits: timeout required}"
    local memory_mb="${2:?orch_run_with_limits: memory_mb required}"
    local cpu_percent="${3:?orch_run_with_limits: cpu_percent required}"
    shift 3
    local cmd=("$@")

    if [[ ${#cmd[@]} -eq 0 ]]; then
        echo "[agent-timeout] ERROR: no command specified" >&2
        return 1
    fi

    # Use defaults if 0
    [[ "$timeout_secs" -eq 0 ]] && timeout_secs="${ORCH_DEFAULT_TIMEOUT:-300}"
    [[ "$memory_mb" -eq 0 ]] && memory_mb="$ORCH_MEMORY_LIMIT_MB"
    [[ "$cpu_percent" -eq 0 ]] && cpu_percent="$ORCH_CPU_LIMIT_PERCENT"

    # If no resource limits, fall back to simple timeout
    if [[ "$memory_mb" -eq 0 && "$cpu_percent" -eq 0 ]]; then
        orch_run_with_timeout "$timeout_secs" "${cmd[@]}"
        return $?
    fi

    # Launch command with ulimits applied in subshell
    (
        _orch_apply_ulimits "$memory_mb"
        exec "${cmd[@]}"
    ) &
    local cmd_pid=$!

    # Monitor in background
    _orch_monitor_resources "$cmd_pid" "$memory_mb" "$cpu_percent" "$timeout_secs" &
    local monitor_pid=$!

    # Wait for the command
    wait "$cmd_pid" 2>/dev/null
    local exit_code=$?

    # Check monitor result
    kill "$monitor_pid" 2>/dev/null
    wait "$monitor_pid" 2>/dev/null
    local monitor_result=$?

    # If monitor killed the process, return appropriate code
    if [[ $exit_code -eq 143 || $exit_code -eq 137 ]]; then
        case "$monitor_result" in
            1) return 125 ;;  # Memory limit
            2) return 126 ;;  # CPU limit (note: overloads "permission denied" but in this context it's clear)
            3) return 124 ;;  # Timeout
            *) return 124 ;;  # Default to timeout
        esac
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
# Agent ID normalisation: lowercase, hyphens/spaces -> underscores, then uppercased.
# Examples:
#   orch_get_agent_timeout 06-backend   -> reads ORCH_TIMEOUT_06_BACKEND
#   orch_get_agent_timeout "07 iOS"     -> reads ORCH_TIMEOUT_07_IOS
# ---------------------------------------------------------------------------
orch_get_agent_timeout() {
    local agent_id="${1:-}"

    if [[ -z "$agent_id" ]]; then
        echo "[agent-timeout] ERROR: orch_get_agent_timeout requires an agent_id argument" >&2
        return 1
    fi

    # Normalise in two passes: hyphens/spaces -> underscores, then lowercase -> uppercase.
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
# _orch_record_timeout <agent_id> [reason]
#
# Internal helper — call this when an agent is killed by timeout/resource limit.
# Appends "<agent_id>:<epoch_timestamp>:<reason>" to _ORCH_TIMEOUTS.
# ---------------------------------------------------------------------------
_orch_record_timeout() {
    local agent_id="${1:-unknown}"
    local reason="${2:-timeout}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    _ORCH_TIMEOUTS+=("${agent_id}:${ts}:${reason}")
}

# ---------------------------------------------------------------------------
# orch_timeout_report
#
# Prints a human-readable summary of all agents killed by timeout or
# resource limits this cycle. Outputs nothing (with a note) when no events.
# ---------------------------------------------------------------------------
orch_timeout_report() {
    if [[ ${#_ORCH_TIMEOUTS[@]} -eq 0 ]]; then
        echo "[agent-timeout] No agent timeouts recorded this cycle."
        return 0
    fi

    echo "[agent-timeout] Agents killed this cycle (${#_ORCH_TIMEOUTS[@]} total):"
    local entry
    for entry in "${_ORCH_TIMEOUTS[@]}"; do
        # Parse agent_id:timestamp:reason (reason may be absent for backwards compat)
        local agent_id="${entry%%:*}"
        local rest="${entry#*:}"
        local ts reason
        if [[ "$rest" == *:* ]]; then
            # Has timestamp:reason
            ts="${rest%:*}"
            reason="${rest##*:}"
        else
            ts="$rest"
            reason="timeout"
        fi
        printf "  %-20s  killed at %s  reason: %s\n" "$agent_id" "$ts" "$reason"
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
