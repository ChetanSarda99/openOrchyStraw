#!/usr/bin/env bash
# Test: session-windower.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/session-windower.sh"

echo "=== session-windower.sh tests ==="

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Test 1: Module loads
[[ -n "${_ORCH_SESSION_WINDOWER_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Token estimation
tmpfile="$TMPDIR_TEST/test-tokens.txt"
# Write exactly 400 chars
printf '%0.s.' {1..400} > "$tmpfile"
tokens=$(orch_estimate_tracker_tokens "$tmpfile")
[[ $tokens -eq 100 ]] && pass "token estimate: 400 chars = 100 tokens" || fail "token estimate: expected 100, got $tokens"

# Test 3: Token estimate for missing file
tokens=$(orch_estimate_tracker_tokens "$TMPDIR_TEST/nonexistent.txt")
[[ $tokens -eq 0 ]] && pass "token estimate: missing file = 0" || fail "token estimate: missing file = 0 (got $tokens)"

# Test 4: Count cycle sections
tracker="$TMPDIR_TEST/tracker.txt"
cat > "$tracker" <<'EOF'
## MILESTONE DASHBOARD
| v0.1.0 | 0 | 12 |

## WHAT SHIPPED — Cycle 3
### 06-Backend
- Built integration tests

## WHAT SHIPPED — Cycle 2
### 06-Backend
- Built modules

## WHAT SHIPPED — Cycle 1
### 11-Web
- Landing page
EOF

count=$(orch_count_cycle_sections "$tracker")
[[ $count -eq 3 ]] && pass "count sections: 3" || fail "count sections: 3 (got $count)"

# Test 5: No windowing needed (within window)
result=$(orch_window_session_tracker "$tracker" 5)
# File should be unchanged
count_after=$(orch_count_cycle_sections "$tracker")
[[ $count_after -eq 3 ]] && pass "no window needed: 3 sections, window=5" || fail "no window needed (got $count_after)"

# Test 6: Window compresses oldest cycle
cat > "$tracker" <<'EOF'
## MILESTONE DASHBOARD
| v0.1.0 | 0 | 12 |

## WHAT SHIPPED — Cycle 3
### 06-Backend
- Built integration tests

## WHAT SHIPPED — Cycle 2
### 06-Backend
- Built modules

## WHAT SHIPPED — Cycle 1
### 11-Web
- Landing page
EOF

orch_window_session_tracker "$tracker" 2

# Should have compressed history section
grep -q "Compressed History" "$tracker" && pass "window creates compressed section" || fail "window creates compressed section"

# Should still have 2 full cycle sections
full_count=$(orch_count_cycle_sections "$tracker")
[[ $full_count -eq 2 ]] && pass "window keeps 2 recent cycles" || fail "window keeps 2 recent cycles (got $full_count)"

# Test 7: Backup created
[[ -f "${tracker}.bak" ]] && pass "backup file created" || fail "backup file created"

# Test 8: should_window respects threshold
small_file="$TMPDIR_TEST/small-tracker.txt"
echo "small content" > "$small_file"
if orch_should_window "$small_file"; then
    fail "should_window: small file false"
else
    pass "should_window: small file false"
fi

# Test 9: should_window triggers for large file
large_file="$TMPDIR_TEST/large-tracker.txt"
# 8000 tokens * 4 chars = 32000+ chars
python3 -c "print('x' * 40000)" > "$large_file" 2>/dev/null || printf '%0.s.' {1..40000} > "$large_file"
if orch_should_window "$large_file"; then
    pass "should_window: large file true"
else
    fail "should_window: large file true"
fi

# Test 10: auto_window only windows when needed
small_tracker="$TMPDIR_TEST/auto-small.txt"
echo "tiny" > "$small_tracker"
if orch_auto_window "$small_tracker"; then
    fail "auto_window: skip small file"
else
    pass "auto_window: skip small file"
fi

# Test 11: Default window size
[[ "$_ORCH_WINDOW_SIZE" -eq 5 ]] && pass "default window size = 5" || fail "default window size = 5 (got $_ORCH_WINDOW_SIZE)"

echo ""
echo "session-windower: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
