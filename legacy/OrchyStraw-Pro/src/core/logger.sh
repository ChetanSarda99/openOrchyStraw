#!/usr/bin/env bash
# =============================================================================
# logger.sh — Structured logging library for OrchyStraw
#
# Sourceable module for auto-agent.sh integration. Provides leveled logging
# with timestamps, component tagging, file output, and a per-cycle summary.
#
# Usage:
#   source src/core/logger.sh
#   orch_log_init logs
#   orch_log INFO 06-backend "Cycle started"
#
# Environment:
#   ORCH_QUIET=1   — suppress stdout output (file logging still active)
#   ORCH_LOG_LEVEL — minimum level to emit: DEBUG|INFO|WARN|ERROR|FATAL
#                    defaults to INFO
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_LOGGER_LOADED:-}" ]] && return 0
_ORCH_LOGGER_LOADED=1

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

# Current active log file (set by orch_log_init)
_ORCH_LOG_FILE=""

# Counters (bash associative array — requires bash 5.x)
declare -A _ORCH_LOG_COUNTS=(
    [DEBUG]=0
    [INFO]=0
    [WARN]=0
    [ERROR]=0
    [FATAL]=0
)

# Level ordering (lower index = lower severity)
declare -A _ORCH_LEVEL_ORDER=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

# Default minimum level
ORCH_LOG_LEVEL="${ORCH_LOG_LEVEL:-INFO}"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_timestamp — emit current timestamp in log format
_orch_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# _orch_level_enabled <level> — return 0 if level should be emitted
_orch_level_enabled() {
    local level="$1"
    local min_order="${_ORCH_LEVEL_ORDER[$ORCH_LOG_LEVEL]:-1}"
    local this_order="${_ORCH_LEVEL_ORDER[$level]:-1}"
    [[ "$this_order" -ge "$min_order" ]]
}

# _orch_format <level> <component> <message> — produce a formatted log line
_orch_format() {
    local level="$1"
    local component="$2"
    local message="$3"
    printf '[%s] [%-5s] [%s] %s\n' "$(_orch_timestamp)" "$level" "$component" "$message"
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# orch_log_init <log_dir>
#   Set up log directory and create a new cycle log file.
#   The cycle number is auto-incremented based on existing cycle-N.log files.
#   Sets _ORCH_LOG_FILE.
orch_log_init() {
    local log_dir="${1:?orch_log_init: log_dir required}"

    mkdir -p "$log_dir"

    # Determine next cycle number
    local max_cycle=0
    local f cycle_num
    for f in "$log_dir"/cycle-*.log; do
        [[ -e "$f" ]] || continue
        # Extract the number from cycle-N.log
        cycle_num="${f##*/cycle-}"
        cycle_num="${cycle_num%.log}"
        if [[ "$cycle_num" =~ ^[0-9]+$ ]] && [[ "$cycle_num" -gt "$max_cycle" ]]; then
            max_cycle="$cycle_num"
        fi
    done

    local next_cycle=$(( max_cycle + 1 ))
    _ORCH_LOG_FILE="${log_dir}/cycle-${next_cycle}.log"

    # Reset counters for this session
    _ORCH_LOG_COUNTS=( [DEBUG]=0 [INFO]=0 [WARN]=0 [ERROR]=0 [FATAL]=0 )

    # Write session header
    local header
    header="$(printf '=%.0s' {1..72})"
    {
        printf '%s\n' "$header"
        printf '  OrchyStraw cycle log — cycle %s — started %s\n' \
            "$next_cycle" "$(_orch_timestamp)"
        printf '%s\n' "$header"
    } >> "$_ORCH_LOG_FILE"

    orch_log INFO logger "Log initialised: $_ORCH_LOG_FILE (cycle ${next_cycle})"
}

# orch_log <level> <component> <message>
#   Log to the active log file (if initialised) and stdout (unless ORCH_QUIET=1).
#   Level must be one of: DEBUG INFO WARN ERROR FATAL
orch_log() {
    local level="${1:?orch_log: level required}"
    local component="${2:?orch_log: component required}"
    local message="${3:?orch_log: message required}"

    # Normalise level to uppercase
    level="${level^^}"

    # Validate level
    if [[ -z "${_ORCH_LEVEL_ORDER[$level]+x}" ]]; then
        level="INFO"
    fi

    # Check minimum level filter
    _orch_level_enabled "$level" || return 0

    local line
    line="$(_orch_format "$level" "$component" "$message")"

    # Increment counter
    (( _ORCH_LOG_COUNTS[$level]++ )) || true

    # Write to stdout unless quiet
    if [[ "${ORCH_QUIET:-0}" != "1" ]]; then
        # Colourize based on level when outputting to a terminal
        if [[ -t 1 ]]; then
            case "$level" in
                DEBUG) printf '\033[0;90m%s\033[0m\n' "$line" ;;   # dark grey
                INFO)  printf '%s\n' "$line" ;;                     # default
                WARN)  printf '\033[0;33m%s\033[0m\n' "$line" ;;   # yellow
                ERROR) printf '\033[0;31m%s\033[0m\n' "$line" ;;   # red
                FATAL) printf '\033[1;31m%s\033[0m\n' "$line" ;;   # bold red
                *)     printf '%s\n' "$line" ;;
            esac
        else
            printf '%s\n' "$line"
        fi
    fi

    # Write to active log file if initialised
    if [[ -n "$_ORCH_LOG_FILE" ]]; then
        printf '%s\n' "$line" >> "$_ORCH_LOG_FILE"
    fi
}

# orch_log_to_file <file> <level> <component> <message>
#   Log to a specific file regardless of the active log file.
#   Also honours ORCH_QUIET and the level filter.
orch_log_to_file() {
    local file="${1:?orch_log_to_file: file required}"
    local level="${2:?orch_log_to_file: level required}"
    local component="${3:?orch_log_to_file: component required}"
    local message="${4:?orch_log_to_file: message required}"

    level="${level^^}"
    if [[ -z "${_ORCH_LEVEL_ORDER[$level]+x}" ]]; then
        level="INFO"
    fi

    _orch_level_enabled "$level" || return 0

    local line
    line="$(_orch_format "$level" "$component" "$message")"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$line" >> "$file"

    # Also increment shared counters so the summary stays accurate
    (( _ORCH_LOG_COUNTS[$level]++ )) || true

    # Echo to stdout unless quiet (no colour — specific-file calls are usually programmatic)
    if [[ "${ORCH_QUIET:-0}" != "1" ]]; then
        printf '%s\n' "$line"
    fi
}

# orch_log_summary
#   Print a summary of log counts for WARN, ERROR, and FATAL from this session.
#   Writes to stdout and, if a log file is active, appends to it as well.
orch_log_summary() {
    local warn_count="${_ORCH_LOG_COUNTS[WARN]:-0}"
    local error_count="${_ORCH_LOG_COUNTS[ERROR]:-0}"
    local fatal_count="${_ORCH_LOG_COUNTS[FATAL]:-0}"
    local total_issues=$(( warn_count + error_count + fatal_count ))

    local sep
    sep="$(printf '=%.0s' {1..72})"

    local summary
    summary="$(printf '%s\nLog summary — %s\n  WARN: %d  ERROR: %d  FATAL: %d  (total issues: %d)\n%s\n' \
        "$sep" "$(_orch_timestamp)" \
        "$warn_count" "$error_count" "$fatal_count" "$total_issues" \
        "$sep")"

    if [[ "${ORCH_QUIET:-0}" != "1" ]]; then
        printf '%s\n' "$summary"
    fi

    if [[ -n "$_ORCH_LOG_FILE" ]]; then
        printf '%s\n' "$summary" >> "$_ORCH_LOG_FILE"
    fi
}
