#!/usr/bin/env bash
# prompt-compression.sh — Tiered prompt loading for token savings
# v0.2.0: #47 — classify prompt sections, compress stable content on repeat runs
#
# Agent prompts contain sections that rarely change (tech stack, ownership, rules)
# and sections that change every cycle (tasks, status, done list). By classifying
# sections into tiers, the orchestrator can skip or summarize stable content on
# repeat runs, saving 30-50% of prompt tokens.
#
# Tiers:
#   stable    — Tech stack, file ownership, rules, identity (rarely changes)
#   dynamic   — Current tasks, what's done, status, shared context (changes every cycle)
#   reference — Research protocol, auto-cycle instructions, git safety (load on first run)
#
# Modes:
#   full      — All sections, all tiers (first run or when stable sections change)
#   standard  — Stable sections condensed to 1-line summaries, dynamic+reference in full
#   minimal   — Dynamic sections only (emergency token budget)
#
# Provides:
#   orch_prompt_init             — configure known section patterns
#   orch_prompt_classify         — parse prompt file, classify sections by tier
#   orch_prompt_compress         — return compressed prompt for given mode
#   orch_prompt_estimate_tokens  — rough token count (~4 chars per token)
#   orch_prompt_stable_hash      — hash stable sections for change detection
#   orch_prompt_load_hashes      — load previous stable hashes from state file
#   orch_prompt_save_hashes      — persist stable hashes to state file
#   orch_prompt_mode_for_agent   — decide mode based on hash comparison + budget

[[ -n "${_ORCH_PROMPT_COMPRESSION_LOADED:-}" ]] && return 0
_ORCH_PROMPT_COMPRESSION_LOADED=1

# ── State ──
declare -g -A _ORCH_PROMPT_TIER=()         # "agent:section_header" -> stable|dynamic|reference
declare -g -A _ORCH_PROMPT_SECTIONS=()     # "agent:N" -> section content (indexed by order)
declare -g -A _ORCH_PROMPT_SEC_HEADERS=()  # "agent:N" -> section header text
declare -g -A _ORCH_PROMPT_SEC_TIER=()     # "agent:N" -> tier for this section
declare -g -A _ORCH_PROMPT_SEC_COUNT=()    # agent -> number of sections parsed
declare -g -A _ORCH_PROMPT_STABLE_HASH=()  # agent -> hash of all stable sections combined
declare -g -A _ORCH_PROMPT_PREV_HASH=()    # agent -> previous run's stable hash
declare -g _ORCH_PROMPT_TOKEN_BUDGET=0     # max tokens per agent (0 = unlimited)

# Known header patterns → tier classification
# These match common OrchyStraw prompt section headers
declare -g -a _ORCH_PROMPT_STABLE_PATTERNS=(
    "What is OrchyStraw"
    "Tech Stack"
    "File Ownership"
    "PROTECTED FILES"
    "Rules"
    "Stack Reference"
    "Your Role"
)
declare -g -a _ORCH_PROMPT_DYNAMIC_PATTERNS=(
    "Current Tasks"
    "Your Tasks"
    "What's DONE"
    "What.*DONE"
    "Status"
    "SHARED CONTEXT"
    "CROSS-CYCLE HISTORY"
)
declare -g -a _ORCH_PROMPT_REFERENCE_PATTERNS=(
    "Research-First Protocol"
    "Auto-Cycle Mode"
    "Git Safety"
    "AFTER YOU FINISH"
)

# ── Helpers ──

_orch_prompt_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "prompt-compress" "$2"
    fi
}

_orch_prompt_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Classify a section header into a tier by matching against known patterns
_orch_prompt_classify_header() {
    local header="$1"

    for pattern in "${_ORCH_PROMPT_STABLE_PATTERNS[@]}"; do
        if [[ "$header" =~ $pattern ]]; then
            printf 'stable'
            return 0
        fi
    done

    for pattern in "${_ORCH_PROMPT_DYNAMIC_PATTERNS[@]}"; do
        if [[ "$header" =~ $pattern ]]; then
            printf 'dynamic'
            return 0
        fi
    done

    for pattern in "${_ORCH_PROMPT_REFERENCE_PATTERNS[@]}"; do
        if [[ "$header" =~ $pattern ]]; then
            printf 'reference'
            return 0
        fi
    done

    # Default: dynamic (safer to include than to omit)
    printf 'dynamic'
}

# ── Public API ──

# orch_prompt_init [token_budget]
#   Configure the compression engine. Optional token budget (0 = unlimited).
orch_prompt_init() {
    local budget="${1:-0}"
    _ORCH_PROMPT_TOKEN_BUDGET="$budget"
    _orch_prompt_log INFO "Prompt compression initialized (budget=${budget})"
}

# orch_prompt_classify <agent_id> <prompt_file>
#   Parse a prompt file into sections (split on ## headers), classify each by tier.
#   Stores results in internal state for later compression.
orch_prompt_classify() {
    local agent_id="${1:?orch_prompt_classify: agent_id required}"
    local prompt_file="${2:?orch_prompt_classify: prompt_file required}"

    if [[ ! -f "$prompt_file" ]]; then
        _orch_prompt_log ERROR "Prompt file not found: $prompt_file"
        return 1
    fi

    # Reset state for this agent
    local i
    for i in $(seq 0 "${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"); do
        unset "_ORCH_PROMPT_SECTIONS[$agent_id:$i]"
        unset "_ORCH_PROMPT_SEC_HEADERS[$agent_id:$i]"
        unset "_ORCH_PROMPT_SEC_TIER[$agent_id:$i]"
    done

    local sec_idx=0
    local current_header=""
    local current_content=""
    local in_section=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            # Save previous section
            if [[ "$in_section" == true ]]; then
                _ORCH_PROMPT_SEC_HEADERS["$agent_id:$sec_idx"]="$current_header"
                _ORCH_PROMPT_SECTIONS["$agent_id:$sec_idx"]="$current_content"
                local tier
                tier=$(_orch_prompt_classify_header "$current_header")
                _ORCH_PROMPT_SEC_TIER["$agent_id:$sec_idx"]="$tier"
                sec_idx=$((sec_idx + 1))
            fi
            current_header="${BASH_REMATCH[1]}"
            current_content="## $current_header"$'\n'
            in_section=true
        elif [[ "$line" =~ ^#[[:space:]]+(.*) && "$in_section" == false ]]; then
            # Top-level # header — treat as preamble start
            current_header="${BASH_REMATCH[1]}"
            current_content="# $current_header"$'\n'
            in_section=true
        else
            if [[ "$in_section" == true ]]; then
                current_content+="$line"$'\n'
            else
                # Content before first header — treat as preamble (dynamic)
                current_header="preamble"
                current_content+="$line"$'\n'
                in_section=true
            fi
        fi
    done < "$prompt_file"

    # Save final section
    if [[ "$in_section" == true && -n "$current_content" ]]; then
        _ORCH_PROMPT_SEC_HEADERS["$agent_id:$sec_idx"]="$current_header"
        _ORCH_PROMPT_SECTIONS["$agent_id:$sec_idx"]="$current_content"
        local tier
        tier=$(_orch_prompt_classify_header "$current_header")
        _ORCH_PROMPT_SEC_TIER["$agent_id:$sec_idx"]="$tier"
        sec_idx=$((sec_idx + 1))
    fi

    _ORCH_PROMPT_SEC_COUNT["$agent_id"]="$sec_idx"
    _orch_prompt_log INFO "Classified $sec_idx sections for $agent_id"
    return 0
}

# orch_prompt_compress <agent_id> <mode>
#   Output the compressed prompt for the given mode.
#   mode: full | standard | minimal
orch_prompt_compress() {
    local agent_id="${1:?orch_prompt_compress: agent_id required}"
    local mode="${2:-standard}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"

    if [[ "$sec_count" -eq 0 ]]; then
        _orch_prompt_log WARN "No sections classified for $agent_id — call orch_prompt_classify first"
        return 1
    fi

    local i
    for ((i = 0; i < sec_count; i++)); do
        local header="${_ORCH_PROMPT_SEC_HEADERS[$agent_id:$i]}"
        local content="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
        local tier="${_ORCH_PROMPT_SEC_TIER[$agent_id:$i]}"

        case "$mode" in
            full)
                # Output everything
                printf '%s' "$content"
                ;;
            standard)
                case "$tier" in
                    stable)
                        # Condense: just the header + one-line summary
                        printf '## %s\n' "$header"
                        printf '[Stable section — unchanged since last run. See full prompt for details.]\n\n'
                        ;;
                    dynamic|reference)
                        printf '%s' "$content"
                        ;;
                esac
                ;;
            minimal)
                case "$tier" in
                    dynamic)
                        printf '%s' "$content"
                        ;;
                    stable|reference)
                        # Skip entirely
                        ;;
                esac
                ;;
        esac
    done
}

# orch_prompt_estimate_tokens <text>
#   Rough token estimate. Claude tokenizer averages ~4 chars per token for English.
#   Reads from stdin if no argument given.
orch_prompt_estimate_tokens() {
    local text=""
    if [[ $# -gt 0 ]]; then
        text="$1"
    else
        text=$(cat)
    fi

    local char_count=${#text}
    local tokens=$(( (char_count + 3) / 4 ))
    printf '%d\n' "$tokens"
}

# orch_prompt_stable_hash <agent_id>
#   Compute a hash of all stable sections for change detection.
#   Returns the hash string. Stores it in _ORCH_PROMPT_STABLE_HASH.
orch_prompt_stable_hash() {
    local agent_id="${1:?orch_prompt_stable_hash: agent_id required}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"

    local stable_content=""
    local i
    for ((i = 0; i < sec_count; i++)); do
        if [[ "${_ORCH_PROMPT_SEC_TIER[$agent_id:$i]}" == "stable" ]]; then
            stable_content+="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
        fi
    done

    local hash=""
    if [[ -n "$stable_content" ]]; then
        if command -v sha256sum &>/dev/null; then
            hash=$(printf '%s' "$stable_content" | sha256sum | cut -d' ' -f1)
        elif command -v shasum &>/dev/null; then
            hash=$(printf '%s' "$stable_content" | shasum -a 256 | cut -d' ' -f1)
        else
            # Fallback: use string length + first/last chars as poor-man's hash
            local len=${#stable_content}
            hash="len${len}_${stable_content:0:8}_${stable_content: -8}"
        fi
    else
        hash="empty"
    fi

    _ORCH_PROMPT_STABLE_HASH["$agent_id"]="$hash"
    printf '%s\n' "$hash"
}

# orch_prompt_load_hashes <state_file>
#   Load previous stable hashes from state file. Call before mode_for_agent.
orch_prompt_load_hashes() {
    local state_file="${1:?orch_prompt_load_hashes: state_file required}"

    [[ ! -f "$state_file" ]] && return 0

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        IFS='|' read -r agent_id hash <<< "$line"
        agent_id=$(_orch_prompt_trim "$agent_id")
        hash=$(_orch_prompt_trim "$hash")
        [[ -n "$agent_id" && -n "$hash" ]] && _ORCH_PROMPT_PREV_HASH["$agent_id"]="$hash"
    done < "$state_file"
}

# orch_prompt_save_hashes <state_file>
#   Persist current stable hashes to state file.
orch_prompt_save_hashes() {
    local state_file="${1:?orch_prompt_save_hashes: state_file required}"

    if ! mkdir -p "$(dirname "$state_file")"; then
        _orch_prompt_log ERROR "Failed to create directory for: $state_file"
        return 1
    fi

    {
        printf '# prompt-compression stable hashes — %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        for agent_id in "${!_ORCH_PROMPT_STABLE_HASH[@]}"; do
            printf '%s|%s\n' "$agent_id" "${_ORCH_PROMPT_STABLE_HASH[$agent_id]}"
        done
    } > "$state_file" || {
        _orch_prompt_log ERROR "Failed to write hash state: $state_file"
        return 1
    }
}

# orch_prompt_mode_for_agent <agent_id>
#   Decide compression mode based on hash comparison and token budget.
#   Call after classify + stable_hash + load_hashes.
#   Prints: full | standard | minimal
orch_prompt_mode_for_agent() {
    local agent_id="${1:?orch_prompt_mode_for_agent: agent_id required}"

    local current_hash="${_ORCH_PROMPT_STABLE_HASH[$agent_id]:-}"
    local prev_hash="${_ORCH_PROMPT_PREV_HASH[$agent_id]:-}"

    # First run or no previous hash — full mode
    if [[ -z "$prev_hash" || "$prev_hash" == "empty" ]]; then
        printf 'full\n'
        return 0
    fi

    # Stable sections changed — full mode
    if [[ "$current_hash" != "$prev_hash" ]]; then
        _orch_prompt_log INFO "Stable sections changed for $agent_id — using full mode"
        printf 'full\n'
        return 0
    fi

    # Check token budget
    if [[ "$_ORCH_PROMPT_TOKEN_BUDGET" -gt 0 ]]; then
        # Estimate full prompt tokens
        local full_text
        full_text=$(orch_prompt_compress "$agent_id" "full")
        local full_tokens
        full_tokens=$(orch_prompt_estimate_tokens "$full_text")

        if [[ "$full_tokens" -gt $((_ORCH_PROMPT_TOKEN_BUDGET * 2)) ]]; then
            _orch_prompt_log WARN "$agent_id prompt ($full_tokens tokens) exceeds 2x budget — minimal mode"
            printf 'minimal\n'
            return 0
        fi
    fi

    # Default: standard compression (stable sections condensed)
    printf 'standard\n'
}

# orch_prompt_stats <agent_id>
#   Print tier breakdown: count and estimated tokens per tier.
orch_prompt_stats() {
    local agent_id="${1:?orch_prompt_stats: agent_id required}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"

    local stable_count=0 dynamic_count=0 reference_count=0
    local stable_chars=0 dynamic_chars=0 reference_chars=0

    local i
    for ((i = 0; i < sec_count; i++)); do
        local tier="${_ORCH_PROMPT_SEC_TIER[$agent_id:$i]}"
        local content="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
        local chars=${#content}

        case "$tier" in
            stable)    stable_count=$((stable_count + 1)); stable_chars=$((stable_chars + chars)) ;;
            dynamic)   dynamic_count=$((dynamic_count + 1)); dynamic_chars=$((dynamic_chars + chars)) ;;
            reference) reference_count=$((reference_count + 1)); reference_chars=$((reference_chars + chars)) ;;
        esac
    done

    local total_chars=$((stable_chars + dynamic_chars + reference_chars))
    local stable_pct=0 dynamic_pct=0 reference_pct=0
    if [[ "$total_chars" -gt 0 ]]; then
        stable_pct=$((stable_chars * 100 / total_chars))
        dynamic_pct=$((dynamic_chars * 100 / total_chars))
        reference_pct=$((reference_chars * 100 / total_chars))
    fi

    printf 'prompt-compression stats for %s (%d sections):\n' "$agent_id" "$sec_count"
    printf '  stable:    %d sections, ~%d tokens (%d%%)\n' "$stable_count" "$(( (stable_chars + 3) / 4 ))" "$stable_pct"
    printf '  dynamic:   %d sections, ~%d tokens (%d%%)\n' "$dynamic_count" "$(( (dynamic_chars + 3) / 4 ))" "$dynamic_pct"
    printf '  reference: %d sections, ~%d tokens (%d%%)\n' "$reference_count" "$(( (reference_chars + 3) / 4 ))" "$reference_pct"
    printf '  total:     ~%d tokens\n' "$(( (total_chars + 3) / 4 ))"
    printf '  standard mode saves: ~%d tokens (%d%%)\n' "$(( (stable_chars + 3) / 4 ))" "$stable_pct"
}
