#!/usr/bin/env bash
# =============================================================================
# onboarding.sh — Conversation-based project setup / onboarding module
#
# Analyzes a project directory and generates initial agents.conf + prompt
# files. Lowers the barrier to entry for new OrchyStraw users.
#
# Usage:
#   source src/core/onboarding.sh
#
#   orch_onboard_init
#   orch_onboard_detect_project "/path/to/project"
#   orch_onboard_suggest_agents "javascript"
#   orch_onboard_generate_conf  "/path/to/project" "backend frontend qa pm"
#   orch_onboard_generate_prompts "/path/to/output" "backend frontend qa pm"
#   orch_onboard_run "/path/to/project" "/path/to/output"
#
# Requires: bash 4.2+ (declare -g)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_ONBOARD_LOADED:-}" ]] && return 0
_ORCH_ONBOARD_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g  _ORCH_ONBOARD_PROJECT_DIR=""
declare -g  _ORCH_ONBOARD_PROJECT_TYPE=""
declare -g  _ORCH_ONBOARD_AGENTS=""
declare -g  _ORCH_ONBOARD_INITIALIZED=0

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_onboard_log <message>
#   Print an informational message to stderr.
_orch_onboard_log() {
    printf '[onboarding] %s\n' "$1" >&2
}

# _orch_onboard_role_for <agent_name>
#   Map an agent short-name to a human-readable role string.
_orch_onboard_role_for() {
    local name="$1"
    case "$name" in
        backend)      echo "Backend Developer" ;;
        frontend)     echo "Frontend Developer" ;;
        qa)           echo "QA Engineer" ;;
        pm)           echo "Project Manager" ;;
        data-science) echo "Data Science Engineer" ;;
        systems)      echo "Systems Engineer" ;;
        api)          echo "API Developer" ;;
        devops)       echo "DevOps Engineer" ;;
        *)            echo "Developer" ;;
    esac
}

# _orch_onboard_owns_for <agent_name>
#   Return default file-ownership patterns for a given agent.
_orch_onboard_owns_for() {
    local name="$1"
    case "$name" in
        backend)      echo "src/ scripts/ lib/" ;;
        frontend)     echo "src/components/ src/styles/ public/" ;;
        qa)           echo "tests/ reports/" ;;
        pm)           echo "prompts/ docs/" ;;
        data-science) echo "notebooks/ data/ models/" ;;
        systems)      echo "src/ benches/" ;;
        api)          echo "api/ cmd/ internal/" ;;
        devops)       echo "ci/ infra/ deploy/" ;;
        *)            echo "src/" ;;
    esac
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# orch_onboard_init
#   Initialize (or reset) onboarding state.
orch_onboard_init() {
    _ORCH_ONBOARD_PROJECT_DIR=""
    _ORCH_ONBOARD_PROJECT_TYPE=""
    _ORCH_ONBOARD_AGENTS=""
    _ORCH_ONBOARD_INITIALIZED=1
    _orch_onboard_log "Onboarding state initialized"
}

# orch_onboard_detect_project <project_dir>
#   Detect the project type(s) from marker files in the given directory.
#   Sets _ORCH_ONBOARD_PROJECT_TYPE and prints the detected type.
#   Possible outputs: javascript, python, rust, go, java, multi, unknown
orch_onboard_detect_project() {
    local project_dir="${1:?Usage: orch_onboard_detect_project <project_dir>}"

    if [[ ! -d "$project_dir" ]]; then
        _orch_onboard_log "ERROR: directory does not exist: $project_dir"
        return 1
    fi

    # Validate: reject path traversal attempts
    case "$project_dir" in
        *..*)
            _orch_onboard_log "ERROR: path traversal detected: $project_dir"
            return 1
            ;;
    esac

    _ORCH_ONBOARD_PROJECT_DIR="$project_dir"

    local -a detected=()

    # JavaScript / TypeScript
    if [[ -f "$project_dir/package.json" ]]; then
        detected+=("javascript")
    fi

    # Python
    if [[ -f "$project_dir/setup.py" ]] \
        || [[ -f "$project_dir/pyproject.toml" ]] \
        || [[ -f "$project_dir/requirements.txt" ]]; then
        detected+=("python")
    fi

    # Rust
    if [[ -f "$project_dir/Cargo.toml" ]]; then
        detected+=("rust")
    fi

    # Go
    if [[ -f "$project_dir/go.mod" ]]; then
        detected+=("go")
    fi

    # Java
    if [[ -f "$project_dir/pom.xml" ]] || [[ -f "$project_dir/build.gradle" ]]; then
        detected+=("java")
    fi

    local count=${#detected[@]}

    if (( count == 0 )); then
        _ORCH_ONBOARD_PROJECT_TYPE="unknown"
    elif (( count == 1 )); then
        _ORCH_ONBOARD_PROJECT_TYPE="${detected[0]}"
    else
        _ORCH_ONBOARD_PROJECT_TYPE="multi"
    fi

    _orch_onboard_log "Detected project type: $_ORCH_ONBOARD_PROJECT_TYPE"
    printf '%s' "$_ORCH_ONBOARD_PROJECT_TYPE"
}

# orch_onboard_suggest_agents <project_type>
#   Suggest an agent team for the given project type.
#   Sets _ORCH_ONBOARD_AGENTS and prints a space-separated list.
orch_onboard_suggest_agents() {
    local project_type="${1:?Usage: orch_onboard_suggest_agents <project_type>}"

    local agents=""
    case "$project_type" in
        javascript)  agents="backend frontend qa pm" ;;
        python)      agents="backend qa data-science pm" ;;
        rust)        agents="backend systems qa pm" ;;
        go)          agents="backend api qa pm" ;;
        java)        agents="backend qa devops pm" ;;
        multi)
            # Multi-language: union of common agents + frontend
            agents="backend frontend qa devops pm"
            ;;
        *)
            # Unknown / generic
            agents="backend qa pm"
            ;;
    esac

    _ORCH_ONBOARD_AGENTS="$agents"
    _orch_onboard_log "Suggested agents: $agents"
    printf '%s' "$agents"
}

# orch_onboard_generate_conf <project_dir> <agents_list>
#   Generate agents.conf content and print it to stdout.
#   agents_list is a space-separated string of agent names.
orch_onboard_generate_conf() {
    local project_dir="${1:?Usage: orch_onboard_generate_conf <project_dir> <agents_list>}"
    local agents_list="${2:?Usage: orch_onboard_generate_conf <project_dir> <agents_list>}"

    local project_type="${_ORCH_ONBOARD_PROJECT_TYPE:-unknown}"

    local conf=""
    conf+="# OrchyStraw Agent Configuration"$'\n'
    conf+="# Generated by onboarding module"$'\n'
    conf+="# Project type: ${project_type}"$'\n'
    conf+=""$'\n'

    local idx=1
    local name
    for name in $agents_list; do
        local role
        role="$(_orch_onboard_role_for "$name")"
        local owns
        owns="$(_orch_onboard_owns_for "$name")"
        local padded_idx
        padded_idx=$(printf '%02d' "$idx")

        conf+="[agent:${padded_idx}-${name}]"$'\n'
        conf+="role = ${role}"$'\n'
        conf+="frequency = every_cycle"$'\n'
        conf+="prompt = prompts/${padded_idx}-${name}/${padded_idx}-${name}.txt"$'\n'
        conf+="owns = ${owns}"$'\n'
        conf+=""$'\n'

        idx=$(( idx + 1 ))
    done

    printf '%s' "$conf"
}

# orch_onboard_generate_prompts <output_dir> <agents_list>
#   Generate minimal prompt files under output_dir for each agent.
#   Creates output_dir/<NN>-<name>/<NN>-<name>.txt for each agent.
orch_onboard_generate_prompts() {
    local output_dir="${1:?Usage: orch_onboard_generate_prompts <output_dir> <agents_list>}"
    local agents_list="${2:?Usage: orch_onboard_generate_prompts <output_dir> <agents_list>}"

    local project_type="${_ORCH_ONBOARD_PROJECT_TYPE:-unknown}"

    local idx=1
    local name
    for name in $agents_list; do
        local role
        role="$(_orch_onboard_role_for "$name")"
        local padded_idx
        padded_idx=$(printf '%02d' "$idx")
        local agent_dir="${output_dir}/${padded_idx}-${name}"
        local prompt_file="${agent_dir}/${padded_idx}-${name}.txt"

        mkdir -p "$agent_dir"

        cat > "$prompt_file" <<PROMPT
# Agent: ${padded_idx}-${name}
# Role: ${role}
# Project type: ${project_type}

## Responsibilities
You are the ${role} for this project.
Review the shared context and complete your assigned tasks each cycle.

## Current Tasks
- [ ] Review project structure
- [ ] Identify areas of improvement in your domain

## File Ownership
$(printf '%s' "$(_orch_onboard_owns_for "$name")")

## Notes
Generated by OrchyStraw onboarding module.
PROMPT

        _orch_onboard_log "Created prompt: $prompt_file"
        idx=$(( idx + 1 ))
    done
}

# orch_onboard_run <project_dir> <output_dir>
#   Full onboarding pipeline: init → detect → suggest → generate conf + prompts.
#   Writes agents.conf into output_dir and prompt dirs under output_dir/prompts/.
orch_onboard_run() {
    local project_dir="${1:?Usage: orch_onboard_run <project_dir> <output_dir>}"
    local output_dir="${2:?Usage: orch_onboard_run <project_dir> <output_dir>}"

    orch_onboard_init

    local project_type
    project_type="$(orch_onboard_detect_project "$project_dir")"
    # Persist type in parent shell (subshell doesn't propagate)
    _ORCH_ONBOARD_PROJECT_TYPE="$project_type"

    local agents
    agents="$(orch_onboard_suggest_agents "$project_type")"
    _ORCH_ONBOARD_AGENTS="$agents"

    # Write agents.conf
    mkdir -p "$output_dir"
    orch_onboard_generate_conf "$project_dir" "$agents" > "${output_dir}/agents.conf"
    _orch_onboard_log "Wrote ${output_dir}/agents.conf"

    # Write prompt files
    orch_onboard_generate_prompts "${output_dir}/prompts" "$agents"
    _orch_onboard_log "Onboarding complete for project type: $project_type"

    printf '%s' "$project_type"
}
