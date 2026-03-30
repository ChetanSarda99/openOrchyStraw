#!/usr/bin/env bash
# conditional-activation.sh — Skip agents with no actual work
# v0.2.0: #48 — check owned-path changes, context mentions, PM force flags
#
# Complements the dynamic router (interval-based scheduling) with work-based
# activation. Even if an agent is interval-eligible, skip it if:
#   - No files changed in its owned paths since last run
#   - No mentions/requests for it in shared context
#   - No PM force flag set
#
# This avoids wasting API tokens on agents that will produce empty cycles.
#
# Provides:
#   orch_activation_init           — parse ownership from agents.conf
#   orch_activation_check          — should this agent run? (0=yes, 1=skip)
#   orch_activation_reason         — human-readable reason for last decision
#   orch_activation_set_changed    — feed changed-files list for a cycle
#   orch_activation_set_context    — feed shared context content for mention scan
#   orch_activation_stats          — print activation summary for all agents

[[ -n "${_ORCH_CONDITIONAL_ACTIVATION_LOADED:-}" ]] && return 0
_ORCH_CONDITIONAL_ACTIVATION_LOADED=1

# ── State ──
declare -g -A _ORCH_ACTIVATION_OWNERSHIP=()   # agent_id -> "path1 path2 !excluded"
declare -g -A _ORCH_ACTIVATION_REASON=()       # agent_id -> last decision reason
declare -g -A _ORCH_ACTIVATION_DECISION=()     # agent_id -> "run" | "skip"
declare -g -a _ORCH_ACTIVATION_AGENTS=()       # ordered agent list
declare -g _ORCH_ACTIVATION_CHANGED_FILES=""   # newline-separated changed files
declare -g _ORCH_ACTIVATION_CONTEXT=""         # shared context content for mention scan
declare -g _ORCH_ACTIVATION_LOADED=false

# Patterns that indicate a request/need for an agent in shared context
declare -g -a _ORCH_ACTIVATION_MENTION_PATTERNS=(
    "NEED:.*%s"
    "BLOCKED.*%s"
    "waiting.*%s"
    "needs.*%s"
    "%s.*should"
    "%s.*must"
    "assign.*%s"
)

# ── Helpers ──

_orch_activation_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "activation" "$2"
    fi
}

_orch_activation_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Check if any changed file matches an ownership path
_orch_activation_has_owned_changes() {
    local agent_id="$1"
    local ownership="${_ORCH_ACTIVATION_OWNERSHIP[$agent_id]:-}"

    [[ -z "$ownership" || "$ownership" == "none" ]] && return 1
    [[ -z "$_ORCH_ACTIVATION_CHANGED_FILES" ]] && return 1

    # Parse include/exclude paths
    local -a includes=()
    local -a excludes=()
    IFS=' ' read -ra paths <<< "$ownership"
    for path in "${paths[@]}"; do
        if [[ "$path" == !* ]]; then
            excludes+=("${path#!}")
        else
            includes+=("$path")
        fi
    done

    [[ ${#includes[@]} -eq 0 ]] && return 1

    # Check each changed file against ownership
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local matched=false
        for inc in "${includes[@]}"; do
            if [[ "$file" == ${inc}* ]]; then
                matched=true
                break
            fi
        done

        [[ "$matched" == false ]] && continue

        # Check excludes
        local excluded=false
        for exc in "${excludes[@]}"; do
            if [[ "$file" == ${exc}* ]]; then
                excluded=true
                break
            fi
        done

        if [[ "$excluded" == false ]]; then
            return 0  # Found a matching changed file
        fi
    done <<< "$_ORCH_ACTIVATION_CHANGED_FILES"

    return 1
}

# Check if shared context mentions this agent
_orch_activation_has_context_mention() {
    local agent_id="$1"

    [[ -z "$_ORCH_ACTIVATION_CONTEXT" ]] && return 1

    # Direct agent ID mention
    if [[ "$_ORCH_ACTIVATION_CONTEXT" == *"$agent_id"* ]]; then
        return 0
    fi

    # Extract label from agent ID (e.g., "06-backend" -> "backend", "09-qa" -> "qa")
    local label="${agent_id#*-}"
    if [[ -n "$label" && "$_ORCH_ACTIVATION_CONTEXT" == *"$label"* ]]; then
        # Verify it's a meaningful mention (not just a substring of another word)
        # Use case-insensitive word boundary check
        local context_lower="${_ORCH_ACTIVATION_CONTEXT,,}"
        local label_lower="${label,,}"
        if [[ "$context_lower" =~ (need|block|wait|assign|must|should).*$label_lower ]] || \
           [[ "$context_lower" =~ $label_lower.*(need|block|wait|assign|must|should) ]]; then
            return 0
        fi
    fi

    return 1
}

# ── Public API ──

# orch_activation_init <conf_file>
#   Parse agents.conf to extract agent IDs and ownership paths.
orch_activation_init() {
    local conf_file="${1:?orch_activation_init: conf_file required}"

    if [[ ! -f "$conf_file" ]]; then
        _orch_activation_log ERROR "Config file not found: $conf_file"
        return 1
    fi

    _ORCH_ACTIVATION_AGENTS=()
    _ORCH_ACTIVATION_OWNERSHIP=()
    _ORCH_ACTIVATION_REASON=()
    _ORCH_ACTIVATION_DECISION=()

    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed
        trimmed=$(_orch_activation_trim "$raw_line")
        [[ "$trimmed" == \#* ]] && continue

        IFS='|' read -r f_id f_prompt f_ownership f_interval f_label _ <<< "$raw_line"

        f_id=$(_orch_activation_trim "$f_id")
        f_ownership=$(_orch_activation_trim "$f_ownership")
        f_interval=$(_orch_activation_trim "$f_interval")

        [[ -z "$f_id" ]] && continue

        # Skip coordinator (interval=0)
        [[ "$f_interval" == "0" ]] && continue

        _ORCH_ACTIVATION_AGENTS+=("$f_id")
        _ORCH_ACTIVATION_OWNERSHIP["$f_id"]="$f_ownership"
    done < "$conf_file"

    _ORCH_ACTIVATION_LOADED=true
    _orch_activation_log INFO "Activation initialized with ${#_ORCH_ACTIVATION_AGENTS[@]} agents"
    return 0
}

# orch_activation_set_changed <changed_files>
#   Feed the list of changed files (newline-separated) for this cycle.
#   Typically from: git diff --name-only HEAD~N + git ls-files --others
orch_activation_set_changed() {
    _ORCH_ACTIVATION_CHANGED_FILES="${1:-}"
}

# orch_activation_set_context <context_content>
#   Feed the shared context content for mention scanning.
orch_activation_set_context() {
    _ORCH_ACTIVATION_CONTEXT="${1:-}"
}

# orch_activation_check <agent_id> [force_flag]
#   Decide whether an agent should run.
#   force_flag: "1" to force run (PM override). Default "0".
#   Returns 0 = should run, 1 = should skip.
orch_activation_check() {
    local agent_id="${1:?orch_activation_check: agent_id required}"
    local force_flag="${2:-0}"

    [[ "$_ORCH_ACTIVATION_LOADED" != "true" ]] && {
        _orch_activation_log ERROR "Not initialized — call orch_activation_init first"
        return 0  # Fail-open: run if not initialized
    }

    # PM force override — always run
    if [[ "$force_flag" == "1" ]]; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="PM force flag set"
        _orch_activation_log INFO "$agent_id: ACTIVATED (PM force)"
        return 0
    fi

    # Check 1: owned files changed
    if _orch_activation_has_owned_changes "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Changed files in owned paths"
        _orch_activation_log INFO "$agent_id: ACTIVATED (owned files changed)"
        return 0
    fi

    # Check 2: mentioned in shared context
    if _orch_activation_has_context_mention "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Mentioned in shared context"
        _orch_activation_log INFO "$agent_id: ACTIVATED (context mention)"
        return 0
    fi

    # No work detected — skip
    _ORCH_ACTIVATION_DECISION["$agent_id"]="skip"
    _ORCH_ACTIVATION_REASON["$agent_id"]="No changes in owned paths, no context mentions"
    _orch_activation_log INFO "$agent_id: SKIPPED (no work detected)"
    return 1
}

# orch_activation_reason <agent_id>
#   Print the human-readable reason for the last activation decision.
orch_activation_reason() {
    local agent_id="${1:?orch_activation_reason: agent_id required}"
    printf '%s\n' "${_ORCH_ACTIVATION_REASON[$agent_id]:-no decision yet}"
}

# orch_activation_stats
#   Print activation summary for all agents.
orch_activation_stats() {
    [[ "$_ORCH_ACTIVATION_LOADED" != "true" ]] && return 1

    local run_count=0
    local skip_count=0

    printf 'conditional-activation summary (%d agents):\n' "${#_ORCH_ACTIVATION_AGENTS[@]}"
    printf '%-14s %-6s %s\n' "AGENT" "RESULT" "REASON"

    for id in "${_ORCH_ACTIVATION_AGENTS[@]}"; do
        local decision="${_ORCH_ACTIVATION_DECISION[$id]:-pending}"
        local reason="${_ORCH_ACTIVATION_REASON[$id]:-not checked}"

        printf '%-14s %-6s %s\n' "$id" "$decision" "$reason"

        case "$decision" in
            run)  run_count=$((run_count + 1)) ;;
            skip) skip_count=$((skip_count + 1)) ;;
        esac
    done

    printf 'totals: %d run, %d skip\n' "$run_count" "$skip_count"
}
