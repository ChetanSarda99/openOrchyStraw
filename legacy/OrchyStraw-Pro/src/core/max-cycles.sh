#!/usr/bin/env bash
# ============================================
# OrchyStraw — Max Cycles Override Module
# ============================================
# Allows cycle count override via env var or config file.
# Priority: MAX_CYCLES env → .orchystraw/max-cycles file → default (10)
#
# Usage:
#   source src/core/max-cycles.sh
#   max="$(orch_max_cycles_get)"

[[ -n "${_ORCH_MAX_CYCLES_LOADED:-}" ]] && return 0
_ORCH_MAX_CYCLES_LOADED=1

_MAX_CYCLES_DEFAULT=10
_MAX_CYCLES_FILE=".orchystraw/max-cycles"
_MAX_CYCLES_MIN=1
_MAX_CYCLES_MAX=100

# ── Validation ───────────────────────────────────────────────────────────

# Validate that a value is a positive integer within bounds
# Args: $1=value, $2=source_label
# Returns: 0 if valid, 1 if invalid
# Stdout: validated value or empty
orch_max_cycles_validate() {
    local val="$1" source="${2:-unknown}"

    # Must be a positive integer
    if [[ ! "$val" =~ ^[0-9]+$ ]]; then
        printf 'WARN: max-cycles from %s is not a number: "%s" — using default\n' "$source" "$val" >&2
        return 1
    fi

    # Convert and check bounds
    local num=$((val))
    if [[ "$num" -lt "$_MAX_CYCLES_MIN" ]]; then
        printf 'WARN: max-cycles from %s too low (%d) — clamping to %d\n' "$source" "$num" "$_MAX_CYCLES_MIN" >&2
        echo "$_MAX_CYCLES_MIN"
        return 0
    fi
    if [[ "$num" -gt "$_MAX_CYCLES_MAX" ]]; then
        printf 'WARN: max-cycles from %s too high (%d) — clamping to %d\n' "$source" "$num" "$_MAX_CYCLES_MAX" >&2
        echo "$_MAX_CYCLES_MAX"
        return 0
    fi

    echo "$num"
    return 0
}

# ── Resolution ───────────────────────────────────────────────────────────

# Get max cycles with priority: env → file → default
# Args: $1=project_root (optional, defaults to PWD)
# Stdout: max cycles number
orch_max_cycles_get() {
    local project_root="${1:-$PWD}"
    local result=""

    # Priority 1: Environment variable
    if [[ -n "${MAX_CYCLES:-}" ]]; then
        result="$(orch_max_cycles_validate "$MAX_CYCLES" "env:MAX_CYCLES")" && {
            echo "$result"
            return 0
        }
    fi

    # Priority 2: Config file
    local config_file="$project_root/$_MAX_CYCLES_FILE"
    if [[ -f "$config_file" ]]; then
        local file_val
        file_val="$(head -1 "$config_file" | tr -d '[:space:]')"
        if [[ -n "$file_val" ]]; then
            result="$(orch_max_cycles_validate "$file_val" "file:$_MAX_CYCLES_FILE")" && {
                echo "$result"
                return 0
            }
        fi
    fi

    # Priority 3: Default
    echo "$_MAX_CYCLES_DEFAULT"
    return 0
}

# Get the source of the current max-cycles value (for logging/debugging)
# Args: $1=project_root (optional)
# Stdout: "env", "file", or "default"
orch_max_cycles_source() {
    local project_root="${1:-$PWD}"

    if [[ -n "${MAX_CYCLES:-}" ]]; then
        local validated
        validated="$(orch_max_cycles_validate "$MAX_CYCLES" "env" 2>/dev/null)" && {
            echo "env"
            return 0
        }
    fi

    local config_file="$project_root/$_MAX_CYCLES_FILE"
    if [[ -f "$config_file" ]]; then
        local file_val
        file_val="$(head -1 "$config_file" | tr -d '[:space:]')"
        if [[ -n "$file_val" ]]; then
            local validated
            validated="$(orch_max_cycles_validate "$file_val" "file" 2>/dev/null)" && {
                echo "file"
                return 0
            }
        fi
    fi

    echo "default"
}

# Set max cycles config file
# Args: $1=value, $2=project_root (optional)
orch_max_cycles_set() {
    local val="$1" project_root="${2:-$PWD}"
    local config_dir="$project_root/.orchystraw"
    local config_file="$config_dir/max-cycles"

    # Validate before writing
    local validated
    validated="$(orch_max_cycles_validate "$val" "set")" || return 1

    mkdir -p "$config_dir"
    printf '%s\n' "$validated" > "$config_file"
}
