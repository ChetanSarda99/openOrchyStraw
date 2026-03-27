#!/usr/bin/env bash
# Test: migrate.sh — Version detection and migration logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Test harness ──
PASS=0
FAIL=0

_assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected=%s actual=%s)\n' "$desc" "$expected" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if echo "$actual" | grep -qE "$pattern"; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (pattern=%s actual=%s)\n' "$desc" "$pattern" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected to contain: %s)\n' "$desc" "$needle"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (should NOT contain: %s)\n' "$desc" "$needle"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file not found: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_dir_exists() {
    local desc="$1" path="$2"
    if [[ -d "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (dir not found: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Setup: use a temp directory as fake project root ──
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

MIGRATE_SCRIPT="$PROJECT_ROOT/scripts/migrate.sh"

echo "=== test-migrate.sh ==="

# ────────────────────────────────────────────
# Group 1: Script syntax check
# ────────────────────────────────────────────
echo ""
echo "── Group 1: Script syntax ──"

result=$(bash -n "$MIGRATE_SCRIPT" 2>&1 && echo "OK" || echo "SYNTAX_ERROR")
_assert "migrate.sh has valid bash syntax" "OK" "$result"

# ────────────────────────────────────────────
# Group 2: Help and usage
# ────────────────────────────────────────────
echo ""
echo "── Group 2: Help and usage ──"

result=$(bash "$MIGRATE_SCRIPT" --help 2>&1)
_assert_contains "help shows detect command" "detect" "$result"
_assert_contains "help shows upgrade command" "upgrade" "$result"
_assert_contains "help shows check command" "check" "$result"

# No args shows usage and exits non-zero
result=$(bash "$MIGRATE_SCRIPT" 2>&1 || true)
_assert_contains "no args shows usage" "Usage" "$result"

# Unknown command exits non-zero
result=$(bash "$MIGRATE_SCRIPT" bogus 2>&1 || true)
_assert_contains "unknown command shows error" "Unknown command" "$result"

# ────────────────────────────────────────────
# Group 3: Version detection — v0.1.x
# ────────────────────────────────────────────
echo ""
echo "── Group 3: Detect v0.1.x ──"

# Create a fake v0.1 project: src/core/ with <=10 .sh files, no .orchystraw/
FAKE_01="$TEST_TMP/v01"
mkdir -p "$FAKE_01/src/core" "$FAKE_01/scripts"
for i in $(seq 1 8); do
    touch "$FAKE_01/src/core/module-$i.sh"
done
cp "$MIGRATE_SCRIPT" "$FAKE_01/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_01" bash "$FAKE_01/scripts/migrate.sh" detect 2>&1)
_assert_contains "detects v0.1 with 8 modules" "0.1" "$result"

# ────────────────────────────────────────────
# Group 4: Version detection — v0.2.x
# ────────────────────────────────────────────
echo ""
echo "── Group 4: Detect v0.2.x ──"

# Create a fake v0.2 project: src/core/ with 15 .sh files
FAKE_02="$TEST_TMP/v02"
mkdir -p "$FAKE_02/src/core" "$FAKE_02/scripts"
for i in $(seq 1 15); do
    touch "$FAKE_02/src/core/module-$i.sh"
done
cp "$MIGRATE_SCRIPT" "$FAKE_02/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_02" bash "$FAKE_02/scripts/migrate.sh" detect 2>&1)
_assert_contains "detects v0.2 with 15 modules" "0.2" "$result"

# ────────────────────────────────────────────
# Group 5: Version detection — explicit version file
# ────────────────────────────────────────────
echo ""
echo "── Group 5: Detect from version file ──"

FAKE_VF="$TEST_TMP/vfile"
mkdir -p "$FAKE_VF/src/core" "$FAKE_VF/.orchystraw" "$FAKE_VF/scripts"
echo "0.2.0" > "$FAKE_VF/.orchystraw/version"
for i in $(seq 1 5); do
    touch "$FAKE_VF/src/core/module-$i.sh"
done
cp "$MIGRATE_SCRIPT" "$FAKE_VF/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_VF" bash "$FAKE_VF/scripts/migrate.sh" detect 2>&1)
_assert_contains "version file overrides heuristic" "0.2.0" "$result"
_assert_not_contains "does not say inferred" "inferred" "$result"

# ────────────────────────────────────────────
# Group 6: Version detection — v0.5.x
# ────────────────────────────────────────────
echo ""
echo "── Group 6: Detect v0.5.x ──"

FAKE_05="$TEST_TMP/v05"
mkdir -p "$FAKE_05/src/core" "$FAKE_05/.orchystraw/db" "$FAKE_05/scripts"
cp "$MIGRATE_SCRIPT" "$FAKE_05/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_05" bash "$FAKE_05/scripts/migrate.sh" detect 2>&1)
_assert_contains "detects v0.5 with db directory" "0.5" "$result"

# ────────────────────────────────────────────
# Group 7: Dry-run (check) for v0.1 → v0.2
# ────────────────────────────────────────────
echo ""
echo "── Group 7: Dry-run check ──"

FAKE_CHECK="$TEST_TMP/vcheck"
mkdir -p "$FAKE_CHECK/src/core" "$FAKE_CHECK/scripts"
for i in $(seq 1 8); do
    touch "$FAKE_CHECK/src/core/module-$i.sh"
done
cp "$MIGRATE_SCRIPT" "$FAKE_CHECK/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_CHECK" bash "$FAKE_CHECK/scripts/migrate.sh" check 2>&1)
_assert_contains "check shows upgrade available" "v0.2.0" "$result"
_assert_contains "check says dry run" "Dry run" "$result"

# Verify no actual changes were made
_assert "dry run does not create .orchystraw" "false" "$(test -d "$FAKE_CHECK/.orchystraw" && echo true || echo false)"

# ────────────────────────────────────────────
# Group 8: Upgrade v0.1 → v0.2
# ────────────────────────────────────────────
echo ""
echo "── Group 8: Upgrade v0.1 to v0.2 ──"

FAKE_UP="$TEST_TMP/vup"
mkdir -p "$FAKE_UP/src/core" "$FAKE_UP/scripts"
for i in $(seq 1 8); do
    touch "$FAKE_UP/src/core/module-$i.sh"
done
cp "$MIGRATE_SCRIPT" "$FAKE_UP/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_UP" bash "$FAKE_UP/scripts/migrate.sh" upgrade 2>&1)
_assert_contains "upgrade output mentions v0.2" "v0.2" "$result"

# Verify .orchystraw/ was created
_assert_dir_exists "upgrade creates .orchystraw/" "$FAKE_UP/.orchystraw"

# Verify version file was written
_assert_file_exists "upgrade writes version file" "$FAKE_UP/.orchystraw/version"

if [[ -f "$FAKE_UP/.orchystraw/version" ]]; then
    ver_content=$(< "$FAKE_UP/.orchystraw/version")
    _assert "version file contains 0.2.0" "0.2.0" "$ver_content"
fi

# ────────────────────────────────────────────
# Group 9: Upgrade idempotency
# ────────────────────────────────────────────
echo ""
echo "── Group 9: Upgrade idempotency ──"

# After upgrade, detect should show v0.2
result=$(ORCH_PROJECT_ROOT="$FAKE_UP" bash "$FAKE_UP/scripts/migrate.sh" detect 2>&1)
_assert_contains "post-upgrade detects v0.2" "0.2.0" "$result"

# Running upgrade again should say already at v0.2
result=$(ORCH_PROJECT_ROOT="$FAKE_UP" bash "$FAKE_UP/scripts/migrate.sh" upgrade 2>&1)
_assert_contains "second upgrade says already at v0.2" "Already at v0.2" "$result"

# ────────────────────────────────────────────
# Group 10: Double-source guard
# ────────────────────────────────────────────
echo ""
echo "── Group 10: Double-source guard ──"

# Source the script and check guard variable
(
    unset _ORCH_MIGRATE_LOADED
    export ORCH_PROJECT_ROOT="$FAKE_UP"
    source "$MIGRATE_SCRIPT"
    if [[ "${_ORCH_MIGRATE_LOADED:-}" == "1" ]]; then
        echo "GUARD_SET"
    else
        echo "GUARD_MISSING"
    fi
) > "$TEST_TMP/guard_result.txt" 2>&1
guard_result=$(< "$TEST_TMP/guard_result.txt")
_assert_contains "double-source guard sets variable" "GUARD_SET" "$guard_result"

# ────────────────────────────────────────────
# Group 11: Unknown version handling
# ────────────────────────────────────────────
echo ""
echo "── Group 11: Edge cases ──"

FAKE_EMPTY="$TEST_TMP/vempty"
mkdir -p "$FAKE_EMPTY/scripts"
cp "$MIGRATE_SCRIPT" "$FAKE_EMPTY/scripts/migrate.sh"

result=$(ORCH_PROJECT_ROOT="$FAKE_EMPTY" bash "$FAKE_EMPTY/scripts/migrate.sh" detect 2>&1)
_assert_contains "empty project detects unknown" "unknown" "$result"

# Check on unknown version should error
result=$(ORCH_PROJECT_ROOT="$FAKE_EMPTY" bash "$FAKE_EMPTY/scripts/migrate.sh" check 2>&1 || true)
_assert_contains "check on unknown shows error" "Cannot determine" "$result"

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
