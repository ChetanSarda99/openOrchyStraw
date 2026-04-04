#!/usr/bin/env bash
# test-audit-cost.sh — Test per-agent cost tracking in audit-log.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_contains() {
    local desc="$1" pattern="$2" text="$3"
    if echo "$text" | grep -qE "$pattern"; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (pattern "%s" not found)\n' "$desc" "$pattern" >&2
        (( FAIL++ )) || true
    fi
}

# Setup temp project
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.orchystraw"
git init -q "$TMPDIR"

# Create a dummy prompt file (10 lines => ~40 tokens)
PROMPT_FILE="$TMPDIR/test-prompt.txt"
for i in $(seq 1 10); do echo "line $i of the prompt"; done > "$PROMPT_FILE"

# Test 1: audit-log.sh with model param produces cost_estimate field
bash "$PROJECT_ROOT/scripts/audit-log.sh" "06-backend" 1 "success" 3 60 "$PROMPT_FILE" "opus" "$TMPDIR"
AUDIT_LINE=$(cat "$TMPDIR/.orchystraw/audit.jsonl")

assert_contains "has model field" '"model":"opus"' "$AUDIT_LINE"
assert_contains "has cost_estimate field" '"cost_estimate":"0\.' "$AUDIT_LINE"
assert_contains "has tokens_est" '"tokens_est":40' "$AUDIT_LINE"

# Test 2: different models produce different costs
bash "$PROJECT_ROOT/scripts/audit-log.sh" "09-qa" 2 "success" 1 30 "$PROMPT_FILE" "haiku" "$TMPDIR"
HAIKU_LINE=$(tail -1 "$TMPDIR/.orchystraw/audit.jsonl")
assert_contains "haiku model recorded" '"model":"haiku"' "$HAIKU_LINE"

# Test 3: sonnet model
bash "$PROJECT_ROOT/scripts/audit-log.sh" "11-web" 3 "success" 2 45 "$PROMPT_FILE" "sonnet" "$TMPDIR"
SONNET_LINE=$(tail -1 "$TMPDIR/.orchystraw/audit.jsonl")
assert_contains "sonnet model recorded" '"model":"sonnet"' "$SONNET_LINE"

# Test 4: default model (opus) when called with explicit model
bash "$PROJECT_ROOT/scripts/audit-log.sh" "01-ceo" 4 "success" 0 10 "$PROMPT_FILE" "opus" "$TMPDIR"
DEFAULT_LINE=$(tail -1 "$TMPDIR/.orchystraw/audit.jsonl")
assert_contains "opus model recorded" '"model":"opus"' "$DEFAULT_LINE"

# Test 5: verify all 3 lines exist
LINE_COUNT=$(wc -l < "$TMPDIR/.orchystraw/audit.jsonl" | tr -d '[:space:]')
if [[ "$LINE_COUNT" -eq 4 ]]; then
    (( PASS++ )) || true
else
    printf '  FAIL: expected 4 audit lines, got %s\n' "$LINE_COUNT" >&2
    (( FAIL++ )) || true
fi

printf 'test-audit-cost: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
