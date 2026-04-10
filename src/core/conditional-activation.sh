#!/usr/bin/env bash
# conditional-activation.sh — Skip agents with no actual work
# v0.3.0: #48 — check owned-path changes, context mentions, PM force flags
#         v0.3 adds: dependency graph activation, event-driven triggers,
#         cooldown periods, activation history tracking
#
# Complements the dynamic router (interval-based scheduling) with work-based
# activation. Even if an agent is interval-eligible, skip it if:
#   - No files changed in its owned paths since last run
#   - No mentions/requests for it in shared context
#   - No PM force flag set
#   - No dependency activated (v0.3)
#   - No event trigger fired (v0.3)
#   - Agent is in cooldown period (v0.3)
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
#   orch_activation_add_trigger    — register an event-driven trigger (v0.3)
#   orch_activation_fire_event     — fire a named event (v0.3)
#   orch_activation_set_cooldown   — set cooldown period for agent (v0.3)
#   orch_activation_set_deps       — set dependency agents (v0.3)
#   orch_activation_dep_activated  — check if any dependency was activated (v0.3)

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

# v0.3 Dependency graph state
declare -g -A _ORCH_ACTIVATION_DEPS=()         # agent_id -> "dep1 dep2" (space-separated)

# v0.3 Event-driven triggers: "event_name" -> "agent1 agent2" (space-separated)
declare -g -A _ORCH_ACTIVATION_TRIGGERS=()
# Fired events for this cycle
declare -g -A _ORCH_ACTIVATION_FIRED_EVENTS=() # event_name -> 1

# v0.3 Cooldown state
declare -g -A _ORCH_ACTIVATION_COOLDOWN_UNTIL=()  # agent_id -> epoch timestamp when cooldown ends
declare -g -A _ORCH_ACTIVATION_COOLDOWN_SECS=()   # agent_id -> cooldown duration in seconds

# v0.3 Activation history
declare -g -A _ORCH_ACTIVATION_HISTORY_COUNT=()    # agent_id -> total activation count
declare -g -A _ORCH_ACTIVATION_LAST_ACTIVATED=()   # agent_id -> cycle number of last activation

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
    _ORCH_ACTIVATION_DEPS=()
    _ORCH_ACTIVATION_FIRED_EVENTS=()
    _ORCH_ACTIVATION_HISTORY_COUNT=()
    _ORCH_ACTIVATION_LAST_ACTIVATED=()
    _ORCH_ACTIVATION_ISSUES_CHECKED=false
    _ORCH_ACTIVATION_HAS_ISSUES=false

    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed
        trimmed=$(_orch_activation_trim "$raw_line")
        [[ "$trimmed" == \#* ]] && continue

        IFS='|' read -r f_id f_prompt f_ownership f_interval f_label f_priority f_deps _ <<< "$raw_line"

        f_id=$(_orch_activation_trim "$f_id")
        f_ownership=$(_orch_activation_trim "$f_ownership")
        f_interval=$(_orch_activation_trim "$f_interval")
        f_deps=$(_orch_activation_trim "${f_deps:-}")

        [[ -z "$f_id" ]] && continue

        # Skip coordinator (interval=0)
        [[ "$f_interval" == "0" ]] && continue

        _ORCH_ACTIVATION_AGENTS+=("$f_id")
        _ORCH_ACTIVATION_OWNERSHIP["$f_id"]="$f_ownership"

        # v0.3: parse dependencies
        if [[ -n "$f_deps" && "$f_deps" != "none" ]]; then
            _ORCH_ACTIVATION_DEPS["$f_id"]="${f_deps//,/ }"
        fi
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

    # v0.3: Check cooldown first — if in cooldown, skip unless forced
    if [[ "$force_flag" != "1" ]]; then
        local cooldown_until="${_ORCH_ACTIVATION_COOLDOWN_UNTIL[$agent_id]:-0}"
        if [[ "$cooldown_until" -gt 0 ]]; then
            local now
            now=$(date +%s)
            if [[ "$now" -lt "$cooldown_until" ]]; then
                local remaining=$(( cooldown_until - now ))
                _ORCH_ACTIVATION_DECISION["$agent_id"]="skip"
                _ORCH_ACTIVATION_REASON["$agent_id"]="In cooldown (${remaining}s remaining)"
                _orch_activation_log INFO "$agent_id: SKIPPED (cooldown, ${remaining}s left)"
                return 1
            fi
        fi
    fi

    # PM force override — always run
    if [[ "$force_flag" == "1" ]]; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="PM force flag set"
        _orch_activation_log INFO "$agent_id: ACTIVATED (PM force)"
        _orch_activation_record_activation "$agent_id"
        return 0
    fi

    # Check 1: owned files changed
    if _orch_activation_has_owned_changes "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Changed files in owned paths"
        _orch_activation_log INFO "$agent_id: ACTIVATED (owned files changed)"
        _orch_activation_record_activation "$agent_id"
        return 0
    fi

    # Check 2: mentioned in shared context
    if _orch_activation_has_context_mention "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Mentioned in shared context"
        _orch_activation_log INFO "$agent_id: ACTIVATED (context mention)"
        _orch_activation_record_activation "$agent_id"
        return 0
    fi

    # v0.3 Check 3: dependency was activated this cycle
    if _orch_activation_dep_activated_internal "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Dependency agent was activated"
        _orch_activation_log INFO "$agent_id: ACTIVATED (dependency triggered)"
        _orch_activation_record_activation "$agent_id"
        return 0
    fi

    # v0.3 Check 4: event trigger fired
    if _orch_activation_has_event_trigger "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Event trigger fired"
        _orch_activation_log INFO "$agent_id: ACTIVATED (event trigger)"
        _orch_activation_record_activation "$agent_id"
        return 0
    fi

    # v0.5 Check 5: always-run agents (cofounder, PM, security)
    case "$agent_id" in
        00-cofounder|*-cofounder|03-pm|*-pm|10-security|*-security)
            _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
            _ORCH_ACTIVATION_REASON["$agent_id"]="Critical agent (always runs)"
            _orch_activation_log INFO "$agent_id: ACTIVATED (always-run)"
            _orch_activation_record_activation "$agent_id"
            return 0
            ;;
    esac

    # v0.5 Check 6: open GitHub issues exist (work to do)
    if _orch_activation_has_open_issues "$agent_id"; then
        _ORCH_ACTIVATION_DECISION["$agent_id"]="run"
        _ORCH_ACTIVATION_REASON["$agent_id"]="Open GitHub issues to address"
        _orch_activation_log INFO "$agent_id: ACTIVATED (open issues)"
        _orch_activation_record_activation "$agent_id"
        return 0
    fi

    # No work detected — skip
    _ORCH_ACTIVATION_DECISION["$agent_id"]="skip"
    _ORCH_ACTIVATION_REASON["$agent_id"]="No changes in owned paths, no context mentions, no open issues, no triggers"
    _orch_activation_log INFO "$agent_id: SKIPPED (no work detected)"
    return 1
}

# v0.5: Check if there are open GitHub issues for this project
# Caches the result for the lifetime of the cycle to avoid hammering gh CLI
declare -g _ORCH_ACTIVATION_ISSUES_CHECKED=false
declare -g _ORCH_ACTIVATION_HAS_ISSUES=false

_orch_activation_has_open_issues() {
    # Test/isolation escape hatch — skip the gh query when explicitly disabled
    [[ "${ORCH_ACTIVATION_SKIP_ISSUES_CHECK:-}" == "1" ]] && return 1

    # Run gh check once per cycle, not per agent
    if [[ "$_ORCH_ACTIVATION_ISSUES_CHECKED" != "true" ]]; then
        _ORCH_ACTIVATION_ISSUES_CHECKED=true
        if command -v gh &>/dev/null; then
            local issue_count
            issue_count=$(gh issue list --state open --limit 1 --json number 2>/dev/null | grep -c '"number"' 2>/dev/null || echo "0")
            if [[ "$issue_count" -gt 0 ]]; then
                _ORCH_ACTIVATION_HAS_ISSUES=true
            fi
        fi
    fi
    [[ "$_ORCH_ACTIVATION_HAS_ISSUES" == "true" ]]
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

# ══════════════════════════════════════════════════
# v0.3 Internal Helpers
# ══════════════════════════════════════════════════

# Record an activation for history tracking
_orch_activation_record_activation() {
    local agent_id="$1"
    _ORCH_ACTIVATION_HISTORY_COUNT["$agent_id"]=$(( ${_ORCH_ACTIVATION_HISTORY_COUNT[$agent_id]:-0} + 1 ))
}

# Check if any dependency of this agent was activated this cycle
_orch_activation_dep_activated_internal() {
    local agent_id="$1"
    local deps="${_ORCH_ACTIVATION_DEPS[$agent_id]:-}"

    [[ -z "$deps" ]] && return 1

    local dep
    for dep in $deps; do
        if [[ "${_ORCH_ACTIVATION_DECISION[$dep]:-}" == "run" ]]; then
            return 0
        fi
    done

    return 1
}

# Check if any event trigger for this agent has fired
_orch_activation_has_event_trigger() {
    local agent_id="$1"

    for event in "${!_ORCH_ACTIVATION_TRIGGERS[@]}"; do
        # Skip events that haven't fired
        [[ -z "${_ORCH_ACTIVATION_FIRED_EVENTS[$event]+x}" ]] && continue

        # Check if this agent is in the trigger's target list
        local targets="${_ORCH_ACTIVATION_TRIGGERS[$event]}"
        local target
        for target in $targets; do
            [[ "$target" == "$agent_id" ]] && return 0
        done
    done

    return 1
}

# ══════════════════════════════════════════════════
# v0.3 Public API: Event-Driven Triggers
# ══════════════════════════════════════════════════

# orch_activation_add_trigger <event_name> <agent_ids...>
#   Register agents to activate when event_name fires.
#   agent_ids: space-separated list of agent IDs.
orch_activation_add_trigger() {
    local event_name="${1:?orch_activation_add_trigger: event_name required}"
    shift
    local agents="$*"

    [[ -z "$agents" ]] && {
        _orch_activation_log WARN "No agents specified for trigger '$event_name'"
        return 1
    }

    _ORCH_ACTIVATION_TRIGGERS["$event_name"]="$agents"
    _orch_activation_log INFO "Trigger registered: $event_name -> $agents"
    return 0
}

# orch_activation_fire_event <event_name>
#   Fire a named event. All agents registered for this event will be activated
#   when orch_activation_check is called.
orch_activation_fire_event() {
    local event_name="${1:?orch_activation_fire_event: event_name required}"
    _ORCH_ACTIVATION_FIRED_EVENTS["$event_name"]=1
    _orch_activation_log INFO "Event fired: $event_name"
    return 0
}

# orch_activation_clear_events
#   Clear all fired events (call at start of each cycle).
orch_activation_clear_events() {
    _ORCH_ACTIVATION_FIRED_EVENTS=()
}

# ══════════════════════════════════════════════════
# v0.3 Public API: Cooldown Periods
# ══════════════════════════════════════════════════

# orch_activation_set_cooldown <agent_id> <seconds>
#   Set a cooldown period. Agent won't activate for <seconds> after this call.
#   Useful after errors or rate limits to prevent thrashing.
orch_activation_set_cooldown() {
    local agent_id="${1:?orch_activation_set_cooldown: agent_id required}"
    local seconds="${2:?orch_activation_set_cooldown: seconds required}"

    [[ ! "$seconds" =~ ^[0-9]+$ ]] && {
        _orch_activation_log WARN "Invalid cooldown seconds: $seconds"
        return 1
    }

    local now
    now=$(date +%s)
    _ORCH_ACTIVATION_COOLDOWN_UNTIL["$agent_id"]=$(( now + seconds ))
    _ORCH_ACTIVATION_COOLDOWN_SECS["$agent_id"]="$seconds"
    _orch_activation_log INFO "$agent_id: cooldown set for ${seconds}s (until $(( now + seconds )))"
    return 0
}

# orch_activation_clear_cooldown <agent_id>
#   Clear cooldown for an agent immediately.
orch_activation_clear_cooldown() {
    local agent_id="${1:?orch_activation_clear_cooldown: agent_id required}"
    _ORCH_ACTIVATION_COOLDOWN_UNTIL["$agent_id"]=0
    _ORCH_ACTIVATION_COOLDOWN_SECS["$agent_id"]=0
}

# orch_activation_in_cooldown <agent_id>
#   Returns 0 if agent is currently in cooldown, 1 otherwise.
orch_activation_in_cooldown() {
    local agent_id="${1:?orch_activation_in_cooldown: agent_id required}"
    local cooldown_until="${_ORCH_ACTIVATION_COOLDOWN_UNTIL[$agent_id]:-0}"

    [[ "$cooldown_until" -eq 0 ]] && return 1

    local now
    now=$(date +%s)
    [[ "$now" -lt "$cooldown_until" ]]
}

# ══════════════════════════════════════════════════
# v0.3 Public API: Dependency Graph
# ══════════════════════════════════════════════════

# orch_activation_set_deps <agent_id> <dep_agents...>
#   Set dependency agents. When any dep is activated, this agent also activates.
orch_activation_set_deps() {
    local agent_id="${1:?orch_activation_set_deps: agent_id required}"
    shift
    _ORCH_ACTIVATION_DEPS["$agent_id"]="$*"
}

# orch_activation_dep_activated <agent_id>
#   Check if any dependency of agent_id was activated this cycle.
#   Returns 0 if yes, 1 if no.
orch_activation_dep_activated() {
    local agent_id="${1:?orch_activation_dep_activated: agent_id required}"
    _orch_activation_dep_activated_internal "$agent_id"
}

# orch_activation_history <agent_id>
#   Print activation history for an agent.
orch_activation_history() {
    local agent_id="${1:?orch_activation_history: agent_id required}"
    local count="${_ORCH_ACTIVATION_HISTORY_COUNT[$agent_id]:-0}"
    printf '%s: %d activations\n' "$agent_id" "$count"
}
