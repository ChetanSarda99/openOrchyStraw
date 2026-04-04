#!/usr/bin/env bash
# =============================================================================
# task-decomposer.sh — Progressive task decomposition for OrchyStraw (#50)
#
# Breaks large agent task lists into prioritized chunks that fit within
# a token budget. When an agent has too many tasks, this module selects
# the highest-priority subset and defers the rest to the next cycle.
#
# v0.4.0 additions:
#   - Priority-weighted decomposition (weight = priority * effort)
#   - Dependency DAG (task A blocks task B)
#   - Effort estimation (S/M/L/XL t-shirt sizing)
#   - Parallel task identification (tasks with no mutual dependencies)
#
# Usage:
#   source src/core/task-decomposer.sh
#
#   # Parse tasks from a prompt file (looks for markdown task lists)
#   orch_decompose_tasks "prompts/06-backend/06-backend.txt" 3
#   # Returns: top 3 tasks by priority, writes deferred tasks to context
#
#   # Or manually provide tasks
#   orch_select_tasks "$max_tasks" "P0:fix eval bug" "P1:add logging" "P2:refactor"
#
#   # v0.4: Weighted decomposition with effort + dependencies
#   orch_task_set_effort "fix eval bug" "S"
#   orch_task_add_dep "add logging" "fix eval bug"
#   orch_weighted_select 3
#   orch_parallel_tasks          # → tasks that can run concurrently
#   orch_task_dag_report
#
# Task format: "PRIORITY:description" where PRIORITY is P0/P1/P2/P3
# Extended: "PRIORITY:description:EFFORT" where EFFORT is S/M/L/XL
# Dependency: "PRIORITY:description:EFFORT:dep1,dep2"
# P0 = critical (always included), P1 = high, P2 = medium, P3 = low
#
# Requires: bash 5.0+
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_TASK_DECOMPOSER_LOADED:-}" ]] && return 0
readonly _ORCH_TASK_DECOMPOSER_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g -a _ORCH_SELECTED_TASKS=()
declare -g -a _ORCH_DEFERRED_TASKS=()
declare -g -a _ORCH_PARALLEL_TASKS=()

# Default max tasks per agent per cycle (configurable via env)
declare -g _ORCH_MAX_TASKS_PER_AGENT="${ORCH_MAX_TASKS_PER_AGENT:-5}"

# v0.4: Effort estimates and dependency DAG
declare -g -A _ORCH_TASK_EFFORT=()      # "description" -> S/M/L/XL
declare -g -A _ORCH_TASK_DEPS=()        # "description" -> "dep1,dep2"
declare -g -A _ORCH_TASK_WEIGHTS=()     # "description" -> numeric weight
declare -g -A _ORCH_TASK_PRIORITY=()    # "description" -> 0-3

# ---------------------------------------------------------------------------
# _orch_task_priority — extract numeric priority from "P0:description"
# Returns: 0-3 (lower = higher priority)
# ---------------------------------------------------------------------------
_orch_task_priority() {
    local task="$1"
    case "${task%%:*}" in
        P0|p0) echo 0 ;;
        P1|p1) echo 1 ;;
        P2|p2) echo 2 ;;
        P3|p3) echo 3 ;;
        *)     echo 2 ;;  # Default to P2 if no priority prefix
    esac
}

# ---------------------------------------------------------------------------
# _orch_task_description — extract description from "P0:description"
# ---------------------------------------------------------------------------
_orch_task_description() {
    local task="$1"
    if [[ "$task" == *:* ]]; then
        echo "${task#*:}"
    else
        echo "$task"
    fi
}

# ---------------------------------------------------------------------------
# orch_select_tasks — select top N tasks by priority
#
# Args:
#   $1 — max tasks to select (0 = use default)
#   $2+ — task strings in "PRIORITY:description" format
#
# Sets:
#   _ORCH_SELECTED_TASKS — array of selected task descriptions
#   _ORCH_DEFERRED_TASKS — array of deferred task descriptions
# ---------------------------------------------------------------------------
orch_select_tasks() {
    local max_tasks="${1:-$_ORCH_MAX_TASKS_PER_AGENT}"
    shift
    [[ $max_tasks -eq 0 ]] && max_tasks="$_ORCH_MAX_TASKS_PER_AGENT"

    _ORCH_SELECTED_TASKS=()
    _ORCH_DEFERRED_TASKS=()

    # No tasks? Nothing to do
    [[ $# -eq 0 ]] && return 0

    # Sort tasks by priority (P0 first, P3 last)
    # We use a simple insertion sort since task lists are small (<20)
    local -a sorted=()
    local -a priorities=()
    local i j task pri

    for task in "$@"; do
        pri=$(_orch_task_priority "$task")
        # Find insertion point
        local inserted=false
        for ((j=0; j<${#sorted[@]}; j++)); do
            if [[ $pri -lt ${priorities[$j]} ]]; then
                # Insert before j
                sorted=("${sorted[@]:0:$j}" "$task" "${sorted[@]:$j}")
                priorities=("${priorities[@]:0:$j}" "$pri" "${priorities[@]:$j}")
                inserted=true
                break
            fi
        done
        if [[ "$inserted" == "false" ]]; then
            sorted+=("$task")
            priorities+=("$pri")
        fi
    done

    # P0 tasks are always included (don't count toward limit)
    local p0_count=0
    for ((i=0; i<${#sorted[@]}; i++)); do
        if [[ ${priorities[$i]} -eq 0 ]]; then
            _ORCH_SELECTED_TASKS+=("$(_orch_task_description "${sorted[$i]}")")
            p0_count=$((p0_count + 1))
        fi
    done

    # Fill remaining slots from P1+ tasks (P0s don't count against limit)
    local slots=$max_tasks

    local non_p0_added=0
    for ((i=0; i<${#sorted[@]}; i++)); do
        [[ ${priorities[$i]} -eq 0 ]] && continue  # Already added P0s
        if [[ $non_p0_added -lt $slots ]]; then
            _ORCH_SELECTED_TASKS+=("$(_orch_task_description "${sorted[$i]}")")
            non_p0_added=$((non_p0_added + 1))
        else
            _ORCH_DEFERRED_TASKS+=("$(_orch_task_description "${sorted[$i]}")")
        fi
    done
}

# ---------------------------------------------------------------------------
# orch_extract_tasks — parse tasks from a markdown prompt file
#
# Looks for lines matching:
#   - **P0:** description    or    - P0: description
#   - [ ] P1: description    or    1. P1: description
#   - description (no priority — defaults to P2)
#
# Only extracts from "Current Tasks" / "Your Tasks" / "Tasks" sections
#
# Args: $1 — path to prompt file
# Returns: tasks on stdout, one per line, in "PRIORITY:description" format
# ---------------------------------------------------------------------------
orch_extract_tasks() {
    local prompt_file="$1"
    [[ ! -f "$prompt_file" ]] && return 1

    local in_task_section=false
    local line

    while IFS= read -r line; do
        # Detect task section headers
        if [[ "$line" =~ ^##.*[Tt]ask ]] || [[ "$line" =~ ^##.*TODO ]] || [[ "$line" =~ ^##.*CURRENT ]]; then
            in_task_section=true
            continue
        fi

        # Exit task section on next ## header
        if [[ "$in_task_section" == "true" ]] && [[ "$line" =~ ^## ]] && ! [[ "$line" =~ [Tt]ask ]]; then
            in_task_section=false
            continue
        fi

        if [[ "$in_task_section" == "true" ]]; then
            # Match task lines: "- **P0:** desc" or "- P0: desc" or "- [ ] desc"
            if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+\*\*([Pp][0-3]):\*\*[[:space:]]*(.*) ]]; then
                echo "${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+([Pp][0-3]):[[:space:]]*(.*) ]]; then
                echo "${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+\[.\][[:space:]]*(.*) ]]; then
                echo "P2:${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+(.*) ]]; then
                echo "P2:${BASH_REMATCH[1]}"
            fi
        fi
    done < "$prompt_file"
}

# ---------------------------------------------------------------------------
# orch_decompose_tasks — full pipeline: extract + select + report
#
# Args:
#   $1 — prompt file path
#   $2 — max tasks (optional, default _ORCH_MAX_TASKS_PER_AGENT)
#
# Sets _ORCH_SELECTED_TASKS and _ORCH_DEFERRED_TASKS
# ---------------------------------------------------------------------------
orch_decompose_tasks() {
    local prompt_file="$1"
    local max_tasks="${2:-$_ORCH_MAX_TASKS_PER_AGENT}"

    local -a tasks=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && tasks+=("$line")
    done < <(orch_extract_tasks "$prompt_file")

    orch_select_tasks "$max_tasks" "${tasks[@]}"
}

# ---------------------------------------------------------------------------
# orch_selected_count / orch_deferred_count — convenience getters
# ---------------------------------------------------------------------------
orch_selected_count() { echo "${#_ORCH_SELECTED_TASKS[@]}"; }
orch_deferred_count() { echo "${#_ORCH_DEFERRED_TASKS[@]}"; }

# ---------------------------------------------------------------------------
# orch_task_report — print selected/deferred summary
# ---------------------------------------------------------------------------
orch_task_report() {
    local agent_id="${1:-agent}"
    echo "[$agent_id] Task decomposition: ${#_ORCH_SELECTED_TASKS[@]} selected, ${#_ORCH_DEFERRED_TASKS[@]} deferred"

    if [[ ${#_ORCH_SELECTED_TASKS[@]} -gt 0 ]]; then
        echo "  Selected:"
        for task in "${_ORCH_SELECTED_TASKS[@]}"; do
            echo "    - $task"
        done
    fi

    if [[ ${#_ORCH_DEFERRED_TASKS[@]} -gt 0 ]]; then
        echo "  Deferred to next cycle:"
        for task in "${_ORCH_DEFERRED_TASKS[@]}"; do
            echo "    - $task"
        done
    fi
}

# ===========================================================================
# v0.4.0 — Priority-weighted decomposition, Dependency DAG, Effort, Parallel
# ===========================================================================

# ---------------------------------------------------------------------------
# _orch_effort_to_points — convert t-shirt size to numeric effort points
# S=1, M=2, L=4, XL=8 (Fibonacci-ish)
# ---------------------------------------------------------------------------
_orch_effort_to_points() {
    case "${1^^}" in
        S)  echo 1 ;;
        M)  echo 2 ;;
        L)  echo 4 ;;
        XL) echo 8 ;;
        *)  echo 2 ;;  # Default to M
    esac
}

# ---------------------------------------------------------------------------
# orch_task_set_effort — set effort estimate for a task
# Args: $1 — task description, $2 — effort (S/M/L/XL)
# ---------------------------------------------------------------------------
orch_task_set_effort() {
    local desc="${1:?orch_task_set_effort: description required}"
    local effort="${2:-M}"

    case "${effort^^}" in
        S|M|L|XL) ;;
        *) effort="M" ;;
    esac

    _ORCH_TASK_EFFORT["$desc"]="${effort^^}"
}

# ---------------------------------------------------------------------------
# orch_task_get_effort — get effort for a task (default M)
# ---------------------------------------------------------------------------
orch_task_get_effort() {
    local desc="${1:?orch_task_get_effort: description required}"
    echo "${_ORCH_TASK_EFFORT[$desc]:-M}"
}

# ---------------------------------------------------------------------------
# orch_task_add_dep — declare task dependency (A depends on B)
# Args: $1 — task description (dependent), $2 — task description (dependency)
# ---------------------------------------------------------------------------
orch_task_add_dep() {
    local task="${1:?orch_task_add_dep: task required}"
    local dep="${2:?orch_task_add_dep: dependency required}"

    local existing="${_ORCH_TASK_DEPS[$task]:-}"
    if [[ -z "$existing" ]]; then
        _ORCH_TASK_DEPS["$task"]="$dep"
    else
        # Avoid duplicate deps
        local IFS=','
        local -a deps_arr
        read -ra deps_arr <<< "$existing"
        for d in "${deps_arr[@]}"; do
            [[ "$d" == "$dep" ]] && return 0
        done
        _ORCH_TASK_DEPS["$task"]="${existing},${dep}"
    fi
}

# ---------------------------------------------------------------------------
# orch_task_get_deps — get dependencies for a task (comma-separated)
# ---------------------------------------------------------------------------
orch_task_get_deps() {
    local desc="${1:?orch_task_get_deps: description required}"
    echo "${_ORCH_TASK_DEPS[$desc]:-}"
}

# ---------------------------------------------------------------------------
# orch_task_has_cycle — detect cycles in the dependency DAG
# Returns: 0 if cycle found (bad), 1 if acyclic (good)
# ---------------------------------------------------------------------------
orch_task_has_cycle() {
    local -A visited=()
    local -A in_stack=()

    _orch_dfs_visit() {
        local node="$1"
        [[ -n "${in_stack[$node]+x}" ]] && return 0  # Cycle found
        [[ -n "${visited[$node]+x}" ]] && return 1    # Already done
        visited["$node"]=1
        in_stack["$node"]=1

        local deps="${_ORCH_TASK_DEPS[$node]:-}"
        if [[ -n "$deps" ]]; then
            local IFS=','
            local -a dep_arr
            read -ra dep_arr <<< "$deps"
            for d in "${dep_arr[@]}"; do
                _orch_dfs_visit "$d" && return 0
            done
        fi

        unset 'in_stack[$node]'
        return 1
    }

    local task
    for task in "${!_ORCH_TASK_DEPS[@]}"; do
        visited=()
        in_stack=()
        _orch_dfs_visit "$task" && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# _orch_task_compute_weight — compute priority-weighted score for a task
# Weight = (4 - priority) * effort_points (higher = more important/costly)
# For scheduling: higher weight = should be done first
# ---------------------------------------------------------------------------
_orch_task_compute_weight() {
    local desc="$1"
    local pri="${_ORCH_TASK_PRIORITY[$desc]:-2}"
    local effort="${_ORCH_TASK_EFFORT[$desc]:-M}"
    local effort_pts
    effort_pts=$(_orch_effort_to_points "$effort")

    # Weight formula: priority importance * effort awareness
    # (4-pri) maps P0=4, P1=3, P2=2, P3=1
    local weight=$(( (4 - pri) * 3 + effort_pts ))
    _ORCH_TASK_WEIGHTS["$desc"]=$weight
    echo "$weight"
}

# ---------------------------------------------------------------------------
# orch_weighted_select — select tasks using priority-weighted scoring
#
# Unlike orch_select_tasks which uses simple priority ordering, this uses
# a composite weight = f(priority, effort) and respects dependency ordering.
# Tasks whose dependencies are not selected get deferred.
#
# Args: $1 — max tasks to select (0 = use default)
# Prerequisite: call orch_select_tasks first to populate task lists,
#               then call orch_task_set_effort / orch_task_add_dep as needed
# Sets: _ORCH_SELECTED_TASKS, _ORCH_DEFERRED_TASKS (re-sorted)
# ---------------------------------------------------------------------------
orch_weighted_select() {
    local max_tasks="${1:-$_ORCH_MAX_TASKS_PER_AGENT}"
    [[ $max_tasks -eq 0 ]] && max_tasks="$_ORCH_MAX_TASKS_PER_AGENT"

    # Gather all tasks (selected + deferred from prior call)
    local -a all_tasks=()
    local task
    for task in "${_ORCH_SELECTED_TASKS[@]}"; do
        [[ -n "$task" ]] && all_tasks+=("$task")
    done
    for task in "${_ORCH_DEFERRED_TASKS[@]}"; do
        [[ -n "$task" ]] && all_tasks+=("$task")
    done

    [[ ${#all_tasks[@]} -eq 0 ]] && return 0

    # Compute weights
    for task in "${all_tasks[@]}"; do
        _orch_task_compute_weight "$task" > /dev/null
    done

    # Sort by weight (descending — highest weight first)
    local -a sorted=()
    local -a sort_weights=()
    local i j w

    for task in "${all_tasks[@]}"; do
        w="${_ORCH_TASK_WEIGHTS[$task]:-0}"
        local inserted=false
        for ((j=0; j<${#sorted[@]}; j++)); do
            if [[ $w -gt ${sort_weights[$j]} ]]; then
                sorted=("${sorted[@]:0:$j}" "$task" "${sorted[@]:$j}")
                sort_weights=("${sort_weights[@]:0:$j}" "$w" "${sort_weights[@]:$j}")
                inserted=true
                break
            fi
        done
        if [[ "$inserted" == "false" ]]; then
            sorted+=("$task")
            sort_weights+=("$w")
        fi
    done

    # Select tasks respecting dependency constraints
    local -A selected_set=()
    _ORCH_SELECTED_TASKS=()
    _ORCH_DEFERRED_TASKS=()

    local -a p0_tasks=()
    for task in "${sorted[@]}"; do
        local pri="${_ORCH_TASK_PRIORITY[$task]:-2}"
        [[ "$pri" -eq 0 ]] && p0_tasks+=("$task")
    done

    # P0 tasks always selected
    for task in "${p0_tasks[@]}"; do
        _ORCH_SELECTED_TASKS+=("$task")
        selected_set["$task"]=1
    done

    # Fill remaining slots
    local slots=$max_tasks
    local non_p0_added=0
    for task in "${sorted[@]}"; do
        [[ -n "${selected_set[$task]+x}" ]] && continue
        [[ $non_p0_added -ge $slots ]] && { _ORCH_DEFERRED_TASKS+=("$task"); continue; }

        # Check if all dependencies are in selected set
        local deps="${_ORCH_TASK_DEPS[$task]:-}"
        local deps_met=true
        if [[ -n "$deps" ]]; then
            local IFS=','
            local -a dep_arr
            read -ra dep_arr <<< "$deps"
            for d in "${dep_arr[@]}"; do
                if [[ -z "${selected_set[$d]+x}" ]]; then
                    deps_met=false
                    break
                fi
            done
        fi

        if [[ "$deps_met" == "true" ]]; then
            _ORCH_SELECTED_TASKS+=("$task")
            selected_set["$task"]=1
            non_p0_added=$((non_p0_added + 1))
        else
            _ORCH_DEFERRED_TASKS+=("$task")
        fi
    done
}

# ---------------------------------------------------------------------------
# orch_parallel_tasks — identify tasks that can run in parallel
#
# Two tasks can run in parallel if neither depends on the other (directly
# or transitively). Only considers currently selected tasks.
#
# Sets: _ORCH_PARALLEL_TASKS (array of "taskA|taskB" pairs)
# ---------------------------------------------------------------------------
orch_parallel_tasks() {
    _ORCH_PARALLEL_TASKS=()

    local -a tasks=("${_ORCH_SELECTED_TASKS[@]}")
    local n=${#tasks[@]}
    [[ $n -lt 2 ]] && return 0

    # Build transitive dependency closure for each task
    _orch_all_deps() {
        local task="$1"
        local -A seen=()
        local -a queue=("$task")
        while [[ ${#queue[@]} -gt 0 ]]; do
            local current="${queue[0]}"
            queue=("${queue[@]:1}")
            local deps="${_ORCH_TASK_DEPS[$current]:-}"
            if [[ -n "$deps" ]]; then
                local IFS=','
                local -a dep_arr
                read -ra dep_arr <<< "$deps"
                for d in "${dep_arr[@]}"; do
                    if [[ -z "${seen[$d]+x}" ]]; then
                        seen["$d"]=1
                        queue+=("$d")
                    fi
                done
            fi
        done
        local IFS=','
        echo "${!seen[*]}"
    }

    local i j
    for ((i=0; i<n; i++)); do
        local deps_i
        deps_i=$(_orch_all_deps "${tasks[$i]}")
        for ((j=i+1; j<n; j++)); do
            local deps_j
            deps_j=$(_orch_all_deps "${tasks[$j]}")

            # Check: neither depends on the other
            local has_dep=false
            if [[ ",$deps_i," == *",${tasks[$j]},"* ]] || [[ ",$deps_j," == *",${tasks[$i]},"* ]]; then
                has_dep=true
            fi

            if [[ "$has_dep" == "false" ]]; then
                _ORCH_PARALLEL_TASKS+=("${tasks[$i]}|${tasks[$j]}")
            fi
        done
    done
}

# ---------------------------------------------------------------------------
# orch_parallel_count — number of parallelizable task pairs
# ---------------------------------------------------------------------------
orch_parallel_count() { echo "${#_ORCH_PARALLEL_TASKS[@]}"; }

# ---------------------------------------------------------------------------
# orch_task_dag_report — print DAG info (deps, weights, parallel groups)
# ---------------------------------------------------------------------------
orch_task_dag_report() {
    local agent_id="${1:-agent}"
    echo "[$agent_id] Task DAG Report"
    echo "  Tasks with effort estimates:"

    local task
    for task in "${_ORCH_SELECTED_TASKS[@]}"; do
        local effort="${_ORCH_TASK_EFFORT[$task]:-M}"
        local weight="${_ORCH_TASK_WEIGHTS[$task]:-?}"
        local deps="${_ORCH_TASK_DEPS[$task]:-none}"
        printf '    - %s [effort=%s weight=%s deps=%s]\n' "$task" "$effort" "$weight" "$deps"
    done

    if [[ ${#_ORCH_DEFERRED_TASKS[@]} -gt 0 ]]; then
        echo "  Deferred:"
        for task in "${_ORCH_DEFERRED_TASKS[@]}"; do
            local deps="${_ORCH_TASK_DEPS[$task]:-none}"
            printf '    - %s [deps=%s]\n' "$task" "$deps"
        done
    fi

    if [[ ${#_ORCH_PARALLEL_TASKS[@]} -gt 0 ]]; then
        echo "  Parallelizable pairs:"
        for pair in "${_ORCH_PARALLEL_TASKS[@]}"; do
            echo "    - ${pair//|/ <-> }"
        done
    fi
}

# ---------------------------------------------------------------------------
# orch_task_reset_dag — clear all DAG state (effort, deps, weights)
# ---------------------------------------------------------------------------
orch_task_reset_dag() {
    _ORCH_TASK_EFFORT=()
    _ORCH_TASK_DEPS=()
    _ORCH_TASK_WEIGHTS=()
    _ORCH_TASK_PRIORITY=()
    _ORCH_PARALLEL_TASKS=()
}

# ---------------------------------------------------------------------------
# orch_extract_tasks_extended — parse extended task format from markdown
#
# Extended format in markdown:
#   - **P0:** Fix bug [S]                     → P0:Fix bug:S
#   - P1: Add logging [M] (depends: Fix bug)  → P1:Add logging:M:Fix bug
#   - P2: Refactor [L]                        → P2:Refactor:L
#
# Also populates effort and dependency state.
# ---------------------------------------------------------------------------
orch_extract_tasks_extended() {
    local prompt_file="$1"
    [[ ! -f "$prompt_file" ]] && return 1

    orch_task_reset_dag

    local in_task_section=false
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^##.*[Tt]ask ]] || [[ "$line" =~ ^##.*TODO ]] || [[ "$line" =~ ^##.*CURRENT ]]; then
            in_task_section=true
            continue
        fi

        if [[ "$in_task_section" == "true" ]] && [[ "$line" =~ ^## ]] && ! [[ "$line" =~ [Tt]ask ]]; then
            in_task_section=false
            continue
        fi

        if [[ "$in_task_section" == "true" ]]; then
            local pri="" desc="" effort="M" deps=""

            # Match: - **P0:** desc [S] (depends: dep1, dep2)
            if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+\*\*([Pp][0-3]):\*\*[[:space:]]*(.*) ]]; then
                pri="${BASH_REMATCH[1]}"
                desc="${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+([Pp][0-3]):[[:space:]]*(.*) ]]; then
                pri="${BASH_REMATCH[1]}"
                desc="${BASH_REMATCH[2]}"
            elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+\[.\][[:space:]]*(.*) ]]; then
                pri="P2"
                desc="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+(.*) ]]; then
                pri="P2"
                desc="${BASH_REMATCH[1]}"
            fi

            [[ -z "$pri" ]] && continue

            # Extract effort tag [S/M/L/XL]
            if [[ "$desc" =~ \[([SMLXsmlx]+)\] ]]; then
                effort="${BASH_REMATCH[1]^^}"
                desc="${desc/\[${BASH_REMATCH[1]}\]/}"
            fi

            # Extract dependency annotation (depends: dep1, dep2)
            if [[ "$desc" =~ \(depends:[[:space:]]*(.*)\) ]]; then
                deps="${BASH_REMATCH[1]}"
                desc="${desc/\(depends: ${BASH_REMATCH[1]}\)/}"
                desc="${desc/\(depends:${BASH_REMATCH[1]}\)/}"
            fi

            # Trim trailing whitespace from desc
            desc="${desc%"${desc##*[![:space:]]}"}"
            desc="${desc#"${desc%%[![:space:]]*}"}"

            [[ -z "$desc" ]] && continue

            echo "${pri}:${desc}"

            # Store metadata
            local pri_num
            pri_num=$(_orch_task_priority "${pri}:${desc}")
            _ORCH_TASK_PRIORITY["$desc"]=$pri_num
            _ORCH_TASK_EFFORT["$desc"]="$effort"

            if [[ -n "$deps" ]]; then
                # Parse comma-separated deps
                local IFS=','
                local -a dep_arr
                read -ra dep_arr <<< "$deps"
                for d in "${dep_arr[@]}"; do
                    d="${d#"${d%%[![:space:]]*}"}"
                    d="${d%"${d##*[![:space:]]}"}"
                    [[ -n "$d" ]] && orch_task_add_dep "$desc" "$d"
                done
            fi
        fi
    done < "$prompt_file"
}

# ---------------------------------------------------------------------------
# orch_decompose_tasks_weighted — full pipeline with DAG support
# Args: $1 — prompt file, $2 — max tasks (optional)
# ---------------------------------------------------------------------------
orch_decompose_tasks_weighted() {
    local prompt_file="$1"
    local max_tasks="${2:-$_ORCH_MAX_TASKS_PER_AGENT}"

    local -a tasks=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && tasks+=("$line")
    done < <(orch_extract_tasks_extended "$prompt_file")

    orch_select_tasks "$max_tasks" "${tasks[@]}"
    orch_weighted_select "$max_tasks"
    orch_parallel_tasks
}
