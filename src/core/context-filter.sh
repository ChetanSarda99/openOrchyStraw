#!/usr/bin/env bash
# =============================================================================
# context-filter.sh — Differential context filtering for OrchyStraw (#33)
#
# Filters the shared context file (context.md) per agent, delivering only
# the sections each agent needs. Reduces token waste by skipping irrelevant
# sections (e.g., iOS agent doesn't need Design Status).
#
# Usage:
#   source src/core/context-filter.sh
#
#   orch_context_filter_init
#   orch_context_for_agent "06-backend" "prompts/00-shared-context/context.md"
#   orch_context_estimate_savings "06-backend" "prompts/00-shared-context/context.md"
#   orch_context_write_filtered "06-backend" "context.md" "/tmp/ctx-backend.md"
#
# Section detection: lines matching ^## start a new section.
# Section ends at the next ^## or EOF.
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_CONTEXT_FILTER_LOADED:-}" ]] && return 0
readonly _ORCH_CONTEXT_FILTER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_CTX_MAP=()  # agent_id → comma-separated section names

# ---------------------------------------------------------------------------
# orch_context_filter_init — set up default relevance mappings
#
# Populates _ORCH_CTX_MAP with which sections each agent needs.
# Value "ALL" means the agent receives every section.
# Blockers and Notes are always included as a safety net regardless
# of mapping (enforced in orch_context_for_agent).
# ---------------------------------------------------------------------------
orch_context_filter_init() {
    _ORCH_CTX_MAP=()

    # Full-picture agents
    _ORCH_CTX_MAP["01-ceo"]="ALL"
    _ORCH_CTX_MAP["02-cto"]="ALL"
    _ORCH_CTX_MAP["03-pm"]="ALL"
    _ORCH_CTX_MAP["09-qa"]="ALL"
    _ORCH_CTX_MAP["10-security"]="ALL"

    # Scoped agents
    _ORCH_CTX_MAP["04-tauri-rust"]="Usage,Progress,Backend Status,Design Status,Blockers,Notes"
    _ORCH_CTX_MAP["05-tauri-ui"]="Usage,Progress,Design Status,Backend Status,Blockers,Notes"
    _ORCH_CTX_MAP["06-backend"]="Usage,Progress,Backend Status,Blockers,Notes"
    _ORCH_CTX_MAP["07-ios"]="Usage,Progress,iOS Status,Blockers,Notes"
    _ORCH_CTX_MAP["08-pixel"]="Usage,Progress,Design Status,Blockers,Notes"
    _ORCH_CTX_MAP["11-web"]="Usage,Progress,Design Status,Blockers,Notes"
}

# ---------------------------------------------------------------------------
# orch_context_add_mapping — add or override a relevance mapping
#
# Args:
#   $1 — agent_id (e.g., "06-backend")
#   $2 — comma-separated section names, or "ALL"
# ---------------------------------------------------------------------------
orch_context_add_mapping() {
    local agent_id="$1"
    local sections="$2"

    [[ -z "$agent_id" ]] && return 1
    [[ -z "$sections" ]] && return 1

    _ORCH_CTX_MAP["$agent_id"]="$sections"
}

# ---------------------------------------------------------------------------
# _orch_section_in_list — check if a section name is in a comma-separated list
#
# Internal helper. Matches by prefix so "Progress" matches
# "## Progress (last cycle → this cycle)".
#
# Args:
#   $1 — section name (from ## heading, without the ## prefix)
#   $2 — comma-separated allowed sections
#
# Returns 0 if found, 1 if not.
# ---------------------------------------------------------------------------
_orch_section_in_list() {
    local section_name="$1"
    local allowed_csv="$2"

    # Split CSV into array
    local IFS=','
    local -a allowed=()
    read -ra allowed <<< "$allowed_csv"

    local entry
    for entry in "${allowed[@]}"; do
        # Trim leading/trailing whitespace
        entry="${entry#"${entry%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"

        # Check if section name starts with the allowed entry
        if [[ "$section_name" == "$entry"* ]]; then
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# orch_context_for_agent — filter context.md for a specific agent
#
# Reads the context file and outputs only the sections relevant to
# the given agent. The file header (everything before first ##) is
# always included. Blockers and Notes sections are always included
# as a safety net even if not in the mapping.
#
# Args:
#   $1 — agent_id (e.g., "06-backend")
#   $2 — path to context.md
#
# Outputs: filtered content to stdout
# Returns: 0 on success, 1 on error
# ---------------------------------------------------------------------------
orch_context_for_agent() {
    local agent_id="$1"
    local context_file="$2"

    [[ -z "$agent_id" ]] && return 1
    [[ ! -f "$context_file" ]] && return 1

    # Look up mapping; unknown agents get ALL
    local mapping="${_ORCH_CTX_MAP[$agent_id]:-ALL}"

    local in_header=true
    local in_section=false
    local section_included=false
    local current_section=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Detect section start
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            current_section="${BASH_REMATCH[1]}"
            in_header=false
            in_section=true

            # Determine if this section should be included
            if [[ "$mapping" == "ALL" ]]; then
                section_included=true
            else
                # Always include Blockers and Notes as safety net
                if [[ "$current_section" == Blockers* ]] || \
                   [[ "$current_section" == Notes* ]]; then
                    section_included=true
                elif _orch_section_in_list "$current_section" "$mapping"; then
                    section_included=true
                else
                    section_included=false
                fi
            fi

            if [[ "$section_included" == "true" ]]; then
                echo "$line"
            fi
            continue
        fi

        # Header lines (before any ## section)
        if [[ "$in_header" == "true" ]]; then
            echo "$line"
            continue
        fi

        # Section body lines
        if [[ "$in_section" == "true" ]] && [[ "$section_included" == "true" ]]; then
            echo "$line"
        fi
    done < "$context_file"
}

# ---------------------------------------------------------------------------
# orch_context_estimate_savings — estimate token savings from filtering
#
# Compares full file token count vs filtered output for a given agent.
# Uses chars/4 as the rough token approximation (same as session-windower).
#
# Args:
#   $1 — agent_id
#   $2 — path to context.md
#
# Outputs: "full_tokens filtered_tokens savings_pct" (space-separated)
# Returns: 0 on success, 1 on error
# ---------------------------------------------------------------------------
orch_context_estimate_savings() {
    local agent_id="$1"
    local context_file="$2"

    [[ -z "$agent_id" ]] && return 1
    [[ ! -f "$context_file" ]] && return 1

    local full_chars
    full_chars=$(wc -c < "$context_file" 2>/dev/null || echo 0)
    local full_tokens=$(( full_chars / 4 ))

    local filtered_output
    filtered_output=$(orch_context_for_agent "$agent_id" "$context_file")
    local filtered_chars=${#filtered_output}
    local filtered_tokens=$(( filtered_chars / 4 ))

    local savings_pct=0
    if [[ $full_tokens -gt 0 ]]; then
        savings_pct=$(( (full_tokens - filtered_tokens) * 100 / full_tokens ))
    fi

    echo "$full_tokens $filtered_tokens $savings_pct"
}

# ---------------------------------------------------------------------------
# orch_context_write_filtered — write filtered context to a file
#
# Convenience wrapper: filters context for an agent and writes the
# result to the specified output path.
#
# Args:
#   $1 — agent_id
#   $2 — path to context.md (input)
#   $3 — output file path
#
# Returns: 0 on success, 1 on error
# ---------------------------------------------------------------------------
orch_context_write_filtered() {
    local agent_id="$1"
    local context_file="$2"
    local output_path="$3"

    [[ -z "$agent_id" ]] && return 1
    [[ ! -f "$context_file" ]] && return 1
    [[ -z "$output_path" ]] && return 1

    # Ensure output directory exists
    local output_dir
    output_dir=$(dirname "$output_path")
    [[ ! -d "$output_dir" ]] && mkdir -p "$output_dir"

    orch_context_for_agent "$agent_id" "$context_file" > "$output_path"
}
