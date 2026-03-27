#!/usr/bin/env bash
# lock-file.sh — Sourceable bash library for orchestrator lock management
# Usage: source src/core/lock-file.sh
#
# Prevents multiple orchestrators from running simultaneously via a PID lock file.

# Guard against double-sourcing
[[ -n "${_ORCH_LOCK_FILE_LOADED:-}" ]] && return 0
readonly _ORCH_LOCK_FILE_LOADED=1

# Lock file path (relative to repo root, where the orchestrator runs)
readonly _ORCH_LOCK_DIR=".orchystraw"
readonly _ORCH_LOCK_FILE="${_ORCH_LOCK_DIR}/orchestrator.lock"

# orch_lock_acquire — Try to acquire the orchestrator lock.
# Returns 0 on success, 1 if another orchestrator is already running.
orch_lock_acquire() {
    # 1. Create lock directory if needed
    if [[ ! -d "${_ORCH_LOCK_DIR}" ]]; then
        mkdir -p "${_ORCH_LOCK_DIR}" || {
            echo "[lock] ERROR: Failed to create lock directory: ${_ORCH_LOCK_DIR}" >&2
            return 1
        }
    fi

    # 2. Check if lock file exists
    if [[ -f "${_ORCH_LOCK_FILE}" ]]; then
        local existing_pid existing_timestamp

        existing_pid=$(grep '^pid=' "${_ORCH_LOCK_FILE}" 2>/dev/null | cut -d= -f2)
        existing_timestamp=$(grep '^timestamp=' "${_ORCH_LOCK_FILE}" 2>/dev/null | cut -d= -f2-)

        # 3. If exists: check if that PID is still running
        if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
            # 4. PID still running — print error and return 1
            echo "[lock] ERROR: Orchestrator already running (PID ${existing_pid}, started ${existing_timestamp})" >&2
            echo "[lock] Lock file: ${_ORCH_LOCK_FILE}" >&2
            return 1
        else
            # 5. PID is dead (stale lock) — warn and remove
            echo "[lock] WARNING: Removing stale lock file (PID ${existing_pid:-unknown} is no longer running)" >&2
            rm -f "${_ORCH_LOCK_FILE}"
        fi
    fi

    # 6. Write current PID + timestamp to lock file
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    printf 'pid=%s\ntimestamp=%s\n' "$$" "${now}" > "${_ORCH_LOCK_FILE}" || {
        echo "[lock] ERROR: Failed to write lock file: ${_ORCH_LOCK_FILE}" >&2
        return 1
    }

    # 7. Return 0 on success
    return 0
}

# orch_lock_release — Remove the lock file. Call in cleanup/exit traps.
orch_lock_release() {
    if [[ -f "${_ORCH_LOCK_FILE}" ]]; then
        rm -f "${_ORCH_LOCK_FILE}"
    fi
}

# orch_lock_check — Return 0 if lock is held by the current process, 1 otherwise.
orch_lock_check() {
    [[ -f "${_ORCH_LOCK_FILE}" ]] || return 1

    local locked_pid
    locked_pid=$(grep '^pid=' "${_ORCH_LOCK_FILE}" 2>/dev/null | cut -d= -f2)

    [[ "${locked_pid}" == "$$" ]] && return 0
    return 1
}

# orch_lock_info — Print who holds the lock (PID, timestamp).
# Prints nothing and returns 1 if no lock file exists.
orch_lock_info() {
    if [[ ! -f "${_ORCH_LOCK_FILE}" ]]; then
        echo "[lock] No lock file found at: ${_ORCH_LOCK_FILE}"
        return 1
    fi

    local locked_pid locked_timestamp
    locked_pid=$(grep '^pid=' "${_ORCH_LOCK_FILE}" 2>/dev/null | cut -d= -f2)
    locked_timestamp=$(grep '^timestamp=' "${_ORCH_LOCK_FILE}" 2>/dev/null | cut -d= -f2-)

    echo "[lock] Lock held by PID ${locked_pid:-unknown} (started ${locked_timestamp:-unknown})"
    echo "[lock] Lock file: ${_ORCH_LOCK_FILE}"
    return 0
}
