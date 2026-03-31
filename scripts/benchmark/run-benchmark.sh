#!/usr/bin/env bash
# ============================================
# OrchyStraw — Benchmark Runner (BENCH-001)
# ============================================
#
# Main entry point for all benchmark suites.
#
# Usage:
#   ./scripts/benchmark/run-benchmark.sh --suite custom --limit 5
#   ./scripts/benchmark/run-benchmark.sh --suite swebench-lite --dry-run
#   ./scripts/benchmark/run-benchmark.sh --suite custom --parallel 3
#   ./scripts/benchmark/run-benchmark.sh --report <results-dir>
#
# Suites: custom, swebench-lite, swebench, featurebench
# See docs/architecture/BENCHMARK-ARCHITECTURE.md for full spec.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CUSTOM_DIR="$SCRIPT_DIR/custom"
TASKS_DIR="$SCRIPT_DIR/tasks"
DEFAULT_RESULTS="$SCRIPT_DIR/results"
DEFAULT_REPORTS="$SCRIPT_DIR/reports"

source "$LIB_DIR/instance-runner.sh"
source "$LIB_DIR/cost-estimator.sh"
source "$LIB_DIR/results-collector.sh"

_log() { printf '[benchmark] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

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

_load_instances() {
    local suite="$1" limit="$2"
    local instances=()

    case "$suite" in
        custom)
            local tasks_file="$CUSTOM_DIR/tasks.jsonl"
            [[ -f "$tasks_file" ]] || _die "custom tasks not found: $tasks_file"
            local count=0
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                [[ "$line" == \#* ]] && continue
                instances+=("$line")
                count=$(( count + 1 ))
                [[ "$limit" -gt 0 ]] && [[ "$count" -ge "$limit" ]] && break
            done < "$tasks_file"
            ;;
        swebench-lite|swebench)
            local count=0
            for f in "$TASKS_DIR"/*.json; do
                [[ -f "$f" ]] || continue
                instances+=("$(cat "$f")")
                count=$(( count + 1 ))
                [[ "$limit" -gt 0 ]] && [[ "$count" -ge "$limit" ]] && break
            done
            ;;
        *)
            _die "unknown suite: $suite (valid: custom, swebench-lite, swebench)"
            ;;
    esac

    printf '%s\n' "${instances[@]}"
}

_run_all() {
    local suite="$1" limit="$2" model="$3" agents="$4" max_cycles="$5"
    local parallel="$6" timeout="$7" resume="$8" output_dir="$9"

    mkdir -p "$output_dir"
    local results_file="$output_dir/${suite}-$(date +%Y%m%d-%H%M%S).jsonl"
    local workspace_base="/tmp/orchystraw-bench-$$"

    export BENCH_MODEL="$model"
    export BENCH_AGENTS="$agents"

    _log "suite=$suite model=$model agents=$agents cycles=$max_cycles limit=$limit"
    _log "results → $results_file"

    local instances
    instances="$(_load_instances "$suite" "$limit")"
    local total
    total="$(printf '%s\n' "$instances" | grep -c . || true)"
    _log "loaded $total instance(s)"

    if [[ "$total" -eq 0 ]]; then
        _die "no instances to run"
    fi

    local completed=0 running=0 pids=()

    while IFS= read -r instance_json; do
        [[ -z "$instance_json" ]] && continue

        local id
        id="$(printf '%s' "$instance_json" | jq -r '.instance_id // .id')"

        if [[ "$resume" -eq 1 ]] && grep -q "\"instance_id\":\"$id\"" "$results_file" 2>/dev/null; then
            _log "skipping $id (already completed)"
            continue
        fi

        if [[ "$parallel" -gt 0 ]]; then
            local tmp_instance="/tmp/orchystraw-instance-$id.json"
            printf '%s' "$instance_json" > "$tmp_instance"
            (
                result="$(run_instance "$tmp_instance" "$workspace_base" "$model" "$max_cycles" "$timeout")"
                printf '%s\n' "$result" >> "$results_file"
                rm -f "$tmp_instance"
            ) &
            pids+=($!)
            running=$(( running + 1 ))
            if [[ "$running" -ge "$parallel" ]]; then
                wait -n 2>/dev/null || true
                running=$(( running - 1 ))
            fi
        else
            local tmp_instance="/tmp/orchystraw-instance-$id.json"
            printf '%s' "$instance_json" > "$tmp_instance"
            local result
            result="$(run_instance "$tmp_instance" "$workspace_base" "$model" "$max_cycles" "$timeout")" || true
            printf '%s\n' "$result" >> "$results_file"
            rm -f "$tmp_instance"
        fi

        completed=$(( completed + 1 ))
    done <<< "$instances"

    if [[ "$parallel" -gt 0 ]]; then
        for pid in "${pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done
    fi

    _log "all instances complete"

    local summary_file="$output_dir/${suite}-summary.json"
    aggregate_jsonl "$results_file" > "$summary_file"
    _log "summary → $summary_file"

    local report_file="${DEFAULT_REPORTS}/${suite}-$(date +%Y%m%d).md"
    mkdir -p "$DEFAULT_REPORTS"
    generate_report "$summary_file" "$results_file" "$suite" > "$report_file"
    _log "report → $report_file"

    printf '\n'
    jq '.' "$summary_file"
    printf '\n'
}

_usage() {
    cat <<'EOF'
Usage: run-benchmark.sh [OPTIONS]

Options:
  --suite <name>       Suite to run: custom, swebench-lite, swebench (required)
  --limit <N>          Max instances to run (default: 10)
  --model <name>       Model for agents: sonnet, opus, haiku (default: sonnet)
  --agents <N>         Agents per instance (default: 1)
  --max-cycles <N>     Max orchestrator cycles per instance (default: 5)
  --parallel <N>       Run up to N instances concurrently (default: 0 = sequential)
  --timeout <secs>     Timeout per instance in seconds (default: 600)
  --resume             Skip instances with existing results
  --dry-run            Estimate cost and exit without running
  --output <dir>       Results directory (default: scripts/benchmark/results/)
  --report <dir>       Print formatted report from existing results dir
  --help               Show this help

Suites:
  custom          Custom multi-file tasks (scripts/benchmark/custom/tasks.jsonl)
  swebench-lite   SWE-bench Lite tasks (scripts/benchmark/tasks/*.json)
  swebench        Full SWE-bench (requires swebench Python package)

Examples:
  ./run-benchmark.sh --suite custom --limit 5 --dry-run
  ./run-benchmark.sh --suite swebench-lite --limit 3 --model sonnet
  ./run-benchmark.sh --suite custom --parallel 3 --timeout 300
EOF
}

main() {
    local suite="" limit=10 model="sonnet" agents=1 max_cycles=5
    local parallel=0 timeout=600 resume=0 dry_run=0
    local output_dir="$DEFAULT_RESULTS"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --suite)     suite="$2"; shift 2 ;;
            --limit)     limit="$2"; shift 2 ;;
            --model)     model="$2"; shift 2 ;;
            --agents)    agents="$2"; shift 2 ;;
            --max-cycles) max_cycles="$2"; shift 2 ;;
            --parallel)  parallel="$2"; shift 2 ;;
            --timeout)   timeout="$2"; shift 2 ;;
            --resume)    resume=1; shift ;;
            --dry-run)   dry_run=1; shift ;;
            --output)    output_dir="$2"; shift 2 ;;
            --report)
                local rdir="$2"; shift 2
                local latest
                latest="$(ls -t "$rdir"/*-summary.json 2>/dev/null | head -1)"
                [[ -f "$latest" ]] || _die "no summary found in $rdir"
                jq '.' "$latest"
                exit 0
                ;;
            --help|-h)   _usage; exit 0 ;;
            *)           _die "unknown arg: $1" ;;
        esac
    done

    [[ -n "$suite" ]] || _die "missing --suite (use: custom, swebench-lite, swebench)"

    _check_deps

    if [[ "$dry_run" -eq 1 ]]; then
        local instances
        instances="$(_load_instances "$suite" "$limit")"
        local count
        count="$(printf '%s\n' "$instances" | grep -c .)" || count=0
        _log "dry-run: $count instance(s) from suite=$suite"
        local est
        est="$(estimate_cost "$count" "$model" "$agents" "$max_cycles")"
        print_estimate "$est"
        exit 0
    fi

    _run_all "$suite" "$limit" "$model" "$agents" "$max_cycles" \
        "$parallel" "$timeout" "$resume" "$output_dir"
}

main "$@"
