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

    # ── Check 1: file exists and is readable ────────────────────────────────
    if [[ ! -e "$conf_file" ]]; then
        _orch_cv_error "config file does not exist: $conf_file"
        return 1
    fi

    if [[ ! -r "$conf_file" ]]; then
        _orch_cv_error "config file is not readable: $conf_file"
        return 1
    fi

    # ── Per-line validation ─────────────────────────────────────────────────

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

        # ── Check 2: 5, 7, 8, or 9 pipe-separated fields (v1, v3, v2, v2+) ──
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

        # ── Check 3: non-empty agent ID ──────────────────────────────────────
        if [[ -z "$f_id" ]]; then
            _orch_cv_error "line $lineno: agent ID is empty"
            continue
        fi

        # ── Check 3: unique agent ID ─────────────────────────────────────────
        if [[ -n "${_seen_ids[$f_id]+x}" ]]; then
            _orch_cv_error "line $lineno: duplicate agent ID '$f_id' (first seen on line ${_seen_ids[$f_id]})"
        else
            _seen_ids["$f_id"]="$lineno"
        fi

        # ── Check 4: prompt path points to an existing file ──────────────────
        if [[ -z "$f_prompt" ]]; then
            _orch_cv_error "line $lineno [$f_id]: prompt path is empty"
        else
            # Prompt paths in agents.conf are relative to the project root.
            # Resolve relative to the directory that contains the conf file.
            local conf_dir
            conf_dir="$(dirname "$conf_file")"
            # agents.conf typically lives in scripts/ or the project root;
            # paths like "prompts/01-ceo/01-ceo.txt" are relative to project root.
            # We resolve relative to the conf file's directory first, then fall
            # back one level up (project root) so both layouts work.
            local resolved_prompt="$conf_dir/$f_prompt"
            if [[ ! -f "$resolved_prompt" ]]; then
                # Try one directory up (project root convention)
                resolved_prompt="$(dirname "$conf_dir")/$f_prompt"
            fi
            if [[ ! -f "$resolved_prompt" ]]; then
                _orch_cv_error "line $lineno [$f_id]: prompt file not found: $f_prompt"
            fi
        fi

        # ── Check 5: interval is a non-negative integer ───────────────────────
        if [[ -z "$f_interval" ]]; then
            _orch_cv_error "line $lineno [$f_id]: interval is empty"
        elif [[ ! "$f_interval" =~ ^[0-9]+$ ]]; then
            _orch_cv_error "line $lineno [$f_id]: interval must be a non-negative integer, got '$f_interval'"
        else
            # ── Check 6: count coordinators ──────────────────────────────────
            if [[ "$f_interval" -eq 0 ]]; then
                (( coordinator_count++ )) || true
            fi
        fi

        # ── Check 7: non-empty label ──────────────────────────────────────────
        if [[ -z "$f_label" ]]; then
            _orch_cv_error "line $lineno [$f_id]: label is empty"
        fi

        # ── Check 8: model value (warn-only per MODEL-001) ───────────────────
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

        # ── Check 9: max_tokens (v3 — numeric, > 0, warn on low) ────────────
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

    # ── Check 6: exactly one coordinator ────────────────────────────────────
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
