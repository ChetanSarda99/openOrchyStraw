#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — Test runner for src/core/ modules
#
# Usage:  bash tests/core/run-tests.sh
#
# Runs each test file in tests/core/test-*.sh and reports pass/fail.
# Exit code: 0 if all pass, 1 if any fail.
# =============================================================================

set -euo pipefail

# ── Auto-detect bash 5+ and re-exec if needed ────────────────────────────
# Most core modules require bash 5.0+ (declare -g, associative arrays, etc.)
# macOS ships bash 3.2 by default; Linux distros vary in bash location.
if (( BASH_VERSINFO[0] < 5 )); then
    for _bash5 in /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash $(command -v bash 2>/dev/null); do
        if [[ -x "$_bash5" ]] && "$_bash5" -c '(( BASH_VERSINFO[0] >= 5 ))' 2>/dev/null; then
            exec "$_bash5" "$0" "$@"
        fi
    done
    printf '\n  WARNING: bash 5.0+ not found. Tests requiring bash 5 features will fail.\n'
    printf '  Install with: brew install bash  (macOS)  |  apt install bash  (Linux)\n\n'
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

run_test_file() {
    local test_file="$1"
    local name
    name="$(basename "$test_file")"

    printf '  %-40s ' "$name"

    local output
    if output=$("${BASH}" "$test_file" 2>&1); then
        printf 'PASS\n'
        (( PASS++ )) || true
    else
        printf 'FAIL\n'
        (( FAIL++ )) || true
        ERRORS+=("$name: $output")
    fi
}

printf '\n══════════════════════════════════════════\n'
printf '  OrchyStraw Core Module Tests\n'
printf '══════════════════════════════════════════\n\n'

for test_file in "$SCRIPT_DIR"/test-*.sh; do
    [[ -e "$test_file" ]] || continue
    run_test_file "$test_file"
done

printf '\n──────────────────────────────────────────\n'
printf '  Results: %d passed, %d failed\n' "$PASS" "$FAIL"
printf '──────────────────────────────────────────\n'

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf '\nFailures:\n'
    for err in "${ERRORS[@]}"; do
        printf '  %s\n' "$err"
    done
    exit 1
fi

exit 0
