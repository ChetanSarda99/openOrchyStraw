#!/usr/bin/env bash
# =============================================================================
# run-cross-project.sh — Cross-project benchmark runner (#201)
#
# Runs 1 dry-run cycle on each registered project and measures:
#   - Agent count and configuration
#   - Prompt sizes (lines, chars, estimated tokens)
#   - Estimated total tokens per cycle
#   - Compares metrics across all projects
#   - Outputs a summary table
#
# Usage:
#   ./scripts/benchmark/run-cross-project.sh
#   ./scripts/benchmark/run-cross-project.sh --projects ~/Projects/Klaro,~/Projects/AIVA
#   ./scripts/benchmark/run-cross-project.sh --output json
#   ./scripts/benchmark/run-cross-project.sh --verbose
#
# Requires: bash 5.0+, orchystraw registered projects
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCH_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Auto-detect bash 5+ ──
if (( BASH_VERSINFO[0] < 5 )); then
    for _bash5 in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$_bash5" ]] && "$_bash5" -c '(( BASH_VERSINFO[0] >= 5 ))' 2>/dev/null; then
            exec "$_bash5" "$0" "$@"
        fi
    done
    printf 'ERROR: bash 5.0+ required. Install with: brew install bash\n' >&2
    exit 1
fi

# ── Defaults ──

OUTPUT_FORMAT="table"      # table | json | csv
VERBOSE=false
SPECIFIC_PROJECTS=""
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# ── CLI args ──

while [[ $# -gt 0 ]]; do
    case "$1" in
        --projects)  SPECIFIC_PROJECTS="$2"; shift 2 ;;
        --output)    OUTPUT_FORMAT="$2"; shift 2 ;;
        --verbose)   VERBOSE=true; shift ;;
        --help|-h)
            printf 'Usage: %s [--projects path1,path2] [--output table|json|csv] [--verbose]\n' "$0"
            exit 0
            ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
done

# ── Logging ──

_log()  { printf '[bench %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
_verb() { [[ "$VERBOSE" == true ]] && _log "$*"; }

# ── Helpers ──

# Estimate tokens from character count (~4 chars per token)
_estimate_tokens() {
    local chars="$1"
    echo $(( (chars + 3) / 4 ))
}

# Count agents in an agents.conf file
_count_agents() {
    local conf="$1"
    [[ ! -f "$conf" ]] && { echo 0; return; }
    grep -cvE '^\s*$|^\s*#' "$conf" 2>/dev/null || echo 0
}

# Measure a prompt file: lines, chars, tokens
_measure_prompt() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "0 0 0"; return; }
    local lines chars tokens
    lines=$(wc -l < "$file" | tr -d ' ')
    chars=$(wc -c < "$file" | tr -d ' ')
    tokens=$(_estimate_tokens "$chars")
    echo "$lines $chars $tokens"
}

# ── Discover projects ──

_discover_projects() {
    local -a projects=()

    if [[ -n "$SPECIFIC_PROJECTS" ]]; then
        IFS=',' read -ra projects <<< "$SPECIFIC_PROJECTS"
    else
        # Read from orchystraw registry
        local registry="$HOME/.orchystraw/registry.jsonl"
        if [[ -f "$registry" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local path=""
                if [[ "$line" =~ \"path\":\"([^\"]+)\" ]]; then
                    path="${BASH_REMATCH[1]}"
                fi
                [[ -n "$path" && -d "$path" ]] && projects+=("$path")
            done < "$registry"
        fi

        # Always include self
        local self_found=false
        for p in "${projects[@]}"; do
            [[ "$p" == "$ORCH_ROOT" ]] && self_found=true
        done
        [[ "$self_found" == false ]] && projects+=("$ORCH_ROOT")
    fi

    printf '%s\n' "${projects[@]}"
}

# ── Benchmark a single project ──

declare -g -A BENCH_RESULTS=()  # "project:metric" -> value

_benchmark_project() {
    local project_path="$1"
    local project_name
    project_name="$(basename "$project_path")"

    _log "Benchmarking: $project_name ($project_path)"

    # Find agents.conf
    local conf=""
    for candidate in "$project_path/agents.conf" "$project_path/scripts/agents.conf"; do
        [[ -f "$candidate" ]] && { conf="$candidate"; break; }
    done

    if [[ -z "$conf" ]]; then
        _log "  SKIP: No agents.conf found"
        BENCH_RESULTS["$project_name:status"]="no_config"
        return 0
    fi

    # Count agents
    local agent_count
    agent_count=$(_count_agents "$conf")
    BENCH_RESULTS["$project_name:agents"]="$agent_count"
    BENCH_RESULTS["$project_name:status"]="ok"

    _verb "  Agents: $agent_count"

    # Find prompts directory
    local prompts_dir=""
    for candidate in "$project_path/prompts" "$project_path/scripts/prompts"; do
        [[ -d "$candidate" ]] && { prompts_dir="$candidate"; break; }
    done

    # Measure each agent's prompt
    local total_lines=0
    local total_chars=0
    local total_tokens=0
    local prompt_count=0
    local max_prompt_tokens=0
    local max_prompt_agent=""

    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed="${raw_line#"${raw_line%%[![:space:]]*}"}"
        [[ "$trimmed" == \#* ]] && continue

        # Parse agent ID and prompt path
        IFS='|' read -r f_id f_prompt _ <<< "$raw_line"
        f_id="${f_id#"${f_id%%[![:space:]]*}"}"
        f_id="${f_id%"${f_id##*[![:space:]]}"}"
        f_prompt="${f_prompt#"${f_prompt%%[![:space:]]*}"}"
        f_prompt="${f_prompt%"${f_prompt##*[![:space:]]}"}"

        [[ -z "$f_id" ]] && continue

        # Resolve prompt path
        local prompt_file="$project_path/$f_prompt"
        if [[ ! -f "$prompt_file" && -n "$prompts_dir" ]]; then
            prompt_file="$prompts_dir/$f_prompt"
        fi

        if [[ -f "$prompt_file" ]]; then
            read -r p_lines p_chars p_tokens <<< "$(_measure_prompt "$prompt_file")"
            total_lines=$((total_lines + p_lines))
            total_chars=$((total_chars + p_chars))
            total_tokens=$((total_tokens + p_tokens))
            prompt_count=$((prompt_count + 1))

            if [[ "$p_tokens" -gt "$max_prompt_tokens" ]]; then
                max_prompt_tokens="$p_tokens"
                max_prompt_agent="$f_id"
            fi

            _verb "  $f_id: ${p_lines} lines, ~${p_tokens} tokens"
        else
            _verb "  $f_id: prompt not found ($f_prompt)"
        fi
    done < "$conf"

    BENCH_RESULTS["$project_name:prompt_count"]="$prompt_count"
    BENCH_RESULTS["$project_name:total_lines"]="$total_lines"
    BENCH_RESULTS["$project_name:total_chars"]="$total_chars"
    BENCH_RESULTS["$project_name:total_tokens"]="$total_tokens"
    BENCH_RESULTS["$project_name:max_tokens"]="$max_prompt_tokens"
    BENCH_RESULTS["$project_name:max_agent"]="$max_prompt_agent"

    # Average tokens per prompt
    if [[ "$prompt_count" -gt 0 ]]; then
        BENCH_RESULTS["$project_name:avg_tokens"]=$(( total_tokens / prompt_count ))
    else
        BENCH_RESULTS["$project_name:avg_tokens"]=0
    fi

    # Check for .orchystraw state
    if [[ -d "$project_path/.orchystraw" ]]; then
        BENCH_RESULTS["$project_name:has_state"]="yes"
        # Count cycles from quality-scores.jsonl if available
        local scores="$project_path/.orchystraw/quality-scores.jsonl"
        if [[ -f "$scores" ]]; then
            local cycle_count
            cycle_count=$(wc -l < "$scores" | tr -d ' ')
            BENCH_RESULTS["$project_name:history_entries"]="$cycle_count"
        else
            BENCH_RESULTS["$project_name:history_entries"]=0
        fi
    else
        BENCH_RESULTS["$project_name:has_state"]="no"
        BENCH_RESULTS["$project_name:history_entries"]=0
    fi

    # Dry-run cycle to measure timing
    local dry_run_time=0
    if [[ -x "$ORCH_ROOT/bin/orchystraw" ]]; then
        local start_time end_time
        start_time=$(date +%s)
        "$ORCH_ROOT/bin/orchystraw" run "$project_path" --dry-run --cycles 1 >/dev/null 2>&1 || true
        end_time=$(date +%s)
        dry_run_time=$((end_time - start_time))
    fi
    BENCH_RESULTS["$project_name:dry_run_secs"]="$dry_run_time"

    _log "  Done: ${agent_count} agents, ~${total_tokens} tokens, ${dry_run_time}s dry-run"
}

# ── Output formatters ──

_output_table() {
    local -a projects=("$@")

    printf '\n'
    printf '╔══════════════════════════════════════════════════════════════════════════════════════════╗\n'
    printf '║                   OrchyStraw Cross-Project Benchmark — %s                    ║\n' "$TIMESTAMP"
    printf '╠══════════════════════════════════════════════════════════════════════════════════════════╣\n'
    printf '║ %-20s │ %6s │ %8s │ %8s │ %8s │ %8s │ %6s ║\n' \
        "PROJECT" "AGENTS" "PROMPTS" "TOT_TOK" "AVG_TOK" "MAX_TOK" "DRY(s)"
    printf '╟──────────────────────┼────────┼──────────┼──────────┼──────────┼──────────┼────────╢\n'

    local grand_agents=0 grand_tokens=0

    for project in "${projects[@]}"; do
        local name
        name="$(basename "$project")"
        local status="${BENCH_RESULTS[$name:status]:-unknown}"

        if [[ "$status" == "no_config" ]]; then
            printf '║ %-20s │ %6s │ %8s │ %8s │ %8s │ %8s │ %6s ║\n' \
                "$name" "-" "-" "-" "-" "-" "SKIP"
            continue
        fi

        local agents="${BENCH_RESULTS[$name:agents]:-0}"
        local prompts="${BENCH_RESULTS[$name:prompt_count]:-0}"
        local tot_tok="${BENCH_RESULTS[$name:total_tokens]:-0}"
        local avg_tok="${BENCH_RESULTS[$name:avg_tokens]:-0}"
        local max_tok="${BENCH_RESULTS[$name:max_tokens]:-0}"
        local dry_secs="${BENCH_RESULTS[$name:dry_run_secs]:-0}"

        grand_agents=$((grand_agents + agents))
        grand_tokens=$((grand_tokens + tot_tok))

        printf '║ %-20s │ %6s │ %8s │ %8s │ %8s │ %8s │ %6s ║\n' \
            "$name" "$agents" "$prompts" "$tot_tok" "$avg_tok" "$max_tok" "$dry_secs"
    done

    printf '╟──────────────────────┼────────┼──────────┼──────────┼──────────┼──────────┼────────╢\n'
    printf '║ %-20s │ %6s │ %8s │ %8s │ %8s │ %8s │ %6s ║\n' \
        "TOTALS" "$grand_agents" "" "$grand_tokens" "" "" ""
    printf '╚══════════════════════════════════════════════════════════════════════════════════════════╝\n'

    # Additional insights
    printf '\n'
    printf 'Insights:\n'

    # Find largest project
    local max_project="" max_project_tokens=0
    for project in "${projects[@]}"; do
        local name
        name="$(basename "$project")"
        local tok="${BENCH_RESULTS[$name:total_tokens]:-0}"
        if [[ "$tok" -gt "$max_project_tokens" ]]; then
            max_project_tokens="$tok"
            max_project="$name"
        fi
    done
    [[ -n "$max_project" ]] && printf '  Largest project: %s (~%d tokens/cycle)\n' "$max_project" "$max_project_tokens"

    # Estimated daily cost at 5 cycles/day with sonnet
    local est_daily_tokens=$((grand_tokens * 5))
    local est_daily_cost=$(( est_daily_tokens * 300 / 1000000 ))  # $3/M tokens for sonnet
    printf '  Estimated daily cost (5 cycles/day, sonnet): ~$%d.%02d\n' "$((est_daily_cost / 100))" "$((est_daily_cost % 100))"

    printf '\n'
}

_output_json() {
    local -a projects=("$@")

    printf '{\n'
    printf '  "timestamp": "%s",\n' "$TIMESTAMP"
    printf '  "projects": [\n'

    local first=true
    for project in "${projects[@]}"; do
        local name
        name="$(basename "$project")"

        [[ "$first" == true ]] || printf ',\n'
        first=false

        printf '    {\n'
        printf '      "name": "%s",\n' "$name"
        printf '      "path": "%s",\n' "$project"
        printf '      "status": "%s",\n' "${BENCH_RESULTS[$name:status]:-unknown}"
        printf '      "agents": %s,\n' "${BENCH_RESULTS[$name:agents]:-0}"
        printf '      "prompt_count": %s,\n' "${BENCH_RESULTS[$name:prompt_count]:-0}"
        printf '      "total_tokens": %s,\n' "${BENCH_RESULTS[$name:total_tokens]:-0}"
        printf '      "avg_tokens": %s,\n' "${BENCH_RESULTS[$name:avg_tokens]:-0}"
        printf '      "max_tokens": %s,\n' "${BENCH_RESULTS[$name:max_tokens]:-0}"
        printf '      "max_agent": "%s",\n' "${BENCH_RESULTS[$name:max_agent]:-}"
        printf '      "dry_run_secs": %s,\n' "${BENCH_RESULTS[$name:dry_run_secs]:-0}"
        printf '      "has_state": "%s",\n' "${BENCH_RESULTS[$name:has_state]:-no}"
        printf '      "history_entries": %s\n' "${BENCH_RESULTS[$name:history_entries]:-0}"
        printf '    }'
    done

    printf '\n  ]\n'
    printf '}\n'
}

_output_csv() {
    local -a projects=("$@")

    printf 'project,agents,prompts,total_tokens,avg_tokens,max_tokens,max_agent,dry_run_secs,has_state\n'

    for project in "${projects[@]}"; do
        local name
        name="$(basename "$project")"
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$name" \
            "${BENCH_RESULTS[$name:agents]:-0}" \
            "${BENCH_RESULTS[$name:prompt_count]:-0}" \
            "${BENCH_RESULTS[$name:total_tokens]:-0}" \
            "${BENCH_RESULTS[$name:avg_tokens]:-0}" \
            "${BENCH_RESULTS[$name:max_tokens]:-0}" \
            "${BENCH_RESULTS[$name:max_agent]:-}" \
            "${BENCH_RESULTS[$name:dry_run_secs]:-0}" \
            "${BENCH_RESULTS[$name:has_state]:-no}"
    done
}

# ── Main ──

main() {
    _log "OrchyStraw Cross-Project Benchmark"
    _log "ORCH_ROOT: $ORCH_ROOT"

    mkdir -p "$RESULTS_DIR"

    # Discover projects
    local -a projects=()
    while IFS= read -r p; do
        [[ -n "$p" ]] && projects+=("$p")
    done <<< "$(_discover_projects)"

    if [[ ${#projects[@]} -eq 0 ]]; then
        _log "No projects found. Register projects with: orchystraw run <path>"
        exit 1
    fi

    _log "Found ${#projects[@]} projects"

    # Benchmark each project
    for project in "${projects[@]}"; do
        _benchmark_project "$project"
    done

    # Output results
    case "$OUTPUT_FORMAT" in
        table)
            _output_table "${projects[@]}"
            ;;
        json)
            _output_json "${projects[@]}" | tee "$RESULTS_DIR/cross-project-$TIMESTAMP.json"
            ;;
        csv)
            _output_csv "${projects[@]}" | tee "$RESULTS_DIR/cross-project-$TIMESTAMP.csv"
            ;;
    esac

    _log "Benchmark complete."
}

main "$@"
