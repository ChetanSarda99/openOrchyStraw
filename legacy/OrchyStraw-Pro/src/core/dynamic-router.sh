#!/usr/bin/env bash
# =============================================================================
# dynamic-router.sh — Dependency-aware parallel execution (#27)
#
# Parses a depends_on column from agents.conf, builds a dependency graph,
# performs topological sort into execution groups, and detects circular
# dependencies. Agents within the same group can run in parallel.
#
# Usage:
#   source src/core/dynamic-router.sh
#
#   orch_router_init
#   orch_router_add_agent "06-backend" "none" 5
#   orch_router_add_agent "09-qa" "06-backend,02-cto" 3
#   orch_router_add_agent "03-pm" "all" 10
#   orch_router_build_groups
#   orch_router_get_groups
#   orch_router_report
#
#   # Or parse directly from agents.conf:
#   orch_router_init
#   orch_router_parse_config "agents.conf"
#   orch_router_build_groups
#   orch_router_report
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_DYNAMIC_ROUTER_LOADED:-}" ]] && return 0
readonly _ORCH_DYNAMIC_ROUTER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_ROUTER_DEPS=()       # agent_id → "dep1,dep2" or "none"
declare -gA _ORCH_ROUTER_PRIORITY=()   # agent_id → integer
declare -gA _ORCH_ROUTER_GROUP=()      # agent_id → group number
declare -g  _ORCH_ROUTER_GROUP_COUNT=0
declare -ga _ORCH_ROUTER_GROUPS=()     # index=group_num, value=comma-separated agent IDs
declare -ga _ORCH_ROUTER_AGENTS=()     # ordered list of all registered agents

# ---------------------------------------------------------------------------
# orch_router_init — reset all state for a fresh routing pass
# ---------------------------------------------------------------------------
orch_router_init() {
    _ORCH_ROUTER_DEPS=()
    _ORCH_ROUTER_PRIORITY=()
    _ORCH_ROUTER_GROUP=()
    _ORCH_ROUTER_GROUP_COUNT=0
    _ORCH_ROUTER_GROUPS=()
    _ORCH_ROUTER_AGENTS=()
}

# ---------------------------------------------------------------------------
# orch_router_add_agent — register an agent with its dependencies and priority
#
# Args:
#   $1 — agent_id (e.g., "06-backend")
#   $2 — depends_on: comma-separated agent IDs, "none", or "all"
#   $3 — priority: integer, higher = more important (default 5)
# ---------------------------------------------------------------------------
orch_router_add_agent() {
    local agent_id="$1"
    local depends_on="${2:-none}"
    local priority="${3:-5}"

    [[ -z "$agent_id" ]] && return 1

    # Normalize whitespace
    depends_on=$(echo "$depends_on" | tr -d '[:space:]')
    [[ -z "$depends_on" ]] && depends_on="none"

    _ORCH_ROUTER_DEPS["$agent_id"]="$depends_on"
    _ORCH_ROUTER_PRIORITY["$agent_id"]="$priority"
    _ORCH_ROUTER_AGENTS+=("$agent_id")
}

# ---------------------------------------------------------------------------
# orch_router_parse_config — parse agents.conf to extract dependency info
#
# Current format (5-6 columns, pipe-delimited):
#   id | prompt | ownership | interval | label | model
#
# Extended format adds columns 7 and 8:
#   id | prompt | ownership | interval | label | model | priority | depends_on
#
# If priority/depends_on columns are missing, defaults are used:
#   priority=5, depends_on=none
#
# Args:
#   $1 — path to agents.conf
# ---------------------------------------------------------------------------
orch_router_parse_config() {
    local conf_file="$1"

    if [[ ! -f "$conf_file" ]]; then
        echo "dynamic-router: config file not found: $conf_file" >&2
        return 1
    fi

    local line
    while IFS= read -r line; do
        # Skip blank lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Split on pipe delimiter
        local -a fields=()
        IFS='|' read -ra fields <<< "$line"

        # Must have at least 5 columns (id, prompt, ownership, interval, label)
        [[ ${#fields[@]} -lt 5 ]] && continue

        # Trim whitespace from the agent ID (field 0)
        local agent_id
        agent_id=$(echo "${fields[0]}" | xargs)
        [[ -z "$agent_id" ]] && continue

        # Extract priority (field 6, 0-indexed) if present, default 5
        local priority=5
        if [[ ${#fields[@]} -ge 7 ]]; then
            local raw_priority
            raw_priority=$(echo "${fields[6]}" | xargs)
            if [[ "$raw_priority" =~ ^[0-9]+$ ]]; then
                priority="$raw_priority"
            fi
        fi

        # Extract depends_on (field 7, 0-indexed) if present, default none
        local depends_on="none"
        if [[ ${#fields[@]} -ge 8 ]]; then
            local raw_deps
            raw_deps=$(echo "${fields[7]}" | xargs)
            if [[ -n "$raw_deps" ]]; then
                depends_on="$raw_deps"
            fi
        fi

        orch_router_add_agent "$agent_id" "$depends_on" "$priority"
    done < "$conf_file"
}

# ---------------------------------------------------------------------------
# orch_router_has_cycle — detect circular dependencies via DFS
#
# Returns: 0 if cycle found (prints cycle path to stdout), 1 if clean
# ---------------------------------------------------------------------------
orch_router_has_cycle() {
    # DFS-based cycle detection
    # States: 0 = unvisited, 1 = in-progress, 2 = done
    local -A visit_state=()
    local -A parent=()
    local cycle_found=1  # 1 = no cycle (clean)

    # Initialize all agents as unvisited
    local agent
    for agent in "${_ORCH_ROUTER_AGENTS[@]}"; do
        visit_state["$agent"]=0
    done

    # DFS from each unvisited node
    _orch_router_dfs_visit() {
        local node="$1"
        visit_state["$node"]=1  # mark in-progress

        local deps="${_ORCH_ROUTER_DEPS[$node]:-none}"
        if [[ "$deps" != "none" && "$deps" != "all" ]]; then
            local -a dep_list=()
            IFS=',' read -ra dep_list <<< "$deps"

            local dep
            for dep in "${dep_list[@]}"; do
                dep=$(echo "$dep" | xargs)
                [[ -z "$dep" ]] && continue

                # Only check deps that are registered agents
                [[ -z "${_ORCH_ROUTER_DEPS[$dep]+x}" ]] && continue

                if [[ "${visit_state[$dep]}" -eq 1 ]]; then
                    # Found a cycle: reconstruct the path
                    echo "Cycle detected: $dep → $node → $dep"
                    cycle_found=0
                    return
                elif [[ "${visit_state[$dep]}" -eq 0 ]]; then
                    parent["$dep"]="$node"
                    _orch_router_dfs_visit "$dep"
                    [[ $cycle_found -eq 0 ]] && return
                fi
            done
        fi

        visit_state["$node"]=2  # mark done
    }

    for agent in "${_ORCH_ROUTER_AGENTS[@]}"; do
        if [[ "${visit_state[$agent]}" -eq 0 ]]; then
            _orch_router_dfs_visit "$agent"
            [[ $cycle_found -eq 0 ]] && break
        fi
    done

    unset -f _orch_router_dfs_visit
    return $cycle_found
}

# ---------------------------------------------------------------------------
# _orch_router_sort_by_priority — sort agent IDs by priority (descending)
#
# Args: comma-separated agent IDs
# Outputs: comma-separated agent IDs sorted by priority (descending)
# ---------------------------------------------------------------------------
_orch_router_sort_by_priority() {
    local agents_csv="$1"
    [[ -z "$agents_csv" ]] && return

    local -a agents=()
    IFS=',' read -ra agents <<< "$agents_csv"

    # Build sortable pairs: "priority:agent_id"
    local -a pairs=()
    local agent
    for agent in "${agents[@]}"; do
        agent=$(echo "$agent" | xargs)
        [[ -z "$agent" ]] && continue
        local pri="${_ORCH_ROUTER_PRIORITY[$agent]:-5}"
        pairs+=("${pri}:${agent}")
    done

    # Sort descending by priority (numeric), then alphabetically by name
    local sorted
    sorted=$(printf '%s\n' "${pairs[@]}" | sort -t: -k1,1nr -k2,2 | cut -d: -f2 | paste -sd,)
    echo "$sorted"
}

# ---------------------------------------------------------------------------
# orch_router_build_groups — topological sort into execution groups
#
# Algorithm:
#   1. Separate "all"-dependency agents (coordinators) — they go last
#   2. Build in-degree map (count of unresolved deps per agent)
#   3. Agents with in-degree 0 → group 0
#   4. Remove group 0, recalculate in-degrees
#   5. New in-degree 0 agents → group 1
#   6. Repeat until all assigned or cycle detected
#   7. Coordinators ("all") → final group
#   8. Within each group, sort by priority (descending)
#
# Returns: 0 on success, 1 if circular dependency detected
# ---------------------------------------------------------------------------
orch_router_build_groups() {
    _ORCH_ROUTER_GROUP=()
    _ORCH_ROUTER_GROUPS=()
    _ORCH_ROUTER_GROUP_COUNT=0

    local agent_count=${#_ORCH_ROUTER_AGENTS[@]}
    [[ $agent_count -eq 0 ]] && return 0

    # Check for cycles first
    local cycle_output
    cycle_output=$(orch_router_has_cycle)
    if [[ $? -eq 0 ]]; then
        echo "dynamic-router: cannot build groups — $cycle_output" >&2
        return 1
    fi

    # Separate coordinators (depends_on=all) from normal agents
    local -a coordinators=()
    local -a normal_agents=()
    local agent
    for agent in "${_ORCH_ROUTER_AGENTS[@]}"; do
        local deps="${_ORCH_ROUTER_DEPS[$agent]:-none}"
        if [[ "$deps" == "all" ]]; then
            coordinators+=("$agent")
        else
            normal_agents+=("$agent")
        fi
    done

    # Build in-degree map for normal agents
    local -A in_degree=()
    local -A assigned=()

    for agent in "${normal_agents[@]}"; do
        in_degree["$agent"]=0
        assigned["$agent"]=0
    done

    # Count incoming edges (only from registered normal agents)
    for agent in "${normal_agents[@]}"; do
        local deps="${_ORCH_ROUTER_DEPS[$agent]:-none}"
        [[ "$deps" == "none" ]] && continue

        local -a dep_list=()
        IFS=',' read -ra dep_list <<< "$deps"

        local dep
        for dep in "${dep_list[@]}"; do
            dep=$(echo "$dep" | xargs)
            [[ -z "$dep" ]] && continue

            # Only count deps that are registered normal agents
            if [[ -n "${in_degree[$dep]+x}" || -z "${_ORCH_ROUTER_DEPS[$dep]+x}" ]]; then
                # This agent depends on $dep, so increment agent's in-degree
                local current="${in_degree[$agent]:-0}"
                in_degree["$agent"]=$(( current + 1 ))
            fi
        done
    done

    # Recalculate: only count deps on agents that actually exist in the graph
    in_degree=()
    for agent in "${normal_agents[@]}"; do
        in_degree["$agent"]=0
    done

    for agent in "${normal_agents[@]}"; do
        local deps="${_ORCH_ROUTER_DEPS[$agent]:-none}"
        [[ "$deps" == "none" ]] && continue

        local -a dep_list=()
        IFS=',' read -ra dep_list <<< "$deps"

        local count=0
        local dep
        for dep in "${dep_list[@]}"; do
            dep=$(echo "$dep" | xargs)
            [[ -z "$dep" ]] && continue
            # Only count if dep is a registered normal agent
            if [[ -n "${in_degree[$dep]+x}" ]]; then
                count=$(( count + 1 ))
            fi
        done
        in_degree["$agent"]=$count
    done

    # Kahn's algorithm: iteratively extract zero in-degree nodes
    local group_num=0
    local assigned_count=0
    local total_normal=${#normal_agents[@]}

    while [[ $assigned_count -lt $total_normal ]]; do
        # Find all agents with in-degree 0 that are not yet assigned
        local -a zero_degree=()
        for agent in "${normal_agents[@]}"; do
            if [[ "${assigned[$agent]}" -eq 0 && "${in_degree[$agent]}" -eq 0 ]]; then
                zero_degree+=("$agent")
            fi
        done

        # If no zero-degree nodes remain but agents are unassigned, there's a cycle
        # (should not happen since we checked above, but guard anyway)
        if [[ ${#zero_degree[@]} -eq 0 && $assigned_count -lt $total_normal ]]; then
            echo "dynamic-router: unexpected cycle during group building" >&2
            return 1
        fi

        # Sort this group by priority
        local group_csv
        group_csv=$(IFS=,; echo "${zero_degree[*]}")
        local sorted_csv
        sorted_csv=$(_orch_router_sort_by_priority "$group_csv")

        # Assign group
        _ORCH_ROUTER_GROUPS[$group_num]="$sorted_csv"

        # Mark agents as assigned and record their group
        for agent in "${zero_degree[@]}"; do
            assigned["$agent"]=1
            _ORCH_ROUTER_GROUP["$agent"]=$group_num
            assigned_count=$(( assigned_count + 1 ))
        done

        # Decrease in-degrees of agents that depended on the just-assigned agents
        for agent in "${normal_agents[@]}"; do
            [[ "${assigned[$agent]}" -eq 1 ]] && continue

            local deps="${_ORCH_ROUTER_DEPS[$agent]:-none}"
            [[ "$deps" == "none" ]] && continue

            local -a dep_list=()
            IFS=',' read -ra dep_list <<< "$deps"

            local dep
            for dep in "${dep_list[@]}"; do
                dep=$(echo "$dep" | xargs)
                [[ -z "$dep" ]] && continue

                # If this dependency was just assigned, decrement in-degree
                if [[ "${assigned[$dep]:-0}" -eq 1 ]]; then
                    # Check it was assigned in THIS round
                    local was_in_this_group=0
                    local z
                    for z in "${zero_degree[@]}"; do
                        [[ "$z" == "$dep" ]] && was_in_this_group=1 && break
                    done
                    if [[ $was_in_this_group -eq 1 ]]; then
                        in_degree["$agent"]=$(( ${in_degree[$agent]} - 1 ))
                    fi
                fi
            done
        done

        group_num=$(( group_num + 1 ))
    done

    # Add coordinators to the final group
    if [[ ${#coordinators[@]} -gt 0 ]]; then
        local coord_csv
        coord_csv=$(IFS=,; echo "${coordinators[*]}")
        local sorted_coords
        sorted_coords=$(_orch_router_sort_by_priority "$coord_csv")

        _ORCH_ROUTER_GROUPS[$group_num]="$sorted_coords"

        for agent in "${coordinators[@]}"; do
            _ORCH_ROUTER_GROUP["$agent"]=$group_num
        done

        group_num=$(( group_num + 1 ))
    fi

    _ORCH_ROUTER_GROUP_COUNT=$group_num
    return 0
}

# ---------------------------------------------------------------------------
# orch_router_get_groups — return newline-separated groups
#
# Each line is a comma-separated list of agent IDs in that group.
# Groups are in execution order (group 0 first, last group last).
# ---------------------------------------------------------------------------
orch_router_get_groups() {
    local i
    for (( i = 0; i < _ORCH_ROUTER_GROUP_COUNT; i++ )); do
        echo "${_ORCH_ROUTER_GROUPS[$i]}"
    done
}

# ---------------------------------------------------------------------------
# orch_router_get_group — return group number for an agent
#
# Args: $1 — agent_id
# Outputs: group number, or -1 if agent not found
# ---------------------------------------------------------------------------
orch_router_get_group() {
    local agent_id="$1"
    echo "${_ORCH_ROUTER_GROUP[$agent_id]:--1}"
}

# ---------------------------------------------------------------------------
# orch_router_get_priority — return priority for an agent
#
# Args: $1 — agent_id
# Outputs: priority integer, or 5 (default) if not found
# ---------------------------------------------------------------------------
orch_router_get_priority() {
    local agent_id="$1"
    echo "${_ORCH_ROUTER_PRIORITY[$agent_id]:-5}"
}

# ---------------------------------------------------------------------------
# orch_router_get_deps — return comma-separated dependencies for an agent
#
# Args: $1 — agent_id
# Outputs: dependency string, or "none" if not found
# ---------------------------------------------------------------------------
orch_router_get_deps() {
    local agent_id="$1"
    echo "${_ORCH_ROUTER_DEPS[$agent_id]:-none}"
}

# ---------------------------------------------------------------------------
# orch_router_group_count — return the total number of execution groups
# ---------------------------------------------------------------------------
orch_router_group_count() {
    echo "$_ORCH_ROUTER_GROUP_COUNT"
}

# ---------------------------------------------------------------------------
# orch_router_report — print formatted report of execution groups
# ---------------------------------------------------------------------------
orch_router_report() {
    echo "Dynamic Router — Execution Groups"
    echo "  Agents: ${#_ORCH_ROUTER_AGENTS[@]}  |  Groups: $_ORCH_ROUTER_GROUP_COUNT"
    echo ""

    local i
    for (( i = 0; i < _ORCH_ROUTER_GROUP_COUNT; i++ )); do
        local group_agents="${_ORCH_ROUTER_GROUPS[$i]}"
        local label="parallel"

        # Check if this is the last group with coordinators
        if [[ $i -eq $(( _ORCH_ROUTER_GROUP_COUNT - 1 )) ]]; then
            # Check if any agent in this group has depends_on=all
            local -a agents_in_group=()
            IFS=',' read -ra agents_in_group <<< "$group_agents"
            local a
            for a in "${agents_in_group[@]}"; do
                a=$(echo "$a" | xargs)
                if [[ "${_ORCH_ROUTER_DEPS[$a]:-none}" == "all" ]]; then
                    label="coordinator (runs last)"
                    break
                fi
            done
        fi

        echo "  Group $i ($label):"

        local -a agents_in_group=()
        IFS=',' read -ra agents_in_group <<< "$group_agents"
        local agent
        for agent in "${agents_in_group[@]}"; do
            agent=$(echo "$agent" | xargs)
            [[ -z "$agent" ]] && continue
            local pri="${_ORCH_ROUTER_PRIORITY[$agent]:-5}"
            local deps="${_ORCH_ROUTER_DEPS[$agent]:-none}"
            echo "    - $agent  (priority: $pri, depends_on: $deps)"
        done
        echo ""
    done
}
