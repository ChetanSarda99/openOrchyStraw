#!/usr/bin/env bash
# ============================================
# founder-mode.sh — Always-on front agent for triaging incoming work
# Source this file: source src/core/founder-mode.sh
#
# Implements a "founder mode" triage layer that classifies tasks,
# routes them to the right agent(s), manages delegation logs,
# and can override agent scheduling priorities per cycle.
#
# Public API:
#   orch_founder_init              — Initialize founder mode
#   orch_founder_triage            — Classify task and recommend agent(s)
#   orch_founder_delegate          — Record task→agent delegation
#   orch_founder_should_run        — Decide if an agent runs this cycle
#   orch_founder_override_priority — Override priority for current cycle
#   orch_founder_status            — Print current founder state
#
# Requires: bash 4.2+
# ============================================

# Guard against double-sourcing
[[ -n "${_ORCH_FOUNDER_MODE_LOADED:-}" ]] && return 0
_ORCH_FOUNDER_MODE_LOADED=1

# ── Defaults ──
declare -g _ORCH_FOUNDER_PROJECT_ROOT=""
declare -g _ORCH_FOUNDER_AGENT="${FOUNDER_AGENT:-01-ceo}"
declare -g _ORCH_FOUNDER_STATE_DIR=""
declare -g _ORCH_FOUNDER_DELEGATION_LOG=""
declare -g _ORCH_FOUNDER_OVERRIDES_FILE=""
declare -g _ORCH_FOUNDER_TRIAGE_FILE=""
declare -gA _ORCH_FOUNDER_AGENTS=()         # agent_id → interval
declare -gA _ORCH_FOUNDER_AGENT_LABELS=()   # agent_id → label
declare -gA _ORCH_FOUNDER_ACTIVE_TASKS=()   # agent_id → count of active tasks
declare -gA _ORCH_FOUNDER_OVERRIDES=()      # agent_id → priority override

# ---------------------------------------------------------------------------
# orch_founder_init [project_root]
#
# Initialize founder mode. Reads agents.conf, identifies the founder agent,
# sets up state directory and files. Idempotent.
# ---------------------------------------------------------------------------
orch_founder_init() {
    local project_root="${1:-}"

    if [[ -z "$project_root" ]]; then
        project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    fi

    _ORCH_FOUNDER_PROJECT_ROOT="$project_root"
    _ORCH_FOUNDER_AGENT="${FOUNDER_AGENT:-01-ceo}"

    # State directory
    _ORCH_FOUNDER_STATE_DIR="$project_root/.orchystraw"
    mkdir -p "$_ORCH_FOUNDER_STATE_DIR"

    # State files
    _ORCH_FOUNDER_DELEGATION_LOG="$_ORCH_FOUNDER_STATE_DIR/founder-delegations.log"
    _ORCH_FOUNDER_OVERRIDES_FILE="$_ORCH_FOUNDER_STATE_DIR/founder-overrides.json"
    _ORCH_FOUNDER_TRIAGE_FILE="$_ORCH_FOUNDER_STATE_DIR/founder-triage.state"

    # Touch state files if they don't exist
    [[ -f "$_ORCH_FOUNDER_DELEGATION_LOG" ]] || touch "$_ORCH_FOUNDER_DELEGATION_LOG"
    [[ -f "$_ORCH_FOUNDER_TRIAGE_FILE" ]]    || touch "$_ORCH_FOUNDER_TRIAGE_FILE"

    # Initialize overrides file as empty JSON object if missing
    if [[ ! -f "$_ORCH_FOUNDER_OVERRIDES_FILE" ]]; then
        echo '{}' > "$_ORCH_FOUNDER_OVERRIDES_FILE"
    fi

    # Reset runtime state
    _ORCH_FOUNDER_AGENTS=()
    _ORCH_FOUNDER_AGENT_LABELS=()
    _ORCH_FOUNDER_ACTIVE_TASKS=()
    _ORCH_FOUNDER_OVERRIDES=()

    # Parse agents.conf
    local conf_file="$project_root/agents.conf"
    if [[ -f "$conf_file" ]]; then
        _orch_founder_parse_agents "$conf_file"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# _orch_founder_parse_agents <agents_conf_path>
#
# Parse agents.conf and populate _ORCH_FOUNDER_AGENTS and labels.
# Format: id | prompt_path | ownership | interval | label | model
# ---------------------------------------------------------------------------
_orch_founder_parse_agents() {
    local conf_file="$1"
    local line

    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Split on pipe
        local id interval label
        id=$(echo "$line" | cut -d'|' -f1 | tr -d '[:space:]')
        interval=$(echo "$line" | cut -d'|' -f4 | tr -d '[:space:]')
        label=$(echo "$line" | cut -d'|' -f5 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ -n "$id" && -n "$interval" ]]; then
            _ORCH_FOUNDER_AGENTS["$id"]="$interval"
            _ORCH_FOUNDER_AGENT_LABELS["$id"]="$label"
        fi
    done < "$conf_file"
}

# ---------------------------------------------------------------------------
# orch_founder_triage <task_description> [priority]
#
# Classify a task into a category and recommend agent(s).
# Prints: category|agent1,agent2
# Priority is optional (default: "normal").
#
# Categories: bug, feature, refactor, docs, infra, security
# ---------------------------------------------------------------------------
orch_founder_triage() {
    local task="${1:-}"
    local priority="${2:-normal}"

    if [[ -z "$task" ]]; then
        echo "[founder-mode] ERROR: orch_founder_triage requires a task description" >&2
        return 1
    fi

    local task_lower
    task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')

    local category=""
    local agents=""

    # Security (check first — security trumps other categories)
    if echo "$task_lower" | grep -qE '(security|vuln|audit|cve|exploit|breach)'; then
        category="security"
        agents="10-security"
    # Infra (check before bug — "deploy", "ci", "pipeline" are strong infra signals)
    elif echo "$task_lower" | grep -qE '(deploy|ci[^a-z]|infra|pipeline|release)'; then
        category="infra"
        agents="06-backend"
    # Bug
    elif echo "$task_lower" | grep -qE '(bug|fix|crash|error|broken|regression)'; then
        category="bug"
        # Route based on sub-keywords
        if echo "$task_lower" | grep -qE '(test|qa|quality)'; then
            agents="09-qa"
        elif echo "$task_lower" | grep -qwE '(ui|frontend|component|layout)'; then
            agents="05-tauri-ui"
        elif echo "$task_lower" | grep -qE '(mobile|ios|swift)'; then
            agents="07-ios"
        else
            agents="06-backend"
        fi
    # Feature
    elif echo "$task_lower" | grep -qE '(feature|add|new|implement|create|build)'; then
        category="feature"
        if echo "$task_lower" | grep -qE '(mobile|ios|swift|companion)'; then
            agents="07-ios"
        elif echo "$task_lower" | grep -qwE '(ui|frontend|dashboard|component|layout)'; then
            agents="05-tauri-ui"
        elif echo "$task_lower" | grep -qE '(pixel|animation|visual)'; then
            agents="08-pixel"
        elif echo "$task_lower" | grep -qE '(site|landing|page|web|docs)'; then
            agents="11-web"
        elif echo "$task_lower" | grep -qE '(api|backend|script|engine|cli)'; then
            agents="06-backend"
        else
            agents="06-backend"
        fi
    # Refactor
    elif echo "$task_lower" | grep -qE '(refactor|clean|optimize|simplify|restructure)'; then
        category="refactor"
        if echo "$task_lower" | grep -qE '(arch|design|pattern)'; then
            agents="02-cto"
        else
            agents="06-backend"
        fi
    # Docs
    elif echo "$task_lower" | grep -qE '(doc|readme|guide|tutorial|reference)'; then
        category="docs"
        agents="11-web"
    # Default: unknown → route to founder agent
    else
        category="unknown"
        agents="$_ORCH_FOUNDER_AGENT"
    fi

    # Write last triage result to state file
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    printf '%s|%s|%s|%s|%s\n' "$timestamp" "$category" "$agents" "$priority" "$task" \
        > "$_ORCH_FOUNDER_TRIAGE_FILE"

    # Output result
    echo "${category}|${agents}"
    return 0
}

# ---------------------------------------------------------------------------
# orch_founder_delegate <task_description> <agent_name>
#
# Record a delegation: task → agent mapping with timestamp.
# Appends to .orchystraw/founder-delegations.log.
# ---------------------------------------------------------------------------
orch_founder_delegate() {
    local task="${1:-}"
    local agent="${2:-}"

    if [[ -z "$task" ]]; then
        echo "[founder-mode] ERROR: orch_founder_delegate requires a task description" >&2
        return 1
    fi
    if [[ -z "$agent" ]]; then
        echo "[founder-mode] ERROR: orch_founder_delegate requires an agent name" >&2
        return 1
    fi

    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Append to delegation log
    printf '%s|%s|%s\n' "$timestamp" "$agent" "$task" \
        >> "$_ORCH_FOUNDER_DELEGATION_LOG"

    # Track active task count
    local current="${_ORCH_FOUNDER_ACTIVE_TASKS[$agent]:-0}"
    _ORCH_FOUNDER_ACTIVE_TASKS["$agent"]=$(( current + 1 ))

    return 0
}

# ---------------------------------------------------------------------------
# orch_founder_should_run <agent_name> <cycle_num>
#
# Return 0 if the founder thinks this agent should run this cycle.
# Return 1 if the agent should be skipped.
#
# Decision factors:
#   1. Agent has an active override → always run
#   2. Agent has active delegated tasks → always run
#   3. Agent interval from agents.conf: cycle_num % interval == 0
#   4. Coordinator (interval=0) → always runs
# ---------------------------------------------------------------------------
orch_founder_should_run() {
    local agent="${1:-}"
    local cycle_num="${2:-0}"

    if [[ -z "$agent" ]]; then
        echo "[founder-mode] ERROR: orch_founder_should_run requires an agent name" >&2
        return 1
    fi

    # Check for priority override
    if [[ -n "${_ORCH_FOUNDER_OVERRIDES[$agent]:-}" ]]; then
        return 0
    fi

    # Check for active delegated tasks
    local active="${_ORCH_FOUNDER_ACTIVE_TASKS[$agent]:-0}"
    if [[ "$active" -gt 0 ]]; then
        return 0
    fi

    # Check interval from agents.conf
    local interval="${_ORCH_FOUNDER_AGENTS[$agent]:-}"

    # Unknown agent — skip
    if [[ -z "$interval" ]]; then
        return 1
    fi

    # Coordinator (interval=0) always runs
    if [[ "$interval" -eq 0 ]]; then
        return 0
    fi

    # Interval check: run if cycle_num is divisible by interval
    if [[ "$cycle_num" -gt 0 ]] && (( cycle_num % interval == 0 )); then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# orch_founder_override_priority <agent_name> <new_priority>
#
# Override the priority for an agent for the current cycle.
# Writes to .orchystraw/founder-overrides.json.
# Priority values: "critical", "high", "normal", "low", "skip"
# ---------------------------------------------------------------------------
orch_founder_override_priority() {
    local agent="${1:-}"
    local new_priority="${2:-}"

    if [[ -z "$agent" ]]; then
        echo "[founder-mode] ERROR: orch_founder_override_priority requires an agent name" >&2
        return 1
    fi
    if [[ -z "$new_priority" ]]; then
        echo "[founder-mode] ERROR: orch_founder_override_priority requires a priority" >&2
        return 1
    fi

    # Store in runtime state
    _ORCH_FOUNDER_OVERRIDES["$agent"]="$new_priority"

    # Write to JSON file (pure bash — no jq)
    # Rebuild the file from the associative array with sanitized values
    local json="{"
    local first=1
    local key val_safe key_safe
    for key in "${!_ORCH_FOUNDER_OVERRIDES[@]}"; do
        if [[ "$first" -eq 1 ]]; then
            first=0
        else
            json+=","
        fi
        # Sanitize: strip any characters that could break JSON structure
        key_safe="${key//[\"\\]/}"
        val_safe="${_ORCH_FOUNDER_OVERRIDES[$key]//[\"\\]/}"
        json+="\"${key_safe}\":\"${val_safe}\""
    done
    json+="}"

    echo "$json" > "$_ORCH_FOUNDER_OVERRIDES_FILE"

    return 0
}

# ---------------------------------------------------------------------------
# orch_founder_status
#
# Print current delegation state, active overrides, last triage results.
# Human-readable output to stdout.
# ---------------------------------------------------------------------------
orch_founder_status() {
    echo "=== Founder Mode Status ==="
    echo "Founder agent: $_ORCH_FOUNDER_AGENT"
    echo "Project root:  $_ORCH_FOUNDER_PROJECT_ROOT"
    echo "State dir:     $_ORCH_FOUNDER_STATE_DIR"
    echo ""

    # Known agents
    echo "--- Known Agents ---"
    local agent_id
    for agent_id in "${!_ORCH_FOUNDER_AGENTS[@]}"; do
        local interval="${_ORCH_FOUNDER_AGENTS[$agent_id]}"
        local label="${_ORCH_FOUNDER_AGENT_LABELS[$agent_id]:-}"
        printf '  %-14s interval=%-2s %s\n' "$agent_id" "$interval" "$label"
    done
    echo ""

    # Active overrides
    echo "--- Active Overrides ---"
    if [[ ${#_ORCH_FOUNDER_OVERRIDES[@]} -eq 0 ]]; then
        echo "  (none)"
    else
        for agent_id in "${!_ORCH_FOUNDER_OVERRIDES[@]}"; do
            printf '  %-14s → %s\n' "$agent_id" "${_ORCH_FOUNDER_OVERRIDES[$agent_id]}"
        done
    fi
    echo ""

    # Active delegations (task counts)
    echo "--- Active Delegations ---"
    local has_tasks=0
    for agent_id in "${!_ORCH_FOUNDER_ACTIVE_TASKS[@]}"; do
        local count="${_ORCH_FOUNDER_ACTIVE_TASKS[$agent_id]}"
        if [[ "$count" -gt 0 ]]; then
            printf '  %-14s %d task(s)\n' "$agent_id" "$count"
            has_tasks=1
        fi
    done
    if [[ "$has_tasks" -eq 0 ]]; then
        echo "  (none)"
    fi
    echo ""

    # Last triage result
    echo "--- Last Triage ---"
    if [[ -f "$_ORCH_FOUNDER_TRIAGE_FILE" && -s "$_ORCH_FOUNDER_TRIAGE_FILE" ]]; then
        local last_line
        last_line=$(tail -1 "$_ORCH_FOUNDER_TRIAGE_FILE")
        local ts cat agents pri desc
        ts=$(echo "$last_line" | cut -d'|' -f1)
        cat=$(echo "$last_line" | cut -d'|' -f2)
        agents=$(echo "$last_line" | cut -d'|' -f3)
        pri=$(echo "$last_line" | cut -d'|' -f4)
        desc=$(echo "$last_line" | cut -d'|' -f5-)
        echo "  Time:     $ts"
        echo "  Category: $cat"
        echo "  Agents:   $agents"
        echo "  Priority: $pri"
        echo "  Task:     $desc"
    else
        echo "  (no triage performed yet)"
    fi
    echo ""

    # Delegation log summary
    echo "--- Delegation Log ---"
    if [[ -f "$_ORCH_FOUNDER_DELEGATION_LOG" && -s "$_ORCH_FOUNDER_DELEGATION_LOG" ]]; then
        local line_count
        line_count=$(wc -l < "$_ORCH_FOUNDER_DELEGATION_LOG")
        echo "  Total delegations: $line_count"
        echo "  Recent:"
        tail -5 "$_ORCH_FOUNDER_DELEGATION_LOG" | while IFS='|' read -r ts agent desc; do
            printf '    [%s] %s → %s\n' "$ts" "$agent" "$desc"
        done
    else
        echo "  (no delegations recorded)"
    fi
}
