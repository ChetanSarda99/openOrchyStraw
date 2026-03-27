#!/usr/bin/env bash
# Test: agent-kpis.sh — Per-agent KPI tracking module
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

_assert_nonzero() {
    local desc="$1" actual="$2"
    if [[ -n "$actual" && "$actual" != "0" && "$actual" != "0.0" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected nonzero, got=%s)\n' "$desc" "$actual"
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

_assert_file_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -f "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file should not exist: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Setup: use a temp directory for KPI output ──
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

export ORCH_KPI_DIR="$TEST_TMP/kpis"
export ORCH_KPI_CYCLE=4

# ── Source the module ──
source "$PROJECT_ROOT/src/core/agent-kpis.sh"

echo "=== test-agent-kpis.sh ==="

# ────────────────────────────────────────────
# Group 1: Initialization
# ────────────────────────────────────────────
echo ""
echo "--- orch_kpi_init ---"

# Test 1: init creates directory
orch_kpi_init 4
_assert "init creates KPI directory" "0" "$([[ -d "$ORCH_KPI_DIR" ]] && echo 0 || echo 1)"

# Test 2: cycle number is set
_assert "cycle number set to 4" "4" "$ORCH_KPI_CYCLE"

# Test 3: init is idempotent
orch_kpi_init 4
_assert "init idempotent — no error on second call" "0" "$?"

# Test 4: init with different cycle updates cycle
orch_kpi_init 7
_assert "init updates cycle number" "7" "$ORCH_KPI_CYCLE"
# Reset back
orch_kpi_init 4

# ────────────────────────────────────────────
# Group 2: Composite score computation
# ────────────────────────────────────────────
echo ""
echo "--- _orch_kpi_compute_score ---"

# Test 5: zero metrics = baseline score (neutral cycle_time gives 50 * 15 = 750 / 100 = 7.5)
score=$(_orch_kpi_compute_score 0 0 0 0 0 0)
_assert "zero metrics gives baseline" "7.5" "$score"

# Test 6: perfect metrics score
# files=20 → 100, tasks=10 → 100, tests=100, cycle=300 → 100, net=500 → 100
# (100*20 + 100*25 + 100*30 + 100*15 + 100*10) / 100 = 100.0
score=$(_orch_kpi_compute_score 20 10 100 300 500 0)
_assert "perfect metrics = 100.0" "100.0" "$score"

# Test 7: files above cap still gives 100 points for files
# files=50 → 100 (capped at 20)
score=$(_orch_kpi_compute_score 50 10 100 300 500 0)
_assert "files capped at 20 still 100.0" "100.0" "$score"

# Test 8: tasks above cap still gives 100 points
score=$(_orch_kpi_compute_score 20 20 100 300 500 0)
_assert "tasks capped at 10 still 100.0" "100.0" "$score"

# Test 9: only test pass rate contributes
# tests=100 → 100, rest=0 except cycle_time neutral
# (0*20 + 0*25 + 100*30 + 50*15 + 0*10) / 100 = 37.5
score=$(_orch_kpi_compute_score 0 0 100 0 0 0)
_assert "only test_pass_rate=100 gives 37.5" "37.5" "$score"

# Test 10: long cycle time penalises score
# cycle_time=1800 → 0 points
score=$(_orch_kpi_compute_score 0 0 0 1800 0 0)
_assert "1800s cycle_time = 0 cycle points" "0.0" "$score"

# Test 11: lines removed counts as absolute
score1=$(_orch_kpi_compute_score 0 0 0 0 0 100)
score2=$(_orch_kpi_compute_score 0 0 0 0 100 0)
_assert "abs(lines) symmetric for add/remove" "$score1" "$score2"

# ────────────────────────────────────────────
# Group 3: Collect (with git mock scenario)
# ────────────────────────────────────────────
echo ""
echo "--- orch_kpi_collect ---"

# Test 12: collect without agent name fails
if orch_kpi_collect "" 2>/dev/null; then
    _assert "collect with empty name fails" "1" "0"
else
    _assert "collect with empty name fails" "1" "1"
fi

# Test 13: collect before init fails
saved_dir="$ORCH_KPI_DIR"
ORCH_KPI_DIR="$TEST_TMP/nonexistent"
if orch_kpi_collect "06-backend" 2>/dev/null; then
    _assert "collect before init fails" "1" "0"
else
    _assert "collect before init fails" "1" "1"
fi
ORCH_KPI_DIR="$saved_dir"

# Test 14: collect with --skip-tests creates JSON
cd "$PROJECT_ROOT"
outfile=$(orch_kpi_collect "06-backend" --skip-tests)
_assert_file_exists "collect creates JSON file" "$ORCH_KPI_DIR/06-backend.json"

# Helper: extract JSON value without jq
_json_val() {
    local file="$1" key="$2"
    awk -F': ' -v k="\"$key\"" '$0 ~ k {gsub(/[",]/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' "$file"
}

# Test 15: JSON has required fields
agent_val=$(_json_val "$ORCH_KPI_DIR/06-backend.json" "agent")
_assert "JSON agent field" "06-backend" "$agent_val"

# Test 16: JSON has cycle number
cycle_val=$(_json_val "$ORCH_KPI_DIR/06-backend.json" "cycle")
_assert "JSON cycle field" "4" "$cycle_val"

# Test 17: JSON has timestamp in ISO format
ts_val=$(_json_val "$ORCH_KPI_DIR/06-backend.json" "timestamp")
_assert_match "JSON timestamp is ISO" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$ts_val"

# Test 18: JSON has metrics object with all 6 fields
metric_count=$(grep -cE '"(files_changed|tasks_completed|test_pass_rate|cycle_time_seconds|lines_added|lines_removed)"' "$ORCH_KPI_DIR/06-backend.json")
_assert "JSON metrics has 6 fields" "6" "$metric_count"

# Test 19: JSON has composite_score
has_score=$(grep -c '"composite_score"' "$ORCH_KPI_DIR/06-backend.json")
_assert "JSON has composite_score" "1" "$has_score"

# Test 20: collect returns file path
_assert_match "collect returns output path" "06-backend\\.json$" "$outfile"

# ────────────────────────────────────────────
# Group 4: Agent score retrieval
# ────────────────────────────────────────────
echo ""
echo "--- orch_kpi_agent_score ---"

# Test 21: agent_score for existing agent returns a number
score=$(orch_kpi_agent_score "06-backend")
_assert_match "agent_score returns numeric" '^[0-9]+\.[0-9]' "$score"

# Test 22: agent_score for non-existent agent returns 0.0
score=$(orch_kpi_agent_score "99-nonexistent")
_assert "agent_score for missing agent" "0.0" "$score"

# Test 23: agent_score without name fails
if orch_kpi_agent_score "" 2>/dev/null; then
    _assert "agent_score with empty name fails" "1" "0"
else
    _assert "agent_score with empty name fails" "1" "1"
fi

# ────────────────────────────────────────────
# Group 5: Report generation
# ────────────────────────────────────────────
echo ""
echo "--- orch_kpi_report ---"

# Test 24: report includes agent name
report=$(orch_kpi_report)
_assert_match "report contains agent name" "06-backend" "$report"

# Test 25: report includes header
_assert_match "report contains header" "Agent KPI Report" "$report"

# Test 26: report includes cycle number
_assert_match "report contains cycle number" "Cycle 4" "$report"

# Test 27: report to file
orch_kpi_report --file "$TEST_TMP/report.txt" >/dev/null
_assert_file_exists "report --file creates output" "$TEST_TMP/report.txt"

# Test 28: report file has content
file_content=$(cat "$TEST_TMP/report.txt")
_assert_match "report file has agent data" "06-backend" "$file_content"

# ────────────────────────────────────────────
# Group 6: Reset
# ────────────────────────────────────────────
echo ""
echo "--- orch_kpi_reset ---"

# Test 29: reset clears JSON files
orch_kpi_reset
_assert_file_not_exists "reset removes agent JSON" "$ORCH_KPI_DIR/06-backend.json"

# Test 30: reset leaves directory intact
_assert "reset preserves directory" "0" "$([[ -d "$ORCH_KPI_DIR" ]] && echo 0 || echo 1)"

# Test 31: reset on empty dir is safe
orch_kpi_reset
_assert "reset on empty dir succeeds" "0" "$?"

# Test 32: reset on nonexistent dir is safe
saved_dir="$ORCH_KPI_DIR"
ORCH_KPI_DIR="$TEST_TMP/gone"
orch_kpi_reset
_assert "reset on missing dir succeeds" "0" "$?"
ORCH_KPI_DIR="$saved_dir"

# ────────────────────────────────────────────
# Group 7: Report edge cases
# ────────────────────────────────────────────
echo ""
echo "--- edge cases ---"

# Test 33: report with no data shows message
orch_kpi_reset
report=$(orch_kpi_report)
_assert_match "empty report shows no-data message" "No KPI data" "$report"

# Test 34: collect multiple agents
orch_kpi_collect "06-backend" --skip-tests >/dev/null
orch_kpi_collect "09-qa" --skip-tests >/dev/null
_assert_file_exists "multiple agents: backend exists" "$ORCH_KPI_DIR/06-backend.json"
_assert_file_exists "multiple agents: qa exists" "$ORCH_KPI_DIR/09-qa.json"

# Test 35: report shows both agents
report=$(orch_kpi_report)
_assert_match "report shows backend" "06-backend" "$report"
_assert_match "report shows qa" "09-qa" "$report"

# ────────────────────────────────────────────
# Group 8: Double-source guard
# ────────────────────────────────────────────
echo ""
echo "--- double-source guard ---"

# Test 38: sourcing again doesn't error
source "$PROJECT_ROOT/src/core/agent-kpis.sh"
_assert "double-source guard works" "1" "$_ORCH_KPI_LOADED"

# ────────────────────────────────────────────
# Group 9: JSON schema validation
# ────────────────────────────────────────────
echo ""
echo "--- JSON schema ---"

# Fresh collect for schema checks
orch_kpi_reset
orch_kpi_collect "01-ceo" --skip-tests >/dev/null

# Test 39: all metric fields are numbers (no quotes around values = numeric in JSON)
_assert_json_numeric() {
    local desc="$1" file="$2" key="$3"
    # Numeric JSON values have no quotes: "key": 123 or "key": 45.6
    if grep -qE "\"$key\": *[0-9]" "$file"; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (key %s not numeric in %s)\n' "$desc" "$key" "$file"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_json_numeric "files_changed is number" "$ORCH_KPI_DIR/01-ceo.json" "files_changed"
_assert_json_numeric "tasks_completed is number" "$ORCH_KPI_DIR/01-ceo.json" "tasks_completed"
_assert_json_numeric "test_pass_rate is number" "$ORCH_KPI_DIR/01-ceo.json" "test_pass_rate"
_assert_json_numeric "cycle_time_seconds is number" "$ORCH_KPI_DIR/01-ceo.json" "cycle_time_seconds"
_assert_json_numeric "lines_added is number" "$ORCH_KPI_DIR/01-ceo.json" "lines_added"
_assert_json_numeric "lines_removed is number" "$ORCH_KPI_DIR/01-ceo.json" "lines_removed"
_assert_json_numeric "composite_score is number" "$ORCH_KPI_DIR/01-ceo.json" "composite_score"

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
