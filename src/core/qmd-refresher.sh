#!/usr/bin/env bash
# =============================================================================
# qmd-refresher.sh — Auto-refresh QMD index each cycle (#53)
#
# Provides a clean, testable API for managing qmd index updates and vector
# re-embeds during orchestration cycles. Replaces the inline qmd logic in
# auto-agent.sh (lines 690-703) with proper state tracking.
#
# Usage:
#   source src/core/qmd-refresher.sh
#
#   orch_qmd_available                    # Check if qmd CLI exists
#   orch_qmd_refresh                      # Fast BM25 re-index
#   orch_qmd_embed                        # Slower vector re-embed
#   orch_qmd_auto_refresh                 # Smart refresh (update always, embed when needed)
#   orch_qmd_status                       # Print availability + timestamps
#   orch_qmd_collections_exist            # Check if collections are set up
#
# State files:
#   .orchystraw/qmd-last-update  — timestamp of last `qmd update`
#   .orchystraw/qmd-last-embed   — timestamp of last `qmd embed`
#
# Requires: bash 5.0+
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_QMD_REFRESHER_LOADED:-}" ]] && return 0
readonly _ORCH_QMD_REFRESHER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g _ORCH_QMD_STATE_DIR="${ORCH_STATE_DIR:-.orchystraw}"
declare -g _ORCH_QMD_EMBED_INTERVAL="${ORCH_QMD_EMBED_INTERVAL:-300}"

readonly _ORCH_QMD_UPDATE_STATE_FILE="qmd-last-update"
readonly _ORCH_QMD_EMBED_STATE_FILE="qmd-last-embed"

# ---------------------------------------------------------------------------
# _orch_qmd_ensure_state_dir — create state directory if needed
# ---------------------------------------------------------------------------
_orch_qmd_ensure_state_dir() {
    if [[ ! -d "${_ORCH_QMD_STATE_DIR}" ]]; then
        mkdir -p "${_ORCH_QMD_STATE_DIR}" || {
            echo "[qmd-refresher] ERROR: could not create state directory: ${_ORCH_QMD_STATE_DIR}" >&2
            return 1
        }
    fi
}

# ---------------------------------------------------------------------------
# _orch_qmd_write_timestamp — write current epoch to a state file
#
# Args: $1 — state file name (relative to state dir)
# ---------------------------------------------------------------------------
_orch_qmd_write_timestamp() {
    local file="${1:?_orch_qmd_write_timestamp requires a file name}"
    [[ "$file" =~ ^[a-zA-Z0-9._-]+$ ]] || { _orch_qmd_log WARN "Invalid state file name: $file"; return 1; }
    _orch_qmd_ensure_state_dir || return 1
    printf '%s\n' "$(date +%s)" > "${_ORCH_QMD_STATE_DIR}/${file}"
}

# ---------------------------------------------------------------------------
# _orch_qmd_read_timestamp — read epoch from a state file
#
# Args: $1 — state file name (relative to state dir)
# Returns: echoes the timestamp, or "0" if file doesn't exist
# ---------------------------------------------------------------------------
_orch_qmd_read_timestamp() {
    local file="${1:?_orch_qmd_read_timestamp requires a file name}"
    local path="${_ORCH_QMD_STATE_DIR}/${file}"
    if [[ -f "${path}" ]]; then
        cat "${path}" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# ---------------------------------------------------------------------------
# orch_qmd_available — check if qmd CLI is installed
#
# Returns: 0 if qmd is available, 1 otherwise
# ---------------------------------------------------------------------------
orch_qmd_available() {
    command -v qmd &>/dev/null
}

# ---------------------------------------------------------------------------
# orch_qmd_refresh — run `qmd update` (fast BM25 re-index)
#
# Args: $1 — project root (optional, defaults to current directory)
# Returns: 0 on success, 1 on failure or qmd unavailable
# ---------------------------------------------------------------------------
orch_qmd_refresh() {
    local project_root="${1:-.}"

    if ! orch_qmd_available; then
        echo "[qmd-refresher] WARNING: qmd not installed, skipping update" >&2
        return 1
    fi

    if (cd "${project_root}" && qmd update 2>/dev/null); then
        _orch_qmd_write_timestamp "${_ORCH_QMD_UPDATE_STATE_FILE}"
        return 0
    else
        echo "[qmd-refresher] ERROR: qmd update failed" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# orch_qmd_embed — run `qmd embed` (slower vector re-embed)
#
# Args: $1 — project root (optional, defaults to current directory)
# Returns: 0 on success, 1 on failure or qmd unavailable
# ---------------------------------------------------------------------------
orch_qmd_embed() {
    local project_root="${1:-.}"

    if ! orch_qmd_available; then
        echo "[qmd-refresher] WARNING: qmd not installed, skipping embed" >&2
        return 1
    fi

    if (cd "${project_root}" && qmd embed 2>/dev/null); then
        _orch_qmd_write_timestamp "${_ORCH_QMD_EMBED_STATE_FILE}"
        return 0
    else
        echo "[qmd-refresher] ERROR: qmd embed failed" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# orch_qmd_auto_refresh — smart refresh logic
#
# Always runs `qmd update` (fast). Only runs `qmd embed` when:
#   - force_embed is "true", OR
#   - more than _ORCH_QMD_EMBED_INTERVAL seconds since last embed
#
# Args:
#   $1 — force_embed: "true" or "false" (default: "false")
#   $2 — project_root (optional, defaults to current directory)
#
# Returns: 0 if update succeeded (embed failure is non-fatal), 1 if update failed
# ---------------------------------------------------------------------------
orch_qmd_auto_refresh() {
    local force_embed="${1:-false}"
    local project_root="${2:-.}"

    if ! orch_qmd_available; then
        echo "[qmd-refresher] WARNING: qmd not installed, skipping auto-refresh" >&2
        return 1
    fi

    # Always run fast update
    if ! orch_qmd_refresh "${project_root}"; then
        return 1
    fi

    # Determine if embed is needed
    local should_embed=false

    if [[ "${force_embed}" == "true" ]]; then
        should_embed=true
    else
        local last_embed now elapsed
        last_embed="$(_orch_qmd_read_timestamp "${_ORCH_QMD_EMBED_STATE_FILE}")"
        now="$(date +%s)"
        elapsed=$(( now - last_embed ))

        if (( elapsed > _ORCH_QMD_EMBED_INTERVAL )); then
            should_embed=true
        fi
    fi

    if [[ "${should_embed}" == "true" ]]; then
        if orch_qmd_embed "${project_root}"; then
            echo "[qmd-refresher] re-indexed + re-embedded" >&2
        else
            echo "[qmd-refresher] WARNING: embed failed, update still succeeded" >&2
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_qmd_status — print availability and last refresh/embed timestamps
#
# Output format (stdout):
#   qmd=available|unavailable
#   last_update=<epoch|0>
#   last_embed=<epoch|0>
# ---------------------------------------------------------------------------
orch_qmd_status() {
    local avail="unavailable"
    if orch_qmd_available; then
        avail="available"
    fi

    local last_update last_embed
    last_update="$(_orch_qmd_read_timestamp "${_ORCH_QMD_UPDATE_STATE_FILE}")"
    last_embed="$(_orch_qmd_read_timestamp "${_ORCH_QMD_EMBED_STATE_FILE}")"

    echo "qmd=${avail}"
    echo "last_update=${last_update}"
    echo "last_embed=${last_embed}"
}

# ---------------------------------------------------------------------------
# orch_qmd_collections_exist — check if qmd collections are set up
#
# Args: $1 — project root (optional, defaults to current directory)
# Returns: 0 if collections exist, 1 otherwise
# ---------------------------------------------------------------------------
orch_qmd_collections_exist() {
    local project_root="${1:-.}"
    [[ -d "${project_root}/.qmd" ]]
}
