#!/usr/bin/env bash
# error-handler.sh — Sourceable bash library for graceful agent error handling
# Usage: source src/core/error-handler.sh
#
# Public API:
#   orch_handle_agent_failure <agent_id> <exit_code> <log_file>
#   orch_should_retry         <agent_id> <failure_count>
#   orch_failure_report       <cycle_num>
#   orch_reset_failures

# Guard against double-sourcing
[[ -n "${_ORCH_ERROR_HANDLER_LOADED:-}" ]] && return 0
readonly _ORCH_ERROR_HANDLER_LOADED=1

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

# Associative array: keys are "<agent_id>:<field>", values are stored data.
# Fields per agent: exit_code, timestamp, last_output, count
declare -gA _ORCH_FAILURES=()

# Maximum number of retries before giving up on an agent.
readonly _ORCH_MAX_RETRIES=2

# ---------------------------------------------------------------------------
# orch_handle_agent_failure <agent_id> <exit_code> <log_file>
#
# Records a failure entry and prints structured diagnostic info to stderr.
# Outputs a newline-delimited block of key=value pairs to stdout so callers
# can capture it with $(...) if needed.
# ---------------------------------------------------------------------------
orch_handle_agent_failure() {
    local agent_id="${1:?orch_handle_agent_failure: agent_id required}"
    local exit_code="${2:?orch_handle_agent_failure: exit_code required}"
    local log_file="${3:-}"

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Capture last 20 lines of the agent log for diagnostics.
    local last_output=""
    if [[ -n "${log_file}" && -r "${log_file}" ]]; then
        last_output="$(tail -n 20 "${log_file}" 2>/dev/null || true)"
    fi

    # Increment failure count for this agent.
    local count_key="${agent_id}:count"
    local current_count="${_ORCH_FAILURES[${count_key}]:-0}"
    (( current_count++ )) || true
    _ORCH_FAILURES["${count_key}"]="${current_count}"

    # Store structured fields.
    _ORCH_FAILURES["${agent_id}:exit_code"]="${exit_code}"
    _ORCH_FAILURES["${agent_id}:timestamp"]="${timestamp}"
    _ORCH_FAILURES["${agent_id}:last_output"]="${last_output}"

    # Log to stderr so it doesn't pollute stdout captures.
    printf '[error-handler] AGENT FAILURE: id=%s exit_code=%s time=%s failure_count=%s\n' \
        "${agent_id}" "${exit_code}" "${timestamp}" "${current_count}" >&2

    if [[ -n "${last_output}" ]]; then
        printf '[error-handler] Last 20 lines of %s:\n' "${log_file:-<no log>}" >&2
        printf '%s\n' "${last_output}" | sed 's/^/  | /' >&2
    else
        printf '[error-handler] No log output available for %s\n' "${agent_id}" >&2
    fi

    # Emit structured info to stdout for callers that capture it.
    printf 'agent_id=%s\n'      "${agent_id}"
    printf 'exit_code=%s\n'     "${exit_code}"
    printf 'timestamp=%s\n'     "${timestamp}"
    printf 'failure_count=%s\n' "${current_count}"
    printf 'last_output<<EOF\n%s\nEOF\n' "${last_output}"
}

# ---------------------------------------------------------------------------
# orch_should_retry <agent_id> <failure_count>
#
# Returns 0 (true) if the agent should be retried, 1 (false) if it has
# exhausted its retry budget.
# ---------------------------------------------------------------------------
orch_should_retry() {
    local agent_id="${1:?orch_should_retry: agent_id required}"
    local failure_count="${2:?orch_should_retry: failure_count required}"

    if (( failure_count <= _ORCH_MAX_RETRIES )); then
        printf '[error-handler] %s: retry %s/%s permitted\n' \
            "${agent_id}" "${failure_count}" "${_ORCH_MAX_RETRIES}" >&2
        return 0
    else
        printf '[error-handler] %s: max retries (%s) exhausted — skipping\n' \
            "${agent_id}" "${_ORCH_MAX_RETRIES}" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# orch_failure_report <cycle_num>
#
# Prints a human-readable summary of all failures recorded this cycle.
# Output goes to stdout; suitable for appending to a cycle log.
# ---------------------------------------------------------------------------
orch_failure_report() {
    local cycle_num="${1:?orch_failure_report: cycle_num required}"

    local sep="────────────────────────────────────────"

    printf '\n%s\n' "${sep}"
    printf 'FAILURE REPORT — Cycle %s\n' "${cycle_num}"
    printf 'Generated: %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf '%s\n' "${sep}"

    # Collect unique agent IDs from the _ORCH_FAILURES keys.
    local -a agent_ids=()
    local key
    for key in "${!_ORCH_FAILURES[@]}"; do
        local maybe_id="${key%%:*}"
        # Deduplicate by checking if already present.
        local already=0
        local existing
        for existing in "${agent_ids[@]:-}"; do
            [[ "${existing}" == "${maybe_id}" ]] && already=1 && break
        done
        (( already == 0 )) && agent_ids+=("${maybe_id}")
    done

    if (( ${#agent_ids[@]} == 0 )); then
        printf 'No failures recorded this cycle.\n'
        printf '%s\n\n' "${sep}"
        return 0
    fi

    printf 'Total agents with failures: %s\n\n' "${#agent_ids[@]}"

    local agent
    for agent in "${agent_ids[@]}"; do
        local exit_code="${_ORCH_FAILURES["${agent}:exit_code"]:-unknown}"
        local timestamp="${_ORCH_FAILURES["${agent}:timestamp"]:-unknown}"
        local count="${_ORCH_FAILURES["${agent}:count"]:-0}"
        local last_output="${_ORCH_FAILURES["${agent}:last_output"]:-}"

        printf 'Agent:         %s\n'  "${agent}"
        printf 'Failures:      %s/%s\n' "${count}" "${_ORCH_MAX_RETRIES}"
        printf 'Last exit:     %s\n'  "${exit_code}"
        printf 'Last seen:     %s\n'  "${timestamp}"
        printf 'Status:        %s\n'  "$( (( count > _ORCH_MAX_RETRIES )) && printf 'ABANDONED' || printf 'RETRYABLE' )"

        if [[ -n "${last_output}" ]]; then
            printf 'Last output (tail):\n'
            printf '%s\n' "${last_output}" | sed 's/^/  | /'
        else
            printf 'Last output:   <none captured>\n'
        fi

        printf '%s\n' "${sep}"
    done

    printf '\n'
}

# ---------------------------------------------------------------------------
# orch_reset_failures
#
# Clears all tracked failure state. Call at the start of each new cycle.
# ---------------------------------------------------------------------------
orch_reset_failures() {
    _ORCH_FAILURES=()
    printf '[error-handler] Failure tracking reset\n' >&2
}
