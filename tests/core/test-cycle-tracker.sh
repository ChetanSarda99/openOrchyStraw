#!/usr/bin/env bash
# Test: cycle-tracker.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/cycle-tracker.sh"

# Test 1: Init
orch_tracker_init 1
[[ "$_ORCH_TRACKER_CYCLE" == "1" ]] || { echo "FAIL: cycle not set"; exit 1; }
[[ "$_ORCH_TRACKER_COMMITS" == "0" ]] || { echo "FAIL: commits not zero"; exit 1; }

# Test 2: Empty when no agents ran
orch_tracker_is_empty || { echo "FAIL: should be empty with no agents"; exit 1; }

# Test 3: Record success
orch_tracker_record "06-backend" "success"
[[ "$_ORCH_TRACKER_AGENTS_RUN" == "1" ]] || { echo "FAIL: agents_run not 1"; exit 1; }
[[ "$_ORCH_TRACKER_AGENTS_OK" == "1" ]] || { echo "FAIL: agents_ok not 1"; exit 1; }

# Test 4: Productive after success (even without commits)
orch_tracker_is_productive || { echo "FAIL: should be productive after success"; exit 1; }

# Test 5: Not empty after success
! orch_tracker_is_empty || { echo "FAIL: should not be empty after success"; exit 1; }

# Test 6: Record failure
orch_tracker_record "09-qa" "fail"
[[ "$_ORCH_TRACKER_AGENTS_FAIL" == "1" ]] || { echo "FAIL: fail not counted"; exit 1; }
[[ "$_ORCH_TRACKER_AGENTS_RUN" == "2" ]] || { echo "FAIL: total run not 2"; exit 1; }

# Test 7: Skip doesn't count as run
orch_tracker_record "01-ceo" "skip"
[[ "$_ORCH_TRACKER_AGENTS_RUN" == "2" ]] || { echo "FAIL: skip should not count as run"; exit 1; }

# Test 8: Set commits
orch_tracker_set_commits 3
[[ "$_ORCH_TRACKER_COMMITS" == "3" ]] || { echo "FAIL: commits not set"; exit 1; }

# Test 9: Summary format
summary=$(orch_tracker_summary)
[[ "$summary" == *"PRODUCTIVE"* ]] || { echo "FAIL: summary missing PRODUCTIVE"; exit 1; }
[[ "$summary" == *"Cycle 1"* ]] || { echo "FAIL: summary missing cycle number"; exit 1; }

# Test 10: All-fail cycle IS empty
orch_tracker_init 2
orch_tracker_record "06-backend" "fail"
orch_tracker_record "09-qa" "timeout"
orch_tracker_is_empty || { echo "FAIL: all-fail cycle should be empty"; exit 1; }
! orch_tracker_is_productive || { echo "FAIL: all-fail should not be productive"; exit 1; }

# Test 11: Empty streak tracking
orch_tracker_update_streak
[[ "$(orch_tracker_empty_streak)" == "1" ]] || { echo "FAIL: streak not 1"; exit 1; }
orch_tracker_update_streak
[[ "$(orch_tracker_empty_streak)" == "2" ]] || { echo "FAIL: streak not 2"; exit 1; }

# Test 12: Should stop after threshold
! orch_tracker_should_stop 3 || { echo "FAIL: should not stop at 2"; exit 1; }
orch_tracker_update_streak
orch_tracker_should_stop 3 || { echo "FAIL: should stop at 3"; exit 1; }

# Test 13: Productive cycle resets streak
orch_tracker_init 3
orch_tracker_record "06-backend" "success"
orch_tracker_update_streak
[[ "$(orch_tracker_empty_streak)" == "0" ]] || { echo "FAIL: streak not reset"; exit 1; }

# Test 14: Commits alone make cycle productive
orch_tracker_init 4
orch_tracker_record "06-backend" "fail"
orch_tracker_set_commits 1
orch_tracker_is_productive || { echo "FAIL: should be productive with commits"; exit 1; }
! orch_tracker_is_empty || { echo "FAIL: should not be empty with commits"; exit 1; }

echo "test-cycle-tracker.sh: ALL PASS (14 tests)"
