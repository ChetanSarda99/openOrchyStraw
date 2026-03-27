#!/usr/bin/env bash
# cycle-state.sh — Sourceable library for persisting and resuming orchestrator cycle state
#
# Usage:
#   source src/core/cycle-state.sh
#
# State file: .orchystraw/cycle-state (plain text, key=value)
# Exports: ORCH_LAST_CYCLE, ORCH_LAST_STATUS, ORCH_LAST_TIMESTAMP

# Guard against double-sourcing
[[ -n "${_ORCH_CYCLE_STATE_LOADED:-}" ]] && return 0
readonly _ORCH_CYCLE_STATE_LOADED=1

# ---------------------------------------------------------------------------
# Internal constants
# ---------------------------------------------------------------------------

readonly _ORCH_STATE_DIR=".orchystraw"
readonly _ORCH_STATE_FILE="${_ORCH_STATE_DIR}/cycle-state"

# ---------------------------------------------------------------------------
# orch_state_init
#   Create the .orchystraw/ directory if it does not already exist.
# ---------------------------------------------------------------------------
orch_state_init() {
    if [[ ! -d "${_ORCH_STATE_DIR}" ]]; then
        mkdir -p "${_ORCH_STATE_DIR}" || {
            echo "[cycle-state] ERROR: could not create state directory: ${_ORCH_STATE_DIR}" >&2
            return 1
        }
    fi
}

# ---------------------------------------------------------------------------
# orch_state_save <cycle_num> [status]
#   Write cycle state to the state file.
#
#   Arguments:
#     cycle_num  — integer cycle number (required)
#     status     — one of: running | completed | failed  (default: running)
#
#   State file fields written:
#     cycle      — cycle number
#     status     — running / completed / failed
#     timestamp  — time this save was written (always updated)
#     started    — time the cycle started (set only on first save for this cycle)
# ---------------------------------------------------------------------------
orch_state_save() {
    local cycle_num="${1:?orch_state_save requires a cycle number}"
    local status="${2:-running}"
    local now
    now="$(date '+%Y-%m-%d %H:%M:%S')"

    # Validate status
    case "${status}" in
        running|completed|failed) ;;
        *)
            echo "[cycle-state] WARNING: unknown status '${status}', defaulting to 'running'" >&2
            status="running"
            ;;
    esac

    orch_state_init || return 1

    # Preserve existing 'started' timestamp if we already have one for this cycle,
    # so that re-saves (e.g. status updates) don't overwrite the original start time.
    local started="${now}"
    if [[ -f "${_ORCH_STATE_FILE}" ]]; then
        local existing_cycle existing_started
        existing_cycle="$(_orch_state_read_field "cycle")"
        existing_started="$(_orch_state_read_field "started")"
        if [[ "${existing_cycle}" == "${cycle_num}" && -n "${existing_started}" ]]; then
            started="${existing_started}"
        fi
    fi

    {
        printf 'cycle=%s\n'     "${cycle_num}"
        printf 'status=%s\n'    "${status}"
        printf 'timestamp=%s\n' "${now}"
        printf 'started=%s\n'   "${started}"
    } > "${_ORCH_STATE_FILE}" || {
        echo "[cycle-state] ERROR: could not write state file: ${_ORCH_STATE_FILE}" >&2
        return 1
    }
}

# ---------------------------------------------------------------------------
# orch_state_load
#   Read the state file and export:
#     ORCH_LAST_CYCLE      — cycle number (empty string if no state file)
#     ORCH_LAST_STATUS     — status value
#     ORCH_LAST_TIMESTAMP  — timestamp of last save
# ---------------------------------------------------------------------------
orch_state_load() {
    ORCH_LAST_CYCLE=""
    ORCH_LAST_STATUS=""
    ORCH_LAST_TIMESTAMP=""

    if [[ ! -f "${_ORCH_STATE_FILE}" ]]; then
        return 0
    fi

    ORCH_LAST_CYCLE="$(_orch_state_read_field "cycle")"
    ORCH_LAST_STATUS="$(_orch_state_read_field "status")"
    ORCH_LAST_TIMESTAMP="$(_orch_state_read_field "timestamp")"

    export ORCH_LAST_CYCLE ORCH_LAST_STATUS ORCH_LAST_TIMESTAMP
}

# ---------------------------------------------------------------------------
# orch_state_resume
#   Print the cycle number to resume from:
#     - If last status was 'failed'    → resume from last_cycle (retry it)
#     - If last status was 'completed' → resume from last_cycle + 1
#     - If no state file exists        → resume from 1
#
#   Callers should capture the output:
#     resume_from=$(orch_state_resume)
# ---------------------------------------------------------------------------
orch_state_resume() {
    orch_state_load

    if [[ -z "${ORCH_LAST_CYCLE}" ]]; then
        # No prior state — start fresh
        echo "1"
        return 0
    fi

    case "${ORCH_LAST_STATUS}" in
        failed)
            # Retry the cycle that failed
            echo "${ORCH_LAST_CYCLE}"
            ;;
        completed)
            # Advance to the next cycle
            echo $(( ORCH_LAST_CYCLE + 1 ))
            ;;
        running)
            # Interrupted mid-cycle — treat same as failed: retry
            echo "${ORCH_LAST_CYCLE}"
            ;;
        *)
            # Unknown status — fall back to retrying the last recorded cycle
            echo "${ORCH_LAST_CYCLE}"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# orch_state_clear
#   Remove the state file for a clean start. The directory is left intact.
# ---------------------------------------------------------------------------
orch_state_clear() {
    if [[ -f "${_ORCH_STATE_FILE}" ]]; then
        rm -f "${_ORCH_STATE_FILE}" || {
            echo "[cycle-state] ERROR: could not remove state file: ${_ORCH_STATE_FILE}" >&2
            return 1
        }
    fi

    # Also clear exported variables in the current shell
    ORCH_LAST_CYCLE=""
    ORCH_LAST_STATUS=""
    ORCH_LAST_TIMESTAMP=""
    export ORCH_LAST_CYCLE ORCH_LAST_STATUS ORCH_LAST_TIMESTAMP
}

# ---------------------------------------------------------------------------
# _orch_state_read_field <key>  [internal]
#   Extract a single key=value entry from the state file. Prints the value.
# ---------------------------------------------------------------------------
_orch_state_read_field() {
    local key="${1:?_orch_state_read_field requires a key}"
    local line value

    while IFS= read -r line; do
        # Match lines of the form: key=value (leading/trailing whitespace tolerated)
        if [[ "${line}" =~ ^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
            value="${BASH_REMATCH[1]}"
            # Strip any trailing carriage return (Windows line endings)
            value="${value%$'\r'}"
            printf '%s' "${value}"
            return 0
        fi
    done < "${_ORCH_STATE_FILE}"

    # Key not found — return empty
    return 0
}
