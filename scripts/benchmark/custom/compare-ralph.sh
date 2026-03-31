#!/usr/bin/env bash
# OrchyStraw vs Ralph — Head-to-Head Comparison
#
# Runs the same custom tasks through BOTH OrchyStraw (multi-agent) and
# Ralph (single-agent), then generates a side-by-side markdown report.
#
# Usage:
#   ./compare-ralph.sh [--limit N] [--model sonnet] [--timeout 600]
#                      [--agents 3] [--cycles 5] [--dry-run] [--help]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$BENCH_DIR/lib"
RESULTS_DIR="$BENCH_DIR/results"
REPORTS_DIR="$BENCH_DIR/reports"

source "$LIB_DIR/instance-runner.sh"
source "$LIB_DIR/results-collector.sh"
source "$LIB_DIR/cost-estimator.sh"

TASKS_FILE="$SCRIPT_DIR/tasks.jsonl"

_log() { printf '[compare] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

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

_usage() {
    cat <<'EOF'
Usage: compare-ralph.sh [OPTIONS]

Runs the same benchmark tasks through both OrchyStraw (multi-agent)
and Ralph (single-agent), then generates a side-by-side comparison.

Options:
  --limit <N>       Max tasks to run (default: 10)
  --model <name>    Model for agents: sonnet, opus, haiku (default: sonnet)
  --timeout <secs>  Timeout per task in seconds (default: 600)
  --agents <N>      Agents for OrchyStraw run (default: 3)
  --cycles <N>      Max orchestrator cycles for OrchyStraw (default: 5)
  --dry-run         Estimate cost for both approaches and exit
  --help, -h        Show this help

Examples:
  ./compare-ralph.sh --limit 5 --dry-run
  ./compare-ralph.sh --limit 3 --model sonnet --timeout 300
  ./compare-ralph.sh --agents 5 --cycles 10 --limit 2
EOF
}

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

_run_approach() {
    local label="$1" agents="$2" cycles="$3" model="$4" timeout="$5" results_file="$6"

    export BENCH_MODEL="$model"
    export BENCH_AGENTS="$agents"

    local workspace_base
    workspace_base="$(mktemp -d "/tmp/orchystraw-compare-${label}-XXXXXX")"

    _log "[$label] starting (agents=$agents, cycles=$cycles, model=$model)"

    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$(( count + 1 ))

        local id
        id="$(printf '%s' "$line" | jq -r '.instance_id // .id')"
        if [[ ! "$id" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            _err "invalid task id: '$id' — skipping"
            continue
        fi
        _log "[$label] task $count: $id"

        local tmp
        tmp="$(mktemp "/tmp/orchystraw-compare-${label}-XXXXXX.json")"
        printf '%s' "$line" > "$tmp"

        local result
        result="$(run_instance "$tmp" "$workspace_base" "$model" "$cycles" "$timeout")" || true
        printf '%s\n' "$result" >> "$results_file"
        rm -f "$tmp"
    done

    _log "[$label] complete — $count tasks"
}

_generate_comparison_report() {
    local ralph_results="$1"
    local orchy_results="$2"
    local ralph_summary="$3"
    local orchy_summary="$4"
    local num_tasks="$5"
    local model="$6"
    local timeout="$7"
    local agents="$8"
    local cycles="$9"

    _validate_numeric() {
        local name="$1" val="$2"
        if [[ ! "$val" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
            _err "non-numeric value from summary JSON: $name='$val'"
            printf '0'
            return
        fi
        printf '%s' "$val"
    }

    local ralph_rate orchy_rate ralph_time orchy_time ralph_rogue orchy_rogue
    local ralph_resolved orchy_resolved ralph_total orchy_total

    ralph_rate="$(_validate_numeric ralph_rate "$(jq -r '.resolve_rate' "$ralph_summary")")"
    orchy_rate="$(_validate_numeric orchy_rate "$(jq -r '.resolve_rate' "$orchy_summary")")"
    ralph_time="$(_validate_numeric ralph_time "$(jq -r '.avg_wall_time_seconds' "$ralph_summary")")"
    orchy_time="$(_validate_numeric orchy_time "$(jq -r '.avg_wall_time_seconds' "$orchy_summary")")"
    ralph_rogue="$(_validate_numeric ralph_rogue "$(jq -r '.rogue_write_total' "$ralph_summary")")"
    orchy_rogue="$(_validate_numeric orchy_rogue "$(jq -r '.rogue_write_total' "$orchy_summary")")"
    ralph_resolved="$(_validate_numeric ralph_resolved "$(jq -r '.resolved' "$ralph_summary")")"
    orchy_resolved="$(_validate_numeric orchy_resolved "$(jq -r '.resolved' "$orchy_summary")")"
    ralph_total="$(_validate_numeric ralph_total "$(jq -r '.total' "$ralph_summary")")"
    orchy_total="$(_validate_numeric orchy_total "$(jq -r '.total' "$orchy_summary")")"

    local ralph_avg_rogue orchy_avg_rogue
    ralph_avg_rogue="$(awk -v r="$ralph_rogue" -v t="$ralph_total" 'BEGIN {printf "%.1f", r / (t > 0 ? t : 1)}')"
    orchy_avg_rogue="$(awk -v r="$orchy_rogue" -v t="$orchy_total" 'BEGIN {printf "%.1f", r / (t > 0 ? t : 1)}')"

    local rate_delta time_delta rogue_delta
    rate_delta="$(awk -v o="$orchy_rate" -v r="$ralph_rate" 'BEGIN {printf "%+.1f%%", o - r}')"
    time_delta="$(awk -v o="$orchy_time" -v r="$ralph_time" 'BEGIN {printf "%+.1fs", o - r}')"
    rogue_delta="$(awk -v o="$orchy_avg_rogue" -v r="$ralph_avg_rogue" 'BEGIN {printf "%+.1f", o - r}')"

    local ralph_patch_sum orchy_patch_sum ralph_patch_avg orchy_patch_avg
    ralph_patch_sum="$(_validate_numeric ralph_patch_sum "$(jq -s '[.[].patch_match] | add // 0' "$ralph_results")")"
    orchy_patch_sum="$(_validate_numeric orchy_patch_sum "$(jq -s '[.[].patch_match] | add // 0' "$orchy_results")")"
    ralph_patch_avg="$(awk -v s="$ralph_patch_sum" -v t="$ralph_total" 'BEGIN {printf "%.0f%%", (s / (t > 0 ? t : 1)) * 100}')"
    orchy_patch_avg="$(awk -v s="$orchy_patch_sum" -v t="$orchy_total" 'BEGIN {printf "%.0f%%", (s / (t > 0 ? t : 1)) * 100}')"

    local ralph_diff_len orchy_diff_len
    ralph_diff_len="$(_validate_numeric ralph_diff_len "$(jq -s '[.[].diff_length] | add // 0' "$ralph_results")")"
    orchy_diff_len="$(_validate_numeric orchy_diff_len "$(jq -s '[.[].diff_length] | add // 0' "$orchy_results")")"
    local ralph_avg_diff orchy_avg_diff
    ralph_avg_diff="$(awk -v d="$ralph_diff_len" -v t="$ralph_total" 'BEGIN {printf "%.0f", d / (t > 0 ? t : 1)}')"
    orchy_avg_diff="$(awk -v d="$orchy_diff_len" -v t="$orchy_total" 'BEGIN {printf "%.0f", d / (t > 0 ? t : 1)}')"

    cat <<REPORT
# OrchyStraw vs Ralph — Head-to-Head Comparison

Date: $(date +%Y-%m-%d)
Tasks: $num_tasks | Model: $model | Timeout: ${timeout}s
OrchyStraw config: ${agents} agents, ${cycles} cycles

## Summary

| Metric | OrchyStraw (multi-agent) | Ralph (single-agent) | Delta |
|--------|--------------------------|----------------------|-------|
| Resolve rate | ${orchy_rate}% | ${ralph_rate}% | ${rate_delta} |
| Avg wall time | ${orchy_time}s | ${ralph_time}s | ${time_delta} |
| Avg rogue writes | ${orchy_avg_rogue} | ${ralph_avg_rogue} | ${rogue_delta} |
| Patch match rate | ${orchy_patch_avg} | ${ralph_patch_avg} | — |
| Avg diff size (chars) | ${orchy_avg_diff} | ${ralph_avg_diff} | — |
| Total resolved | ${orchy_resolved}/${orchy_total} | ${ralph_resolved}/${ralph_total} | — |

## Per-Task Results

| Task | OrchyStraw | Ralph | Winner |
|------|-----------|-------|--------|
REPORT

    RALPH_RESULTS_FILE="$ralph_results" ORCHY_RESULTS_FILE="$orchy_results" \
    python3 -c '
import json, os

ralph_data = {}
orchy_data = {}

with open(os.environ["RALPH_RESULTS_FILE"]) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        r = json.loads(line)
        ralph_data[r["instance_id"]] = r

with open(os.environ["ORCHY_RESULTS_FILE"]) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        r = json.loads(line)
        orchy_data[r["instance_id"]] = r

all_ids = list(dict.fromkeys(list(ralph_data.keys()) + list(orchy_data.keys())))

for tid in all_ids:
    r = ralph_data.get(tid, {})
    o = orchy_data.get(tid, {})

    r_status = r.get("status", "n/a")
    o_status = o.get("status", "n/a")
    r_time = r.get("wall_time_seconds", 0)
    o_time = o.get("wall_time_seconds", 0)

    r_label = f"{r_status} ({r_time}s)"
    o_label = f"{o_status} ({o_time}s)"

    r_pass = r.get("resolved", False)
    o_pass = o.get("resolved", False)
    if o_pass and not r_pass:
        winner = "OrchyStraw"
    elif r_pass and not o_pass:
        winner = "Ralph"
    elif o_pass and r_pass:
        winner = "OrchyStraw" if o_time < r_time else ("Ralph" if r_time < o_time else "Tie")
    else:
        winner = "Neither"

    print(f"| {tid} | {o_label} | {r_label} | {winner} |")
'

    printf '\n---\n*Generated by OrchyStraw benchmark harness*\n'
}

_dry_run() {
    local limit="$1" model="$2" agents="$3" cycles="$4"

    local tasks
    tasks="$(_load_tasks "$limit")"
    local count
    count="$(printf '%s\n' "$tasks" | grep -c . || echo 0)"

    _log "dry-run: $count task(s) — estimating cost for both approaches"

    printf '\n── Ralph (single-agent, 1 cycle) ──\n'
    local ralph_est
    ralph_est="$(estimate_cost "$count" "$model" 1 1)"
    print_estimate "$ralph_est"

    printf '── OrchyStraw (multi-agent, %s agents, %s cycles) ──\n' "$agents" "$cycles"
    local orchy_est
    orchy_est="$(estimate_cost "$count" "$model" "$agents" "$cycles")"
    print_estimate "$orchy_est"

    local ralph_cost orchy_cost total_cost
    ralph_cost="$(printf '%s' "$ralph_est" | jq -r '.estimated_total_cost_usd')"
    orchy_cost="$(printf '%s' "$orchy_est" | jq -r '.estimated_total_cost_usd')"
    total_cost="$(awk -v r="$ralph_cost" -v o="$orchy_cost" 'BEGIN {printf "%.2f", r + o}')"

    printf '── Combined ──\n'
    printf '  Total estimated cost: $%s\n\n' "$total_cost"
}

_check_deps() {
    local missing=()
    for cmd in git jq python3; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _die "missing dependencies: ${missing[*]}"
    fi
    if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        _die "bash 5.0+ required (found ${BASH_VERSION})"
    fi
}

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
    local ralph_results="$RESULTS_DIR/compare-ralph-${run_ts}.jsonl"
    local orchy_results="$RESULTS_DIR/compare-orchy-${run_ts}.jsonl"

    local tasks
    tasks="$(_load_tasks "$limit")"
    local task_count
    task_count="$(printf '%s\n' "$tasks" | grep -c . || echo 0)"

    [[ "$task_count" -gt 0 ]] || _die "no tasks found"

    _log "comparison run: $task_count tasks, model=$model, timeout=${timeout}s"
    _log "ralph: 1 agent, 1 cycle"
    _log "orchystraw: $agents agents, $cycles cycles"

    _log "── Phase 1: Running Ralph baseline ──"
    printf '%s\n' "$tasks" | _run_approach "ralph" 1 1 "$model" "$timeout" "$ralph_results"

    _log "── Phase 2: Running OrchyStraw ──"
    printf '%s\n' "$tasks" | _run_approach "orchy" "$agents" "$cycles" "$model" "$timeout" "$orchy_results"

    _log "── Phase 3: Generating comparison report ──"

    local ralph_summary="$RESULTS_DIR/compare-ralph-summary-${run_ts}.json"
    local orchy_summary="$RESULTS_DIR/compare-orchy-summary-${run_ts}.json"

    if [[ -f "$ralph_results" ]]; then
        aggregate_jsonl "$ralph_results" > "$ralph_summary"
    else
        _die "ralph results missing: $ralph_results"
    fi

    if [[ -f "$orchy_results" ]]; then
        aggregate_jsonl "$orchy_results" > "$orchy_summary"
    else
        _die "orchy results missing: $orchy_results"
    fi

    local report_file="$REPORTS_DIR/compare-ralph-${run_ts}.md"
    _generate_comparison_report \
        "$ralph_results" "$orchy_results" \
        "$ralph_summary" "$orchy_summary" \
        "$task_count" "$model" "$timeout" "$agents" "$cycles" \
        > "$report_file"

    _log "results:"
    _log "  ralph  → $ralph_results"
    _log "  orchy  → $orchy_results"
    _log "  report → $report_file"

    printf '\n'
    cat "$report_file"
}

main "$@"
