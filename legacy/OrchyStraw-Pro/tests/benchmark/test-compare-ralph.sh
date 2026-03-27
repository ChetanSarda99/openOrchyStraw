#!/usr/bin/env bash
# Test: compare-ralph.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPARE_SCRIPT="$PROJECT_ROOT/scripts/benchmark/custom/compare-ralph.sh"

PASSED=0
FAILED=0
SKIPPED=0

_pass() { PASSED=$(( PASSED + 1 )); printf '  PASS: %s\n' "$1"; }
_fail() { FAILED=$(( FAILED + 1 )); printf '  FAIL: %s\n' "$1"; }
_skip() { SKIPPED=$(( SKIPPED + 1 )); printf '  SKIP: %s\n' "$1"; }

# Check if runtime deps are available (jq needed for dry-run/lib tests)
HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# ── Test 1: Syntax check ────────────────────────────────────────
if bash -n "$COMPARE_SCRIPT" 2>/dev/null; then
    _pass "syntax check (bash -n)"
else
    _fail "syntax check (bash -n)"
fi

# ── Test 2: --help flag works ────────────────────────────────────
help_output="$(bash "$COMPARE_SCRIPT" --help 2>&1)" || true
if printf '%s' "$help_output" | grep -q "Usage:"; then
    _pass "--help prints usage"
else
    _fail "--help should print usage"
fi

if printf '%s' "$help_output" | grep -q "\-\-dry-run"; then
    _pass "--help mentions --dry-run"
else
    _fail "--help should mention --dry-run"
fi

if printf '%s' "$help_output" | grep -q "\-\-agents"; then
    _pass "--help mentions --agents"
else
    _fail "--help should mention --agents"
fi

if printf '%s' "$help_output" | grep -q "\-\-cycles"; then
    _pass "--help mentions --cycles"
else
    _fail "--help should mention --cycles"
fi

# ── Test 3: --dry-run produces cost estimate output ──────────────
if [[ "$HAS_JQ" -eq 1 ]]; then
    dry_output="$(bash "$COMPARE_SCRIPT" --dry-run --limit 1 2>&1)" || true
    if printf '%s' "$dry_output" | grep -q "Cost Estimate"; then
        _pass "--dry-run shows cost estimate"
    else
        _fail "--dry-run should show cost estimate"
    fi

    if printf '%s' "$dry_output" | grep -q "Ralph"; then
        _pass "--dry-run mentions Ralph"
    else
        _fail "--dry-run should mention Ralph"
    fi

    if printf '%s' "$dry_output" | grep -q "OrchyStraw"; then
        _pass "--dry-run mentions OrchyStraw"
    else
        _fail "--dry-run should mention OrchyStraw"
    fi

    if printf '%s' "$dry_output" | grep -q "Combined"; then
        _pass "--dry-run shows combined cost"
    else
        _fail "--dry-run should show combined cost"
    fi
else
    _skip "--dry-run tests (jq not installed)"
fi

# ── Test 4: Required functions exist ─────────────────────────────
# Source the script in a subshell and check functions are defined
if [[ "$HAS_JQ" -eq 1 ]]; then
    func_check="$(bash -c "
        source '$PROJECT_ROOT/scripts/benchmark/lib/instance-runner.sh'
        source '$PROJECT_ROOT/scripts/benchmark/lib/results-collector.sh'
        source '$PROJECT_ROOT/scripts/benchmark/lib/cost-estimator.sh'
        type -t run_instance 2>/dev/null || echo missing_run_instance
        type -t aggregate_jsonl 2>/dev/null || echo missing_aggregate_jsonl
        type -t generate_report 2>/dev/null || echo missing_generate_report
        type -t estimate_cost 2>/dev/null || echo missing_estimate_cost
        type -t print_estimate 2>/dev/null || echo missing_print_estimate
    " 2>&1)" || true

    if ! printf '%s' "$func_check" | grep -q "missing_run_instance"; then
        _pass "run_instance function exists"
    else
        _fail "run_instance function missing from lib"
    fi

    if ! printf '%s' "$func_check" | grep -q "missing_aggregate_jsonl"; then
        _pass "aggregate_jsonl function exists"
    else
        _fail "aggregate_jsonl function missing from lib"
    fi

    if ! printf '%s' "$func_check" | grep -q "missing_estimate_cost"; then
        _pass "estimate_cost function exists"
    else
        _fail "estimate_cost function missing from lib"
    fi

    if ! printf '%s' "$func_check" | grep -q "missing_print_estimate"; then
        _pass "print_estimate function exists"
    else
        _fail "print_estimate function missing from lib"
    fi
else
    # Even without jq, we can check the lib files exist and are sourceable
    # The associative arrays in cost-estimator.sh require bash 4+
    for lib_file in instance-runner.sh results-collector.sh cost-estimator.sh; do
        if [[ -f "$PROJECT_ROOT/scripts/benchmark/lib/$lib_file" ]]; then
            _pass "lib/$lib_file exists"
        else
            _fail "lib/$lib_file missing"
        fi
    done
    _skip "function existence tests (jq not installed)"
fi

# ── Test 5: Input validation rejects bad values ──────────────────

# Bad limit (not a number)
bad_limit="$(bash "$COMPARE_SCRIPT" --limit abc 2>&1)" && bad_limit_exit=0 || bad_limit_exit=$?
if [[ "$bad_limit_exit" -ne 0 ]] && printf '%s' "$bad_limit" | grep -qi "positive integer"; then
    _pass "rejects non-numeric --limit"
else
    _fail "should reject --limit abc"
fi

# Bad limit (zero)
bad_zero="$(bash "$COMPARE_SCRIPT" --limit 0 2>&1)" && bad_zero_exit=0 || bad_zero_exit=$?
if [[ "$bad_zero_exit" -ne 0 ]]; then
    _pass "rejects --limit 0"
else
    _fail "should reject --limit 0"
fi

# Bad limit (negative)
bad_neg="$(bash "$COMPARE_SCRIPT" --limit -5 2>&1)" && bad_neg_exit=0 || bad_neg_exit=$?
if [[ "$bad_neg_exit" -ne 0 ]]; then
    _pass "rejects --limit -5"
else
    _fail "should reject --limit -5"
fi

# Bad model
bad_model="$(bash "$COMPARE_SCRIPT" --model gpt4 2>&1)" && bad_model_exit=0 || bad_model_exit=$?
if [[ "$bad_model_exit" -ne 0 ]] && printf '%s' "$bad_model" | grep -qi "invalid model"; then
    _pass "rejects invalid --model"
else
    _fail "should reject --model gpt4"
fi

# Bad agents
bad_agents="$(bash "$COMPARE_SCRIPT" --agents 0 2>&1)" && bad_agents_exit=0 || bad_agents_exit=$?
if [[ "$bad_agents_exit" -ne 0 ]]; then
    _pass "rejects --agents 0"
else
    _fail "should reject --agents 0"
fi

# Bad timeout
bad_timeout="$(bash "$COMPARE_SCRIPT" --timeout foo 2>&1)" && bad_timeout_exit=0 || bad_timeout_exit=$?
if [[ "$bad_timeout_exit" -ne 0 ]]; then
    _pass "rejects non-numeric --timeout"
else
    _fail "should reject --timeout foo"
fi

# Unknown flag
bad_flag="$(bash "$COMPARE_SCRIPT" --banana 2>&1)" && bad_flag_exit=0 || bad_flag_exit=$?
if [[ "$bad_flag_exit" -ne 0 ]] && printf '%s' "$bad_flag" | grep -qi "unknown"; then
    _pass "rejects unknown flag"
else
    _fail "should reject --banana"
fi

# ── Summary ──────────────────────────────────────────────────────
printf '\ncompare-ralph: %d passed, %d failed, %d skipped\n' "$PASSED" "$FAILED" "$SKIPPED"
[[ "$FAILED" -eq 0 ]] || exit 1
