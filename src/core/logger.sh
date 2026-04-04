#!/usr/bin/env bash
# =============================================================================
# logger.sh — Structured logging library for OrchyStraw
#
# Sourceable module for auto-agent.sh integration. Provides leveled logging
# with timestamps, component tagging, file output, per-cycle summary,
# JSON structured logging, log rotation, and color support detection.
#
# Usage:
#   source src/core/logger.sh
#   orch_log_init logs
#   orch_log INFO 06-backend "Cycle started"
#
# Environment:
#   ORCH_QUIET=1        — suppress stdout output (file logging still active)
#   ORCH_LOG_LEVEL      — minimum level to emit: DEBUG|INFO|WARN|ERROR|FATAL
#                         defaults to INFO
#   ORCH_LOG_FORMAT      — "text" (default) or "json" for structured JSON output
#   ORCH_LOG_MAX_SIZE    — max log file size in bytes before rotation (default: 10485760 = 10MB)
#   ORCH_LOG_MAX_FILES   — max rotated files to keep (default: 5)
#   ORCH_LOG_COLOR       — "auto" (default), "always", or "never"
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

# Default log format: "text" or "json"
ORCH_LOG_FORMAT="${ORCH_LOG_FORMAT:-text}"

# Log rotation settings
ORCH_LOG_MAX_SIZE="${ORCH_LOG_MAX_SIZE:-10485760}"   # 10MB default
ORCH_LOG_MAX_FILES="${ORCH_LOG_MAX_FILES:-5}"

# Color mode: auto, always, never
ORCH_LOG_COLOR="${ORCH_LOG_COLOR:-auto}"

# Cached color support flag (set once by _orch_detect_color)
_ORCH_COLOR_SUPPORTED=""

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_detect_color — detect terminal color support, cache result
# Sets _ORCH_COLOR_SUPPORTED to "1" or "0"
_orch_detect_color() {
    if [[ -n "$_ORCH_COLOR_SUPPORTED" ]]; then
        return
    fi

    case "$ORCH_LOG_COLOR" in
        always)
            _ORCH_COLOR_SUPPORTED=1
            return
            ;;
        never)
            _ORCH_COLOR_SUPPORTED=0
            return
            ;;
    esac

    # auto detection
    _ORCH_COLOR_SUPPORTED=0

    # Check if stdout is a terminal
    [[ -t 1 ]] || return 0

    # Check TERM is not dumb
    [[ "${TERM:-dumb}" != "dumb" ]] || return 0

    # Check NO_COLOR convention (https://no-color.org/)
    [[ -z "${NO_COLOR:-}" ]] || return 0

    # Check if tput is available and reports colors
    if command -v tput >/dev/null 2>&1; then
        local colors
        colors=$(tput colors 2>/dev/null || echo 0)
        if [[ "$colors" -ge 8 ]]; then
            _ORCH_COLOR_SUPPORTED=1
            return 0
        fi
    fi

    # Fallback: common TERM values that support color
    case "${TERM:-}" in
        xterm*|screen*|tmux*|rxvt*|linux|cygwin|msys|mingw*)
            _ORCH_COLOR_SUPPORTED=1
            ;;
    esac
}

# _orch_timestamp — emit current timestamp in log format
_orch_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# _orch_timestamp_iso — emit ISO 8601 timestamp for JSON logs
_orch_timestamp_iso() {
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S'
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

# _orch_format_json <level> <component> <message> [extra_fields]
#   Produce a single-line JSON log entry. No external dependencies.
#   Extra fields is an optional string of pre-formatted JSON k/v pairs.
_orch_format_json() {
    local level="$1"
    local component="$2"
    local message="$3"
    local extra="${4:-}"

    # Escape special JSON characters in message
    local escaped_msg
    escaped_msg="$(_orch_json_escape "$message")"
    local escaped_comp
    escaped_comp="$(_orch_json_escape "$component")"

    local json
    json="{\"timestamp\":\"$(_orch_timestamp_iso)\",\"level\":\"${level}\",\"component\":\"${escaped_comp}\",\"message\":\"${escaped_msg}\""

    if [[ -n "$extra" ]]; then
        json="${json},${extra}"
    fi

    json="${json}}"
    printf '%s\n' "$json"
}

# _orch_json_escape <string> — escape a string for safe JSON embedding
_orch_json_escape() {
    local s="$1"
    # Backslash must be first
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# _orch_rotate_log <log_file> — rotate log file if it exceeds ORCH_LOG_MAX_SIZE
_orch_rotate_log() {
    local log_file="$1"

    [[ -f "$log_file" ]] || return 0

    local file_size=0
    if [[ -r "$log_file" ]]; then
        # Portable file size: wc -c
        file_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
        # Strip whitespace (wc output varies)
        file_size="${file_size//[[:space:]]/}"
    fi

    if [[ "$file_size" -lt "$ORCH_LOG_MAX_SIZE" ]]; then
        return 0
    fi

    # Rotate: file.log -> file.log.1, file.log.1 -> file.log.2, etc.
    local i
    # Remove the oldest if at max
    local oldest="${log_file}.${ORCH_LOG_MAX_FILES}"
    [[ -f "$oldest" ]] && rm -f "$oldest"

    # Shift existing rotated files up
    i=$((ORCH_LOG_MAX_FILES - 1))
    while [[ "$i" -ge 1 ]]; do
        local src="${log_file}.${i}"
        local dst="${log_file}.$(( i + 1 ))"
        [[ -f "$src" ]] && mv -f "$src" "$dst"
        (( i-- ))
    done

    # Move current to .1
    mv -f "$log_file" "${log_file}.1"

    # Touch new empty file
    : > "$log_file"
}

# _orch_colorize <level> <line> — print colorized line to stdout
_orch_colorize() {
    local level="$1"
    local line="$2"

    _orch_detect_color

    if [[ "$_ORCH_COLOR_SUPPORTED" == "1" ]]; then
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
    if [[ "$ORCH_LOG_FORMAT" == "json" ]]; then
        _orch_format_json "INFO" "logger" "Log initialised: $_ORCH_LOG_FILE (cycle ${next_cycle})" \
            "\"cycle\":${next_cycle},\"event\":\"init\"" >> "$_ORCH_LOG_FILE"
    else
        local header
        header="$(printf '=%.0s' {1..72})"
        {
            printf '%s\n' "$header"
            printf '  OrchyStraw cycle log — cycle %s — started %s\n' \
                "$next_cycle" "$(_orch_timestamp)"
            printf '%s\n' "$header"
        } >> "$_ORCH_LOG_FILE"
    fi

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

    # Increment counter
    (( _ORCH_LOG_COUNTS[$level]++ )) || true

    # Format the line based on output format
    local line file_line
    if [[ "$ORCH_LOG_FORMAT" == "json" ]]; then
        line="$(_orch_format_json "$level" "$component" "$message")"
        file_line="$line"
    else
        line="$(_orch_format "$level" "$component" "$message")"
        file_line="$line"
    fi

    # Write to stdout unless quiet
    if [[ "${ORCH_QUIET:-0}" != "1" ]]; then
        if [[ "$ORCH_LOG_FORMAT" == "json" ]]; then
            printf '%s\n' "$line"
        else
            _orch_colorize "$level" "$line"
        fi
    fi

    # Write to active log file if initialised
    if [[ -n "$_ORCH_LOG_FILE" ]]; then
        # Check rotation before writing
        _orch_rotate_log "$_ORCH_LOG_FILE"
        printf '%s\n' "$file_line" >> "$_ORCH_LOG_FILE"
    fi
}

# orch_log_json <level> <component> <message> <extra_json_fields>
#   Log with extra JSON key-value pairs. Always produces JSON regardless of ORCH_LOG_FORMAT.
#   extra_json_fields should be pre-formatted: "\"key\":\"val\",\"key2\":123"
orch_log_json() {
    local level="${1:?orch_log_json: level required}"
    local component="${2:?orch_log_json: component required}"
    local message="${3:?orch_log_json: message required}"
    local extra="${4:-}"

    level="${level^^}"
    if [[ -z "${_ORCH_LEVEL_ORDER[$level]+x}" ]]; then
        level="INFO"
    fi

    _orch_level_enabled "$level" || return 0

    (( _ORCH_LOG_COUNTS[$level]++ )) || true

    local line
    line="$(_orch_format_json "$level" "$component" "$message" "$extra")"

    if [[ "${ORCH_QUIET:-0}" != "1" ]]; then
        printf '%s\n' "$line"
    fi

    if [[ -n "$_ORCH_LOG_FILE" ]]; then
        _orch_rotate_log "$_ORCH_LOG_FILE"
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
    if [[ "$ORCH_LOG_FORMAT" == "json" ]]; then
        line="$(_orch_format_json "$level" "$component" "$message")"
    else
        line="$(_orch_format "$level" "$component" "$message")"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$file")"

    # Check rotation on target file
    _orch_rotate_log "$file"
    printf '%s\n' "$line" >> "$file"

    # Also increment shared counters so the summary stays accurate
    (( _ORCH_LOG_COUNTS[$level]++ )) || true

    # Echo to stdout unless quiet
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

    if [[ "$ORCH_LOG_FORMAT" == "json" ]]; then
        local summary
        summary="$(_orch_format_json "INFO" "logger" "Log summary" \
            "\"event\":\"summary\",\"warn_count\":${warn_count},\"error_count\":${error_count},\"fatal_count\":${fatal_count},\"total_issues\":${total_issues}")"

        if [[ "${ORCH_QUIET:-0}" != "1" ]]; then
            printf '%s\n' "$summary"
        fi
        if [[ -n "$_ORCH_LOG_FILE" ]]; then
            printf '%s\n' "$summary" >> "$_ORCH_LOG_FILE"
        fi
    else
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
    fi
}

# orch_log_color_supported — return 0 if color is supported, 1 otherwise
orch_log_color_supported() {
    _orch_detect_color
    [[ "$_ORCH_COLOR_SUPPORTED" == "1" ]]
}
