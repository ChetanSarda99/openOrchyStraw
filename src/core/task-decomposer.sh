#!/usr/bin/env bash
# =============================================================================
# task-decomposer.sh — Progressive task decomposition for OrchyStraw (#50)
#
# Breaks large agent task lists into prioritized chunks that fit within
# a token budget. When an agent has too many tasks, this module selects
# the highest-priority subset and defers the rest to the next cycle.
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
# Task format: "PRIORITY:description" where PRIORITY is P0/P1/P2/P3
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

# Default max tasks per agent per cycle (configurable via env)
declare -g _ORCH_MAX_TASKS_PER_AGENT="${ORCH_MAX_TASKS_PER_AGENT:-5}"

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
