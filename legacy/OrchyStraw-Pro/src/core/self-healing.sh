#!/usr/bin/env bash
# =============================================================================
# self-healing.sh — Auto-detect and fix common agent failures (#72)
#
# When an agent fails, this module analyzes the failure, classifies it, and
# applies automatic remediation before retrying. Designed to be conservative:
# only fixes things it's confident about, never modifies files outside an
# agent's ownership paths, and logs every action for PM/QA review.
#
# Failure classes:
#   rate-limit, timeout, context-overflow, permission, crash, git-conflict, unknown
#
# Usage:
#   source src/core/self-healing.sh
#
#   orch_heal_init 3 15
#   class=$(orch_heal_diagnose "06-backend" 1 "/path/to/log")
#   orch_heal_can_fix "$class" && orch_heal_apply "06-backend" "$class" "/project/root"
#   orch_heal_should_retry "06-backend" && echo "retry permitted"
#   orch_heal_record "06-backend" "$class" "waited 30s" "true"
#   orch_heal_history "06-backend"
#   orch_heal_report
#   orch_heal_stats
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_SELF_HEALING_LOADED:-}" ]] && return 0
readonly _ORCH_SELF_HEALING_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# Healing attempt tracking, keyed by "agent_id:field"
# Fields: count, last_class, last_action, last_time, last_success
declare -gA _ORCH_HEAL_ATTEMPTS=()

# Full audit trail — indexed array of "timestamp|agent_id|class|action|success"
declare -ga _ORCH_HEAL_HISTORY=()

# Configuration
declare -g _ORCH_HEAL_MAX_RETRIES=2
declare -g _ORCH_HEAL_COOLDOWN=10

# Recommended timeout overrides, keyed by agent_id
declare -gA _ORCH_HEAL_TIMEOUT_OVERRIDES=()

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_heal_log — info-level logging to stderr
_orch_heal_log() {
    printf '[self-healing] %s\n' "$*" >&2
}

# _orch_heal_err — error-level logging to stderr
_orch_heal_err() {
    printf '[self-healing] ERROR: %s\n' "$*" >&2
}

# _orch_heal_timestamp — current UTC timestamp
_orch_heal_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# _orch_heal_epoch — current epoch seconds
_orch_heal_epoch() {
    date +%s
}

# _orch_heal_get_ownership — look up an agent's owned paths from agents.conf
# Args: $1 — agent_id, $2 — project_root
# Outputs: space-separated list of ownership paths
_orch_heal_get_ownership() {
    local agent_id="$1"
    local project_root="$2"

    # Try both possible locations for agents.conf
    local conf_file=""
    if [[ -f "${project_root}/agents.conf" ]]; then
        conf_file="${project_root}/agents.conf"
    elif [[ -f "${project_root}/scripts/agents.conf" ]]; then
        conf_file="${project_root}/scripts/agents.conf"
    else
        return 1
    fi

    # Parse agents.conf: id | prompt_path | ownership | ...
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        local id
        id="$(echo "$line" | cut -d'|' -f1 | xargs)"
        if [[ "$id" == "$agent_id" ]]; then
            echo "$line" | cut -d'|' -f3 | xargs
            return 0
        fi
    done < "$conf_file"

    return 1
}

# _orch_heal_file_in_ownership — check if a file path is within agent ownership
# Args: $1 — file_path, $2 — ownership_paths (space-separated), $3 — project_root
# Returns: 0 if owned, 1 if not
_orch_heal_file_in_ownership() {
    local file_path="$1"
    local ownership="$2"
    local project_root="$3"

    local -a ownership_arr
    IFS=' ' read -ra ownership_arr <<< "$ownership"
    local path
    for path in "${ownership_arr[@]}"; do
        # Normalize: ensure trailing slash for directory comparison
        local abs_path="${project_root}/${path}"
        if [[ "$file_path" == "${abs_path}"* ]]; then
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# orch_heal_init [max_retries] [cooldown_secs]
#
# Initialize self-healing state. Resets all tracked attempts and history.
# Args:
#   $1 — max retries per agent (default: 2)
#   $2 — cooldown seconds between retries (default: 10)
# ---------------------------------------------------------------------------
orch_heal_init() {
    _ORCH_HEAL_MAX_RETRIES="${1:-2}"
    _ORCH_HEAL_COOLDOWN="${2:-10}"
    _ORCH_HEAL_ATTEMPTS=()
    _ORCH_HEAL_HISTORY=()
    _ORCH_HEAL_TIMEOUT_OVERRIDES=()

    _orch_heal_log "Initialized: max_retries=${_ORCH_HEAL_MAX_RETRIES}, cooldown=${_ORCH_HEAL_COOLDOWN}s"
}

# ---------------------------------------------------------------------------
# orch_heal_diagnose <agent_id> <exit_code> <log_file>
#
# Analyze a failure and classify it. Scans the last 50 lines of the log file
# for known failure patterns. Classification priority matches the order below
# (first match wins).
#
# Args:
#   $1 — agent_id
#   $2 — exit code from the agent process
#   $3 — path to agent log file
#
# Outputs: failure class to stdout
# Returns: 0 always (classification always succeeds, defaulting to "unknown")
# ---------------------------------------------------------------------------
orch_heal_diagnose() {
    local agent_id="${1:?orch_heal_diagnose: agent_id required}"
    local exit_code="${2:?orch_heal_diagnose: exit_code required}"
    local log_file="${3:-}"

    # Capture last 50 lines of log for analysis
    local log_tail=""
    if [[ -n "$log_file" && -r "$log_file" ]]; then
        log_tail="$(tail -n 50 "$log_file" 2>/dev/null || true)"
    fi

    # --- Crash detection (by exit code alone, check first) ---
    case "$exit_code" in
        134) # SIGABRT
            _orch_heal_log "Diagnosed ${agent_id}: crash (SIGABRT, exit 134)"
            echo "crash"
            return 0
            ;;
        139) # SIGSEGV
            _orch_heal_log "Diagnosed ${agent_id}: crash (SIGSEGV, exit 139)"
            echo "crash"
            return 0
            ;;
        137) # SIGKILL
            _orch_heal_log "Diagnosed ${agent_id}: crash (SIGKILL, exit 137)"
            echo "crash"
            return 0
            ;;
    esac

    # --- Timeout detection (exit code 124 or log keywords) ---
    if [[ "$exit_code" == "124" ]]; then
        _orch_heal_log "Diagnosed ${agent_id}: timeout (exit code 124)"
        echo "timeout"
        return 0
    fi

    if [[ -n "$log_tail" ]]; then
        # --- Rate limit ---
        if echo "$log_tail" | grep -qiE 'rate.?limit|rate_limit|429|Too Many Requests|quota exceeded'; then
            _orch_heal_log "Diagnosed ${agent_id}: rate-limit"
            echo "rate-limit"
            return 0
        fi

        # --- Timeout (log keywords) ---
        if echo "$log_tail" | grep -qiE 'timed out|timeout|SIGALRM'; then
            _orch_heal_log "Diagnosed ${agent_id}: timeout (log keywords)"
            echo "timeout"
            return 0
        fi

        # --- Context overflow ---
        if echo "$log_tail" | grep -qiE 'context.?length|token.?limit|maximum.?context|too long|context_length_exceeded'; then
            _orch_heal_log "Diagnosed ${agent_id}: context-overflow"
            echo "context-overflow"
            return 0
        fi

        # --- Permission ---
        if echo "$log_tail" | grep -qE 'permission denied|Permission denied|EACCES|EPERM'; then
            _orch_heal_log "Diagnosed ${agent_id}: permission"
            echo "permission"
            return 0
        fi

        # --- Git conflict ---
        if echo "$log_tail" | grep -qE 'CONFLICT|merge conflict|Merge conflict|unmerged'; then
            _orch_heal_log "Diagnosed ${agent_id}: git-conflict"
            echo "git-conflict"
            return 0
        fi
    fi

    _orch_heal_log "Diagnosed ${agent_id}: unknown (exit_code=${exit_code})"
    echo "unknown"
    return 0
}

# ---------------------------------------------------------------------------
# orch_heal_can_fix <failure_class>
#
# Returns 0 if self-healing can attempt a fix for this failure class.
# Returns 1 if the failure requires manual investigation.
# ---------------------------------------------------------------------------
orch_heal_can_fix() {
    local failure_class="${1:?orch_heal_can_fix: failure_class required}"

    case "$failure_class" in
        rate-limit|timeout|context-overflow|permission|git-conflict)
            return 0
            ;;
        crash|unknown|*)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# orch_heal_apply <agent_id> <failure_class> <project_root>
#
# Apply the remediation for the given failure class.
# Returns 0 if remediation was applied, 1 if not applicable.
#
# Remediations:
#   rate-limit:       exponential backoff wait (10s * 2^attempts, max 300s)
#   timeout:          store increased timeout recommendation (+50%)
#   context-overflow: write compress flag for prompt-compression module
#   permission:       chmod u+rw on owned files missing write permission
#   git-conflict:     git checkout --theirs on conflicting files in ownership
#   crash/unknown:    log diagnostic, recommend manual investigation
# ---------------------------------------------------------------------------
orch_heal_apply() {
    local agent_id="${1:?orch_heal_apply: agent_id required}"
    local failure_class="${2:?orch_heal_apply: failure_class required}"
    local project_root="${3:?orch_heal_apply: project_root required}"

    local attempt_count="${_ORCH_HEAL_ATTEMPTS["${agent_id}:count"]:-0}"

    case "$failure_class" in

        rate-limit)
            # Exponential backoff: 10 * 2^attempt_count, capped at 300s
            local backoff=$(( 10 * (1 << attempt_count) ))
            if (( backoff > 300 )); then
                backoff=300
            fi
            _orch_heal_log "${agent_id}: rate-limit — waiting ${backoff}s (attempt ${attempt_count})"
            sleep "$backoff"
            _orch_heal_log "${agent_id}: rate-limit — backoff complete"
            return 0
            ;;

        timeout)
            # Get current timeout (from overrides or default 300s)
            local current_timeout="${_ORCH_HEAL_TIMEOUT_OVERRIDES["${agent_id}"]:-300}"
            # Increase by 50%
            local new_timeout=$(( current_timeout + current_timeout / 2 ))
            _ORCH_HEAL_TIMEOUT_OVERRIDES["${agent_id}"]="$new_timeout"
            _orch_heal_log "${agent_id}: timeout — recommend increasing timeout from ${current_timeout}s to ${new_timeout}s"
            return 0
            ;;

        context-overflow)
            # Write flag file for prompt-compression module
            local heal_dir="${project_root}/.orchystraw"
            if [[ ! -d "$heal_dir" ]]; then
                mkdir -p "$heal_dir" 2>/dev/null || {
                    _orch_heal_err "${agent_id}: cannot create ${heal_dir}"
                    return 1
                }
            fi
            local flag_file="${heal_dir}/heal-compress-${agent_id}"
            printf 'minimal\n' > "$flag_file"
            _orch_heal_log "${agent_id}: context-overflow — wrote compress flag to ${flag_file}"
            _orch_heal_log "${agent_id}: context-overflow — prompt will be compressed to 'minimal' tier on next run"
            return 0
            ;;

        permission)
            # Look up agent ownership paths
            local ownership
            ownership="$(_orch_heal_get_ownership "$agent_id" "$project_root")" || {
                _orch_heal_err "${agent_id}: cannot determine ownership paths"
                return 1
            }

            local fixed_count=0
            local -a ownership_arr
            IFS=' ' read -ra ownership_arr <<< "$ownership"
            local path
            for path in "${ownership_arr[@]}"; do
                local abs_path="${project_root}/${path}"
                [[ -e "$abs_path" ]] || continue

                # Find files without user write permission within owned paths
                while IFS= read -r file; do
                    [[ -z "$file" ]] && continue
                    chmod u+rw "$file" 2>/dev/null && {
                        _orch_heal_log "${agent_id}: permission — fixed: ${file}"
                        (( fixed_count++ ))
                    }
                done < <(find "$abs_path" -not -perm -u+w -type f 2>/dev/null)
            done

            _orch_heal_log "${agent_id}: permission — fixed ${fixed_count} file(s)"
            return 0
            ;;

        git-conflict)
            # Look up agent ownership paths
            local ownership
            ownership="$(_orch_heal_get_ownership "$agent_id" "$project_root")" || {
                _orch_heal_err "${agent_id}: cannot determine ownership paths"
                return 1
            }

            _orch_heal_log "WARNING: ${agent_id}: git-conflict — applying --theirs on owned conflicting files"
            _orch_heal_log "WARNING: This will discard the agent's local changes in favor of incoming changes"

            # Find unmerged files
            local resolved_count=0
            local conflict_file
            while IFS= read -r conflict_file; do
                [[ -z "$conflict_file" ]] && continue

                # Only touch files within agent's ownership
                if _orch_heal_file_in_ownership "${project_root}/${conflict_file}" "$ownership" "$project_root"; then
                    if git -C "$project_root" checkout --theirs -- "$conflict_file" 2>/dev/null; then
                        git -C "$project_root" add -- "$conflict_file" 2>/dev/null
                        _orch_heal_log "${agent_id}: git-conflict — resolved (--theirs): ${conflict_file}"
                        (( resolved_count++ ))
                    else
                        _orch_heal_err "${agent_id}: git-conflict — failed to resolve: ${conflict_file}"
                    fi
                else
                    _orch_heal_log "${agent_id}: git-conflict — skipped (not owned): ${conflict_file}"
                fi
            done < <(git -C "$project_root" diff --name-only --diff-filter=U 2>/dev/null)

            _orch_heal_log "${agent_id}: git-conflict — resolved ${resolved_count} file(s)"
            return 0
            ;;

        crash)
            _orch_heal_log "${agent_id}: crash — no auto-fix available"
            _orch_heal_log "${agent_id}: crash — recommend manual investigation (check for OOM, segfaults, signal handlers)"
            return 1
            ;;

        unknown|*)
            _orch_heal_log "${agent_id}: unknown failure — no auto-fix available"
            _orch_heal_log "${agent_id}: unknown — recommend manual investigation"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# orch_heal_should_retry <agent_id>
#
# Returns 0 if the agent should be retried:
#   - Within retry budget (attempt count < max_retries)
#   - Cooldown has elapsed since last attempt
# Returns 1 if retries exhausted or cooldown not elapsed.
# ---------------------------------------------------------------------------
orch_heal_should_retry() {
    local agent_id="${1:?orch_heal_should_retry: agent_id required}"

    local attempt_count="${_ORCH_HEAL_ATTEMPTS["${agent_id}:count"]:-0}"

    # Check retry budget
    if (( attempt_count >= _ORCH_HEAL_MAX_RETRIES )); then
        _orch_heal_log "${agent_id}: retries exhausted (${attempt_count}/${_ORCH_HEAL_MAX_RETRIES})"
        return 1
    fi

    # Check cooldown
    local last_time="${_ORCH_HEAL_ATTEMPTS["${agent_id}:last_time"]:-}"
    if [[ -n "$last_time" ]]; then
        local now
        now="$(_orch_heal_epoch)"
        local last_epoch
        # Convert ISO timestamp to epoch — handle both GNU and BSD date
        last_epoch="$(date -d "$last_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_time" +%s 2>/dev/null || echo 0)"
        local elapsed=$(( now - last_epoch ))

        if (( elapsed < _ORCH_HEAL_COOLDOWN )); then
            _orch_heal_log "${agent_id}: cooldown not elapsed (${elapsed}s < ${_ORCH_HEAL_COOLDOWN}s)"
            return 1
        fi
    fi

    _orch_heal_log "${agent_id}: retry permitted (${attempt_count}/${_ORCH_HEAL_MAX_RETRIES}, cooldown OK)"
    return 0
}

# ---------------------------------------------------------------------------
# orch_heal_record <agent_id> <failure_class> <action_taken> <success>
#
# Record a healing attempt for audit trail and state tracking.
# Args:
#   $1 — agent_id
#   $2 — failure class
#   $3 — description of action taken
#   $4 — "true" or "false"
# ---------------------------------------------------------------------------
orch_heal_record() {
    local agent_id="${1:?orch_heal_record: agent_id required}"
    local failure_class="${2:?orch_heal_record: failure_class required}"
    local action_taken="${3:?orch_heal_record: action_taken required}"
    local success="${4:?orch_heal_record: success required}"

    local timestamp
    timestamp="$(_orch_heal_timestamp)"

    # Update attempt state
    local current_count="${_ORCH_HEAL_ATTEMPTS["${agent_id}:count"]:-0}"
    (( current_count++ )) || true
    _ORCH_HEAL_ATTEMPTS["${agent_id}:count"]="$current_count"
    _ORCH_HEAL_ATTEMPTS["${agent_id}:last_class"]="$failure_class"
    _ORCH_HEAL_ATTEMPTS["${agent_id}:last_action"]="$action_taken"
    _ORCH_HEAL_ATTEMPTS["${agent_id}:last_time"]="$timestamp"
    _ORCH_HEAL_ATTEMPTS["${agent_id}:last_success"]="$success"

    # Append to audit trail
    _ORCH_HEAL_HISTORY+=("${timestamp}|${agent_id}|${failure_class}|${action_taken}|${success}")

    _orch_heal_log "Recorded: agent=${agent_id} class=${failure_class} action='${action_taken}' success=${success}"
}

# ---------------------------------------------------------------------------
# orch_heal_history <agent_id>
#
# Print the healing history for an agent (all recorded attempts).
# Args: $1 — agent_id
# ---------------------------------------------------------------------------
orch_heal_history() {
    local agent_id="${1:?orch_heal_history: agent_id required}"

    local sep="────────────────────────────────────────"
    printf '%s\n' "$sep"
    printf 'Healing History — %s\n' "$agent_id"
    printf '%s\n' "$sep"

    local found=0
    local entry
    for entry in "${_ORCH_HEAL_HISTORY[@]}"; do
        # Format: timestamp|agent_id|class|action|success
        local entry_agent
        entry_agent="$(echo "$entry" | cut -d'|' -f2)"

        if [[ "$entry_agent" == "$agent_id" ]]; then
            local ts action class outcome
            ts="$(echo "$entry" | cut -d'|' -f1)"
            class="$(echo "$entry" | cut -d'|' -f3)"
            action="$(echo "$entry" | cut -d'|' -f4)"
            outcome="$(echo "$entry" | cut -d'|' -f5)"

            printf '  [%s] class=%-18s action=%-30s outcome=%s\n' \
                "$ts" "$class" "$action" "$outcome"
            found=1
        fi
    done

    if (( found == 0 )); then
        printf '  No healing history recorded.\n'
    fi

    printf '%s\n' "$sep"
}

# ---------------------------------------------------------------------------
# orch_heal_report
#
# Print a summary report of all healing activity this cycle.
# Shows: agent, failure class, action taken, outcome.
# ---------------------------------------------------------------------------
orch_heal_report() {
    local sep="════════════════════════════════════════════════════════════════"
    printf '\n%s\n' "$sep"
    printf 'SELF-HEALING REPORT\n'
    printf 'Generated: %s\n' "$(_orch_heal_timestamp)"
    printf '%s\n\n' "$sep"

    if (( ${#_ORCH_HEAL_HISTORY[@]} == 0 )); then
        printf 'No healing activity this cycle.\n'
        printf '%s\n\n' "$sep"
        return 0
    fi

    printf '%-14s %-18s %-30s %s\n' "AGENT" "CLASS" "ACTION" "OUTCOME"
    printf '%-14s %-18s %-30s %s\n' "─────" "─────" "──────" "───────"

    local entry
    for entry in "${_ORCH_HEAL_HISTORY[@]}"; do
        local ts agent class action outcome
        ts="$(echo "$entry" | cut -d'|' -f1)"
        agent="$(echo "$entry" | cut -d'|' -f2)"
        class="$(echo "$entry" | cut -d'|' -f3)"
        action="$(echo "$entry" | cut -d'|' -f4)"
        outcome="$(echo "$entry" | cut -d'|' -f5)"

        printf '%-14s %-18s %-30s %s\n' "$agent" "$class" "$action" "$outcome"
    done

    printf '\n%s\n\n' "$sep"
}

# ---------------------------------------------------------------------------
# orch_heal_stats
#
# Print aggregate stats: total failures, auto-fixed count, manual-needed count.
# ---------------------------------------------------------------------------
orch_heal_stats() {
    local total=0
    local auto_fixed=0
    local manual_needed=0

    local entry
    for entry in "${_ORCH_HEAL_HISTORY[@]}"; do
        (( total++ ))

        local outcome
        outcome="$(echo "$entry" | cut -d'|' -f5)"
        if [[ "$outcome" == "true" ]]; then
            (( auto_fixed++ ))
        else
            (( manual_needed++ ))
        fi
    done

    printf 'Self-Healing Stats\n'
    printf '  Total failures:   %d\n' "$total"
    printf '  Auto-fixed:       %d\n' "$auto_fixed"
    printf '  Manual needed:    %d\n' "$manual_needed"

    if (( total > 0 )); then
        local pct=$(( auto_fixed * 100 / total ))
        printf '  Auto-fix rate:    %d%%\n' "$pct"
    fi
}
