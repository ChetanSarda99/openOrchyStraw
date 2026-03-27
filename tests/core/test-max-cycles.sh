#!/usr/bin/env bash
# Tests for max-cycles.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/src/core/max-cycles.sh"

PASS=0 FAIL=0
assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        PASS=$(( PASS + 1 ))
    else
        FAIL=$(( FAIL + 1 ))
        printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$desc" "$expected" "$actual"
    fi
}

# Create temp project root
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# ── Default behavior ─────────────────────────────────────────────────────

unset MAX_CYCLES
assert "default is 10" "10" "$(orch_max_cycles_get "$TMP_ROOT")"
assert "default source" "default" "$(orch_max_cycles_source "$TMP_ROOT")"

# ── Environment variable ─────────────────────────────────────────────────

export MAX_CYCLES=5
assert "env MAX_CYCLES=5" "5" "$(orch_max_cycles_get "$TMP_ROOT")"
assert "env source" "env" "$(orch_max_cycles_source "$TMP_ROOT")"

export MAX_CYCLES=1
assert "env MIN boundary" "1" "$(orch_max_cycles_get "$TMP_ROOT")"

export MAX_CYCLES=100
assert "env MAX boundary" "100" "$(orch_max_cycles_get "$TMP_ROOT")"

export MAX_CYCLES=0
assert "env 0 clamps to 1" "1" "$(orch_max_cycles_get "$TMP_ROOT" 2>/dev/null)"

export MAX_CYCLES=999
assert "env 999 clamps to 100" "100" "$(orch_max_cycles_get "$TMP_ROOT" 2>/dev/null)"

export MAX_CYCLES="abc"
assert "env non-number falls to default" "10" "$(orch_max_cycles_get "$TMP_ROOT" 2>/dev/null)"
assert "env invalid → source=default" "default" "$(orch_max_cycles_source "$TMP_ROOT")"

unset MAX_CYCLES

# ── Config file ──────────────────────────────────────────────────────────

mkdir -p "$TMP_ROOT/.orchystraw"
echo "7" > "$TMP_ROOT/.orchystraw/max-cycles"
assert "file max-cycles=7" "7" "$(orch_max_cycles_get "$TMP_ROOT")"
assert "file source" "file" "$(orch_max_cycles_source "$TMP_ROOT")"

echo "  15  " > "$TMP_ROOT/.orchystraw/max-cycles"
assert "file with whitespace" "15" "$(orch_max_cycles_get "$TMP_ROOT")"

echo "0" > "$TMP_ROOT/.orchystraw/max-cycles"
assert "file 0 clamps to 1" "1" "$(orch_max_cycles_get "$TMP_ROOT" 2>/dev/null)"

echo "200" > "$TMP_ROOT/.orchystraw/max-cycles"
assert "file 200 clamps to 100" "100" "$(orch_max_cycles_get "$TMP_ROOT" 2>/dev/null)"

echo "notanumber" > "$TMP_ROOT/.orchystraw/max-cycles"
assert "file non-number falls to default" "10" "$(orch_max_cycles_get "$TMP_ROOT" 2>/dev/null)"

echo "" > "$TMP_ROOT/.orchystraw/max-cycles"
assert "file empty falls to default" "10" "$(orch_max_cycles_get "$TMP_ROOT")"

rm -f "$TMP_ROOT/.orchystraw/max-cycles"

# ── Env takes priority over file ─────────────────────────────────────────

mkdir -p "$TMP_ROOT/.orchystraw"
echo "20" > "$TMP_ROOT/.orchystraw/max-cycles"
export MAX_CYCLES=3
assert "env overrides file" "3" "$(orch_max_cycles_get "$TMP_ROOT")"
assert "env priority source" "env" "$(orch_max_cycles_source "$TMP_ROOT")"
unset MAX_CYCLES
rm -f "$TMP_ROOT/.orchystraw/max-cycles"

# ── Set function ─────────────────────────────────────────────────────────

orch_max_cycles_set 25 "$TMP_ROOT"
assert "set writes file" "25" "$(cat "$TMP_ROOT/.orchystraw/max-cycles" | tr -d '[:space:]')"
assert "set value readable" "25" "$(orch_max_cycles_get "$TMP_ROOT")"

# Set with clamping
orch_max_cycles_set 500 "$TMP_ROOT" 2>/dev/null
assert "set clamps high" "100" "$(cat "$TMP_ROOT/.orchystraw/max-cycles" | tr -d '[:space:]')"

# Set invalid
result="$(orch_max_cycles_set "abc" "$TMP_ROOT" 2>/dev/null)" && rc=0 || rc=$?
assert "set invalid returns 1" "1" "$rc"

# ── Validation function directly ─────────────────────────────────────────

assert "validate 10" "10" "$(orch_max_cycles_validate 10 "test")"
assert "validate 1" "1" "$(orch_max_cycles_validate 1 "test")"
assert "validate 100" "100" "$(orch_max_cycles_validate 100 "test")"
assert "validate 0 clamps" "1" "$(orch_max_cycles_validate 0 "test" 2>/dev/null)"
assert "validate 101 clamps" "100" "$(orch_max_cycles_validate 101 "test" 2>/dev/null)"

result="$(orch_max_cycles_validate "xyz" "test" 2>/dev/null)" && rc=0 || rc=$?
assert "validate non-number fails" "1" "$rc"

# ── Double source guard ──────────────────────────────────────────────────

source "$PROJECT_ROOT/src/core/max-cycles.sh"
assert "double source guard" "1" "$_ORCH_MAX_CYCLES_LOADED"

# ── Summary ──────────────────────────────────────────────────────────────

printf '\n── max-cycles tests: %d passed, %d failed ──\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
