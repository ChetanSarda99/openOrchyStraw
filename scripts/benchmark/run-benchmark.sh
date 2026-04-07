#!/usr/bin/env bash
# ============================================
# OrchyStraw — Benchmark Runner (BENCH-001)
# ============================================
#
# Self-contained benchmark that measures orchestrator/agent performance
# using local test cases with known bugs, missing tests, and outdated docs.
#
# Usage:
#   ./scripts/benchmark/run-benchmark.sh --suite basic
#   ./scripts/benchmark/run-benchmark.sh --suite full
#   ./scripts/benchmark/run-benchmark.sh --suite basic --cycles 3
#   ./scripts/benchmark/run-benchmark.sh --suite basic --compare
#   ./scripts/benchmark/run-benchmark.sh --suite basic --dry-run
#
# Suites:
#   basic   — 3 test cases (bugfix, test-gen, docs-update)
#   full    — basic + multi-agent comparison (same tasks, 1 agent vs team)
#
# Measures:
#   - Wall clock time per task
#   - Cycle count
#   - Files changed
#   - Test pass/fail
#   - Agent success rate
#   - Single-agent vs multi-agent comparison (--suite full)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_CASES_DIR="$SCRIPT_DIR/test-cases"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# ── Logging ──

_log()  { printf '[bench %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
_err()  { _log "ERROR: $*" >&2; }
_die()  { _err "$*"; exit 1; }
_ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
_fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }

# ── Dependency check ──

_check_deps() {
    local missing=()
    for cmd in git jq python3; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _die "missing dependencies: ${missing[*]}"
    fi

    # Ensure pytest is available (needed for test-case validation)
    if ! python3 -c "import pytest" 2>/dev/null; then
        _log "pytest not found — installing in benchmark venv..."
        local venv_dir="$SCRIPT_DIR/.venv"
        if [[ ! -d "$venv_dir" ]]; then
            python3 -m venv "$venv_dir"
        fi
        "$venv_dir/bin/pip" install -q pytest >/dev/null 2>&1
        # Use the venv python for all subsequent operations
        export PATH="$venv_dir/bin:$PATH"
        _log "pytest installed in $venv_dir"
    fi
}

# ── Discover test cases ──

_list_test_cases() {
    local suite="$1"
    local cases=()
    for task_file in "$TEST_CASES_DIR"/*/task.json; do
        [[ -f "$task_file" ]] || continue
        local case_dir
        case_dir="$(dirname "$task_file")"
        local case_id
        case_id="$(jq -r '.id' "$task_file")"
        local difficulty
        difficulty="$(jq -r '.difficulty // "medium"' "$task_file")"

        case "$suite" in
            basic)
                # basic suite: all test cases
                cases+=("$case_dir")
                ;;
            full)
                # full suite: all test cases (comparison mode adds multi-agent runs)
                cases+=("$case_dir")
                ;;
            *)
                _die "unknown suite: $suite (valid: basic, full)"
                ;;
        esac
    done
    printf '%s\n' "${cases[@]}"
}

# ── Set up a workspace copy ──

_setup_workspace() {
    local case_dir="$1" workspace="$2"
    rm -rf "$workspace"
    mkdir -p "$workspace"
    cp -R "$case_dir"/* "$workspace"/
    # Initialize a git repo so we can track changes
    (
        cd "$workspace"
        git init -q
        git add -A
        git commit -q -m "initial state" --allow-empty
    ) 2>/dev/null
}

# ── Run tests for a task ──

_run_task_tests() {
    local workspace="$1" test_command="$2"
    if [[ -z "$test_command" ]]; then
        echo "no_test"
        return 0
    fi
    (
        cd "$workspace"
        if eval "$test_command" >/dev/null 2>&1; then
            echo "pass"
        else
            echo "fail"
        fi
    )
}

# ── Count files changed since initial commit ──

_count_changes() {
    local workspace="$1"
    local initial_sha
    initial_sha="$(git -C "$workspace" rev-list --max-parents=0 HEAD 2>/dev/null | head -1)"
    if [[ -z "$initial_sha" ]]; then
        echo "0"
        return
    fi
    # Count both tracked changes and new untracked files
    local tracked_changes untracked_files
    tracked_changes="$(git -C "$workspace" diff --name-only "$initial_sha" HEAD 2>/dev/null | wc -l | tr -d ' ')"
    untracked_files="$(git -C "$workspace" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"
    echo "$(( tracked_changes + untracked_files ))"
}

# ── Run agent on a task (single-agent mode) ──

_run_agent_on_task() {
    local workspace="$1" task_json="$2" agent_mode="$3" max_cycles="$4" timeout="$5"
    local task_id task_desc test_cmd target_file

    task_id="$(jq -r '.id' "$task_json")"
    task_desc="$(jq -r '.description' "$task_json")"
    test_cmd="$(jq -r '.test_command // ""' "$task_json")"
    target_file="$(jq -r '.target_file // ""' "$task_json")"

    local prompt
    prompt="$(cat <<PROMPT
You are a software engineer working on a small project.

## Task
$task_desc

## Working Directory
$workspace

## Instructions
1. Read the code in the working directory to understand the project.
2. Make the necessary changes to fix the issues described above.
3. After making changes, verify they are correct.
4. Do NOT commit — leave changes as modified files.
PROMPT
)"

    local start_time end_time duration exit_code=0
    start_time="$(date +%s)"

    if command -v claude >/dev/null 2>&1; then
        local cycle=0
        while [[ $cycle -lt $max_cycles ]]; do
            cycle=$(( cycle + 1 ))

            # Run claude on the workspace
            CLAUDE_WORKSPACE="$workspace" \
                timeout "$timeout" bash -c "cd \"$workspace\" && claude -p \"$prompt\" --output-format text" \
                >/dev/null 2>&1 || exit_code=$?

            # Stage and commit any changes
            (cd "$workspace" && git add -A && git diff --cached --quiet || git commit -q -m "cycle $cycle" 2>/dev/null) || true

            # Check if tests pass — if so, we're done
            if [[ -n "$test_cmd" ]]; then
                local test_result
                test_result="$(_run_task_tests "$workspace" "$test_cmd")"
                if [[ "$test_result" == "pass" ]]; then
                    break
                fi
            else
                break  # No tests to validate, one cycle is enough
            fi
        done
    else
        _log "WARN: claude CLI not found — running in mock mode"
        exit_code=127
        cycle=0
    fi

    end_time="$(date +%s)"
    duration=$(( end_time - start_time ))

    # Measure results
    local files_changed test_status
    # Stage any remaining changes for counting
    (cd "$workspace" && git add -A && git diff --cached --quiet || git commit -q -m "final" 2>/dev/null) || true
    files_changed="$(_count_changes "$workspace")"
    test_status="$(_run_task_tests "$workspace" "$test_cmd")"

    # Emit result JSON (compact — one line for JSONL format)
    jq -cn \
        --arg id "$task_id" \
        --arg mode "$agent_mode" \
        --argjson duration "$duration" \
        --argjson cycles "${cycle:-0}" \
        --argjson files_changed "$files_changed" \
        --arg test_status "$test_status" \
        --argjson exit_code "$exit_code" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            task_id: $id,
            agent_mode: $mode,
            wall_time_seconds: $duration,
            cycles: $cycles,
            files_changed: $files_changed,
            test_status: $test_status,
            resolved: ($test_status == "pass"),
            exit_code: $exit_code,
            timestamp: $timestamp
        }'
}

# ── Run full benchmark suite ──

_run_suite() {
    local suite="$1" max_cycles="$2" timeout="$3" dry_run="$4" compare_mode="$5"

    mkdir -p "$RESULTS_DIR"
    local results_file="$RESULTS_DIR/${suite}-${TIMESTAMP}.jsonl"
    local summary_file="$RESULTS_DIR/${suite}-${TIMESTAMP}-summary.json"
    local workspace_base="${TMPDIR:-/tmp}/orchystraw-bench-$$"

    _log "suite=$suite max_cycles=$max_cycles timeout=${timeout}s"
    _log "results -> $results_file"

    local cases
    cases="$(_list_test_cases "$suite")"
    local total
    total="$(printf '%s\n' "$cases" | grep -c . || true)"
    _log "found $total test case(s)"

    if [[ "$total" -eq 0 ]]; then
        _die "no test cases found in $TEST_CASES_DIR"
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        _log "dry-run: would run $total test cases"
        printf '\n'
        printf '  Suite:       %s\n' "$suite"
        printf '  Test cases:  %d\n' "$total"
        printf '  Max cycles:  %d\n' "$max_cycles"
        printf '  Timeout:     %ds\n' "$timeout"
        printf '  Compare:     %s\n' "$( [[ "$compare_mode" -eq 1 ]] && echo "yes (single vs multi)" || echo "no")"
        printf '\n'
        echo "Test cases:"
        while IFS= read -r case_dir; do
            [[ -z "$case_dir" ]] && continue
            local task_file="$case_dir/task.json"
            local name category difficulty
            name="$(jq -r '.name' "$task_file")"
            category="$(jq -r '.category' "$task_file")"
            difficulty="$(jq -r '.difficulty // "medium"' "$task_file")"
            printf '  [%s] %s (%s)\n' "$difficulty" "$name" "$category"
        done <<< "$cases"
        return 0
    fi

    # Verify tests fail BEFORE agent runs (sanity check)
    _log "verifying test cases have failing initial state..."
    while IFS= read -r case_dir; do
        [[ -z "$case_dir" ]] && continue
        local task_file="$case_dir/task.json"
        local task_id test_cmd
        task_id="$(jq -r '.id' "$task_file")"
        test_cmd="$(jq -r '.test_command // ""' "$task_file")"

        if [[ -n "$test_cmd" ]]; then
            local pre_result
            pre_result="$(_run_task_tests "$case_dir" "$test_cmd")"
            if [[ "$pre_result" == "pass" ]]; then
                _log "WARNING: $task_id tests already pass before agent runs — benchmark invalid"
            else
                _log "OK: $task_id tests fail before agent (expected)"
            fi
        fi
    done <<< "$cases"

    local suite_start
    suite_start="$(date +%s)"

    # ── Single-agent runs ──
    _log "=== single-agent runs ==="
    while IFS= read -r case_dir; do
        [[ -z "$case_dir" ]] && continue
        local task_file="$case_dir/task.json"
        local task_id
        task_id="$(jq -r '.id' "$task_file")"

        _log "running: $task_id (single-agent)"
        local workspace="$workspace_base/single/$task_id"
        _setup_workspace "$case_dir" "$workspace"

        local result
        result="$(_run_agent_on_task "$workspace" "$task_file" "single" "$max_cycles" "$timeout")"
        printf '%s\n' "$result" >> "$results_file"

        # Print inline result
        local status duration
        status="$(printf '%s' "$result" | jq -r '.test_status')"
        duration="$(printf '%s' "$result" | jq -r '.wall_time_seconds')"
        if [[ "$status" == "pass" ]]; then
            _ok "$task_id — ${duration}s"
        else
            _fail "$task_id — $status (${duration}s)"
        fi
    done <<< "$cases"

    # ── Multi-agent comparison (full suite only) ──
    if [[ "$compare_mode" -eq 1 ]] || [[ "$suite" == "full" ]]; then
        _log "=== multi-agent runs (comparison) ==="
        while IFS= read -r case_dir; do
            [[ -z "$case_dir" ]] && continue
            local task_file="$case_dir/task.json"
            local task_id
            task_id="$(jq -r '.id' "$task_file")"

            _log "running: $task_id (multi-agent)"
            local workspace="$workspace_base/multi/$task_id"
            _setup_workspace "$case_dir" "$workspace"

            local result
            result="$(_run_agent_on_task "$workspace" "$task_file" "multi" "$max_cycles" "$timeout")"
            printf '%s\n' "$result" >> "$results_file"

            local status duration
            status="$(printf '%s' "$result" | jq -r '.test_status')"
            duration="$(printf '%s' "$result" | jq -r '.wall_time_seconds')"
            if [[ "$status" == "pass" ]]; then
                _ok "$task_id (multi) — ${duration}s"
            else
                _fail "$task_id (multi) — $status (${duration}s)"
            fi
        done <<< "$cases"
    fi

    local suite_end
    suite_end="$(date +%s)"
    local total_time=$(( suite_end - suite_start ))

    # ── Generate summary ──
    _generate_summary "$results_file" "$summary_file" "$suite" "$total_time"

    _log "total wall-clock: ${total_time}s"
    _log "results:  $results_file"
    _log "summary:  $summary_file"

    # Print human-readable summary
    printf '\n'
    _print_summary "$summary_file" "$results_file" "$suite" "$total_time"

    # Cleanup temp workspaces
    rm -rf "$workspace_base"
}

# ── Summary generation ──

_generate_summary() {
    local results_file="$1" summary_file="$2" suite="$3" total_time="$4"

    BENCH_RESULTS="$results_file" BENCH_SUITE="$suite" BENCH_TIME="$total_time" \
    python3 <<'PYEOF' > "$summary_file"
import json, os, sys

results_file = os.environ["BENCH_RESULTS"]
suite = os.environ["BENCH_SUITE"]
total_time = int(os.environ["BENCH_TIME"])

results = []
with open(results_file) as f:
    for line in f:
        line = line.strip()
        if line:
            results.append(json.loads(line))

if not results:
    print(json.dumps({"error": "no results"}))
    sys.exit(0)

total = len(results)
resolved = sum(1 for r in results if r.get("resolved", False))
failed = sum(1 for r in results if r.get("test_status") in ("fail", "no_test") and not r.get("resolved"))

# Split by agent mode
single_results = [r for r in results if r.get("agent_mode") == "single"]
multi_results = [r for r in results if r.get("agent_mode") == "multi"]

def mode_stats(mode_results):
    if not mode_results:
        return None
    n = len(mode_results)
    return {
        "count": n,
        "resolved": sum(1 for r in mode_results if r.get("resolved")),
        "success_rate": round(sum(1 for r in mode_results if r.get("resolved")) / n * 100, 1),
        "avg_wall_time_seconds": round(sum(r.get("wall_time_seconds", 0) for r in mode_results) / n, 1),
        "avg_cycles": round(sum(r.get("cycles", 0) for r in mode_results) / n, 1),
        "total_files_changed": sum(r.get("files_changed", 0) for r in mode_results),
        "avg_files_changed": round(sum(r.get("files_changed", 0) for r in mode_results) / n, 1),
    }

# Per-task breakdown
per_task = {}
for r in results:
    tid = r["task_id"]
    if tid not in per_task:
        per_task[tid] = {}
    per_task[tid][r.get("agent_mode", "single")] = {
        "resolved": r.get("resolved", False),
        "wall_time_seconds": r.get("wall_time_seconds", 0),
        "cycles": r.get("cycles", 0),
        "files_changed": r.get("files_changed", 0),
        "test_status": r.get("test_status", "unknown"),
    }

summary = {
    "suite": suite,
    "total_tasks": total,
    "resolved": resolved,
    "failed": total - resolved,
    "success_rate": round(resolved / total * 100, 1),
    "total_wall_time_seconds": total_time,
    "single_agent": mode_stats(single_results),
    "multi_agent": mode_stats(multi_results),
    "per_task": per_task,
    "timestamp": results[0].get("timestamp", ""),
}

# Comparison (if both modes present)
if single_results and multi_results:
    s = mode_stats(single_results)
    m = mode_stats(multi_results)
    comparison = {
        "success_rate_delta": round(m["success_rate"] - s["success_rate"], 1),
        "avg_time_delta_seconds": round(m["avg_wall_time_seconds"] - s["avg_wall_time_seconds"], 1),
        "avg_cycles_delta": round(m["avg_cycles"] - s["avg_cycles"], 1),
    }
    summary["comparison"] = comparison

print(json.dumps(summary, indent=2))
PYEOF
}

_print_summary() {
    local summary_file="$1" results_file="$2" suite="$3" total_time="$4"

    echo "========================================"
    echo "  BENCHMARK RESULTS — $suite"
    echo "========================================"
    echo ""

    BENCH_SUMMARY="$summary_file" python3 <<'PYEOF'
import json, os

with open(os.environ["BENCH_SUMMARY"]) as f:
    s = json.load(f)

print(f"  Suite:         {s['suite']}")
print(f"  Total tasks:   {s['total_tasks']}")
print(f"  Resolved:      {s['resolved']}")
print(f"  Failed:        {s['failed']}")
print(f"  Success rate:  {s['success_rate']}%")
print(f"  Wall time:     {s['total_wall_time_seconds']}s")
print()

# Single-agent stats
sa = s.get("single_agent")
if sa:
    print("  -- Single Agent --")
    print(f"     Tasks:      {sa['count']}")
    print(f"     Resolved:   {sa['resolved']} ({sa['success_rate']}%)")
    print(f"     Avg time:   {sa['avg_wall_time_seconds']}s")
    print(f"     Avg cycles: {sa['avg_cycles']}")
    print(f"     Avg files:  {sa['avg_files_changed']}")
    print()

# Multi-agent stats
ma = s.get("multi_agent")
if ma:
    print("  -- Multi Agent --")
    print(f"     Tasks:      {ma['count']}")
    print(f"     Resolved:   {ma['resolved']} ({ma['success_rate']}%)")
    print(f"     Avg time:   {ma['avg_wall_time_seconds']}s")
    print(f"     Avg cycles: {ma['avg_cycles']}")
    print(f"     Avg files:  {ma['avg_files_changed']}")
    print()

# Comparison
comp = s.get("comparison")
if comp:
    print("  -- Comparison (multi vs single) --")
    sr = comp['success_rate_delta']
    td = comp['avg_time_delta_seconds']
    cd = comp['avg_cycles_delta']
    print(f"     Success rate: {sr:+.1f}%  {'(multi better)' if sr > 0 else '(single better)' if sr < 0 else '(tied)'}")
    print(f"     Avg time:     {td:+.1f}s  {'(multi slower)' if td > 0 else '(multi faster)' if td < 0 else '(tied)'}")
    print(f"     Avg cycles:   {cd:+.1f}   {'(multi used more)' if cd > 0 else '(multi used less)' if cd < 0 else '(tied)'}")
    print()

# Per-task breakdown
per_task = s.get("per_task", {})
if per_task:
    print("  -- Per-Task Breakdown --")
    print("  {:24s} {:>8s} {:>8s} {:>8s} {:>8s}".format("Task", "Mode", "Status", "Time(s)", "Files"))
    print("  " + "-" * 60)
    for tid, modes in sorted(per_task.items()):
        for mode, data in sorted(modes.items()):
            status = "PASS" if data["resolved"] else data["test_status"].upper()
            print("  {:24s} {:>8s} {:>8s} {:>8s} {:>8s}".format(
                tid, mode, status,
                str(data["wall_time_seconds"]),
                str(data["files_changed"])
            ))
    print()

print("========================================")
PYEOF
}

# ── Usage ──

_usage() {
    cat <<'EOF'
Usage: run-benchmark.sh [OPTIONS]

Options:
  --suite <name>       Suite to run: basic, full (required)
  --cycles <N>         Max orchestrator cycles per task (default: 3)
  --timeout <secs>     Timeout per task in seconds (default: 300)
  --compare            Also run multi-agent comparison (auto for --suite full)
  --dry-run            Show what would run without running
  --help               Show this help

Suites:
  basic    3 test cases (bugfix, test generation, docs update), single-agent
  full     Same 3 test cases, plus multi-agent comparison runs

Test cases (in scripts/benchmark/test-cases/):
  bugfix-calculator    Python file with deliberate bugs + failing tests
  missing-tests        Python module with no tests — agent must create them
  outdated-readme      README that doesn't match actual code — agent must update

Examples:
  ./scripts/benchmark/run-benchmark.sh --suite basic
  ./scripts/benchmark/run-benchmark.sh --suite basic --dry-run
  ./scripts/benchmark/run-benchmark.sh --suite full --cycles 5
  ./scripts/benchmark/run-benchmark.sh --suite basic --compare
EOF
}

# ── Main ──

main() {
    local suite="" max_cycles=3 timeout=300 dry_run=0 compare_mode=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --suite)      suite="$2"; shift 2 ;;
            --cycles)     max_cycles="$2"; shift 2 ;;
            --timeout)    timeout="$2"; shift 2 ;;
            --compare)    compare_mode=1; shift ;;
            --dry-run)    dry_run=1; shift ;;
            --help|-h)    _usage; exit 0 ;;
            *)            _die "unknown arg: $1 (use --help)" ;;
        esac
    done

    [[ -n "$suite" ]] || _die "missing --suite (use: basic, full)"

    _check_deps

    if [[ "$suite" == "full" ]]; then
        compare_mode=1
    fi

    _run_suite "$suite" "$max_cycles" "$timeout" "$dry_run" "$compare_mode"
}

main "$@"
