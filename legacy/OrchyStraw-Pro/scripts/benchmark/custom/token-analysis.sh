#!/usr/bin/env bash
# ============================================
# Token Cost Reduction Analysis
# ============================================
#
# Parses cycle logs and session tracker to estimate token usage per agent,
# identify high-cost agents, and suggest optimization targets.
#
# Usage:
#   ./token-analysis.sh [--cycles N] [--model sonnet] [--format table|json]
#                       [--top N] [--help]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$BENCH_DIR/../.." && pwd)"
REPORTS_DIR="$BENCH_DIR/reports"

TRACKER_FILE="$PROJECT_ROOT/prompts/00-session-tracker/SESSION_TRACKER.txt"
AGENTS_CONF="$PROJECT_ROOT/scripts/agents.conf"
CONTEXT_FILE="$PROJECT_ROOT/prompts/00-shared-context/context.md"

_log() { printf '[token-analysis] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

# ── Input validation ─────────────────────────────────────────────

_validate_positive_int() {
    local name="$1" value="$2"
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        _die "$name must be a positive integer, got: '$value'"
    fi
}

_validate_format() {
    local fmt="$1"
    case "$fmt" in
        table|json) ;;
        *) _die "invalid format: '$fmt' (valid: table, json)" ;;
    esac
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
Usage: token-analysis.sh [OPTIONS]

Analyzes token usage across orchestrator cycles and identifies
cost reduction opportunities.

Options:
  --cycles <N>      Number of recent cycles to analyze (default: all)
  --model <name>    Model for cost calc: sonnet, opus, haiku (default: sonnet)
  --format <fmt>    Output format: table, json (default: table)
  --top <N>         Show top N agents by cost (default: 5)
  --help, -h        Show this help

Data sources:
  - prompts/00-session-tracker/SESSION_TRACKER.txt (cycle history)
  - scripts/agents.conf (agent definitions + intervals)
  - prompts/00-shared-context/context.md (codebase size info)

Examples:
  ./token-analysis.sh
  ./token-analysis.sh --cycles 10 --model opus
  ./token-analysis.sh --format json --top 3
EOF
}

# ── Token cost rates (per 1M tokens, USD) ────────────────────────

declare -A INPUT_COST=(
    [sonnet]=3.00
    [opus]=15.00
    [haiku]=0.25
)
declare -A OUTPUT_COST=(
    [sonnet]=15.00
    [opus]=75.00
    [haiku]=1.25
)

# Average tokens per agent invocation (estimated from prompt sizes)
# Agents with larger prompts consume more input tokens
declare -A AGENT_INPUT_TOKENS=(
    [01]=18000   # CEO — reads strategy docs + shared context
    [02]=22000   # CTO — reads architecture + tech registry + shared context
    [03]=25000   # PM — reads ALL agent prompts + shared context (heaviest reader)
    [04]=20000   # Tauri-Rust — reads Rust src + prompts
    [05]=20000   # Tauri-UI — reads React src + prompts
    [06]=30000   # Backend — reads src/core (39 modules) + integration guide + prompts
    [07]=18000   # iOS — reads iOS src + prompts
    [08]=15000   # Pixel — reads pixel src + prompts (smaller scope)
    [09]=22000   # QA — reads test files + reports + prompts
    [10]=20000   # Security — reads all src + prompts (read-only audit)
    [11]=20000   # Web — reads site/ src + prompts
    [13]=12000   # HR — reads team docs + prompts (lightest)
)
declare -A AGENT_OUTPUT_TOKENS=(
    [01]=4000    # CEO — writes memos (short)
    [02]=6000    # CTO — writes ADRs, reviews (medium)
    [03]=8000    # PM — writes prompt updates, status (heavy writes)
    [04]=10000   # Tauri-Rust — writes Rust code
    [05]=10000   # Tauri-UI — writes React code
    [06]=15000   # Backend — writes bash modules + tests (heaviest writer)
    [07]=10000   # iOS — writes Swift code
    [08]=8000    # Pixel — writes pixel code
    [09]=6000    # QA — writes reports, verifications
    [10]=5000    # Security — writes audit reports (read-heavy, write-light)
    [11]=12000   # Web — writes Next.js pages (heavy)
    [13]=3000    # HR — writes health reports (lightest)
)

# Agent names for display
declare -A AGENT_NAMES=(
    [01]="CEO" [02]="CTO" [03]="PM" [04]="Tauri-Rust" [05]="Tauri-UI"
    [06]="Backend" [07]="iOS" [08]="Pixel" [09]="QA" [10]="Security"
    [11]="Web" [13]="HR"
)

# ── Parse session tracker ────────────────────────────────────────

_parse_cycles() {
    local max_cycles="$1"

    [[ -f "$TRACKER_FILE" ]] || _die "session tracker not found: $TRACKER_FILE"

    # Extract cycle rows: | N | date | agents | outcomes |
    # Filter to lines matching the table format
    local lines
    lines="$(grep -E '^\| [0-9]+ \|' "$TRACKER_FILE" || true)"

    if [[ -z "$lines" ]]; then
        _die "no cycle data found in session tracker"
    fi

    # If max_cycles set, take only the last N
    if [[ "$max_cycles" -gt 0 ]]; then
        lines="$(printf '%s\n' "$lines" | tail -n "$max_cycles")"
    fi

    printf '%s\n' "$lines"
}

# ── Count agent invocations ──────────────────────────────────────

_count_invocations() {
    local cycle_data="$1"

    # For each agent, count how many cycles they appeared in
    declare -A invocations
    for agent_id in "${!AGENT_NAMES[@]}"; do
        invocations[$agent_id]=0
    done

    while IFS= read -r line; do
        # Extract agents column (3rd column): "01,02,06,08,09,10,11"
        local agents_col
        agents_col="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')"

        # Split by comma and count
        IFS=',' read -ra agent_list <<< "$agents_col"
        for agent in "${agent_list[@]}"; do
            agent="$(printf '%s' "$agent" | tr -d ' ')"
            # Validate agent id format
            if [[ "$agent" =~ ^[0-9]+$ ]]; then
                if [[ -n "${invocations[$agent]+x}" ]]; then
                    invocations[$agent]=$(( invocations[$agent] + 1 ))
                fi
            fi
        done
    done <<< "$cycle_data"

    # Output as agent_id:count lines
    for agent_id in $(printf '%s\n' "${!invocations[@]}" | sort); do
        printf '%s:%d\n' "$agent_id" "${invocations[$agent_id]}"
    done
}

# ── Calculate costs ──────────────────────────────────────────────

_calculate_costs() {
    local invocation_data="$1" model="$2"

    local input_rate="${INPUT_COST[$model]:-3.00}"
    local output_rate="${OUTPUT_COST[$model]:-15.00}"

    local total_input_tokens=0
    local total_output_tokens=0
    local total_cost_usd="0.00"

    # Process each agent's invocation count
    while IFS=: read -r agent_id count; do
        [[ -z "$agent_id" ]] && continue
        [[ "$count" -eq 0 ]] && continue

        local agent_input="${AGENT_INPUT_TOKENS[$agent_id]:-20000}"
        local agent_output="${AGENT_OUTPUT_TOKENS[$agent_id]:-8000}"

        local input_total=$(( agent_input * count ))
        local output_total=$(( agent_output * count ))
        total_input_tokens=$(( total_input_tokens + input_total ))
        total_output_tokens=$(( total_output_tokens + output_total ))

        local agent_cost
        agent_cost="$(awk "BEGIN {printf \"%.4f\", ($input_total / 1000000) * $input_rate + ($output_total / 1000000) * $output_rate}")"

        local name="${AGENT_NAMES[$agent_id]:-agent-$agent_id}"
        printf '%s|%s|%d|%d|%d|%s\n' "$agent_id" "$name" "$count" "$input_total" "$output_total" "$agent_cost"
    done <<< "$invocation_data"

    total_cost_usd="$(awk "BEGIN {printf \"%.2f\", ($total_input_tokens / 1000000) * $input_rate + ($total_output_tokens / 1000000) * $output_rate}")"

    # Emit totals on a special line
    printf 'TOTAL||0|%d|%d|%s\n' "$total_input_tokens" "$total_output_tokens" "$total_cost_usd"
}

# ── Find idle agents ─────────────────────────────────────────────

_find_idle_agents() {
    local cost_data="$1" cycle_data="$2"

    local total_cycles
    total_cycles="$(printf '%s\n' "$cycle_data" | grep -c . || echo 1)"

    # Agents that ran but produced no commits or meaningful output
    # Heuristic: agents that appear in many cycles but whose outcomes mention "STANDBY" or "no changes"
    while IFS='|' read -r agent_id name count input output cost; do
        [[ "$agent_id" == "TOTAL" ]] && continue
        [[ -z "$agent_id" ]] && continue
        [[ "$count" -eq 0 ]] && continue

        # Check if this agent had many idle cycles
        local idle_mentions
        idle_mentions="$(printf '%s' "$cycle_data" | grep -i "standby\|no change\|idle\|zero changes" | grep -c "$agent_id" || echo 0)"

        if [[ "$idle_mentions" -gt 0 ]]; then
            local idle_pct
            idle_pct="$(awk "BEGIN {printf \"%.0f\", ($idle_mentions / $count) * 100}")"
            if [[ "${idle_pct%.*}" -ge 50 ]]; then
                printf '%s|%s|%d|%d|%s|%s\n' "$agent_id" "$name" "$count" "$idle_mentions" "$idle_pct" "$cost"
            fi
        fi
    done <<< "$cost_data"
}

# ── Output: table format ─────────────────────────────────────────

_output_table() {
    local cost_data="$1" idle_data="$2" model="$3" num_cycles="$4" top_n="$5"

    printf '\n'
    printf '# Token Cost Analysis Report\n\n'
    printf 'Date: %s | Model: %s | Cycles analyzed: %s\n\n' "$(date +%Y-%m-%d)" "$model" "$num_cycles"

    # ── Per-agent cost table (sorted by cost descending)
    printf '## Per-Agent Token Usage\n\n'
    printf '| Rank | Agent | Invocations | Input Tokens | Output Tokens | Est. Cost |\n'
    printf '|------|-------|-------------|-------------|---------------|----------|\n'

    local rank=0
    # Sort by cost (field 6) descending, skip TOTAL line
    printf '%s\n' "$cost_data" | grep -v '^TOTAL|' | sort -t'|' -k6 -rn | head -n "$top_n" | \
    while IFS='|' read -r agent_id name count input output cost; do
        [[ -z "$agent_id" ]] && continue
        rank=$(( rank + 1 ))
        printf '| %d | %s (%s) | %d | %s | %s | $%s |\n' \
            "$rank" "$name" "$agent_id" "$count" \
            "$(printf '%d' "$input" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')" \
            "$(printf '%d' "$output" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')" \
            "$cost"
    done

    # ── Totals
    local total_line
    total_line="$(printf '%s\n' "$cost_data" | grep '^TOTAL|')"
    if [[ -n "$total_line" ]]; then
        local total_input total_output total_cost
        total_input="$(printf '%s' "$total_line" | cut -d'|' -f4)"
        total_output="$(printf '%s' "$total_line" | cut -d'|' -f5)"
        total_cost="$(printf '%s' "$total_line" | cut -d'|' -f6)"

        printf '\n## Totals\n\n'
        printf '| Metric | Value |\n'
        printf '|--------|-------|\n'
        printf '| Total input tokens | %s |\n' "$(printf '%d' "$total_input" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
        printf '| Total output tokens | %s |\n' "$(printf '%d' "$total_output" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
        printf '| Estimated total cost | $%s |\n' "$total_cost"
        printf '| Cost per cycle | $%s |\n' "$(awk "BEGIN {printf \"%.2f\", $total_cost / ($num_cycles > 0 ? $num_cycles : 1)}")"
    fi

    # ── Idle agents / optimization targets
    if [[ -n "$idle_data" ]]; then
        printf '\n## Optimization Targets (Idle Agents)\n\n'
        printf 'Agents that ran frequently but were idle (STANDBY/no changes) 50%%+ of the time:\n\n'
        printf '| Agent | Invocations | Idle Cycles | Idle %% | Wasted Cost |\n'
        printf '|-------|-------------|------------|--------|------------|\n'

        while IFS='|' read -r agent_id name count idle_count idle_pct cost; do
            [[ -z "$agent_id" ]] && continue
            printf '| %s (%s) | %d | %d | %s%% | $%s |\n' \
                "$name" "$agent_id" "$count" "$idle_count" "$idle_pct" "$cost"
        done <<< "$idle_data"
    fi

    # ── Recommendations
    printf '\n## Recommendations\n\n'
    printf '1. **Increase agent intervals** — Agents on STANDBY should run less frequently (every 3rd+ cycle)\n'
    printf '2. **Use conditional activation** — `conditional-activation.sh` can skip idle agents automatically\n'
    printf '3. **Apply prompt compression** — `prompt-compression.sh` can reduce input tokens 30-70%%\n'
    printf '4. **Use context filtering** — `context-filter.sh` sends only relevant context per agent\n'
    printf '5. **Model tiering** — Use haiku for status-check agents, opus only for complex decisions\n'

    printf '\n---\n*Generated by OrchyStraw token-analysis*\n'
}

# ── Output: JSON format ──────────────────────────────────────────

_output_json() {
    local cost_data="$1" idle_data="$2" model="$3" num_cycles="$4" top_n="$5"

    printf '{\n'
    printf '  "date": "%s",\n' "$(date +%Y-%m-%d)"
    printf '  "model": "%s",\n' "$model"
    printf '  "cycles_analyzed": %d,\n' "$num_cycles"
    printf '  "agents": [\n'

    local first=1
    printf '%s\n' "$cost_data" | grep -v '^TOTAL|' | sort -t'|' -k6 -rn | head -n "$top_n" | \
    while IFS='|' read -r agent_id name count input output cost; do
        [[ -z "$agent_id" ]] && continue
        [[ "$first" -eq 0 ]] && printf ',\n'
        first=0
        printf '    {"id": "%s", "name": "%s", "invocations": %d, "input_tokens": %d, "output_tokens": %d, "cost_usd": %s}' \
            "$agent_id" "$name" "$count" "$input" "$output" "$cost"
    done

    printf '\n  ],\n'

    # Totals
    local total_line
    total_line="$(printf '%s\n' "$cost_data" | grep '^TOTAL|')"
    local total_input total_output total_cost
    total_input="$(printf '%s' "$total_line" | cut -d'|' -f4)"
    total_output="$(printf '%s' "$total_line" | cut -d'|' -f5)"
    total_cost="$(printf '%s' "$total_line" | cut -d'|' -f6)"

    printf '  "totals": {"input_tokens": %d, "output_tokens": %d, "cost_usd": %s, "cost_per_cycle": %s}\n' \
        "$total_input" "$total_output" "$total_cost" \
        "$(awk "BEGIN {printf \"%.2f\", $total_cost / ($num_cycles > 0 ? $num_cycles : 1)}")"

    printf '}\n'
}

# ── Main ─────────────────────────────────────────────────────────

main() {
    local max_cycles=0 model="sonnet" format="table" top_n=5

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cycles)  _validate_positive_int "cycles" "$2"; max_cycles="$2"; shift 2 ;;
            --model)   _validate_model "$2";                  model="$2"; shift 2 ;;
            --format)  _validate_format "$2";                 format="$2"; shift 2 ;;
            --top)     _validate_positive_int "top" "$2";     top_n="$2"; shift 2 ;;
            --help|-h) _usage; exit 0 ;;
            *)         _die "unknown arg: $1" ;;
        esac
    done

    [[ -f "$TRACKER_FILE" ]] || _die "session tracker not found: $TRACKER_FILE"

    # Parse cycle data
    local cycle_data
    cycle_data="$(_parse_cycles "$max_cycles")"
    local num_cycles
    num_cycles="$(printf '%s\n' "$cycle_data" | grep -c . || echo 0)"

    [[ "$num_cycles" -gt 0 ]] || _die "no cycle data found"

    _log "analyzing $num_cycles cycles with model=$model"

    # Count agent invocations
    local invocation_data
    invocation_data="$(_count_invocations "$cycle_data")"

    # Calculate costs
    local cost_data
    cost_data="$(_calculate_costs "$invocation_data" "$model")"

    # Find idle agents
    local idle_data
    idle_data="$(_find_idle_agents "$cost_data" "$cycle_data")"

    # Output
    mkdir -p "$REPORTS_DIR"

    case "$format" in
        table) _output_table "$cost_data" "$idle_data" "$model" "$num_cycles" "$top_n" ;;
        json)  _output_json "$cost_data" "$idle_data" "$model" "$num_cycles" "$top_n" ;;
    esac
}

main "$@"
