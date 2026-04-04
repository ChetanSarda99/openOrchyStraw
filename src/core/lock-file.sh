#!/usr/bin/env bash
# lock-file.sh — Sourceable bash library for orchestrator lock management
# Usage: source src/core/lock-file.sh
#
# Prevents multiple orchestrators from running simultaneously via a PID lock file.
# Supports advisory locking with flock, deadlock detection, and lock timeouts.
#
# Public API:
#   orch_lock_acquire      — acquire the orchestrator lock
#   orch_lock_release      — release the orchestrator lock
#   orch_lock_check        — check if current process holds the lock
#   orch_lock_info         — print lock holder info
#   orch_lock_acquire_timeout <seconds> — acquire with timeout
#   orch_lock_acquire_named <name>      — acquire a named advisory lock
#   orch_lock_release_named <name>      — release a named advisory lock
#   orch_lock_detect_deadlock           — check for potential deadlocks
#   orch_lock_list                      — list all held locks

# Guard against double-sourcing
[[ -n "${_ORCH_LOCK_FILE_LOADED:-}" ]] && return 0
readonly _ORCH_LOCK_FILE_LOADED=1

# Lock file path (relative to repo root, where the orchestrator runs)
readonly _ORCH_LOCK_DIR=".orchystraw"
readonly _ORCH_LOCK_FILE="${_ORCH_LOCK_DIR}/orchestrator.lock"

# Named locks directory
readonly _ORCH_NAMED_LOCK_DIR="${_ORCH_LOCK_DIR}/locks"

# Track which named locks this process holds (for deadlock detection)
declare -gA _ORCH_HELD_LOCKS=()

# Advisory lock FD tracking
declare -gA _ORCH_LOCK_FDS=()
# Next available FD number for flock
_ORCH_NEXT_LOCK_FD=200

# ---------------------------------------------------------------------------
# _orch_lock_write <file> <pid> <timestamp> [holder_name]
#
# Write a lock file with structured data.
# ---------------------------------------------------------------------------
_orch_lock_write() {
    local file="$1"
    local pid="$2"
    local timestamp="$3"
    local holder="${4:-$$}"

    printf 'pid=%s\ntimestamp=%s\nholder=%s\n' "$pid" "$timestamp" "$holder" > "$file"
}

# ---------------------------------------------------------------------------
# _orch_lock_read <file> <field>
#
# Read a field from a lock file. Returns empty string if not found.
# ---------------------------------------------------------------------------
_orch_lock_read() {
    local file="$1"
    local field="$2"
    grep "^${field}=" "$file" 2>/dev/null | cut -d= -f2- || true
}

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

        existing_pid=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "pid")
        existing_timestamp=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "timestamp")

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
    _orch_lock_write "${_ORCH_LOCK_FILE}" "$$" "${now}" "orchestrator"

    # 7. Try advisory lock with flock if available
    if command -v flock >/dev/null 2>&1; then
        exec 199>"${_ORCH_LOCK_FILE}.flock"
        if ! flock -n 199; then
            echo "[lock] ERROR: Failed to acquire advisory lock (another process holds it)" >&2
            rm -f "${_ORCH_LOCK_FILE}"
            return 1
        fi
    fi

    # 8. Return 0 on success
    return 0
}

# orch_lock_release — Remove the lock file. Call in cleanup/exit traps.
orch_lock_release() {
    # Release advisory lock if held
    if command -v flock >/dev/null 2>&1; then
        flock -u 199 2>/dev/null || true
        exec 199>&- 2>/dev/null || true
        rm -f "${_ORCH_LOCK_FILE}.flock"
    fi

    if [[ -f "${_ORCH_LOCK_FILE}" ]]; then
        rm -f "${_ORCH_LOCK_FILE}"
    fi
}

# orch_lock_check — Return 0 if lock is held by the current process, 1 otherwise.
orch_lock_check() {
    [[ -f "${_ORCH_LOCK_FILE}" ]] || return 1

    local locked_pid
    locked_pid=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "pid")

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

    local locked_pid locked_timestamp locked_holder
    locked_pid=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "pid")
    locked_timestamp=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "timestamp")
    locked_holder=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "holder")

    echo "[lock] Lock held by PID ${locked_pid:-unknown} (${locked_holder:-unknown}, started ${locked_timestamp:-unknown})"
    echo "[lock] Lock file: ${_ORCH_LOCK_FILE}"

    # Check if holder is still alive
    if [[ -n "${locked_pid}" ]]; then
        if kill -0 "${locked_pid}" 2>/dev/null; then
            echo "[lock] Status: ACTIVE"
        else
            echo "[lock] Status: STALE (PID ${locked_pid} is dead)"
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_lock_acquire_timeout <seconds>
#
# Try to acquire the orchestrator lock, waiting up to <seconds> seconds.
# Polls every second. Returns 0 on success, 1 on timeout.
# ---------------------------------------------------------------------------
orch_lock_acquire_timeout() {
    local timeout_secs="${1:?orch_lock_acquire_timeout: seconds required}"
    local waited=0

    while (( waited < timeout_secs )); do
        if orch_lock_acquire 2>/dev/null; then
            return 0
        fi
        sleep 1
        (( waited++ ))
    done

    echo "[lock] ERROR: Failed to acquire lock within ${timeout_secs}s timeout" >&2
    return 1
}

# ---------------------------------------------------------------------------
# orch_lock_acquire_named <name> [timeout_seconds]
#
# Acquire a named advisory lock. Named locks allow fine-grained locking
# of specific resources (e.g., "config-write", "prompt-update").
#
# Uses flock if available, falls back to PID-based locking.
# Returns 0 on success, 1 if lock cannot be acquired.
# ---------------------------------------------------------------------------
orch_lock_acquire_named() {
    local name="${1:?orch_lock_acquire_named: name required}"
    local timeout="${2:-0}"

    # Sanitize name for filesystem
    local safe_name="${name//[^a-zA-Z0-9_-]/_}"
    local lock_file="${_ORCH_NAMED_LOCK_DIR}/${safe_name}.lock"

    mkdir -p "${_ORCH_NAMED_LOCK_DIR}"

    local waited=0
    while true; do
        # Check existing lock
        if [[ -f "$lock_file" ]]; then
            local existing_pid
            existing_pid=$(_orch_lock_read "$lock_file" "pid")

            if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
                # Lock is held by a live process
                if [[ "$timeout" -le 0 ]] || [[ "$waited" -ge "$timeout" ]]; then
                    echo "[lock] ERROR: Named lock '${name}' held by PID ${existing_pid}" >&2
                    return 1
                fi
                sleep 1
                (( waited++ ))
                continue
            else
                # Stale lock
                rm -f "$lock_file"
            fi
        fi

        # Try to acquire
        local now
        now=$(date '+%Y-%m-%d %H:%M:%S')
        _orch_lock_write "$lock_file" "$$" "$now" "$name"

        # Use flock for advisory locking if available
        if command -v flock >/dev/null 2>&1; then
            local fd="$_ORCH_NEXT_LOCK_FD"
            (( _ORCH_NEXT_LOCK_FD++ ))

            eval "exec ${fd}>\"${lock_file}.flock\""
            if flock -n "$fd"; then
                _ORCH_LOCK_FDS["$name"]="$fd"
            else
                eval "exec ${fd}>&-" 2>/dev/null || true
                if [[ "$timeout" -le 0 ]] || [[ "$waited" -ge "$timeout" ]]; then
                    rm -f "$lock_file"
                    echo "[lock] ERROR: Advisory lock failed for '${name}'" >&2
                    return 1
                fi
                sleep 1
                (( waited++ ))
                continue
            fi
        fi

        _ORCH_HELD_LOCKS["$name"]="$$:$(date +%s)"
        return 0
    done
}

# ---------------------------------------------------------------------------
# orch_lock_release_named <name>
#
# Release a named advisory lock.
# ---------------------------------------------------------------------------
orch_lock_release_named() {
    local name="${1:?orch_lock_release_named: name required}"
    local safe_name="${name//[^a-zA-Z0-9_-]/_}"
    local lock_file="${_ORCH_NAMED_LOCK_DIR}/${safe_name}.lock"

    # Release flock if held
    if [[ -n "${_ORCH_LOCK_FDS[$name]+x}" ]]; then
        local fd="${_ORCH_LOCK_FDS[$name]}"
        flock -u "$fd" 2>/dev/null || true
        eval "exec ${fd}>&-" 2>/dev/null || true
        unset '_ORCH_LOCK_FDS[$name]'
        rm -f "${lock_file}.flock"
    fi

    rm -f "$lock_file"
    unset '_ORCH_HELD_LOCKS[$name]'
}

# ---------------------------------------------------------------------------
# orch_lock_detect_deadlock
#
# Simple deadlock detection: checks if any locks held by this process
# are also being waited on by processes that hold locks we need.
#
# This is a best-effort heuristic — checks for:
# 1. Stale locks (holder PID is dead)
# 2. Circular wait patterns among lock files in the named lock dir
#
# Returns 0 if no deadlock detected, 1 if potential deadlock found.
# Prints diagnostic info to stderr.
# ---------------------------------------------------------------------------
orch_lock_detect_deadlock() {
    [[ -d "${_ORCH_NAMED_LOCK_DIR}" ]] || return 0

    local deadlock_found=0
    local stale_count=0

    # Collect all lock holders
    declare -A holders=()
    local lock_f
    for lock_f in "${_ORCH_NAMED_LOCK_DIR}"/*.lock; do
        [[ -e "$lock_f" ]] || continue
        [[ "$lock_f" == *.flock ]] && continue

        local lock_name
        lock_name="$(basename "$lock_f" .lock)"
        local holder_pid
        holder_pid=$(_orch_lock_read "$lock_f" "pid")

        if [[ -n "$holder_pid" ]]; then
            if ! kill -0 "$holder_pid" 2>/dev/null; then
                printf '[lock] DEADLOCK-CHECK: Stale lock detected: %s held by dead PID %s\n' \
                    "$lock_name" "$holder_pid" >&2
                (( stale_count++ ))
                deadlock_found=1
            else
                holders["$lock_name"]="$holder_pid"
            fi
        fi
    done

    # Check for simple circular waits:
    # If process A holds lock X and wants lock Y, while process B holds lock Y and wants lock X
    # We approximate this by checking if any two processes hold each other's locks
    local -a pids=()
    local name
    for name in "${!holders[@]}"; do
        local pid="${holders[$name]}"
        local already=0
        local p
        for p in "${pids[@]:-}"; do
            [[ "$p" == "$pid" ]] && already=1 && break
        done
        (( already == 0 )) && pids+=("$pid")
    done

    if [[ "${#pids[@]}" -gt 1 ]]; then
        # Multiple processes hold locks — check if any are waiting on each other
        # by looking at locks held by each PID
        declare -A pid_locks=()
        for name in "${!holders[@]}"; do
            local pid="${holders[$name]}"
            pid_locks["$pid"]="${pid_locks[$pid]:-} $name"
        done

        # If current process holds locks AND other processes also hold locks,
        # there's a potential for deadlock
        if [[ -n "${pid_locks[$$]:-}" ]] && [[ "${#pids[@]}" -gt 1 ]]; then
            printf '[lock] DEADLOCK-CHECK: WARNING — %d processes hold named locks simultaneously\n' \
                "${#pids[@]}" >&2
            for pid in "${pids[@]}"; do
                printf '[lock] DEADLOCK-CHECK:   PID %s holds:%s\n' "$pid" "${pid_locks[$pid]}" >&2
            done
        fi
    fi

    if [[ "$stale_count" -gt 0 ]]; then
        printf '[lock] DEADLOCK-CHECK: Found %d stale locks (recommend cleanup)\n' "$stale_count" >&2
    fi

    return "$deadlock_found"
}

# ---------------------------------------------------------------------------
# orch_lock_list
#
# List all currently held locks (both main orchestrator lock and named locks).
# Prints to stdout.
# ---------------------------------------------------------------------------
orch_lock_list() {
    local found=0

    # Main orchestrator lock
    if [[ -f "${_ORCH_LOCK_FILE}" ]]; then
        local pid ts holder
        pid=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "pid")
        ts=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "timestamp")
        holder=$(_orch_lock_read "${_ORCH_LOCK_FILE}" "holder")
        local status="active"
        if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
            status="STALE"
        fi
        printf '%-20s  PID=%-8s  %s  (%s)  [%s]\n' "orchestrator" "${pid:-?}" "${ts:-?}" "${holder:-?}" "$status"
        found=1
    fi

    # Named locks
    if [[ -d "${_ORCH_NAMED_LOCK_DIR}" ]]; then
        local lock_f
        for lock_f in "${_ORCH_NAMED_LOCK_DIR}"/*.lock; do
            [[ -e "$lock_f" ]] || continue
            [[ "$lock_f" == *.flock ]] && continue

            local name pid ts holder
            name="$(basename "$lock_f" .lock)"
            pid=$(_orch_lock_read "$lock_f" "pid")
            ts=$(_orch_lock_read "$lock_f" "timestamp")
            holder=$(_orch_lock_read "$lock_f" "holder")
            local status="active"
            if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
                status="STALE"
            fi
            printf '%-20s  PID=%-8s  %s  (%s)  [%s]\n' "$name" "${pid:-?}" "${ts:-?}" "${holder:-?}" "$status"
            found=1
        done
    fi

    if [[ "$found" -eq 0 ]]; then
        echo "[lock] No locks currently held."
    fi
}
