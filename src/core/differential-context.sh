#!/usr/bin/env bash
# differential-context.sh — Per-agent relevant context filtering
# v0.3.0: #49 — filter shared context to only sections each agent needs
#         v0.3 adds: relevance scoring, context budget allocation,
#         sliding window with importance weighting, section aging
#
# Shared context (context.md) contains sections for all surfaces:
# Backend Status, iOS Status, Design Status, QA Findings, Blockers, Notes.
# Most agents only need a subset. This module filters context per-agent,
# saving 30-60% of context tokens for agents that don't need all sections.
#
# Section types:
#   universal   — All agents see this (Usage, Progress, Blockers, Notes, QA Findings)
#   role-mapped — Only agents in the mapping see this (Backend Status → backend, cto, qa, ...)
#
# Cross-cycle history filtering:
#   Each agent sees: own entries, dependency entries, PM entries, entries mentioning them
#
# Provides:
#   orch_diffctx_init           — set up default section→agent mappings
#   orch_diffctx_add_mapping    — add/override a section→agents mapping
#   orch_diffctx_parse          — parse context file into named sections
#   orch_diffctx_filter         — return filtered context for a given agent
#   orch_diffctx_filter_history — filter cross-cycle history for agent relevance
#   orch_diffctx_stats          — print per-agent token savings estimate
#   orch_diffctx_score_sections — relevance scoring per section per agent (v0.3)
#   orch_diffctx_budget_filter  — filter to fit within token budget (v0.3)
#   orch_diffctx_sliding_window — sliding window history with importance weighting (v0.3)

[[ -n "${_ORCH_DIFFCTX_LOADED:-}" ]] && return 0
_ORCH_DIFFCTX_LOADED=1

# ── State ──
declare -g -A _ORCH_DIFFCTX_MAPPINGS=()    # "section_key" -> "agent1 agent2 ..." or "*" for universal
declare -g -A _ORCH_DIFFCTX_SECTIONS=()    # "N" -> section content (indexed by parse order)
declare -g -A _ORCH_DIFFCTX_SEC_KEYS=()    # "N" -> section key (normalized header)
declare -g -A _ORCH_DIFFCTX_SEC_HEADERS=() # "N" -> raw header text
declare -g _ORCH_DIFFCTX_SEC_COUNT=0
declare -g -A _ORCH_DIFFCTX_DEPS=()        # agent_id -> "dep1 dep2 ..." (dependency agents)
declare -g _ORCH_DIFFCTX_INITIALIZED=false

# v0.3 Relevance scoring state
declare -g -A _ORCH_DIFFCTX_RELEVANCE=()    # "agent:N" -> relevance score (0-100)

# v0.3 Context budget (tokens)
declare -g _ORCH_DIFFCTX_BUDGET="${ORCH_DIFFCTX_BUDGET:-0}"  # 0 = unlimited

# v0.3 Sliding window config
declare -g _ORCH_DIFFCTX_WINDOW_SIZE="${ORCH_DIFFCTX_WINDOW_SIZE:-5}"     # keep last N cycles
declare -g _ORCH_DIFFCTX_RECENCY_WEIGHT="${ORCH_DIFFCTX_RECENCY_WEIGHT:-20}"  # bonus per cycle of recency

# v0.3 Importance weights for scoring
declare -g -A _ORCH_DIFFCTX_IMPORTANCE=(
    [universal]=80
    [role-mapped]=60
    [unmapped]=40
)

# ── Helpers ──

_orch_diffctx_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "diff-context" "$2"
    fi
}

_orch_diffctx_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Normalize a section header to a key: lowercase, spaces→dashes, strip emoji/special
_orch_diffctx_normalize_key() {
    local header="$1"
    local key="${header,,}"
    # Strip leading emoji (common in prompts)
    key="${key#[[:space:]]}"
    key=$(printf '%s' "$key" | sed 's/[^a-z0-9 _-]//g')
    key=$(_orch_diffctx_trim "$key")
    key="${key// /-}"
    printf '%s' "$key"
}

# Extract agent label from agent_id: "06-backend" -> "backend", "09-qa" -> "qa"
_orch_diffctx_agent_label() {
    local agent_id="$1"
    printf '%s' "${agent_id#*-}"
}

# Check if an agent is in a space-separated list
_orch_diffctx_in_list() {
    local needle="$1"
    local haystack="$2"

    [[ "$haystack" == "*" ]] && return 0

    local item
    for item in $haystack; do
        [[ "$item" == "$needle" ]] && return 0
    done

    # Also match by label (e.g., "backend" matches "06-backend")
    local needle_label
    needle_label=$(_orch_diffctx_agent_label "$needle")
    for item in $haystack; do
        [[ "$item" == "$needle_label" ]] && return 0
    done

    return 1
}

# ── Public API ──

# orch_diffctx_init [conf_file]
#   Set up default section→agent mappings. Optionally parse agents.conf for dependencies.
orch_diffctx_init() {
    local conf_file="${1:-}"

    # Reset state
    _ORCH_DIFFCTX_MAPPINGS=()
    _ORCH_DIFFCTX_SECTIONS=()
    _ORCH_DIFFCTX_SEC_KEYS=()
    _ORCH_DIFFCTX_SEC_HEADERS=()
    _ORCH_DIFFCTX_SEC_COUNT=0
    _ORCH_DIFFCTX_DEPS=()

    # Universal sections — all agents see these
    _ORCH_DIFFCTX_MAPPINGS["usage"]="*"
    _ORCH_DIFFCTX_MAPPINGS["progress-last-cycle--this-cycle"]="*"
    _ORCH_DIFFCTX_MAPPINGS["progress"]="*"
    _ORCH_DIFFCTX_MAPPINGS["blockers"]="*"
    _ORCH_DIFFCTX_MAPPINGS["notes"]="*"
    _ORCH_DIFFCTX_MAPPINGS["qa-findings"]="*"

    # Role-mapped sections — only relevant agents
    _ORCH_DIFFCTX_MAPPINGS["backend-status"]="06-backend 02-cto 09-qa 10-security 03-pm"
    _ORCH_DIFFCTX_MAPPINGS["ios-status"]="07-ios 02-cto 09-qa 03-pm"
    _ORCH_DIFFCTX_MAPPINGS["design-status"]="05-tauri-ui 08-pixel 11-web 02-cto 03-pm"
    _ORCH_DIFFCTX_MAPPINGS["tauri-status"]="04-tauri-rust 05-tauri-ui 02-cto 03-pm"
    _ORCH_DIFFCTX_MAPPINGS["web-status"]="11-web 02-cto 03-pm"
    _ORCH_DIFFCTX_MAPPINGS["pixel-status"]="08-pixel 02-cto 03-pm"
    _ORCH_DIFFCTX_MAPPINGS["security-findings"]="10-security 06-backend 02-cto 03-pm"

    # Parse dependencies from agents.conf if available (v2+ format with depends_on)
    if [[ -n "$conf_file" && -f "$conf_file" ]]; then
        _orch_diffctx_parse_deps "$conf_file"
    fi

    _ORCH_DIFFCTX_INITIALIZED=true
    _orch_diffctx_log INFO "Differential context initialized (${#_ORCH_DIFFCTX_MAPPINGS[@]} section mappings)"
    return 0
}

# Parse depends_on from agents.conf (column 7 in v2+ format)
_orch_diffctx_parse_deps() {
    local conf_file="$1"

    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed
        trimmed=$(_orch_diffctx_trim "$raw_line")
        [[ "$trimmed" == \#* ]] && continue

        # Try to parse v2+ format (7+ columns)
        local col_count
        col_count=$(printf '%s' "$raw_line" | awk -F'|' '{print NF}')

        if [[ "$col_count" -ge 7 ]]; then
            IFS='|' read -r f_id _ _ _ _ _ f_deps _ <<< "$raw_line"
            f_id=$(_orch_diffctx_trim "$f_id")
            f_deps=$(_orch_diffctx_trim "$f_deps")
            if [[ -n "$f_id" && -n "$f_deps" && "$f_deps" != "none" ]]; then
                # Convert comma-separated to space-separated
                _ORCH_DIFFCTX_DEPS["$f_id"]="${f_deps//,/ }"
            fi
        fi
    done < "$conf_file"
}

# orch_diffctx_add_mapping <section_key> <agent_list>
#   Add or override a section→agents mapping.
#   agent_list: space-separated agent IDs, or "*" for universal.
orch_diffctx_add_mapping() {
    local section_key="${1:?orch_diffctx_add_mapping: section_key required}"
    local agent_list="${2:?orch_diffctx_add_mapping: agent_list required}"

    _ORCH_DIFFCTX_MAPPINGS["$section_key"]="$agent_list"
}

# orch_diffctx_parse <context_file>
#   Parse context.md into named sections (split on ## headers).
orch_diffctx_parse() {
    local context_file="${1:?orch_diffctx_parse: context_file required}"

    if [[ ! -f "$context_file" ]]; then
        _orch_diffctx_log ERROR "Context file not found: $context_file"
        return 1
    fi

    # Reset parse state
    _ORCH_DIFFCTX_SECTIONS=()
    _ORCH_DIFFCTX_SEC_KEYS=()
    _ORCH_DIFFCTX_SEC_HEADERS=()
    _ORCH_DIFFCTX_SEC_COUNT=0

    local sec_idx=0
    local current_header=""
    local current_key=""
    local current_content=""
    local in_section=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            # Save previous section
            if [[ "$in_section" == true && -n "$current_content" ]]; then
                _ORCH_DIFFCTX_SEC_HEADERS["$sec_idx"]="$current_header"
                _ORCH_DIFFCTX_SEC_KEYS["$sec_idx"]="$current_key"
                _ORCH_DIFFCTX_SECTIONS["$sec_idx"]="$current_content"
                sec_idx=$((sec_idx + 1))
            fi
            current_header="${BASH_REMATCH[1]}"
            current_key=$(_orch_diffctx_normalize_key "$current_header")
            current_content="## $current_header"$'\n'
            in_section=true
        elif [[ "$line" =~ ^#[[:space:]]+(.*) && "$in_section" == false ]]; then
            # Top-level header — keep as preamble
            current_header="${BASH_REMATCH[1]}"
            current_key="preamble"
            current_content="# $current_header"$'\n'
            in_section=true
        else
            if [[ "$in_section" == true ]]; then
                current_content+="$line"$'\n'
            else
                # Content before first header — preamble
                current_header="preamble"
                current_key="preamble"
                current_content+="$line"$'\n'
                in_section=true
            fi
        fi
    done < "$context_file"

    # Save final section
    if [[ "$in_section" == true && -n "$current_content" ]]; then
        _ORCH_DIFFCTX_SEC_HEADERS["$sec_idx"]="$current_header"
        _ORCH_DIFFCTX_SEC_KEYS["$sec_idx"]="$current_key"
        _ORCH_DIFFCTX_SECTIONS["$sec_idx"]="$current_content"
        sec_idx=$((sec_idx + 1))
    fi

    _ORCH_DIFFCTX_SEC_COUNT="$sec_idx"
    _orch_diffctx_log INFO "Parsed $sec_idx sections from $context_file"
    return 0
}

# orch_diffctx_filter <agent_id>
#   Output only the context sections relevant to this agent.
#   Unmapped sections are included by default (fail-open — safer to include than omit).
orch_diffctx_filter() {
    local agent_id="${1:?orch_diffctx_filter: agent_id required}"

    [[ "$_ORCH_DIFFCTX_INITIALIZED" != "true" ]] && {
        _orch_diffctx_log ERROR "Not initialized — call orch_diffctx_init first"
        return 1
    }

    if [[ "$_ORCH_DIFFCTX_SEC_COUNT" -eq 0 ]]; then
        _orch_diffctx_log WARN "No sections parsed — call orch_diffctx_parse first"
        return 1
    fi

    # PM/coordinator always gets everything
    local agent_label
    agent_label=$(_orch_diffctx_agent_label "$agent_id")
    if [[ "$agent_label" == "pm" ]]; then
        local i
        for ((i = 0; i < _ORCH_DIFFCTX_SEC_COUNT; i++)); do
            printf '%s' "${_ORCH_DIFFCTX_SECTIONS[$i]}"
        done
        return 0
    fi

    local included=0
    local excluded=0
    local i
    for ((i = 0; i < _ORCH_DIFFCTX_SEC_COUNT; i++)); do
        local key="${_ORCH_DIFFCTX_SEC_KEYS[$i]}"
        local mapping="${_ORCH_DIFFCTX_MAPPINGS[$key]:-}"

        if [[ -z "$mapping" ]]; then
            # Unmapped section — include (fail-open)
            printf '%s' "${_ORCH_DIFFCTX_SECTIONS[$i]}"
            included=$((included + 1))
        elif _orch_diffctx_in_list "$agent_id" "$mapping"; then
            printf '%s' "${_ORCH_DIFFCTX_SECTIONS[$i]}"
            included=$((included + 1))
        else
            excluded=$((excluded + 1))
        fi
    done

    _orch_diffctx_log INFO "$agent_id: included $included sections, excluded $excluded"
    return 0
}

# orch_diffctx_filter_history <agent_id> <history_content>
#   Filter cross-cycle history to only entries relevant to this agent.
#   Keeps: own entries, dependency entries, PM entries, entries mentioning agent.
#   Input: the raw history text (from context-cycle-*.md or inline).
#   Output: filtered history text.
orch_diffctx_filter_history() {
    local agent_id="${1:?orch_diffctx_filter_history: agent_id required}"
    local history_content="${2:-}"

    [[ -z "$history_content" ]] && return 0

    # PM gets everything
    local agent_label
    agent_label=$(_orch_diffctx_agent_label "$agent_id")
    if [[ "$agent_label" == "pm" ]]; then
        printf '%s' "$history_content"
        return 0
    fi

    # Build relevance list: self + deps + pm
    local -a relevant_ids=("$agent_id" "03-pm")
    local deps="${_ORCH_DIFFCTX_DEPS[$agent_id]:-}"
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            relevant_ids+=("$dep")
        done
    fi

    # Also build label list for matching
    local -a relevant_labels=()
    for rid in "${relevant_ids[@]}"; do
        relevant_labels+=("$(_orch_diffctx_agent_label "$rid")")
    done

    local output=""
    local current_block=""
    local current_header=""
    local include_block=false
    local in_block=false

    while IFS= read -r line; do
        # Detect ### agent header (e.g., "### 06-Backend (this cycle)")
        if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
            # Flush previous block
            if [[ "$in_block" == true && "$include_block" == true ]]; then
                output+="$current_block"
            fi

            current_header="${BASH_REMATCH[1]}"
            current_block="$line"$'\n'
            in_block=true
            include_block=false

            # Check if this block is relevant
            local header_lower="${current_header,,}"
            for rid in "${relevant_ids[@]}"; do
                if [[ "$header_lower" == *"${rid,,}"* ]]; then
                    include_block=true
                    break
                fi
            done
            if [[ "$include_block" == false ]]; then
                for rlbl in "${relevant_labels[@]}"; do
                    if [[ "$header_lower" == *"$rlbl"* ]]; then
                        include_block=true
                        break
                    fi
                done
            fi

            # "All" blocks are always relevant
            if [[ "$header_lower" == *"all"* ]]; then
                include_block=true
            fi

        elif [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            # Flush previous block
            if [[ "$in_block" == true && "$include_block" == true ]]; then
                output+="$current_block"
            fi
            # ## headers are cycle separators — always include
            output+="$line"$'\n'
            in_block=false
            current_block=""

        elif [[ "$line" =~ ^---$ ]]; then
            # Flush previous block
            if [[ "$in_block" == true && "$include_block" == true ]]; then
                output+="$current_block"
            fi
            output+="$line"$'\n'
            in_block=false
            current_block=""

        else
            if [[ "$in_block" == true ]]; then
                current_block+="$line"$'\n'

                # Check if this line mentions our agent (catch cross-references)
                if [[ "$include_block" == false ]]; then
                    local line_lower="${line,,}"
                    for rid in "${relevant_ids[@]}"; do
                        if [[ "$line_lower" == *"${rid,,}"* ]]; then
                            include_block=true
                            break
                        fi
                    done
                fi
            else
                # Content outside blocks (preamble, milestone tables, etc.) — always include
                output+="$line"$'\n'
            fi
        fi
    done <<< "$history_content"

    # Flush last block
    if [[ "$in_block" == true && "$include_block" == true ]]; then
        output+="$current_block"
    fi

    printf '%s' "$output"
}

# orch_diffctx_stats <agent_id>
#   Print token savings estimate for filtering this agent's context.
orch_diffctx_stats() {
    local agent_id="${1:?orch_diffctx_stats: agent_id required}"

    [[ "$_ORCH_DIFFCTX_SEC_COUNT" -eq 0 ]] && {
        printf 'No sections parsed.\n'
        return 1
    }

    local total_chars=0
    local included_chars=0
    local excluded_chars=0
    local agent_label
    agent_label=$(_orch_diffctx_agent_label "$agent_id")

    local i
    for ((i = 0; i < _ORCH_DIFFCTX_SEC_COUNT; i++)); do
        local content="${_ORCH_DIFFCTX_SECTIONS[$i]}"
        local chars=${#content}
        total_chars=$((total_chars + chars))

        local key="${_ORCH_DIFFCTX_SEC_KEYS[$i]}"
        local mapping="${_ORCH_DIFFCTX_MAPPINGS[$key]:-}"

        if [[ -z "$mapping" ]] || [[ "$agent_label" == "pm" ]] || _orch_diffctx_in_list "$agent_id" "$mapping"; then
            included_chars=$((included_chars + chars))
        else
            excluded_chars=$((excluded_chars + chars))
        fi
    done

    local total_tokens=$(( (total_chars + 3) / 4 ))
    local included_tokens=$(( (included_chars + 3) / 4 ))
    local excluded_tokens=$(( (excluded_chars + 3) / 4 ))
    local savings_pct=0
    if [[ "$total_chars" -gt 0 ]]; then
        savings_pct=$((excluded_chars * 100 / total_chars))
    fi

    printf 'differential-context stats for %s:\n' "$agent_id"
    printf '  total:    ~%d tokens (%d chars)\n' "$total_tokens" "$total_chars"
    printf '  included: ~%d tokens (%d chars)\n' "$included_tokens" "$included_chars"
    printf '  excluded: ~%d tokens (%d chars)\n' "$excluded_tokens" "$excluded_chars"
    printf '  savings:  %d%%\n' "$savings_pct"
}

# orch_diffctx_list_mappings
#   Print all section→agent mappings for debugging.
orch_diffctx_list_mappings() {
    printf 'differential-context section mappings:\n'
    for key in $(printf '%s\n' "${!_ORCH_DIFFCTX_MAPPINGS[@]}" | sort); do
        printf '  %-35s → %s\n' "$key" "${_ORCH_DIFFCTX_MAPPINGS[$key]}"
    done
}

# ══════════════════════════════════════════════════
# v0.3 Relevance Scoring
# ══════════════════════════════════════════════════

# orch_diffctx_score_sections <agent_id>
#   Compute relevance score (0-100) for each section relative to an agent.
#   Scoring factors: mapping match, keyword overlap, section position (recency).
#   Stores results in _ORCH_DIFFCTX_RELEVANCE and prints breakdown.
orch_diffctx_score_sections() {
    local agent_id="${1:?orch_diffctx_score_sections: agent_id required}"

    [[ "$_ORCH_DIFFCTX_INITIALIZED" != "true" ]] && return 1
    [[ "$_ORCH_DIFFCTX_SEC_COUNT" -eq 0 ]] && return 1

    local agent_label
    agent_label=$(_orch_diffctx_agent_label "$agent_id")

    printf 'relevance scores for %s:\n' "$agent_id"
    printf '%-4s %-30s %-12s %s\n' "IDX" "SECTION" "MAPPING" "SCORE"

    local i
    for ((i = 0; i < _ORCH_DIFFCTX_SEC_COUNT; i++)); do
        local key="${_ORCH_DIFFCTX_SEC_KEYS[$i]}"
        local header="${_ORCH_DIFFCTX_SEC_HEADERS[$i]}"
        local content="${_ORCH_DIFFCTX_SECTIONS[$i]}"
        local mapping="${_ORCH_DIFFCTX_MAPPINGS[$key]:-}"
        local score=0
        local mapping_type="unmapped"

        # PM gets everything at max score
        if [[ "$agent_label" == "pm" ]]; then
            score=100
            mapping_type="pm-all"
        elif [[ -z "$mapping" ]]; then
            # Unmapped: base score 40 (fail-open)
            score="${_ORCH_DIFFCTX_IMPORTANCE[unmapped]}"
            mapping_type="unmapped"
        elif [[ "$mapping" == "*" ]]; then
            # Universal: high relevance
            score="${_ORCH_DIFFCTX_IMPORTANCE[universal]}"
            mapping_type="universal"
        elif _orch_diffctx_in_list "$agent_id" "$mapping"; then
            # Directly mapped: high relevance
            score="${_ORCH_DIFFCTX_IMPORTANCE[role-mapped]}"
            mapping_type="role-mapped"
        else
            # Not in mapping: low relevance
            score=10
            mapping_type="excluded"
        fi

        # Bonus: content mentions the agent
        local content_lower="${content,,}"
        if [[ "$content_lower" == *"${agent_id,,}"* || "$content_lower" == *"${agent_label,,}"* ]]; then
            score=$(( score + 15 ))
        fi

        # Cap at 100
        [[ "$score" -gt 100 ]] && score=100

        _ORCH_DIFFCTX_RELEVANCE["$agent_id:$i"]="$score"

        printf '%-4d %-30s %-12s %d\n' "$i" "${header:0:30}" "$mapping_type" "$score"
    done
}

# orch_diffctx_budget_filter <agent_id> [budget_tokens]
#   Filter context sections for an agent, fitting within a token budget.
#   Sections are sorted by relevance score (highest first).
#   Outputs sections until budget is exhausted.
orch_diffctx_budget_filter() {
    local agent_id="${1:?orch_diffctx_budget_filter: agent_id required}"
    local budget="${2:-$_ORCH_DIFFCTX_BUDGET}"

    [[ "$_ORCH_DIFFCTX_SEC_COUNT" -eq 0 ]] && return 1

    # Ensure scores are computed
    local has_scores=true
    if [[ -z "${_ORCH_DIFFCTX_RELEVANCE[$agent_id:0]+x}" ]]; then
        orch_diffctx_score_sections "$agent_id" >/dev/null
    fi

    # If no budget, use regular filter
    if [[ "$budget" -le 0 ]]; then
        orch_diffctx_filter "$agent_id"
        return $?
    fi

    # Build sorted index by score (descending)
    local -a sorted_indices=()
    sorted_indices=($(for ((i = 0; i < _ORCH_DIFFCTX_SEC_COUNT; i++)); do
        printf '%s %d\n' "${_ORCH_DIFFCTX_RELEVANCE[$agent_id:$i]:-0}" "$i"
    done | sort -rn -k1 | awk '{print $2}'))

    local budget_remaining="$budget"
    local included=0
    local excluded=0

    for idx in "${sorted_indices[@]}"; do
        local content="${_ORCH_DIFFCTX_SECTIONS[$idx]}"
        local char_count=${#content}
        local tokens=$(( (char_count + 3) / 4 ))
        local score="${_ORCH_DIFFCTX_RELEVANCE[$agent_id:$idx]:-0}"

        # Skip sections with score <= 10 (not relevant)
        [[ "$score" -le 10 ]] && { excluded=$((excluded + 1)); continue; }

        if [[ "$tokens" -le "$budget_remaining" ]]; then
            printf '%s' "$content"
            budget_remaining=$((budget_remaining - tokens))
            included=$((included + 1))
        else
            excluded=$((excluded + 1))
        fi
    done

    _orch_diffctx_log INFO "$agent_id: budget filter included $included, excluded $excluded sections (${budget_remaining} tokens remaining)"
}

# ══════════════════════════════════════════════════
# v0.3 Sliding Window with Importance Weighting
# ══════════════════════════════════════════════════

# orch_diffctx_sliding_window <agent_id> <history_content> [current_cycle]
#   Apply a sliding window to cross-cycle history, keeping only the most recent
#   and most important entries. Combines recency weighting with relevance.
#   - Recent cycles get full detail
#   - Older cycles get only high-importance entries (blockers, errors, mentions)
#   - Cycles beyond window_size are dropped entirely
orch_diffctx_sliding_window() {
    local agent_id="${1:?orch_diffctx_sliding_window: agent_id required}"
    local history_content="${2:-}"
    local current_cycle="${3:-0}"

    [[ -z "$history_content" ]] && return 0

    local window_size="$_ORCH_DIFFCTX_WINDOW_SIZE"
    local agent_label
    agent_label=$(_orch_diffctx_agent_label "$agent_id")

    # PM gets everything
    if [[ "$agent_label" == "pm" ]]; then
        printf '%s' "$history_content"
        return 0
    fi

    local output=""
    local current_block=""
    local current_cycle_num=0
    local in_cycle_header=false
    local block_importance=0

    while IFS= read -r line; do
        # Detect cycle headers: "## Cycle N" or "## cycle-N"
        if [[ "$line" =~ ^##[[:space:]]+[Cc]ycle.*([0-9]+) ]]; then
            # Flush previous block
            if [[ -n "$current_block" && "$block_importance" -gt 0 ]]; then
                output+="$current_block"
            fi

            current_cycle_num="${BASH_REMATCH[1]}"
            current_block="$line"$'\n'
            in_cycle_header=true

            # Compute age-based importance
            local age=0
            if [[ "$current_cycle" -gt 0 && "$current_cycle_num" -gt 0 ]]; then
                age=$(( current_cycle - current_cycle_num ))
            fi

            if [[ "$age" -gt "$window_size" ]]; then
                block_importance=0  # Too old, drop
            elif [[ "$age" -le 2 ]]; then
                block_importance=100  # Very recent, keep all
            else
                block_importance=$(( 100 - (age * _ORCH_DIFFCTX_RECENCY_WEIGHT) ))
                [[ "$block_importance" -lt 0 ]] && block_importance=0
            fi

        elif [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            # Other ## headers
            if [[ -n "$current_block" && "$block_importance" -gt 0 ]]; then
                output+="$current_block"
            fi
            current_block="$line"$'\n'
            block_importance=50  # Default importance for non-cycle headers

        elif [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
            # Agent entry header — check relevance
            if [[ -n "$current_block" && "$block_importance" -gt 0 ]]; then
                output+="$current_block"
            fi
            current_block="$line"$'\n'
            local entry_header="${BASH_REMATCH[1],,}"

            # Boost importance if it mentions our agent or is PM
            if [[ "$entry_header" == *"${agent_id,,}"* || "$entry_header" == *"$agent_label"* || "$entry_header" == *"pm"* ]]; then
                block_importance=$(( block_importance + 30 ))
            fi
            # Boost for blocker/error mentions
            if [[ "$entry_header" == *"blocker"* || "$entry_header" == *"error"* ]]; then
                block_importance=$(( block_importance + 20 ))
            fi
        else
            current_block+="$line"$'\n'

            # Boost importance for high-signal content
            local line_lower="${line,,}"
            if [[ "$line_lower" == *"blocker"* || "$line_lower" == *"blocking"* || "$line_lower" == *"error"* || "$line_lower" == *"failed"* ]]; then
                block_importance=$(( block_importance + 10 ))
            fi
            if [[ "$line_lower" == *"${agent_id,,}"* || "$line_lower" == *"$agent_label"* ]]; then
                block_importance=$(( block_importance + 10 ))
            fi
        fi
    done <<< "$history_content"

    # Flush last block
    if [[ -n "$current_block" && "$block_importance" -gt 0 ]]; then
        output+="$current_block"
    fi

    printf '%s' "$output"
}
