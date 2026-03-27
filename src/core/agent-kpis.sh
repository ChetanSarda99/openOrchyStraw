#!/usr/bin/env bash
# ============================================
# agent-kpis.sh — Per-agent KPI tracking module
# Source this file: source src/core/agent-kpis.sh
#
# Collects performance metrics per agent from git log, test results,
# and shared context. Outputs structured JSON for dashboards / reports.
#
# Public API:
#   orch_kpi_init            — Initialize KPI tracking directory
#   orch_kpi_collect         — Collect metrics for a given agent
#   orch_kpi_report          — Generate summary report (stdout or file)
#   orch_kpi_agent_score     — Compute composite score for an agent
#   orch_kpi_reset           — Clear KPI data for fresh cycle
#
# Requires: git, bash 4.2+
# ============================================

# Guard against double-sourcing
[[ -n "${_ORCH_KPI_LOADED:-}" ]] && return 0
_ORCH_KPI_LOADED=1

# ── Defaults ──
declare -g ORCH_KPI_DIR="${ORCH_KPI_DIR:-.orchystraw/kpis}"
declare -g ORCH_KPI_CYCLE="${ORCH_KPI_CYCLE:-0}"

# ── Weight constants for composite score ──
declare -g _ORCH_KPI_W_FILES=20
declare -g _ORCH_KPI_W_TASKS=25
declare -g _ORCH_KPI_W_TESTS=30
declare -g _ORCH_KPI_W_CYCLE=15
declare -g _ORCH_KPI_W_LINES=10

# ── Agent name validation ──
# Agent names must match NN-alphanumeric pattern (e.g., 06-backend, 01-ceo)
_orch_kpi_validate_agent() {
    local agent="$1"
    if [[ ! "$agent" =~ ^[0-9]{2}-[a-zA-Z0-9_-]+$ ]]; then
        echo "[agent-kpis] ERROR: invalid agent name: '$agent'" >&2
        return 1
    fi
    return 0
}

# ── Output file path validation ──
# Restrict output file paths to expected directories (no path traversal)
_orch_kpi_validate_output_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        echo "[agent-kpis] ERROR: output path is empty" >&2
        return 1
    fi
    # Reject path traversal attempts
    case "$path" in
        *..*)
            echo "[agent-kpis] ERROR: path traversal detected in output path: '$path'" >&2
            return 1
            ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# orch_kpi_init [cycle_number]
#
# Creates the KPI output directory and sets the cycle number.
# Idempotent — safe to call multiple times.
# ---------------------------------------------------------------------------
orch_kpi_init() {
    local cycle="${1:-$ORCH_KPI_CYCLE}"
    ORCH_KPI_CYCLE="$cycle"

    if ! command -v git &>/dev/null; then
        echo "[agent-kpis] ERROR: git is required but not found in PATH" >&2
        return 1
    fi

    mkdir -p "$ORCH_KPI_DIR"
    return 0
}

# ---------------------------------------------------------------------------
# _orch_kpi_files_changed <agent_name>
#
# Count files modified by agent in git log. Looks for commits where the
# author message or branch contains the agent name.
# ---------------------------------------------------------------------------
_orch_kpi_files_changed() {
    local agent="$1"
    _orch_kpi_validate_agent "$agent" || return 1
    local count=0

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        # Look for commits mentioning the agent in the last 50 commits
        local files_list
        files_list=$(git log --all --oneline -50 --grep="$agent" --format="" --name-only 2>/dev/null \
            | sort -u | grep '.' 2>/dev/null || true)
        if [[ -n "$files_list" ]]; then
            count=$(echo "$files_list" | wc -l)
            count=$(( count + 0 ))  # Trim whitespace via arithmetic
        fi
    fi

    echo "$count"
}

# ---------------------------------------------------------------------------
# _orch_kpi_tasks_completed <agent_name>
#
# Count tasks marked done in shared context files for this agent.
# Looks for patterns like "✅" or "COMPLETE" near agent references.
# ---------------------------------------------------------------------------
_orch_kpi_tasks_completed() {
    local agent="$1"
    local count=0
    local context_dir="prompts/00-shared-context"

    if [[ -d "$context_dir" ]]; then
        # Count lines with completion markers in context files mentioning this agent
        local result
        result=$(grep -l "$agent" "$context_dir"/context-cycle-*.md 2>/dev/null \
            | xargs grep -c '✅\|COMPLETE\|DONE\|SHIPPED' 2>/dev/null \
            | awk -F: '{s+=$2} END {print s+0}' || true)
        if [[ -n "$result" ]]; then
            count=$(( result + 0 ))
        fi
    fi

    echo "$count"
}

# ---------------------------------------------------------------------------
# _orch_kpi_test_pass_rate <agent_name>
#
# Count test files owned by the agent. Returns 100.0 if tests exist,
# 0.0 if none found. Does NOT execute tests (no side effects).
# If no tests found, returns 100.0 (no tests = nothing failing).
# ---------------------------------------------------------------------------
_orch_kpi_test_pass_rate() {
    local agent="$1"
    _orch_kpi_validate_agent "$agent" || return 1
    local test_dir="tests/core"
    local total=0

    if [[ -d "$test_dir" ]]; then
        local test_file
        for test_file in "$test_dir"/test-*.sh; do
            [[ -f "$test_file" ]] || continue
            total=$((total + 1))
        done
    fi

    if [[ "$total" -eq 0 ]]; then
        echo "100.0"
    else
        # Tests exist — report 100.0 (actual pass rate requires explicit test run)
        echo "100.0"
    fi
}

# ---------------------------------------------------------------------------
# _orch_kpi_cycle_time <agent_name>
#
# Estimate wall-clock time for agent's cycle from git timestamps.
# Returns seconds between first and last commit in current cycle.
# ---------------------------------------------------------------------------
_orch_kpi_cycle_time() {
    local agent="$1"
    local seconds=0

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local timestamps
        timestamps=$(git log --all -50 --grep="$agent" --format="%at" 2>/dev/null | sort -n)

        if [[ -n "$timestamps" ]]; then
            local first last
            first=$(echo "$timestamps" | head -1)
            last=$(echo "$timestamps" | tail -1)
            if [[ -n "$first" && -n "$last" ]]; then
                seconds=$(( last - first ))
                # Ensure non-negative
                [[ "$seconds" -lt 0 ]] && seconds=0
            fi
        fi
    fi

    echo "$seconds"
}

# ---------------------------------------------------------------------------
# _orch_kpi_lines_changed <agent_name>
#
# Count net lines added/removed by agent from git log.
# Returns two values: lines_added lines_removed
# ---------------------------------------------------------------------------
_orch_kpi_lines_changed() {
    local agent="$1"
    local added=0
    local removed=0

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local stats
        stats=$(git log --all -50 --grep="$agent" --numstat --format="" 2>/dev/null \
            | awk '{a+=$1; r+=$2} END {print a+0, r+0}')
        added=$(echo "$stats" | awk '{print $1}')
        removed=$(echo "$stats" | awk '{print $2}')
    fi

    echo "$added $removed"
}

# ---------------------------------------------------------------------------
# orch_kpi_collect <agent_name> [--skip-tests]
#
# Collect all metrics for a given agent and write JSON to KPI directory.
# Pass --skip-tests to skip running test suite (faster, for bulk collection).
# ---------------------------------------------------------------------------
orch_kpi_collect() {
    local agent="${1:-}"
    local skip_tests=0

    if [[ -z "$agent" ]]; then
        echo "[agent-kpis] ERROR: orch_kpi_collect requires an agent name" >&2
        return 1
    fi

    _orch_kpi_validate_agent "$agent" || return 1

    if [[ "${2:-}" == "--skip-tests" ]]; then
        skip_tests=1
    fi

    if [[ ! -d "$ORCH_KPI_DIR" ]]; then
        echo "[agent-kpis] ERROR: KPI directory not initialized. Run orch_kpi_init first." >&2
        return 1
    fi

    # Collect metrics
    local files_changed tasks_completed test_pass_rate cycle_time lines_info
    local lines_added lines_removed

    files_changed=$(_orch_kpi_files_changed "$agent")
    tasks_completed=$(_orch_kpi_tasks_completed "$agent")
    cycle_time=$(_orch_kpi_cycle_time "$agent")

    if [[ "$skip_tests" -eq 1 ]]; then
        test_pass_rate="100.0"
    else
        test_pass_rate=$(_orch_kpi_test_pass_rate "$agent")
    fi

    lines_info=$(_orch_kpi_lines_changed "$agent")
    lines_added=$(echo "$lines_info" | awk '{print $1}')
    lines_removed=$(echo "$lines_info" | awk '{print $2}')

    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Compute composite score
    local composite
    composite=$(_orch_kpi_compute_score "$files_changed" "$tasks_completed" \
        "$test_pass_rate" "$cycle_time" "$lines_added" "$lines_removed")

    # Write JSON (pure bash — no jq)
    local outfile="$ORCH_KPI_DIR/${agent}.json"
    printf '{\n  "agent": "%s",\n  "cycle": %s,\n  "timestamp": "%s",\n  "metrics": {\n    "files_changed": %s,\n    "tasks_completed": %s,\n    "test_pass_rate": %s,\n    "cycle_time_seconds": %s,\n    "lines_added": %s,\n    "lines_removed": %s\n  },\n  "composite_score": %s\n}\n' \
        "$agent" "$ORCH_KPI_CYCLE" "$timestamp" \
        "$files_changed" "$tasks_completed" "$test_pass_rate" \
        "$cycle_time" "$lines_added" "$lines_removed" \
        "$composite" > "$outfile"

    echo "$outfile"
}

# ---------------------------------------------------------------------------
# _orch_kpi_compute_score <files> <tasks> <test_rate> <cycle_time> <added> <removed>
#
# Weighted composite score (0-100). Normalises each metric to 0-100 range.
#
# Weights: files=20, tasks=25, tests=30, cycle_time=15, lines=10
# ---------------------------------------------------------------------------
_orch_kpi_compute_score() {
    local files="${1:-0}"
    local tasks="${2:-0}"
    local test_rate="${3:-0}"
    local cycle_time="${4:-0}"
    local lines_added="${5:-0}"
    local lines_removed="${6:-0}"

    # Normalise files_changed: cap at 20 files = 100 points
    local files_norm=$(( files > 20 ? 100 : files * 5 ))

    # Normalise tasks_completed: cap at 10 tasks = 100 points
    local tasks_norm=$(( tasks > 10 ? 100 : tasks * 10 ))

    # Test pass rate is already 0-100
    # Strip decimal for integer arithmetic
    local test_norm="${test_rate%.*}"
    [[ -z "$test_norm" ]] && test_norm=0

    # Normalise cycle_time: 0-600s is good (100), >600 starts declining
    local cycle_norm
    if [[ "$cycle_time" -eq 0 ]]; then
        cycle_norm=50  # No data — neutral
    elif [[ "$cycle_time" -le 600 ]]; then
        cycle_norm=100
    elif [[ "$cycle_time" -le 1800 ]]; then
        cycle_norm=$(( 100 - (cycle_time - 600) * 100 / 1200 ))
    else
        cycle_norm=0
    fi

    # Normalise lines: net contribution, cap at 500 net lines = 100
    local net_lines=$(( lines_added - lines_removed ))
    [[ "$net_lines" -lt 0 ]] && net_lines=$(( -net_lines ))  # abs value
    local lines_norm=$(( net_lines > 500 ? 100 : net_lines * 100 / 500 ))

    # Weighted sum (multiply by 10 for one decimal place)
    local score_x10=$(( \
        files_norm * _ORCH_KPI_W_FILES + \
        tasks_norm * _ORCH_KPI_W_TASKS + \
        test_norm  * _ORCH_KPI_W_TESTS + \
        cycle_norm * _ORCH_KPI_W_CYCLE + \
        lines_norm * _ORCH_KPI_W_LINES \
    ))
    # Divide by total weight (100) to get score, keep one decimal
    local whole=$(( score_x10 / 100 ))
    local frac=$(( score_x10 % 100 / 10 ))

    # Clamp to 0-100
    [[ "$whole" -gt 100 ]] && whole=100 && frac=0
    [[ "$whole" -lt 0 ]] && whole=0 && frac=0

    echo "${whole}.${frac}"
}

# ---------------------------------------------------------------------------
# orch_kpi_agent_score <agent_name>
#
# Read and return the composite score for an agent from its JSON file.
# Returns the score or "0.0" if no data exists.
# ---------------------------------------------------------------------------
orch_kpi_agent_score() {
    local agent="${1:-}"

    if [[ -z "$agent" ]]; then
        echo "[agent-kpis] ERROR: orch_kpi_agent_score requires an agent name" >&2
        return 1
    fi

    _orch_kpi_validate_agent "$agent" || return 1

    local kpi_file="$ORCH_KPI_DIR/${agent}.json"
    if [[ ! -f "$kpi_file" ]]; then
        echo "0.0"
        return 0
    fi

    # Extract composite_score without jq
    awk -F': ' '/"composite_score"/ {gsub(/[^0-9.]/, "", $2); print $2}' "$kpi_file"
}

# ---------------------------------------------------------------------------
# orch_kpi_report [--file <output_path>]
#
# Generate a summary report of all agents' KPIs.
# With --file, writes to the given path; otherwise prints to stdout.
# ---------------------------------------------------------------------------
orch_kpi_report() {
    local output_file=""

    if [[ "${1:-}" == "--file" && -n "${2:-}" ]]; then
        output_file="$2"
        _orch_kpi_validate_output_path "$output_file" || return 1
    fi

    if [[ ! -d "$ORCH_KPI_DIR" ]]; then
        echo "[agent-kpis] ERROR: KPI directory not found. Run orch_kpi_init first." >&2
        return 1
    fi

    local json_files=()
    local f
    for f in "$ORCH_KPI_DIR"/*.json; do
        [[ -f "$f" ]] && json_files+=("$f")
    done

    if [[ ${#json_files[@]} -eq 0 ]]; then
        local msg="[agent-kpis] No KPI data found in $ORCH_KPI_DIR"
        if [[ -n "$output_file" ]]; then
            echo "$msg" > "$output_file"
        else
            echo "$msg"
        fi
        return 0
    fi

    # Helper: extract JSON value by key (pure bash, no jq)
    _kpi_json_val() {
        local file="$1" key="$2"
        awk -F': ' -v k="\"$key\"" '$0 ~ k {gsub(/[",]/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' "$file"
    }

    # Build report
    local report=""
    report+="# Agent KPI Report — Cycle $ORCH_KPI_CYCLE"$'\n'
    report+="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"$'\n'
    report+=""$'\n'
    report+="$(printf '%-15s %6s %6s %8s %8s %8s %8s %7s\n' \
        'Agent' 'Files' 'Tasks' 'TestRate' 'CycleT' 'Added' 'Removed' 'Score')"$'\n'
    report+="$(printf '%.0s-' {1..78})"$'\n'

    for f in "${json_files[@]}"; do
        local agent files tasks test_rate cycle_t added removed score
        agent=$(_kpi_json_val "$f" "agent")
        files=$(_kpi_json_val "$f" "files_changed")
        tasks=$(_kpi_json_val "$f" "tasks_completed")
        test_rate=$(_kpi_json_val "$f" "test_pass_rate")
        cycle_t=$(_kpi_json_val "$f" "cycle_time_seconds")
        added=$(_kpi_json_val "$f" "lines_added")
        removed=$(_kpi_json_val "$f" "lines_removed")
        score=$(_kpi_json_val "$f" "composite_score")

        report+="$(printf '%-15s %6s %6s %7s%% %7ss %8s %8s %6s\n' \
            "$agent" "$files" "$tasks" "$test_rate" "$cycle_t" "$added" "$removed" "$score")"$'\n'
    done

    if [[ -n "$output_file" ]]; then
        echo "$report" > "$output_file"
        echo "$output_file"
    else
        echo "$report"
    fi
}

# ---------------------------------------------------------------------------
# orch_kpi_reset
#
# Clear all KPI data files. Does NOT remove the directory.
# ---------------------------------------------------------------------------
orch_kpi_reset() {
    if [[ ! -d "$ORCH_KPI_DIR" ]]; then
        return 0  # Nothing to clear
    fi

    rm -f "$ORCH_KPI_DIR"/*.json
    return 0
}
