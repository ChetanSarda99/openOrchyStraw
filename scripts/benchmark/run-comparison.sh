#!/usr/bin/env bash
# ============================================
# OrchyStraw — Benchmark Comparison
# ============================================
#
# Compares two benchmark runs (from run-orchestration-bench.sh or run-benchmark.sh).
# Shows deltas for: wall time, tokens, files changed, commit count, resolve rate.
#
# Usage:
#   ./run-comparison.sh --baseline results/run-A.json --candidate results/run-B.json
#   ./run-comparison.sh --baseline results/run-A.json --candidate results/run-B.json --format markdown
#   ./run-comparison.sh --baseline results/run-A.json --candidate results/run-B.json --format json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

_log() { printf '[compare] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

_check_deps() {
    if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        _die "bash 5.0+ required (found ${BASH_VERSION})"
    fi
    command -v python3 >/dev/null 2>&1 || _die "python3 required for comparison"
}

_usage() {
    cat <<'EOF'
Usage: run-comparison.sh [OPTIONS]

Options:
  --baseline <file>    First benchmark result JSON (required)
  --candidate <file>   Second benchmark result JSON (required)
  --format <fmt>       Output format: text, markdown, json (default: text)
  --help               Show this help

Compares two orchestration benchmark runs and shows:
  - Wall time delta (total and per-agent)
  - Token usage delta
  - Files changed delta
  - Commit count delta
  - Percentage improvements/regressions

For SWE-bench results, also compares resolve rates.

Examples:
  ./run-comparison.sh --baseline run-A.json --candidate run-B.json
  ./run-comparison.sh --baseline run-A.json --candidate run-B.json --format markdown
EOF
}

_compare() {
    local baseline="$1" candidate="$2" format="$3"

    BENCH_BASELINE="$baseline" BENCH_CANDIDATE="$candidate" BENCH_FORMAT="$format" \
    python3 <<'PYEOF'
import json, os, sys

baseline_path = os.environ["BENCH_BASELINE"]
candidate_path = os.environ["BENCH_CANDIDATE"]
fmt = os.environ["BENCH_FORMAT"]

with open(baseline_path) as f:
    baseline = json.load(f)
with open(candidate_path) as f:
    candidate = json.load(f)

def pct_change(old, new):
    if old == 0:
        return 0.0 if new == 0 else 100.0
    return round((new - old) / old * 100, 1)

def direction(delta):
    if delta < 0:
        return "faster"
    elif delta > 0:
        return "slower"
    return "same"

def direction_higher_better(delta):
    if delta > 0:
        return "better"
    elif delta < 0:
        return "worse"
    return "same"

# Detect result type
is_orchestration = "cycles" in baseline and "cycles" in candidate
is_swebench = "resolve_rate" in baseline or "total" in baseline

result = {
    "baseline_file": baseline_path,
    "candidate_file": candidate_path,
    "comparisons": []
}

if is_orchestration:
    b_time = baseline.get("total_wall_time_seconds", 0)
    c_time = candidate.get("total_wall_time_seconds", 0)
    time_delta = c_time - b_time
    time_pct = pct_change(b_time, c_time)

    result["comparisons"].append({
        "metric": "Total Wall Time",
        "baseline": f"{b_time}s",
        "candidate": f"{c_time}s",
        "delta": f"{time_delta:+d}s",
        "pct_change": f"{time_pct:+.1f}%",
        "direction": direction(time_delta)
    })

    b_agents = {}
    c_agents = {}

    for cycle in baseline.get("cycles", []):
        for agent in cycle.get("agents", []):
            aid = agent["agent"]
            if aid not in b_agents:
                b_agents[aid] = {"time": 0, "tokens": 0, "files": 0, "commits": 0, "n": 0}
            b_agents[aid]["time"] += agent.get("wall_time_seconds", 0)
            b_agents[aid]["tokens"] += agent.get("estimated_tokens", 0)
            b_agents[aid]["files"] += agent.get("files_changed", 0)
            b_agents[aid]["commits"] += agent.get("commits", 0)
            b_agents[aid]["n"] += 1

    for cycle in candidate.get("cycles", []):
        for agent in cycle.get("agents", []):
            aid = agent["agent"]
            if aid not in c_agents:
                c_agents[aid] = {"time": 0, "tokens": 0, "files": 0, "commits": 0, "n": 0}
            c_agents[aid]["time"] += agent.get("wall_time_seconds", 0)
            c_agents[aid]["tokens"] += agent.get("estimated_tokens", 0)
            c_agents[aid]["files"] += agent.get("files_changed", 0)
            c_agents[aid]["commits"] += agent.get("commits", 0)
            c_agents[aid]["n"] += 1

    all_agents = sorted(set(list(b_agents.keys()) + list(c_agents.keys())))
    agent_comparisons = []

    for aid in all_agents:
        b = b_agents.get(aid, {"time": 0, "tokens": 0, "files": 0, "commits": 0, "n": 1})
        c = c_agents.get(aid, {"time": 0, "tokens": 0, "files": 0, "commits": 0, "n": 1})
        bn = b["n"] or 1
        cn = c["n"] or 1

        agent_comparisons.append({
            "agent": aid,
            "avg_time_baseline": round(b["time"] / bn, 1),
            "avg_time_candidate": round(c["time"] / cn, 1),
            "avg_tokens_baseline": round(b["tokens"] / bn),
            "avg_tokens_candidate": round(c["tokens"] / cn),
            "avg_files_baseline": round(b["files"] / bn, 1),
            "avg_files_candidate": round(c["files"] / cn, 1),
            "time_pct": pct_change(b["time"] / bn, c["time"] / cn),
            "tokens_pct": pct_change(b["tokens"] / bn, c["tokens"] / cn)
        })

    result["agent_comparisons"] = agent_comparisons

elif is_swebench:
    for metric in ["resolve_rate", "avg_wall_time_seconds", "avg_cycles", "rogue_write_rate"]:
        bv = baseline.get(metric, 0)
        cv = candidate.get(metric, 0)
        delta = round(cv - bv, 1)
        higher_better = metric in ("resolve_rate",)
        result["comparisons"].append({
            "metric": metric,
            "baseline": bv,
            "candidate": cv,
            "delta": delta,
            "pct_change": f"{pct_change(bv, cv):+.1f}%",
            "direction": direction_higher_better(delta) if higher_better else direction(delta)
        })

# Output
if fmt == "json":
    print(json.dumps(result, indent=2))
elif fmt == "markdown":
    lines = ["# Benchmark Comparison", ""]
    lines.append(f"**Baseline:** `{baseline_path}`")
    lines.append(f"**Candidate:** `{candidate_path}`")
    lines.append("")
    lines.append("## Overall Metrics")
    lines.append("")
    lines.append("| Metric | Baseline | Candidate | Delta | Change | Direction |")
    lines.append("|--------|----------|-----------|-------|--------|-----------|")
    for c in result.get("comparisons", []):
        lines.append(f"| {c['metric']} | {c['baseline']} | {c['candidate']} | {c['delta']} | {c['pct_change']} | {c['direction']} |")

    if "agent_comparisons" in result:
        lines.append("")
        lines.append("## Per-Agent Comparison")
        lines.append("")
        lines.append("| Agent | Time(B) | Time(C) | Time% | Tokens(B) | Tokens(C) | Tokens% |")
        lines.append("|-------|---------|---------|-------|-----------|-----------|---------|")
        for a in result["agent_comparisons"]:
            lines.append(f"| {a['agent']} | {a['avg_time_baseline']}s | {a['avg_time_candidate']}s | {a['time_pct']:+.1f}% | {a['avg_tokens_baseline']} | {a['avg_tokens_candidate']} | {a['tokens_pct']:+.1f}% |")

    lines.append("")
    lines.append("---")
    lines.append("*Generated by OrchyStraw benchmark comparison*")
    print("\n".join(lines))
else:
    # text format
    print("=" * 60)
    print("  BENCHMARK COMPARISON")
    print("=" * 60)
    print(f"  Baseline:  {baseline_path}")
    print(f"  Candidate: {candidate_path}")
    print()

    for c in result.get("comparisons", []):
        icon = ">>>" if "faster" in str(c.get("direction","")) or "better" in str(c.get("direction","")) else "   "
        print(f"  {icon} {c['metric']:30s}  {c['baseline']:>10}  ->  {c['candidate']:>10}  ({c['pct_change']}  {c['direction']})")

    if "agent_comparisons" in result:
        print()
        print("-" * 60)
        print("  PER-AGENT COMPARISON")
        print("-" * 60)
        for a in result["agent_comparisons"]:
            print(f"  {a['agent']:15s}  time: {a['avg_time_baseline']:>6.1f}s -> {a['avg_time_candidate']:>6.1f}s ({a['time_pct']:+.1f}%)  tokens: {a['avg_tokens_baseline']:>6} -> {a['avg_tokens_candidate']:>6} ({a['tokens_pct']:+.1f}%)")

    print()
    print("=" * 60)
PYEOF
}

main() {
    local baseline="" candidate="" format="text"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --baseline)  baseline="$2"; shift 2 ;;
            --candidate) candidate="$2"; shift 2 ;;
            --format)    format="$2"; shift 2 ;;
            --help|-h)   _usage; exit 0 ;;
            *)           _die "unknown arg: $1" ;;
        esac
    done

    [[ -n "$baseline" ]] || _die "missing --baseline"
    [[ -n "$candidate" ]] || _die "missing --candidate"
    [[ -f "$baseline" ]] || _die "baseline file not found: $baseline"
    [[ -f "$candidate" ]] || _die "candidate file not found: $candidate"

    case "$format" in
        text|markdown|json) ;;
        *) _die "unknown format: $format (use: text, markdown, json)" ;;
    esac

    _check_deps
    _compare "$baseline" "$candidate" "$format"
}

main "$@"
