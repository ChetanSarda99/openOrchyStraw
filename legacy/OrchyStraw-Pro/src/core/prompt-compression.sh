#!/usr/bin/env bash
# =============================================================================
# prompt-compression.sh — Tiered prompt loading (#31)
#
# Reduces token usage by loading agent prompts in tiers. Not every agent
# invocation needs the full prompt — repeated agents can skip boilerplate
# (project overview, tech stack) and load only tasks + rules.
#
# Tiers:
#   full    — Complete prompt as-is (first run, or after config change)
#   standard — Skip static sections (What is OrchyStraw?, Tech Stack)
#   minimal  — Tasks + rules + protected files only
#
# Sections are detected by ## headings. Each heading is classified into a
# tier based on a configurable mapping.
#
# Usage:
#   source src/core/prompt-compression.sh
#
#   orch_compress_init
#   orch_compress_prompt "full" "/path/to/prompt.txt"
#   orch_compress_prompt "standard" "/path/to/prompt.txt"
#   orch_compress_prompt "minimal" "/path/to/prompt.txt"
#   orch_compress_tier_for_agent "06-backend" 5   # cycle 5 → standard
#   orch_compress_estimate_savings "standard" "/path/to/prompt.txt"
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_PROMPT_COMPRESSION_LOADED:-}" ]] && return 0
readonly _ORCH_PROMPT_COMPRESSION_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# Section → tier mapping. Sections at a given tier are included for that
# tier and all higher tiers. "full" includes everything.
# Tier hierarchy: minimal ⊂ standard ⊂ full
declare -gA _ORCH_COMPRESS_SECTION_TIER=()

# Agent → last loaded tier (for tracking)
declare -gA _ORCH_COMPRESS_AGENT_TIER=()

# Agent → consecutive runs (to auto-select tier)
declare -gA _ORCH_COMPRESS_RUN_COUNT=()

# ---------------------------------------------------------------------------
# orch_compress_init — set default section-tier mappings
#
# These map ## heading prefixes to tiers. A section is included if its
# tier level is <= the requested tier.
#
# Tier levels: minimal=1, standard=2, full=3
# ---------------------------------------------------------------------------
orch_compress_init() {
    _ORCH_COMPRESS_SECTION_TIER=()
    _ORCH_COMPRESS_AGENT_TIER=()

    # --- Minimal tier (always loaded) ---
    _ORCH_COMPRESS_SECTION_TIER["PROTECTED FILES"]=1
    _ORCH_COMPRESS_SECTION_TIER["File Ownership"]=1
    _ORCH_COMPRESS_SECTION_TIER["Current Tasks"]=1
    _ORCH_COMPRESS_SECTION_TIER["Your Tasks"]=1
    _ORCH_COMPRESS_SECTION_TIER["Rules"]=1
    _ORCH_COMPRESS_SECTION_TIER["Git Safety"]=1
    _ORCH_COMPRESS_SECTION_TIER["AFTER YOU FINISH"]=1
    _ORCH_COMPRESS_SECTION_TIER["Auto-Cycle Mode"]=1

    # --- Standard tier (loaded on normal runs) ---
    _ORCH_COMPRESS_SECTION_TIER["What's DONE"]=2
    _ORCH_COMPRESS_SECTION_TIER["Research-First Protocol"]=2
    _ORCH_COMPRESS_SECTION_TIER["Integration"]=2

    # --- Full tier (loaded on first run or config change) ---
    _ORCH_COMPRESS_SECTION_TIER["What is OrchyStraw"]=3
    _ORCH_COMPRESS_SECTION_TIER["Tech Stack"]=3
    _ORCH_COMPRESS_SECTION_TIER["Project Overview"]=3
    _ORCH_COMPRESS_SECTION_TIER["Agent Team"]=3
    _ORCH_COMPRESS_SECTION_TIER["Stack Reference"]=3
}

# ---------------------------------------------------------------------------
# orch_compress_add_section — add or override a section-tier mapping
#
# Args:
#   $1 — section heading prefix (matched against ## headings)
#   $2 — tier level: 1=minimal, 2=standard, 3=full
# ---------------------------------------------------------------------------
orch_compress_add_section() {
    local section="$1"
    local tier="${2:-3}"
    [[ -z "$section" ]] && return 1
    _ORCH_COMPRESS_SECTION_TIER["$section"]=$tier
}

# ---------------------------------------------------------------------------
# _orch_compress_tier_level — convert tier name to level number
# ---------------------------------------------------------------------------
_orch_compress_tier_level() {
    case "${1:-full}" in
        minimal)  echo 1 ;;
        standard) echo 2 ;;
        full)     echo 3 ;;
        *)        echo 3 ;;
    esac
}

# ---------------------------------------------------------------------------
# _orch_compress_section_level — get tier level for a section heading
#
# Matches heading text against known prefixes. Unknown sections default
# to standard tier (level 2) so they're included in standard + full.
#
# Args: $1 — section heading text (without ## prefix)
# Returns: tier level (1, 2, or 3)
# ---------------------------------------------------------------------------
_orch_compress_section_level() {
    local heading="$1"

    local key
    for key in "${!_ORCH_COMPRESS_SECTION_TIER[@]}"; do
        if [[ "$heading" == "$key"* ]]; then
            echo "${_ORCH_COMPRESS_SECTION_TIER[$key]}"
            return
        fi
    done

    # Default: standard tier (included in standard + full, not minimal)
    echo 2
}

# ---------------------------------------------------------------------------
# orch_compress_prompt — compress a prompt file to the requested tier
#
# Reads the prompt file and outputs only sections at or below the
# requested tier level. The file header (everything before the first ##)
# is always included (it contains role info and date).
#
# Special: lines containing "---" (section dividers) are included only
# if the surrounding sections are included.
#
# Args:
#   $1 — tier: "full", "standard", or "minimal"
#   $2 — path to prompt file
#
# Outputs: compressed prompt to stdout
# Returns: 0 on success, 1 on error
# ---------------------------------------------------------------------------
orch_compress_prompt() {
    local tier="${1:-full}"
    local prompt_file="$2"

    [[ -z "$prompt_file" ]] && return 1
    [[ ! -f "$prompt_file" ]] && return 1

    local tier_level
    tier_level=$(_orch_compress_tier_level "$tier")

    # Full tier = no compression
    if [[ "$tier_level" -eq 3 ]]; then
        cat "$prompt_file"
        return 0
    fi

    local in_header=true
    local section_included=false
    local current_heading=""
    local pending_divider=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Detect ## section headings
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            current_heading="${BASH_REMATCH[1]}"
            in_header=false

            local section_level
            section_level=$(_orch_compress_section_level "$current_heading")

            if [[ $section_level -le $tier_level ]]; then
                section_included=true
                # Flush pending divider if we have one
                if [[ -n "$pending_divider" ]]; then
                    echo "$pending_divider"
                    pending_divider=""
                fi
                echo "$line"
            else
                section_included=false
                pending_divider=""
            fi
            continue
        fi

        # # top-level headings (role header) — always include
        if [[ "$line" =~ ^#[[:space:]]+ ]] && [[ ! "$line" =~ ^## ]]; then
            echo "$line"
            continue
        fi

        # Header (before any ##) — always include
        if [[ "$in_header" == "true" ]]; then
            echo "$line"
            continue
        fi

        # Section dividers — buffer them; only output if next section is included
        if [[ "$line" == "---" ]]; then
            if [[ "$section_included" == "true" ]]; then
                pending_divider="$line"
            fi
            continue
        fi

        # Body lines — include if section is included
        if [[ "$section_included" == "true" ]]; then
            echo "$line"
        fi
    done < "$prompt_file"
}

# ---------------------------------------------------------------------------
# orch_compress_tier_for_agent — auto-select tier based on agent run count
#
# Logic:
#   - First run (count=0 or 1) → full
#   - Runs 2-4 → standard
#   - Runs 5+ → minimal
#   - If force_full=true → full regardless
#
# Args:
#   $1 — agent_id
#   $2 — run count (or uses internal tracker if omitted)
#   $3 — "force_full" to force full tier (optional)
#
# Outputs: tier name ("full", "standard", "minimal")
# ---------------------------------------------------------------------------
orch_compress_tier_for_agent() {
    local agent_id="$1"
    local run_count="${2:-${_ORCH_COMPRESS_RUN_COUNT[$agent_id]:-0}}"
    local force="${3:-}"

    [[ "$force" == "force_full" ]] && echo "full" && return

    if [[ $run_count -le 1 ]]; then
        echo "full"
    elif [[ $run_count -le 4 ]]; then
        echo "standard"
    else
        echo "minimal"
    fi
}

# ---------------------------------------------------------------------------
# orch_compress_record_run — increment run count for an agent
#
# Args: $1 — agent_id
# ---------------------------------------------------------------------------
orch_compress_record_run() {
    local agent_id="$1"
    [[ -z "$agent_id" ]] && return 1
    local current="${_ORCH_COMPRESS_RUN_COUNT[$agent_id]:-0}"
    _ORCH_COMPRESS_RUN_COUNT["$agent_id"]=$(( current + 1 ))
}

# ---------------------------------------------------------------------------
# orch_compress_reset_run_count — reset run count (e.g., after config change)
#
# Args: $1 — agent_id (or "all" to reset all)
# ---------------------------------------------------------------------------
orch_compress_reset_run_count() {
    local agent_id="$1"
    if [[ "$agent_id" == "all" ]]; then
        _ORCH_COMPRESS_RUN_COUNT=()
    else
        _ORCH_COMPRESS_RUN_COUNT["$agent_id"]=0
    fi
}

# ---------------------------------------------------------------------------
# orch_compress_estimate_savings — estimate token savings for a tier
#
# Compares full prompt size vs compressed output.
# Uses chars/4 as rough token approximation.
#
# Args:
#   $1 — tier: "standard" or "minimal"
#   $2 — path to prompt file
#
# Outputs: "full_tokens compressed_tokens savings_pct" (space-separated)
# Returns: 0 on success, 1 on error
# ---------------------------------------------------------------------------
orch_compress_estimate_savings() {
    local tier="$1"
    local prompt_file="$2"

    [[ -z "$tier" ]] && return 1
    [[ ! -f "$prompt_file" ]] && return 1

    local full_chars
    full_chars=$(wc -c < "$prompt_file" 2>/dev/null || echo 0)
    local full_tokens=$(( full_chars / 4 ))

    local compressed_output
    compressed_output=$(orch_compress_prompt "$tier" "$prompt_file")
    local compressed_chars=${#compressed_output}
    local compressed_tokens=$(( compressed_chars / 4 ))

    local savings_pct=0
    if [[ $full_tokens -gt 0 ]]; then
        savings_pct=$(( (full_tokens - compressed_tokens) * 100 / full_tokens ))
    fi

    echo "$full_tokens $compressed_tokens $savings_pct"
}

# ---------------------------------------------------------------------------
# orch_compress_report — print compression summary for all tracked agents
# ---------------------------------------------------------------------------
orch_compress_report() {
    echo "Prompt Compression Report"
    echo ""

    local agent_id
    for agent_id in $(echo "${!_ORCH_COMPRESS_RUN_COUNT[@]}" | tr ' ' '\n' | sort); do
        local runs="${_ORCH_COMPRESS_RUN_COUNT[$agent_id]}"
        local tier
        tier=$(orch_compress_tier_for_agent "$agent_id" "$runs")
        local last_tier="${_ORCH_COMPRESS_AGENT_TIER[$agent_id]:-none}"
        echo "  $agent_id: runs=$runs tier=$tier (last=$last_tier)"
    done
}
