#!/usr/bin/env bash
# Test: issue-tracker.sh — Local issue tracker module
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Test harness ──
PASS=0
FAIL=0

_assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected=%s actual=%s)\n' "$desc" "$expected" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if echo "$actual" | grep -qE "$pattern"; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (pattern=%s actual=%s)\n' "$desc" "$pattern" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_fail() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        printf '  FAIL: %s (expected failure but succeeded)\n' "$desc"
        FAIL=$(( FAIL + 1 ))
    else
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    fi
}

_assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file not found: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected to contain: %s)\n' "$desc" "$needle"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (should NOT contain: %s)\n' "$desc" "$needle"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Setup: use a temp directory for issue storage ──
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

export ORCH_ISSUE_DIR="$TEST_TMP/issues"

# ── Source the module ──
source "$PROJECT_ROOT/src/core/issue-tracker.sh"

echo "=== test-issue-tracker.sh ==="

# ────────────────────────────────────────────
# Group 1: Create issues
# ────────────────────────────────────────────
echo ""
echo "── Group 1: Create issues ──"

result=$(orch_issue_create "Fix login bug" "P1")
_assert "create returns ID 1" "1" "$result"

result=$(orch_issue_create "Add dashboard widget" "P2" "05-tauri-ui")
_assert "create with assignee returns ID 2" "2" "$result"

result=$(orch_issue_create "Refactor orchestrator" "P0" "06-backend" "backend,core")
_assert "create with assignee+labels returns ID 3" "3" "$result"

_assert_file_exists "issues.jsonl created" "$TEST_TMP/issues/issues.jsonl"

line_count=$(wc -l < "$TEST_TMP/issues/issues.jsonl")
_assert "JSONL has 3 lines" "3" "$line_count"

# ────────────────────────────────────────────
# Group 2: Show issue details
# ────────────────────────────────────────────
echo ""
echo "── Group 2: Show issue details ──"

result=$(orch_issue_show 1)
_assert_contains "show issue 1 title" "Fix login bug" "$result"
_assert_contains "show issue 1 status" "open" "$result"
_assert_contains "show issue 1 priority" "P1" "$result"

result=$(orch_issue_show 3)
_assert_contains "show issue 3 assignee" "06-backend" "$result"
_assert_contains "show issue 3 labels" "backend,core" "$result"

# ────────────────────────────────────────────
# Group 3: List issues with filters
# ────────────────────────────────────────────
echo ""
echo "── Group 3: List issues with filters ──"

result=$(orch_issue_list)
_assert_contains "list all shows issue 1" "Fix login bug" "$result"
_assert_contains "list all shows issue 2" "Add dashboard widget" "$result"
_assert_contains "list all shows issue 3" "Refactor orchestrator" "$result"

result=$(orch_issue_list --status open)
_assert_contains "list open shows issues" "Fix login bug" "$result"

result=$(orch_issue_list --priority P0)
_assert_contains "list P0 shows issue 3" "Refactor orchestrator" "$result"
_assert_not_contains "list P0 excludes issue 1" "Fix login bug" "$result"

result=$(orch_issue_list --assignee 06-backend)
_assert_contains "list by assignee shows issue 3" "Refactor orchestrator" "$result"

# ────────────────────────────────────────────
# Group 4: Close issues
# ────────────────────────────────────────────
echo ""
echo "── Group 4: Close issues ──"

orch_issue_close 1
result=$(orch_issue_show 1)
_assert_contains "closed issue has status closed" "closed" "$result"
_assert_contains "closed issue has closed_at timestamp" "Closed:" "$result"

result=$(orch_issue_list --status closed)
_assert_contains "list closed shows issue 1" "Fix login bug" "$result"

result=$(orch_issue_list --status open)
_assert_not_contains "list open excludes closed issue" "Fix login bug" "$result"

# ────────────────────────────────────────────
# Group 5: Assign issues
# ────────────────────────────────────────────
echo ""
echo "── Group 5: Assign issues ──"

orch_issue_assign 2 "06-backend"
result=$(orch_issue_show 2)
_assert_contains "assigned issue shows new assignee" "06-backend" "$result"

# ────────────────────────────────────────────
# Group 6: Update issues
# ────────────────────────────────────────────
echo ""
echo "── Group 6: Update issues ──"

orch_issue_update 2 --priority P0
result=$(orch_issue_show 2)
_assert_contains "updated priority shows P0" "P0" "$result"

orch_issue_update 2 --labels "urgent,frontend"
result=$(orch_issue_show 2)
_assert_contains "updated labels shows new labels" "urgent,frontend" "$result"

# ────────────────────────────────────────────
# Group 7: Input validation — rejects bad input
# ────────────────────────────────────────────
echo ""
echo "── Group 7: Input validation ──"

# Invalid ID
_assert_fail "reject non-numeric ID" orch_issue_show "abc"
_assert_fail "reject ID with special chars" orch_issue_close "1;rm -rf /"

# Invalid priority
_assert_fail "reject invalid priority P5" orch_issue_create "Test" "P5"
_assert_fail "reject invalid priority HIGH" orch_issue_create "Test" "HIGH"

# Invalid title (shell metacharacters)
_assert_fail "reject title with backtick" orch_issue_create '`whoami`' "P1"
_assert_fail "reject title with dollar-paren" orch_issue_create '$(rm -rf /)' "P1"
_assert_fail "reject title with pipe" orch_issue_create 'foo | bar' "P1"
_assert_fail "reject title with semicolon" orch_issue_create 'foo; rm -rf /' "P1"

# Path traversal
_assert_fail "reject path traversal in title" orch_issue_create '../../etc/passwd' "P1"
_assert_fail "reject path traversal in assignee" orch_issue_create "Safe title" "P1" "../admin"

# Invalid assignee
_assert_fail "reject assignee with spaces" orch_issue_assign 2 "bad agent"
_assert_fail "reject assignee with special chars" orch_issue_assign 2 'agent;rm'

# Invalid labels
_assert_fail "reject labels with spaces" orch_issue_create "Test" "P1" "" "bad label"

# Empty required fields
_assert_fail "reject empty title" orch_issue_create "" "P1"
_assert_fail "reject empty priority" orch_issue_create "Test" ""

# Invalid status filter
_assert_fail "reject invalid status filter" orch_issue_list --status "invalid"

# ────────────────────────────────────────────
# Group 8: Double-source guard
# ────────────────────────────────────────────
echo ""
echo "── Group 8: Double-source guard ──"

_assert "double-source guard variable is set" "1" "$_ORCH_ISSUE_TRACKER_LOADED"

# ────────────────────────────────────────────
# Group 9: Edge cases
# ────────────────────────────────────────────
echo ""
echo "── Group 9: Edge cases ──"

# Show non-existent issue
_assert_fail "show non-existent issue returns error" orch_issue_show 999

# Close non-existent issue
_assert_fail "close non-existent issue returns error" orch_issue_close 999

# Assign non-existent issue
_assert_fail "assign non-existent issue returns error" orch_issue_assign 999 "06-backend"

# Auto-increment after multiple creates
result=$(orch_issue_create "Fourth issue" "P3")
_assert "auto-increment gives ID 4" "4" "$result"

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
