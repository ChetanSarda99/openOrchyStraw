#!/usr/bin/env bash
# =============================================================================
# model-router.sh — Model tiering per agent (#30)
#
# Routes agents to different AI CLI tools (claude, codex, gemini) based on
# configuration in agents.conf. Each model has a CLI binary and default args.
#
# Usage:
#   source src/core/model-router.sh
#
#   orch_model_init
#   orch_model_assign "09-qa" "codex"
#   orch_model_get_cli "09-qa"        # → "codex exec"
#   orch_model_get_name "09-qa"       # → "codex"
#   orch_model_parse_config agents.conf
#   orch_model_report
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_MODEL_ROUTER_LOADED:-}" ]] && return 0
readonly _ORCH_MODEL_ROUTER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_MODEL_CLI=()        # model_name → cli_command
declare -gA _ORCH_MODEL_ARGS=()       # model_name → cli_args
declare -gA _ORCH_MODEL_AGENT=()      # agent_id → model_name
declare -g  _ORCH_MODEL_DEFAULT="claude"
declare -ga _ORCH_MODEL_NAMES=()      # list of registered model names

# ---------------------------------------------------------------------------
# orch_model_init — Initialize with default model mappings
#
# Registers the three built-in models: claude, codex, gemini.
# Resets all agent assignments. Safe to call multiple times.
# ---------------------------------------------------------------------------
orch_model_init() {
    _ORCH_MODEL_CLI=()
    _ORCH_MODEL_ARGS=()
    _ORCH_MODEL_AGENT=()
    _ORCH_MODEL_NAMES=()
    _ORCH_MODEL_DEFAULT="claude"

    # Default registrations per CLAUDE.md model routing table
    orch_model_register "claude" "claude" ""
    orch_model_register "codex"  "codex"  "exec"
    orch_model_register "gemini" "gemini" "-p"
}

# ---------------------------------------------------------------------------
# orch_model_register — Register a model with its CLI command and args
#
# Args:
#   $1 — model_name  (e.g., "claude", "codex", "gemini")
#   $2 — cli_command  (the binary to invoke)
#   $3 — cli_args     (default arguments, may be empty)
# ---------------------------------------------------------------------------
orch_model_register() {
    local model_name="$1"
    local cli_command="$2"
    local cli_args="${3:-}"

    if [[ -z "$model_name" ]] || [[ -z "$cli_command" ]]; then
        printf '[model-router] ERROR: register requires model_name and cli_command\n' >&2
        return 1
    fi

    _ORCH_MODEL_CLI["$model_name"]="$cli_command"
    _ORCH_MODEL_ARGS["$model_name"]="$cli_args"

    # Add to names list if not already present
    local name
    for name in "${_ORCH_MODEL_NAMES[@]}"; do
        [[ "$name" == "$model_name" ]] && return 0
    done
    _ORCH_MODEL_NAMES+=("$model_name")
}

# ---------------------------------------------------------------------------
# orch_model_set_default — Set the default model for unassigned agents
#
# Args:
#   $1 — model_name (must be a registered model)
# ---------------------------------------------------------------------------
orch_model_set_default() {
    local model_name="$1"

    if [[ -z "$model_name" ]]; then
        printf '[model-router] ERROR: set_default requires a model_name\n' >&2
        return 1
    fi

    if [[ -z "${_ORCH_MODEL_CLI[$model_name]:-}" ]]; then
        printf '[model-router] ERROR: model "%s" is not registered\n' "$model_name" >&2
        return 1
    fi

    _ORCH_MODEL_DEFAULT="$model_name"
}

# ---------------------------------------------------------------------------
# orch_model_assign — Assign a model to a specific agent
#
# Args:
#   $1 — agent_id   (e.g., "06-backend")
#   $2 — model_name (e.g., "codex"; must be registered)
# ---------------------------------------------------------------------------
orch_model_assign() {
    local agent_id="$1"
    local model_name="$2"

    if [[ -z "$agent_id" ]] || [[ -z "$model_name" ]]; then
        printf '[model-router] ERROR: assign requires agent_id and model_name\n' >&2
        return 1
    fi

    if [[ -z "${_ORCH_MODEL_CLI[$model_name]:-}" ]]; then
        printf '[model-router] WARN: model "%s" not registered, assigning anyway\n' "$model_name" >&2
    fi

    _ORCH_MODEL_AGENT["$agent_id"]="$model_name"
}

# ---------------------------------------------------------------------------
# orch_model_parse_config — Parse agents.conf for model assignments
#
# Reads the pipe-delimited config file. The 6th column (index 5) is the
# model name. If absent or empty, the default model is used.
#
# Format: id | prompt_path | ownership | interval | label | model
#
# Args:
#   $1 — path to agents.conf
# ---------------------------------------------------------------------------
orch_model_parse_config() {
    local conf_file="$1"

    if [[ ! -f "$conf_file" ]]; then
        printf '[model-router] ERROR: config file not found: %s\n' "$conf_file" >&2
        return 1
    fi

    local line
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Split on pipe delimiter
        IFS='|' read -ra fields <<< "$line"

        # Extract agent ID (column 1) — trim whitespace
        local agent_id
        agent_id="$(_orch_model_trim "${fields[0]:-}")"
        [[ -z "$agent_id" ]] && continue

        # Extract model name (column 6, index 5) — trim whitespace
        local model_name
        model_name="$(_orch_model_trim "${fields[5]:-}")"

        # Use default if no model specified
        if [[ -z "$model_name" ]]; then
            model_name="$_ORCH_MODEL_DEFAULT"
        fi

        _ORCH_MODEL_AGENT["$agent_id"]="$model_name"
    done < "$conf_file"
}

# ---------------------------------------------------------------------------
# orch_model_get_cli — Return the full CLI command for an agent
#
# Combines the CLI binary and default args for the agent's assigned model.
# Falls back to the default model if no explicit assignment exists.
#
# Args:
#   $1 — agent_id
#
# Outputs: full CLI command string (e.g., "codex exec", "claude", "gemini -p")
# ---------------------------------------------------------------------------
orch_model_get_cli() {
    local agent_id="$1"

    local model_name="${_ORCH_MODEL_AGENT[$agent_id]:-$_ORCH_MODEL_DEFAULT}"
    local cli="${_ORCH_MODEL_CLI[$model_name]:-}"
    local args="${_ORCH_MODEL_ARGS[$model_name]:-}"

    if [[ -z "$cli" ]]; then
        # Model not registered — fall back to default
        cli="${_ORCH_MODEL_CLI[$_ORCH_MODEL_DEFAULT]:-claude}"
        args="${_ORCH_MODEL_ARGS[$_ORCH_MODEL_DEFAULT]:-}"
    fi

    if [[ -n "$args" ]]; then
        echo "${cli} ${args}"
    else
        echo "$cli"
    fi
}

# ---------------------------------------------------------------------------
# orch_model_get_name — Return the model name assigned to an agent
#
# Args:
#   $1 — agent_id
#
# Outputs: model name (e.g., "claude", "codex", "gemini")
# ---------------------------------------------------------------------------
orch_model_get_name() {
    local agent_id="$1"
    echo "${_ORCH_MODEL_AGENT[$agent_id]:-$_ORCH_MODEL_DEFAULT}"
}

# ---------------------------------------------------------------------------
# orch_model_is_available — Check if the CLI binary for a model exists in PATH
#
# Args:
#   $1 — model_name
#
# Returns: 0 if available, 1 if not
# ---------------------------------------------------------------------------
orch_model_is_available() {
    local model_name="$1"

    local cli="${_ORCH_MODEL_CLI[$model_name]:-}"
    if [[ -z "$cli" ]]; then
        return 1
    fi

    command -v "$cli" &>/dev/null
}

# ---------------------------------------------------------------------------
# orch_model_fallback — Fall back to default model if assigned model unavailable
#
# Checks whether the agent's assigned model CLI is in PATH. If not, falls
# back to the default model and logs a warning.
#
# Args:
#   $1 — agent_id
#
# Outputs: the CLI command to use (original or fallback)
# Returns: 0 if original available, 1 if fell back to default
# ---------------------------------------------------------------------------
orch_model_fallback() {
    local agent_id="$1"

    local model_name="${_ORCH_MODEL_AGENT[$agent_id]:-$_ORCH_MODEL_DEFAULT}"

    # Check if the assigned model's CLI is available
    if orch_model_is_available "$model_name"; then
        orch_model_get_cli "$agent_id"
        return 0
    fi

    # Fall back to default
    printf '[model-router] WARN: %s CLI for agent %s not found in PATH, falling back to %s\n' \
        "$model_name" "$agent_id" "$_ORCH_MODEL_DEFAULT" >&2

    # Check default is available too
    if ! orch_model_is_available "$_ORCH_MODEL_DEFAULT"; then
        printf '[model-router] ERROR: default model %s also not available\n' "$_ORCH_MODEL_DEFAULT" >&2
        echo "$_ORCH_MODEL_DEFAULT"
        return 1
    fi

    local cli="${_ORCH_MODEL_CLI[$_ORCH_MODEL_DEFAULT]:-claude}"
    local args="${_ORCH_MODEL_ARGS[$_ORCH_MODEL_DEFAULT]:-}"

    if [[ -n "$args" ]]; then
        echo "${cli} ${args}"
    else
        echo "$cli"
    fi
    return 1
}

# ---------------------------------------------------------------------------
# orch_model_list_agents — List all agents assigned to a given model
#
# Args:
#   $1 — model_name
#
# Outputs: space-separated list of agent IDs
# ---------------------------------------------------------------------------
orch_model_list_agents() {
    local model_name="$1"

    local -a agents=()
    local agent_id
    for agent_id in "${!_ORCH_MODEL_AGENT[@]}"; do
        if [[ "${_ORCH_MODEL_AGENT[$agent_id]}" == "$model_name" ]]; then
            agents+=("$agent_id")
        fi
    done

    # Sort for deterministic output
    local IFS=$'\n'
    local -a sorted
    sorted=($(sort <<< "${agents[*]}"))
    echo "${sorted[*]}"
}

# ---------------------------------------------------------------------------
# orch_model_report — Print formatted summary of all model assignments
# ---------------------------------------------------------------------------
orch_model_report() {
    echo "Model Router — Assignment Report"
    echo "  Default model: $_ORCH_MODEL_DEFAULT"
    echo ""

    # Print registered models
    echo "  Registered Models:"
    local name
    for name in "${_ORCH_MODEL_NAMES[@]}"; do
        local cli="${_ORCH_MODEL_CLI[$name]}"
        local args="${_ORCH_MODEL_ARGS[$name]:-}"
        local avail
        if orch_model_is_available "$name"; then
            avail="available"
        else
            avail="NOT FOUND"
        fi
        if [[ -n "$args" ]]; then
            printf '    %-10s → %s %s  (%s)\n' "$name" "$cli" "$args" "$avail"
        else
            printf '    %-10s → %s  (%s)\n' "$name" "$cli" "$avail"
        fi
    done
    echo ""

    # Print agent assignments
    echo "  Agent Assignments:"
    local agent_id
    for agent_id in $(echo "${!_ORCH_MODEL_AGENT[@]}" | tr ' ' '\n' | sort); do
        local model="${_ORCH_MODEL_AGENT[$agent_id]}"
        local full_cli
        full_cli="$(orch_model_get_cli "$agent_id")"
        printf '    %-16s → %-10s  (%s)\n' "$agent_id" "$model" "$full_cli"
    done

    # Summary counts per model
    echo ""
    echo "  Counts:"
    for name in "${_ORCH_MODEL_NAMES[@]}"; do
        local agents
        agents="$(orch_model_list_agents "$name")"
        local count=0
        if [[ -n "$agents" ]]; then
            count=$(echo "$agents" | wc -w)
        fi
        printf '    %-10s : %d agents\n' "$name" "$count"
    done
}

# ---------------------------------------------------------------------------
# Internal helper — trim leading/trailing whitespace
# ---------------------------------------------------------------------------
_orch_model_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}
