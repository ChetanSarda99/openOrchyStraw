#!/usr/bin/env bash
# =============================================================================
# model-registry.sh — Auto-detect available AI model CLIs (#70)
#
# Scans for installed AI CLI tools (claude, codex, gemini), queries their
# versions, and maintains a registry in .orchystraw/models/. Alerts when
# new models are detected.
#
# Usage:
#   source src/core/model-registry.sh
#
#   orch_registry_init                  — Initialize registry directory
#   orch_registry_scan                  — Detect installed CLI tools
#   orch_registry_get <name>            — Get CLI info (version, path)
#   orch_registry_list                  — List all registered models
#   orch_registry_check_new             — Check for newly available models
#   orch_registry_is_available <name>   — Check if a specific model is available
#   orch_registry_report                — Print summary report
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_MODEL_REGISTRY_LOADED:-}" ]] && return 0
readonly _ORCH_MODEL_REGISTRY_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_REGISTRY_CLI_PATH=()     # model_name → binary path
declare -gA _ORCH_REGISTRY_CLI_VERSION=()  # model_name → version string
declare -gA _ORCH_REGISTRY_CLI_CMD=()      # model_name → full invocation command
declare -ga _ORCH_REGISTRY_NEW=()          # newly detected model names
declare -g  _ORCH_REGISTRY_DIR=""
declare -g  _ORCH_REGISTRY_SCANNED=0

# Known CLI tools and how to invoke them
# Format: name|binary|version_flag|invoke_command
readonly _ORCH_REGISTRY_KNOWN_MODELS=(
    "claude|claude|--version|claude"
    "codex|codex|--version|codex exec"
    "gemini|gemini|--version|gemini -p"
    "aider|aider|--version|aider"
    "cursor|cursor|--version|cursor"
    "copilot|gh|--version|gh copilot"
)

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
_orch_registry_log() {
    [[ -n "${ORCH_QUIET:-}" ]] && return 0
    printf '[model-registry] %s\n' "$1" >&2
}

_orch_registry_err() {
    printf '[model-registry] ERROR: %s\n' "$1" >&2
}

# ---------------------------------------------------------------------------
# orch_registry_init
#
# Create the registry directory structure. Uses ORCHYSTRAW_HOME or defaults
# to project-local .orchystraw/models/.
# ---------------------------------------------------------------------------
orch_registry_init() {
    local home="${ORCHYSTRAW_HOME:-${PWD}/.orchystraw}"
    _ORCH_REGISTRY_DIR="$home/models"
    mkdir -p "$_ORCH_REGISTRY_DIR"

    # Load previous registry if it exists
    if [[ -f "$_ORCH_REGISTRY_DIR/registry.txt" ]]; then
        _orch_registry_load
    fi

    return 0
}

# ---------------------------------------------------------------------------
# _orch_registry_load
#
# Load saved registry from disk. Format: name|path|version|command
# ---------------------------------------------------------------------------
_orch_registry_load() {
    local line name path version cmd
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        IFS='|' read -r name path version cmd <<< "$line"
        _ORCH_REGISTRY_CLI_PATH["$name"]="$path"
        _ORCH_REGISTRY_CLI_VERSION["$name"]="$version"
        _ORCH_REGISTRY_CLI_CMD["$name"]="$cmd"
    done < "$_ORCH_REGISTRY_DIR/registry.txt"
}

# ---------------------------------------------------------------------------
# _orch_registry_save
#
# Persist current registry state to disk.
# ---------------------------------------------------------------------------
_orch_registry_save() {
    [[ -z "$_ORCH_REGISTRY_DIR" ]] && return 1

    {
        printf '# OrchyStraw Model Registry — %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        local name
        for name in "${!_ORCH_REGISTRY_CLI_PATH[@]}"; do
            printf '%s|%s|%s|%s\n' \
                "$name" \
                "${_ORCH_REGISTRY_CLI_PATH[$name]}" \
                "${_ORCH_REGISTRY_CLI_VERSION[$name]}" \
                "${_ORCH_REGISTRY_CLI_CMD[$name]}"
        done
    } > "$_ORCH_REGISTRY_DIR/registry.txt"
}

# ---------------------------------------------------------------------------
# orch_registry_scan
#
# Detect installed AI CLI tools. For each known model, checks if the binary
# is on PATH, queries its version, and registers it. Detects new models
# that weren't in the previous scan.
#
# Returns: number of available models (printed to stdout)
# ---------------------------------------------------------------------------
orch_registry_scan() {
    if [[ -z "$_ORCH_REGISTRY_DIR" ]]; then
        _orch_registry_err "not initialized — call orch_registry_init first"
        return 1
    fi

    # Remember previous state to detect new models
    local -A prev_models=()
    local name
    for name in "${!_ORCH_REGISTRY_CLI_PATH[@]}"; do
        prev_models["$name"]=1
    done

    _ORCH_REGISTRY_NEW=()
    local count=0
    local entry model_name binary version_flag invoke_cmd

    for entry in "${_ORCH_REGISTRY_KNOWN_MODELS[@]}"; do
        IFS='|' read -r model_name binary version_flag invoke_cmd <<< "$entry"

        local bin_path
        bin_path=$(command -v "$binary" 2>/dev/null) || continue

        # Get version (capture first line, timeout after 5s)
        local version="unknown"
        if [[ "$model_name" == "copilot" ]]; then
            # gh copilot --version doesn't exist; use gh --version
            version=$(timeout 5 "$binary" "$version_flag" 2>/dev/null | head -1) || version="unknown"
        else
            version=$(timeout 5 "$binary" "$version_flag" 2>/dev/null | head -1) || version="unknown"
        fi

        _ORCH_REGISTRY_CLI_PATH["$model_name"]="$bin_path"
        _ORCH_REGISTRY_CLI_VERSION["$model_name"]="$version"
        _ORCH_REGISTRY_CLI_CMD["$model_name"]="$invoke_cmd"

        (( count++ ))

        # Check if this is new
        if [[ -z "${prev_models[$model_name]:-}" ]]; then
            _ORCH_REGISTRY_NEW+=("$model_name")
            _orch_registry_log "NEW model detected: $model_name ($version)"
        fi
    done

    _ORCH_REGISTRY_SCANNED=1
    _orch_registry_save

    printf '%d\n' "$count"
}

# ---------------------------------------------------------------------------
# orch_registry_get <name>
#
# Print info for a registered model: path|version|command
# Returns 1 if not found.
# ---------------------------------------------------------------------------
orch_registry_get() {
    local name="${1:-}"
    [[ -z "$name" ]] && { _orch_registry_err "orch_registry_get requires a name"; return 1; }

    if [[ -z "${_ORCH_REGISTRY_CLI_PATH[$name]:-}" ]]; then
        return 1
    fi

    printf '%s|%s|%s\n' \
        "${_ORCH_REGISTRY_CLI_PATH[$name]}" \
        "${_ORCH_REGISTRY_CLI_VERSION[$name]}" \
        "${_ORCH_REGISTRY_CLI_CMD[$name]}"
}

# ---------------------------------------------------------------------------
# orch_registry_list
#
# Print all registered models, one per line: name version command
# ---------------------------------------------------------------------------
orch_registry_list() {
    if [[ ${#_ORCH_REGISTRY_CLI_PATH[@]} -eq 0 ]]; then
        printf '(no models registered)\n'
        return 0
    fi

    local name
    for name in "${!_ORCH_REGISTRY_CLI_PATH[@]}"; do
        printf '%-12s %-30s %s\n' \
            "$name" \
            "${_ORCH_REGISTRY_CLI_VERSION[$name]}" \
            "${_ORCH_REGISTRY_CLI_CMD[$name]}"
    done
}

# ---------------------------------------------------------------------------
# orch_registry_check_new
#
# Print names of newly detected models (since last scan).
# Returns 0 if new models found, 1 if none.
# ---------------------------------------------------------------------------
orch_registry_check_new() {
    if [[ ${#_ORCH_REGISTRY_NEW[@]} -eq 0 ]]; then
        return 1
    fi

    local name
    for name in "${_ORCH_REGISTRY_NEW[@]}"; do
        printf '%s\n' "$name"
    done
    return 0
}

# ---------------------------------------------------------------------------
# orch_registry_is_available <name>
#
# Returns 0 if the named model is registered and its binary exists, 1 otherwise.
# ---------------------------------------------------------------------------
orch_registry_is_available() {
    local name="${1:-}"
    [[ -z "$name" ]] && return 1

    if [[ -z "${_ORCH_REGISTRY_CLI_PATH[$name]:-}" ]]; then
        return 1
    fi

    # Verify binary still exists
    [[ -x "${_ORCH_REGISTRY_CLI_PATH[$name]}" ]]
}

# ---------------------------------------------------------------------------
# orch_registry_count
#
# Print the number of registered models.
# ---------------------------------------------------------------------------
orch_registry_count() {
    printf '%d\n' "${#_ORCH_REGISTRY_CLI_PATH[@]}"
}

# ---------------------------------------------------------------------------
# orch_registry_report
#
# Print a formatted summary of the model registry.
# ---------------------------------------------------------------------------
orch_registry_report() {
    printf '\n── Model Registry Report ──\n'

    if [[ "$_ORCH_REGISTRY_SCANNED" -eq 0 ]]; then
        printf '  (not scanned yet — call orch_registry_scan)\n'
        return 0
    fi

    local total=${#_ORCH_REGISTRY_CLI_PATH[@]}
    printf '  Available models: %d\n' "$total"

    if [[ $total -gt 0 ]]; then
        printf '  %-12s %-30s %s\n' "Model" "Version" "Command"
        printf '  %-12s %-30s %s\n' "-----" "-------" "-------"
        local name
        for name in "${!_ORCH_REGISTRY_CLI_PATH[@]}"; do
            printf '  %-12s %-30s %s\n' \
                "$name" \
                "${_ORCH_REGISTRY_CLI_VERSION[$name]}" \
                "${_ORCH_REGISTRY_CLI_CMD[$name]}"
        done
    fi

    if [[ ${#_ORCH_REGISTRY_NEW[@]} -gt 0 ]]; then
        printf '\n  New models detected this scan:\n'
        local name
        for name in "${_ORCH_REGISTRY_NEW[@]}"; do
            printf '    → %s\n' "$name"
        done
    fi

    printf '\n'
}
