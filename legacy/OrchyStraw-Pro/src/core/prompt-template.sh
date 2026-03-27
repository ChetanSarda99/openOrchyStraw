#!/usr/bin/env bash
# =============================================================================
# prompt-template.sh — Prompt template inheritance for OrchyStraw (#38)
#
# Eliminates boilerplate repetition across agent prompts. Define shared
# sections (date, git rules, file ownership, etc.) once as template
# variables, then render prompts with {{VAR_NAME}} placeholders.
#
# Usage:
#   source src/core/prompt-template.sh
#
#   orch_template_init "/path/to/project"
#   orch_template_set_defaults
#   orch_template_set "AGENT_NAME" "06-Backend"
#   rendered=$(orch_template_render "prompts/06-backend/06-backend.txt")
#   orch_template_render_to_file "template.txt" "output.txt"
#   orch_template_estimate_savings "template.txt"
#
# Template syntax: {{VARIABLE_NAME}} — double curly braces, uppercase
# with underscores. Unrecognized placeholders are left as-is.
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_PROMPT_TEMPLATE_LOADED:-}" ]] && return 0
readonly _ORCH_PROMPT_TEMPLATE_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_TEMPLATE_VARS=()    # variable_name → value
declare -g  _ORCH_TEMPLATE_ROOT=""    # project root for resolving paths

# ---------------------------------------------------------------------------
# Standard boilerplate blocks (hardcoded to avoid file dependencies)
# ---------------------------------------------------------------------------
read -r -d '' _ORCH_GIT_RULES_BLOCK << 'GITEOF' || true
## Git Safety Rules
- NEVER run: `git checkout`, `git switch`, `git branch`, `git merge`, `git rebase`
- NEVER create or delete branches — the orchestrator handles all branch operations
- NEVER run `git push` — the orchestrator pushes after validating
- You may ONLY run: `git add`, `git commit`, `git status`, `git diff`, `git log`
- Always commit with descriptive messages referencing what changed
- If you need to see another branch's code, ask the PM — do not switch branches
GITEOF

read -r -d '' _ORCH_PROTECTED_FILES_BLOCK << 'PROTEOF' || true
## Protected Files — Do NOT Modify
- `CLAUDE.md` — project-wide config (PM only)
- `agents.conf` — agent roster and schedule (PM only)
- `scripts/auto-agent.sh` — orchestrator script (Backend only)
- `prompts/00-shared-context/context.md` — shared context (PM only)
- Other agents' prompt files — stay in your lane
PROTEOF

read -r -d '' _ORCH_AUTO_CYCLE_RULES_BLOCK << 'ACEOF' || true
## Auto-Cycle Mode
- You are running inside an automated orchestration cycle
- Complete your tasks efficiently — do not ask clarifying questions
- Write your status update to the shared context file when done
- If a task is blocked, note the blocker and move to the next task
- Do not wait for human input — make reasonable decisions and document them
- Keep commits atomic: one logical change per commit
ACEOF

# ---------------------------------------------------------------------------
# orch_template_init — initialize template system
#
# Sets up the template variable registry and project root.
#
# Args: $1 — project_root (optional, defaults to pwd)
# ---------------------------------------------------------------------------
orch_template_init() {
    _ORCH_TEMPLATE_ROOT="${1:-$(pwd)}"
    _ORCH_TEMPLATE_VARS=()
}

# ---------------------------------------------------------------------------
# orch_template_set — set a template variable
#
# Args:
#   $1 — variable_name (uppercase with underscores recommended)
#   $2 — value (can be multiline)
# ---------------------------------------------------------------------------
orch_template_set() {
    local var_name="$1"
    local var_value="$2"

    [[ -z "$var_name" ]] && return 1

    _ORCH_TEMPLATE_VARS["$var_name"]="$var_value"
}

# ---------------------------------------------------------------------------
# orch_template_get — get a template variable value
#
# Args: $1 — variable_name
# Returns: value to stdout, or empty string if not set
# ---------------------------------------------------------------------------
orch_template_get() {
    local var_name="$1"
    echo "${_ORCH_TEMPLATE_VARS[$var_name]:-}"
}

# ---------------------------------------------------------------------------
# orch_template_set_defaults — populate standard boilerplate variables
#
# Sets: DATE, GIT_RULES, PROTECTED_FILES, AUTO_CYCLE_RULES, PROJECT_OVERVIEW
# ---------------------------------------------------------------------------
orch_template_set_defaults() {
    # DATE — current date/time formatted
    _ORCH_TEMPLATE_VARS["DATE"]="$(date '+%B %d, %Y — %H:%M')"

    # GIT_RULES — standard git safety block
    _ORCH_TEMPLATE_VARS["GIT_RULES"]="$_ORCH_GIT_RULES_BLOCK"

    # PROTECTED_FILES — standard protected files list
    _ORCH_TEMPLATE_VARS["PROTECTED_FILES"]="$_ORCH_PROTECTED_FILES_BLOCK"

    # AUTO_CYCLE_RULES — standard auto-cycle mode instructions
    _ORCH_TEMPLATE_VARS["AUTO_CYCLE_RULES"]="$_ORCH_AUTO_CYCLE_RULES_BLOCK"

    # PROJECT_OVERVIEW — extract first paragraph from CLAUDE.md
    local claude_md="${_ORCH_TEMPLATE_ROOT}/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
        local overview=""
        local in_paragraph=false
        local line
        while IFS= read -r line; do
            # Skip heading lines and empty lines before first paragraph
            if [[ "$in_paragraph" == "false" ]]; then
                [[ "$line" =~ ^#  ]] && continue
                [[ -z "$line" ]] && continue
                in_paragraph=true
            fi
            # Stop at the next empty line or heading after we started
            if [[ "$in_paragraph" == "true" ]]; then
                [[ -z "$line" ]] && break
                [[ "$line" =~ ^#  ]] && break
                [[ -n "$overview" ]] && overview+=$'\n'
                overview+="$line"
            fi
        done < "$claude_md"
        _ORCH_TEMPLATE_VARS["PROJECT_OVERVIEW"]="$overview"
    else
        _ORCH_TEMPLATE_VARS["PROJECT_OVERVIEW"]="(CLAUDE.md not found)"
    fi
}

# ---------------------------------------------------------------------------
# orch_template_render — render a template file, replacing {{VAR}} placeholders
#
# Reads the template file, replaces all {{VAR_NAME}} placeholders with
# registered values. Unrecognized placeholders are left as-is.
#
# Args: $1 — template_file_path
# Output: rendered content to stdout
# ---------------------------------------------------------------------------
orch_template_render() {
    local template_file="$1"

    [[ ! -f "$template_file" ]] && {
        echo "orch_template_render: file not found: $template_file" >&2
        return 1
    }

    local content
    content=$(<"$template_file")

    # Replace each registered variable
    local var_name var_value
    for var_name in "${!_ORCH_TEMPLATE_VARS[@]}"; do
        var_value="${_ORCH_TEMPLATE_VARS[$var_name]}"

        # Use a temp file for sed to handle multiline values safely
        # Escape sed special characters in the value
        local escaped_value
        escaped_value=$(printf '%s' "$var_value" | sed -e 's/[&/\]/\\&/g' -e 's/$/\\/' | sed '$ s/\\$//')

        # Replace {{VAR_NAME}} with the value
        # Using a delimiter unlikely to appear in content
        content=$(printf '%s' "$content" | awk -v var="{{${var_name}}}" -v val="$var_value" '
        {
            idx = index($0, var)
            if (idx > 0) {
                prefix = substr($0, 1, idx - 1)
                suffix = substr($0, idx + length(var))
                # Print prefix, then value (which may be multiline), then suffix
                n = split(val, lines, "\n")
                if (n == 0) {
                    printf "%s%s\n", prefix, suffix
                } else if (n == 1) {
                    printf "%s%s%s\n", prefix, val, suffix
                } else {
                    printf "%s%s\n", prefix, lines[1]
                    for (i = 2; i < n; i++) {
                        printf "%s\n", lines[i]
                    }
                    printf "%s%s\n", lines[n], suffix
                }
            } else {
                print $0
            }
        }')
    done

    printf '%s\n' "$content"
}

# ---------------------------------------------------------------------------
# orch_template_render_to_file — render and write to output file
#
# Args:
#   $1 — template_file path
#   $2 — output_file path
# Returns: 0 on success, 1 on failure
# ---------------------------------------------------------------------------
orch_template_render_to_file() {
    local template_file="$1"
    local output_file="$2"

    [[ -z "$template_file" ]] || [[ -z "$output_file" ]] && {
        echo "orch_template_render_to_file: requires template and output paths" >&2
        return 1
    }

    local rendered
    rendered=$(orch_template_render "$template_file") || return 1

    # Ensure output directory exists
    local output_dir
    output_dir=$(dirname "$output_file")
    [[ ! -d "$output_dir" ]] && mkdir -p "$output_dir"

    printf '%s\n' "$rendered" > "$output_file"
}

# ---------------------------------------------------------------------------
# orch_template_list_vars — list all registered variable names
#
# Output: one variable name per line, sorted
# ---------------------------------------------------------------------------
orch_template_list_vars() {
    local var_name
    for var_name in "${!_ORCH_TEMPLATE_VARS[@]}"; do
        echo "$var_name"
    done | sort
}

# ---------------------------------------------------------------------------
# orch_template_estimate_savings — compare template vs expanded size
#
# Estimates token savings from using templates vs duplicating boilerplate.
# Uses chars/4 approximation for token count.
#
# Args: $1 — template_file path
# Output: "template_tokens expanded_tokens savings_pct"
# ---------------------------------------------------------------------------
orch_template_estimate_savings() {
    local template_file="$1"

    [[ ! -f "$template_file" ]] && {
        echo "0 0 0"
        return 1
    }

    # Template size (the file with {{VAR}} placeholders)
    local template_chars
    template_chars=$(wc -c < "$template_file" 2>/dev/null || echo 0)
    local template_tokens=$(( template_chars / 4 ))

    # Rendered (expanded) size
    local rendered
    rendered=$(orch_template_render "$template_file") || {
        echo "$template_tokens $template_tokens 0"
        return 1
    }

    local expanded_chars
    expanded_chars=$(printf '%s' "$rendered" | wc -c 2>/dev/null || echo 0)
    local expanded_tokens=$(( expanded_chars / 4 ))

    # Savings: the template file is what you store, expanded is what you'd
    # have to store without templates. Savings = expanded - template.
    local savings_pct=0
    if [[ $expanded_tokens -gt 0 ]]; then
        savings_pct=$(( (expanded_tokens - template_tokens) * 100 / expanded_tokens ))
    fi

    # Clamp negative savings to 0 (template could be larger if no vars used)
    [[ $savings_pct -lt 0 ]] && savings_pct=0

    echo "$template_tokens $expanded_tokens $savings_pct"
}
