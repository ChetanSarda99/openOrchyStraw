#!/usr/bin/env bash
# Test: memory.sh — agent memory persistence
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/memory.sh"

echo "=== memory.sh tests ==="

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

# Test 1: Module loads
[[ -n "${_ORCH_MEM_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Init creates directories and files
orch_mem_init "$TEST_DIR/project"
[[ -d "$TEST_DIR/project/.orchystraw/memory" ]] && pass "init: dir created" || fail "init: dir created"
[[ -f "$TEST_DIR/project/.orchystraw/memory/episodic.mem" ]] && pass "init: episodic.mem created" || fail "init: episodic.mem"
[[ -f "$TEST_DIR/project/.orchystraw/memory/semantic.mem" ]] && pass "init: semantic.mem created" || fail "init: semantic.mem"
[[ -f "$TEST_DIR/project/.orchystraw/memory/procedural.mem" ]] && pass "init: procedural.mem created" || fail "init: procedural.mem"

# ---------------------------------------------------------------------------
# Store
# ---------------------------------------------------------------------------

# Test 3: Store episodic memory
orch_mem_store "06-backend" "episodic" "Fixed timeout bug in cycle 5"
count=$(orch_mem_count "06-backend" "episodic")
[[ "$count" -eq 1 ]] && pass "store: episodic count=1" || fail "store: episodic count=1 (got $count)"

# Test 4: Store semantic memory
orch_mem_store "06-backend" "semantic" "Bash 5.0+ required for arrays"
count=$(orch_mem_count "06-backend" "semantic")
[[ "$count" -eq 1 ]] && pass "store: semantic count=1" || fail "store: semantic count=1 (got $count)"

# Test 5: Store procedural memory
orch_mem_store "06-backend" "procedural" "Run tests before committing"
count=$(orch_mem_count "06-backend" "procedural")
[[ "$count" -eq 1 ]] && pass "store: procedural count=1" || fail "store: procedural count=1 (got $count)"

# Test 6: Invalid type fails
if ! orch_mem_store "06-backend" "invalid" "content" 2>/dev/null; then
    pass "store: invalid type fails"
else
    fail "store: invalid type fails"
fi

# Test 7: Store without init fails
_ORCH_MEM_INITED=false
if ! orch_mem_store "06-backend" "episodic" "test" 2>/dev/null; then
    pass "store: without init fails"
else
    fail "store: without init fails"
fi
_ORCH_MEM_INITED=true

# Test 8: Multiple stores accumulate
orch_mem_store "06-backend" "episodic" "Second event"
orch_mem_store "06-backend" "episodic" "Third event"
count=$(orch_mem_count "06-backend" "episodic")
[[ "$count" -eq 3 ]] && pass "store: accumulates (3)" || fail "store: accumulates (got $count)"

# ---------------------------------------------------------------------------
# Recall
# ---------------------------------------------------------------------------

# Test 9: Recall by keyword
results=$(orch_mem_recall "06-backend" "timeout")
echo "$results" | grep -q "timeout" && pass "recall: keyword match" || fail "recall: keyword match"

# Test 10: Recall returns only matching agent
orch_mem_store "11-web" "episodic" "Updated CSS styles"
results=$(orch_mem_recall "06-backend" "CSS")
if [[ -z "$results" ]]; then
    pass "recall: agent isolation"
else
    fail "recall: agent isolation (found cross-agent result)"
fi

# Test 11: Recall recent
results=$(orch_mem_recall_recent "06-backend" 2)
count=$(echo "$results" | grep -c "." || true)
[[ $count -le 2 ]] && pass "recall_recent: limit=2" || fail "recall_recent: limit=2 (got $count)"

# Test 12: Recall by type
results=$(orch_mem_recall_type "06-backend" "procedural")
echo "$results" | grep -q "tests before committing" && pass "recall_type: procedural" || fail "recall_type: procedural"

# Test 13: Recall no results
results=$(orch_mem_recall "06-backend" "xyznonexistent123")
[[ -z "$results" ]] && pass "recall: no results for gibberish" || fail "recall: no results for gibberish"

# ---------------------------------------------------------------------------
# Count
# ---------------------------------------------------------------------------

# Test 14: Total count across types
total=$(orch_mem_count "06-backend")
[[ "$total" -ge 4 ]] && pass "count: total >= 4 ($total)" || fail "count: total >= 4 (got $total)"

# Test 15: Count for empty agent
count=$(orch_mem_count "nonexistent-agent")
[[ "$count" -eq 0 ]] && pass "count: empty agent = 0" || fail "count: empty agent (got $count)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

# Test 16: Summary output
summary=$(orch_mem_summary "06-backend")
echo "$summary" | grep -q "Episodic" && pass "summary: has episodic" || fail "summary: has episodic"
echo "$summary" | grep -q "Semantic" && pass "summary: has semantic" || fail "summary: has semantic"
echo "$summary" | grep -q "Procedural" && pass "summary: has procedural" || fail "summary: has procedural"
echo "$summary" | grep -q "Total" && pass "summary: has total" || fail "summary: has total"

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

# Test 17: Export produces markdown
export_output=$(orch_mem_export)
echo "$export_output" | grep -q "Memory Export" && pass "export: has header" || fail "export: has header"
echo "$export_output" | grep -q "06-backend" && pass "export: has agent" || fail "export: has agent"

# ---------------------------------------------------------------------------
# Clear
# ---------------------------------------------------------------------------

# Test 18: Clear specific agent
before=$(orch_mem_count "06-backend")
orch_mem_clear "06-backend"
after=$(orch_mem_count "06-backend")
[[ "$after" -eq 0 ]] && pass "clear: agent memories removed (was $before)" || fail "clear: agent memories removed (got $after)"

# Test 19: Clear doesn't affect other agents
web_count=$(orch_mem_count "11-web")
[[ "$web_count" -ge 1 ]] && pass "clear: other agents unaffected" || fail "clear: other agents unaffected"

# Test 20: Clear all
orch_mem_clear "all"
web_count=$(orch_mem_count "11-web")
[[ "$web_count" -eq 0 ]] && pass "clear all: everything removed" || fail "clear all: everything removed"

# ---------------------------------------------------------------------------
# Garbage collection
# ---------------------------------------------------------------------------

# Test 21: GC prunes old records
# Store a record with a very old timestamp manually
echo "1000000000|2001-09-09T00:00:00|06-backend|episodic|ancient memory" >> "$TEST_DIR/project/.orchystraw/memory/episodic.mem"
orch_mem_store "06-backend" "episodic" "recent memory"

before=$(orch_mem_count "06-backend" "episodic")
pruned=$(orch_mem_gc 30)
after=$(orch_mem_count "06-backend" "episodic")

[[ "$pruned" -ge 1 ]] && pass "gc: pruned old records ($pruned)" || fail "gc: pruned old records"
[[ "$after" -lt "$before" ]] && pass "gc: count decreased ($before -> $after)" || fail "gc: count decreased"

# Test 22: GC without init fails
_ORCH_MEM_INITED=false
if ! orch_mem_gc 30 2>/dev/null; then
    pass "gc: without init fails"
else
    fail "gc: without init fails"
fi

echo ""
echo "memory: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
