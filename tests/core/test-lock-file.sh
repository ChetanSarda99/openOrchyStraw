#!/usr/bin/env bash
# Test: lock-file.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR"
source "$PROJECT_ROOT/src/core/lock-file.sh"

# Test 1: acquire succeeds
orch_lock_acquire || { echo "first acquire should succeed"; exit 1; }

# Test 2: lock file exists with our PID
[[ -f ".orchystraw/orchestrator.lock" ]] || { echo "lock file not created"; exit 1; }
grep -q "pid=$$" ".orchystraw/orchestrator.lock" || { echo "lock doesn't contain our PID"; exit 1; }

# Test 3: check returns 0 for our PID
orch_lock_check || { echo "lock_check should return 0 for our PID"; exit 1; }

# Test 4: info prints lock details
info=$(orch_lock_info)
echo "$info" | grep -q "$$" || { echo "info should show our PID"; exit 1; }

# Test 5: release removes lock
orch_lock_release
[[ ! -f ".orchystraw/orchestrator.lock" ]] || { echo "lock not released"; exit 1; }

# Test 6: stale lock detection (write a dead PID)
mkdir -p ".orchystraw"
printf 'pid=99999\ntimestamp=2026-01-01 00:00:00\n' > ".orchystraw/orchestrator.lock"
# 99999 is unlikely to be running; acquire should succeed after stale detection
orch_lock_acquire 2>/dev/null || { echo "stale lock should be replaced"; exit 1; }
orch_lock_release

# --- New tests for upgraded features ---

# Test 7: acquire with timeout — immediate acquire
orch_lock_acquire_timeout 2 || { echo "acquire_timeout should succeed immediately"; exit 1; }
orch_lock_release

# Test 8: named lock acquire and release
orch_lock_acquire_named "test-resource" || { echo "named lock acquire should succeed"; exit 1; }
[[ -f ".orchystraw/locks/test-resource.lock" ]] || { echo "named lock file not created"; exit 1; }
orch_lock_release_named "test-resource"
[[ ! -f ".orchystraw/locks/test-resource.lock" ]] || { echo "named lock not released"; exit 1; }

# Test 9: named lock — stale detection
mkdir -p ".orchystraw/locks"
printf 'pid=99999\ntimestamp=2026-01-01 00:00:00\nholder=test\n' > ".orchystraw/locks/stale-lock.lock"
orch_lock_acquire_named "stale-lock" || { echo "stale named lock should be replaced"; exit 1; }
orch_lock_release_named "stale-lock"

# Test 10: multiple named locks
orch_lock_acquire_named "lock-a" || { echo "lock-a acquire should succeed"; exit 1; }
orch_lock_acquire_named "lock-b" || { echo "lock-b acquire should succeed"; exit 1; }
[[ -f ".orchystraw/locks/lock-a.lock" ]] || { echo "lock-a file missing"; exit 1; }
[[ -f ".orchystraw/locks/lock-b.lock" ]] || { echo "lock-b file missing"; exit 1; }
orch_lock_release_named "lock-a"
orch_lock_release_named "lock-b"

# Test 11: lock list — empty
output=$(orch_lock_list)
echo "$output" | grep -q "No locks" || { echo "list should show no locks"; exit 1; }

# Test 12: lock list — with locks
orch_lock_acquire 2>/dev/null || true
orch_lock_acquire_named "list-test" || true
output=$(orch_lock_list)
echo "$output" | grep -q "orchestrator" || { echo "list should show orchestrator lock"; exit 1; }
echo "$output" | grep -q "list-test" || { echo "list should show named lock"; exit 1; }
orch_lock_release_named "list-test"
orch_lock_release

# Test 13: deadlock detection — no deadlock
result=0
orch_lock_detect_deadlock 2>/dev/null || result=$?
[[ "$result" -eq 0 ]] || { echo "no deadlock should return 0"; exit 1; }

# Test 14: deadlock detection — stale lock detected
mkdir -p ".orchystraw/locks"
printf 'pid=99999\ntimestamp=2026-01-01 00:00:00\nholder=dead\n' > ".orchystraw/locks/dead-lock.lock"
result=0
orch_lock_detect_deadlock 2>/dev/null || result=$?
[[ "$result" -eq 1 ]] || { echo "stale lock should be detected as potential deadlock"; exit 1; }
rm -f ".orchystraw/locks/dead-lock.lock"

# Test 15: lock info shows status
orch_lock_acquire 2>/dev/null || true
info=$(orch_lock_info)
echo "$info" | grep -q "ACTIVE" || { echo "info should show ACTIVE status"; exit 1; }
orch_lock_release

# Test 16: named lock name sanitization
orch_lock_acquire_named "test/resource:special" || { echo "special chars in name should work"; exit 1; }
[[ -f ".orchystraw/locks/test_resource_special.lock" ]] || { echo "sanitized lock file should exist"; exit 1; }
orch_lock_release_named "test/resource:special"

echo "lock-file: all tests passed"
