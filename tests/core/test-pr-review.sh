#!/usr/bin/env bash
# test-pr-review.sh — Test auto PR reviewer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_contains() {
    local desc="$1" pattern="$2" text="$3"
    if echo "$text" | grep -qE "$pattern"; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (pattern "%s" not found)\n' "$desc" "$pattern" >&2
        (( FAIL++ )) || true
    fi
}

assert_exit() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" -eq "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

# Setup temp git repo
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/scripts" "$TMPDIR/.orchystraw"
git init -q "$TMPDIR"
(cd "$TMPDIR" && git config core.autocrlf false && git commit -q --allow-empty -m "init")

# Copy agents.conf for ownership checks
cat > "$TMPDIR/scripts/agents.conf" << 'CONF'
06-backend | prompts/06-backend.txt | scripts/ | 1 | Backend Developer
CONF

# ── Test 1: Clean commit produces clean review ──
printf 'test-pr-review: Test 1 — Clean commit\n'
echo 'echo "hello"' > "$TMPDIR/scripts/clean.sh"
(cd "$TMPDIR" && git add scripts/clean.sh && git commit -q -m "clean commit")
exit_code=0
output=$(bash "$PROJECT_ROOT/scripts/pr-review.sh" "HEAD~1..HEAD" "$TMPDIR" 2>&1) || exit_code=$?
assert_exit "clean commit exits 0" 0 "$exit_code"
assert_contains "shows CLEAN or info" "CLEAN|info" "$output"

# ── Test 2: Debug statement detection ──
printf 'test-pr-review: Test 2 — Debug detection\n'
echo 'console.log("debug")' > "$TMPDIR/scripts/debug.js"
(cd "$TMPDIR" && git add scripts/debug.js && git commit -q -m "add debug")
exit_code=0
output=$(bash "$PROJECT_ROOT/scripts/pr-review.sh" "HEAD~1..HEAD" "$TMPDIR" 2>&1) || exit_code=$?
assert_contains "detects debug statements" "Debug statements|console.log" "$output"

# ── Test 3: Secret detection ──
printf 'test-pr-review: Test 3 — Secret detection\n'
echo 'OPENAI_API_KEY=sk-abc123def456' > "$TMPDIR/scripts/secrets.env"
(cd "$TMPDIR" && git add scripts/secrets.env && git commit -q -m "add secrets")
exit_code=0
output=$(bash "$PROJECT_ROOT/scripts/pr-review.sh" "HEAD~1..HEAD" "$TMPDIR" 2>&1) || exit_code=$?
assert_exit "secrets trigger error exit" 1 "$exit_code"
assert_contains "detects secret" "secret|credential|ERROR" "$output"

# ── Test 4: Review file created ──
printf 'test-pr-review: Test 4 — Review file output\n'
review_count=$(ls "$TMPDIR/.orchystraw/reviews/"*.md 2>/dev/null | wc -l | tr -d '[:space:]')
if [[ "$review_count" -gt 0 ]]; then
    (( PASS++ )) || true
else
    printf '  FAIL: no review files created\n' >&2
    (( FAIL++ )) || true
fi

# ── Test 5: Empty diff handled gracefully ──
printf 'test-pr-review: Test 5 — Empty diff\n'
exit_code=0
output=$(bash "$PROJECT_ROOT/scripts/pr-review.sh" "HEAD..HEAD" "$TMPDIR" 2>&1) || exit_code=$?
assert_exit "empty diff exits 0" 0 "$exit_code"
assert_contains "empty diff message" "empty diff|no diff" "$output"

# ── Test 6: CRLF detection in shell scripts ──
printf 'test-pr-review: Test 6 — CRLF detection\n'
printf '#!/bin/bash\r\necho "crlf"\r\n' > "$TMPDIR/scripts/crlf.sh"
(cd "$TMPDIR" && git add scripts/crlf.sh && git commit -q -m "add crlf script")
exit_code=0
output=$(bash "$PROJECT_ROOT/scripts/pr-review.sh" "HEAD~1..HEAD" "$TMPDIR" 2>&1) || exit_code=$?
assert_contains "detects CRLF" "CRLF|line endings" "$output"

printf 'test-pr-review: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
