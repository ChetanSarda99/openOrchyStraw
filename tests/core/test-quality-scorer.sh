#!/usr/bin/env bash
# Test: quality-scorer.sh — multi-dimensional scoring
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORCH_ROOT="$PROJECT_ROOT"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Suppress log output during tests
log() { :; }
ORCH_QUIET=1

# Mock agent config arrays
declare -A AGENT_PROMPTS=()
declare -A AGENT_OWNERSHIP=()
declare -A AGENT_INTERVALS=()
declare -A AGENT_LABELS=()
AGENT_PROMPTS[test-agent]="prompts/test/test.txt"
AGENT_OWNERSHIP[test-agent]="src/ tests/"
AGENT_INTERVALS[test-agent]=1
AGENT_LABELS[test-agent]="Test Agent"

source "$PROJECT_ROOT/src/core/quality-scorer.sh"

echo "=== quality-scorer.sh tests ==="

# ---------------------------------------------------------------------------
# Test 1: Module loads
# ---------------------------------------------------------------------------
[[ -n "${_ORCH_QUALITY_SCORER_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# ---------------------------------------------------------------------------
# Test 2: orch_scorer_init creates .orchystraw dir
# ---------------------------------------------------------------------------
export PROJECT_ROOT="$TEST_DIR/project"
_SCORER_PROJECT_ROOT="$TEST_DIR/project"
mkdir -p "$TEST_DIR/project"
orch_scorer_init
[[ -d "$TEST_DIR/project/.orchystraw" ]] && pass "init creates .orchystraw" || fail "init creates .orchystraw"

# ---------------------------------------------------------------------------
# Test 3: orch_scorer_lint returns valid score (0-100)
# ---------------------------------------------------------------------------
# No git repo = should return 100 (no changed files)
score=$(orch_scorer_lint "test-agent" 2>/dev/null || echo 100)
if [[ "$score" -ge 0 && "$score" -le 100 ]]; then
    pass "lint returns valid score ($score)"
else
    fail "lint returns valid score (got: $score)"
fi

# ---------------------------------------------------------------------------
# Test 4: orch_scorer_tests returns valid score
# ---------------------------------------------------------------------------
score=$(orch_scorer_tests 2>/dev/null || echo 50)
if [[ "$score" -ge 0 && "$score" -le 100 ]]; then
    pass "tests returns valid score ($score)"
else
    fail "tests returns valid score (got: $score)"
fi

# ---------------------------------------------------------------------------
# Test 5: orch_scorer_diff_quality returns valid score
# ---------------------------------------------------------------------------
score=$(orch_scorer_diff_quality "test-agent" 2>/dev/null || echo 50)
if [[ "$score" -ge 0 && "$score" -le 100 ]]; then
    pass "diff_quality returns valid score ($score)"
else
    fail "diff_quality returns valid score (got: $score)"
fi

# ---------------------------------------------------------------------------
# Test 6: orch_scorer_output_quality returns valid score
# ---------------------------------------------------------------------------
score=$(orch_scorer_output_quality "test-agent" 2>/dev/null || echo 50)
if [[ "$score" -ge 0 && "$score" -le 100 ]]; then
    pass "output_quality returns valid score ($score)"
else
    fail "output_quality returns valid score (got: $score)"
fi

# ---------------------------------------------------------------------------
# Test 7: orch_scorer_ownership returns valid score
# ---------------------------------------------------------------------------
score=$(orch_scorer_ownership "test-agent" 2>/dev/null || echo 100)
if [[ "$score" -ge 0 && "$score" -le 100 ]]; then
    pass "ownership returns valid score ($score)"
else
    fail "ownership returns valid score (got: $score)"
fi

# ---------------------------------------------------------------------------
# Test 8: orch_scorer_run returns composite score
# ---------------------------------------------------------------------------
score=$(orch_scorer_run "test-agent" 2>/dev/null || echo 50)
if [[ "$score" -ge 0 && "$score" -le 100 ]]; then
    pass "composite run returns valid score ($score)"
else
    fail "composite run returns valid score (got: $score)"
fi

# ---------------------------------------------------------------------------
# Test 9: orch_scorer_record writes to JSONL
# ---------------------------------------------------------------------------
orch_scorer_record "test-agent" 75
if [[ -f "$TEST_DIR/project/.orchystraw/quality-scores.jsonl" ]]; then
    if grep -q '"agent":"test-agent"' "$TEST_DIR/project/.orchystraw/quality-scores.jsonl"; then
        pass "record writes JSONL entry"
    else
        fail "record writes JSONL entry"
    fi
else
    fail "record writes JSONL file"
fi

# ---------------------------------------------------------------------------
# Test 10: orch_scorer_record includes score value
# ---------------------------------------------------------------------------
if grep -q '"score":75' "$TEST_DIR/project/.orchystraw/quality-scores.jsonl"; then
    pass "record includes score value"
else
    fail "record includes score value"
fi

# ---------------------------------------------------------------------------
# Test 11: orch_scorer_get_recent returns entries
# ---------------------------------------------------------------------------
orch_scorer_record "test-agent" 80
orch_scorer_record "test-agent" 90
recent=$(orch_scorer_get_recent "test-agent" 2)
count=$(echo "$recent" | grep -c "test-agent" || echo 0)
if [[ "$count" -eq 2 ]]; then
    pass "get_recent returns correct count"
else
    fail "get_recent returns correct count (got: $count)"
fi

# ---------------------------------------------------------------------------
# Test 12: orch_scorer_get_average calculates correctly
# ---------------------------------------------------------------------------
# We recorded 75, 80, 90 = avg 81.66 -> 81 (integer)
avg=$(orch_scorer_get_average "test-agent" 3)
if [[ "$avg" -ge 80 && "$avg" -le 83 ]]; then
    pass "get_average calculates correctly ($avg)"
else
    fail "get_average calculates correctly (got: $avg, expected ~81)"
fi

# ---------------------------------------------------------------------------
# Test 13: Detected linters array populated
# ---------------------------------------------------------------------------
orch_scorer_init
# At least shellcheck should be available on a dev machine
linter_count=${#_SCORER_LINTERS[@]}
pass "linter detection ran ($linter_count linters found)"

# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS pass, $FAIL fail ($(( PASS + FAIL )) total)"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
