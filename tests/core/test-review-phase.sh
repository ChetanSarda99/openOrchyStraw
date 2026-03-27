#!/usr/bin/env bash
# Test: review-phase.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/review-phase.sh"

echo "=== review-phase.sh tests ==="

# --- Setup: temp project structure ---
TEST_ROOT="$TMPDIR_TEST/test-project"
mkdir -p "$TEST_ROOT/prompts/09-qa/reviews"
mkdir -p "$TEST_ROOT/prompts/02-cto/reviews"
mkdir -p "$TEST_ROOT/prompts/06-backend"
echo "You are the backend developer." > "$TEST_ROOT/prompts/06-backend/06-backend.txt"

# Init a git repo for diff tests
git -C "$TEST_ROOT" init 2>/dev/null || { mkdir -p "$TEST_ROOT" && cd "$TEST_ROOT" && git init; }
git -C "$TEST_ROOT" config user.email "test@test.com"
git -C "$TEST_ROOT" config user.name "Test"
git -C "$TEST_ROOT" commit --allow-empty -m "Initial commit"

# -----------------------------------------------------------------------
# 1. Module loads (guard var set)
# -----------------------------------------------------------------------
if [[ "${_ORCH_REVIEW_PHASE_LOADED:-}" == "1" ]]; then
    pass "1 - module loads (guard var set)"
else
    fail "1 - module loads (guard var set)"
fi

# -----------------------------------------------------------------------
# 2. Double-source guard
# -----------------------------------------------------------------------
# Sourcing again should be a no-op (the guard returns 0 immediately)
if source "$PROJECT_ROOT/src/core/review-phase.sh"; then
    pass "2 - double-source guard"
else
    fail "2 - double-source guard"
fi

# -----------------------------------------------------------------------
# 3. Init sets cycle and root
# -----------------------------------------------------------------------
orch_review_init 5 "$TEST_ROOT"
if [[ "$_ORCH_REVIEW_CYCLE" == "5" && "$_ORCH_REVIEW_ROOT" == "$TEST_ROOT" ]]; then
    pass "3 - init sets cycle and root"
else
    fail "3 - init sets cycle and root (cycle=$_ORCH_REVIEW_CYCLE root=$_ORCH_REVIEW_ROOT)"
fi

# -----------------------------------------------------------------------
# 4. Assign reviews
# -----------------------------------------------------------------------
orch_review_assign "09-qa" "06-backend,08-pixel"
if [[ "${_ORCH_REVIEW_ASSIGNMENTS[09-qa]:-}" == "06-backend,08-pixel" ]]; then
    pass "4 - assign reviews"
else
    fail "4 - assign reviews (got: ${_ORCH_REVIEW_ASSIGNMENTS[09-qa]:-EMPTY})"
fi

# -----------------------------------------------------------------------
# 5. Get assignments
# -----------------------------------------------------------------------
result=$(orch_review_get_assignments "09-qa")
if [[ "$result" == "06-backend,08-pixel" ]]; then
    pass "5 - get assignments"
else
    fail "5 - get assignments (got: $result)"
fi

# -----------------------------------------------------------------------
# 6. Get reviewers for target
# -----------------------------------------------------------------------
result=$(orch_review_get_reviewers "06-backend")
if [[ "$result" == *"09-qa"* ]]; then
    pass "6 - get reviewers for target"
else
    fail "6 - get reviewers for target (got: $result)"
fi

# -----------------------------------------------------------------------
# 7. Multiple reviewers
# -----------------------------------------------------------------------
orch_review_assign "02-cto" "06-backend,04-tauri-rust"
result=$(orch_review_get_reviewers "06-backend")
if [[ "$result" == *"09-qa"* && "$result" == *"02-cto"* ]]; then
    pass "7 - multiple reviewers"
else
    fail "7 - multiple reviewers (got: $result)"
fi

# -----------------------------------------------------------------------
# 8. Build prompt contains diff
# -----------------------------------------------------------------------
fake_diff="diff --git a/foo.sh b/foo.sh
--- a/foo.sh
+++ b/foo.sh
@@ -1 +1 @@
-old line
+new line"

prompt_output=$(orch_review_build_prompt "09-qa" "06-backend" "$fake_diff" "$TEST_ROOT/prompts/06-backend/06-backend.txt")
if [[ "$prompt_output" == *"old line"* && "$prompt_output" == *"new line"* ]]; then
    pass "8 - build prompt contains diff"
else
    fail "8 - build prompt contains diff"
fi

# -----------------------------------------------------------------------
# 9. Build prompt contains template (verdict keywords)
# -----------------------------------------------------------------------
if [[ "$prompt_output" == *"approve"* && "$prompt_output" == *"request-changes"* && "$prompt_output" == *"comment"* ]]; then
    pass "9 - build prompt contains template"
else
    fail "9 - build prompt contains template"
fi

# -----------------------------------------------------------------------
# 10. Build prompt includes target context
# -----------------------------------------------------------------------
if [[ "$prompt_output" == *"You are the backend developer."* ]]; then
    pass "10 - build prompt includes target context"
else
    fail "10 - build prompt includes target context"
fi

# -----------------------------------------------------------------------
# 11. Save review — file exists
# -----------------------------------------------------------------------
orch_review_init 5 "$TEST_ROOT"
orch_review_assign "09-qa" "06-backend"
review_text="**Verdict:** approve

**Summary:** Looks good.

**Details:**
No issues found."

orch_review_save "09-qa" "06-backend" "$review_text" 2>/dev/null
expected_file="$TEST_ROOT/prompts/09-qa/reviews/cycle-5-06-backend.md"
if [[ -f "$expected_file" ]]; then
    pass "11 - save review (file exists)"
else
    fail "11 - save review (file exists at $expected_file)"
fi

# -----------------------------------------------------------------------
# 12. Save review with approve verdict
# -----------------------------------------------------------------------
saved_verdict="${_ORCH_REVIEW_RESULTS[09-qa:06-backend]:-}"
if [[ "$saved_verdict" == "approve" ]]; then
    pass "12 - save review with approve verdict"
else
    fail "12 - save review with approve verdict (got: $saved_verdict)"
fi

# -----------------------------------------------------------------------
# 13. Save review with request-changes
# -----------------------------------------------------------------------
orch_review_init 6 "$TEST_ROOT"
orch_review_assign "09-qa" "06-backend"
rc_text="**Verdict:** request-changes

**Summary:** Needs fixes.

**Details:**
Found security issue."

orch_review_save "09-qa" "06-backend" "$rc_text" 2>/dev/null
saved_verdict="${_ORCH_REVIEW_RESULTS[09-qa:06-backend]:-}"
if [[ "$saved_verdict" == "request-changes" ]]; then
    pass "13 - save review with request-changes"
else
    fail "13 - save review with request-changes (got: $saved_verdict)"
fi

# -----------------------------------------------------------------------
# 14. Has blocking — after request-changes
# -----------------------------------------------------------------------
if orch_review_has_blocking "09-qa"; then
    pass "14 - has blocking after request-changes"
else
    fail "14 - has blocking after request-changes"
fi

# -----------------------------------------------------------------------
# 15. No blocking on approve
# -----------------------------------------------------------------------
orch_review_init 7 "$TEST_ROOT"
orch_review_assign "09-qa" "06-backend"
approve_text="**Verdict:** approve

**Summary:** All good."

orch_review_save "09-qa" "06-backend" "$approve_text" 2>/dev/null
if orch_review_has_blocking "09-qa"; then
    fail "15 - no blocking on approve (got blocking)"
else
    pass "15 - no blocking on approve"
fi

# -----------------------------------------------------------------------
# 16. Summary output
# -----------------------------------------------------------------------
orch_review_init 8 "$TEST_ROOT"
orch_review_assign "09-qa" "06-backend"
orch_review_assign "02-cto" "06-backend"
orch_review_save "09-qa" "06-backend" "**Verdict:** approve" 2>/dev/null
orch_review_save "02-cto" "06-backend" "**Verdict:** request-changes" 2>/dev/null

summary_output=$(orch_review_summary)
if [[ "$summary_output" == *"06-backend"* && "$summary_output" == *"approve="* && "$summary_output" == *"request-changes="* ]]; then
    pass "16 - summary output"
else
    fail "16 - summary output (got: $summary_output)"
fi

# -----------------------------------------------------------------------
# 17. Parse config (no reviews column)
# -----------------------------------------------------------------------
orch_review_init 9 "$TEST_ROOT"

conf_no_reviews="$TMPDIR_TEST/agents-no-reviews.conf"
cat > "$conf_no_reviews" <<'CONF'
# agent | model | freq | active | ownership | prompt
06-backend | claude | 1 | true | src/core/ | prompts/06-backend/06-backend.txt
CONF

orch_review_parse_config "$conf_no_reviews"
result=$(orch_review_get_assignments "06-backend")
if [[ -z "$result" ]]; then
    pass "17 - parse config (no reviews column)"
else
    fail "17 - parse config (no reviews column) (got: $result)"
fi

# -----------------------------------------------------------------------
# 18. Parse config (with reviews column)
# -----------------------------------------------------------------------
orch_review_init 10 "$TEST_ROOT"

conf_with_reviews="$TMPDIR_TEST/agents-with-reviews.conf"
cat > "$conf_with_reviews" <<'CONF'
# agent | model | freq | active | ownership | prompt | reviews
09-qa | claude | 3 | true | tests/ | prompts/09-qa/09-qa.txt | 06-backend,11-web
02-cto | claude | 2 | true | docs/ | prompts/02-cto/02-cto.txt | 06-backend
CONF

orch_review_parse_config "$conf_with_reviews"
result_qa=$(orch_review_get_assignments "09-qa")
result_cto=$(orch_review_get_assignments "02-cto")
if [[ "$result_qa" == "06-backend,11-web" && "$result_cto" == "06-backend" ]]; then
    pass "18 - parse config (with reviews column)"
else
    fail "18 - parse config (with reviews column) (qa=$result_qa cto=$result_cto)"
fi

# -----------------------------------------------------------------------
# 19. Should run — commit mentions agent ID
# -----------------------------------------------------------------------
orch_review_init 11 "$TEST_ROOT"
git -C "$TEST_ROOT" commit --allow-empty -m "feat(06-backend): add new endpoint" 2>/dev/null
if orch_review_should_run "06-backend"; then
    pass "19 - should run (commit mentions agent ID)"
else
    fail "19 - should run (commit mentions agent ID)"
fi

# -----------------------------------------------------------------------
# 20. Report runs without error
# -----------------------------------------------------------------------
orch_review_init 12 "$TEST_ROOT"
orch_review_assign "09-qa" "06-backend"
orch_review_save "09-qa" "06-backend" "**Verdict:** approve" 2>/dev/null
report_output=$(orch_review_report 2>/dev/null) || true
if [[ -n "$report_output" ]]; then
    pass "20 - report runs without error"
else
    fail "20 - report runs without error"
fi

# -----------------------------------------------------------------------
# 21. orch_review_checklist — security type contains security items
# -----------------------------------------------------------------------
orch_review_init 13 "$TEST_ROOT"
checklist_out=$(orch_review_checklist "09-qa" "06-backend" "$fake_diff" "security")
if [[ "$checklist_out" == *"INJ-1"* && "$checklist_out" == *"PATH-1"* && "$checklist_out" == *"DATA-1"* ]]; then
    pass "21 - checklist security type contains security items"
else
    fail "21 - checklist security type contains security items"
fi

# -----------------------------------------------------------------------
# 22. orch_review_checklist — security type does NOT contain correctness items
# -----------------------------------------------------------------------
if [[ "$checklist_out" != *"ERR-1"* && "$checklist_out" != *"ARG-1"* ]]; then
    pass "22 - checklist security type excludes correctness items"
else
    fail "22 - checklist security type excludes correctness items"
fi

# -----------------------------------------------------------------------
# 23. orch_review_checklist — correctness type contains correctness items
# -----------------------------------------------------------------------
checklist_correctness=$(orch_review_checklist "09-qa" "06-backend" "$fake_diff" "correctness")
if [[ "$checklist_correctness" == *"ERR-1"* && "$checklist_correctness" == *"ARG-1"* && "$checklist_correctness" == *"EDGE-1"* ]]; then
    pass "23 - checklist correctness type contains correctness items"
else
    fail "23 - checklist correctness type contains correctness items"
fi

# -----------------------------------------------------------------------
# 24. orch_review_checklist — style type contains style items
# -----------------------------------------------------------------------
checklist_style=$(orch_review_checklist "09-qa" "06-backend" "$fake_diff" "style")
if [[ "$checklist_style" == *"NAME-1"* && "$checklist_style" == *"SC-1"* ]]; then
    pass "24 - checklist style type contains style items"
else
    fail "24 - checklist style type contains style items"
fi

# -----------------------------------------------------------------------
# 25. orch_review_checklist — full type contains items from all three categories
# -----------------------------------------------------------------------
checklist_full=$(orch_review_checklist "09-qa" "06-backend" "$fake_diff" "full")
if [[ "$checklist_full" == *"INJ-1"* && "$checklist_full" == *"ERR-1"* && "$checklist_full" == *"NAME-1"* ]]; then
    pass "25 - checklist full type contains all three categories"
else
    fail "25 - checklist full type contains all three categories"
fi

# -----------------------------------------------------------------------
# 26. orch_review_checklist — includes the diff text
# -----------------------------------------------------------------------
if [[ "$checklist_full" == *"old line"* && "$checklist_full" == *"new line"* ]]; then
    pass "26 - checklist includes diff text"
else
    fail "26 - checklist includes diff text"
fi

# -----------------------------------------------------------------------
# 27. orch_review_checklist — invalid review_type returns error
# -----------------------------------------------------------------------
if orch_review_checklist "09-qa" "06-backend" "$fake_diff" "bogus" 2>/dev/null; then
    fail "27 - checklist rejects invalid review_type (should have returned non-zero)"
else
    pass "27 - checklist rejects invalid review_type"
fi

# -----------------------------------------------------------------------
# 28. orch_review_checklist — empty diff is handled gracefully
# -----------------------------------------------------------------------
checklist_empty=$(orch_review_checklist "09-qa" "06-backend" "" "security")
if [[ "$checklist_empty" == *"no changes detected"* ]]; then
    pass "28 - checklist handles empty diff"
else
    fail "28 - checklist handles empty diff"
fi

# -----------------------------------------------------------------------
# 29. orch_review_batch — output contains each target's section header
# -----------------------------------------------------------------------
orch_review_init 14 "$TEST_ROOT"
# Ensure there is at least one commit so generate_diff does not error
git -C "$TEST_ROOT" commit --allow-empty -m "feat(06-backend): batch test setup" 2>/dev/null

batch_out=$(orch_review_batch "09-qa" "06-backend,11-web" "HEAD~1" 2>/dev/null || true)
if [[ "$batch_out" == *"Agent: 06-backend"* && "$batch_out" == *"Agent: 11-web"* ]]; then
    pass "29 - batch output contains section header for each target"
else
    fail "29 - batch output contains section header for each target (got: ${batch_out:0:200})"
fi

# -----------------------------------------------------------------------
# 30. orch_review_batch — output contains batch verdict instructions
# -----------------------------------------------------------------------
if [[ "$batch_out" == *"Verdicts"* && "$batch_out" == *"approve|request-changes|comment"* ]]; then
    pass "30 - batch output contains verdict instructions"
else
    fail "30 - batch output contains verdict instructions"
fi

# -----------------------------------------------------------------------
# 31. orch_review_batch — single target works (no trailing comma issues)
# -----------------------------------------------------------------------
batch_single=$(orch_review_batch "09-qa" "06-backend" "HEAD~1" 2>/dev/null || true)
if [[ "$batch_single" == *"Agent: 06-backend"* ]]; then
    pass "31 - batch works with a single target"
else
    fail "31 - batch works with a single target"
fi

# -----------------------------------------------------------------------
# 32. orch_review_prioritize — zero-change agents are omitted
# -----------------------------------------------------------------------
orch_review_init 15 "$TEST_ROOT"
# nonexistent-agent will produce an empty diff → should be omitted
prioritized=$(orch_review_prioritize "nonexistent-agent" "HEAD" 2>/dev/null || true)
if [[ -z "$prioritized" ]]; then
    pass "32 - prioritize omits agents with zero changes"
else
    fail "32 - prioritize omits agents with zero changes (got: $prioritized)"
fi

# -----------------------------------------------------------------------
# 33. orch_review_prioritize — agents with changes appear in output
# -----------------------------------------------------------------------
# Create a real file change for 06-backend to ensure a non-empty diff
mkdir -p "$TEST_ROOT/prompts/06-backend"
echo "new content $(date +%s)" >> "$TEST_ROOT/prompts/06-backend/06-backend.txt"
git -C "$TEST_ROOT" add "$TEST_ROOT/prompts/06-backend/06-backend.txt"
git -C "$TEST_ROOT" commit -m "feat(06-backend): prioritize test change" 2>/dev/null

prioritized_real=$(orch_review_prioritize "06-backend,nonexistent-agent" "HEAD~1" 2>/dev/null || true)
if [[ "$prioritized_real" == *"06-backend"* ]]; then
    pass "33 - prioritize includes agents that have changes"
else
    fail "33 - prioritize includes agents that have changes (got: $prioritized_real)"
fi

# -----------------------------------------------------------------------
# 34. orch_review_prioritize — nonexistent agent does not appear in output
# -----------------------------------------------------------------------
if [[ "$prioritized_real" != *"nonexistent-agent"* ]]; then
    pass "34 - prioritize excludes agents with zero changes from mixed list"
else
    fail "34 - prioritize excludes agents with zero changes from mixed list"
fi

# -----------------------------------------------------------------------
# 35. orch_review_auto_verdict — auto-approves tiny prompts/-only change
# -----------------------------------------------------------------------
orch_review_init 16 "$TEST_ROOT"
# Create a tiny change (1 line) inside prompts/ so the diff is tiny and safe
echo "tiny change $(date +%s)" >> "$TEST_ROOT/prompts/06-backend/06-backend.txt"
git -C "$TEST_ROOT" add "$TEST_ROOT/prompts/06-backend/06-backend.txt"
git -C "$TEST_ROOT" commit -m "docs(06-backend): trivial prompt tweak" 2>/dev/null

if orch_review_auto_verdict "06-backend" "HEAD~1" 5 2>/dev/null; then
    pass "35 - auto_verdict approves tiny prompts/-only change"
else
    fail "35 - auto_verdict approves tiny prompts/-only change (returned non-zero)"
fi

# -----------------------------------------------------------------------
# 36. orch_review_auto_verdict — stores approve result in _ORCH_REVIEW_RESULTS
# -----------------------------------------------------------------------
if [[ "${_ORCH_REVIEW_RESULTS[auto:06-backend]:-}" == "approve" ]]; then
    pass "36 - auto_verdict stores approve in results map"
else
    fail "36 - auto_verdict stores approve in results map (got: ${_ORCH_REVIEW_RESULTS[auto:06-backend]:-EMPTY})"
fi

# -----------------------------------------------------------------------
# 37. orch_review_auto_verdict — does not auto-approve when line count exceeds threshold
# -----------------------------------------------------------------------
orch_review_init 17 "$TEST_ROOT"
# Write more than 5 lines so it exceeds the threshold
seq 1 20 | sed 's/^/line /' >> "$TEST_ROOT/prompts/06-backend/06-backend.txt"
git -C "$TEST_ROOT" add "$TEST_ROOT/prompts/06-backend/06-backend.txt"
git -C "$TEST_ROOT" commit -m "feat(06-backend): large change" 2>/dev/null

if orch_review_auto_verdict "06-backend" "HEAD~1" 5 2>/dev/null; then
    fail "37 - auto_verdict should NOT approve large change (returned 0)"
else
    pass "37 - auto_verdict does not auto-approve large change"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
