#!/usr/bin/env bash
# session-tracker.sh — Smart session tracker windowing for token optimization
# v0.3.0: #52 — compress cross-cycle history based on age
#
# SESSION_TRACKER.txt grows ~40 lines per cycle. At cycle 50+, injecting the
# full history wastes thousands of tokens on cycles agents don't need.
#
# Windowing policy:
#   recent    — Last N cycles: full "WHAT SHIPPED" detail (~40-50 lines each)
#   summary   — Next M cycles: table row only (1 line each)
#   milestone — Older cycles: omitted entirely (milestones preserved separately)
#
# Always preserved (not subject to windowing):
#   MILESTONE DASHBOARD, CODEBASE SIZE, NEXT CYCLE PRIORITIES
#
# Target: ~80 lines output regardless of project age.
#
# Provides:
#   orch_tracker_init      — configure windowing parameters
#   orch_tracker_window    — read tracker file, output windowed content
#   orch_tracker_stats     — print compression statistics

[[ -n "${_ORCH_TRACKER_LOADED:-}" ]] && return 0
_ORCH_TRACKER_LOADED=1

# ── State ──
declare -g _ORCH_TRACKER_RECENT=2       # cycles with full detail
declare -g _ORCH_TRACKER_SUMMARY=8      # cycles with table-row summaries
declare -g _ORCH_TRACKER_INITIALIZED=false

# Parsed data
declare -g -a _ORCH_TRACKER_TABLE_ROWS=()    # cycle table rows (index = cycle number)
declare -g -A _ORCH_TRACKER_SHIPPED=()       # cycle_num -> full "WHAT SHIPPED" block
declare -g _ORCH_TRACKER_TABLE_HEADER=""      # table header + separator lines
declare -g _ORCH_TRACKER_PREAMBLE=""          # content before the table
declare -g _ORCH_TRACKER_PRESERVED=""         # MILESTONE DASHBOARD + CODEBASE SIZE + NEXT CYCLE PRIORITIES
declare -g _ORCH_TRACKER_MAX_CYCLE=-1         # highest cycle number found
declare -g _ORCH_TRACKER_ORIG_LINES=0         # original line count
declare -g _ORCH_TRACKER_WINDOWED_LINES=0     # windowed line count

# ── Helpers ──

_orch_tracker_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "session-tracker" "$2"
    fi
}

_orch_tracker_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Count newlines in a string
_orch_tracker_line_count() {
    local text="$1"
    [[ -z "$text" ]] && { printf '0'; return; }
    local count=0
    while IFS= read -r _; do
        count=$((count + 1))
    done <<< "$text"
    printf '%d' "$count"
}

# ── Public API ──

# orch_tracker_init [recent_full] [summary_count]
#   Configure windowing parameters.
#   recent_full:   number of most recent cycles to keep in full detail (default: 2)
#   summary_count: number of cycles after recent to keep as table rows (default: 8)
#   Cycles older than recent+summary are omitted (milestones preserved separately).
orch_tracker_init() {
    local recent="${1:-2}"
    local summary="${2:-8}"

    if [[ "$recent" =~ ^[0-9]+$ ]]; then
        _ORCH_TRACKER_RECENT="$recent"
    else
        _orch_tracker_log WARN "Non-numeric recent_full '$recent', defaulting to 2"
        _ORCH_TRACKER_RECENT=2
    fi

    if [[ "$summary" =~ ^[0-9]+$ ]]; then
        _ORCH_TRACKER_SUMMARY="$summary"
    else
        _orch_tracker_log WARN "Non-numeric summary_count '$summary', defaulting to 8"
        _ORCH_TRACKER_SUMMARY=8
    fi

    # Reset parsed state
    _ORCH_TRACKER_TABLE_ROWS=()
    _ORCH_TRACKER_SHIPPED=()
    _ORCH_TRACKER_TABLE_HEADER=""
    _ORCH_TRACKER_PREAMBLE=""
    _ORCH_TRACKER_PRESERVED=""
    _ORCH_TRACKER_MAX_CYCLE=-1
    _ORCH_TRACKER_ORIG_LINES=0
    _ORCH_TRACKER_WINDOWED_LINES=0

    _ORCH_TRACKER_INITIALIZED=true
    _orch_tracker_log INFO "Session tracker initialized (recent=$_ORCH_TRACKER_RECENT, summary=$_ORCH_TRACKER_SUMMARY)"
    return 0
}

# orch_tracker_window <tracker_file>
#   Read SESSION_TRACKER.txt, apply windowing, output compressed content.
#   Returns 1 if file not found or not initialized.
orch_tracker_window() {
    local tracker_file="${1:?orch_tracker_window: tracker_file required}"

    if [[ "$_ORCH_TRACKER_INITIALIZED" != "true" ]]; then
        _orch_tracker_log ERROR "Not initialized — call orch_tracker_init first"
        return 1
    fi

    if [[ ! -f "$tracker_file" ]]; then
        _orch_tracker_log ERROR "Tracker file not found: $tracker_file"
        return 1
    fi

    # Count original lines
    _ORCH_TRACKER_ORIG_LINES=$(wc -l < "$tracker_file")

    # Reset parsed state
    _ORCH_TRACKER_TABLE_ROWS=()
    _ORCH_TRACKER_SHIPPED=()
    _ORCH_TRACKER_TABLE_HEADER=""
    _ORCH_TRACKER_PREAMBLE=""
    _ORCH_TRACKER_PRESERVED=""
    _ORCH_TRACKER_MAX_CYCLE=-1

    # ── Phase 1: Parse the tracker file ──
    _orch_tracker_parse "$tracker_file" || return 1

    # ── Phase 2: Build windowed output ──
    local output=""

    # Preamble (title + comments)
    if [[ -n "$_ORCH_TRACKER_PREAMBLE" ]]; then
        output+="$_ORCH_TRACKER_PREAMBLE"
    fi

    # Table header
    if [[ -n "$_ORCH_TRACKER_TABLE_HEADER" ]]; then
        output+="$_ORCH_TRACKER_TABLE_HEADER"
    fi

    # Determine cycle boundaries
    local max="$_ORCH_TRACKER_MAX_CYCLE"
    local recent_cutoff=$((max - _ORCH_TRACKER_RECENT + 1))
    local summary_cutoff=$((recent_cutoff - _ORCH_TRACKER_SUMMARY))

    [[ "$recent_cutoff" -lt 0 ]] && recent_cutoff=0
    [[ "$summary_cutoff" -lt 0 ]] && summary_cutoff=0

    # Table rows: summary-range cycles only (recent cycles get full WHAT SHIPPED instead)
    local c
    for ((c = summary_cutoff; c < recent_cutoff; c++)); do
        if [[ -n "${_ORCH_TRACKER_TABLE_ROWS[$c]:-}" ]]; then
            output+="${_ORCH_TRACKER_TABLE_ROWS[$c]}"$'\n'
        fi
    done

    # Recent table rows too (for the summary table)
    for ((c = recent_cutoff; c <= max; c++)); do
        if [[ -n "${_ORCH_TRACKER_TABLE_ROWS[$c]:-}" ]]; then
            output+="${_ORCH_TRACKER_TABLE_ROWS[$c]}"$'\n'
        fi
    done

    output+=$'\n---\n\n'

    # Full "WHAT SHIPPED" blocks for recent cycles (newest first)
    for ((c = max; c >= recent_cutoff && c >= 0; c--)); do
        if [[ -n "${_ORCH_TRACKER_SHIPPED[$c]:-}" ]]; then
            output+="${_ORCH_TRACKER_SHIPPED[$c]}"
        fi
    done

    # Preserved sections (milestone dashboard, codebase size, priorities)
    if [[ -n "$_ORCH_TRACKER_PRESERVED" ]]; then
        output+="$_ORCH_TRACKER_PRESERVED"
    fi

    # Count windowed lines
    _ORCH_TRACKER_WINDOWED_LINES=$(_orch_tracker_line_count "$output")

    printf '%s' "$output"
    _orch_tracker_log INFO "Windowed: $_ORCH_TRACKER_ORIG_LINES → $_ORCH_TRACKER_WINDOWED_LINES lines (cycles $summary_cutoff-$((recent_cutoff - 1)) summarized, <$summary_cutoff omitted)"
    return 0
}

# orch_tracker_stats
#   Print compression statistics from the last orch_tracker_window call.
orch_tracker_stats() {
    if [[ "$_ORCH_TRACKER_ORIG_LINES" -eq 0 ]]; then
        printf 'No tracker data — call orch_tracker_window first.\n'
        return 1
    fi

    local savings_pct=0
    if [[ "$_ORCH_TRACKER_ORIG_LINES" -gt 0 ]]; then
        local saved=$((_ORCH_TRACKER_ORIG_LINES - _ORCH_TRACKER_WINDOWED_LINES))
        savings_pct=$((saved * 100 / _ORCH_TRACKER_ORIG_LINES))
    fi

    local max="$_ORCH_TRACKER_MAX_CYCLE"
    local recent_cutoff=$((max - _ORCH_TRACKER_RECENT + 1))
    local summary_cutoff=$((recent_cutoff - _ORCH_TRACKER_SUMMARY))
    [[ "$recent_cutoff" -lt 0 ]] && recent_cutoff=0
    [[ "$summary_cutoff" -lt 0 ]] && summary_cutoff=0

    printf 'session-tracker windowing stats:\n'
    printf '  total cycles:  %d (0–%d)\n' "$((_ORCH_TRACKER_MAX_CYCLE + 1))" "$_ORCH_TRACKER_MAX_CYCLE"
    printf '  full detail:   cycles %d–%d (%d cycles)\n' "$recent_cutoff" "$max" "$_ORCH_TRACKER_RECENT"
    printf '  summary rows:  cycles %d–%d (%d cycles)\n' "$summary_cutoff" "$((recent_cutoff - 1))" "$_ORCH_TRACKER_SUMMARY"
    printf '  omitted:       cycles 0–%d\n' "$((summary_cutoff - 1))"
    printf '  original:      %d lines\n' "$_ORCH_TRACKER_ORIG_LINES"
    printf '  windowed:      %d lines\n' "$_ORCH_TRACKER_WINDOWED_LINES"
    printf '  savings:       %d%%\n' "$savings_pct"
}

# ── Internal: Parse tracker file ──

_orch_tracker_parse() {
    local tracker_file="$1"

    local preamble=""
    local table_header=""
    local in_table=false
    local in_shipped=false
    local in_preserved=false
    local current_shipped=""
    local current_cycle=-1
    local preserved=""

    # Preserved section names (matched case-insensitively)
    local -a preserved_sections=("MILESTONE DASHBOARD" "CODEBASE SIZE" "NEXT CYCLE PRIORITIES")

    while IFS= read -r line; do
        # Check for preserved ## sections
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            local header="${BASH_REMATCH[1]}"

            # Flush current shipped block
            if [[ "$in_shipped" == true && "$current_cycle" -ge 0 && -n "$current_shipped" ]]; then
                _ORCH_TRACKER_SHIPPED["$current_cycle"]="$current_shipped"
                current_shipped=""
                current_cycle=-1
                in_shipped=false
            fi

            # Check if this is a preserved section
            local is_preserved=false
            for psec in "${preserved_sections[@]}"; do
                if [[ "${header^^}" == *"${psec^^}"* ]]; then
                    is_preserved=true
                    break
                fi
            done

            if [[ "$is_preserved" == true ]]; then
                # Flush any in-progress preserved content
                in_preserved=true
                in_shipped=false
                preserved+="$line"$'\n'
                continue
            fi

            # Check for "WHAT SHIPPED — Cycle N" pattern
            if [[ "$header" =~ WHAT[[:space:]]+SHIPPED.*[Cc]ycle[[:space:]]+([0-9]+) ]]; then
                in_preserved=false
                in_shipped=true
                current_cycle="${BASH_REMATCH[1]}"
                current_shipped="$line"$'\n'
                if [[ "$current_cycle" -gt "$_ORCH_TRACKER_MAX_CYCLE" ]]; then
                    _ORCH_TRACKER_MAX_CYCLE="$current_cycle"
                fi
                continue
            fi

            # Check for "Cycle Log" header (part of preamble)
            if [[ "$header" == "Cycle Log" ]]; then
                preamble+="$line"$'\n'
                continue
            fi

            # Other ## headers — if we're in preserved mode, keep collecting
            if [[ "$in_preserved" == true ]]; then
                preserved+="$line"$'\n'
                continue
            fi

            # Unknown section — treat as preamble if before table, otherwise skip
            if [[ "$in_table" == false ]]; then
                preamble+="$line"$'\n'
            fi
            continue
        fi

        # Collect preserved section content
        if [[ "$in_preserved" == true ]]; then
            # Stop on --- (section boundary) unless it's just a table separator
            if [[ "$line" =~ ^---$ ]]; then
                preserved+="$line"$'\n'
                # Don't stop collecting — preserved sections may span multiple subsections
                continue
            fi
            preserved+="$line"$'\n'
            continue
        fi

        # Collect WHAT SHIPPED content
        if [[ "$in_shipped" == true ]]; then
            if [[ "$line" =~ ^---$ ]]; then
                # End of shipped block
                current_shipped+="$line"$'\n'$'\n'
                _ORCH_TRACKER_SHIPPED["$current_cycle"]="$current_shipped"
                current_shipped=""
                current_cycle=-1
                in_shipped=false
                continue
            fi
            current_shipped+="$line"$'\n'
            continue
        fi

        # Table detection: look for | Cycle | pattern
        if [[ "$line" =~ ^\|[[:space:]]*Cycle ]]; then
            in_table=true
            table_header+="$line"$'\n'
            continue
        fi

        # Table separator: |----
        if [[ "$in_table" == true && "$line" =~ ^\|[-]+\| ]]; then
            table_header+="$line"$'\n'
            continue
        fi

        # Table data rows: | <number> |
        if [[ "$in_table" == true && "$line" =~ ^\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
            local row_cycle="${BASH_REMATCH[1]}"
            _ORCH_TRACKER_TABLE_ROWS["$row_cycle"]="$line"
            if [[ "$row_cycle" -gt "$_ORCH_TRACKER_MAX_CYCLE" ]]; then
                _ORCH_TRACKER_MAX_CYCLE="$row_cycle"
            fi
            continue
        fi

        # Empty line after table ends the table section
        if [[ "$in_table" == true && -z "$(_orch_tracker_trim "$line")" ]]; then
            in_table=false
            continue
        fi

        # --- separator outside shipped/preserved — skip
        if [[ "$line" =~ ^---$ ]]; then
            continue
        fi

        # Preamble content (before table)
        if [[ "$in_table" == false && "$in_shipped" == false ]]; then
            preamble+="$line"$'\n'
        fi
    done < "$tracker_file"

    # Flush final shipped block
    if [[ "$in_shipped" == true && "$current_cycle" -ge 0 && -n "$current_shipped" ]]; then
        _ORCH_TRACKER_SHIPPED["$current_cycle"]="$current_shipped"
    fi

    _ORCH_TRACKER_TABLE_HEADER="$table_header"
    _ORCH_TRACKER_PREAMBLE="$preamble"
    _ORCH_TRACKER_PRESERVED="$preserved"

    _orch_tracker_log INFO "Parsed tracker: max_cycle=$_ORCH_TRACKER_MAX_CYCLE, ${#_ORCH_TRACKER_SHIPPED[@]} shipped blocks, ${#_ORCH_TRACKER_TABLE_ROWS[@]} table rows"
    return 0
}
