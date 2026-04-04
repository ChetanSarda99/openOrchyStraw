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
# Test 25: BUG-017 — printf with leading-dash format strings
# ══════════════════════════════════════

# orch_review_context should not fail when generating review template
create_review_conf
orch_review_init "$TMPDIR_TEST/agents-review.conf" "$TMPDIR_TEST/output"
context_output=$(orch_review_context "09-qa" "06-backend" "$TMPDIR_TEST" 2>/dev/null || true)
assert "T25: context output contains BLOCKING template" '[[ "$context_output" == *"[BLOCKING]"* ]]'

# ══════════════════════════════════════
# Test 26-27: RP-01 — Verdict validation
# ══════════════════════════════════════

_ORCH_REVIEW_CYCLE=5
if orch_review_record "09-qa" "06-backend" "invalid-verdict" "" 2>/dev/null; then
    echo "FAIL: T26 invalid verdict should be rejected"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# Valid verdicts should still work
orch_review_record "09-qa" "06-backend" "approve" "" 2>/dev/null
assert "T27a: approve accepted" '[[ "${_ORCH_REVIEW_VERDICTS[09-qa|06-backend]}" == "approve" ]]'
orch_review_record "09-qa" "06-backend" "request-changes" "" 2>/dev/null
assert "T27b: request-changes accepted" '[[ "${_ORCH_REVIEW_VERDICTS[09-qa|06-backend]}" == "request-changes" ]]'
orch_review_record "09-qa" "06-backend" "comment" "" 2>/dev/null
assert "T27c: comment accepted" '[[ "${_ORCH_REVIEW_VERDICTS[09-qa|06-backend]}" == "comment" ]]'

# ══════════════════════════════════════
# Test 28: RP-02 — Summary field present
# ══════════════════════════════════════

_ORCH_REVIEW_VERDICTS=()
orch_review_record "09-qa" "06-backend" "approve" ""
summary_with_field=$(orch_review_summary || true)
assert "T28a: summary contains Summary field" '[[ "$summary_with_field" == *"**Summary:**"* ]]'
assert "T28b: all-approve shows ALL CLEAR" '[[ "$summary_with_field" == *"ALL CLEAR"* ]]'

_ORCH_REVIEW_VERDICTS=()
orch_review_record "09-qa" "06-backend" "request-changes" ""
summary_attention=$(orch_review_summary || true)
assert "T28c: request-changes shows NEEDS ATTENTION" '[[ "$summary_attention" == *"NEEDS ATTENTION"* ]]'

_ORCH_REVIEW_VERDICTS=()
summary_empty=$(orch_review_summary || true)
assert "T28d: no reviews shows summary" '[[ "$summary_empty" == *"**Summary:**"* ]]'

# ══════════════════════════════════════
# Test 29-30: RP-04 — Path traversal rejected
# ══════════════════════════════════════

if orch_review_record "../evil" "06-backend" "approve" "" 2>/dev/null; then
    echo "FAIL: T29 path traversal in reviewer should be rejected"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

if orch_review_record "09-qa" "../../etc" "approve" "" 2>/dev/null; then
    echo "FAIL: T30 path traversal in target should be rejected"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# ══════════════════════════════════════
# Test 31: RP-04 — Path traversal rejected in orch_review_context
# ══════════════════════════════════════

if orch_review_context "../evil" "06-backend" "$TMPDIR_TEST" >/dev/null 2>&1; then
    echo "FAIL: T31 path traversal in context reviewer should be rejected"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# ══════════════════════════════════════
# v0.3 Tests: Rubrics, Consensus, Findings
# ══════════════════════════════════════

# Test 37: Rubric template generates output
rubric_out=$(orch_review_rubric "06-backend")
assert "T37a: rubric has dimension table" '[[ "$rubric_out" == *"Dimension"* ]]'
assert "T37b: rubric has correctness" '[[ "$rubric_out" == *"correctness"* ]]'
assert "T37c: rubric has security" '[[ "$rubric_out" == *"security"* ]]'
assert "T37d: rubric has severity examples" '[[ "$rubric_out" == *"CRITICAL"* ]]'

# Test 38: Custom dimensions
orch_review_set_dimensions "logic" "style" "testing"
assert "T38: custom dimensions set" '[[ "${#_ORCH_REVIEW_DIMENSIONS[@]}" -eq 3 ]]'
rubric_custom=$(orch_review_rubric "test")
assert "T38b: custom dimension in rubric" '[[ "$rubric_custom" == *"logic"* ]]'
# Reset to defaults
_ORCH_REVIEW_DIMENSIONS=(correctness security performance readability standards)

# Test 39: Record rubric score
orch_review_record_score "09-qa" "06-backend" "correctness" 4
assert "T39a: score recorded" '[[ "${_ORCH_REVIEW_SCORES[09-qa|06-backend|correctness]}" == "4" ]]'
# Invalid score rejected
if orch_review_record_score "09-qa" "06-backend" "security" 6 2>/dev/null; then
    echo "FAIL: T39b invalid score should be rejected"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# Test 40: Multiple reviewer scores
orch_review_record_score "09-qa" "06-backend" "security" 5
orch_review_record_score "09-qa" "06-backend" "performance" 3
orch_review_record_score "02-cto" "06-backend" "correctness" 3
orch_review_record_score "02-cto" "06-backend" "security" 4
summary_rubric=$(orch_review_rubric_summary "06-backend")
assert "T40: rubric summary has dimensions" '[[ "$summary_rubric" == *"correctness"* ]]'

# Test 41: Consensus — unanimous approve
_ORCH_REVIEW_VERDICTS=()
_ORCH_REVIEW_VERDICTS["09-qa|06-backend"]="approve"
_ORCH_REVIEW_VERDICTS["02-cto|06-backend"]="approve"
consensus=$(orch_review_consensus "06-backend")
assert "T41: unanimous approve" '[[ "$consensus" == "approve" ]]'

# Test 42: Consensus — any request-changes with no approve = request-changes
_ORCH_REVIEW_VERDICTS=()
_ORCH_REVIEW_VERDICTS["09-qa|06-backend"]="request-changes"
_ORCH_REVIEW_VERDICTS["02-cto|06-backend"]="request-changes"
consensus2=$(orch_review_consensus "06-backend")
assert "T42: all request-changes" '[[ "$consensus2" == "request-changes" ]]'

# Test 43: Consensus — mixed
_ORCH_REVIEW_VERDICTS=()
_ORCH_REVIEW_VERDICTS["09-qa|06-backend"]="approve"
_ORCH_REVIEW_VERDICTS["02-cto|06-backend"]="request-changes"
consensus3=$(orch_review_consensus "06-backend")
assert "T43: mixed verdict" '[[ "$consensus3" == "mixed" ]]'

# Test 44: Consensus — no reviews
consensus4=$(orch_review_consensus "ghost-agent")
assert "T44: no reviews" '[[ "$consensus4" == "no-reviews" ]]'

# Test 45: Record individual finding
_ORCH_REVIEW_FINDING_LIST=()
orch_review_record_finding "critical" "09-qa" "06-backend" "SQL injection in user input handler"
orch_review_record_finding "major" "09-qa" "06-backend" "Missing error handling in API call"
orch_review_record_finding "minor" "02-cto" "06-backend" "Variable naming inconsistency"
orch_review_record_finding "suggestion" "02-cto" "06-backend" "Consider adding retry logic"
assert "T45: 4 findings recorded" '[[ "${#_ORCH_REVIEW_FINDING_LIST[@]}" -eq 4 ]]'

# Test 46: Invalid severity rejected
if orch_review_record_finding "blocker" "09-qa" "06-backend" "test" 2>/dev/null; then
    echo "FAIL: T46 invalid severity should be rejected"
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# Test 47: Findings by severity
findings_out=$(orch_review_findings_by_severity "06-backend")
assert "T47a: critical findings shown" '[[ "$findings_out" == *"CRITICAL"* ]]'
assert "T47b: major findings shown" '[[ "$findings_out" == *"MAJOR"* ]]'
assert "T47c: SQL injection in output" '[[ "$findings_out" == *"SQL injection"* ]]'

# Test 48: Finding count
crit_count=$(orch_review_finding_count "critical" "06-backend")
assert "T48a: 1 critical finding" '[[ "$crit_count" == "1" ]]'
total_count=$(orch_review_finding_count "" "06-backend")
assert "T48b: 4 total findings" '[[ "$total_count" == "4" ]]'

# Test 49: Feedback template
_ORCH_REVIEW_CYCLE=5
feedback=$(orch_review_feedback_template "06-backend")
assert "T49a: feedback has consensus" '[[ "$feedback" == *"Consensus"* ]]'
assert "T49b: feedback has findings" '[[ "$feedback" == *"Findings"* ]]'
assert "T49c: feedback has actions" '[[ "$feedback" == *"Required Actions"* ]]'
assert "T49d: feedback mentions critical count" '[[ "$feedback" == *"critical"* ]]'

# ══════════════════════════════════════
# Results
# ══════════════════════════════════════
echo ""
echo "test-review-phase: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
