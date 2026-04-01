#!/usr/bin/env bash
# test-e2e-dry-run.sh — E2E golden test: auto-agent.sh orchestrate --dry-run
# Validates that dry-run output contains expected structural elements.
# CI-friendly: no side effects, no git operations, exits 0/1.
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

assert_not_contains() {
    local desc="$1" pattern="$2" text="$3"
    if ! echo "$text" | grep -qE "$pattern"; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (pattern "%s" should NOT be present)\n' "$desc" "$pattern" >&2
        (( FAIL++ )) || true
    fi
}

assert_exit() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" -eq "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

# ── Run dry-run and capture output ──
printf 'test-e2e-dry-run: running auto-agent.sh orchestrate --dry-run...\n'

exit_code=0
output=$(bash "$PROJECT_ROOT/scripts/auto-agent.sh" orchestrate --dry-run 2>&1) || exit_code=$?

# ── Test 1: Exit code is 0 ──
assert_exit "dry-run exits 0" 0 "$exit_code"

# ── Test 2: Header banner present ──
assert_contains "header banner" "orchystraw v3" "$output"

# ── Test 3: DRY RUN marker present ──
assert_contains "DRY RUN marker" "DRY RUN" "$output"

# ── Test 4: Cycle preview present ──
assert_contains "cycle preview header" "Cycle.*Preview" "$output"

# ── Test 5: Agent table headers ──
assert_contains "AGENT ID column" "AGENT ID" "$output"
assert_contains "INTERVAL column" "INTERVAL" "$output"
assert_contains "EXISTS column" "EXISTS" "$output"
assert_contains "LABEL column" "LABEL" "$output"

# ── Test 6: At least one agent listed ──
assert_contains "at least one agent row" "(every|last)" "$output"

# ── Test 7: Summary section ──
assert_contains "agents scheduled count" "Agents scheduled" "$output"
assert_contains "regular workers count" "Regular workers" "$output"
assert_contains "coordinators count" "Coordinators" "$output"

# ── Test 8: Parallel groups ──
assert_contains "parallel groups" "parallel groups" "$output"
assert_contains "group listed" "Group [0-9]+" "$output"

# ── Test 9: Ownership preview ──
assert_contains "ownership section" "File ownership" "$output"

# ── Test 10: No-execution notice ──
assert_contains "no execution notice" "Nothing was executed" "$output"

# ── Test 11: Known agents appear ──
assert_contains "backend agent" "06-backend" "$output"
assert_contains "PM agent" "03-pm" "$output"

# ── Test 12: No error traces ──
assert_not_contains "no bash errors" "syntax error|unbound variable|command not found" "$output"

# ── Test 13: Table structure (border chars) ──
assert_contains "table borders" "\\+.*\\+.*\\+" "$output"

# ── Test 14: Conf file path shown ──
assert_contains "conf file shown" "agents.conf" "$output"

# ── Results ──
printf '\ntest-e2e-dry-run: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
