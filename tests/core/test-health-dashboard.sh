#!/usr/bin/env bash
# test-health-dashboard.sh — Test HTML dashboard generation
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
mkdir -p "$TMPDIR/.orchystraw" "$TMPDIR/scripts"

# Create minimal agents.conf
cat > "$TMPDIR/scripts/agents.conf" << 'CONF'
# id | prompt | ownership | interval | label
03-pm  | prompts/03-pm.txt | prompts/ | 0 | PM Coordinator
06-backend | prompts/06-backend.txt | scripts/ | 1 | Backend Developer
CONF

# Create sample audit.jsonl with cost data
cat > "$TMPDIR/.orchystraw/audit.jsonl" << 'AUDIT'
{"ts":"2026-04-04T10:00:00Z","cycle":1,"agent":"06-backend","outcome":"success","files":3,"duration_s":60,"prompt_lines":10,"tokens_est":40,"model":"opus","cost_estimate":"0.001200","commit":"abc123"}
{"ts":"2026-04-04T10:05:00Z","cycle":1,"agent":"03-pm","outcome":"success","files":1,"duration_s":30,"prompt_lines":5,"tokens_est":20,"model":"sonnet","cost_estimate":"0.000120","commit":"abc124"}
AUDIT

# Create sample metrics.jsonl
cat > "$TMPDIR/.orchystraw/metrics.jsonl" << 'METRICS'
{"ts":"2026-04-04T10:00:00Z","cycle":1,"commits":4,"issues_open":22}
METRICS

git init -q "$TMPDIR"

OUTPUT="$TMPDIR/.orchystraw/dashboard.html"
bash "$PROJECT_ROOT/scripts/health-dashboard.sh" "$TMPDIR" "$OUTPUT"

if [[ ! -f "$OUTPUT" ]]; then
    printf '  FAIL: dashboard.html not created\n' >&2
    exit 1
fi

HTML=$(cat "$OUTPUT")

# Test HTML structure
assert_contains "has doctype" "<!DOCTYPE html>" "$HTML"
assert_contains "has title" "OrchyStraw Health Dashboard" "$HTML"
assert_contains "has agent table" "Agent Status Grid" "$HTML"
assert_contains "has backend agent" "06-backend" "$HTML"
assert_contains "has PM agent" "03-pm" "$HTML"
assert_contains "has model column" "Model" "$HTML"
assert_contains "has cost column" "Est. Cost" "$HTML"
assert_contains "has velocity chart" "velocityChart" "$HTML"
assert_contains "has cost chart" "costChart" "$HTML"
assert_contains "has dark theme" "#0a0a0a" "$HTML"

printf 'test-health-dashboard: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
