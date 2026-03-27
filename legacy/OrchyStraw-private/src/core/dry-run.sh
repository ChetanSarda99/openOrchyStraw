#!/usr/bin/env bash
# src/core/dry-run.sh — Sourceable dry-run mode library for OrchyStraw
#
# Usage:
#   source src/core/dry-run.sh
#   orch_dry_run_init "$@"
#
# Conf format: AGENT_ID | PROMPT_FILE | FILE_OWNERSHIP | CYCLE_INTERVAL | LABEL
# Lines beginning with # are comments; blank lines are ignored.

# ── Guard: prevent double-sourcing ─────────────────────────────────────────────
[[ -n "${_ORCH_DRY_RUN_LOADED:-}" ]] && return 0
readonly _ORCH_DRY_RUN_LOADED=1

# Internal state — 0 = not in dry-run, 1 = dry-run active
_ORCH_DRY_RUN=0

# ── orch_dry_run_init ──────────────────────────────────────────────────────────
# Inspect the environment variable ORCH_DRY_RUN and the argument list passed
# to this function (forward "$@" from the caller's argument list).
# Sets _ORCH_DRY_RUN=1 when either signal is present.
#
# Usage:  orch_dry_run_init "$@"
orch_dry_run_init() {
    # Environment variable takes precedence
    if [[ "${ORCH_DRY_RUN:-0}" == "1" ]]; then
        _ORCH_DRY_RUN=1
        return 0
    fi

    # Scan caller's arguments for --dry-run
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            _ORCH_DRY_RUN=1
            return 0
        fi
    done

    _ORCH_DRY_RUN=0
    return 0
}

# ── orch_is_dry_run ────────────────────────────────────────────────────────────
# Returns 0 (true) when dry-run mode is active, 1 (false) otherwise.
# Designed for idiomatic shell conditionals:
#
#   if orch_is_dry_run; then ...
orch_is_dry_run() {
    [[ "${_ORCH_DRY_RUN}" == "1" ]]
}

# ── orch_dry_exec ──────────────────────────────────────────────────────────────
# If dry-run is active: print what would happen and return 0 without executing.
# If dry-run is inactive: execute the supplied command.
#
# Usage:  orch_dry_exec "human-readable description" cmd arg1 arg2 ...
orch_dry_exec() {
    local description="$1"
    shift

    if orch_is_dry_run; then
        printf '[DRY RUN] Would: %s\n' "$description"
        return 0
    fi

    "$@"
}

# ── _orch_drr_parse_conf (internal) ───────────────────────────────────────────
# Parse agents.conf and emit colon-delimited records:
#   id:prompt_file:ownership:interval:label
# Comment lines (# ...) and blank lines are silently skipped.
_orch_drr_parse_conf() {
    local conf_file="$1"
    local line id prompt_path ownership interval label

    while IFS= read -r line; do
        # Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip comments and blank lines
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

        # Split on | — tolerate variable whitespace around the delimiter
        IFS='|' read -r id prompt_path ownership interval label <<< "$line"

        # Trim each field
        id="${id#"${id%%[![:space:]]*}"}"; id="${id%"${id##*[![:space:]]}"}"
        prompt_path="${prompt_path#"${prompt_path%%[![:space:]]*}"}"; prompt_path="${prompt_path%"${prompt_path##*[![:space:]]}"}"
        ownership="${ownership#"${ownership%%[![:space:]]*}"}"; ownership="${ownership%"${ownership##*[![:space:]]}"}"
        interval="${interval#"${interval%%[![:space:]]*}"}"; interval="${interval%"${interval##*[![:space:]]}"}"
        label="${label#"${label%%[![:space:]]*}"}"; label="${label%"${label##*[![:space:]]}"}"

        printf '%s:%s:%s:%s:%s\n' "$id" "$prompt_path" "$ownership" "$interval" "$label"
    done < "$conf_file"
}

# ── _orch_drr_agent_runs (internal) ───────────────────────────────────────────
# Returns 0 when an agent should run on the given cycle number.
# Interval semantics:
#   0  — coordinator (runs LAST, treated as "always runs" in the report)
#   1  — every cycle
#   N  — every Nth cycle (when cycle_num % N == 0, or cycle_num == 1)
_orch_drr_agent_runs() {
    local interval="$1"
    local cycle_num="$2"

    # Coordinator always included in report
    [[ "$interval" == "0" ]] && return 0
    # Every cycle
    [[ "$interval" == "1" ]] && return 0
    # Every Nth: first cycle always runs; thereafter when divisible
    if (( cycle_num == 1 )) || (( cycle_num % interval == 0 )); then
        return 0
    fi
    return 1
}

# ── orch_dry_run_report ────────────────────────────────────────────────────────
# Parse <conf_file> and print a formatted preview of what would happen on
# cycle <cycle_num>.
#
# Usage:  orch_dry_run_report <conf_file> <cycle_num>
orch_dry_run_report() {
    local conf_file="$1"
    local cycle_num="${2:-1}"

    # Validate inputs
    if [[ ! -f "$conf_file" ]]; then
        printf '[DRY RUN] ERROR: conf file not found: %s\n' "$conf_file" >&2
        return 1
    fi
    if ! [[ "$cycle_num" =~ ^[0-9]+$ ]]; then
        printf '[DRY RUN] ERROR: cycle_num must be a non-negative integer, got: %s\n' "$cycle_num" >&2
        return 1
    fi

    # Collect agents that would run this cycle (coordinators go last)
    local -a regular_agents=()
    local -a coordinator_agents=()
    local record id prompt_path ownership interval label

    while IFS= read -r record; do
        IFS=':' read -r id prompt_path ownership interval label <<< "$record"
        if _orch_drr_agent_runs "$interval" "$cycle_num"; then
            if [[ "$interval" == "0" ]]; then
                coordinator_agents+=("$record")
            else
                regular_agents+=("$record")
            fi
        fi
    done < <(_orch_drr_parse_conf "$conf_file")

    local all_agents=("${regular_agents[@]}" "${coordinator_agents[@]}")

    # ── Header ──────────────────────────────────────────────────────────────
    printf '\n'
    printf '╔══════════════════════════════════════════════════════════════════════════════╗\n'
    printf '║  [DRY RUN] OrchyStraw — Cycle %-3s Preview                                  ║\n' "$cycle_num"
    printf '║  Conf: %-70s║\n' "$conf_file"
    printf '╚══════════════════════════════════════════════════════════════════════════════╝\n'
    printf '\n'

    if [[ ${#all_agents[@]} -eq 0 ]]; then
        printf '  No agents scheduled for cycle %s.\n\n' "$cycle_num"
        return 0
    fi

    # ── Column widths ────────────────────────────────────────────────────────
    local col_id=14
    local col_interval=8
    local col_exists=6
    local col_lines=6
    local col_ok=4
    local col_label=30

    local sep_line
    sep_line=$(printf '  +%-*s+%-*s+%-*s+%-*s+%-*s+%-*s+\n' \
        $((col_id+2))    "$(printf '%0.s-' $(seq 1 $((col_id+2))))" \
        $((col_interval+2)) "$(printf '%0.s-' $(seq 1 $((col_interval+2))))" \
        $((col_exists+2)) "$(printf '%0.s-' $(seq 1 $((col_exists+2))))" \
        $((col_lines+2)) "$(printf '%0.s-' $(seq 1 $((col_lines+2))))" \
        $((col_ok+2))    "$(printf '%0.s-' $(seq 1 $((col_ok+2))))" \
        $((col_label+2)) "$(printf '%0.s-' $(seq 1 $((col_label+2))))")

    printf '%s' "$sep_line"
    printf '  | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n' \
        $col_id       "AGENT ID" \
        $col_interval "INTERVAL" \
        $col_exists   "EXISTS" \
        $col_lines    "LINES" \
        $col_ok       "OK?" \
        $col_label    "LABEL"
    printf '%s' "$sep_line"

    # ── Per-agent rows ───────────────────────────────────────────────────────
    local -a parallel_groups=()
    local current_group_size=0
    local group_num=1
    local group_size_limit=4   # assume up to 4 agents run in parallel

    local exists_str lines_str ok_str interval_label
    for record in "${all_agents[@]}"; do
        IFS=':' read -r id prompt_path ownership interval label <<< "$record"

        # Prompt file existence
        if [[ -f "$prompt_path" ]]; then
            exists_str="yes"
            local line_count
            line_count=$(wc -l < "$prompt_path" 2>/dev/null || printf '0')
            lines_str="$line_count"
            if (( line_count > 30 )); then
                ok_str="YES"
            else
                ok_str="low"
            fi
        else
            exists_str="NO"
            lines_str="-"
            ok_str="MISS"
        fi

        # Human-readable interval
        case "$interval" in
            0) interval_label="last"    ;;
            1) interval_label="every"   ;;
            *) interval_label="every ${interval}" ;;
        esac

        printf '  | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n' \
            $col_id       "$id" \
            $col_interval "$interval_label" \
            $col_exists   "$exists_str" \
            $col_lines    "$lines_str" \
            $col_ok       "$ok_str" \
            $col_label    "$label"

        # Track for parallel group estimation
        (( current_group_size++ ))
        if (( current_group_size >= group_size_limit )); then
            parallel_groups+=("Group $group_num (${current_group_size} agents)")
            (( group_num++ ))
            current_group_size=0
        fi
    done

    # Flush remaining agents into last group
    if (( current_group_size > 0 )); then
        parallel_groups+=("Group $group_num (${current_group_size} agents)")
    fi

    printf '%s' "$sep_line"

    # ── Summary ──────────────────────────────────────────────────────────────
    printf '\n'
    printf '  Agents scheduled : %d\n' "${#all_agents[@]}"
    printf '  Regular workers  : %d\n' "${#regular_agents[@]}"
    printf '  Coordinators     : %d  (run LAST)\n' "${#coordinator_agents[@]}"
    printf '\n'
    printf '  Estimated parallel groups (max %d agents each):\n' "$group_size_limit"
    local g
    for g in "${parallel_groups[@]}"; do
        printf '    %s\n' "$g"
    done

    # ── Ownership preview ────────────────────────────────────────────────────
    printf '\n'
    printf '  File ownership paths:\n'
    for record in "${all_agents[@]}"; do
        IFS=':' read -r id prompt_path ownership interval label <<< "$record"
        printf '    %-14s  %s\n' "$id" "$ownership"
    done

    printf '\n'
    printf '  Nothing was executed. Pass --dry-run to preview; omit it to run.\n'
    printf '\n'
}
