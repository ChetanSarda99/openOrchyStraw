#!/usr/bin/env bash
# audit-log.sh — Append-only audit trail per agent invocation
# Inspired by Paperclip's immutable audit system.
#
# Usage: bash scripts/audit-log.sh <agent_id> <cycle> <outcome> <files_changed> <duration_secs> [prompt_file] [project_root]
# Output: Appends to .orchystraw/audit.jsonl

set -euo pipefail

AGENT_ID="${1:?Usage: audit-log.sh <agent_id> <cycle> <outcome> <files> <duration> [prompt_file] [model] [project_root]}"
CYCLE="${2:?}"
OUTCOME="${3:-unknown}"
FILES="${4:-0}"
DURATION="${5:-0}"
PROMPT_FILE="${6:-}"
MODEL="${7:-opus}"
PROJECT_ROOT="${8:-$(cd "$(dirname "$0")/.." && pwd)}"
AUDIT_FILE="$PROJECT_ROOT/.orchystraw/audit.jsonl"

mkdir -p "$(dirname "$AUDIT_FILE")"

COMMIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "none")

prompt_lines=0
tokens_est=0
if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
    prompt_lines=$(wc -l < "$PROMPT_FILE" | tr -d '[:space:]')
    prompt_lines="${prompt_lines:-0}"
    tokens_est=$(( prompt_lines * 4 ))
fi

# Cost estimation per model (USD per 1K tokens, blended input/output estimate)
# Rates approximate: opus=$0.03, sonnet=$0.006, haiku=$0.0005 per 1K tokens
_cost_per_1k() {
    case "${1:-opus}" in
        opus|claude-opus-4-6)       echo 30000 ;;   # $0.030 * 1000000
        sonnet|claude-sonnet-4-6)   echo 6000 ;;    # $0.006 * 1000000
        haiku|claude-haiku-4-5)     echo 500 ;;     # $0.0005 * 1000000
        *)                          echo 6000 ;;    # default to sonnet rate
    esac
}

rate=$(_cost_per_1k "$MODEL")
# cost_microdollars = tokens_est * rate / 1000  (rate is per 1K tokens scaled by 1M)
cost_microdollars=0
if [[ "$tokens_est" -gt 0 ]]; then
    cost_microdollars=$(( tokens_est * rate / 1000 ))
fi
# Format as dollars with 6 decimal places
cost_dollars="0.$(printf '%06d' "$cost_microdollars")"

printf '{"ts":"%s","cycle":%d,"agent":"%s","outcome":"%s","files":%d,"duration_s":%d,"prompt_lines":%d,"tokens_est":%d,"model":"%s","cost_estimate":"%s","commit":"%s"}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$CYCLE" "$AGENT_ID" "$OUTCOME" "$FILES" "$DURATION" \
    "$prompt_lines" "$tokens_est" "$MODEL" "$cost_dollars" "$COMMIT_HASH" \
    >> "$AUDIT_FILE"
