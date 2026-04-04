#!/usr/bin/env bash
# =============================================================================
# observability.sh — Agent observability, metrics, and traces (#v0.4)
#
# Provides lightweight observability for OrchyStraw agent cycles:
#   - Structured metrics (token usage, latency, error rates per agent)
#   - Trace spans (nested timing of agent phases: plan, execute, review)
#   - Cost tracking (per-agent, per-cycle, cumulative)
#   - Dashboard output (ASCII summary or JSON export)
#
# Design: no external dependencies. Metrics stored as append-only JSONL files.
# Traces stored in .orchystraw/traces/. Dashboards rendered to stdout.
#
# Usage:
#   source src/core/observability.sh
#
#   orch_obs_init "/path/to/project"
#   orch_obs_start_span "06-backend" "execute"
#   ... (agent work) ...
#   orch_obs_end_span "06-backend" "execute"
#   orch_obs_record_metric "06-backend" "tokens_used" 15000
#   orch_obs_record_metric "06-backend" "cost_usd" 0.045
#   orch_obs_dashboard
#   orch_obs_export_json > metrics.json
#
# Requires: bash 5.0+
# =============================================================================

[[ -n "${_ORCH_OBS_LOADED:-}" ]] && return 0
readonly _ORCH_OBS_LOADED=1

# ── State ──
declare -g _ORCH_OBS_DIR=""
declare -g _ORCH_OBS_INITED=false
declare -g -A _ORCH_OBS_SPANS=()          # "agent:phase" -> start_epoch
declare -g -A _ORCH_OBS_LATENCIES=()      # "agent:phase" -> milliseconds
declare -g -A _ORCH_OBS_METRICS=()        # "agent:metric_name" -> value
declare -g -a _ORCH_OBS_EVENTS=()         # append-only event log
declare -g -i _ORCH_OBS_CYCLE=0

# ── Helpers ──

_orch_obs_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "observability" "$2"
    else
        printf '[%s] [%s] [observability] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >&2
    fi
}

_orch_obs_now_ms() {
    # Epoch milliseconds (bash 5+ EPOCHREALTIME has microseconds, fallback to seconds*1000)
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
        # EPOCHREALTIME is like "1712345678.123456" — we want milliseconds
        local secs="${EPOCHREALTIME%%.*}"
        local frac="${EPOCHREALTIME#*.}"
        # Pad/truncate fractional part to 3 digits (milliseconds)
        frac="${frac:0:3}"
        while [[ ${#frac} -lt 3 ]]; do frac="${frac}0"; done
        printf '%s%s' "$secs" "$frac"
    else
        printf '%d000' "$(date '+%s')"
    fi
}

_orch_obs_now_iso() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

# ── Public API ──

# ---------------------------------------------------------------------------
# orch_obs_init — initialize observability
# Args: $1 — project root directory
# ---------------------------------------------------------------------------
orch_obs_init() {
    local project_root="${1:?orch_obs_init requires a project directory}"

    _ORCH_OBS_DIR="${project_root}/.orchystraw/observability"
    mkdir -p "$_ORCH_OBS_DIR" 2>/dev/null || {
        _orch_obs_log ERROR "cannot create observability dir: $_ORCH_OBS_DIR"
        return 1
    }

    _ORCH_OBS_SPANS=()
    _ORCH_OBS_LATENCIES=()
    _ORCH_OBS_METRICS=()
    _ORCH_OBS_EVENTS=()
    _ORCH_OBS_INITED=true

    _orch_obs_log INFO "initialized: dir=$_ORCH_OBS_DIR"
}

# ---------------------------------------------------------------------------
# orch_obs_set_cycle — set the current cycle number
# ---------------------------------------------------------------------------
orch_obs_set_cycle() {
    _ORCH_OBS_CYCLE="${1:-0}"
}

# ---------------------------------------------------------------------------
# orch_obs_start_span — start a timing span for an agent phase
# Args: $1 — agent_id, $2 — phase name (plan/execute/review/etc.)
# ---------------------------------------------------------------------------
orch_obs_start_span() {
    local agent="${1:?start_span: agent required}"
    local phase="${2:?start_span: phase required}"
    local key="${agent}:${phase}"

    _ORCH_OBS_SPANS["$key"]=$(_orch_obs_now_ms)

    _ORCH_OBS_EVENTS+=("{\"type\":\"span_start\",\"agent\":\"${agent}\",\"phase\":\"${phase}\",\"ts\":\"$(_orch_obs_now_iso)\",\"cycle\":${_ORCH_OBS_CYCLE}}")
}

# ---------------------------------------------------------------------------
# orch_obs_end_span — end a timing span, record latency
# Args: $1 — agent_id, $2 — phase name
# Returns: latency in milliseconds on stdout
# ---------------------------------------------------------------------------
orch_obs_end_span() {
    local agent="${1:?end_span: agent required}"
    local phase="${2:?end_span: phase required}"
    local key="${agent}:${phase}"

    local start="${_ORCH_OBS_SPANS[$key]:-0}"
    if [[ "$start" -eq 0 ]]; then
        _orch_obs_log WARN "end_span: no matching start for $key"
        echo "0"
        return 1
    fi

    local end_ms
    end_ms=$(_orch_obs_now_ms)
    local latency=$(( end_ms - start ))
    _ORCH_OBS_LATENCIES["$key"]=$latency

    unset '_ORCH_OBS_SPANS[$key]'

    _ORCH_OBS_EVENTS+=("{\"type\":\"span_end\",\"agent\":\"${agent}\",\"phase\":\"${phase}\",\"latency_ms\":${latency},\"ts\":\"$(_orch_obs_now_iso)\",\"cycle\":${_ORCH_OBS_CYCLE}}")

    echo "$latency"
}

# ---------------------------------------------------------------------------
# orch_obs_record_metric — record a named metric for an agent
# Args: $1 — agent_id, $2 — metric name, $3 — value (numeric)
# ---------------------------------------------------------------------------
orch_obs_record_metric() {
    local agent="${1:?record_metric: agent required}"
    local metric="${2:?record_metric: metric name required}"
    local value="${3:-0}"
    local key="${agent}:${metric}"

    # Accumulate (add to existing value)
    local existing="${_ORCH_OBS_METRICS[$key]:-0}"
    # Use bc for float addition if available, else integer
    if command -v bc &>/dev/null && [[ "$value" == *"."* || "$existing" == *"."* ]]; then
        _ORCH_OBS_METRICS["$key"]=$(echo "$existing + $value" | bc -l 2>/dev/null || echo "$value")
    else
        _ORCH_OBS_METRICS["$key"]=$(( existing + value ))
    fi

    _ORCH_OBS_EVENTS+=("{\"type\":\"metric\",\"agent\":\"${agent}\",\"metric\":\"${metric}\",\"value\":${value},\"ts\":\"$(_orch_obs_now_iso)\",\"cycle\":${_ORCH_OBS_CYCLE}}")
}

# ---------------------------------------------------------------------------
# orch_obs_get_metric — get current value of a metric
# ---------------------------------------------------------------------------
orch_obs_get_metric() {
    local agent="${1:?get_metric: agent required}"
    local metric="${2:?get_metric: metric name required}"
    echo "${_ORCH_OBS_METRICS[${agent}:${metric}]:-0}"
}

# ---------------------------------------------------------------------------
# orch_obs_get_latency — get recorded latency for a span
# ---------------------------------------------------------------------------
orch_obs_get_latency() {
    local agent="${1:?get_latency: agent required}"
    local phase="${2:?get_latency: phase required}"
    echo "${_ORCH_OBS_LATENCIES[${agent}:${phase}]:-0}"
}

# ---------------------------------------------------------------------------
# orch_obs_record_error — record an error event
# Args: $1 — agent_id, $2 — error message
# ---------------------------------------------------------------------------
orch_obs_record_error() {
    local agent="${1:?record_error: agent required}"
    local msg="${2:-unknown error}"

    orch_obs_record_metric "$agent" "errors" 1
    _ORCH_OBS_EVENTS+=("{\"type\":\"error\",\"agent\":\"${agent}\",\"message\":\"${msg}\",\"ts\":\"$(_orch_obs_now_iso)\",\"cycle\":${_ORCH_OBS_CYCLE}}")
}

# ---------------------------------------------------------------------------
# orch_obs_dashboard — print ASCII dashboard to stdout
# ---------------------------------------------------------------------------
orch_obs_dashboard() {
    printf '\n'
    printf '=============================================================================\n'
    printf '  OrchyStraw — Observability Dashboard (Cycle %d)\n' "$_ORCH_OBS_CYCLE"
    printf '=============================================================================\n\n'

    # Collect unique agents
    local -A agents=()
    local key
    for key in "${!_ORCH_OBS_METRICS[@]}"; do
        local agent="${key%%:*}"
        agents["$agent"]=1
    done
    for key in "${!_ORCH_OBS_LATENCIES[@]}"; do
        local agent="${key%%:*}"
        agents["$agent"]=1
    done

    if [[ ${#agents[@]} -eq 0 ]]; then
        printf '  No metrics recorded yet.\n\n'
        return 0
    fi

    printf '  %-14s %10s %10s %10s %10s %8s\n' "Agent" "Tokens" "Cost(\$)" "Latency" "Errors" "Phases"
    printf '  %-14s %10s %10s %10s %10s %8s\n' "--------------" "----------" "----------" "----------" "----------" "--------"

    local agent
    for agent in $(printf '%s\n' "${!agents[@]}" | sort); do
        local tokens="${_ORCH_OBS_METRICS[${agent}:tokens_used]:-0}"
        local cost="${_ORCH_OBS_METRICS[${agent}:cost_usd]:-0}"
        local errors="${_ORCH_OBS_METRICS[${agent}:errors]:-0}"

        # Sum latencies for this agent
        local total_latency=0
        local phase_count=0
        for key in "${!_ORCH_OBS_LATENCIES[@]}"; do
            if [[ "$key" == "${agent}:"* ]]; then
                total_latency=$(( total_latency + _ORCH_OBS_LATENCIES[$key] ))
                phase_count=$((phase_count + 1))
            fi
        done

        local latency_str
        if [[ $total_latency -gt 60000 ]]; then
            latency_str="$(( total_latency / 60000 ))m$(( (total_latency % 60000) / 1000 ))s"
        elif [[ $total_latency -gt 1000 ]]; then
            latency_str="$(( total_latency / 1000 ))s"
        else
            latency_str="${total_latency}ms"
        fi

        printf '  %-14s %10s %10s %10s %10s %8s\n' "$agent" "$tokens" "$cost" "$latency_str" "$errors" "$phase_count"
    done

    printf '\n'

    # Totals
    local total_tokens=0 total_cost=0 total_errors=0
    for key in "${!_ORCH_OBS_METRICS[@]}"; do
        case "$key" in
            *:tokens_used) total_tokens=$(( total_tokens + _ORCH_OBS_METRICS[$key] )) ;;
            *:errors)      total_errors=$(( total_errors + _ORCH_OBS_METRICS[$key] )) ;;
        esac
    done

    if command -v bc &>/dev/null; then
        for key in "${!_ORCH_OBS_METRICS[@]}"; do
            [[ "$key" == *:cost_usd ]] && total_cost=$(echo "$total_cost + ${_ORCH_OBS_METRICS[$key]}" | bc -l 2>/dev/null || true)
        done
    fi

    printf '  TOTALS: %d tokens | $%s | %d errors | %d events\n' "$total_tokens" "$total_cost" "$total_errors" "${#_ORCH_OBS_EVENTS[@]}"
    printf '\n=============================================================================\n\n'
}

# ---------------------------------------------------------------------------
# orch_obs_export_json — export all events as JSONL to stdout
# ---------------------------------------------------------------------------
orch_obs_export_json() {
    for event in "${_ORCH_OBS_EVENTS[@]}"; do
        printf '%s\n' "$event"
    done
}

# ---------------------------------------------------------------------------
# orch_obs_flush — persist events to disk and clear in-memory buffer
# ---------------------------------------------------------------------------
orch_obs_flush() {
    if [[ "$_ORCH_OBS_INITED" != "true" || -z "$_ORCH_OBS_DIR" ]]; then
        _orch_obs_log WARN "flush: not initialized"
        return 1
    fi

    local outfile="${_ORCH_OBS_DIR}/events-cycle-${_ORCH_OBS_CYCLE}.jsonl"
    orch_obs_export_json >> "$outfile"

    local count=${#_ORCH_OBS_EVENTS[@]}
    _ORCH_OBS_EVENTS=()
    _orch_obs_log INFO "flushed ${count} events to ${outfile}"
}

# ---------------------------------------------------------------------------
# orch_obs_event_count — return number of recorded events
# ---------------------------------------------------------------------------
orch_obs_event_count() {
    echo "${#_ORCH_OBS_EVENTS[@]}"
}
