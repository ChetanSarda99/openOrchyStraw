#!/usr/bin/env bash
# Test: context-filter.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# --- Temp fixture setup ---
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

CTX_FILE="$TMPDIR_TEST/context.md"
cat > "$CTX_FILE" <<'FIXTURE'
# Shared Context — Cycle 5
> Read before starting

## Usage
- claude=0

## Progress (last cycle → this cycle)
- Previous cycle: 4

## Backend Status
- Built 3 modules

## iOS Status
- SwiftUI views added

## Design Status
- New mockups ready

## QA Findings
- 2 bugs found

## Blockers
- None

## Notes
- Deploy scheduled
FIXTURE

source "$PROJECT_ROOT/src/core/context-filter.sh"

echo "=== context-filter.sh tests ==="

# 1. Module loads
if [[ "${_ORCH_CONTEXT_FILTER_LOADED:-}" == "1" ]]; then
    pass "Module loads (_ORCH_CONTEXT_FILTER_LOADED=1)"
else
    fail "Module loads (_ORCH_CONTEXT_FILTER_LOADED not set)"
fi

# 2. Double-source guard
_before="$_ORCH_CONTEXT_FILTER_LOADED"
source "$PROJECT_ROOT/src/core/context-filter.sh"
if [[ "${_ORCH_CONTEXT_FILTER_LOADED}" == "$_before" ]]; then
    pass "Double-source guard prevents re-loading"
else
    fail "Double-source guard failed"
fi

# 3. Init creates mappings
orch_context_filter_init
if [[ ${#_ORCH_CTX_MAP[@]} -gt 0 ]]; then
    pass "Init creates mappings (${#_ORCH_CTX_MAP[@]} entries)"
else
    fail "Init creates mappings (map is empty)"
fi

# 4. Backend gets only Usage, Progress, Backend Status, Blockers, Notes
output=$(orch_context_for_agent "06-backend" "$CTX_FILE")
if echo "$output" | grep -q "## Usage" && \
   echo "$output" | grep -q "## Progress" && \
   echo "$output" | grep -q "## Backend Status" && \
   echo "$output" | grep -q "## Blockers" && \
   echo "$output" | grep -q "## Notes"; then
    pass "Backend gets Usage, Progress, Backend Status, Blockers, Notes"
else
    fail "Backend missing expected sections"
fi

# 5. Backend does NOT get iOS Status, Design Status, QA Findings
if ! echo "$output" | grep -q "## iOS Status" && \
   ! echo "$output" | grep -q "## Design Status" && \
   ! echo "$output" | grep -q "## QA Findings"; then
    pass "Backend does NOT get iOS Status, Design Status, QA Findings"
else
    fail "Backend received sections it should not have"
fi

# 6. iOS gets iOS Status but not Backend Status
ios_output=$(orch_context_for_agent "07-ios" "$CTX_FILE")
if echo "$ios_output" | grep -q "## iOS Status" && \
   ! echo "$ios_output" | grep -q "## Backend Status"; then
    pass "iOS gets iOS Status but not Backend Status"
else
    fail "iOS filtering incorrect"
fi

# 7. QA (ALL mapping) gets all sections
qa_output=$(orch_context_for_agent "09-qa" "$CTX_FILE")
if echo "$qa_output" | grep -q "## Usage" && \
   echo "$qa_output" | grep -q "## Backend Status" && \
   echo "$qa_output" | grep -q "## iOS Status" && \
   echo "$qa_output" | grep -q "## Design Status" && \
   echo "$qa_output" | grep -q "## QA Findings" && \
   echo "$qa_output" | grep -q "## Blockers" && \
   echo "$qa_output" | grep -q "## Notes"; then
    pass "QA (ALL mapping) gets all sections"
else
    fail "QA did not get all sections"
fi

# 8. PM (ALL mapping) gets all sections
pm_output=$(orch_context_for_agent "03-pm" "$CTX_FILE")
if echo "$pm_output" | grep -q "## Usage" && \
   echo "$pm_output" | grep -q "## Backend Status" && \
   echo "$pm_output" | grep -q "## iOS Status" && \
   echo "$pm_output" | grep -q "## QA Findings"; then
    pass "PM (ALL mapping) gets all sections"
else
    fail "PM did not get all sections"
fi

# 9. Unknown agent gets ALL sections
unknown_output=$(orch_context_for_agent "99-unknown" "$CTX_FILE")
if echo "$unknown_output" | grep -q "## Usage" && \
   echo "$unknown_output" | grep -q "## Backend Status" && \
   echo "$unknown_output" | grep -q "## iOS Status" && \
   echo "$unknown_output" | grep -q "## Design Status" && \
   echo "$unknown_output" | grep -q "## QA Findings"; then
    pass "Unknown agent gets ALL sections"
else
    fail "Unknown agent did not get all sections"
fi

# 10. Blockers always included even if not in mapping
# Add a custom mapping without Blockers
orch_context_add_mapping "99-test-blockers" "Usage"
blockers_output=$(orch_context_for_agent "99-test-blockers" "$CTX_FILE")
if echo "$blockers_output" | grep -q "## Blockers"; then
    pass "Blockers always included even if not in mapping"
else
    fail "Blockers not included for scoped agent"
fi

# 11. Notes always included even if not in mapping
if echo "$blockers_output" | grep -q "## Notes"; then
    pass "Notes always included even if not in mapping"
else
    fail "Notes not included for scoped agent"
fi

# 12. Header (lines before first ##) always included
if echo "$output" | grep -q "# Shared Context" && \
   echo "$output" | grep -q "> Read before starting"; then
    pass "Header (lines before first ##) always included"
else
    fail "Header not included in filtered output"
fi

# 13. orch_context_add_mapping overrides existing
orch_context_add_mapping "06-backend" "Usage,iOS Status"
override_output=$(orch_context_for_agent "06-backend" "$CTX_FILE")
if echo "$override_output" | grep -q "## iOS Status" && \
   ! echo "$override_output" | grep -q "## Backend Status"; then
    pass "orch_context_add_mapping overrides existing mapping"
else
    fail "orch_context_add_mapping did not override"
fi
# Restore original mapping
orch_context_filter_init

# 14. orch_context_estimate_savings returns 3 values
savings=$(orch_context_estimate_savings "06-backend" "$CTX_FILE")
word_count=$(echo "$savings" | wc -w)
if [[ "$word_count" -eq 3 ]]; then
    pass "orch_context_estimate_savings returns 3 values"
else
    fail "orch_context_estimate_savings returned $word_count values (expected 3)"
fi

# 15. orch_context_estimate_savings shows savings > 0 for scoped agents
savings_pct=$(echo "$savings" | awk '{print $3}')
if [[ "$savings_pct" -gt 0 ]]; then
    pass "orch_context_estimate_savings shows savings > 0 for scoped agents (${savings_pct}%)"
else
    fail "orch_context_estimate_savings savings_pct is $savings_pct (expected > 0)"
fi

# 16. orch_context_write_filtered writes file
OUT_FILE="$TMPDIR_TEST/filtered-backend.md"
orch_context_write_filtered "06-backend" "$CTX_FILE" "$OUT_FILE"
if [[ -f "$OUT_FILE" ]] && [[ -s "$OUT_FILE" ]]; then
    pass "orch_context_write_filtered writes file"
else
    fail "orch_context_write_filtered did not create output file"
fi

# 17. orch_context_for_agent returns 1 for missing file
if ! orch_context_for_agent "06-backend" "/nonexistent/path.md" 2>/dev/null; then
    pass "orch_context_for_agent returns 1 for missing file"
else
    fail "orch_context_for_agent did not return 1 for missing file"
fi

# 18. orch_context_for_agent returns 1 for empty agent_id
if ! orch_context_for_agent "" "$CTX_FILE" 2>/dev/null; then
    pass "orch_context_for_agent returns 1 for empty agent_id"
else
    fail "orch_context_for_agent did not return 1 for empty agent_id"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed ($(( PASS + FAIL )) total)"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
