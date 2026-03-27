#!/usr/bin/env bash
# =============================================================================
# session-windower.sh — Smart session tracker windowing for OrchyStraw (#36)
#
# Keeps the session tracker (SESSION_TRACKER.txt) from growing unbounded.
# Applies a sliding window: keeps the N most recent cycles in full detail,
# compresses older cycles into a one-line summary.
#
# Usage:
#   source src/core/session-windower.sh
#
#   orch_window_session_tracker "/path/to/SESSION_TRACKER.txt" 5
#   # Keeps last 5 cycles in full, compresses older ones
#
#   orch_estimate_tracker_tokens "/path/to/SESSION_TRACKER.txt"
#   # Returns approximate token count (chars / 4)
#
# Requires: bash 4.2+ (declare -g)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_SESSION_WINDOWER_LOADED:-}" ]] && return 0
readonly _ORCH_SESSION_WINDOWER_LOADED=1

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
declare -g _ORCH_WINDOW_SIZE="${ORCH_TRACKER_WINDOW:-5}"
declare -g _ORCH_MAX_TRACKER_TOKENS="${ORCH_MAX_TRACKER_TOKENS:-8000}"

# ---------------------------------------------------------------------------
# orch_estimate_tracker_tokens — rough token estimate for a file
#
# Uses chars/4 as a rough approximation (GPT/Claude tokenizers average ~4
# chars per token for English text with markdown).
#
# Args: $1 — file path
# Returns: estimated token count
# ---------------------------------------------------------------------------
orch_estimate_tracker_tokens() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo 0; return; }

    local chars
    chars=$(wc -c < "$file" 2>/dev/null || echo 0)
    echo $(( chars / 4 ))
}

# ---------------------------------------------------------------------------
# orch_count_cycle_sections — count "WHAT SHIPPED" sections in tracker
#
# Args: $1 — file path
# Returns: number of cycle sections found
# ---------------------------------------------------------------------------
orch_count_cycle_sections() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo 0; return; }

    grep -c "^## WHAT SHIPPED" "$file" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# orch_window_session_tracker — apply sliding window to tracker
#
# Keeps the last N cycles in full detail. Older cycles are compressed to
# a single summary line each, grouped under "## Compressed History".
#
# Args:
#   $1 — path to SESSION_TRACKER.txt
#   $2 — window size (optional, default _ORCH_WINDOW_SIZE)
#
# Modifies the file in place. Creates a .bak backup first.
# ---------------------------------------------------------------------------
orch_window_session_tracker() {
    local tracker_file="$1"
    local window="${2:-$_ORCH_WINDOW_SIZE}"

    [[ ! -f "$tracker_file" ]] && return 1

    local section_count
    section_count=$(orch_count_cycle_sections "$tracker_file")

    # Nothing to compress if within window
    if [[ $section_count -le $window ]]; then
        return 0
    fi

    local sections_to_compress=$(( section_count - window ))

    # Backup
    cp "$tracker_file" "${tracker_file}.bak" 2>/dev/null

    # Parse the file: extract headers and sections
    local -a compressed_lines=()
    local -a kept_lines=()
    local current_section=""
    local section_idx=0
    local in_section=false
    local header_done=false
    local -a header_lines=()
    local line cycle_label agent_summary

    while IFS= read -r line; do
        # Detect cycle section headers
        if [[ "$line" =~ ^##[[:space:]]+WHAT[[:space:]]+SHIPPED.*Cycle[[:space:]]+([0-9]+) ]]; then
            # Save previous compressed section if we were in one
            if [[ "$in_section" == "true" ]] && [[ -n "$cycle_label" ]]; then
                compressed_lines+=("- Cycle $cycle_label: $agent_summary")
            fi

            section_idx=$((section_idx + 1))
            cycle_label="${BASH_REMATCH[1]}"
            header_done=true

            if [[ $section_idx -le $sections_to_compress ]]; then
                # This section will be compressed — start collecting
                in_section=true
                current_section=""
                agent_summary=""
            else
                # Keep this section in full
                in_section=false
                kept_lines+=("$line")
            fi
            continue
        fi

        # Before any "WHAT SHIPPED" section, collect header lines
        if [[ "$header_done" == "false" ]]; then
            header_lines+=("$line")
            continue
        fi

        if [[ "$in_section" == "true" ]]; then
            # We're in a section that needs compressing
            # Detect agent sub-headers to build summary
            if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
                [[ -n "$agent_summary" ]] && agent_summary+=", "
                agent_summary+="${BASH_REMATCH[1]}"
            fi
            # Check for next major section (not a cycle section)
            if [[ "$line" =~ ^##[[:space:]] ]] && ! [[ "$line" =~ WHAT[[:space:]]+SHIPPED ]]; then
                # End of cycle section, hit a non-cycle header
                # Save compressed line
                compressed_lines+=("- Cycle $cycle_label: $agent_summary")
                in_section=false
                kept_lines+=("$line")
            fi
        else
            kept_lines+=("$line")
        fi
    done < "$tracker_file"

    # If we ended while still in a compressed section, save it
    if [[ "$in_section" == "true" ]]; then
        compressed_lines+=("- Cycle $cycle_label: $agent_summary")
    fi

    # Reconstruct the file
    {
        # Header lines (milestone dashboard, etc.)
        for line in "${header_lines[@]}"; do
            echo "$line"
        done

        # Compressed history section (if any)
        if [[ ${#compressed_lines[@]} -gt 0 ]]; then
            echo ""
            echo "## Compressed History (cycles 1-$sections_to_compress)"
            echo ""
            for line in "${compressed_lines[@]}"; do
                echo "$line"
            done
            echo ""
            echo "---"
            echo ""
        fi

        # Recent cycles in full
        for line in "${kept_lines[@]}"; do
            echo "$line"
        done
    } > "$tracker_file"
}

# ---------------------------------------------------------------------------
# orch_should_window — check if tracker exceeds token budget
#
# Returns 0 (true) if windowing is recommended
# ---------------------------------------------------------------------------
orch_should_window() {
    local tracker_file="$1"
    local tokens
    tokens=$(orch_estimate_tracker_tokens "$tracker_file")
    [[ $tokens -gt $_ORCH_MAX_TRACKER_TOKENS ]]
}

# ---------------------------------------------------------------------------
# orch_auto_window — window only if needed (exceeds token budget)
#
# Args:
#   $1 — tracker file path
#   $2 — window size (optional)
# ---------------------------------------------------------------------------
orch_auto_window() {
    local tracker_file="$1"
    local window="${2:-$_ORCH_WINDOW_SIZE}"

    if orch_should_window "$tracker_file"; then
        orch_window_session_tracker "$tracker_file" "$window"
        return 0
    fi
    return 1
}
