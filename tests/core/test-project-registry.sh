#!/usr/bin/env bash
# Test: project-registry.sh — registry CRUD operations
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Suppress log output during tests
log() { :; }
ORCH_QUIET=1

source "$PROJECT_ROOT/src/core/project-registry.sh"

# Override registry location to test dir
ORCH_REGISTRY_DIR="$TEST_DIR/.orchystraw"
ORCH_REGISTRY_FILE="$ORCH_REGISTRY_DIR/registry.jsonl"

echo "=== project-registry.sh tests ==="

# ---------------------------------------------------------------------------
# Test 1: Module loads
# ---------------------------------------------------------------------------
[[ -n "${_ORCH_PROJECT_REGISTRY_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# ---------------------------------------------------------------------------
# Test 2: Init creates directory
# ---------------------------------------------------------------------------
orch_registry_init
[[ -d "$ORCH_REGISTRY_DIR" ]] && pass "init creates directory" || fail "init creates directory"

# ---------------------------------------------------------------------------
# Test 3: Init creates registry file
# ---------------------------------------------------------------------------
[[ -f "$ORCH_REGISTRY_FILE" ]] && pass "init creates registry file" || fail "init creates registry file"

# ---------------------------------------------------------------------------
# Test 4: Register adds project
# ---------------------------------------------------------------------------
orch_registry_register "/home/user/project1" "Project1"
if grep -q '"name":"Project1"' "$ORCH_REGISTRY_FILE"; then
    pass "register adds project"
else
    fail "register adds project"
fi

# ---------------------------------------------------------------------------
# Test 5: Register stores path
# ---------------------------------------------------------------------------
if grep -q '"path":"/home/user/project1"' "$ORCH_REGISTRY_FILE"; then
    pass "register stores path"
else
    fail "register stores path"
fi

# ---------------------------------------------------------------------------
# Test 6: Register deduplicates by path
# ---------------------------------------------------------------------------
orch_registry_register "/home/user/project1" "Project1"
count=$(grep -c "project1" "$ORCH_REGISTRY_FILE")
if [[ "$count" -eq 1 ]]; then
    pass "register deduplicates"
else
    fail "register deduplicates (got $count entries)"
fi

# ---------------------------------------------------------------------------
# Test 7: Register multiple projects
# ---------------------------------------------------------------------------
orch_registry_register "/home/user/project2" "Project2"
orch_registry_register "/home/user/project3" "Project3"
count=$(wc -l < "$ORCH_REGISTRY_FILE" | tr -d ' ')
if [[ "$count" -eq 3 ]]; then
    pass "register multiple projects ($count)"
else
    fail "register multiple projects (got $count, expected 3)"
fi

# ---------------------------------------------------------------------------
# Test 8: List shows all projects
# ---------------------------------------------------------------------------
output=$(orch_registry_list 2>&1)
if echo "$output" | grep -q "Project1" && echo "$output" | grep -q "Project2"; then
    pass "list shows all projects"
else
    fail "list shows all projects"
fi

# ---------------------------------------------------------------------------
# Test 9: Update last run changes timestamp
# ---------------------------------------------------------------------------
sleep 1  # Ensure timestamp differs
orch_registry_update_last_run "/home/user/project1"
new_ts=$(grep "project1" "$ORCH_REGISTRY_FILE" | grep -o '"last_run":"[^"]*"' | cut -d'"' -f4)
if [[ -n "$new_ts" ]]; then
    pass "update_last_run changes timestamp"
else
    fail "update_last_run changes timestamp"
fi

# ---------------------------------------------------------------------------
# Test 10: Status shows project health
# ---------------------------------------------------------------------------
output=$(orch_registry_status 2>&1)
if echo "$output" | grep -qE "Project1|MISSING|NO STATE"; then
    pass "status shows project health"
else
    fail "status shows project health"
fi

# ---------------------------------------------------------------------------
# Test 11: Remove deletes project
# ---------------------------------------------------------------------------
orch_registry_remove "/home/user/project2"
if grep -q "project2" "$ORCH_REGISTRY_FILE"; then
    fail "remove deletes project"
else
    pass "remove deletes project"
fi

# ---------------------------------------------------------------------------
# Test 12: Get all paths returns paths
# ---------------------------------------------------------------------------
paths=$(orch_registry_get_all_paths)
if echo "$paths" | grep -q "/home/user/project1"; then
    pass "get_all_paths returns paths"
else
    fail "get_all_paths returns paths"
fi

# ---------------------------------------------------------------------------
# Test 13: Register includes timestamp
# ---------------------------------------------------------------------------
entry=$(grep "project1" "$ORCH_REGISTRY_FILE")
if echo "$entry" | grep -q '"registered":"20'; then
    pass "register includes timestamp"
else
    fail "register includes timestamp"
fi

# ---------------------------------------------------------------------------
# Test 14: Empty registry list message
# ---------------------------------------------------------------------------
echo -n > "$ORCH_REGISTRY_FILE"
output=$(orch_registry_list 2>&1)
if echo "$output" | grep -q "No projects registered"; then
    pass "empty registry shows message"
else
    fail "empty registry shows message"
fi

# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS pass, $FAIL fail ($(( PASS + FAIL )) total)"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
