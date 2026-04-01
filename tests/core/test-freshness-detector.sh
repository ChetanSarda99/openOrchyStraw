#!/usr/bin/env bash
# test-freshness-detector.sh — Tests for src/core/freshness-detector.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/src/core/freshness-detector.sh"

PASS=0
FAIL=0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected "%s", got "%s")\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

assert_gt() {
    local desc="$1" threshold="$2" actual="$3"
    if [[ "$actual" -gt "$threshold" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected >%s, got %s)\n' "$desc" "$threshold" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

assert_exit() {
    local desc="$1" expected="$2"
    shift 2
    local actual=0
    "$@" || actual=$?
    if [[ "$expected" -eq "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

# ── Test 1: Init defaults ──
_ORCH_FRESHNESS_LOADED=""
source "$PROJECT_ROOT/src/core/freshness-detector.sh"
orch_freshness_init
assert_eq "default max age is 7" "7" "$_ORCH_FRESHNESS_MAX_AGE_DAYS"
assert_eq "findings start empty" "0" "$(orch_freshness_stale_count)"
assert_eq "scanned starts at 0" "0" "$_ORCH_FRESHNESS_SCANNED"

# ── Test 2: Custom max age ──
orch_freshness_init 14
assert_eq "custom max age 14" "14" "$_ORCH_FRESHNESS_MAX_AGE_DAYS"

# ── Test 3: Invalid max age defaults to 7 ──
orch_freshness_init "abc"
assert_eq "invalid max age defaults to 7" "7" "$_ORCH_FRESHNESS_MAX_AGE_DAYS"

# ── Test 4: Zero max age defaults to 7 ──
orch_freshness_init 0
assert_eq "zero max age defaults to 7" "7" "$_ORCH_FRESHNESS_MAX_AGE_DAYS"

# ── Test 5: Scan nonexistent target returns 1 ──
orch_freshness_init 7 "2026-03-31"
assert_exit "nonexistent target returns 1" 1 orch_freshness_scan "/nonexistent/path"

# ── Test 6: Fresh file has zero findings ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/fresh.md" << 'EOF'
# Fresh File
Date: 2026-03-30
Everything is current.
EOF
orch_freshness_scan "$WORK_DIR/fresh.md"
assert_eq "fresh file has 0 findings" "0" "$(orch_freshness_stale_count)"
assert_eq "scanned 1 file" "1" "$_ORCH_FRESHNESS_SCANNED"

# ── Test 7: Stale date detection ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/stale-date.md" << 'EOF'
# Old File
Last updated: 2026-01-15
This is very old.
EOF
orch_freshness_scan "$WORK_DIR/stale-date.md"
count=$(orch_freshness_stale_count)
assert_gt "stale date detected" 0 "$count"

# ── Test 8: Completed work reference detection ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/completed.md" << 'EOF'
### Done
- ✅ BUG-014 FIXED: task completed
- ✅ issue #42 DONE
EOF
orch_freshness_scan "$WORK_DIR/completed.md"
count=$(orch_freshness_stale_count)
assert_gt "completed refs detected" 0 "$count"

# ── Test 9: Blocker detection ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/blocked.md" << 'EOF'
## Status
- **BLOCKED** on CS applying fixes
- Work continues
EOF
orch_freshness_scan "$WORK_DIR/blocked.md"
count=$(orch_freshness_stale_count)
assert_gt "blocker detected" 0 "$count"

# ── Test 10: Cycle reference detection ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/cycle-ref.md" << 'EOF'
## Notes
Built in cycle 3.
Shipped in Cycle 12.
EOF
orch_freshness_scan "$WORK_DIR/cycle-ref.md"
count=$(orch_freshness_stale_count)
assert_gt "cycle refs detected" 0 "$count"

# ── Test 11: Directory scan ──
orch_freshness_init 7 "2026-03-31"
mkdir -p "$WORK_DIR/scandir"
cat > "$WORK_DIR/scandir/a.md" << 'EOF'
Date: 2020-01-01
Old content.
EOF
cat > "$WORK_DIR/scandir/b.txt" << 'EOF'
- BLOCKED on something
EOF
orch_freshness_scan "$WORK_DIR/scandir"
assert_gt "directory scan finds issues" 0 "$(orch_freshness_stale_count)"
assert_eq "scanned 2 files" "2" "$_ORCH_FRESHNESS_SCANNED"

# ── Test 12: Check returns 0 when fresh ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/ok.md" << 'EOF'
All good here.
No dates, no blockers.
EOF
orch_freshness_scan "$WORK_DIR/ok.md"
assert_exit "check returns 0 when fresh" 0 orch_freshness_check

# ── Test 13: Check returns 1 when stale ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/old.md" << 'EOF'
Date: 2025-01-01
Very old reference.
EOF
orch_freshness_scan "$WORK_DIR/old.md"
assert_exit "check returns 1 when stale" 1 orch_freshness_check

# ── Test 14: Report output format ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/rpt.md" << 'EOF'
Date: 2025-06-01
- **BLOCKED** on task #5
EOF
orch_freshness_scan "$WORK_DIR/rpt.md"
report=$(orch_freshness_report)
echo "$report" | grep -q "Freshness Report" && (( PASS++ )) || { printf '  FAIL: report has header\n' >&2; (( FAIL++ )); } || true
echo "$report" | grep -q "STALE_DATE" && (( PASS++ )) || { printf '  FAIL: report contains STALE_DATE\n' >&2; (( FAIL++ )); } || true
echo "$report" | grep -q "STALE_BLOCKER" && (( PASS++ )) || { printf '  FAIL: report contains STALE_BLOCKER\n' >&2; (( FAIL++ )); } || true

# ── Test 15: Guard prevents double-source ──
_ORCH_FRESHNESS_LOADED=1
source "$PROJECT_ROOT/src/core/freshness-detector.sh"
assert_eq "guard set" "1" "$_ORCH_FRESHNESS_LOADED"

# ── Test 16: Init resets findings from prior scan ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/old2.md" << 'EOF'
Date: 2024-01-01
EOF
orch_freshness_scan "$WORK_DIR/old2.md"
assert_gt "has findings before reset" 0 "$(orch_freshness_stale_count)"
orch_freshness_init 7 "2026-03-31"
assert_eq "findings reset after init" "0" "$(orch_freshness_stale_count)"

# ── Test 17: Multiple dates in one line ──
orch_freshness_init 7 "2026-03-31"
cat > "$WORK_DIR/multi.md" << 'EOF'
Updated 2025-01-01 and 2026-03-30 and 2024-06-15
EOF
orch_freshness_scan "$WORK_DIR/multi.md"
count=$(orch_freshness_stale_count)
assert_gt "multiple stale dates detected" 1 "$count"

# ── Test 18: Date within threshold is not flagged ──
orch_freshness_init 30 "2026-03-31"
cat > "$WORK_DIR/recent.md" << 'EOF'
Last updated: 2026-03-15
Still within 30 day window.
EOF
orch_freshness_scan "$WORK_DIR/recent.md"
assert_eq "recent date within threshold is clean" "0" "$(orch_freshness_stale_count)"

# ── Test 19: Custom today date ──
orch_freshness_init 7 "2026-04-15"
cat > "$WORK_DIR/custom.md" << 'EOF'
Date: 2026-04-01
EOF
orch_freshness_scan "$WORK_DIR/custom.md"
count=$(orch_freshness_stale_count)
assert_gt "custom today makes 2026-04-01 stale at +14d" 0 "$count"

# ── Test 20: Empty file has no findings ──
orch_freshness_init 7 "2026-03-31"
: > "$WORK_DIR/empty.md"
orch_freshness_scan "$WORK_DIR/empty.md"
assert_eq "empty file has 0 findings" "0" "$(orch_freshness_stale_count)"

# ── Results ──
printf '\ntest-freshness-detector: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
