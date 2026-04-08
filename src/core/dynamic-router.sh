#!/usr/bin/env bash
# dynamic-router.sh — Dynamic agent routing with dependency-aware parallel groups
# v0.3.0: #41 (dynamic routing), #43 (dependency-aware parallel), #46 (model tiering)
#         v0.3 adds: cost-aware routing, latency tracking, quality scoring,
#         automatic tier promotion/demotion based on agent performance history
#
# Parses agents.conf (v1 5-col, v2 8-col, or v2+ 9-col with model), builds a
# dependency graph, resolves execution groups via topological sort, and decides
# which agents run each cycle based on interval, outcome history, and PM overrides.
#
# Provides:
#   orch_router_init           — parse config, build dependency graph
#   orch_router_eligible       — return agents eligible to run this cycle
#   orch_router_groups         — return execution groups (topo-sorted)
#   orch_router_has_cycle      — detect circular dependencies
#   orch_router_update         — adjust state after cycle completes
#   orch_router_load_state     — load persisted router state from file
#   orch_router_save_state     — persist router state to file
#   orch_router_model          — get resolved model for an agent (#46)
#   orch_router_dump           — debug: print parsed config
#   orch_router_record_cost    — record token cost for a run
#   orch_router_record_latency — record execution latency for a run
#   orch_router_record_quality — record quality score for a run
#   orch_router_cost_report    — print per-agent and total cost summary
#   orch_router_auto_tier      — auto promote/demote model tier based on quality
#   orch_router_agent_score    — get composite quality score for an agent

[[ -n "${_ORCH_DYNAMIC_ROUTER_LOADED:-}" ]] && return 0
_ORCH_DYNAMIC_ROUTER_LOADED=1

# ── State ──
declare -g -a _ORCH_ROUTER_AGENTS=()        # ordered list of agent IDs
declare -g -A _ORCH_ROUTER_PRIORITY=()       # agent_id -> priority (int)
declare -g -A _ORCH_ROUTER_DEPENDS=()        # agent_id -> "dep1,dep2" or "none"
declare -g -A _ORCH_ROUTER_INTERVAL=()       # agent_id -> base interval
declare -g -A _ORCH_ROUTER_EFF_INTERVAL=()   # agent_id -> effective (adjusted) interval
declare -g -A _ORCH_ROUTER_LAST_RUN=()       # agent_id -> cycle number of last run
declare -g -A _ORCH_ROUTER_LAST_OUTCOME=()   # agent_id -> success|fail|skip|timeout
declare -g -A _ORCH_ROUTER_CONSEC_EMPTY=()   # agent_id -> consecutive cycles with no changes
declare -g -A _ORCH_ROUTER_PM_FORCE=()       # agent_id -> 1 if PM forced this cycle
declare -g -A _ORCH_ROUTER_MODEL=()          # agent_id -> model (opus|sonnet|haiku)
declare -g -a _ORCH_ROUTER_GROUPS=()         # group strings: "agent1,agent2" per group
declare -g _ORCH_ROUTER_LOADED=false

# Model tiering (#46 MODEL-001)
declare -g _ORCH_DEFAULT_MODEL="${ORCH_DEFAULT_MODEL:-opus}"
declare -g -A _ORCH_MODEL_FLAGS=(
    [opus]="claude-opus-4-6"
    [sonnet]="claude-sonnet-4-6"
    [haiku]="claude-haiku-4-5"
)
declare -g -a _ORCH_VALID_MODELS=(opus sonnet haiku)

# v0.3 Cost-aware routing state
declare -g -A _ORCH_ROUTER_COST_TOTAL=()      # agent_id -> cumulative token cost
declare -g -A _ORCH_ROUTER_COST_LAST=()        # agent_id -> last run token cost
declare -g -A _ORCH_ROUTER_RUN_COUNT=()        # agent_id -> number of completed runs

# v0.3 Latency tracking state
declare -g -A _ORCH_ROUTER_LATENCY_TOTAL=()    # agent_id -> cumulative latency (seconds)
declare -g -A _ORCH_ROUTER_LATENCY_LAST=()     # agent_id -> last run latency (seconds)
declare -g -A _ORCH_ROUTER_LATENCY_P95=()      # agent_id -> p95 latency estimate (EMA)

# v0.3 Quality scoring state
declare -g -A _ORCH_ROUTER_QUALITY_TOTAL=()    # agent_id -> cumulative quality score
declare -g -A _ORCH_ROUTER_QUALITY_LAST=()     # agent_id -> last quality score (0-100)
declare -g -A _ORCH_ROUTER_QUALITY_AVG=()      # agent_id -> rolling avg quality (0-100)

# v0.3 Auto-tier thresholds
declare -g _ORCH_TIER_PROMOTE_THRESHOLD="${ORCH_TIER_PROMOTE_THRESHOLD:-85}"
declare -g _ORCH_TIER_DEMOTE_THRESHOLD="${ORCH_TIER_DEMOTE_THRESHOLD:-40}"
declare -g _ORCH_TIER_MIN_RUNS="${ORCH_TIER_MIN_RUNS:-3}"
declare -g -A _ORCH_ROUTER_TIER_LOCKED=()      # agent_id -> 1 if tier is locked (no auto-change)

# v0.3 Cost per token by model (USD per 1M tokens, input estimate)
declare -g -A _ORCH_MODEL_COST_PER_M=(
    [opus]=15.00
    [sonnet]=3.00
    [haiku]=0.25
)

# ── Helpers ──

_orch_router_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

_orch_router_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "router" "$2"
    fi
}

# ── Public API ──

# orch_router_init <conf_file>
#   Parse agents.conf (5 or 8 columns), populate internal state.
#   Backward compatible: missing cols 6-8 get defaults.
orch_router_init() {
    local conf_file="${1:?orch_router_init: conf_file required}"

    if [[ ! -f "$conf_file" ]]; then
        _orch_router_log ERROR "Config file not found: $conf_file"
        return 1
    fi

    _ORCH_ROUTER_AGENTS=()
    _ORCH_ROUTER_PRIORITY=()
    _ORCH_ROUTER_DEPENDS=()
    _ORCH_ROUTER_INTERVAL=()
    _ORCH_ROUTER_EFF_INTERVAL=()
    _ORCH_ROUTER_LAST_RUN=()
    _ORCH_ROUTER_LAST_OUTCOME=()
    _ORCH_ROUTER_CONSEC_EMPTY=()
    _ORCH_ROUTER_MODEL=()
    _ORCH_ROUTER_PM_FORCE=()
    _ORCH_ROUTER_GROUPS=()
    _ORCH_ROUTER_COST_TOTAL=()
    _ORCH_ROUTER_COST_LAST=()
    _ORCH_ROUTER_RUN_COUNT=()
    _ORCH_ROUTER_LATENCY_TOTAL=()
    _ORCH_ROUTER_LATENCY_LAST=()
    _ORCH_ROUTER_LATENCY_P95=()
    _ORCH_ROUTER_QUALITY_TOTAL=()
    _ORCH_ROUTER_QUALITY_LAST=()
    _ORCH_ROUTER_QUALITY_AVG=()
    _ORCH_ROUTER_TIER_LOCKED=()

    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed
        trimmed=$(_orch_router_trim "$raw_line")
        [[ "$trimmed" == \#* ]] && continue

        # Split on pipe (up to 9 columns)
        IFS='|' read -r f_id f_prompt f_ownership f_interval f_label f_priority f_depends f_reviews f_model <<< "$raw_line"

        f_id=$(_orch_router_trim "$f_id")
        f_interval=$(_orch_router_trim "$f_interval")
        f_priority=$(_orch_router_trim "${f_priority:-}")
        f_depends=$(_orch_router_trim "${f_depends:-}")
        f_model=$(_orch_router_trim "${f_model:-}")

        [[ -z "$f_id" ]] && continue

        # Defaults for missing v2 columns
        [[ -z "$f_priority" || "$f_priority" == "none" || ! "$f_priority" =~ ^[0-9]+$ ]] && f_priority=5
        [[ -z "$f_depends" ]] && f_depends="none"
        [[ ! "$f_interval" =~ ^[0-9]+$ ]] && f_interval=1
        # Model defaults to ORCH_DEFAULT_MODEL if missing/empty
        [[ -z "$f_model" || "$f_model" == "none" ]] && f_model="$_ORCH_DEFAULT_MODEL"

        _ORCH_ROUTER_AGENTS+=("$f_id")
        _ORCH_ROUTER_INTERVAL["$f_id"]="$f_interval"
        _ORCH_ROUTER_EFF_INTERVAL["$f_id"]="$f_interval"
        _ORCH_ROUTER_PRIORITY["$f_id"]="$f_priority"
        _ORCH_ROUTER_DEPENDS["$f_id"]="$f_depends"
        _ORCH_ROUTER_MODEL["$f_id"]="$f_model"
        _ORCH_ROUTER_LAST_RUN["$f_id"]=0
        _ORCH_ROUTER_LAST_OUTCOME["$f_id"]="none"
        _ORCH_ROUTER_CONSEC_EMPTY["$f_id"]=0
        _ORCH_ROUTER_PM_FORCE["$f_id"]=0
        _ORCH_ROUTER_COST_TOTAL["$f_id"]=0
        _ORCH_ROUTER_COST_LAST["$f_id"]=0
        _ORCH_ROUTER_RUN_COUNT["$f_id"]=0
        _ORCH_ROUTER_LATENCY_TOTAL["$f_id"]=0
        _ORCH_ROUTER_LATENCY_LAST["$f_id"]=0
        _ORCH_ROUTER_LATENCY_P95["$f_id"]=0
        _ORCH_ROUTER_QUALITY_TOTAL["$f_id"]=0
        _ORCH_ROUTER_QUALITY_LAST["$f_id"]=0
        _ORCH_ROUTER_QUALITY_AVG["$f_id"]=0
        _ORCH_ROUTER_TIER_LOCKED["$f_id"]=0
    done < "$conf_file"

    _ORCH_ROUTER_LOADED=true
    _orch_router_log INFO "Router initialized with ${#_ORCH_ROUTER_AGENTS[@]} agents"
    return 0
}

# orch_router_has_cycle
#   Detect circular dependencies. Returns 0 if cycle found, 1 if DAG is clean.
orch_router_has_cycle() {
    [[ "$_ORCH_ROUTER_LOADED" != "true" ]] && return 1

    # Kahn's algorithm: count in-degrees, peel zero-degree nodes
    declare -A in_degree=()
    declare -A adj=()

    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        in_degree["$id"]=0
        adj["$id"]=""
    done

    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        local deps="${_ORCH_ROUTER_DEPENDS[$id]}"
        [[ "$deps" == "none" ]] && continue
        if [[ "$deps" == "all" ]]; then
            for other in "${_ORCH_ROUTER_AGENTS[@]}"; do
                [[ "$other" == "$id" ]] && continue
                adj["$other"]+="$id,"
                in_degree["$id"]=$(( ${in_degree[$id]} + 1 ))
            done
        else
            IFS=',' read -ra dep_list <<< "$deps"
            # BUG-014: deduplicate deps to avoid inflated in-degree
            declare -A _seen_deps=()
            for dep in "${dep_list[@]}"; do
                dep=$(_orch_router_trim "$dep")
                [[ -z "$dep" ]] && continue
                [[ -n "${_seen_deps[$dep]+x}" ]] && continue
                _seen_deps["$dep"]=1
                # Only count if dep is a known agent
                if [[ -n "${in_degree[$dep]+x}" ]]; then
                    adj["$dep"]+="$id,"
                    in_degree["$id"]=$(( ${in_degree[$id]} + 1 ))
                else
                    # BUG-016: warn on unknown dep
                    _orch_router_log WARN "Agent '$id' depends on unknown agent '$dep'"
                fi
            done
            unset _seen_deps
        fi
    done

    # BFS: start with zero in-degree nodes
    local -a queue=()
    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        [[ "${in_degree[$id]}" -eq 0 ]] && queue+=("$id")
    done

    local processed=0
    local qi=0
    while [[ $qi -lt ${#queue[@]} ]]; do
        local node="${queue[$qi]}"
        qi=$((qi + 1))
        processed=$((processed + 1))

        local neighbors="${adj[$node]}"
        [[ -z "$neighbors" ]] && continue
        IFS=',' read -ra nbr_list <<< "$neighbors"
        for nbr in "${nbr_list[@]}"; do
            [[ -z "$nbr" ]] && continue
            in_degree["$nbr"]=$(( ${in_degree[$nbr]} - 1 ))
            [[ "${in_degree[$nbr]}" -eq 0 ]] && queue+=("$nbr")
        done
    done

    # If we couldn't process all nodes, there's a cycle
    if [[ $processed -lt ${#_ORCH_ROUTER_AGENTS[@]} ]]; then
        _orch_router_log ERROR "Circular dependency detected in agents.conf"
        return 0  # cycle FOUND
    fi
    return 1  # no cycle
}

# orch_router_groups
#   Topological sort into execution groups. Agents within a group can run in parallel.
#   Prints groups as newline-separated strings, each group is comma-separated agent IDs.
#   Groups are ordered: group 0 first (no deps), then group 1, etc.
orch_router_groups() {
    [[ "$_ORCH_ROUTER_LOADED" != "true" ]] && return 1

    # Compute group level for each agent via BFS topological layering
    declare -A in_degree=()
    declare -A adj=()
    declare -A group_of=()

    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        in_degree["$id"]=0
        adj["$id"]=""
    done

    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        local deps="${_ORCH_ROUTER_DEPENDS[$id]}"
        [[ "$deps" == "none" ]] && continue
        if [[ "$deps" == "all" ]]; then
            for other in "${_ORCH_ROUTER_AGENTS[@]}"; do
                [[ "$other" == "$id" ]] && continue
                adj["$other"]+="$id,"
                in_degree["$id"]=$(( ${in_degree[$id]} + 1 ))
            done
        else
            IFS=',' read -ra dep_list <<< "$deps"
            # BUG-014: deduplicate deps to avoid inflated in-degree
            declare -A _seen_deps=()
            for dep in "${dep_list[@]}"; do
                dep=$(_orch_router_trim "$dep")
                [[ -z "$dep" ]] && continue
                [[ -n "${_seen_deps[$dep]+x}" ]] && continue
                _seen_deps["$dep"]=1
                if [[ -n "${in_degree[$dep]+x}" ]]; then
                    adj["$dep"]+="$id,"
                    in_degree["$id"]=$(( ${in_degree[$id]} + 1 ))
                else
                    _orch_router_log WARN "Agent '$id' depends on unknown agent '$dep'"
                fi
            done
            unset _seen_deps
        fi
    done

    # BFS layering: nodes with in_degree=0 are group 0, their successors are group 1, etc.
    local -a current_layer=()
    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        if [[ "${in_degree[$id]}" -eq 0 ]]; then
            current_layer+=("$id")
            group_of["$id"]=0
        fi
    done

    local group_num=0
    local -a all_groups=()

    while [[ ${#current_layer[@]} -gt 0 ]]; do
        # Sort current layer by priority (descending) for deterministic ordering
        local sorted_layer
        sorted_layer=$(for id in "${current_layer[@]}"; do
            printf '%s %s\n' "${_ORCH_ROUTER_PRIORITY[$id]:-5}" "$id"
        done | sort -rn -k1 | awk '{print $2}')

        local group_str=""
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            if [[ -n "$group_str" ]]; then
                group_str+=","
            fi
            group_str+="$id"
        done <<< "$sorted_layer"

        all_groups+=("$group_str")

        # Find next layer
        local -a next_layer=()
        for node in "${current_layer[@]}"; do
            local neighbors="${adj[$node]}"
            [[ -z "$neighbors" ]] && continue
            IFS=',' read -ra nbr_list <<< "$neighbors"
            for nbr in "${nbr_list[@]}"; do
                [[ -z "$nbr" ]] && continue
                in_degree["$nbr"]=$(( ${in_degree[$nbr]} - 1 ))
                if [[ "${in_degree[$nbr]}" -eq 0 ]]; then
                    next_layer+=("$nbr")
                    group_of["$nbr"]=$(( group_num + 1 ))
                fi
            done
        done

        current_layer=("${next_layer[@]+"${next_layer[@]}"}")
        group_num=$((group_num + 1))
    done

    _ORCH_ROUTER_GROUPS=("${all_groups[@]}")

    for g in "${all_groups[@]}"; do
        printf '%s\n' "$g"
    done
}

# orch_router_force_agent <agent_id>
#   PM override: force an agent to run next cycle regardless of interval.
orch_router_force_agent() {
    local agent_id="${1:?orch_router_force_agent: agent_id required}"
    _ORCH_ROUTER_PM_FORCE["$agent_id"]=1
}

# orch_router_eligible <cycle_num>
#   Return agents eligible for this cycle (one per line), respecting intervals,
#   outcome adjustments, and PM overrides.
#   Coordinator (interval=0) is always excluded — it runs separately as LAST.
orch_router_eligible() {
    local cycle_num="${1:?orch_router_eligible: cycle_num required}"
    [[ "$_ORCH_ROUTER_LOADED" != "true" ]] && return 1

    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        local base_interval="${_ORCH_ROUTER_INTERVAL[$id]}"

        # Skip coordinator (interval=0) — always runs last, not through router
        [[ "$base_interval" -eq 0 ]] && continue

        # PM force override
        if [[ "${_ORCH_ROUTER_PM_FORCE[$id]:-0}" == "1" ]]; then
            printf '%s\n' "$id"
            continue
        fi

        local eff_interval="${_ORCH_ROUTER_EFF_INTERVAL[$id]}"
        local last_run="${_ORCH_ROUTER_LAST_RUN[$id]:-0}"

        # Never run before — always eligible
        if [[ "$last_run" -eq 0 ]]; then
            printf '%s\n' "$id"
            continue
        fi

        # Check if enough cycles have passed
        local cycles_since=$(( cycle_num - last_run ))
        if [[ $cycles_since -ge $eff_interval ]]; then
            printf '%s\n' "$id"
        fi
    done
}

# orch_router_update <agent_id> <outcome>
#   Update router state after an agent completes. Adjusts effective interval.
#   outcome: success | fail | skip | timeout
orch_router_update() {
    local agent_id="${1:?orch_router_update: agent_id required}"
    local outcome="${2:?orch_router_update: outcome required}"
    local cycle_num="${3:-0}"

    _ORCH_ROUTER_LAST_OUTCOME["$agent_id"]="$outcome"
    _ORCH_ROUTER_LAST_RUN["$agent_id"]="$cycle_num"
    _ORCH_ROUTER_PM_FORCE["$agent_id"]=0  # clear force flag

    local base="${_ORCH_ROUTER_INTERVAL[$agent_id]}"
    [[ "$base" -eq 0 ]] && return 0  # coordinator — no adjustment

    case "$outcome" in
        fail|timeout)
            # Retry sooner: halve interval (min 1)
            local new_eff=$(( base / 2 ))
            [[ $new_eff -lt 1 ]] && new_eff=1
            _ORCH_ROUTER_EFF_INTERVAL["$agent_id"]="$new_eff"
            _ORCH_ROUTER_CONSEC_EMPTY["$agent_id"]=0
            ;;
        success)
            # Reset to base interval, clear empty streak
            _ORCH_ROUTER_EFF_INTERVAL["$agent_id"]="$base"
            _ORCH_ROUTER_CONSEC_EMPTY["$agent_id"]=0
            ;;
        skip)
            # No changes produced — increment empty counter
            local empty=$(( ${_ORCH_ROUTER_CONSEC_EMPTY[$agent_id]:-0} + 1 ))
            _ORCH_ROUTER_CONSEC_EMPTY["$agent_id"]="$empty"
            # Back off after 3+ empty cycles: double interval (cap at base * 4)
            if [[ $empty -ge 3 ]]; then
                local new_eff=$(( base * 2 ))
                local max_eff=$(( base * 4 ))
                [[ $new_eff -gt $max_eff ]] && new_eff=$max_eff
                _ORCH_ROUTER_EFF_INTERVAL["$agent_id"]="$new_eff"
            fi
            ;;
    esac
}

# (save_state and load_state moved to v0.3 section below with extended fields)

# orch_router_model <agent_id>
#   Get the resolved model for an agent. Respects overrides:
#   0. model-selector.sh intelligent selection (if loaded + ORCH_INTELLIGENT_MODEL=1)
#   1. ORCH_MODEL_OVERRIDE_<ID> env var (highest priority)
#   2. --model CLI override (caller sets ORCH_MODEL_CLI_OVERRIDE)
#   3. agents.conf column 9
#   4. ORCH_DEFAULT_MODEL env var / "opus" fallback
#   Prints the model flag (e.g., "claude-opus-4-6") to stdout.
orch_router_model() {
    local agent_id="${1:?orch_router_model: agent_id required}"

    # Priority 0: Delegate to intelligent model selector if available
    if [[ "${ORCH_INTELLIGENT_MODEL:-0}" == "1" ]] && \
       [[ "$(type -t orch_model_select)" == "function" ]]; then
        local smart_model
        smart_model=$(orch_model_select "$agent_id" 2>/dev/null) || smart_model=""
        if [[ -n "$smart_model" ]]; then
            if [[ -n "${_ORCH_MODEL_FLAGS[$smart_model]+x}" ]]; then
                printf '%s\n' "${_ORCH_MODEL_FLAGS[$smart_model]}"
            else
                printf '%s\n' "$smart_model"
            fi
            return 0
        fi
    fi

    # Normalize agent ID for env var lookup: 06-backend -> 06_BACKEND
    local env_key="${agent_id//-/_}"
    env_key="${env_key^^}"
    local override_var="ORCH_MODEL_OVERRIDE_${env_key}"

    local model=""

    # Priority 1: per-agent env var override
    if [[ -n "${!override_var:-}" ]]; then
        model="${!override_var}"
    # Priority 2: CLI override (global)
    elif [[ -n "${ORCH_MODEL_CLI_OVERRIDE:-}" ]]; then
        model="$ORCH_MODEL_CLI_OVERRIDE"
    # Priority 3: agents.conf value
    elif [[ -n "${_ORCH_ROUTER_MODEL[$agent_id]+x}" ]]; then
        model="${_ORCH_ROUTER_MODEL[$agent_id]}"
    # Priority 4: default
    else
        model="$_ORCH_DEFAULT_MODEL"
    fi

    # Map abstract name to flag
    if [[ -n "${_ORCH_MODEL_FLAGS[$model]+x}" ]]; then
        printf '%s\n' "${_ORCH_MODEL_FLAGS[$model]}"
    else
        # Unknown model name — pass through as-is (forward compat)
        _orch_router_log WARN "Unknown model '$model' for agent $agent_id — passing through"
        printf '%s\n' "$model"
    fi
}

# orch_router_model_name <agent_id>
#   Like orch_router_model but returns the abstract name (opus/sonnet/haiku)
#   instead of the flag. Useful for logging and display.
orch_router_model_name() {
    local agent_id="${1:?orch_router_model_name: agent_id required}"

    local env_key="${agent_id//-/_}"
    env_key="${env_key^^}"
    local override_var="ORCH_MODEL_OVERRIDE_${env_key}"

    if [[ -n "${!override_var:-}" ]]; then
        printf '%s\n' "${!override_var}"
    elif [[ -n "${ORCH_MODEL_CLI_OVERRIDE:-}" ]]; then
        printf '%s\n' "$ORCH_MODEL_CLI_OVERRIDE"
    elif [[ -n "${_ORCH_ROUTER_MODEL[$agent_id]+x}" ]]; then
        printf '%s\n' "${_ORCH_ROUTER_MODEL[$agent_id]}"
    else
        printf '%s\n' "$_ORCH_DEFAULT_MODEL"
    fi
}

# orch_router_model_fallback <model_name>
#   Returns the next cheaper model for fallback retries.
#   opus -> sonnet -> haiku -> "" (no fallback).
orch_router_model_fallback() {
    local model="${1:?orch_router_model_fallback: model required}"
    case "$model" in
        opus|claude-opus-4-6)       printf 'sonnet\n' ;;
        sonnet|claude-sonnet-4-6)   printf 'haiku\n' ;;
        *)                          printf '' ;;
    esac
}

# orch_router_is_rate_limited <log_file>
#   Check if a log file contains rate-limit indicators.
#   Returns 0 if rate-limited, 1 otherwise.
orch_router_is_rate_limited() {
    local log_file="${1:-}"
    [[ -z "$log_file" || ! -f "$log_file" ]] && return 1
    grep -qiE "rate.?limit|429|too many requests|overloaded|capacity|quota exceeded" "$log_file" 2>/dev/null
}

# orch_router_fallback_flag <model_name>
#   Convert abstract model name to CLI flag. Convenience for fallback callers.
orch_router_fallback_flag() {
    local model="${1:?orch_router_fallback_flag: model required}"
    if [[ -n "${_ORCH_MODEL_FLAGS[$model]+x}" ]]; then
        printf '%s\n' "${_ORCH_MODEL_FLAGS[$model]}"
    else
        printf '%s\n' "$model"
    fi
}

# orch_router_try_with_fallback <agent_id> <run_cmd_func> [max_attempts]
#   Run a command function with automatic model fallback on rate-limit.
#   run_cmd_func is called as: $run_cmd_func <model_flag> <log_file>
#   Returns the exit code of the last attempt. Sets ORCH_FALLBACK_MODEL
#   to the model name that was actually used.
#   max_attempts defaults to 3 (primary + 2 fallbacks).
declare -g ORCH_FALLBACK_MODEL=""
orch_router_try_with_fallback() {
    local agent_id="${1:?orch_router_try_with_fallback: agent_id required}"
    local run_cmd="${2:?orch_router_try_with_fallback: run_cmd function required}"
    local max_attempts="${3:-3}"
    local log_file="${4:-/dev/null}"

    local model_name
    model_name=$(orch_router_model_name "$agent_id" 2>/dev/null) || model_name="opus"
    local attempt=0
    local exit_code=1

    while [[ $attempt -lt $max_attempts ]]; do
        local model_flag
        model_flag=$(orch_router_fallback_flag "$model_name" 2>/dev/null) || model_flag="$model_name"
        ORCH_FALLBACK_MODEL="$model_name"

        if [[ $attempt -gt 0 ]]; then
            _orch_router_log INFO "Fallback attempt $((attempt+1)): $agent_id using $model_name ($model_flag)"
        fi

        exit_code=0
        $run_cmd "$model_flag" "$log_file" || exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            break
        fi

        # Check if it was a rate limit
        if orch_router_is_rate_limited "$log_file"; then
            local next_model
            next_model=$(orch_router_model_fallback "$model_name" 2>/dev/null)
            if [[ -z "$next_model" ]]; then
                _orch_router_log WARN "No fallback available after $model_name for $agent_id"
                break
            fi
            model_name="$next_model"
        else
            break
        fi

        attempt=$((attempt + 1))
    done

    return $exit_code
}

# orch_router_dump
#   Debug: print all router state.
orch_router_dump() {
    printf 'dynamic-router state (%d agents):\n' "${#_ORCH_ROUTER_AGENTS[@]}"
    printf '%-12s %-4s %-5s %-8s %-8s %-5s %-7s %s\n' \
        "AGENT" "PRI" "INTV" "EFF_INTV" "LAST_OUT" "EMPTY" "MODEL" "DEPENDS"
    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        printf '%-12s %-4s %-5s %-8s %-8s %-5s %-7s %s\n' \
            "$id" \
            "${_ORCH_ROUTER_PRIORITY[$id]:-5}" \
            "${_ORCH_ROUTER_INTERVAL[$id]:-1}" \
            "${_ORCH_ROUTER_EFF_INTERVAL[$id]:-1}" \
            "${_ORCH_ROUTER_LAST_OUTCOME[$id]:-none}" \
            "${_ORCH_ROUTER_CONSEC_EMPTY[$id]:-0}" \
            "${_ORCH_ROUTER_MODEL[$id]:-$_ORCH_DEFAULT_MODEL}" \
            "${_ORCH_ROUTER_DEPENDS[$id]:-none}"
    done
}

# ══════════════════════════════════════════════════
# v0.3 Cost-Aware Routing
# ══════════════════════════════════════════════════

# orch_router_record_cost <agent_id> <tokens>
#   Record token cost for a completed run.
orch_router_record_cost() {
    local agent_id="${1:?orch_router_record_cost: agent_id required}"
    local tokens="${2:?orch_router_record_cost: tokens required}"

    [[ ! "$tokens" =~ ^[0-9]+$ ]] && {
        _orch_router_log WARN "Invalid token count for $agent_id: $tokens"
        return 1
    }

    _ORCH_ROUTER_COST_LAST["$agent_id"]="$tokens"
    _ORCH_ROUTER_COST_TOTAL["$agent_id"]=$(( ${_ORCH_ROUTER_COST_TOTAL[$agent_id]:-0} + tokens ))
    _ORCH_ROUTER_RUN_COUNT["$agent_id"]=$(( ${_ORCH_ROUTER_RUN_COUNT[$agent_id]:-0} + 1 ))
    return 0
}

# orch_router_record_latency <agent_id> <seconds>
#   Record execution latency for a completed run. Updates EMA-based p95 estimate.
orch_router_record_latency() {
    local agent_id="${1:?orch_router_record_latency: agent_id required}"
    local seconds="${2:?orch_router_record_latency: seconds required}"

    [[ ! "$seconds" =~ ^[0-9]+$ ]] && {
        _orch_router_log WARN "Invalid latency for $agent_id: $seconds"
        return 1
    }

    _ORCH_ROUTER_LATENCY_LAST["$agent_id"]="$seconds"
    _ORCH_ROUTER_LATENCY_TOTAL["$agent_id"]=$(( ${_ORCH_ROUTER_LATENCY_TOTAL[$agent_id]:-0} + seconds ))

    # EMA-based p95 estimate: track the max-leaning exponential moving average
    # alpha=0.3 for responsiveness; bias toward higher values for p95 approximation
    local prev_p95="${_ORCH_ROUTER_LATENCY_P95[$agent_id]:-0}"
    if [[ "$prev_p95" -eq 0 ]]; then
        _ORCH_ROUTER_LATENCY_P95["$agent_id"]="$seconds"
    else
        # Integer EMA: new = prev + alpha*(sample - prev), bias up for p95
        local sample="$seconds"
        [[ "$sample" -gt "$prev_p95" ]] && sample=$(( sample + (sample - prev_p95) / 2 ))
        local new_p95=$(( prev_p95 + (sample - prev_p95) * 3 / 10 ))
        [[ "$new_p95" -lt 1 ]] && new_p95=1
        _ORCH_ROUTER_LATENCY_P95["$agent_id"]="$new_p95"
    fi

    return 0
}

# orch_router_record_quality <agent_id> <score>
#   Record quality score (0-100) for a completed run. Updates rolling average.
orch_router_record_quality() {
    local agent_id="${1:?orch_router_record_quality: agent_id required}"
    local score="${2:?orch_router_record_quality: score required}"

    [[ ! "$score" =~ ^[0-9]+$ ]] && {
        _orch_router_log WARN "Invalid quality score for $agent_id: $score"
        return 1
    }
    [[ "$score" -gt 100 ]] && score=100

    _ORCH_ROUTER_QUALITY_LAST["$agent_id"]="$score"
    _ORCH_ROUTER_QUALITY_TOTAL["$agent_id"]=$(( ${_ORCH_ROUTER_QUALITY_TOTAL[$agent_id]:-0} + score ))

    local run_count="${_ORCH_ROUTER_RUN_COUNT[$agent_id]:-1}"
    [[ "$run_count" -lt 1 ]] && run_count=1
    _ORCH_ROUTER_QUALITY_AVG["$agent_id"]=$(( ${_ORCH_ROUTER_QUALITY_TOTAL[$agent_id]} / run_count ))

    return 0
}

# orch_router_agent_score <agent_id>
#   Print composite quality score (0-100) for an agent. -1 if no data.
orch_router_agent_score() {
    local agent_id="${1:?orch_router_agent_score: agent_id required}"
    local run_count="${_ORCH_ROUTER_RUN_COUNT[$agent_id]:-0}"

    if [[ "$run_count" -eq 0 ]]; then
        printf '%d\n' "-1"
        return 0
    fi

    printf '%d\n' "${_ORCH_ROUTER_QUALITY_AVG[$agent_id]:-0}"
}

# orch_router_cost_report
#   Print per-agent cost summary with model cost estimates.
orch_router_cost_report() {
    [[ "$_ORCH_ROUTER_LOADED" != "true" ]] && return 1

    printf 'cost-aware routing report:\n'
    printf '%-12s %-7s %-10s %-10s %-8s %-6s %-8s %s\n' \
        "AGENT" "MODEL" "TOKENS" "LAST_TOK" "RUNS" "Q_AVG" "P95_LAT" "EST_COST"

    local grand_total_cost=0

    for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
        local model="${_ORCH_ROUTER_MODEL[$id]:-$_ORCH_DEFAULT_MODEL}"
        local total_tokens="${_ORCH_ROUTER_COST_TOTAL[$id]:-0}"
        local last_tokens="${_ORCH_ROUTER_COST_LAST[$id]:-0}"
        local runs="${_ORCH_ROUTER_RUN_COUNT[$id]:-0}"
        local q_avg="${_ORCH_ROUTER_QUALITY_AVG[$id]:-0}"
        local p95="${_ORCH_ROUTER_LATENCY_P95[$id]:-0}"

        # Estimate cost in USD (tokens / 1M * cost_per_M)
        local cost_per_m="${_ORCH_MODEL_COST_PER_M[$model]:-3.00}"
        # Integer math: cost_cents = tokens * cost_per_m_cents / 1000000
        local cost_per_m_cents
        cost_per_m_cents=$(printf '%.0f' "$(echo "$cost_per_m * 100" | bc 2>/dev/null || echo "300")")
        local est_cost_cents=$(( total_tokens * cost_per_m_cents / 1000000 ))
        grand_total_cost=$((grand_total_cost + est_cost_cents))

        local est_display
        if [[ "$est_cost_cents" -lt 100 ]]; then
            est_display="\$0.${est_cost_cents}"
        else
            est_display="\$$(( est_cost_cents / 100 )).$(printf '%02d' $(( est_cost_cents % 100 )))"
        fi

        printf '%-12s %-7s %-10s %-10s %-8s %-6s %-8s %s\n' \
            "$id" "$model" "$total_tokens" "$last_tokens" "$runs" "$q_avg" "${p95}s" "$est_display"
    done

    local grand_display
    if [[ "$grand_total_cost" -lt 100 ]]; then
        grand_display="\$0.${grand_total_cost}"
    else
        grand_display="\$$(( grand_total_cost / 100 )).$(printf '%02d' $(( grand_total_cost % 100 )))"
    fi
    printf 'total estimated cost: %s\n' "$grand_display"
}

# orch_router_lock_tier <agent_id>
#   Lock an agent's model tier (prevent auto-promotion/demotion).
orch_router_lock_tier() {
    local agent_id="${1:?orch_router_lock_tier: agent_id required}"
    _ORCH_ROUTER_TIER_LOCKED["$agent_id"]=1
}

# orch_router_unlock_tier <agent_id>
#   Unlock an agent's model tier (allow auto-promotion/demotion).
orch_router_unlock_tier() {
    local agent_id="${1:?orch_router_unlock_tier: agent_id required}"
    _ORCH_ROUTER_TIER_LOCKED["$agent_id"]=0
}

# orch_router_auto_tier <agent_id>
#   Auto-promote or demote model tier based on quality score history.
#   Returns 0 if tier changed, 1 if no change.
#   Promotion: avg quality >= PROMOTE_THRESHOLD for MIN_RUNS → demote to cheaper model
#   Demotion: avg quality <= DEMOTE_THRESHOLD for MIN_RUNS → promote to better model
#   (High quality = agent does fine on cheaper model; low quality = needs better model)
orch_router_auto_tier() {
    local agent_id="${1:?orch_router_auto_tier: agent_id required}"

    # Skip locked agents
    [[ "${_ORCH_ROUTER_TIER_LOCKED[$agent_id]:-0}" == "1" ]] && return 1

    local run_count="${_ORCH_ROUTER_RUN_COUNT[$agent_id]:-0}"
    [[ "$run_count" -lt "$_ORCH_TIER_MIN_RUNS" ]] && return 1

    local q_avg="${_ORCH_ROUTER_QUALITY_AVG[$agent_id]:-50}"
    local current_model="${_ORCH_ROUTER_MODEL[$agent_id]:-$_ORCH_DEFAULT_MODEL}"

    # High quality → save cost by using cheaper model
    if [[ "$q_avg" -ge "$_ORCH_TIER_PROMOTE_THRESHOLD" ]]; then
        local cheaper
        cheaper=$(orch_router_model_fallback "$current_model" 2>/dev/null)
        if [[ -n "$cheaper" ]]; then
            _ORCH_ROUTER_MODEL["$agent_id"]="$cheaper"
            _orch_router_log INFO "Auto-tier: $agent_id demoted $current_model → $cheaper (quality=$q_avg >= $_ORCH_TIER_PROMOTE_THRESHOLD)"
            return 0
        fi
    fi

    # Low quality → use more capable model
    if [[ "$q_avg" -le "$_ORCH_TIER_DEMOTE_THRESHOLD" ]]; then
        local better=""
        case "$current_model" in
            haiku|claude-haiku-4-5)   better="sonnet" ;;
            sonnet|claude-sonnet-4-6) better="opus" ;;
        esac
        if [[ -n "$better" ]]; then
            _ORCH_ROUTER_MODEL["$agent_id"]="$better"
            _orch_router_log INFO "Auto-tier: $agent_id promoted $current_model → $better (quality=$q_avg <= $_ORCH_TIER_DEMOTE_THRESHOLD)"
            return 0
        fi
    fi

    return 1
}

# orch_router_save_state — updated to include v0.3 fields
# Override the v0.2 version with extended format
orch_router_save_state() {
    local state_file="${1:?orch_router_save_state: state_file required}"

    if ! mkdir -p "$(dirname "$state_file")"; then
        _orch_router_log ERROR "Failed to create state directory for: $state_file"
        return 1
    fi

    {
        printf '# dynamic-router state v0.3 — %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        for id in "${_ORCH_ROUTER_AGENTS[@]}"; do
            printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
                "$id" \
                "${_ORCH_ROUTER_LAST_RUN[$id]:-0}" \
                "${_ORCH_ROUTER_LAST_OUTCOME[$id]:-none}" \
                "${_ORCH_ROUTER_EFF_INTERVAL[$id]:-${_ORCH_ROUTER_INTERVAL[$id]:-1}}" \
                "${_ORCH_ROUTER_CONSEC_EMPTY[$id]:-0}" \
                "${_ORCH_ROUTER_COST_TOTAL[$id]:-0}" \
                "${_ORCH_ROUTER_RUN_COUNT[$id]:-0}" \
                "${_ORCH_ROUTER_LATENCY_TOTAL[$id]:-0}" \
                "${_ORCH_ROUTER_LATENCY_P95[$id]:-0}" \
                "${_ORCH_ROUTER_QUALITY_TOTAL[$id]:-0}" \
                "${_ORCH_ROUTER_QUALITY_AVG[$id]:-0}" \
                "${_ORCH_ROUTER_MODEL[$id]:-$_ORCH_DEFAULT_MODEL}"
        done
    } > "$state_file" || {
        _orch_router_log ERROR "Failed to write state file: $state_file"
        return 1
    }
}

# orch_router_load_state — updated to handle v0.3 extended format
# Backward compatible: extra fields are optional.
orch_router_load_state() {
    local state_file="${1:?orch_router_load_state: state_file required}"

    [[ ! -f "$state_file" ]] && return 0

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue

        IFS='|' read -r id last_run last_outcome eff_interval consec_empty \
            cost_total run_count latency_total latency_p95 quality_total quality_avg saved_model <<< "$line"
        id=$(_orch_router_trim "$id")

        [[ -z "${_ORCH_ROUTER_INTERVAL[$id]+x}" ]] && continue

        # DR-01: validate numeric fields before restoring
        [[ ! "$last_run" =~ ^[0-9]+$ ]] && continue
        [[ ! "$eff_interval" =~ ^[0-9]+$ ]] && continue
        [[ ! "$consec_empty" =~ ^[0-9]+$ ]] && continue

        _ORCH_ROUTER_LAST_RUN["$id"]="$last_run"
        _ORCH_ROUTER_LAST_OUTCOME["$id"]="$last_outcome"
        _ORCH_ROUTER_EFF_INTERVAL["$id"]="$eff_interval"
        _ORCH_ROUTER_CONSEC_EMPTY["$id"]="$consec_empty"

        # v0.3 fields (optional — backward compat with v0.2 state files)
        if [[ -n "${cost_total:-}" && "$cost_total" =~ ^[0-9]+$ ]]; then
            _ORCH_ROUTER_COST_TOTAL["$id"]="$cost_total"
        fi
        if [[ -n "${run_count:-}" && "$run_count" =~ ^[0-9]+$ ]]; then
            _ORCH_ROUTER_RUN_COUNT["$id"]="$run_count"
        fi
        if [[ -n "${latency_total:-}" && "$latency_total" =~ ^[0-9]+$ ]]; then
            _ORCH_ROUTER_LATENCY_TOTAL["$id"]="$latency_total"
        fi
        if [[ -n "${latency_p95:-}" && "$latency_p95" =~ ^[0-9]+$ ]]; then
            _ORCH_ROUTER_LATENCY_P95["$id"]="$latency_p95"
        fi
        if [[ -n "${quality_total:-}" && "$quality_total" =~ ^[0-9]+$ ]]; then
            _ORCH_ROUTER_QUALITY_TOTAL["$id"]="$quality_total"
        fi
        if [[ -n "${quality_avg:-}" && "$quality_avg" =~ ^[0-9]+$ ]]; then
            _ORCH_ROUTER_QUALITY_AVG["$id"]="$quality_avg"
        fi
        if [[ -n "${saved_model:-}" ]]; then
            saved_model=$(_orch_router_trim "$saved_model")
            [[ -n "$saved_model" ]] && _ORCH_ROUTER_MODEL["$id"]="$saved_model"
        fi
    done < "$state_file"
}
