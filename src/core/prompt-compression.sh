#!/usr/bin/env bash
# prompt-compression.sh — Tiered prompt loading for token savings
# v0.3.0: #47 — classify prompt sections, compress stable content on repeat runs
#         v0.3 adds: precise token counting, semantic deduplication, priority-based
#         truncation with budget enforcement, per-section token tracking
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
#   budget    — Priority-based truncation to fit within token budget (v0.3)
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
#   orch_prompt_count_tokens     — precise token counting with multiple methods (v0.3)
#   orch_prompt_dedup_sections   — semantic deduplication of similar sections (v0.3)
#   orch_prompt_truncate_to_budget — priority-based truncation to fit budget (v0.3)
#   orch_prompt_section_tokens   — get token count per section (v0.3)

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

# v0.3 Per-section token counts and priority
declare -g -A _ORCH_PROMPT_SEC_TOKENS=()   # "agent:N" -> token count for section
declare -g -A _ORCH_PROMPT_SEC_PRIORITY=() # "agent:N" -> priority (1=highest, 10=lowest)
declare -g -A _ORCH_PROMPT_DEDUP_MAP=()    # "agent:N" -> "agent:M" if N is duplicate of M

# v0.3 Tier priorities (lower = higher priority, kept first during truncation)
declare -g -A _ORCH_PROMPT_TIER_PRIORITY=(
    [dynamic]=1
    [reference]=5
    [stable]=8
)

# v0.3 Token counting method: chars (fast, ~4 chars/token) | words (medium, ~1.3 tokens/word)
declare -g _ORCH_PROMPT_TOKEN_METHOD="${ORCH_PROMPT_TOKEN_METHOD:-chars}"

# v0.3 Deduplication similarity threshold (0-100, percentage of shared words)
declare -g _ORCH_PROMPT_DEDUP_THRESHOLD="${ORCH_PROMPT_DEDUP_THRESHOLD:-70}"

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

# (orch_prompt_compress moved to v0.3 section below with budget mode support)

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

# ══════════════════════════════════════════════════
# v0.3 Precise Token Counting
# ══════════════════════════════════════════════════

# orch_prompt_count_tokens <text> [method]
#   Count tokens using the specified method.
#   Methods: chars (~4 chars/token), words (~1.3 tokens/word)
#   Reads from stdin if no text argument given.
orch_prompt_count_tokens() {
    local text=""
    local method="${2:-$_ORCH_PROMPT_TOKEN_METHOD}"

    if [[ $# -gt 0 && -n "$1" ]]; then
        text="$1"
    else
        text=$(cat)
    fi

    [[ -z "$text" ]] && { printf '0\n'; return 0; }

    case "$method" in
        chars)
            local char_count=${#text}
            printf '%d\n' "$(( (char_count + 3) / 4 ))"
            ;;
        words)
            # Word-based: ~1.3 tokens per word (accounts for subword tokenization)
            local word_count
            word_count=$(printf '%s' "$text" | wc -w)
            word_count="${word_count// /}"
            printf '%d\n' "$(( (word_count * 13 + 9) / 10 ))"
            ;;
        *)
            # Fallback to chars
            local char_count=${#text}
            printf '%d\n' "$(( (char_count + 3) / 4 ))"
            ;;
    esac
}

# orch_prompt_section_tokens <agent_id>
#   Compute and cache token counts for each section. Prints section-by-section breakdown.
orch_prompt_section_tokens() {
    local agent_id="${1:?orch_prompt_section_tokens: agent_id required}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"
    local total=0

    local i
    for ((i = 0; i < sec_count; i++)); do
        local content="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
        local tokens
        tokens=$(orch_prompt_count_tokens "$content")
        _ORCH_PROMPT_SEC_TOKENS["$agent_id:$i"]="$tokens"

        # Assign priority based on tier
        local tier="${_ORCH_PROMPT_SEC_TIER[$agent_id:$i]}"
        _ORCH_PROMPT_SEC_PRIORITY["$agent_id:$i"]="${_ORCH_PROMPT_TIER_PRIORITY[$tier]:-5}"

        local header="${_ORCH_PROMPT_SEC_HEADERS[$agent_id:$i]}"
        printf '  [%d] %-30s %-10s %d tokens (pri=%s)\n' \
            "$i" "$header" "$tier" "$tokens" "${_ORCH_PROMPT_SEC_PRIORITY[$agent_id:$i]}"

        total=$((total + tokens))
    done

    printf '  total: %d tokens\n' "$total"
}

# ══════════════════════════════════════════════════
# v0.3 Semantic Deduplication
# ══════════════════════════════════════════════════

# _orch_prompt_word_set <text>
#   Extract unique lowercase words from text (for similarity comparison).
_orch_prompt_word_set() {
    local text="${1,,}"
    # Remove punctuation, extract words
    printf '%s' "$text" | tr -cs 'a-z0-9' '\n' | sort -u | tr '\n' ' '
}

# _orch_prompt_similarity <text_a> <text_b>
#   Compute word-level Jaccard similarity (0-100).
_orch_prompt_similarity() {
    local text_a="$1"
    local text_b="$2"

    local words_a words_b
    words_a=$(_orch_prompt_word_set "$text_a")
    words_b=$(_orch_prompt_word_set "$text_b")

    [[ -z "$words_a" || -z "$words_b" ]] && { printf '0'; return; }

    # Count intersection and union
    local -A set_a=() set_b=()
    local w
    for w in $words_a; do set_a["$w"]=1; done
    for w in $words_b; do set_b["$w"]=1; done

    local intersection=0 union=0
    for w in "${!set_a[@]}"; do
        union=$((union + 1))
        [[ -n "${set_b[$w]+x}" ]] && intersection=$((intersection + 1))
    done
    for w in "${!set_b[@]}"; do
        [[ -z "${set_a[$w]+x}" ]] && union=$((union + 1))
    done

    [[ "$union" -eq 0 ]] && { printf '0'; return; }
    printf '%d' "$(( intersection * 100 / union ))"
}

# orch_prompt_dedup_sections <agent_id>
#   Find and mark semantically duplicate sections. Duplicates are marked in
#   _ORCH_PROMPT_DEDUP_MAP. Returns count of duplicates found.
orch_prompt_dedup_sections() {
    local agent_id="${1:?orch_prompt_dedup_sections: agent_id required}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"
    local threshold="${_ORCH_PROMPT_DEDUP_THRESHOLD}"
    local dedup_count=0

    # Clear previous dedup map for this agent
    local i
    for ((i = 0; i < sec_count; i++)); do
        unset "_ORCH_PROMPT_DEDUP_MAP[$agent_id:$i]"
    done

    # Compare all pairs (O(n^2) but section count is small, typically <15)
    local j
    for ((i = 0; i < sec_count; i++)); do
        # Skip if already marked as duplicate
        [[ -n "${_ORCH_PROMPT_DEDUP_MAP[$agent_id:$i]+x}" ]] && continue

        local content_i="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
        [[ ${#content_i} -lt 20 ]] && continue  # skip tiny sections

        for ((j = i + 1; j < sec_count; j++)); do
            [[ -n "${_ORCH_PROMPT_DEDUP_MAP[$agent_id:$j]+x}" ]] && continue

            local content_j="${_ORCH_PROMPT_SECTIONS[$agent_id:$j]}"
            [[ ${#content_j} -lt 20 ]] && continue

            local sim
            sim=$(_orch_prompt_similarity "$content_i" "$content_j")

            if [[ "$sim" -ge "$threshold" ]]; then
                _ORCH_PROMPT_DEDUP_MAP["$agent_id:$j"]="$agent_id:$i"
                _orch_prompt_log INFO "Dedup: section $j (~${sim}% similar to $i) for $agent_id"
                dedup_count=$((dedup_count + 1))
            fi
        done
    done

    printf '%d\n' "$dedup_count"
}

# ══════════════════════════════════════════════════
# v0.3 Priority-Based Truncation
# ══════════════════════════════════════════════════

# orch_prompt_truncate_to_budget <agent_id> <max_tokens>
#   Output prompt truncated to fit within max_tokens budget.
#   Keeps sections in priority order (dynamic first, then reference, then stable).
#   Skips deduplicated sections. Truncates last-included section if needed.
orch_prompt_truncate_to_budget() {
    local agent_id="${1:?orch_prompt_truncate_to_budget: agent_id required}"
    local max_tokens="${2:?orch_prompt_truncate_to_budget: max_tokens required}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"

    [[ "$sec_count" -eq 0 ]] && return 1

    # Ensure section tokens are computed
    local i
    for ((i = 0; i < sec_count; i++)); do
        if [[ -z "${_ORCH_PROMPT_SEC_TOKENS[$agent_id:$i]+x}" ]]; then
            local content="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
            _ORCH_PROMPT_SEC_TOKENS["$agent_id:$i"]=$(orch_prompt_count_tokens "$content")
        fi
        if [[ -z "${_ORCH_PROMPT_SEC_PRIORITY[$agent_id:$i]+x}" ]]; then
            local tier="${_ORCH_PROMPT_SEC_TIER[$agent_id:$i]}"
            _ORCH_PROMPT_SEC_PRIORITY["$agent_id:$i"]="${_ORCH_PROMPT_TIER_PRIORITY[$tier]:-5}"
        fi
    done

    # Build sorted index by priority (ascending = highest priority first)
    local -a sorted_indices=()
    sorted_indices=($(for ((i = 0; i < sec_count; i++)); do
        printf '%s %d\n' "${_ORCH_PROMPT_SEC_PRIORITY[$agent_id:$i]:-5}" "$i"
    done | sort -n -k1 | awk '{print $2}'))

    local budget_remaining="$max_tokens"
    local included=0

    for idx in "${sorted_indices[@]}"; do
        # Skip deduplicated sections
        [[ -n "${_ORCH_PROMPT_DEDUP_MAP[$agent_id:$idx]+x}" ]] && continue

        local tokens="${_ORCH_PROMPT_SEC_TOKENS[$agent_id:$idx]}"
        local content="${_ORCH_PROMPT_SECTIONS[$agent_id:$idx]}"

        if [[ "$tokens" -le "$budget_remaining" ]]; then
            printf '%s' "$content"
            budget_remaining=$((budget_remaining - tokens))
            included=$((included + 1))
        elif [[ "$budget_remaining" -gt 50 ]]; then
            # Truncate this section to fit remaining budget
            local max_chars=$(( budget_remaining * 4 ))  # ~4 chars per token
            local header="${_ORCH_PROMPT_SEC_HEADERS[$agent_id:$idx]}"
            printf '## %s\n' "$header"
            # Take first max_chars of content (after header)
            local body="${content#*$'\n'}"
            printf '%s\n' "${body:0:$max_chars}"
            printf '\n[...truncated to fit token budget]\n\n'
            budget_remaining=0
            included=$((included + 1))
            break
        else
            # Not enough budget for any meaningful content
            break
        fi
    done

    _orch_prompt_log INFO "Budget truncation for $agent_id: $included/$sec_count sections, ${budget_remaining} tokens remaining"
}

# orch_prompt_compress — updated to support "budget" mode (v0.3)
# Extended the existing function by adding budget mode handling
orch_prompt_compress() {
    local agent_id="${1:?orch_prompt_compress: agent_id required}"
    local mode="${2:-standard}"
    local sec_count="${_ORCH_PROMPT_SEC_COUNT[$agent_id]:-0}"

    if [[ "$sec_count" -eq 0 ]]; then
        _orch_prompt_log WARN "No sections classified for $agent_id — call orch_prompt_classify first"
        return 1
    fi

    # v0.3 budget mode delegates to truncation
    if [[ "$mode" == "budget" ]]; then
        local budget="${_ORCH_PROMPT_TOKEN_BUDGET}"
        [[ "$budget" -le 0 ]] && budget=10000  # default budget if not set
        orch_prompt_truncate_to_budget "$agent_id" "$budget"
        return $?
    fi

    local i
    for ((i = 0; i < sec_count; i++)); do
        local header="${_ORCH_PROMPT_SEC_HEADERS[$agent_id:$i]}"
        local content="${_ORCH_PROMPT_SECTIONS[$agent_id:$i]}"
        local tier="${_ORCH_PROMPT_SEC_TIER[$agent_id:$i]}"

        # v0.3: skip deduplicated sections in all modes except full
        if [[ "$mode" != "full" && -n "${_ORCH_PROMPT_DEDUP_MAP[$agent_id:$i]+x}" ]]; then
            continue
        fi

        case "$mode" in
            full)
                printf '%s' "$content"
                ;;
            standard)
                case "$tier" in
                    stable)
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
                        ;;
                esac
                ;;
        esac
    done
}
