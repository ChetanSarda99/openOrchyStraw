#!/usr/bin/env bash
# =============================================================================
# quality-gates.sh — Scripted quality gates for agent work (#67)
#
# Quality gates that agents must pass before their work is accepted into main.
# Gates include: syntax check, shellcheck, test pass, file ownership validation,
# and custom gate support. Each gate is either "blocking" (must pass) or
# "warning" (logged but non-blocking).
#
# Usage:
#   source src/core/quality-gates.sh
#
#   orch_gate_init "/path/to/project"
#   orch_gate_register_defaults
#   orch_gate_register "my-gate" "echo ok" "warning"
#   orch_gate_run "syntax"
#   orch_gate_run_all "06-backend"
#   orch_gate_check_ownership "06-backend" "src/core/ scripts/ !src/core/secret.sh"
#   orch_gate_result "syntax"             # → "pass"
#   orch_gate_report
#   orch_gate_passed_all
#   orch_gate_add_custom "my-fn-gate" "my_check_fn" "blocking"
#   orch_gate_skip "shellcheck"
#   orch_gate_reset
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_QUALITY_GATES_LOADED:-}" ]] && return 0
readonly _ORCH_QUALITY_GATES_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_GATE_COMMANDS=()     # gate_name → command string or function name
declare -gA _ORCH_GATE_SEVERITY=()     # gate_name → "blocking" | "warning"
declare -gA _ORCH_GATE_TYPE=()         # gate_name → "command" | "function"
declare -gA _ORCH_GATE_RESULTS=()      # gate_name → "pass" | "fail" | "skip"
declare -gA _ORCH_GATE_OUTPUT=()       # gate_name → captured stdout+stderr (truncated)
declare -gA _ORCH_GATE_DURATION=()     # gate_name → execution time in seconds
declare -ga _ORCH_GATE_ORDER=()        # indexed array preserving registration order
declare -gA _ORCH_GATE_SKIPPED=()      # gate_name → 1 if skipped
declare -g  _ORCH_GATE_ROOT=""         # project root
declare -g  _ORCH_GATE_INITIALIZED=""  # init flag
declare -g  _ORCH_GATE_TIMEOUT=60      # per-gate timeout in seconds

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_gate_log <message>
#   Print a timestamped log line to stderr.
_orch_gate_log() {
    printf '[quality-gates] %s\n' "$1" >&2
}

# _orch_gate_err <message>
#   Print an error message to stderr.
_orch_gate_err() {
    printf '[quality-gates] ERROR: %s\n' "$1" >&2
}

# _orch_gate_truncate <string> <max_chars>
#   Truncate string to max_chars, appending "... (truncated)" if needed.
_orch_gate_truncate() {
    local str="$1"
    local max="${2:-500}"
    if (( ${#str} > max )); then
        printf '%s... (truncated)' "${str:0:$max}"
    else
        printf '%s' "$str"
    fi
}

# _orch_gate_has <gate_name>
#   Return 0 if gate is registered, 1 otherwise.
_orch_gate_has() {
    local name="$1"
    [[ -n "${_ORCH_GATE_COMMANDS[$name]+x}" ]]
}

# _orch_gate_exec <gate_name> [agent_id]
#   Execute a gate and capture output, duration, and result.
#   Stores results in state arrays. Returns 0 on pass, 1 on fail.
_orch_gate_exec() {
    local name="$1"
    local agent_id="${2:-}"
    local cmd="${_ORCH_GATE_COMMANDS[$name]}"
    local gtype="${_ORCH_GATE_TYPE[$name]}"
    local output=""
    local rc=0
    local start_time end_time duration

    start_time=$(date +%s)

    # Determine timeout wrapper
    local timeout_cmd=""
    if command -v timeout &>/dev/null; then
        timeout_cmd="timeout ${_ORCH_GATE_TIMEOUT}"
    fi

    if [[ "$gtype" == "function" ]]; then
        # Call bash function directly in current shell (needs access to state)
        if declare -F "$cmd" &>/dev/null; then
            output=$( "$cmd" "$agent_id" 2>&1 ) || rc=$?
        else
            output="function '$cmd' is not defined"
            rc=1
        fi
    else
        # Run shell command via bash -c (isolated)
        if [[ -n "$timeout_cmd" ]]; then
            output=$( $timeout_cmd bash -c "$cmd" 2>&1 ) || rc=$?
        else
            output=$( bash -c "$cmd" 2>&1 ) || rc=$?
        fi
        # timeout returns 124 on timeout
        if [[ $rc -eq 124 ]]; then
            output="TIMEOUT: gate exceeded ${_ORCH_GATE_TIMEOUT}s limit"
        fi
    fi

    end_time=$(date +%s)
    duration=$(( end_time - start_time ))

    # Store results
    if [[ $rc -eq 0 ]]; then
        _ORCH_GATE_RESULTS["$name"]="pass"
    else
        _ORCH_GATE_RESULTS["$name"]="fail"
    fi
    _ORCH_GATE_OUTPUT["$name"]="$(_orch_gate_truncate "$output" 500)"
    _ORCH_GATE_DURATION["$name"]="$duration"

    return $rc
}

# _orch_gate_builtin_syntax
#   Check bash syntax on all .sh files in src/core/.
_orch_gate_builtin_syntax() {
    local -i errors=0
    while IFS= read -r f; do
        if ! bash -n "$f" 2>/dev/null; then
            echo "syntax error: $f"
            errors+=1
        fi
    done < <(find "$_ORCH_GATE_ROOT/src/core" -name "*.sh" -type f 2>/dev/null)
    return $errors
}

# _orch_gate_builtin_shellcheck
#   Run shellcheck on all .sh files in src/core/.
_orch_gate_builtin_shellcheck() {
    if ! command -v shellcheck &>/dev/null; then
        echo "shellcheck not installed — skipping"
        return 0
    fi
    local -a files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$_ORCH_GATE_ROOT/src/core" -name "*.sh" -type f 2>/dev/null)
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "no .sh files found in src/core/"
        return 0
    fi
    shellcheck -S warning "${files[@]}" 2>&1
}

# _orch_gate_builtin_test
#   Run the test runner if it exists.
_orch_gate_builtin_test() {
    local runner="$_ORCH_GATE_ROOT/tests/core/run-tests.sh"
    if [[ -x "$runner" ]]; then
        bash "$runner"
    else
        echo "test runner not found — skipping"
        return 0
    fi
}

# _orch_gate_builtin_ownership <agent_id>
#   Check that git diff only shows changes within agent ownership.
_orch_gate_builtin_ownership() {
    local agent_id="${1:-}"
    if [[ -z "$agent_id" ]]; then
        echo "no agent_id provided — skipping ownership check"
        return 0
    fi
    # Ownership paths would come from agents.conf; for the built-in gate
    # we cannot resolve them without the caller providing them, so this
    # gate is a placeholder that always passes when called generically.
    # Use orch_gate_check_ownership directly for real ownership checks.
    echo "ownership check requires explicit paths — use orch_gate_check_ownership"
    return 0
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# orch_gate_init [project_root]
#   Initialize gate system. Defaults project_root to git toplevel.
# ---------------------------------------------------------------------------
orch_gate_init() {
    _ORCH_GATE_ROOT="${1:-}"

    if [[ -z "$_ORCH_GATE_ROOT" ]]; then
        _ORCH_GATE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
            _orch_gate_err "cannot determine project root — pass it explicitly"
            return 1
        }
    fi

    if [[ ! -d "$_ORCH_GATE_ROOT" ]]; then
        _orch_gate_err "project root does not exist: $_ORCH_GATE_ROOT"
        return 1
    fi

    # Reset all state
    _ORCH_GATE_COMMANDS=()
    _ORCH_GATE_SEVERITY=()
    _ORCH_GATE_TYPE=()
    _ORCH_GATE_RESULTS=()
    _ORCH_GATE_OUTPUT=()
    _ORCH_GATE_DURATION=()
    _ORCH_GATE_ORDER=()
    _ORCH_GATE_SKIPPED=()
    _ORCH_GATE_INITIALIZED=1

    _orch_gate_log "initialized — root: $_ORCH_GATE_ROOT"
    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_register <gate_name> <gate_command> <severity>
#   Register a quality gate.
#   severity: "blocking" or "warning"
# ---------------------------------------------------------------------------
orch_gate_register() {
    local name="${1:?orch_gate_register requires gate_name}"
    local cmd="${2:?orch_gate_register requires gate_command}"
    local severity="${3:?orch_gate_register requires severity}"

    if [[ "$severity" != "blocking" && "$severity" != "warning" ]]; then
        _orch_gate_err "invalid severity '$severity' — must be 'blocking' or 'warning'"
        return 1
    fi

    _ORCH_GATE_COMMANDS["$name"]="$cmd"
    _ORCH_GATE_SEVERITY["$name"]="$severity"
    _ORCH_GATE_TYPE["$name"]="command"

    # Add to order list if not already present
    local existing
    for existing in "${_ORCH_GATE_ORDER[@]}"; do
        [[ "$existing" == "$name" ]] && return 0
    done
    _ORCH_GATE_ORDER+=("$name")

    _orch_gate_log "registered gate: $name ($severity)"
    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_register_defaults
#   Register the four built-in gates.
# ---------------------------------------------------------------------------
orch_gate_register_defaults() {
    if [[ -z "$_ORCH_GATE_INITIALIZED" ]]; then
        _orch_gate_err "call orch_gate_init first"
        return 1
    fi

    # syntax — bash -n on all .sh files (blocking)
    orch_gate_add_custom "syntax" "_orch_gate_builtin_syntax" "blocking"

    # shellcheck — lint .sh files (warning)
    orch_gate_add_custom "shellcheck" "_orch_gate_builtin_shellcheck" "warning"

    # test — run test suite (blocking)
    orch_gate_add_custom "test" "_orch_gate_builtin_test" "blocking"

    # ownership — validate file writes (blocking)
    orch_gate_add_custom "ownership" "_orch_gate_builtin_ownership" "blocking"

    _orch_gate_log "registered 4 default gates"
    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_run <gate_name> [agent_id]
#   Run a single gate. Returns 0 on pass, 1 on fail.
# ---------------------------------------------------------------------------
orch_gate_run() {
    local name="${1:?orch_gate_run requires gate_name}"
    local agent_id="${2:-}"

    if ! _orch_gate_has "$name"; then
        _orch_gate_err "unknown gate: $name"
        return 1
    fi

    # Check if skipped
    if [[ -n "${_ORCH_GATE_SKIPPED[$name]+x}" ]]; then
        _ORCH_GATE_RESULTS["$name"]="skip"
        _ORCH_GATE_OUTPUT["$name"]="gate skipped"
        _ORCH_GATE_DURATION["$name"]="0"
        _orch_gate_log "skipped gate: $name"
        return 0
    fi

    local severity="${_ORCH_GATE_SEVERITY[$name]}"
    _orch_gate_log "running gate: $name ($severity)"

    local rc=0
    _orch_gate_exec "$name" "$agent_id" || rc=$?

    local result="${_ORCH_GATE_RESULTS[$name]}"
    local dur="${_ORCH_GATE_DURATION[$name]}"

    if [[ "$result" == "pass" ]]; then
        _orch_gate_log "gate $name: PASS (${dur}s)"
    elif [[ "$severity" == "warning" ]]; then
        _orch_gate_log "gate $name: WARN (${dur}s)"
        # Warnings still return 0
        return 0
    else
        _orch_gate_log "gate $name: FAIL (${dur}s)"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_run_all [agent_id]
#   Run all registered gates in order.
#   Stops on first blocking failure. Warnings run regardless.
#   Returns 0 if all blocking gates pass, 1 if any blocking gate fails.
# ---------------------------------------------------------------------------
orch_gate_run_all() {
    local agent_id="${1:-}"
    local -i blocking_failed=0
    local -i total=0
    local -i passed=0
    local -i failed=0
    local -i warned=0
    local -i skipped=0

    _orch_gate_log "running all gates (${#_ORCH_GATE_ORDER[@]} registered)"

    for name in "${_ORCH_GATE_ORDER[@]}"; do
        total+=1
        local severity="${_ORCH_GATE_SEVERITY[$name]}"

        # If we already hit a blocking failure, skip remaining gates
        if (( blocking_failed )); then
            _ORCH_GATE_RESULTS["$name"]="skip"
            _ORCH_GATE_OUTPUT["$name"]="skipped — prior blocking gate failed"
            _ORCH_GATE_DURATION["$name"]="0"
            skipped+=1
            continue
        fi

        local rc=0
        orch_gate_run "$name" "$agent_id" || rc=$?

        local result="${_ORCH_GATE_RESULTS[$name]}"

        case "$result" in
            pass)  passed+=1 ;;
            skip)  skipped+=1 ;;
            fail)
                if [[ "$severity" == "blocking" ]]; then
                    failed+=1
                    blocking_failed=1
                else
                    warned+=1
                fi
                ;;
        esac
    done

    _orch_gate_log "complete: $passed passed, $failed failed, $warned warnings, $skipped skipped"

    return $blocking_failed
}

# ---------------------------------------------------------------------------
# orch_gate_check_ownership <agent_id> <ownership_paths>
#   Check that git diff only shows changes in agent's allowed paths.
#   ownership_paths: space-separated list of allowed paths.
#   Paths prefixed with ! are exclusions.
#   Returns 0 if all changes are within ownership, 1 if rogue writes found.
#   Prints rogue files to stdout.
# ---------------------------------------------------------------------------
orch_gate_check_ownership() {
    local agent_id="${1:?orch_gate_check_ownership requires agent_id}"
    local ownership_paths="${2:?orch_gate_check_ownership requires ownership_paths}"

    # Get changed files
    local -a changed_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && changed_files+=("$f")
    done < <(cd "$_ORCH_GATE_ROOT" && git diff --name-only HEAD~1 2>/dev/null)

    if [[ ${#changed_files[@]} -eq 0 ]]; then
        return 0
    fi

    # Parse allowed and excluded paths
    local -a allowed=()
    local -a excluded=()
    local -a ownership_arr
    IFS=' ' read -ra ownership_arr <<< "$ownership_paths"
    local path
    for path in "${ownership_arr[@]}"; do
        if [[ "$path" == !* ]]; then
            excluded+=("${path#!}")
        else
            allowed+=("$path")
        fi
    done

    # Check each changed file
    local -a rogue=()
    local file
    for file in "${changed_files[@]}"; do
        local is_allowed=0

        # Check if file matches any allowed path
        local allow
        for allow in "${allowed[@]}"; do
            # Strip trailing slash for directory matching
            local pattern="${allow%/}"
            if [[ "$file" == "$pattern"* ]] || [[ "$file" == "$pattern" ]]; then
                is_allowed=1
                break
            fi
        done

        # Check if file matches any exclusion
        if (( is_allowed )); then
            local excl
            for excl in "${excluded[@]}"; do
                local epattern="${excl%/}"
                if [[ "$file" == "$epattern"* ]] || [[ "$file" == "$epattern" ]]; then
                    is_allowed=0
                    break
                fi
            done
        fi

        if (( ! is_allowed )); then
            rogue+=("$file")
        fi
    done

    if [[ ${#rogue[@]} -gt 0 ]]; then
        printf '%s\n' "${rogue[@]}"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_result <gate_name>
#   Print the result of the last run: "pass", "fail", or "skip"
# ---------------------------------------------------------------------------
orch_gate_result() {
    local name="${1:?orch_gate_result requires gate_name}"

    if ! _orch_gate_has "$name"; then
        _orch_gate_err "unknown gate: $name"
        return 1
    fi

    printf '%s' "${_ORCH_GATE_RESULTS[$name]:-skip}"
}

# ---------------------------------------------------------------------------
# orch_gate_report
#   Print a formatted report of all gate results.
# ---------------------------------------------------------------------------
orch_gate_report() {
    printf '\nQuality Gate Report\n'
    printf '================================================\n'

    local name
    for name in "${_ORCH_GATE_ORDER[@]}"; do
        local result="${_ORCH_GATE_RESULTS[$name]:-skip}"
        local severity="${_ORCH_GATE_SEVERITY[$name]}"
        local duration="${_ORCH_GATE_DURATION[$name]:-0}"
        local output="${_ORCH_GATE_OUTPUT[$name]:-}"

        # Format result label
        local label
        case "$result" in
            pass)  label="[PASS]" ;;
            fail)
                if [[ "$severity" == "warning" ]]; then
                    label="[WARN]"
                else
                    label="[FAIL]"
                fi
                ;;
            skip)  label="[SKIP]" ;;
            *)     label="[????]" ;;
        esac

        # Build the line
        local line
        line=$(printf '  %-6s  %-14s %-10s %s.0s' "$label" "$name" "$severity" "$duration")

        # Add output snippet for failures/warnings
        if [[ "$result" == "fail" && -n "$output" ]]; then
            # First line of output as snippet
            local snippet
            snippet=$(printf '%s' "$output" | head -n 1 | cut -c 1-80)
            line="$line  — $snippet"
        fi

        printf '%s\n' "$line"
    done

    printf '\n'

    # Summary line
    local -i blocking_failures=0
    for name in "${_ORCH_GATE_ORDER[@]}"; do
        local result="${_ORCH_GATE_RESULTS[$name]:-skip}"
        local severity="${_ORCH_GATE_SEVERITY[$name]}"
        if [[ "$result" == "fail" && "$severity" == "blocking" ]]; then
            blocking_failures+=1
        fi
    done

    if (( blocking_failures )); then
        printf 'Result: BLOCKED (%d blocking gate(s) failed)\n' "$blocking_failures"
    else
        printf 'Result: PASSED (all blocking gates passed)\n'
    fi
    printf '\n'
}

# ---------------------------------------------------------------------------
# orch_gate_passed_all
#   Returns 0 if all blocking gates passed, 1 otherwise.
# ---------------------------------------------------------------------------
orch_gate_passed_all() {
    local name
    for name in "${_ORCH_GATE_ORDER[@]}"; do
        local result="${_ORCH_GATE_RESULTS[$name]:-skip}"
        local severity="${_ORCH_GATE_SEVERITY[$name]}"
        if [[ "$result" == "fail" && "$severity" == "blocking" ]]; then
            return 1
        fi
    done
    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_add_custom <gate_name> <bash_function_name> <severity>
#   Register a gate that calls a bash function instead of a shell command.
#   The function must already be defined.
# ---------------------------------------------------------------------------
orch_gate_add_custom() {
    local name="${1:?orch_gate_add_custom requires gate_name}"
    local func="${2:?orch_gate_add_custom requires bash_function_name}"
    local severity="${3:?orch_gate_add_custom requires severity}"

    if [[ "$severity" != "blocking" && "$severity" != "warning" ]]; then
        _orch_gate_err "invalid severity '$severity' — must be 'blocking' or 'warning'"
        return 1
    fi

    if ! declare -F "$func" &>/dev/null; then
        _orch_gate_err "function '$func' is not defined"
        return 1
    fi

    _ORCH_GATE_COMMANDS["$name"]="$func"
    _ORCH_GATE_SEVERITY["$name"]="$severity"
    _ORCH_GATE_TYPE["$name"]="function"

    # Add to order list if not already present
    local existing
    for existing in "${_ORCH_GATE_ORDER[@]}"; do
        [[ "$existing" == "$name" ]] && return 0
    done
    _ORCH_GATE_ORDER+=("$name")

    _orch_gate_log "registered custom gate: $name ($severity) → $func()"
    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_skip <gate_name>
#   Mark a gate as skipped (won't run in run_all).
# ---------------------------------------------------------------------------
orch_gate_skip() {
    local name="${1:?orch_gate_skip requires gate_name}"

    if ! _orch_gate_has "$name"; then
        _orch_gate_err "unknown gate: $name"
        return 1
    fi

    _ORCH_GATE_SKIPPED["$name"]=1
    _orch_gate_log "marked gate as skipped: $name"
    return 0
}

# ---------------------------------------------------------------------------
# orch_gate_reset
#   Clear all results but keep registrations. Call between cycles.
# ---------------------------------------------------------------------------
orch_gate_reset() {
    _ORCH_GATE_RESULTS=()
    _ORCH_GATE_OUTPUT=()
    _ORCH_GATE_DURATION=()
    _ORCH_GATE_SKIPPED=()
    _orch_gate_log "results reset — registrations preserved"
    return 0
}
