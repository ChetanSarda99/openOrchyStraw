#!/usr/bin/env bash
# freshness-detector.sh — Detect stale references in agent prompts
# v0.3.0: #167 — scan prompt files for outdated dates, closed issues,
# references to completed work. Outputs a staleness report.
#
# Prevents the exact problem that caused cycles to go stagnant: agents
# operating on outdated context from prior cycles.
#
# Provides:
#   orch_freshness_init        — configure scan parameters
#   orch_freshness_scan        — scan a file or directory, populate findings
#   orch_freshness_report      — output staleness report to stdout
#   orch_freshness_stale_count — return count of stale references found
#   orch_freshness_check       — quick pass/fail: 0 if fresh, 1 if stale

[[ -n "${_ORCH_FRESHNESS_LOADED:-}" ]] && return 0
_ORCH_FRESHNESS_LOADED=1

# ── State ──
declare -g -i _ORCH_FRESHNESS_MAX_AGE_DAYS=7
declare -g _ORCH_FRESHNESS_TODAY=""
declare -g -a _ORCH_FRESHNESS_FINDINGS=()
declare -g -i _ORCH_FRESHNESS_SCANNED=0
declare -g _ORCH_FRESHNESS_INITED=false

# ── Helpers ──

_orch_freshness_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "freshness" "$2"
    fi
}

_orch_freshness_date_to_epoch() {
    local datestr="$1"
    if date -d "$datestr" '+%s' 2>/dev/null; then
        return 0
    fi
    if date -j -f '%Y-%m-%d' "$datestr" '+%s' 2>/dev/null; then
        return 0
    fi
    echo "0"
}

_orch_freshness_today_epoch() {
    if [[ -n "$_ORCH_FRESHNESS_TODAY" ]]; then
        _orch_freshness_date_to_epoch "$_ORCH_FRESHNESS_TODAY"
    else
        date '+%s'
    fi
}

# ── Public API ──

orch_freshness_init() {
    local max_age="${1:-7}"
    local today="${2:-}"

    if [[ "$max_age" =~ ^[0-9]+$ ]] && [[ "$max_age" -gt 0 ]]; then
        _ORCH_FRESHNESS_MAX_AGE_DAYS=$max_age
    else
        _ORCH_FRESHNESS_MAX_AGE_DAYS=7
    fi

    _ORCH_FRESHNESS_TODAY="$today"
    _ORCH_FRESHNESS_FINDINGS=()
    _ORCH_FRESHNESS_SCANNED=0
    _ORCH_FRESHNESS_INITED=true
    _orch_freshness_log INFO "initialized: max_age=${_ORCH_FRESHNESS_MAX_AGE_DAYS}d"
}

orch_freshness_scan() {
    local target="$1"

    if [[ ! -e "$target" ]]; then
        _orch_freshness_log WARN "target not found: $target"
        return 1
    fi

    if [[ "$_ORCH_FRESHNESS_INITED" != "true" ]]; then
        orch_freshness_init
    fi

    local files=()
    if [[ -d "$target" ]]; then
        while IFS= read -r f; do
            [[ -n "$f" ]] && files+=("$f")
        done < <(find "$target" -name '*.md' -o -name '*.txt' 2>/dev/null)
    elif [[ -f "$target" ]]; then
        files+=("$target")
    fi

    local today_epoch
    today_epoch=$(_orch_freshness_today_epoch)
    local threshold_epoch=$(( today_epoch - _ORCH_FRESHNESS_MAX_AGE_DAYS * 86400 ))

    for file in "${files[@]}"; do
        _ORCH_FRESHNESS_SCANNED=$(( _ORCH_FRESHNESS_SCANNED + 1 ))

        local lineno=0
        while IFS= read -r line; do
            lineno=$(( lineno + 1 ))

            # Check for YYYY-MM-DD dates
            local dates
            dates=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
            for d in $dates; do
                local d_epoch
                d_epoch=$(_orch_freshness_date_to_epoch "$d")
                if [[ "$d_epoch" -gt 0 && "$d_epoch" -lt "$threshold_epoch" ]]; then
                    _ORCH_FRESHNESS_FINDINGS+=("STALE_DATE|${file}|${lineno}|Date $d is older than ${_ORCH_FRESHNESS_MAX_AGE_DAYS} days")
                fi
            done

            # Check for "DONE" or "FIXED" or "SHIPPED" or "completed" markers
            # that reference specific items — these may be outdated context
            if echo "$line" | grep -qiE '(✅|DONE|FIXED|SHIPPED|completed|CLOSED)' 2>/dev/null; then
                if echo "$line" | grep -qiE '(task|bug|issue|ticket|#[0-9])' 2>/dev/null; then
                    _ORCH_FRESHNESS_FINDINGS+=("COMPLETED_REF|${file}|${lineno}|Completed work reference may be stale")
                fi
            fi

            # Check for "BLOCKED" or "WAITING" that may have been resolved
            if echo "$line" | grep -qiE '^[[:space:]]*(- )?\*?\*?BLOCKED' 2>/dev/null; then
                _ORCH_FRESHNESS_FINDINGS+=("STALE_BLOCKER|${file}|${lineno}|Blocker reference — verify still active")
            fi

            # Check for cycle references (e.g., "cycle 3", "Cycle 5")
            if echo "$line" | grep -qiE 'cycle [0-9]+' 2>/dev/null; then
                local cycle_num
                cycle_num=$(echo "$line" | grep -oiE 'cycle [0-9]+' | head -1 | grep -oE '[0-9]+')
                if [[ -n "$cycle_num" && "$cycle_num" =~ ^[0-9]+$ ]]; then
                    _ORCH_FRESHNESS_FINDINGS+=("CYCLE_REF|${file}|${lineno}|References cycle ${cycle_num} — may be outdated")
                fi
            fi

        done < "$file"
    done

    return 0
}

orch_freshness_report() {
    local count=${#_ORCH_FRESHNESS_FINDINGS[@]}

    printf '# Freshness Report\n'
    printf '> Scanned: %d files | Max age: %d days | Findings: %d\n\n' \
        "$_ORCH_FRESHNESS_SCANNED" "$_ORCH_FRESHNESS_MAX_AGE_DAYS" "$count"

    if [[ $count -eq 0 ]]; then
        printf 'All references appear fresh.\n'
        return 0
    fi

    printf '| Type | File | Line | Detail |\n'
    printf '|------|------|------|--------|\n'

    for finding in "${_ORCH_FRESHNESS_FINDINGS[@]}"; do
        local type file line detail
        IFS='|' read -r type file line detail <<< "$finding"
        local basename
        basename=$(basename "$file")
        printf '| %s | %s | %s | %s |\n' "$type" "$basename" "$line" "$detail"
    done
}

orch_freshness_stale_count() {
    echo "${#_ORCH_FRESHNESS_FINDINGS[@]}"
}

orch_freshness_check() {
    if [[ ${#_ORCH_FRESHNESS_FINDINGS[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}
