#!/usr/bin/env bash
# =============================================================================
# agent-as-tool.sh — Lightweight read-only agent invocations (#26)
#
# Lets agents invoke other agents for quick lookups. The invoked agent runs
# in a restricted mode: it can only read files and return stdout. No file
# writes, no git operations, no prompt modifications.
#
# Usage:
#   source src/core/agent-as-tool.sh
#
#   orch_tool_init
#   orch_tool_register "02-cto" "prompts/02-cto/02-cto.txt" "claude"
#   orch_tool_register "10-security" "prompts/10-security/10-security.txt" "claude"
#
#   orch_tool_invoke "06-backend" "02-cto" "What is the current DB schema?"
#   # => captured stdout from 02-cto's response
#
#   orch_tool_set_timeout 60
#   orch_tool_list
#   orch_tool_is_registered "02-cto" && echo "yes"
#   orch_tool_get_history "06-backend"
#   orch_tool_report
#
# Public API:
#   orch_tool_init                              — initialize module
#   orch_tool_register <id> <prompt> <cli>      — register agent as invocable tool
#   orch_tool_invoke <caller> <target> <query>  — invoke target (read-only)
#   orch_tool_set_timeout <seconds>             — set invocation timeout
#   orch_tool_list                              — list all registered tool agents
#   orch_tool_is_registered <id>                — check if agent is registered
#   orch_tool_get_history <caller_id>           — return invocation history
#   orch_tool_report                            — formatted summary
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_AGENT_TOOL_LOADED:-}" ]] && return 0
readonly _ORCH_AGENT_TOOL_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_TOOL_REGISTRY=()       # agent_id → prompt_path
declare -gA _ORCH_TOOL_CLI=()            # agent_id → cli_command
declare -g  _ORCH_TOOL_TIMEOUT=30        # default timeout in seconds
declare -g  _ORCH_TOOL_ROOT=""           # project root
declare -gA _ORCH_TOOL_HISTORY=()        # caller_id → newline-separated "target:timestamp:status"
declare -g  _ORCH_TOOL_INVOKE_COUNT=0    # total invocations
declare -g  _ORCH_TOOL_HISTORY_LIMIT=50  # max history entries per caller

# ---------------------------------------------------------------------------
# Internal helpers (prefixed _orch_at_)
# ---------------------------------------------------------------------------

# _orch_at_trim <string>
#   Strip leading and trailing whitespace; print the result.
_orch_at_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# _orch_at_timestamp
#   Print current UTC timestamp in ISO-8601 compact form.
_orch_at_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf '%s' "unknown"
}

# _orch_at_log_invocation <caller_id> <target_id> <status>
#   Append an invocation record to the caller's history.
_orch_at_log_invocation() {
    local caller_id="$1" target_id="$2" status="$3"
    local ts
    ts=$(_orch_at_timestamp)
    local entry="${target_id}:${ts}:${status}"

    local existing="${_ORCH_TOOL_HISTORY[$caller_id]:-}"
    if [[ -n "$existing" ]]; then
        _ORCH_TOOL_HISTORY["$caller_id"]="${existing}"$'\n'"${entry}"
    else
        _ORCH_TOOL_HISTORY["$caller_id"]="$entry"
    fi

    # Trim history if it exceeds the limit
    _orch_at_trim_history "$caller_id"

    (( _ORCH_TOOL_INVOKE_COUNT++ )) || true
}

# _orch_at_trim_history <caller_id>
#   Keep only the last N entries for a caller.
_orch_at_trim_history() {
    local caller_id="$1"
    local history="${_ORCH_TOOL_HISTORY[$caller_id]:-}"
    [[ -z "$history" ]] && return 0

    local -a lines
    IFS=$'\n' read -r -d '' -a lines <<< "$history" || true

    local count="${#lines[@]}"
    if (( count > _ORCH_TOOL_HISTORY_LIMIT )); then
        local start=$(( count - _ORCH_TOOL_HISTORY_LIMIT ))
        local trimmed=""
        local i
        for (( i = start; i < count; i++ )); do
            if [[ -n "$trimmed" ]]; then
                trimmed="${trimmed}"$'\n'"${lines[$i]}"
            else
                trimmed="${lines[$i]}"
            fi
        done
        _ORCH_TOOL_HISTORY["$caller_id"]="$trimmed"
    fi
}

# _orch_at_build_prompt <caller_id> <query>
#   Build the read-only wrapped prompt for the target agent.
_orch_at_build_prompt() {
    local caller_id="$1" query="$2"

    cat <<PROMPT
You are being invoked as a READ-ONLY tool by agent ${caller_id}.
Answer the following query. Do NOT modify any files. Do NOT run git commands that change state.
Only provide information via stdout.

Query: ${query}
PROMPT
}

# ---------------------------------------------------------------------------
# orch_tool_init
#
# Initialize the agent-as-tool module. Resets all state. Sets project root
# from the argument, or defaults to the current working directory.
#
# Args:
#   $1 — project root (optional, defaults to PWD)
# ---------------------------------------------------------------------------
orch_tool_init() {
    _ORCH_TOOL_ROOT="${1:-$PWD}"
    _ORCH_TOOL_REGISTRY=()
    _ORCH_TOOL_CLI=()
    _ORCH_TOOL_TIMEOUT=30
    _ORCH_TOOL_HISTORY=()
    _ORCH_TOOL_INVOKE_COUNT=0
}

# ---------------------------------------------------------------------------
# orch_tool_register <agent_id> <prompt_path> <model_cli>
#
# Register an agent as an invocable read-only tool.
#
# Args:
#   $1 — agent_id    (e.g., "02-cto")
#   $2 — prompt_path (path to the agent's prompt file)
#   $3 — model_cli   (CLI command to invoke, e.g., "claude", "codex exec")
# ---------------------------------------------------------------------------
orch_tool_register() {
    local agent_id="$1"
    local prompt_path="$2"
    local model_cli="$3"

    if [[ -z "$agent_id" ]] || [[ -z "$prompt_path" ]] || [[ -z "$model_cli" ]]; then
        printf '[agent-as-tool] ERROR: register requires agent_id, prompt_path, and model_cli\n' >&2
        return 1
    fi

    _ORCH_TOOL_REGISTRY["$agent_id"]="$prompt_path"
    _ORCH_TOOL_CLI["$agent_id"]="$model_cli"
}

# ---------------------------------------------------------------------------
# orch_tool_invoke <caller_id> <target_id> <query>
#
# Invoke a registered agent as a read-only tool. Builds a restricted prompt,
# invokes the target's CLI with a timeout, and returns captured stdout.
#
# Args:
#   $1 — caller_id  (the agent making the request)
#   $2 — target_id  (the agent being invoked)
#   $3 — query      (the question / lookup request)
#
# Returns:
#   0 — success (stdout contains the agent's response)
#   1 — timeout
#   2 — unknown target (not registered)
#   3 — self-invoke (caller == target)
# ---------------------------------------------------------------------------
orch_tool_invoke() {
    local caller_id="$1"
    local target_id="$2"
    local query="$3"

    if [[ -z "$caller_id" ]] || [[ -z "$target_id" ]] || [[ -z "$query" ]]; then
        printf '[agent-as-tool] ERROR: invoke requires caller_id, target_id, and query\n' >&2
        return 1
    fi

    # Self-invoke guard
    if [[ "$caller_id" == "$target_id" ]]; then
        printf '[agent-as-tool] ERROR: agent %s cannot invoke itself\n' "$caller_id" >&2
        _orch_at_log_invocation "$caller_id" "$target_id" "self-invoke"
        return 3
    fi

    # Target must be registered
    if [[ -z "${_ORCH_TOOL_REGISTRY[$target_id]:-}" ]]; then
        printf '[agent-as-tool] ERROR: target agent %s is not registered as a tool\n' "$target_id" >&2
        _orch_at_log_invocation "$caller_id" "$target_id" "unknown-target"
        return 2
    fi

    local cli_cmd="${_ORCH_TOOL_CLI[$target_id]}"
    local prompt_path="${_ORCH_TOOL_REGISTRY[$target_id]}"

    # Build the read-only prompt
    local wrapped_prompt
    wrapped_prompt=$(_orch_at_build_prompt "$caller_id" "$query")

    # Use mock command if set (for testing), otherwise use the real CLI
    local effective_cmd="${_ORCH_TOOL_MOCK_CMD:-$cli_cmd}"

    # Invoke with timeout
    local result
    local exit_code
    result=$(timeout "$_ORCH_TOOL_TIMEOUT" $effective_cmd "$wrapped_prompt" 2>/dev/null)
    exit_code=$?

    # timeout(1) returns 124 on timeout
    if [[ "$exit_code" -eq 124 ]]; then
        printf '[agent-as-tool] ERROR: invocation of %s timed out after %ds\n' \
            "$target_id" "$_ORCH_TOOL_TIMEOUT" >&2
        _orch_at_log_invocation "$caller_id" "$target_id" "timeout"
        return 1
    fi

    if [[ "$exit_code" -ne 0 ]]; then
        printf '[agent-as-tool] WARN: %s exited with code %d\n' "$target_id" "$exit_code" >&2
        _orch_at_log_invocation "$caller_id" "$target_id" "error:${exit_code}"
        printf '%s' "$result"
        return "$exit_code"
    fi

    _orch_at_log_invocation "$caller_id" "$target_id" "ok"
    printf '%s' "$result"
    return 0
}

# ---------------------------------------------------------------------------
# orch_tool_set_timeout <seconds>
#
# Set the invocation timeout in seconds.
#
# Args:
#   $1 — timeout in seconds (positive integer)
# ---------------------------------------------------------------------------
orch_tool_set_timeout() {
    local seconds="$1"

    if [[ -z "$seconds" ]] || ! [[ "$seconds" =~ ^[0-9]+$ ]] || [[ "$seconds" -eq 0 ]]; then
        printf '[agent-as-tool] ERROR: set_timeout requires a positive integer\n' >&2
        return 1
    fi

    _ORCH_TOOL_TIMEOUT="$seconds"
}

# ---------------------------------------------------------------------------
# orch_tool_list
#
# List all registered tool agents. Prints one line per agent with its ID,
# prompt path, and CLI command.
# ---------------------------------------------------------------------------
orch_tool_list() {
    if [[ ${#_ORCH_TOOL_REGISTRY[@]} -eq 0 ]]; then
        printf '(no agents registered as tools)\n'
        return 0
    fi

    local agent_id
    for agent_id in $(printf '%s\n' "${!_ORCH_TOOL_REGISTRY[@]}" | sort); do
        local prompt="${_ORCH_TOOL_REGISTRY[$agent_id]}"
        local cli="${_ORCH_TOOL_CLI[$agent_id]}"
        printf '  %-16s  prompt=%-40s  cli=%s\n' "$agent_id" "$prompt" "$cli"
    done
}

# ---------------------------------------------------------------------------
# orch_tool_is_registered <agent_id>
#
# Check if an agent is registered as a tool.
#
# Args:
#   $1 — agent_id
#
# Returns: 0 if registered, 1 if not
# ---------------------------------------------------------------------------
orch_tool_is_registered() {
    local agent_id="$1"

    if [[ -z "$agent_id" ]]; then
        return 1
    fi

    [[ -n "${_ORCH_TOOL_REGISTRY[$agent_id]:-}" ]]
}

# ---------------------------------------------------------------------------
# orch_tool_get_history <caller_id>
#
# Return invocation history for a caller. Prints one line per invocation
# in the format "target:timestamp:status".
#
# Args:
#   $1 — caller_id
# ---------------------------------------------------------------------------
orch_tool_get_history() {
    local caller_id="$1"

    if [[ -z "$caller_id" ]]; then
        printf '[agent-as-tool] ERROR: get_history requires caller_id\n' >&2
        return 1
    fi

    local history="${_ORCH_TOOL_HISTORY[$caller_id]:-}"
    if [[ -z "$history" ]]; then
        printf '(no invocation history for %s)\n' "$caller_id"
        return 0
    fi

    printf '%s\n' "$history"
}

# ---------------------------------------------------------------------------
# orch_tool_report
#
# Print a formatted summary of all registrations and recent invocations.
# ---------------------------------------------------------------------------
orch_tool_report() {
    printf '=== Agent-as-Tool Report ===\n'
    printf 'Project root: %s\n' "$_ORCH_TOOL_ROOT"
    printf 'Timeout:      %ds\n' "$_ORCH_TOOL_TIMEOUT"
    printf 'Total invocations: %d\n\n' "$_ORCH_TOOL_INVOKE_COUNT"

    printf '── Registered Tools ──\n'
    if [[ ${#_ORCH_TOOL_REGISTRY[@]} -eq 0 ]]; then
        printf '  (none)\n'
    else
        local agent_id
        for agent_id in $(printf '%s\n' "${!_ORCH_TOOL_REGISTRY[@]}" | sort); do
            local prompt="${_ORCH_TOOL_REGISTRY[$agent_id]}"
            local cli="${_ORCH_TOOL_CLI[$agent_id]}"
            printf '  %-16s  cli=%-20s  prompt=%s\n' "$agent_id" "$cli" "$prompt"
        done
    fi
    printf '\n'

    printf '── Recent Invocations ──\n'
    if [[ ${#_ORCH_TOOL_HISTORY[@]} -eq 0 ]]; then
        printf '  (none)\n'
    else
        local caller_id
        for caller_id in $(printf '%s\n' "${!_ORCH_TOOL_HISTORY[@]}" | sort); do
            printf '  %s:\n' "$caller_id"
            local history="${_ORCH_TOOL_HISTORY[$caller_id]}"
            local line
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                printf '    %s\n' "$line"
            done <<< "$history"
        done
    fi
    printf '\n'
}
