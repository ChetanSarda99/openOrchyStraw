#!/usr/bin/env bash
# error-handler.sh — Sourceable bash library for graceful agent error handling
# Usage: source src/core/error-handler.sh
#
# Public API:
#   orch_handle_agent_failure <agent_id> <exit_code> <log_file>
#   orch_should_retry         <agent_id> <failure_count>
#   orch_failure_report       <cycle_num>
#   orch_reset_failures
#   orch_stack_trace          — capture and format bash call stack
#   orch_categorize_error     <exit_code> — return error category string
#   orch_retry_with_backoff   <max_retries> <command...> — retry with exponential backoff
#   orch_set_error_handler    — install ERR trap that captures stack traces

# Guard against double-sourcing
[[ -n "${_ORCH_ERROR_HANDLER_LOADED:-}" ]] && return 0
readonly _ORCH_ERROR_HANDLER_LOADED=1

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

# Associative array: keys are "<agent_id>:<field>", values are stored data.
# Fields per agent: exit_code, timestamp, last_output, count, category, stack_trace
declare -gA _ORCH_FAILURES=()

# Maximum number of retries before giving up on an agent.
readonly _ORCH_MAX_RETRIES=2

# Error categories
declare -gA _ORCH_ERROR_CATEGORIES=(
    [1]="general"
    [2]="misuse"
    [126]="permission"
    [127]="not_found"
    [128]="signal"
    [124]="timeout"
    [137]="killed"       # SIGKILL (128+9)
    [139]="segfault"     # SIGSEGV (128+11)
    [143]="terminated"   # SIGTERM (128+15)
)

# Retry configuration
ORCH_BACKOFF_BASE="${ORCH_BACKOFF_BASE:-1}"         # Base delay in seconds
ORCH_BACKOFF_MAX="${ORCH_BACKOFF_MAX:-60}"           # Maximum delay cap in seconds
ORCH_BACKOFF_JITTER="${ORCH_BACKOFF_JITTER:-1}"      # Add jitter: 1=yes, 0=no

# Last captured stack trace (set by orch_stack_trace or ERR trap)
_ORCH_LAST_STACK_TRACE=""

# ---------------------------------------------------------------------------
# orch_stack_trace [skip_frames]
#
# Captures the current bash call stack and stores it in _ORCH_LAST_STACK_TRACE.
# Also prints the stack trace to stderr.
# skip_frames: number of stack frames to skip from the top (default: 1, skips this function)
# ---------------------------------------------------------------------------
orch_stack_trace() {
    local skip="${1:-1}"
    local trace=""
    local frame=0
    local i

    trace="Stack trace (most recent call last):"$'\n'

    # BASH_SOURCE, BASH_LINENO, FUNCNAME are bash built-in arrays
    local depth="${#FUNCNAME[@]}"

    i=$((depth - 1))
    while [[ "$i" -ge "$skip" ]]; do
        local func="${FUNCNAME[$i]:-main}"
        local src="${BASH_SOURCE[$i]:-unknown}"
        local line="${BASH_LINENO[$((i - 1))]:-0}"
        # Make source path relative if possible
        src="${src##*/}"
        trace+="  #${frame} ${src}:${line} in ${func}()"$'\n'
        (( frame++ )) || true
        (( i-- )) || true
    done

    _ORCH_LAST_STACK_TRACE="$trace"
    printf '%s' "$trace" >&2
}

# ---------------------------------------------------------------------------
# _orch_err_trap_handler
#
# Internal handler for ERR trap. Captures stack trace automatically.
# ---------------------------------------------------------------------------
_orch_err_trap_handler() {
    local exit_code=$?
    # Skip 2 frames: this handler + the trap dispatch
    orch_stack_trace 2
    return "$exit_code"
}

# ---------------------------------------------------------------------------
# orch_set_error_handler
#
# Installs an ERR trap that automatically captures stack traces on errors.
# Call this at the top of scripts that want automatic stack traces.
# ---------------------------------------------------------------------------
orch_set_error_handler() {
    trap '_orch_err_trap_handler' ERR
}

# ---------------------------------------------------------------------------
# orch_categorize_error <exit_code>
#
# Returns a human-readable error category based on the exit code.
# Categories: general, misuse, permission, not_found, signal, timeout,
#             killed, segfault, terminated, unknown
# ---------------------------------------------------------------------------
orch_categorize_error() {
    local exit_code="${1:?orch_categorize_error: exit_code required}"

    # Direct lookup
    if [[ -n "${_ORCH_ERROR_CATEGORIES[$exit_code]+x}" ]]; then
        printf '%s\n' "${_ORCH_ERROR_CATEGORIES[$exit_code]}"
        return 0
    fi

    # Signal range: 128+N
    if [[ "$exit_code" -gt 128 && "$exit_code" -le 192 ]]; then
        local signal_num=$(( exit_code - 128 ))
        printf 'signal_%d\n' "$signal_num"
        return 0
    fi

    printf 'unknown\n'
}

# ---------------------------------------------------------------------------
# orch_retry_with_backoff <max_retries> <command...>
#
# Executes a command with exponential backoff on failure.
# Backoff formula: min(ORCH_BACKOFF_BASE * 2^attempt, ORCH_BACKOFF_MAX)
# With optional jitter: delay += random(0, delay/2)
#
# Returns:
#   0 if the command eventually succeeds
#   Last exit code if all retries are exhausted
#
# Environment:
#   ORCH_BACKOFF_BASE   — base delay in seconds (default: 1)
#   ORCH_BACKOFF_MAX    — maximum delay cap (default: 60)
#   ORCH_BACKOFF_JITTER — add jitter: 1=yes, 0=no (default: 1)
# ---------------------------------------------------------------------------
orch_retry_with_backoff() {
    local max_retries="${1:?orch_retry_with_backoff: max_retries required}"
    shift
    local cmd=("$@")

    if [[ ${#cmd[@]} -eq 0 ]]; then
        printf '[error-handler] ERROR: no command specified for retry\n' >&2
        return 1
    fi

    local attempt=0
    local exit_code=0

    while true; do
        # Execute the command
        "${cmd[@]}" && return 0
        exit_code=$?

        (( attempt++ ))

        if [[ "$attempt" -ge "$max_retries" ]]; then
            printf '[error-handler] Command failed after %d attempts (last exit: %d): %s\n' \
                "$attempt" "$exit_code" "${cmd[*]}" >&2
            return "$exit_code"
        fi

        # Calculate delay: base * 2^attempt, capped at max
        local delay=$(( ORCH_BACKOFF_BASE * (1 << attempt) ))
        if [[ "$delay" -gt "$ORCH_BACKOFF_MAX" ]]; then
            delay="$ORCH_BACKOFF_MAX"
        fi

        # Add jitter if enabled
        if [[ "$ORCH_BACKOFF_JITTER" == "1" && "$delay" -gt 1 ]]; then
            local jitter=$(( RANDOM % (delay / 2 + 1) ))
            delay=$(( delay + jitter ))
            # Re-cap after jitter
            if [[ "$delay" -gt "$ORCH_BACKOFF_MAX" ]]; then
                delay="$ORCH_BACKOFF_MAX"
            fi
        fi

        local category
        category="$(orch_categorize_error "$exit_code")"

        printf '[error-handler] Attempt %d/%d failed (exit: %d, category: %s). Retrying in %ds...\n' \
            "$attempt" "$max_retries" "$exit_code" "$category" "$delay" >&2

        sleep "$delay"
    done
}

# ---------------------------------------------------------------------------
# orch_handle_agent_failure <agent_id> <exit_code> <log_file>
#
# Records a failure entry and prints structured diagnostic info to stderr.
# Now includes error categorization and stack trace if available.
# Outputs a newline-delimited block of key=value pairs to stdout so callers
# can capture it with $(...) if needed.
# ---------------------------------------------------------------------------
orch_handle_agent_failure() {
    local agent_id="${1:?orch_handle_agent_failure: agent_id required}"
    local exit_code="${2:?orch_handle_agent_failure: exit_code required}"
    local log_file="${3:-}"

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Categorize the error
    local category
    category="$(orch_categorize_error "$exit_code")"

    # Capture last 20 lines of the agent log for diagnostics.
    local last_output=""
    if [[ -n "${log_file}" && -r "${log_file}" ]]; then
        last_output="$(tail -n 20 "${log_file}" 2>/dev/null || true)"
    fi

    # Capture stack trace if available
    local stack_trace="${_ORCH_LAST_STACK_TRACE:-}"

    # Increment failure count for this agent.
    local count_key="${agent_id}:count"
    local current_count="${_ORCH_FAILURES[${count_key}]:-0}"
    (( current_count++ )) || true
    _ORCH_FAILURES["${count_key}"]="${current_count}"

    # Store structured fields.
    _ORCH_FAILURES["${agent_id}:exit_code"]="${exit_code}"
    _ORCH_FAILURES["${agent_id}:timestamp"]="${timestamp}"
    _ORCH_FAILURES["${agent_id}:last_output"]="${last_output}"
    _ORCH_FAILURES["${agent_id}:category"]="${category}"
    _ORCH_FAILURES["${agent_id}:stack_trace"]="${stack_trace}"

    # Log to stderr so it doesn't pollute stdout captures.
    printf '[error-handler] AGENT FAILURE: id=%s exit_code=%s category=%s time=%s failure_count=%s\n' \
        "${agent_id}" "${exit_code}" "${category}" "${timestamp}" "${current_count}" >&2

    if [[ -n "${stack_trace}" ]]; then
        printf '[error-handler] Stack trace:\n' >&2
        printf '%s\n' "${stack_trace}" | sed 's/^/  | /' >&2
    fi

    if [[ -n "${last_output}" ]]; then
        printf '[error-handler] Last 20 lines of %s:\n' "${log_file:-<no log>}" >&2
        printf '%s\n' "${last_output}" | sed 's/^/  | /' >&2
    else
        printf '[error-handler] No log output available for %s\n' "${agent_id}" >&2
    fi

    # Emit structured info to stdout for callers that capture it.
    printf 'agent_id=%s\n'      "${agent_id}"
    printf 'exit_code=%s\n'     "${exit_code}"
    printf 'category=%s\n'      "${category}"
    printf 'timestamp=%s\n'     "${timestamp}"
    printf 'failure_count=%s\n' "${current_count}"
    if [[ -n "${stack_trace}" ]]; then
        printf 'stack_trace<<EOF\n%s\nEOF\n' "${stack_trace}"
    fi
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
# Now includes error categories and stack traces.
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
        local category="${_ORCH_FAILURES["${agent}:category"]:-unknown}"
        local last_output="${_ORCH_FAILURES["${agent}:last_output"]:-}"
        local stack_trace="${_ORCH_FAILURES["${agent}:stack_trace"]:-}"

        printf 'Agent:         %s\n'  "${agent}"
        printf 'Failures:      %s/%s\n' "${count}" "${_ORCH_MAX_RETRIES}"
        printf 'Last exit:     %s\n'  "${exit_code}"
        printf 'Category:      %s\n'  "${category}"
        printf 'Last seen:     %s\n'  "${timestamp}"
        printf 'Status:        %s\n'  "$( (( count > _ORCH_MAX_RETRIES )) && printf 'ABANDONED' || printf 'RETRYABLE' )"

        if [[ -n "${stack_trace}" ]]; then
            printf 'Stack trace:\n'
            printf '%s\n' "${stack_trace}" | sed 's/^/  | /'
        fi

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
    _ORCH_LAST_STACK_TRACE=""
    printf '[error-handler] Failure tracking reset\n' >&2
}
