#!/usr/bin/env bash
# signal-handler.sh — Graceful shutdown with SHUTTING_DOWN flag
# Fixes P1: "No Signal Handling for Agent Subprocesses"
#
# Provides:
#   orch_signal_init          — install traps (call once at startup)
#   orch_is_shutting_down     — returns 0 if shutdown in progress
#   orch_register_agent_pid   — track a spawned agent PID
#   orch_unregister_agent_pid — remove a finished agent PID
#   orch_kill_agents          — SIGTERM all tracked agents, SIGKILL after timeout

[[ -n "${_ORCH_SIGNAL_HANDLER_LOADED:-}" ]] && return 0
_ORCH_SIGNAL_HANDLER_LOADED=1

# ── State ──
declare -g _ORCH_SHUTTING_DOWN=false
declare -g -a _ORCH_AGENT_PIDS=()
declare -g _ORCH_KILL_TIMEOUT=10  # seconds before SIGKILL

orch_signal_init() {
    local kill_timeout="${1:-10}"
    _ORCH_KILL_TIMEOUT="$kill_timeout"
    trap '_orch_shutdown_handler' INT TERM
    trap '_orch_exit_handler' EXIT
}

orch_is_shutting_down() {
    [[ "$_ORCH_SHUTTING_DOWN" == "true" ]]
}

orch_register_agent_pid() {
    local pid="$1"
    _ORCH_AGENT_PIDS+=("$pid")
}

orch_unregister_agent_pid() {
    local pid="$1"
    local -a new_pids=()
    for p in "${_ORCH_AGENT_PIDS[@]}"; do
        [[ "$p" != "$pid" ]] && new_pids+=("$p")
    done
    _ORCH_AGENT_PIDS=("${new_pids[@]}")
}

orch_kill_agents() {
    local timeout="${1:-$_ORCH_KILL_TIMEOUT}"
    local -a live_pids=()

    # Phase 1: SIGTERM
    for pid in "${_ORCH_AGENT_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null
            live_pids+=("$pid")
            [[ "$(type -t orch_log)" == "function" ]] && orch_log WARN orchestrator "Sent SIGTERM to agent PID $pid"
        fi
    done

    if [[ ${#live_pids[@]} -eq 0 ]]; then
        return 0
    fi

    # Phase 2: Wait with timeout
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local still_alive=false
        for pid in "${live_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                still_alive=true
                break
            fi
        done
        [[ "$still_alive" == "false" ]] && return 0
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Phase 3: SIGKILL survivors
    for pid in "${live_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
            [[ "$(type -t orch_log)" == "function" ]] && orch_log ERROR orchestrator "Sent SIGKILL to agent PID $pid (did not exit after ${timeout}s)"
        fi
    done

    # Brief wait for SIGKILL to take effect
    sleep 1
}

# ── Internal handlers ──

_orch_shutdown_handler() {
    if [[ "$_ORCH_SHUTTING_DOWN" == "true" ]]; then
        # Already shutting down — force kill
        orch_kill_agents 2
        exit 1
    fi

    _ORCH_SHUTTING_DOWN=true
    [[ "$(type -t orch_log)" == "function" ]] && orch_log WARN orchestrator "Shutdown signal received — stopping ${#_ORCH_AGENT_PIDS[@]} agents..."
    orch_kill_agents
}

_orch_exit_handler() {
    # Ensure all agents are dead on exit
    for pid in "${_ORCH_AGENT_PIDS[@]}"; do
        kill -KILL "$pid" 2>/dev/null
    done
}
