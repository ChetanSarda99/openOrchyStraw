#!/usr/bin/env bash
# ============================================
# OrchyStraw — Orchestration Benchmark Runner
# ============================================
#
# Standalone benchmark that measures orchestration cycle performance.
# Takes a project dir + agents.conf, runs N cycles, measures:
#   - Wall-clock time per agent
#   - Estimated tokens used (prompt line count * ~4 tokens/line)
#   - Files changed per agent
#   - Commit count per agent
# Outputs: JSON results + markdown summary
#
# Usage:
#   ./run-orchestration-bench.sh --project-dir /path/to/project --conf agents.conf --cycles 3
#   ./run-orchestration-bench.sh --project-dir . --cycles 5 --output results/
#   ./run-orchestration-bench.sh --project-dir . --dry-run
#
# Requires: bash 5.0+, git, auto-agent.sh in scripts/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

_log() { printf '[orch-bench] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

# ── Validate environment ──

_check_deps() {
    if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        _die "bash 5.0+ required (found ${BASH_VERSION})"
    fi
    for cmd in git date; do
        command -v "$cmd" >/dev/null 2>&1 || _die "missing dependency: $cmd"
    done
}

# ── Parse agents.conf ──

_parse_agents() {
    local conf_file="$1"
    local agents=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        local agent_id
        agent_id="$(printf '%s' "$line" | cut -d'|' -f1 | tr -d ' ')"
        [[ -n "$agent_id" ]] && agents+=("$agent_id")
    done < "$conf_file"
    printf '%s\n' "${agents[@]}"
}

_get_agent_prompt() {
    local conf_file="$1" agent_id="$2"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        local id prompt
        id="$(printf '%s' "$line" | cut -d'|' -f1 | tr -d ' ')"
        if [[ "$id" == "$agent_id" ]]; then
            prompt="$(printf '%s' "$line" | cut -d'|' -f2 | tr -d ' ')"
            printf '%s' "$prompt"
            return 0
        fi
    done < "$conf_file"
    return 1
}

_get_agent_ownership() {
    local conf_file="$1" agent_id="$2"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        local id ownership
        id="$(printf '%s' "$line" | cut -d'|' -f1 | tr -d ' ')"
        if [[ "$id" == "$agent_id" ]]; then
            ownership="$(printf '%s' "$line" | cut -d'|' -f3 | sed 's/^ *//;s/ *$//')"
            printf '%s' "$ownership"
            return 0
        fi
    done < "$conf_file"
    return 1
}

# ── Measure single agent ──

_estimate_tokens() {
    local prompt_file="$1"
    if [[ -f "$prompt_file" ]]; then
        local lines
        lines=$(wc -l < "$prompt_file") || lines=0
        printf '%d' "$(( lines * 4 ))"
    else
        printf '0'
    fi
}

_count_files_changed() {
    local project_dir="$1" agent_id="$2" before_sha="$3" after_sha="$4"
    if [[ "$before_sha" == "$after_sha" ]]; then
        printf '0'
        return
    fi
    local count
    count=$(git -C "$project_dir" diff --name-only "$before_sha" "$after_sha" 2>/dev/null | wc -l) || count=0
    printf '%d' "$count"
}

_count_commits() {
    local project_dir="$1" before_sha="$2" after_sha="$3"
    if [[ "$before_sha" == "$after_sha" ]]; then
        printf '0'
        return
    fi
    local count
    count=$(git -C "$project_dir" rev-list --count "$before_sha".."$after_sha" 2>/dev/null) || count=0
    printf '%d' "$count"
}

# ── Run a single cycle, collecting per-agent metrics ──

_run_cycle() {
    local project_dir="$1" conf_file="$2" cycle_num="$3" dry_run="$4"
    local cycle_start cycle_end
    cycle_start=$(date +%s)

    local agents_list
    agents_list="$(_parse_agents "$conf_file")"

    local agent_results=()

    while IFS= read -r agent_id; do
        [[ -z "$agent_id" ]] && continue

        local agent_start before_sha prompt_file tokens files_changed commits agent_end wall_time
        agent_start=$(date +%s)
        before_sha=$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || echo "none")

        prompt_file="$(_get_agent_prompt "$conf_file" "$agent_id")" || prompt_file=""
        local full_prompt_path="$project_dir/$prompt_file"
        tokens=$(_estimate_tokens "$full_prompt_path")

        if [[ "$dry_run" -eq 1 ]]; then
            _log "[dry-run] cycle=$cycle_num agent=$agent_id tokens=$tokens"
        else
            # Run the agent via auto-agent.sh single-agent mode if available
            local auto_agent="$project_dir/scripts/auto-agent.sh"
            if [[ -x "$auto_agent" ]]; then
                bash "$auto_agent" single "$agent_id" --dry-run 2>/dev/null || true
            fi
        fi

        local after_sha
        after_sha=$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || echo "none")
        agent_end=$(date +%s)
        wall_time=$(( agent_end - agent_start ))
        files_changed=$(_count_files_changed "$project_dir" "$agent_id" "$before_sha" "$after_sha")
        commits=$(_count_commits "$project_dir" "$before_sha" "$after_sha")

        agent_results+=("{\"agent\":\"$agent_id\",\"wall_time_seconds\":$wall_time,\"estimated_tokens\":$tokens,\"files_changed\":$files_changed,\"commits\":$commits}")
    done <<< "$agents_list"

    cycle_end=$(date +%s)
    local cycle_time=$(( cycle_end - cycle_start ))

    # Build cycle JSON
    local agents_json
    agents_json=$(printf '%s,' "${agent_results[@]}")
    agents_json="[${agents_json%,}]"

    printf '{"cycle":%d,"wall_time_seconds":%d,"agents":%s}' \
        "$cycle_num" "$cycle_time" "$agents_json"
}

# ── Generate markdown summary ──

_generate_markdown() {
    local json_file="$1" output_file="$2"

    cat > "$output_file" <<'HEADER'
# Orchestration Benchmark Results

HEADER

    if ! command -v python3 >/dev/null 2>&1; then
        # Fallback: just dump the JSON
        printf '```json\n' >> "$output_file"
        cat "$json_file" >> "$output_file"
        printf '\n```\n' >> "$output_file"
        return
    fi

    BENCH_JSON="$json_file" python3 -c '
import json, os, sys

with open(os.environ["BENCH_JSON"]) as f:
    data = json.load(f)

meta = data.get("metadata", {})
cycles = data.get("cycles", [])

lines = []
lines.append(f"**Project:** {meta.get(\"project_dir\", \"unknown\")}")
lines.append(f"**Config:** {meta.get(\"conf_file\", \"unknown\")}")
lines.append(f"**Cycles:** {meta.get(\"total_cycles\", 0)}")
lines.append(f"**Total time:** {data.get(\"total_wall_time_seconds\", 0)}s")
lines.append(f"**Timestamp:** {meta.get(\"timestamp\", \"unknown\")}")
lines.append("")
lines.append("## Per-Cycle Summary")
lines.append("")
lines.append("| Cycle | Time(s) | Agents | Total Files | Total Commits |")
lines.append("|-------|---------|--------|-------------|---------------|")

for c in cycles:
    agents = c.get("agents", [])
    total_files = sum(a.get("files_changed", 0) for a in agents)
    total_commits = sum(a.get("commits", 0) for a in agents)
    lines.append(f"| {c[\"cycle\"]} | {c[\"wall_time_seconds\"]} | {len(agents)} | {total_files} | {total_commits} |")

lines.append("")
lines.append("## Per-Agent Averages")
lines.append("")
lines.append("| Agent | Avg Time(s) | Avg Tokens | Avg Files | Avg Commits |")
lines.append("|-------|-------------|------------|-----------|-------------|")

agent_stats = {}
for c in cycles:
    for a in c.get("agents", []):
        aid = a["agent"]
        if aid not in agent_stats:
            agent_stats[aid] = {"time": [], "tokens": [], "files": [], "commits": []}
        agent_stats[aid]["time"].append(a.get("wall_time_seconds", 0))
        agent_stats[aid]["tokens"].append(a.get("estimated_tokens", 0))
        agent_stats[aid]["files"].append(a.get("files_changed", 0))
        agent_stats[aid]["commits"].append(a.get("commits", 0))

for aid in sorted(agent_stats.keys()):
    s = agent_stats[aid]
    n = len(s["time"]) or 1
    lines.append(f"| {aid} | {sum(s[\"time\"])/n:.1f} | {sum(s[\"tokens\"])/n:.0f} | {sum(s[\"files\"])/n:.1f} | {sum(s[\"commits\"])/n:.1f} |")

lines.append("")
lines.append("---")
lines.append("*Generated by OrchyStraw orchestration benchmark*")

print("\n".join(lines))
' >> "$output_file"
}

# ── Main ──

_usage() {
    cat <<'EOF'
Usage: run-orchestration-bench.sh [OPTIONS]

Options:
  --project-dir <path>   Project directory to benchmark (required)
  --conf <file>          agents.conf file path (default: agents.conf in project dir)
  --cycles <N>           Number of orchestration cycles to run (default: 3)
  --output <dir>         Output directory for results (default: scripts/benchmark/results/)
  --dry-run              Measure prompt sizes only, don't run agents
  --help                 Show this help

Outputs:
  <output>/orch-bench-<timestamp>.json   — Full JSON results
  <output>/orch-bench-<timestamp>.md     — Markdown summary

Examples:
  ./run-orchestration-bench.sh --project-dir /path/to/project --cycles 3
  ./run-orchestration-bench.sh --project-dir . --conf agents.conf --dry-run
EOF
}

main() {
    local project_dir="" conf_file="" cycles=3 dry_run=0
    local output_dir="$SCRIPT_DIR/results"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project-dir) project_dir="$2"; shift 2 ;;
            --conf)        conf_file="$2"; shift 2 ;;
            --cycles)      cycles="$2"; shift 2 ;;
            --output)      output_dir="$2"; shift 2 ;;
            --dry-run)     dry_run=1; shift ;;
            --help|-h)     _usage; exit 0 ;;
            *)             _die "unknown arg: $1" ;;
        esac
    done

    [[ -n "$project_dir" ]] || _die "missing --project-dir"
    [[ -d "$project_dir" ]] || _die "project dir not found: $project_dir"

    # Resolve absolute path
    project_dir="$(cd "$project_dir" && pwd)"

    # Find agents.conf
    if [[ -z "$conf_file" ]]; then
        conf_file="$project_dir/agents.conf"
    fi
    [[ -f "$conf_file" ]] || _die "agents.conf not found: $conf_file"

    _check_deps

    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$output_dir"

    local json_file="$output_dir/orch-bench-${timestamp}.json"
    local md_file="$output_dir/orch-bench-${timestamp}.md"

    _log "project=$project_dir conf=$conf_file cycles=$cycles dry_run=$dry_run"
    _log "output → $json_file"

    local total_start
    total_start=$(date +%s)

    local cycle_results=()
    local i
    for (( i=1; i<=cycles; i++ )); do
        _log "── cycle $i/$cycles ──"
        local cycle_json
        cycle_json="$(_run_cycle "$project_dir" "$conf_file" "$i" "$dry_run")"
        cycle_results+=("$cycle_json")
    done

    local total_end
    total_end=$(date +%s)
    local total_time=$(( total_end - total_start ))

    # Build final JSON
    local cycles_json
    cycles_json=$(printf '%s,' "${cycle_results[@]}")
    cycles_json="[${cycles_json%,}]"

    cat > "$json_file" <<JSON
{
  "metadata": {
    "project_dir": "$project_dir",
    "conf_file": "$conf_file",
    "total_cycles": $cycles,
    "dry_run": $([ "$dry_run" -eq 1 ] && echo "true" || echo "false"),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "total_wall_time_seconds": $total_time,
  "cycles": $cycles_json
}
JSON

    _log "JSON results → $json_file"

    # Generate markdown summary
    _generate_markdown "$json_file" "$md_file"
    _log "Markdown summary → $md_file"

    # Print summary to stdout
    _log "total time: ${total_time}s across $cycles cycles"
    cat "$md_file"
}

main "$@"
