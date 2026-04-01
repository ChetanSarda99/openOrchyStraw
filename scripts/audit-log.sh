#!/usr/bin/env bash
# audit-log.sh — Append-only audit trail per agent invocation
# Inspired by Paperclip's immutable audit system.
#
# Usage: bash scripts/audit-log.sh <agent_id> <cycle> <outcome> <files_changed> <duration_secs> [prompt_file] [project_root]
# Output: Appends to .orchystraw/audit.jsonl

set -euo pipefail

AGENT_ID="${1:?Usage: audit-log.sh <agent_id> <cycle> <outcome> <files> <duration> [prompt_file] [project_root]}"
CYCLE="${2:?}"
OUTCOME="${3:-unknown}"
FILES="${4:-0}"
DURATION="${5:-0}"
PROMPT_FILE="${6:-}"
PROJECT_ROOT="${7:-$(cd "$(dirname "$0")/.." && pwd)}"
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

printf '{"ts":"%s","cycle":%d,"agent":"%s","outcome":"%s","files":%d,"duration_s":%d,"prompt_lines":%d,"tokens_est":%d,"commit":"%s"}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$CYCLE" "$AGENT_ID" "$OUTCOME" "$FILES" "$DURATION" \
    "$prompt_lines" "$tokens_est" "$COMMIT_HASH" \
    >> "$AUDIT_FILE"
