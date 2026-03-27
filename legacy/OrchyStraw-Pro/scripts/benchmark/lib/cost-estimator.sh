#!/usr/bin/env bash
# Cost Estimator — estimates benchmark run cost before committing
set -euo pipefail

# Token cost estimates (per 1M tokens, USD)
# Updated 2026-03-20 — adjust as pricing changes
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

# Average tokens per instance (estimated from initial runs)
AVG_INPUT_TOKENS=25000
AVG_OUTPUT_TOKENS=8000

estimate_cost() {
    local num_instances="${1:-1}"
    local model="${2:-sonnet}"
    local agents_per_instance="${3:-1}"
    local max_cycles="${4:-5}"

    local input_rate="${INPUT_COST[$model]:-3.00}"
    local output_rate="${OUTPUT_COST[$model]:-15.00}"

    # Scale by agents and cycles
    local total_input=$(( AVG_INPUT_TOKENS * num_instances * agents_per_instance * max_cycles ))
    local total_output=$(( AVG_OUTPUT_TOKENS * num_instances * agents_per_instance * max_cycles ))

    # Cost in USD (integer math with 2 decimal places via bc or awk)
    local input_cost output_cost total_cost
    input_cost="$(awk "BEGIN {printf \"%.2f\", ($total_input / 1000000) * $input_rate}")"
    output_cost="$(awk "BEGIN {printf \"%.2f\", ($total_output / 1000000) * $output_rate}")"
    total_cost="$(awk "BEGIN {printf \"%.2f\", $input_cost + $output_cost}")"

    # Output as JSON
    jq -n \
        --arg instances "$num_instances" \
        --arg model "$model" \
        --arg agents "$agents_per_instance" \
        --arg cycles "$max_cycles" \
        --arg input_tokens "$total_input" \
        --arg output_tokens "$total_output" \
        --arg input_cost "$input_cost" \
        --arg output_cost "$output_cost" \
        --arg total_cost "$total_cost" \
        '{
            instances: ($instances | tonumber),
            model: $model,
            agents_per_instance: ($agents | tonumber),
            max_cycles: ($cycles | tonumber),
            estimated_input_tokens: ($input_tokens | tonumber),
            estimated_output_tokens: ($output_tokens | tonumber),
            estimated_input_cost_usd: ($input_cost | tonumber),
            estimated_output_cost_usd: ($output_cost | tonumber),
            estimated_total_cost_usd: ($total_cost | tonumber)
        }'
}

# Pretty-print cost estimate
print_estimate() {
    local json="$1"
    printf '\n'
    printf '╔══════════════════════════════════════════════╗\n'
    printf '║        Benchmark Cost Estimate               ║\n'
    printf '╠══════════════════════════════════════════════╣\n'
    printf '║  Instances:    %-6s  Model: %-14s ║\n' \
        "$(printf '%s' "$json" | jq -r '.instances')" \
        "$(printf '%s' "$json" | jq -r '.model')"
    printf '║  Agents/inst:  %-6s  Cycles: %-13s ║\n' \
        "$(printf '%s' "$json" | jq -r '.agents_per_instance')" \
        "$(printf '%s' "$json" | jq -r '.max_cycles')"
    printf '╠══════════════════════════════════════════════╣\n'
    printf '║  Input tokens:  %-28s ║\n' \
        "$(printf '%s' "$json" | jq -r '.estimated_input_tokens | tostring | explode | reverse | [range(0;length;3) as $i | .[($i):($i+3)]] | map(implode) | reverse | join(",")' 2>/dev/null || printf '%s' "$json" | jq -r '.estimated_input_tokens')"
    printf '║  Output tokens: %-28s ║\n' \
        "$(printf '%s' "$json" | jq -r '.estimated_output_tokens | tostring | explode | reverse | [range(0;length;3) as $i | .[($i):($i+3)]] | map(implode) | reverse | join(",")' 2>/dev/null || printf '%s' "$json" | jq -r '.estimated_output_tokens')"
    printf '╠══════════════════════════════════════════════╣\n'
    printf '║  Input cost:   $%-28s ║\n' "$(printf '%s' "$json" | jq -r '.estimated_input_cost_usd')"
    printf '║  Output cost:  $%-28s ║\n' "$(printf '%s' "$json" | jq -r '.estimated_output_cost_usd')"
    printf '║  ─────────────────────────────────────────── ║\n'
    printf '║  TOTAL:        $%-28s ║\n' "$(printf '%s' "$json" | jq -r '.estimated_total_cost_usd')"
    printf '╚══════════════════════════════════════════════╝\n'
    printf '\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    json="$(estimate_cost "$@")"
    print_estimate "$json"
fi
