#!/usr/bin/env bash
# audit-log.sh — Append-only audit trail per agent invocation
# Inspired by Paperclip's immutable audit system.
#
# Usage: bash scripts/audit-log.sh <agent_id> <cycle> <outcome> <files_changed> <duration_secs> [project_root]
# Output: Appends to .orchystraw/audit.jsonl

set -euo pipefail

AGENT_ID="${1:?Usage: audit-log.sh <agent_id> <cycle> <outcome> <files> <duration>}"
CYCLE="${2:?}"
OUTCOME="${3:-unknown}"
FILES="${4:-0}"
DURATION="${5:-0}"
PROJECT_ROOT="${6:-$(cd "$(dirname "$0")/.." && pwd)}"
AUDIT_FILE="$PROJECT_ROOT/.orchystraw/audit.jsonl"

mkdir -p "$(dirname "$AUDIT_FILE")"

COMMIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "none")

printf '{"ts":"%s","cycle":%d,"agent":"%s","outcome":"%s","files":%d,"duration_s":%d,"commit":"%s"}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$CYCLE" "$AGENT_ID" "$OUTCOME" "$FILES" "$DURATION" "$COMMIT_HASH" \
    >> "$AUDIT_FILE"
