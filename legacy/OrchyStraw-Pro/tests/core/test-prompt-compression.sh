#!/usr/bin/env bash
# Test: prompt-compression.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# ---------------------------------------------------------------------------
# Setup: temp dir + fixture prompt
# ---------------------------------------------------------------------------
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

FIXTURE="$TEST_DIR/test-prompt.txt"
cat > "$FIXTURE" <<'EOF'
# Agent Prompt
**Role:** Test Agent

---

## What is OrchyStraw?
Project overview text.

---

## Tech Stack
- Bash
- Markdown

---

## PROTECTED FILES
- auto-agent.sh
- agents.conf

---

## File Ownership
- src/core/

---

## Current Tasks
1. Build feature X
2. Fix bug Y

---

## What's DONE
- Shipped v0.1.0

---

## Rules
1. Stay in lane
2. Write tests

---

## Git Safety
- Never push

---

## AFTER YOU FINISH
Update shared context.
EOF

# ---------------------------------------------------------------------------
# Source the module
# ---------------------------------------------------------------------------
source "$PROJECT_ROOT/src/core/prompt-compression.sh"

echo "=== prompt-compression.sh tests ==="

# ---------------------------------------------------------------------------
# 1. Module loads
# ---------------------------------------------------------------------------
[[ -n "${_ORCH_PROMPT_COMPRESSION_LOADED:-}" ]] && pass "1. module loads" || fail "1. module loads"

# ---------------------------------------------------------------------------
# 2. Double-source guard
# ---------------------------------------------------------------------------
_before="$_ORCH_PROMPT_COMPRESSION_LOADED"
source "$PROJECT_ROOT/src/core/prompt-compression.sh"
[[ "$_ORCH_PROMPT_COMPRESSION_LOADED" == "$_before" ]] && pass "2. double-source guard" || fail "2. double-source guard"

# ---------------------------------------------------------------------------
# 3. Init creates section mappings
# ---------------------------------------------------------------------------
orch_compress_init
[[ ${#_ORCH_COMPRESS_SECTION_TIER[@]} -gt 0 ]] && pass "3. init creates section mappings" || fail "3. init creates section mappings"

# ---------------------------------------------------------------------------
# 4. Full tier returns entire file unchanged
# ---------------------------------------------------------------------------
full_output=$(orch_compress_prompt "full" "$FIXTURE")
original=$(cat "$FIXTURE")
[[ "$full_output" == "$original" ]] && pass "4. full tier returns entire file" || fail "4. full tier returns entire file"

# ---------------------------------------------------------------------------
# 5. Standard tier includes Current Tasks (minimal section)
# ---------------------------------------------------------------------------
std_output=$(orch_compress_prompt "standard" "$FIXTURE")
echo "$std_output" | grep -q "Current Tasks" && pass "5. standard includes Current Tasks" || fail "5. standard includes Current Tasks"

# ---------------------------------------------------------------------------
# 6. Standard tier includes What's DONE (standard section)
# ---------------------------------------------------------------------------
echo "$std_output" | grep -q "What's DONE" && pass "6. standard includes What's DONE" || fail "6. standard includes What's DONE"

# ---------------------------------------------------------------------------
# 7. Standard tier EXCLUDES What is OrchyStraw (full-only)
# ---------------------------------------------------------------------------
if echo "$std_output" | grep -q "What is OrchyStraw"; then
    fail "7. standard excludes What is OrchyStraw"
else
    pass "7. standard excludes What is OrchyStraw"
fi

# ---------------------------------------------------------------------------
# 8. Standard tier EXCLUDES Tech Stack (full-only)
# ---------------------------------------------------------------------------
if echo "$std_output" | grep -q "Tech Stack"; then
    fail "8. standard excludes Tech Stack"
else
    pass "8. standard excludes Tech Stack"
fi

# ---------------------------------------------------------------------------
# 9. Minimal tier includes PROTECTED FILES
# ---------------------------------------------------------------------------
min_output=$(orch_compress_prompt "minimal" "$FIXTURE")
echo "$min_output" | grep -q "PROTECTED FILES" && pass "9. minimal includes PROTECTED FILES" || fail "9. minimal includes PROTECTED FILES"

# ---------------------------------------------------------------------------
# 10. Minimal tier includes Current Tasks
# ---------------------------------------------------------------------------
echo "$min_output" | grep -q "Current Tasks" && pass "10. minimal includes Current Tasks" || fail "10. minimal includes Current Tasks"

# ---------------------------------------------------------------------------
# 11. Minimal tier includes Rules
# ---------------------------------------------------------------------------
echo "$min_output" | grep -q "Rules" && pass "11. minimal includes Rules" || fail "11. minimal includes Rules"

# ---------------------------------------------------------------------------
# 12. Minimal tier includes Git Safety
# ---------------------------------------------------------------------------
echo "$min_output" | grep -q "Git Safety" && pass "12. minimal includes Git Safety" || fail "12. minimal includes Git Safety"

# ---------------------------------------------------------------------------
# 13. Minimal tier EXCLUDES What's DONE
# ---------------------------------------------------------------------------
if echo "$min_output" | grep -q "What's DONE"; then
    fail "13. minimal excludes What's DONE"
else
    pass "13. minimal excludes What's DONE"
fi

# ---------------------------------------------------------------------------
# 14. Minimal tier EXCLUDES What is OrchyStraw
# ---------------------------------------------------------------------------
if echo "$min_output" | grep -q "What is OrchyStraw"; then
    fail "14. minimal excludes What is OrchyStraw"
else
    pass "14. minimal excludes What is OrchyStraw"
fi

# ---------------------------------------------------------------------------
# 15. Header (before first ##) always included in all tiers
# ---------------------------------------------------------------------------
echo "$min_output" | grep -q "Role.*Test Agent" && pass "15. header included in minimal" || fail "15. header included in minimal"

# ---------------------------------------------------------------------------
# 16. Tier for agent: run count 0 → full
# ---------------------------------------------------------------------------
tier=$(orch_compress_tier_for_agent "test-agent" 0)
[[ "$tier" == "full" ]] && pass "16. run count 0 → full" || fail "16. run count 0 → full (got $tier)"

# ---------------------------------------------------------------------------
# 17. Tier for agent: run count 3 → standard
# ---------------------------------------------------------------------------
tier=$(orch_compress_tier_for_agent "test-agent" 3)
[[ "$tier" == "standard" ]] && pass "17. run count 3 → standard" || fail "17. run count 3 → standard (got $tier)"

# ---------------------------------------------------------------------------
# 18. Tier for agent: run count 6 → minimal
# ---------------------------------------------------------------------------
tier=$(orch_compress_tier_for_agent "test-agent" 6)
[[ "$tier" == "minimal" ]] && pass "18. run count 6 → minimal" || fail "18. run count 6 → minimal (got $tier)"

# ---------------------------------------------------------------------------
# 19. Force full overrides run count
# ---------------------------------------------------------------------------
tier=$(orch_compress_tier_for_agent "test-agent" 10 "force_full")
[[ "$tier" == "full" ]] && pass "19. force_full overrides run count" || fail "19. force_full overrides run count (got $tier)"

# ---------------------------------------------------------------------------
# 20. Record run increments count
# ---------------------------------------------------------------------------
_ORCH_COMPRESS_RUN_COUNT=()
orch_compress_record_run "test-agent"
orch_compress_record_run "test-agent"
[[ "${_ORCH_COMPRESS_RUN_COUNT[test-agent]}" -eq 2 ]] && pass "20. record run increments count" || fail "20. record run increments count"

# ---------------------------------------------------------------------------
# 21. Reset run count works (single agent)
# ---------------------------------------------------------------------------
orch_compress_reset_run_count "test-agent"
[[ "${_ORCH_COMPRESS_RUN_COUNT[test-agent]}" -eq 0 ]] && pass "21. reset run count (single)" || fail "21. reset run count (single)"

# ---------------------------------------------------------------------------
# 22. Reset run count works (all)
# ---------------------------------------------------------------------------
orch_compress_record_run "agent-a"
orch_compress_record_run "agent-b"
orch_compress_reset_run_count "all"
[[ ${#_ORCH_COMPRESS_RUN_COUNT[@]} -eq 0 ]] && pass "22. reset run count (all)" || fail "22. reset run count (all)"

# ---------------------------------------------------------------------------
# 23. Estimate savings returns 3 values
# ---------------------------------------------------------------------------
savings=$(orch_compress_estimate_savings "standard" "$FIXTURE")
word_count=$(echo "$savings" | wc -w)
[[ "$word_count" -eq 3 ]] && pass "23. estimate savings returns 3 values" || fail "23. estimate savings returns 3 values (got $word_count)"

# ---------------------------------------------------------------------------
# 24. Standard savings > 0
# ---------------------------------------------------------------------------
std_pct=$(echo "$savings" | awk '{print $3}')
[[ "$std_pct" -gt 0 ]] && pass "24. standard savings > 0% (got ${std_pct}%)" || fail "24. standard savings > 0% (got ${std_pct}%)"

# ---------------------------------------------------------------------------
# 25. Minimal savings > standard savings
# ---------------------------------------------------------------------------
min_savings=$(orch_compress_estimate_savings "minimal" "$FIXTURE")
min_pct=$(echo "$min_savings" | awk '{print $3}')
[[ "$min_pct" -gt "$std_pct" ]] && pass "25. minimal savings ($min_pct%) > standard ($std_pct%)" || fail "25. minimal savings ($min_pct%) > standard ($std_pct%)"

# ---------------------------------------------------------------------------
# 26. Missing file returns error
# ---------------------------------------------------------------------------
if orch_compress_prompt "full" "$TEST_DIR/nonexistent.txt" 2>/dev/null; then
    fail "26. missing file returns error"
else
    pass "26. missing file returns error"
fi

# ---------------------------------------------------------------------------
# 27. orch_compress_add_section overrides existing
# ---------------------------------------------------------------------------
orch_compress_init
orch_compress_add_section "Rules" 3
[[ "${_ORCH_COMPRESS_SECTION_TIER[Rules]}" -eq 3 ]] && pass "27. add_section overrides existing" || fail "27. add_section overrides existing"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed ($(( PASS + FAIL )) total)"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
