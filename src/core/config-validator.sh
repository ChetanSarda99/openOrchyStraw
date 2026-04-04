#!/usr/bin/env bash
# =============================================================================
# config-validator.sh — Sourceable bash library for validating agents.conf
#
# Usage:
#   source src/core/config-validator.sh
#   orch_validate_config agents.conf && echo "valid" || echo "invalid"
#
# Public API:
#   orch_validate_config  <conf_file>   — validate config file (0=ok, 1=errors)
#   orch_validate_prompt  <prompt_file> — validate a single prompt file
#   orch_config_error_count             — print number of errors found
#   orch_config_warning_count           — print number of warnings found
#   orch_validate_schema  <conf_file> <schema_file> — validate against a schema
#   orch_validate_field   <value> <type> [constraints] — validate a single field
#   orch_config_defaults  <conf_file> <defaults_file> — apply defaults to config
#   orch_config_get       <conf_file> <agent_id> <field> — get a field value
#
# Errors are printed to stderr and collected in _ORCH_CONFIG_ERRORS array.
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_CONFIG_VALIDATOR_LOADED:-}" ]] && return 0
readonly _ORCH_CONFIG_VALIDATOR_LOADED=1

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

# Accumulates error messages across the current validation run.
declare -a _ORCH_CONFIG_ERRORS=()

# Warning messages (non-fatal, e.g. unknown model names).
declare -a _ORCH_CONFIG_WARNINGS=()

# Minimum prompt length enforced by auto-agent.sh run_agent().
readonly _ORCH_MIN_PROMPT_LINES=30

# Valid model names per MODEL-001 ADR.
readonly -a _ORCH_VALID_MODEL_NAMES=(opus sonnet haiku)

# Supported field types for schema validation
declare -gA _ORCH_VALID_TYPES=(
    [string]=1
    [integer]=1
    [boolean]=1
    [path]=1
    [enum]=1
    [float]=1
)

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_cv_error <message>
#   Append an error message to _ORCH_CONFIG_ERRORS and print it to stderr.
_orch_cv_error() {
    local msg="$1"
    _ORCH_CONFIG_ERRORS+=("$msg")
    printf '[config-validator] ERROR: %s\n' "$msg" >&2
}

# _orch_cv_warn <message>
#   Append a warning message and print to stderr. Warnings don't fail validation.
_orch_cv_warn() {
    local msg="$1"
    _ORCH_CONFIG_WARNINGS+=("$msg")
    printf '[config-validator] WARN: %s\n' "$msg" >&2
}

# _orch_cv_reset
#   Clear the error and warning arrays before a new validation run.
_orch_cv_reset() {
    _ORCH_CONFIG_ERRORS=()
    _ORCH_CONFIG_WARNINGS=()
}

# _orch_cv_trim <string>
#   Strip leading and trailing whitespace; print the result.
_orch_cv_trim() {
    local s="$1"
    # Remove leading whitespace
    s="${s#"${s%%[![:space:]]*}"}"
    # Remove trailing whitespace
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# orch_validate_field <value> <type> [constraint]
#
# Validate a single field value against a type.
# Supported types:
#   string     — any non-empty string
#   integer    — numeric integer (optional constraint: "min:max")
#   boolean    — true/false/yes/no/1/0
#   path       — filesystem path (checks existence if constraint="exists")
#   enum       — value must be in constraint list (comma-separated)
#   float      — numeric float/integer (optional constraint: "min:max")
#
# Returns 0 if valid, 1 if invalid. Prints error description to stdout on failure.
# ---------------------------------------------------------------------------
orch_validate_field() {
    local value="${1:-}"
    local type="${2:?orch_validate_field: type required}"
    local constraint="${3:-}"

    case "$type" in
        string)
            if [[ -z "$value" ]]; then
                printf 'empty string'
                return 1
            fi
            # Optional constraint: min_length:max_length
            if [[ -n "$constraint" && "$constraint" == *:* ]]; then
                local min_len="${constraint%%:*}"
                local max_len="${constraint#*:}"
                local len="${#value}"
                if [[ -n "$min_len" && "$len" -lt "$min_len" ]]; then
                    printf 'string too short (%d < %d)' "$len" "$min_len"
                    return 1
                fi
                if [[ -n "$max_len" && "$len" -gt "$max_len" ]]; then
                    printf 'string too long (%d > %d)' "$len" "$max_len"
                    return 1
                fi
            fi
            ;;

        integer)
            if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                printf 'not an integer: %s' "$value"
                return 1
            fi
            if [[ -n "$constraint" && "$constraint" == *:* ]]; then
                local min_val="${constraint%%:*}"
                local max_val="${constraint#*:}"
                if [[ -n "$min_val" && "$value" -lt "$min_val" ]]; then
                    printf 'integer below minimum (%d < %d)' "$value" "$min_val"
                    return 1
                fi
                if [[ -n "$max_val" && "$value" -gt "$max_val" ]]; then
                    printf 'integer above maximum (%d > %d)' "$value" "$max_val"
                    return 1
                fi
            fi
            ;;

        boolean)
            case "${value,,}" in
                true|false|yes|no|1|0) ;;
                *)
                    printf 'not a boolean: %s' "$value"
                    return 1
                    ;;
            esac
            ;;

        path)
            if [[ -z "$value" ]]; then
                printf 'empty path'
                return 1
            fi
            if [[ "$constraint" == "exists" && ! -e "$value" ]]; then
                printf 'path does not exist: %s' "$value"
                return 1
            fi
            if [[ "$constraint" == "file" && ! -f "$value" ]]; then
                printf 'not a file: %s' "$value"
                return 1
            fi
            if [[ "$constraint" == "dir" && ! -d "$value" ]]; then
                printf 'not a directory: %s' "$value"
                return 1
            fi
            ;;

        enum)
            if [[ -z "$constraint" ]]; then
                printf 'enum type requires constraint (comma-separated values)'
                return 1
            fi
            local found=0
            local IFS=','
            local allowed
            for allowed in $constraint; do
                allowed="$(_orch_cv_trim "$allowed")"
                if [[ "$value" == "$allowed" ]]; then
                    found=1
                    break
                fi
            done
            if [[ "$found" -eq 0 ]]; then
                printf 'value "%s" not in allowed values: %s' "$value" "$constraint"
                return 1
            fi
            ;;

        float)
            # Match integer or decimal
            if [[ ! "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
                printf 'not a number: %s' "$value"
                return 1
            fi
            ;;

        *)
            printf 'unknown type: %s' "$type"
            return 1
            ;;
    esac

    return 0
}

# ---------------------------------------------------------------------------
# orch_validate_schema <conf_file> <schema_file>
#
# Validate a config file against a schema definition file.
# Schema format (one rule per line, # comments allowed):
#   field_index | field_name | type | required | default | constraint
#
# field_index: 0-based column index in the pipe-delimited config
# type: string, integer, boolean, path, enum, float
# required: yes/no
# default: default value if field is empty (- for none)
# constraint: type-specific constraint (- for none)
#
# Returns 0 if valid, 1 if errors found.
# ---------------------------------------------------------------------------
orch_validate_schema() {
    local conf_file="${1:?orch_validate_schema: conf_file required}"
    local schema_file="${2:?orch_validate_schema: schema_file required}"

    _orch_cv_reset

    if [[ ! -r "$conf_file" ]]; then
        _orch_cv_error "config file not readable: $conf_file"
        return 1
    fi

    if [[ ! -r "$schema_file" ]]; then
        _orch_cv_error "schema file not readable: $schema_file"
        return 1
    fi

    # Parse schema into arrays
    declare -a schema_indices=()
    declare -a schema_names=()
    declare -a schema_types=()
    declare -a schema_required=()
    declare -a schema_defaults=()
    declare -a schema_constraints=()

    local schema_lineno=0
    while IFS= read -r schema_line; do
        (( schema_lineno++ )) || true
        local trimmed
        trimmed="$(_orch_cv_trim "$schema_line")"
        [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

        local s_idx s_name s_type s_req s_default s_constraint
        IFS='|' read -r s_idx s_name s_type s_req s_default s_constraint <<< "$schema_line"

        s_idx=$(_orch_cv_trim "$s_idx")
        s_name=$(_orch_cv_trim "$s_name")
        s_type=$(_orch_cv_trim "$s_type")
        s_req=$(_orch_cv_trim "$s_req")
        s_default=$(_orch_cv_trim "$s_default")
        s_constraint=$(_orch_cv_trim "$s_constraint")

        # Validate schema itself
        if [[ ! "$s_idx" =~ ^[0-9]+$ ]]; then
            _orch_cv_error "schema line $schema_lineno: invalid field index '$s_idx'"
            continue
        fi

        if [[ -z "${_ORCH_VALID_TYPES[$s_type]+x}" ]]; then
            _orch_cv_error "schema line $schema_lineno: unknown type '$s_type'"
            continue
        fi

        schema_indices+=("$s_idx")
        schema_names+=("$s_name")
        schema_types+=("$s_type")
        schema_required+=("$s_req")
        schema_defaults+=("$s_default")
        schema_constraints+=("$s_constraint")
    done < "$schema_file"

    # Validate each config line against schema
    local conf_lineno=0
    while IFS= read -r conf_line; do
        (( conf_lineno++ )) || true
        local trimmed
        trimmed="$(_orch_cv_trim "$conf_line")"
        [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

        # Split into fields
        IFS='|' read -ra fields <<< "$conf_line"

        local i
        for i in "${!schema_indices[@]}"; do
            local idx="${schema_indices[$i]}"
            local fname="${schema_names[$i]}"
            local ftype="${schema_types[$i]}"
            local freq="${schema_required[$i]}"
            local fdefault="${schema_defaults[$i]}"
            local fconstraint="${schema_constraints[$i]}"

            # Get field value
            local fvalue=""
            if [[ "$idx" -lt "${#fields[@]}" ]]; then
                fvalue="$(_orch_cv_trim "${fields[$idx]}")"
            fi

            # Apply default if empty
            if [[ -z "$fvalue" && "$fdefault" != "-" && -n "$fdefault" ]]; then
                fvalue="$fdefault"
            fi

            # Check required
            if [[ "$freq" == "yes" && -z "$fvalue" ]]; then
                _orch_cv_error "line $conf_lineno: required field '$fname' (column $idx) is empty"
                continue
            fi

            # Skip validation if empty and not required
            [[ -z "$fvalue" ]] && continue

            # Normalize constraint
            [[ "$fconstraint" == "-" ]] && fconstraint=""

            # Type check
            local err
            err=$(orch_validate_field "$fvalue" "$ftype" "$fconstraint")
            if [[ $? -ne 0 ]]; then
                _orch_cv_error "line $conf_lineno: field '$fname' (column $idx): $err"
            fi
        done
    done < "$conf_file"

    if [[ "${#_ORCH_CONFIG_ERRORS[@]}" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# orch_config_defaults <conf_file> <defaults_file>
#
# Apply default values to a config file. Writes the result to stdout.
# Does not modify the original file.
#
# Defaults file format (one per line, # comments allowed):
#   field_index | default_value
#
# Empty fields in the config at field_index are replaced with default_value.
# ---------------------------------------------------------------------------
orch_config_defaults() {
    local conf_file="${1:?orch_config_defaults: conf_file required}"
    local defaults_file="${2:?orch_config_defaults: defaults_file required}"

    if [[ ! -r "$conf_file" ]]; then
        printf '[config-validator] ERROR: config file not readable: %s\n' "$conf_file" >&2
        return 1
    fi

    if [[ ! -r "$defaults_file" ]]; then
        printf '[config-validator] ERROR: defaults file not readable: %s\n' "$defaults_file" >&2
        return 1
    fi

    # Parse defaults
    declare -A defaults=()
    while IFS= read -r line; do
        local trimmed
        trimmed="$(_orch_cv_trim "$line")"
        [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

        local d_idx d_val
        IFS='|' read -r d_idx d_val <<< "$line"
        d_idx=$(_orch_cv_trim "$d_idx")
        d_val=$(_orch_cv_trim "$d_val")
        defaults["$d_idx"]="$d_val"
    done < "$defaults_file"

    # Process config
    while IFS= read -r line; do
        local trimmed
        trimmed="$(_orch_cv_trim "$line")"
        if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
            printf '%s\n' "$line"
            continue
        fi

        # Split by pipe — use a method that preserves trailing empty fields
        # by appending a sentinel before splitting
        local sentinel_line="${line}|_SENTINEL_"
        IFS='|' read -ra fields <<< "$sentinel_line"
        # Remove sentinel
        unset 'fields[${#fields[@]}-1]'

        local idx
        for idx in "${!defaults[@]}"; do
            if [[ "$idx" -lt "${#fields[@]}" ]]; then
                local val
                val="$(_orch_cv_trim "${fields[$idx]}")"
                if [[ -z "$val" ]]; then
                    fields[$idx]=" ${defaults[$idx]} "
                fi
            fi
        done

        # Rejoin with pipes
        local result="${fields[0]}"
        local i
        for (( i=1; i<${#fields[@]}; i++ )); do
            result="${result}|${fields[$i]}"
        done
        printf '%s\n' "$result"
    done < "$conf_file"
}

# ---------------------------------------------------------------------------
# orch_config_get <conf_file> <agent_id> <field_index>
#
# Get a specific field value from a config file for a given agent ID.
# Agent ID is matched against column 0 (trimmed).
# Returns the trimmed field value. Empty string if not found.
# ---------------------------------------------------------------------------
orch_config_get() {
    local conf_file="${1:?orch_config_get: conf_file required}"
    local agent_id="${2:?orch_config_get: agent_id required}"
    local field_idx="${3:?orch_config_get: field_index required}"

    if [[ ! -r "$conf_file" ]]; then
        return 1
    fi

    while IFS= read -r line; do
        local trimmed
        trimmed="$(_orch_cv_trim "$line")"
        [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

        IFS='|' read -ra fields <<< "$line"
        local id
        id="$(_orch_cv_trim "${fields[0]:-}")"

        if [[ "$id" == "$agent_id" ]]; then
            if [[ "$field_idx" -lt "${#fields[@]}" ]]; then
                _orch_cv_trim "${fields[$field_idx]}"
                return 0
            fi
            return 1
        fi
    done < "$conf_file"

    return 1
}

# ---------------------------------------------------------------------------
# orch_validate_prompt <prompt_file>
#
# Checks that a prompt file:
#   1. Exists
#   2. Is readable
#   3. Has more than _ORCH_MIN_PROMPT_LINES lines
#
# Returns 0 if all checks pass, 1 otherwise.
# Errors are appended to _ORCH_CONFIG_ERRORS and printed to stderr.
# ---------------------------------------------------------------------------
orch_validate_prompt() {
    local prompt_file="${1:?orch_validate_prompt: prompt_file required}"
    local ok=0

    if [[ ! -e "$prompt_file" ]]; then
        _orch_cv_error "prompt file does not exist: $prompt_file"
        ok=1
        return $ok
    fi

    if [[ ! -r "$prompt_file" ]]; then
        _orch_cv_error "prompt file is not readable: $prompt_file"
        ok=1
        return $ok
    fi

    local line_count
    line_count=$(wc -l < "$prompt_file" 2>/dev/null || printf '0')
    # wc -l output may have leading spaces on some platforms — strip them
    line_count=$(_orch_cv_trim "$line_count")

    if [[ ! "$line_count" =~ ^[0-9]+$ ]] || (( line_count <= _ORCH_MIN_PROMPT_LINES )); then
        _orch_cv_error "prompt file too short ($line_count lines, minimum is >${_ORCH_MIN_PROMPT_LINES}): $prompt_file"
        ok=1
    fi

    return $ok
}

# ---------------------------------------------------------------------------
# orch_validate_config <conf_file>
#
# Full validation of an agents.conf file. Checks in order:
#   1. File exists and is readable
#   2. Each non-comment line has 5, 7, 8, or 9 pipe-separated fields
#   3. Agent IDs are non-empty and unique
#   4. Prompt paths point to existing files
#   5. Interval is a non-negative integer
#   6. Exactly one coordinator (interval=0)
#   7. No empty labels
#   8. Model values are valid names (warn-only per MODEL-001)
#   9. max_tokens (v3 col 7) is numeric and > 0 (warn on < 10000)
#
# Returns 0 if all checks pass, 1 if any errors were found.
# All errors are collected in _ORCH_CONFIG_ERRORS and printed to stderr.
# ---------------------------------------------------------------------------
orch_validate_config() {
    local conf_file="${1:?orch_validate_config: conf_file required}"

    # Reset state for this run
    _orch_cv_reset

    # -- Check 1: file exists and is readable --
    if [[ ! -e "$conf_file" ]]; then
        _orch_cv_error "config file does not exist: $conf_file"
        return 1
    fi

    if [[ ! -r "$conf_file" ]]; then
        _orch_cv_error "config file is not readable: $conf_file"
        return 1
    fi

    # -- Per-line validation --

    # Track seen agent IDs for duplicate detection.
    declare -A _seen_ids=()

    # Count coordinators (interval=0) across all valid lines.
    local coordinator_count=0

    # Line number counter for human-readable error messages.
    local lineno=0

    while IFS= read -r raw_line; do
        (( lineno++ )) || true

        # Skip blank lines
        [[ -z "${raw_line// /}" ]] && continue

        # Skip comment lines (first non-whitespace character is #)
        local trimmed_line
        trimmed_line=$(_orch_cv_trim "$raw_line")
        [[ "$trimmed_line" == \#* ]] && continue

        # -- Check 2: 5, 7, 8, or 9 pipe-separated fields (v1, v3, v2, v2+) --
        local pipe_count
        pipe_count=$(printf '%s' "$raw_line" | tr -cd '|' | wc -c)
        pipe_count=$(_orch_cv_trim "$pipe_count")

        if [[ "$pipe_count" -ne 4 && "$pipe_count" -ne 6 && "$pipe_count" -ne 7 && "$pipe_count" -ne 8 ]]; then
            _orch_cv_error "line $lineno: expected 5, 7, 8, or 9 pipe-separated fields, found $(( pipe_count + 1 )) — '$trimmed_line'"
            continue
        fi

        # Split into fields (up to 9 columns)
        local f_id f_prompt f_ownership f_interval f_label f_model f_max_tokens
        local f_priority f_depends f_reviews
        f_model="" f_max_tokens=""

        if [[ "$pipe_count" -eq 6 ]]; then
            # v3 format: id | prompt | ownership | interval | label | model | max_tokens
            IFS='|' read -r f_id f_prompt f_ownership f_interval f_label f_model f_max_tokens <<< "$raw_line"
        else
            # v1 (5 col), v2 (8 col), v2+ (9 col)
            IFS='|' read -r f_id f_prompt f_ownership f_interval f_label f_priority f_depends f_reviews f_model <<< "$raw_line"
        fi

        f_id=$(_orch_cv_trim "$f_id")
        f_prompt=$(_orch_cv_trim "$f_prompt")
        f_ownership=$(_orch_cv_trim "$f_ownership")
        f_interval=$(_orch_cv_trim "$f_interval")
        f_label=$(_orch_cv_trim "$f_label")
        f_model=$(_orch_cv_trim "${f_model:-}")
        f_max_tokens=$(_orch_cv_trim "${f_max_tokens:-}")

        # -- Check 3: non-empty agent ID --
        if [[ -z "$f_id" ]]; then
            _orch_cv_error "line $lineno: agent ID is empty"
            continue
        fi

        # -- Check 3: unique agent ID --
        if [[ -n "${_seen_ids[$f_id]+x}" ]]; then
            _orch_cv_error "line $lineno: duplicate agent ID '$f_id' (first seen on line ${_seen_ids[$f_id]})"
        else
            _seen_ids["$f_id"]="$lineno"
        fi

        # -- Check 4: prompt path points to an existing file --
        if [[ -z "$f_prompt" ]]; then
            _orch_cv_error "line $lineno [$f_id]: prompt path is empty"
        else
            local conf_dir
            conf_dir="$(dirname "$conf_file")"
            local resolved_prompt="$conf_dir/$f_prompt"
            if [[ ! -f "$resolved_prompt" ]]; then
                resolved_prompt="$(dirname "$conf_dir")/$f_prompt"
            fi
            if [[ ! -f "$resolved_prompt" ]]; then
                _orch_cv_error "line $lineno [$f_id]: prompt file not found: $f_prompt"
            fi
        fi

        # -- Check 5: interval is a non-negative integer --
        if [[ -z "$f_interval" ]]; then
            _orch_cv_error "line $lineno [$f_id]: interval is empty"
        elif [[ ! "$f_interval" =~ ^[0-9]+$ ]]; then
            _orch_cv_error "line $lineno [$f_id]: interval must be a non-negative integer, got '$f_interval'"
        else
            # -- Check 6: count coordinators --
            if [[ "$f_interval" -eq 0 ]]; then
                (( coordinator_count++ )) || true
            fi
        fi

        # -- Check 7: non-empty label --
        if [[ -z "$f_label" ]]; then
            _orch_cv_error "line $lineno [$f_id]: label is empty"
        fi

        # -- Check 8: model value (warn-only per MODEL-001) --
        if [[ -n "$f_model" && "$f_model" != "none" ]]; then
            local model_valid=false
            for valid_model in "${_ORCH_VALID_MODEL_NAMES[@]}"; do
                if [[ "$f_model" == "$valid_model" ]]; then
                    model_valid=true
                    break
                fi
            done
            if [[ "$model_valid" == "false" ]]; then
                _orch_cv_warn "line $lineno [$f_id]: unknown model '$f_model' (expected: opus, sonnet, haiku)"
            fi
        fi

        # -- Check 9: max_tokens (v3 — numeric, > 0, warn on low) --
        if [[ -n "$f_max_tokens" ]]; then
            if [[ ! "$f_max_tokens" =~ ^[0-9]+$ ]]; then
                _orch_cv_error "line $lineno [$f_id]: max_tokens must be a positive integer, got '$f_max_tokens'"
            elif [[ "$f_max_tokens" -eq 0 ]]; then
                _orch_cv_error "line $lineno [$f_id]: max_tokens must be > 0"
            elif [[ "$f_max_tokens" -lt 10000 ]]; then
                _orch_cv_warn "line $lineno [$f_id]: max_tokens=$f_max_tokens is suspiciously low (agent output may be truncated)"
            fi
        fi

    done < "$conf_file"

    # -- Check 6: exactly one coordinator --
    if [[ "$coordinator_count" -eq 0 ]]; then
        _orch_cv_error "no coordinator found (exactly one agent must have interval=0)"
    elif [[ "$coordinator_count" -gt 1 ]]; then
        _orch_cv_error "found $coordinator_count coordinators (interval=0); exactly one is required"
    fi

    # Return based on error count
    if [[ "${#_ORCH_CONFIG_ERRORS[@]}" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# orch_config_error_count
#
# Print the number of errors recorded by the most recent validation run.
# ---------------------------------------------------------------------------
orch_config_error_count() {
    printf '%s\n' "${#_ORCH_CONFIG_ERRORS[@]}"
}

# ---------------------------------------------------------------------------
# orch_config_warning_count
#
# Print the number of warnings recorded by the most recent validation run.
# ---------------------------------------------------------------------------
orch_config_warning_count() {
    printf '%s\n' "${#_ORCH_CONFIG_WARNINGS[@]}"
}
