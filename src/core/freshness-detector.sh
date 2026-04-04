#!/usr/bin/env bash
# freshness-detector.sh — Detect stale references in agent prompts
# v0.3.0: #167 — scan prompt files for outdated dates, closed issues,
# references to completed work. Outputs a staleness report.
# v0.4.0: git-blame age analysis, cross-reference validation (gh issues),
#          semantic drift detection (content divergence between cycles)
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
#   orch_freshness_git_blame   — analyze file age via git blame (v0.4)
#   orch_freshness_check_refs  — validate issue/PR references via gh (v0.4)
#   orch_freshness_drift       — detect semantic drift between versions (v0.4)

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

# ===========================================================================
# v0.4.0 — Git Blame Age, Cross-Reference Validation, Semantic Drift
# ===========================================================================

# ---------------------------------------------------------------------------
# orch_freshness_git_blame — analyze file staleness via git blame
#
# For each file, computes the average and max age of lines.
# Lines older than max_age_days are flagged.
#
# Args: $1 — file path (must be in a git repo)
# Returns: 0 on success, 1 if not in git repo or git blame fails
# ---------------------------------------------------------------------------
orch_freshness_git_blame() {
    local file="$1"

    [[ ! -f "$file" ]] && return 1

    # Check if git is available and file is in a repo
    if ! command -v git &>/dev/null; then
        _orch_freshness_log WARN "git not available for blame analysis"
        return 1
    fi

    local file_dir
    file_dir=$(dirname "$file")
    if ! git -C "$file_dir" rev-parse --git-dir &>/dev/null 2>&1; then
        _orch_freshness_log WARN "not a git repo: $file_dir"
        return 1
    fi

    if [[ "$_ORCH_FRESHNESS_INITED" != "true" ]]; then
        orch_freshness_init
    fi

    local today_epoch
    today_epoch=$(_orch_freshness_today_epoch)
    local threshold_epoch=$(( today_epoch - _ORCH_FRESHNESS_MAX_AGE_DAYS * 86400 ))

    # Get blame timestamps (epoch format)
    local blame_output
    blame_output=$(git -C "$file_dir" blame --porcelain "$(basename "$file")" 2>/dev/null) || return 1

    local -a timestamps=()
    local oldest_epoch=$today_epoch
    local oldest_line=""
    local line_count=0
    local stale_lines=0

    while IFS= read -r bline; do
        if [[ "$bline" =~ ^author-time[[:space:]]+([0-9]+) ]]; then
            local ts="${BASH_REMATCH[1]}"
            timestamps+=("$ts")
            line_count=$((line_count + 1))

            if [[ "$ts" -lt "$oldest_epoch" ]]; then
                oldest_epoch=$ts
            fi

            if [[ "$ts" -lt "$threshold_epoch" ]]; then
                stale_lines=$((stale_lines + 1))
            fi
        fi
    done <<< "$blame_output"

    if [[ $line_count -eq 0 ]]; then
        return 0
    fi

    local age_days=$(( (today_epoch - oldest_epoch) / 86400 ))
    local stale_pct=0
    [[ $line_count -gt 0 ]] && stale_pct=$(( stale_lines * 100 / line_count ))

    if [[ $stale_pct -gt 50 ]]; then
        _ORCH_FRESHNESS_FINDINGS+=("GIT_BLAME|${file}|0|${stale_pct}% of lines older than ${_ORCH_FRESHNESS_MAX_AGE_DAYS}d (oldest: ${age_days}d)")
    elif [[ $age_days -gt $((_ORCH_FRESHNESS_MAX_AGE_DAYS * 3)) ]]; then
        _ORCH_FRESHNESS_FINDINGS+=("GIT_BLAME|${file}|0|File has content ${age_days} days old (3x threshold)")
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_freshness_check_refs — validate GitHub issue/PR references via gh CLI
#
# Scans for #NNN references and checks if they are still open.
# Closed/merged issues referenced as active work are flagged.
#
# Args: $1 — file path, $2 — GitHub repo (owner/repo, optional)
# Returns: 0 on success, 1 if gh not available
# ---------------------------------------------------------------------------
orch_freshness_check_refs() {
    local file="$1"
    local repo="${2:-}"

    [[ ! -f "$file" ]] && return 1

    if ! command -v gh &>/dev/null; then
        _orch_freshness_log WARN "gh CLI not available for reference validation"
        return 1
    fi

    # Auto-detect repo from git remote if not provided
    if [[ -z "$repo" ]]; then
        local file_dir
        file_dir=$(dirname "$file")
        repo=$(git -C "$file_dir" remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]([^.]+)(\.git)?$|\1|' || true)
        if [[ -z "$repo" ]]; then
            _orch_freshness_log WARN "cannot detect GitHub repo for reference validation"
            return 1
        fi
    fi

    if [[ "$_ORCH_FRESHNESS_INITED" != "true" ]]; then
        orch_freshness_init
    fi

    local lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))

        # Find #NNN references (issue/PR numbers)
        local refs
        refs=$(echo "$line" | grep -oE '#[0-9]+' || true)

        for ref in $refs; do
            local num="${ref#\#}"
            [[ -z "$num" ]] && continue

            # Check issue state via gh (with timeout to avoid blocking)
            local state
            state=$(timeout 5 gh issue view "$num" --repo "$repo" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")

            if [[ "$state" == "CLOSED" ]]; then
                # Check if the line references it as active work
                if echo "$line" | grep -qiE '(TODO|WIP|in.progress|working.on|fix|implement|add)' 2>/dev/null; then
                    _ORCH_FRESHNESS_FINDINGS+=("CLOSED_REF|${file}|${lineno}|Issue ${ref} is CLOSED but referenced as active work")
                fi
            fi
        done
    done < "$file"

    return 0
}

# ---------------------------------------------------------------------------
# orch_freshness_drift — detect semantic drift between two versions of a file
#
# Compares current file content against a previous snapshot (or git HEAD~1).
# Flags significant structural changes that may indicate context drift.
#
# Drift signals:
#   - Section headings changed (## sections added/removed)
#   - Task list items changed by > 50%
#   - Key terms appeared/disappeared
#
# Args: $1 — current file, $2 — previous file (or "git" to use HEAD~1)
# Returns: 0 on success
# ---------------------------------------------------------------------------
orch_freshness_drift() {
    local current_file="$1"
    local previous="${2:-git}"

    [[ ! -f "$current_file" ]] && return 1

    if [[ "$_ORCH_FRESHNESS_INITED" != "true" ]]; then
        orch_freshness_init
    fi

    local prev_content=""

    if [[ "$previous" == "git" ]]; then
        local file_dir
        file_dir=$(dirname "$current_file")
        local rel_path
        rel_path=$(git -C "$file_dir" ls-files --full-name "$(basename "$current_file")" 2>/dev/null || true)

        if [[ -n "$rel_path" ]]; then
            prev_content=$(git -C "$file_dir" show "HEAD~1:${rel_path}" 2>/dev/null || true)
        fi
    elif [[ -f "$previous" ]]; then
        prev_content=$(cat "$previous")
    fi

    if [[ -z "$prev_content" ]]; then
        _orch_freshness_log WARN "no previous version available for drift detection"
        return 0
    fi

    local curr_content
    curr_content=$(cat "$current_file")

    # Compare section headings
    local curr_headings prev_headings
    curr_headings=$(echo "$curr_content" | grep -E '^##' | sort || true)
    prev_headings=$(echo "$prev_content" | grep -E '^##' | sort || true)

    local added_sections removed_sections
    added_sections=$(comm -23 <(echo "$curr_headings") <(echo "$prev_headings") 2>/dev/null | wc -l || echo 0)
    removed_sections=$(comm -13 <(echo "$curr_headings") <(echo "$prev_headings") 2>/dev/null | wc -l || echo 0)

    if [[ "$added_sections" -gt 2 || "$removed_sections" -gt 2 ]]; then
        _ORCH_FRESHNESS_FINDINGS+=("DRIFT_STRUCTURE|${current_file}|0|Structural drift: ${added_sections} sections added, ${removed_sections} removed")
    fi

    # Compare task counts
    local curr_tasks prev_tasks
    curr_tasks=$(echo "$curr_content" | grep -cE '^[[:space:]]*[-*][[:space:]]' || echo 0)
    prev_tasks=$(echo "$prev_content" | grep -cE '^[[:space:]]*[-*][[:space:]]' || echo 0)

    if [[ "$prev_tasks" -gt 0 ]]; then
        local task_change
        if [[ "$curr_tasks" -gt "$prev_tasks" ]]; then
            task_change=$(( (curr_tasks - prev_tasks) * 100 / prev_tasks ))
        else
            task_change=$(( (prev_tasks - curr_tasks) * 100 / prev_tasks ))
        fi

        if [[ "$task_change" -gt 50 ]]; then
            _ORCH_FRESHNESS_FINDINGS+=("DRIFT_TASKS|${current_file}|0|Task list changed by ${task_change}% (${prev_tasks} -> ${curr_tasks} items)")
        fi
    fi

    # Check for key term drift (important words disappearing)
    local -a key_terms=("BLOCKED" "CRITICAL" "P0" "URGENT" "DEADLINE" "BREAKING")
    for term in "${key_terms[@]}"; do
        local prev_count curr_count
        prev_count=$(echo "$prev_content" | grep -ci "$term" || echo 0)
        curr_count=$(echo "$curr_content" | grep -ci "$term" || echo 0)

        if [[ "$prev_count" -gt 0 && "$curr_count" -eq 0 ]]; then
            _ORCH_FRESHNESS_FINDINGS+=("DRIFT_TERM|${current_file}|0|Key term '${term}' disappeared (was in ${prev_count} lines)")
        fi
    done

    return 0
}
