#!/usr/bin/env bash
# Test: review-phase.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/review-phase.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PASS=0
FAIL=0

assert() {
    local test_name="$1" condition="$2"
    if eval "$condition"; then
        (( PASS++ )) || true
    else
        echo "FAIL: $test_name"
        (( FAIL++ )) || true
    fi
}

# ── Helper: create a v2 agents.conf with review config ──
create_review_conf() {
    cat > "$TMPDIR_TEST/agents-review.conf" << 'EOF'
# v2 format with reviews (col 8)
06-backend   | prompts/06-backend/06-backend.txt | src/core/       | 1 | Backend | 10 | none | none
08-pixel     | prompts/08-pixel/08-pixel.txt     | src/pixel/      | 2 | Pixel   | 6  | none | none
09-qa        | prompts/09-qa/09-qa.txt           | tests/          | 3 | QA      | 5  | 06-backend | 06-backend,08-pixel
02-cto       | prompts/02-cto/02-cto.txt         | docs/           | 2 | CTO     | 7  | none | 06-backend
03-pm        | prompts/03-pm/03-pm.txt           | prompts/        | 0 | PM      | 0  | all | none
EOF
}

# ── Helper: create a v1 conf (no reviews column) ──
create_no_review_conf() {
    cat > "$TMPDIR_TEST/agents-v1.conf" << 'EOF'
03-pm        | prompts/03-pm/03-pm.txt       | prompts/ docs/     | 0 | PM Coordinator
06-backend   | prompts/06-backend/06-backend.txt | src/core/       | 1 | Backend
09-qa        | prompts/09-qa/09-qa.txt       | tests/             | 3 | QA
EOF
}

# ══════════════════════════════════════
# Test 1: Init with review config
# ══════════════════════════════════════
create_review_conf
orch_review_init "$TMPDIR_TEST/agents-review.conf" "$TMPDIR_TEST/output"
assert "T1: initialized" '[[ "$_ORCH_REVIEW_INITIALIZED" == "true" ]]'

# Test 2: Correct number of reviewers parsed
reviewer_count="${#_ORCH_REVIEW_MAP[@]}"
assert "T2: 2 reviewers" '[[ "$reviewer_count" -eq 2 ]]'

# Test 3: QA reviews backend and pixel
assert "T3: QA reviews targets" '[[ "${_ORCH_REVIEW_MAP[09-qa]}" == "06-backend,08-pixel" ]]'

# Test 4: CTO reviews backend
assert "T4: CTO reviews backend" '[[ "${_ORCH_REVIEW_MAP[02-cto]}" == "06-backend" ]]'

# Test 5: Init with missing file fails
if orch_review_init "$TMPDIR_TEST/nonexistent.conf" "$TMPDIR_TEST/output" 2>/dev/null; then
    echo "FAIL: T5 should fail on missing file"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# Test 6: v1 config has no reviewers
create_no_review_conf
orch_review_init "$TMPDIR_TEST/agents-v1.conf" "$TMPDIR_TEST/output"
assert "T6: v1 has 0 reviewers" '[[ "${#_ORCH_REVIEW_MAP[@]}" -eq 0 ]]'

# ══════════════════════════════════════
# Test 7-9: Review plan
# ══════════════════════════════════════
create_review_conf
orch_review_init "$TMPDIR_TEST/agents-review.conf" "$TMPDIR_TEST/output"

# Only backend committed
orch_review_plan 5 "06-backend"
plan_count="${#_ORCH_REVIEW_PLAN[@]}"
assert "T7: 2 reviews when backend committed" '[[ "$plan_count" -eq 2 ]]'

# Both backend and pixel committed
orch_review_plan 5 "06-backend" "08-pixel"
plan_count="${#_ORCH_REVIEW_PLAN[@]}"
assert "T8: 3 reviews when backend+pixel committed" '[[ "$plan_count" -eq 3 ]]'

# No agents committed
orch_review_plan 5
plan_count="${#_ORCH_REVIEW_PLAN[@]}"
assert "T9: 0 reviews when nobody committed" '[[ "$plan_count" -eq 0 ]]'

# ══════════════════════════════════════
# Test 10-11: Review plan with non-reviewed agents
# ══════════════════════════════════════

# Only PM committed (nobody reviews PM)
orch_review_plan 5 "03-pm"
assert "T10: 0 reviews for non-reviewed agent" '[[ "${#_ORCH_REVIEW_PLAN[@]}" -eq 0 ]]'

# Only pixel committed (QA reviews pixel, CTO does not)
orch_review_plan 5 "08-pixel"
assert "T11: 1 review when only pixel committed" '[[ "${#_ORCH_REVIEW_PLAN[@]}" -eq 1 ]]'

# ══════════════════════════════════════
# Test 12-14: Record and summary
# ══════════════════════════════════════

_ORCH_REVIEW_CYCLE=5
orch_review_record "09-qa" "06-backend" "approve" "- [NOTE] Code looks good"
orch_review_record "02-cto" "06-backend" "request-changes" "- [BLOCKING] Missing error handling"
orch_review_record "09-qa" "08-pixel" "comment" "- [SUGGESTION] Add docstring"

assert "T12: 3 verdicts recorded" '[[ "${#_ORCH_REVIEW_VERDICTS[@]}" -eq 3 ]]'

# Check review file was written
assert "T13: review file exists" '[[ -f "$TMPDIR_TEST/output/09-qa/reviews/cycle-5-06-backend.md" ]]'
assert "T14: CTO review file exists" '[[ -f "$TMPDIR_TEST/output/02-cto/reviews/cycle-5-06-backend.md" ]]'

# ══════════════════════════════════════
# Test 15-16: Summary output
# ══════════════════════════════════════

summary_output=$(orch_review_summary || true)
assert "T15: summary contains changes requested" '[[ "$summary_output" == *"Changes requested:"*"1"* ]]'

# Summary returns 1 when changes requested
if orch_review_summary > /dev/null 2>&1; then
    echo "FAIL: T16 should return 1 with request-changes"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# ══════════════════════════════════════
# Test 17-18: All approvals → return 0
# ══════════════════════════════════════

_ORCH_REVIEW_VERDICTS=()
_ORCH_REVIEW_FINDINGS=()
orch_review_record "09-qa" "06-backend" "approve" ""
orch_review_record "02-cto" "06-backend" "approve" ""

if orch_review_summary > /dev/null; then
    (( PASS++ )) || true
else
    echo "FAIL: T17 all-approve should return 0"
    (( FAIL++ )) || true
fi

# Empty verdicts → return 0
_ORCH_REVIEW_VERDICTS=()
if orch_review_summary > /dev/null; then
    (( PASS++ )) || true
else
    echo "FAIL: T18 no verdicts should return 0"
    (( FAIL++ )) || true
fi

# ══════════════════════════════════════
# Test 19-20: Cost guard
# ══════════════════════════════════════

if orch_review_should_run 30; then
    (( PASS++ )) || true
else
    echo "FAIL: T19 should run at 30%"
    (( FAIL++ )) || true
fi

if orch_review_should_run 50 2>/dev/null; then
    echo "FAIL: T20 should skip at 50%"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# ══════════════════════════════════════
# Test 21: Cost guard boundary — 49% runs
# ══════════════════════════════════════

if orch_review_should_run 49; then
    (( PASS++ )) || true
else
    echo "FAIL: T21 should run at 49%"
    (( FAIL++ )) || true
fi

# ══════════════════════════════════════
# Test 22: Review file content check
# ══════════════════════════════════════

review_content=$(cat "$TMPDIR_TEST/output/09-qa/reviews/cycle-5-06-backend.md")
assert "T22: review file has verdict" '[[ "$review_content" == *"approve"* ]]'

# ══════════════════════════════════════
# Test 23: get_plan output
# ══════════════════════════════════════

create_review_conf
orch_review_init "$TMPDIR_TEST/agents-review.conf" "$TMPDIR_TEST/output"
orch_review_plan 5 "06-backend"
plan_output=$(orch_review_get_plan)
assert "T23: plan output contains reviewer:target pairs" '[[ "$plan_output" == *":"* ]]'

# ══════════════════════════════════════
# Test 24: get_reviewers output
# ══════════════════════════════════════

reviewers_output=$(orch_review_get_reviewers)
assert "T24: reviewers includes 09-qa" '[[ "$reviewers_output" == *"09-qa"* ]]'

# ══════════════════════════════════════
# Results
# ══════════════════════════════════════
echo ""
echo "test-review-phase: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
