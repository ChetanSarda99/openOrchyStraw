#!/usr/bin/env bash
# Test: session-tracker.sh — smart windowing
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/session-tracker.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; exit 1; }

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# ── Helper: create a tracker file with N cycles ──
create_tracker() {
    local file="$1"
    local num_cycles="$2"

    cat > "$file" << 'HEADER'
# OrchyStraw Session Tracker
# Records cycle history for continuity across sessions

## Cycle Log
| Cycle | Date | Agents Run | Key Outcomes |
|-------|------|-----------|--------------|
HEADER

    local c
    for ((c = 0; c < num_cycles; c++)); do
        echo "| $c | 2026-03-$((17 + c)) | 01,02,06 | Cycle $c outcomes summary line |" >> "$file"
    done

    echo "" >> "$file"
    echo "---" >> "$file"
    echo "" >> "$file"

    # WHAT SHIPPED blocks (newest first in file matches real format — newest at top)
    for ((c = num_cycles - 1; c >= 0; c--)); do
        cat >> "$file" << EOF
## WHAT SHIPPED — Cycle $c (2026-03-$((17 + c)) 10:00–10:30)

### 06-Backend
- Built module-$c.sh with feature X
- Tests: $((c * 10 + 5)) assertions pass

### 02-CTO
- Reviewed module-$c — APPROVED
- Hardening spec updated

### 03-PM (this cycle)
- Committed cycle $c work
- Session tracker updated

---

EOF
    done

    # Preserved sections
    cat >> "$file" << 'PRESERVED'
## MILESTONE DASHBOARD
| Milestone | Open | Closed | Status |
|-----------|------|--------|--------|
| v0.1.0 | 0 | 4 | TAG-READY |
| v0.2.0 | 3 | 8 | IN PROGRESS |

## CODEBASE SIZE
- `src/core/` modules: 17 bash files
- `tests/core/` files: 17 test files
- Total tests: 245

## NEXT CYCLE PRIORITIES
1. Tag v0.1.0
2. Continue token optimization
3. Benchmark sprint after tag
PRESERVED
}

# ── Test 1: Init with defaults ──
orch_session_init
[[ "$_ORCH_SESSION_INITIALIZED" == "true" ]] || fail "T1: not initialized"
[[ "$_ORCH_SESSION_RECENT" -eq 2 ]] || fail "T1: recent not 2"
[[ "$_ORCH_SESSION_SUMMARY" -eq 8 ]] || fail "T1: summary not 8"
pass "T1: init with defaults"

# ── Test 2: Init with custom params ──
orch_session_init 3 5
[[ "$_ORCH_SESSION_RECENT" -eq 3 ]] || fail "T2: recent not 3"
[[ "$_ORCH_SESSION_SUMMARY" -eq 5 ]] || fail "T2: summary not 5"
pass "T2: init with custom params"

# ── Test 3: Init with non-numeric defaults gracefully ──
orch_session_init "abc" "xyz"
[[ "$_ORCH_SESSION_RECENT" -eq 2 ]] || fail "T3: non-numeric recent didn't default to 2"
[[ "$_ORCH_SESSION_SUMMARY" -eq 8 ]] || fail "T3: non-numeric summary didn't default to 8"
pass "T3: non-numeric params default gracefully"

# ── Test 4: Window fails without init ──
_ORCH_SESSION_INITIALIZED=false
result=$(orch_session_window "/nonexistent" 2>&1) && fail "T4: should fail without init" || true
_ORCH_SESSION_INITIALIZED=false  # Reset for next test
pass "T4: window fails without init"

# ── Test 5: Window fails with missing file ──
orch_session_init
result=$(orch_session_window "/nonexistent/file.txt" 2>&1) && fail "T5: should fail with missing file" || true
pass "T5: window fails with missing file"

# ── Test 6: Small tracker (fewer cycles than recent window) ──
create_tracker "$TEST_DIR/small.txt" 2
orch_session_init 2 8
output=$(orch_session_window "$TEST_DIR/small.txt")
# Should contain both cycles' WHAT SHIPPED
[[ "$output" == *"WHAT SHIPPED — Cycle 1"* ]] || fail "T6: missing cycle 1 shipped"
[[ "$output" == *"WHAT SHIPPED — Cycle 0"* ]] || fail "T6: missing cycle 0 shipped"
# Should contain preserved sections
[[ "$output" == *"MILESTONE DASHBOARD"* ]] || fail "T6: missing milestone dashboard"
[[ "$output" == *"CODEBASE SIZE"* ]] || fail "T6: missing codebase size"
[[ "$output" == *"NEXT CYCLE PRIORITIES"* ]] || fail "T6: missing priorities"
pass "T6: small tracker preserves all content"

# ── Test 7: Medium tracker (cycles within summary range) ──
create_tracker "$TEST_DIR/medium.txt" 8
orch_session_init 2 8
output=$(orch_session_window "$TEST_DIR/medium.txt")
# Recent cycles (6, 7) should have full detail
[[ "$output" == *"WHAT SHIPPED — Cycle 7"* ]] || fail "T7: missing cycle 7 shipped"
[[ "$output" == *"WHAT SHIPPED — Cycle 6"* ]] || fail "T7: missing cycle 6 shipped"
# Older cycles should only have table rows, not full WHAT SHIPPED
[[ "$output" == *"| 3 |"* ]] || fail "T7: missing cycle 3 table row"
echo "$output" | grep -q "WHAT SHIPPED — Cycle 3 (" && fail "T7: cycle 3 should not have full shipped"
pass "T7: medium tracker shows recent detail + summary rows"

# ── Test 8: Large tracker (cycles beyond summary range are omitted) ──
create_tracker "$TEST_DIR/large.txt" 20
orch_session_init 2 8
output=$(orch_session_window "$TEST_DIR/large.txt")
# Recent (18, 19) have full detail
[[ "$output" == *"WHAT SHIPPED — Cycle 19"* ]] || fail "T8: missing cycle 19 shipped"
[[ "$output" == *"WHAT SHIPPED — Cycle 18"* ]] || fail "T8: missing cycle 18 shipped"
# Summary range (10-17) have table rows
[[ "$output" == *"| 10 |"* ]] || fail "T8: missing cycle 10 table row"
[[ "$output" == *"| 17 |"* ]] || fail "T8: missing cycle 17 table row"
# Old cycles (0-9) are omitted — match full row pattern to avoid milestone table false positives
echo "$output" | grep -q "^| 0 |" && fail "T8: cycle 0 table row should be omitted"
echo "$output" | grep -q "^| 9 |" && fail "T8: cycle 9 table row should be omitted"
echo "$output" | grep -q "WHAT SHIPPED — Cycle 0 (" && fail "T8: cycle 0 shipped should be omitted"
# Preserved sections still present
[[ "$output" == *"MILESTONE DASHBOARD"* ]] || fail "T8: missing milestone dashboard"
pass "T8: large tracker omits old cycles"

# ── Test 9: Preserved sections always present ──
create_tracker "$TEST_DIR/preserved.txt" 5
orch_session_init 1 2
output=$(orch_session_window "$TEST_DIR/preserved.txt")
[[ "$output" == *"MILESTONE DASHBOARD"* ]] || fail "T9a: missing milestone dashboard"
[[ "$output" == *"TAG-READY"* ]] || fail "T9b: missing milestone content"
[[ "$output" == *"CODEBASE SIZE"* ]] || fail "T9c: missing codebase size"
[[ "$output" == *"17 bash files"* ]] || fail "T9d: missing codebase size content"
[[ "$output" == *"NEXT CYCLE PRIORITIES"* ]] || fail "T9e: missing priorities"
[[ "$output" == *"Tag v0.1.0"* ]] || fail "T9f: missing priorities content"
pass "T9: preserved sections always present with content"

# ── Test 10: Preamble preserved ──
create_tracker "$TEST_DIR/preamble.txt" 3
orch_session_init
output=$(orch_session_window "$TEST_DIR/preamble.txt")
[[ "$output" == *"OrchyStraw Session Tracker"* ]] || fail "T10: missing preamble title"
pass "T10: preamble preserved"

# ── Test 11: Table header preserved ──
create_tracker "$TEST_DIR/header.txt" 3
orch_session_init
output=$(orch_session_window "$TEST_DIR/header.txt")
[[ "$output" == *"| Cycle | Date | Agents Run | Key Outcomes |"* ]] || fail "T11: missing table header"
[[ "$output" == *"|-------|------|-----------|--------------|"* ]] || fail "T11: missing table separator"
pass "T11: table header preserved"

# ── Test 12: Stats output ──
create_tracker "$TEST_DIR/stats.txt" 20
orch_session_init 2 8
orch_session_window "$TEST_DIR/stats.txt" > /dev/null
stats=$(orch_session_stats)
[[ "$stats" == *"total cycles:"* ]] || fail "T12: stats missing total cycles"
[[ "$stats" == *"full detail:"* ]] || fail "T12: stats missing full detail"
[[ "$stats" == *"summary rows:"* ]] || fail "T12: stats missing summary rows"
[[ "$stats" == *"savings:"* ]] || fail "T12: stats missing savings"
pass "T12: stats output complete"

# ── Test 13: Stats shows compression ──
create_tracker "$TEST_DIR/compress.txt" 20
orch_session_init 2 8
orch_session_window "$TEST_DIR/compress.txt" > /dev/null
stats=$(orch_session_stats)
# With 20 cycles, omitting 10 full shipped blocks should save significant lines
[[ "$stats" == *"original:"* ]] || fail "T13: stats missing original"
[[ "$stats" == *"windowed:"* ]] || fail "T13: stats missing windowed"
# Windowed should be fewer lines than original
local_orig=$(echo "$stats" | grep "original:" | grep -o '[0-9]\+')
local_wind=$(echo "$stats" | grep "windowed:" | grep -o '[0-9]\+')
[[ "$local_wind" -lt "$local_orig" ]] || fail "T13: windowed ($local_wind) not less than original ($local_orig)"
pass "T13: windowing compresses output"

# ── Test 14: Stats fails without prior window call ──
orch_session_init  # Reset state
_ORCH_SESSION_ORIG_LINES=0
result=$(orch_session_stats 2>&1) && {
    [[ "$result" == *"No tracker data"* ]] || fail "T14: should warn about no data"
}
pass "T14: stats warns without prior window"

# ── Test 15: Single cycle tracker ──
create_tracker "$TEST_DIR/single.txt" 1
orch_session_init 2 8
output=$(orch_session_window "$TEST_DIR/single.txt")
[[ "$output" == *"WHAT SHIPPED — Cycle 0"* ]] || fail "T15: missing cycle 0 shipped"
[[ "$output" == *"MILESTONE DASHBOARD"* ]] || fail "T15: missing preserved"
pass "T15: single cycle tracker works"

# ── Test 16: Zero cycles (empty tracker with only structure) ──
cat > "$TEST_DIR/empty.txt" << 'EMPTY'
# OrchyStraw Session Tracker

## Cycle Log
| Cycle | Date | Agents Run | Key Outcomes |
|-------|------|-----------|--------------|

---

## MILESTONE DASHBOARD
| Milestone | Open | Closed | Status |
|-----------|------|--------|--------|

## CODEBASE SIZE
- Nothing yet

## NEXT CYCLE PRIORITIES
1. Start building
EMPTY

orch_session_init
output=$(orch_session_window "$TEST_DIR/empty.txt")
[[ "$output" == *"MILESTONE DASHBOARD"* ]] || fail "T16: missing milestone in empty tracker"
[[ "$output" == *"Start building"* ]] || fail "T16: missing priorities in empty tracker"
pass "T16: empty tracker with structure works"

# ── Test 17: Custom window sizes ──
create_tracker "$TEST_DIR/custom.txt" 15
orch_session_init 3 4
output=$(orch_session_window "$TEST_DIR/custom.txt")
# Recent 3: cycles 12, 13, 14 — full detail
[[ "$output" == *"WHAT SHIPPED — Cycle 14"* ]] || fail "T17a: missing cycle 14"
[[ "$output" == *"WHAT SHIPPED — Cycle 13"* ]] || fail "T17b: missing cycle 13"
[[ "$output" == *"WHAT SHIPPED — Cycle 12"* ]] || fail "T17c: missing cycle 12"
# Cycle 11 should NOT have full detail
echo "$output" | grep -q "WHAT SHIPPED — Cycle 11 (" && fail "T17d: cycle 11 should not have full detail"
# Summary range (8-11) should have table rows
[[ "$output" == *"| 8 |"* ]] || fail "T17e: missing cycle 8 table row"
[[ "$output" == *"| 11 |"* ]] || fail "T17f: missing cycle 11 table row"
# Old cycles (0-7) should be omitted
echo "$output" | grep -q "^| 0 |" && fail "T17g: cycle 0 should be omitted"
echo "$output" | grep -q "^| 7 |" && fail "T17h: cycle 7 should be omitted"
pass "T17: custom window sizes (recent=3, summary=4)"

# ── Test 18: Recent window larger than total cycles ──
create_tracker "$TEST_DIR/overflow.txt" 3
orch_session_init 10 8
output=$(orch_session_window "$TEST_DIR/overflow.txt")
# All cycles should get full detail since recent > total
[[ "$output" == *"WHAT SHIPPED — Cycle 0"* ]] || fail "T18a: missing cycle 0"
[[ "$output" == *"WHAT SHIPPED — Cycle 1"* ]] || fail "T18b: missing cycle 1"
[[ "$output" == *"WHAT SHIPPED — Cycle 2"* ]] || fail "T18c: missing cycle 2"
pass "T18: recent window > total cycles — all get full detail"

# ── Test 19: WHAT SHIPPED content includes agent subsections ──
create_tracker "$TEST_DIR/subsections.txt" 5
orch_session_init 2 3
output=$(orch_session_window "$TEST_DIR/subsections.txt")
# Recent cycles should contain agent subsections
[[ "$output" == *"### 06-Backend"* ]] || fail "T19a: missing backend subsection"
[[ "$output" == *"### 02-CTO"* ]] || fail "T19b: missing CTO subsection"
[[ "$output" == *"### 03-PM (this cycle)"* ]] || fail "T19c: missing PM subsection"
pass "T19: full detail includes agent subsections"

# ── Test 20: Summary-range cycles do NOT include shipped blocks ──
create_tracker "$TEST_DIR/nosummary.txt" 10
orch_session_init 2 5
output=$(orch_session_window "$TEST_DIR/nosummary.txt")
# Cycles 3-7 are in summary range — should have table row but not shipped
for c in 3 4 5 6 7; do
    [[ "$output" == *"| $c |"* ]] || fail "T20: missing table row for cycle $c"
    echo "$output" | grep -q "WHAT SHIPPED — Cycle $c (" && fail "T20: cycle $c should not have shipped block"
done
pass "T20: summary-range cycles have table rows only"

# ── Test 21: Omitted cycles have neither table rows nor shipped blocks ──
create_tracker "$TEST_DIR/omit.txt" 15
orch_session_init 2 5
output=$(orch_session_window "$TEST_DIR/omit.txt")
# Cycles 0-7 should be fully omitted (recent=13-14, summary=8-12)
for c in 0 1 2 3 4 5 6 7; do
    echo "$output" | grep -q "^| $c |" && fail "T21: cycle $c table row should be omitted"
    echo "$output" | grep -q "WHAT SHIPPED — Cycle $c (" && fail "T21: cycle $c shipped should be omitted"
done
pass "T21: omitted cycles fully excluded"

# ── Test 22: Double-source guard ──
# Sourcing again should be a no-op (already loaded)
source "$PROJECT_ROOT/src/core/session-tracker.sh"
[[ "$_ORCH_SESSION_TRACKER_LOADED" == "1" ]] || fail "T22: double-source guard failed"
pass "T22: double-source guard works"

# ── Test 23: Real tracker file parsing ──
# Test with the actual SESSION_TRACKER.txt if it exists
real_tracker="$PROJECT_ROOT/prompts/00-session-tracker/SESSION_TRACKER.txt"
if [[ -f "$real_tracker" ]]; then
    orch_session_init 2 8
    output=$(orch_session_window "$real_tracker")
    # Should contain recent cycles
    [[ "$output" == *"WHAT SHIPPED"* ]] || fail "T23a: missing WHAT SHIPPED in real tracker"
    [[ "$output" == *"MILESTONE DASHBOARD"* ]] || fail "T23b: missing milestone in real tracker"
    # Should be shorter than original
    orig_lines=$(wc -l < "$real_tracker")
    wind_lines=$(_orch_session_line_count "$output")
    [[ "$wind_lines" -le "$orig_lines" ]] || fail "T23c: windowed ($wind_lines) > original ($orig_lines)"
    pass "T23: real tracker file parses and compresses"
else
    pass "T23: (skipped — real tracker not found)"
fi

# ── Test 24: Output ordering — recent cycles newest first ──
create_tracker "$TEST_DIR/order.txt" 10
orch_session_init 2 5
output=$(orch_session_window "$TEST_DIR/order.txt")
# Cycle 9 should appear before cycle 8 in output (newest first)
pos_9=$(echo "$output" | grep -n "WHAT SHIPPED — Cycle 9" | head -1 | cut -d: -f1)
pos_8=$(echo "$output" | grep -n "WHAT SHIPPED — Cycle 8" | head -1 | cut -d: -f1)
[[ -n "$pos_9" && -n "$pos_8" ]] || fail "T24: missing shipped blocks"
[[ "$pos_9" -lt "$pos_8" ]] || fail "T24: cycle 9 ($pos_9) should come before cycle 8 ($pos_8)"
pass "T24: recent cycles ordered newest first"

# ── Test 25: Milestone dashboard content preserved ──
create_tracker "$TEST_DIR/milestone.txt" 5
orch_session_init
output=$(orch_session_window "$TEST_DIR/milestone.txt")
[[ "$output" == *"v0.1.0"* ]] || fail "T25a: milestone v0.1.0 missing"
[[ "$output" == *"v0.2.0"* ]] || fail "T25b: milestone v0.2.0 missing"
[[ "$output" == *"TAG-READY"* ]] || fail "T25c: TAG-READY status missing"
[[ "$output" == *"IN PROGRESS"* ]] || fail "T25d: IN PROGRESS status missing"
pass "T25: milestone dashboard content fully preserved"

# ── Test 26: Init resets state between calls ──
create_tracker "$TEST_DIR/reset1.txt" 10
orch_session_init 2 3
orch_session_window "$TEST_DIR/reset1.txt" > /dev/null
[[ "$_ORCH_SESSION_MAX_CYCLE" -eq 9 ]] || fail "T26a: max cycle should be 9"

create_tracker "$TEST_DIR/reset2.txt" 5
orch_session_init 1 2
orch_session_window "$TEST_DIR/reset2.txt" > /dev/null
[[ "$_ORCH_SESSION_MAX_CYCLE" -eq 4 ]] || fail "T26b: max cycle should be 4 after re-init"
pass "T26: init resets state between calls"

# ── Test 27: Large cycle numbers ──
cat > "$TEST_DIR/largecycle.txt" << 'EOF'
# Session Tracker

## Cycle Log
| Cycle | Date | Agents Run | Key Outcomes |
|-------|------|-----------|--------------|
| 98 | 2026-06-15 | 01,06 | Cycle 98 work |
| 99 | 2026-06-16 | 01,06 | Cycle 99 work |
| 100 | 2026-06-17 | 01,06 | Cycle 100 milestone |

---

## WHAT SHIPPED — Cycle 100 (2026-06-17 10:00–10:30)

### 06-Backend
- Module 100 shipped

---

## WHAT SHIPPED — Cycle 99 (2026-06-16 10:00–10:30)

### 06-Backend
- Module 99 shipped

---

## WHAT SHIPPED — Cycle 98 (2026-06-15 10:00–10:30)

### 06-Backend
- Module 98 shipped

---

## MILESTONE DASHBOARD
| Milestone | Status |
|-----------|--------|
| v1.0.0 | SHIPPED |

## NEXT CYCLE PRIORITIES
1. v2.0.0 planning
EOF

orch_session_init 2 1
output=$(orch_session_window "$TEST_DIR/largecycle.txt")
[[ "$output" == *"WHAT SHIPPED — Cycle 100"* ]] || fail "T27a: missing cycle 100"
[[ "$output" == *"WHAT SHIPPED — Cycle 99"* ]] || fail "T27b: missing cycle 99"
echo "$output" | grep -q "WHAT SHIPPED — Cycle 98 (" && fail "T27c: cycle 98 should not have full detail"
[[ "$output" == *"| 98 |"* ]] || fail "T27d: cycle 98 should have table row"
pass "T27: large cycle numbers work correctly"

# ── Test 28: Windowed output line count reasonable ──
create_tracker "$TEST_DIR/linecount.txt" 30
orch_session_init 2 8
output=$(orch_session_window "$TEST_DIR/linecount.txt")
orig_lines=$(wc -l < "$TEST_DIR/linecount.txt")
wind_lines=$(_orch_session_line_count "$output")
# Windowed should be significantly smaller
savings_pct=$(( (orig_lines - wind_lines) * 100 / orig_lines ))
[[ "$savings_pct" -ge 30 ]] || fail "T28: savings $savings_pct% too low (expected >= 30%)"
pass "T28: 30-cycle tracker compressed by ${savings_pct}%"

# ── Test 29: Summary window of 0 means no summary rows ──
create_tracker "$TEST_DIR/nosummary2.txt" 10
orch_session_init 2 0
output=$(orch_session_window "$TEST_DIR/nosummary2.txt")
# Only recent (8, 9) should have anything
[[ "$output" == *"WHAT SHIPPED — Cycle 9"* ]] || fail "T29a: missing cycle 9"
[[ "$output" == *"WHAT SHIPPED — Cycle 8"* ]] || fail "T29b: missing cycle 8"
# No summary table rows for older cycles
echo "$output" | grep -q "^| 5 |" && fail "T29c: cycle 5 table row should be omitted"
pass "T29: summary=0 means no summary rows"

# ── Test 30: Recent window of 0 means no full detail ──
create_tracker "$TEST_DIR/norecent.txt" 10
orch_session_init 0 5
output=$(orch_session_window "$TEST_DIR/norecent.txt")
# No WHAT SHIPPED blocks at all
echo "$output" | grep -q "WHAT SHIPPED — Cycle" && fail "T30: no shipped blocks with recent=0"
# But summary table rows should exist
[[ "$output" == *"| 5 |"* ]] || fail "T30: missing table row for summary range"
pass "T30: recent=0 means no full detail blocks"

# ── Test 31: Tracker with no preserved sections ──
cat > "$TEST_DIR/nopreserved.txt" << 'EOF'
# Session Tracker

## Cycle Log
| Cycle | Date | Agents Run | Key Outcomes |
|-------|------|-----------|--------------|
| 0 | 2026-03-17 | 06 | Initial work |

---

## WHAT SHIPPED — Cycle 0 (2026-03-17 10:00–10:30)

### 06-Backend
- First module built

---
EOF

orch_session_init
output=$(orch_session_window "$TEST_DIR/nopreserved.txt")
[[ "$output" == *"WHAT SHIPPED — Cycle 0"* ]] || fail "T31: missing cycle 0"
[[ "$output" == *"First module built"* ]] || fail "T31: missing shipped content"
pass "T31: tracker without preserved sections works"

# ── Test 32: Table rows for recent cycles still appear ──
create_tracker "$TEST_DIR/tablerecent.txt" 5
orch_session_init 2 3
output=$(orch_session_window "$TEST_DIR/tablerecent.txt")
# Recent cycles should have both table row AND full detail
[[ "$output" == *"| 4 |"* ]] || fail "T32a: missing table row for recent cycle 4"
[[ "$output" == *"| 3 |"* ]] || fail "T32b: missing table row for recent cycle 3"
[[ "$output" == *"WHAT SHIPPED — Cycle 4"* ]] || fail "T32c: missing shipped for cycle 4"
pass "T32: recent cycles have both table rows and full detail"

# ── Test 33: Stats shows correct cycle ranges ──
create_tracker "$TEST_DIR/ranges.txt" 20
orch_session_init 2 8
orch_session_window "$TEST_DIR/ranges.txt" > /dev/null
stats=$(orch_session_stats)
[[ "$stats" == *"total cycles:  20"* ]] || fail "T33a: wrong total cycles"
[[ "$stats" == *"full detail:   cycles 18–19"* ]] || fail "T33b: wrong full detail range"
[[ "$stats" == *"summary rows:  cycles 10–17"* ]] || fail "T33c: wrong summary range"
pass "T33: stats shows correct cycle ranges"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════"

[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
