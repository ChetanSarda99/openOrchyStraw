#!/usr/bin/env bash
# ============================================
# Ralph Baseline — single-agent comparison runner
# ============================================
#
# Runs the same custom tasks using a single claude invocation (no orchestrator)
# for apples-to-apples comparison with OrchyStraw's multi-agent approach.
#
# Usage:
#   ./ralph-baseline.sh [--limit N] [--model sonnet] [--timeout 600]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$BENCH_DIR/lib"

source "$LIB_DIR/instance-runner.sh"
source "$LIB_DIR/results-collector.sh"

TASKS_FILE="$SCRIPT_DIR/tasks.jsonl"
RESULTS_DIR="$BENCH_DIR/results"

_log() { printf '[ralph] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_die() { _log "ERROR: $*" >&2; exit 1; }

main() {
    local limit=10 model="sonnet" timeout=600

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)   limit="$2"; shift 2 ;;
            --model)   model="$2"; shift 2 ;;
            --timeout) timeout="$2"; shift 2 ;;
            --help|-h) echo "Usage: ralph-baseline.sh [--limit N] [--model sonnet] [--timeout 600]"; exit 0 ;;
            *) _die "unknown arg: $1" ;;
        esac
    done

    [[ -f "$TASKS_FILE" ]] || _die "tasks file not found: $TASKS_FILE"

    mkdir -p "$RESULTS_DIR"
    local results_file="$RESULTS_DIR/ralph-$(date +%Y%m%d-%H%M%S).jsonl"
    local workspace_base="/tmp/orchystraw-ralph-$$"

    export BENCH_MODEL="$model"
    export BENCH_AGENTS=1

    _log "running ralph baseline (model=$model, limit=$limit, timeout=$timeout)"

    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        count=$(( count + 1 ))
        [[ "$count" -gt "$limit" ]] && break

        local id
        id="$(printf '%s' "$line" | jq -r '.instance_id // .id')"
        _log "task $count: $id"

        local tmp="/tmp/orchystraw-ralph-$id.json"
        printf '%s' "$line" > "$tmp"

        local result
        result="$(run_instance "$tmp" "$workspace_base" "$model" 1 "$timeout")" || true
        printf '%s\n' "$result" >> "$results_file"
        rm -f "$tmp"

    done < "$TASKS_FILE"

    _log "complete — $count tasks"
    _log "results → $results_file"

    # Aggregate
    if [[ -f "$results_file" ]]; then
        local summary="$RESULTS_DIR/ralph-summary.json"
        aggregate_jsonl "$results_file" > "$summary"
        _log "summary → $summary"
        jq '.' "$summary"
    fi
}

main "$@"
