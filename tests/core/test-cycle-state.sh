#!/usr/bin/env bash
# Test: cycle-state.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Override the state directory to use temp dir
cd "$TEST_DIR"
source "$PROJECT_ROOT/src/core/cycle-state.sh"

# Test 1: init creates directory
orch_state_init
[[ -d ".orchystraw" ]] || { echo ".orchystraw dir not created"; exit 1; }

# Test 2: save writes state file
orch_state_save 5 completed
[[ -f ".orchystraw/cycle-state" ]] || { echo "state file not created"; exit 1; }

# Test 3: load reads state
orch_state_load
[[ "$ORCH_LAST_CYCLE" == "5" ]] || { echo "cycle not loaded: got '$ORCH_LAST_CYCLE'"; exit 1; }
[[ "$ORCH_LAST_STATUS" == "completed" ]] || { echo "status not loaded: got '$ORCH_LAST_STATUS'"; exit 1; }

# Test 4: resume after completed → next cycle
resume=$(orch_state_resume)
[[ "$resume" == "6" ]] || { echo "resume after completed should be 6, got '$resume'"; exit 1; }

# Test 5: resume after failed → same cycle
orch_state_save 5 failed
resume=$(orch_state_resume)
[[ "$resume" == "5" ]] || { echo "resume after failed should be 5, got '$resume'"; exit 1; }

# Test 6: clear removes state
orch_state_clear
[[ ! -f ".orchystraw/cycle-state" ]] || { echo "state file not cleared"; exit 1; }

# Test 7: resume with no state → 1
resume=$(orch_state_resume)
[[ "$resume" == "1" ]] || { echo "resume with no state should be 1, got '$resume'"; exit 1; }

echo "cycle-state: all tests passed"
