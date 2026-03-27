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

echo "lock-file: all tests passed"
