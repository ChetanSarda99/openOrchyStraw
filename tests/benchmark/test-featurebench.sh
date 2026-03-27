#!/usr/bin/env bash
# Test: featurebench.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FEATUREBENCH="$PROJECT_ROOT/scripts/benchmark/custom/featurebench.sh"
TASKS_FILE="$PROJECT_ROOT/scripts/benchmark/custom/featurebench-tasks.jsonl"

PASSED=0
FAILED=0
SKIPPED=0

_pass() { PASSED=$(( PASSED + 1 )); printf '  PASS: %s\n' "$1"; }
_fail() { FAILED=$(( FAILED + 1 )); printf '  FAIL: %s\n' "$1"; }
_skip() { SKIPPED=$(( SKIPPED + 1 )); printf '  SKIP: %s\n' "$1"; }

HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# ── Test 1: Syntax check ────────────────────────────────────────
if bash -n "$FEATUREBENCH" 2>/dev/null; then
    _pass "syntax check (bash -n)"
else
    _fail "syntax check (bash -n)"
fi

# ── Test 2: --help flag works ────────────────────────────────────
help_output="$(bash "$FEATUREBENCH" --help 2>&1)" || true
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

if printf '%s' "$help_output" | grep -q "\-\-limit"; then
    _pass "--help mentions --limit"
else
    _fail "--help should mention --limit"
fi

if printf '%s' "$help_output" | grep -q "\-\-timeout"; then
    _pass "--help mentions --timeout"
else
    _fail "--help should mention --timeout"
fi

if printf '%s' "$help_output" | grep -q "FeatureBench\|feature"; then
    _pass "--help mentions FeatureBench/feature"
else
    _fail "--help should mention FeatureBench"
fi

# ── Test 3: --dry-run produces cost estimate ─────────────────────
if [[ "$HAS_JQ" -eq 1 ]]; then
    dry_output="$(bash "$FEATUREBENCH" --dry-run --limit 1 2>&1)" || true
    if printf '%s' "$dry_output" | grep -q "Cost Estimate"; then
        _pass "--dry-run shows cost estimate"
    else
        _fail "--dry-run should show cost estimate"
    fi

    if printf '%s' "$dry_output" | grep -q "FeatureBench"; then
        _pass "--dry-run mentions FeatureBench"
    else
        _fail "--dry-run should mention FeatureBench"
    fi
else
    _skip "--dry-run tests (jq not installed)"
fi

# ── Test 4: Tasks file exists and is valid ───────────────────────
if [[ -f "$TASKS_FILE" ]]; then
    _pass "featurebench-tasks.jsonl exists"
else
    _fail "featurebench-tasks.jsonl missing"
fi

# Count tasks
task_count="$(grep -c '^{' "$TASKS_FILE" 2>/dev/null || echo 0)"
if [[ "$task_count" -ge 3 ]]; then
    _pass "at least 3 sample tasks ($task_count found)"
else
    _fail "need at least 3 sample tasks (got $task_count)"
fi

# Validate task JSON structure (each line should have required fields)
if [[ "$HAS_JQ" -eq 1 ]]; then
    valid_tasks=0
    invalid_tasks=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        has_id="$(printf '%s' "$line" | jq -r '.id // empty' 2>/dev/null)"
        has_name="$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)"
        has_diff="$(printf '%s' "$line" | jq -r '.difficulty // empty' 2>/dev/null)"
        has_criteria="$(printf '%s' "$line" | jq -r '.acceptance_criteria // empty' 2>/dev/null)"
        if [[ -n "$has_id" ]] && [[ -n "$has_name" ]] && [[ -n "$has_diff" ]] && [[ -n "$has_criteria" ]]; then
            valid_tasks=$(( valid_tasks + 1 ))
        else
            invalid_tasks=$(( invalid_tasks + 1 ))
        fi
    done < "$TASKS_FILE"

    if [[ "$valid_tasks" -ge 3 ]] && [[ "$invalid_tasks" -eq 0 ]]; then
        _pass "all tasks have required fields (id, name, difficulty, acceptance_criteria)"
    else
        _fail "task validation: $valid_tasks valid, $invalid_tasks invalid"
    fi

    # Check difficulty distribution
    easy_count="$(jq -r '.difficulty' "$TASKS_FILE" 2>/dev/null | grep -c "easy" || echo 0)"
    medium_count="$(jq -r '.difficulty' "$TASKS_FILE" 2>/dev/null | grep -c "medium" || echo 0)"
    hard_count="$(jq -r '.difficulty' "$TASKS_FILE" 2>/dev/null | grep -c "hard" || echo 0)"

    if [[ "$easy_count" -ge 1 ]] && [[ "$medium_count" -ge 1 ]] && [[ "$hard_count" -ge 1 ]]; then
        _pass "tasks include easy ($easy_count), medium ($medium_count), hard ($hard_count)"
    else
        _fail "tasks should include all difficulty levels"
    fi
else
    _skip "task JSON validation (jq not installed)"
fi

# ── Test 5: Input validation rejects bad values ──────────────────

# Bad limit (not a number)
bad_limit="$(bash "$FEATUREBENCH" --limit abc 2>&1)" && bad_limit_exit=0 || bad_limit_exit=$?
if [[ "$bad_limit_exit" -ne 0 ]] && printf '%s' "$bad_limit" | grep -qi "positive integer"; then
    _pass "rejects non-numeric --limit"
else
    _fail "should reject --limit abc"
fi

# Bad limit (zero)
bad_zero="$(bash "$FEATUREBENCH" --limit 0 2>&1)" && bad_zero_exit=0 || bad_zero_exit=$?
if [[ "$bad_zero_exit" -ne 0 ]]; then
    _pass "rejects --limit 0"
else
    _fail "should reject --limit 0"
fi

# Bad limit (negative)
bad_neg="$(bash "$FEATUREBENCH" --limit -5 2>&1)" && bad_neg_exit=0 || bad_neg_exit=$?
if [[ "$bad_neg_exit" -ne 0 ]]; then
    _pass "rejects --limit -5"
else
    _fail "should reject --limit -5"
fi

# Bad model
bad_model="$(bash "$FEATUREBENCH" --model gpt4 2>&1)" && bad_model_exit=0 || bad_model_exit=$?
if [[ "$bad_model_exit" -ne 0 ]] && printf '%s' "$bad_model" | grep -qi "invalid model"; then
    _pass "rejects invalid --model"
else
    _fail "should reject --model gpt4"
fi

# Bad agents
bad_agents="$(bash "$FEATUREBENCH" --agents 0 2>&1)" && bad_agents_exit=0 || bad_agents_exit=$?
if [[ "$bad_agents_exit" -ne 0 ]]; then
    _pass "rejects --agents 0"
else
    _fail "should reject --agents 0"
fi

# Bad timeout
bad_timeout="$(bash "$FEATUREBENCH" --timeout foo 2>&1)" && bad_timeout_exit=0 || bad_timeout_exit=$?
if [[ "$bad_timeout_exit" -ne 0 ]]; then
    _pass "rejects non-numeric --timeout"
else
    _fail "should reject --timeout foo"
fi

# Unknown flag
bad_flag="$(bash "$FEATUREBENCH" --banana 2>&1)" && bad_flag_exit=0 || bad_flag_exit=$?
if [[ "$bad_flag_exit" -ne 0 ]] && printf '%s' "$bad_flag" | grep -qi "unknown"; then
    _pass "rejects unknown flag"
else
    _fail "should reject --banana"
fi

# ── Test 6: Key functions exist in script ────────────────────────
script_content="$(cat "$FEATUREBENCH")"

if printf '%s' "$script_content" | grep -q '_load_tasks()'; then
    _pass "_load_tasks function defined"
else
    _fail "_load_tasks function missing"
fi

if printf '%s' "$script_content" | grep -q '_run_feature_tasks()'; then
    _pass "_run_feature_tasks function defined"
else
    _fail "_run_feature_tasks function missing"
fi

if printf '%s' "$script_content" | grep -q '_evaluate_results()'; then
    _pass "_evaluate_results function defined"
else
    _fail "_evaluate_results function missing"
fi

if printf '%s' "$script_content" | grep -q '_generate_report()'; then
    _pass "_generate_report function defined"
else
    _fail "_generate_report function missing"
fi

if printf '%s' "$script_content" | grep -q '_dry_run()'; then
    _pass "_dry_run function defined"
else
    _fail "_dry_run function missing"
fi

if printf '%s' "$script_content" | grep -q '_check_deps()'; then
    _pass "_check_deps function defined"
else
    _fail "_check_deps function missing"
fi

# ── Test 7: Security patterns ────────────────────────────────────
if printf '%s' "$script_content" | grep -q '_validate_positive_int'; then
    _pass "uses _validate_positive_int for input validation"
else
    _fail "missing _validate_positive_int"
fi

if printf '%s' "$script_content" | grep -q '_validate_model'; then
    _pass "uses _validate_model for model validation"
else
    _fail "missing _validate_model"
fi

if printf '%s' "$script_content" | grep -q 'a-zA-Z0-9_\.'; then
    _pass "validates task IDs with regex"
else
    _fail "missing task ID validation regex"
fi

if printf '%s' "$script_content" | grep -q 'mktemp'; then
    _pass "uses mktemp for temp files"
else
    _fail "should use mktemp for temp files"
fi

# ── Test 8: Script structure ─────────────────────────────────────
if head -1 "$FEATUREBENCH" | grep -q '#!/usr/bin/env bash'; then
    _pass "correct shebang"
else
    _fail "wrong shebang (expected #!/usr/bin/env bash)"
fi

if head -15 "$FEATUREBENCH" | grep -q 'set -euo pipefail'; then
    _pass "set -euo pipefail enabled"
else
    _fail "missing set -euo pipefail"
fi

if printf '%s' "$script_content" | grep -q 'source.*instance-runner.sh'; then
    _pass "sources instance-runner.sh"
else
    _fail "should source instance-runner.sh"
fi

if printf '%s' "$script_content" | grep -q 'source.*results-collector.sh'; then
    _pass "sources results-collector.sh"
else
    _fail "should source results-collector.sh"
fi

if printf '%s' "$script_content" | grep -q 'source.*cost-estimator.sh'; then
    _pass "sources cost-estimator.sh"
else
    _fail "should source cost-estimator.sh"
fi

if printf '%s' "$script_content" | grep -q 'main "\$@"'; then
    _pass "main \"\$@\" entry point"
else
    _fail "missing main \"\$@\" entry point"
fi

# ── Summary ──────────────────────────────────────────────────────
printf '\nfeaturebench: %d passed, %d failed, %d skipped\n' "$PASSED" "$FAILED" "$SKIPPED"
[[ "$FAILED" -eq 0 ]] || exit 1
