#!/usr/bin/env bash
# ============================================
# FeatureBench — Feature-Building Evaluation Harness
# ============================================
#
# Tests OrchyStraw's ability to build features (not just fix bugs).
# Each task specifies: feature description, expected files, acceptance criteria.
# Evaluates: file creation, test passage, spec adherence.
#
# Usage:
#   ./featurebench.sh [--limit N] [--model sonnet] [--timeout 600]
#                     [--agents 3] [--cycles 5] [--dry-run] [--help]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$BENCH_DIR/lib"
RESULTS_DIR="$BENCH_DIR/results"
REPORTS_DIR="$BENCH_DIR/reports"

source "$LIB_DIR/instance-runner.sh"
source "$LIB_DIR/results-collector.sh"
source "$LIB_DIR/cost-estimator.sh"

TASKS_FILE="$SCRIPT_DIR/featurebench-tasks.jsonl"

_log() { printf '[featurebench] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

# ── Input validation ─────────────────────────────────────────────

_validate_positive_int() {
    local name="$1" value="$2"
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        _die "$name must be a positive integer, got: '$value'"
    fi
}

_validate_model() {
    local model="$1"
    case "$model" in
        sonnet|opus|haiku) ;;
        *) _die "invalid model: '$model' (valid: sonnet, opus, haiku)" ;;
    esac
}

# ── Usage ────────────────────────────────────────────────────────

_usage() {
    cat <<'EOF'
Usage: featurebench.sh [OPTIONS]

Evaluates OrchyStraw's ability to build features from scratch.
Each task defines a feature spec + expected files + acceptance criteria.

Options:
  --limit <N>       Max tasks to run (default: 10)
  --model <name>    Model for agents: sonnet, opus, haiku (default: sonnet)
  --timeout <secs>  Timeout per task in seconds (default: 600)
  --agents <N>      Agents for OrchyStraw run (default: 3)
  --cycles <N>      Max orchestrator cycles (default: 5)
  --dry-run         Estimate cost and exit
  --help, -h        Show this help

Examples:
  ./featurebench.sh --limit 5 --dry-run
  ./featurebench.sh --limit 3 --model opus --timeout 900
  ./featurebench.sh --agents 5 --cycles 10 --limit 2
EOF
}

# ── Load tasks ───────────────────────────────────────────────────

_load_tasks() {
    local limit="$1"
    local tasks=()
    local count=0

    [[ -f "$TASKS_FILE" ]] || _die "tasks file not found: $TASKS_FILE"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        tasks+=("$line")
        count=$(( count + 1 ))
        [[ "$limit" -gt 0 ]] && [[ "$count" -ge "$limit" ]] && break
    done < "$TASKS_FILE"

    printf '%s\n' "${tasks[@]}"
}

# ── Run feature tasks ────────────────────────────────────────────

_run_feature_tasks() {
    local agents="$1" cycles="$2" model="$3" timeout="$4" results_file="$5"

    export BENCH_MODEL="$model"
    export BENCH_AGENTS="$agents"

    local workspace_base
    workspace_base="$(mktemp -d "/tmp/featurebench-XXXXXX")"

    _log "starting (agents=$agents, cycles=$cycles, model=$model)"

    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$(( count + 1 ))

        local id
        id="$(printf '%s' "$line" | jq -r '.instance_id // .id')"
        # Validate id: alphanumeric, hyphens, underscores, dots only
        if [[ ! "$id" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            _err "invalid task id: '$id' — skipping"
            continue
        fi
        _log "task $count: $id"

        local tmp
        tmp="$(mktemp "/tmp/featurebench-task-XXXXXX.json")"
        printf '%s' "$line" > "$tmp"

        local result
        result="$(run_instance "$tmp" "$workspace_base" "$model" "$cycles" "$timeout")" || true
        printf '%s\n' "$result" >> "$results_file"
        rm -f "$tmp"
    done

    _log "complete — $count tasks"
}

# ── Evaluate feature results ─────────────────────────────────────

_evaluate_results() {
    local results_file="$1" tasks_file="$2"

    local total=0 passed=0 partial=0 failed=0 timed_out=0
    local total_files_expected=0 total_files_created=0
    local total_time=0

    while IFS= read -r result_line; do
        [[ -z "$result_line" ]] && continue
        total=$(( total + 1 ))

        local status wall_time resolved
        status="$(printf '%s' "$result_line" | jq -r '.status // "unknown"')"
        wall_time="$(printf '%s' "$result_line" | jq -r '.wall_time_seconds // 0')"
        resolved="$(printf '%s' "$result_line" | jq -r '.resolved // false')"

        total_time="$(awk "BEGIN {printf \"%.1f\", $total_time + $wall_time}")"

        case "$status" in
            resolved)  passed=$(( passed + 1 )) ;;
            timeout)   timed_out=$(( timed_out + 1 )) ;;
            partial)   partial=$(( partial + 1 )) ;;
            *)         failed=$(( failed + 1 )) ;;
        esac

        # Count files created vs expected
        local files_expected files_created
        files_expected="$(printf '%s' "$result_line" | jq -r '.files_expected // 0')"
        files_created="$(printf '%s' "$result_line" | jq -r '.files_created // 0')"
        total_files_expected=$(( total_files_expected + files_expected ))
        total_files_created=$(( total_files_created + files_created ))
    done < "$results_file"

    local avg_time="0.0"
    if [[ "$total" -gt 0 ]]; then
        avg_time="$(awk "BEGIN {printf \"%.1f\", $total_time / $total}")"
    fi

    local resolve_rate="0.0"
    if [[ "$total" -gt 0 ]]; then
        resolve_rate="$(awk "BEGIN {printf \"%.1f\", ($passed / $total) * 100}")"
    fi

    local file_hit_rate="0.0"
    if [[ "$total_files_expected" -gt 0 ]]; then
        file_hit_rate="$(awk "BEGIN {printf \"%.1f\", ($total_files_created / $total_files_expected) * 100}")"
    fi

    # Output summary JSON (jq-free — printf-based)
    printf '{\n'
    printf '  "total": %d,\n' "$total"
    printf '  "passed": %d,\n' "$passed"
    printf '  "partial": %d,\n' "$partial"
    printf '  "failed": %d,\n' "$failed"
    printf '  "timed_out": %d,\n' "$timed_out"
    printf '  "resolve_rate": %s,\n' "$resolve_rate"
    printf '  "avg_wall_time_seconds": %s,\n' "$avg_time"
    printf '  "total_files_expected": %d,\n' "$total_files_expected"
    printf '  "total_files_created": %d,\n' "$total_files_created"
    printf '  "file_hit_rate": %s\n' "$file_hit_rate"
    printf '}\n'
}

# ── Generate FeatureBench report ─────────────────────────────────

_generate_report() {
    local results_file="$1" summary_file="$2"
    local num_tasks="$3" model="$4" timeout="$5" agents="$6" cycles="$7"

    local total passed partial failed timed_out resolve_rate avg_time file_hit_rate
    total="$(jq -r '.total' "$summary_file")"
    passed="$(jq -r '.passed' "$summary_file")"
    partial="$(jq -r '.partial' "$summary_file")"
    failed="$(jq -r '.failed' "$summary_file")"
    timed_out="$(jq -r '.timed_out' "$summary_file")"
    resolve_rate="$(jq -r '.resolve_rate' "$summary_file")"
    avg_time="$(jq -r '.avg_wall_time_seconds' "$summary_file")"
    file_hit_rate="$(jq -r '.file_hit_rate' "$summary_file")"

    cat <<REPORT
# FeatureBench — Evaluation Report

Date: $(date +%Y-%m-%d)
Tasks: $num_tasks | Model: $model | Timeout: ${timeout}s
Config: ${agents} agents, ${cycles} cycles

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | $total |
| Passed (fully resolved) | $passed |
| Partial | $partial |
| Failed | $failed |
| Timed out | $timed_out |
| Resolve rate | ${resolve_rate}% |
| Avg wall time | ${avg_time}s |
| File creation rate | ${file_hit_rate}% |

## Difficulty Breakdown

REPORT

    # Per-difficulty stats via Python (safe — env vars for paths)
    RESULTS_FILE="$results_file" python3 -c '
import json, os, sys

results = []
with open(os.environ["RESULTS_FILE"]) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        results.append(json.loads(line))

diff_stats = {}
for r in results:
    d = r.get("difficulty", "unknown")
    if d not in diff_stats:
        diff_stats[d] = {"total": 0, "resolved": 0}
    diff_stats[d]["total"] += 1
    if r.get("resolved", False):
        diff_stats[d]["resolved"] += 1

print("| Difficulty | Resolved | Total | Rate |")
print("|-----------|----------|-------|------|")
for d in ["easy", "medium", "hard"]:
    s = diff_stats.get(d, {"total": 0, "resolved": 0})
    rate = (s["resolved"] / s["total"] * 100) if s["total"] > 0 else 0
    print(f"| {d} | {s[\"resolved\"]} | {s[\"total\"]} | {rate:.0f}% |")
'

    cat <<REPORT

## Per-Task Results

| Task | Category | Difficulty | Status | Time |
|------|----------|-----------|--------|------|
REPORT

    RESULTS_FILE="$results_file" python3 -c '
import json, os

with open(os.environ["RESULTS_FILE"]) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        r = json.loads(line)
        tid = r.get("instance_id", "?")
        cat = r.get("category", "?")
        diff = r.get("difficulty", "?")
        status = r.get("status", "?")
        time = r.get("wall_time_seconds", 0)
        print(f"| {tid} | {cat} | {diff} | {status} | {time}s |")
'

    printf '\n---\n*Generated by FeatureBench evaluation harness*\n'
}

# ── Dry-run cost estimation ──────────────────────────────────────

_dry_run() {
    local limit="$1" model="$2" agents="$3" cycles="$4"

    local tasks
    tasks="$(_load_tasks "$limit")"
    local count
    count="$(printf '%s\n' "$tasks" | grep -c . || echo 0)"

    _log "dry-run: $count task(s) — estimating cost"

    printf '\n── FeatureBench (%s agents, %s cycles) ──\n' "$agents" "$cycles"
    local est
    est="$(estimate_cost "$count" "$model" "$agents" "$cycles")"
    print_estimate "$est"

    local total_cost
    total_cost="$(printf '%s' "$est" | jq -r '.estimated_total_cost_usd')"
    printf '  Estimated cost: $%s\n\n' "$total_cost"
}

# ── Check dependencies ───────────────────────────────────────────

_check_deps() {
    local missing=()
    for cmd in git jq python3; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _die "missing dependencies: ${missing[*]}"
    fi
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -lt 2 ]]; }; then
        _die "bash 4.2+ required (found ${BASH_VERSION})"
    fi
}

# ── Main ─────────────────────────────────────────────────────────

main() {
    local limit=10 model="sonnet" timeout=600 agents=3 cycles=5 dry_run=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)   _validate_positive_int "limit"   "$2"; limit="$2"; shift 2 ;;
            --model)   _validate_model "$2";              model="$2"; shift 2 ;;
            --timeout) _validate_positive_int "timeout" "$2"; timeout="$2"; shift 2 ;;
            --agents)  _validate_positive_int "agents"  "$2"; agents="$2"; shift 2 ;;
            --cycles)  _validate_positive_int "cycles"  "$2"; cycles="$2"; shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            --help|-h) _usage; exit 0 ;;
            *)         _die "unknown arg: $1" ;;
        esac
    done

    _check_deps

    if [[ "$dry_run" -eq 1 ]]; then
        _dry_run "$limit" "$model" "$agents" "$cycles"
        exit 0
    fi

    [[ -f "$TASKS_FILE" ]] || _die "tasks file not found: $TASKS_FILE"

    mkdir -p "$RESULTS_DIR" "$REPORTS_DIR"

    local run_ts
    run_ts="$(date +%Y%m%d-%H%M%S)"
    local results_file="$RESULTS_DIR/featurebench-${run_ts}.jsonl"

    # Load tasks
    local tasks
    tasks="$(_load_tasks "$limit")"
    local task_count
    task_count="$(printf '%s\n' "$tasks" | grep -c . || echo 0)"

    [[ "$task_count" -gt 0 ]] || _die "no tasks found"

    _log "featurebench run: $task_count tasks, model=$model, timeout=${timeout}s"
    _log "config: $agents agents, $cycles cycles"

    # ── Phase 1: Run tasks ────────────────────────────────────────
    _log "── Phase 1: Running feature tasks ──"
    printf '%s\n' "$tasks" | _run_feature_tasks "$agents" "$cycles" "$model" "$timeout" "$results_file"

    # ── Phase 2: Evaluate ─────────────────────────────────────────
    _log "── Phase 2: Evaluating results ──"

    local summary_file="$RESULTS_DIR/featurebench-summary-${run_ts}.json"
    if [[ -f "$results_file" ]]; then
        _evaluate_results "$results_file" "$TASKS_FILE" > "$summary_file"
    else
        _die "results missing: $results_file"
    fi

    # ── Phase 3: Report ───────────────────────────────────────────
    _log "── Phase 3: Generating report ──"

    local report_file="$REPORTS_DIR/featurebench-${run_ts}.md"
    _generate_report \
        "$results_file" "$summary_file" \
        "$task_count" "$model" "$timeout" "$agents" "$cycles" \
        > "$report_file"

    _log "results:"
    _log "  data   → $results_file"
    _log "  summary → $summary_file"
    _log "  report → $report_file"

    printf '\n'
    cat "$report_file"
}

main "$@"
