#!/usr/bin/env bash
# quality-scorer.sh — Multi-dimensional quality scoring for agent output
# Scores agent work on: lint (25%), tests (25%), diff quality (20%), output quality (15%), ownership (15%)
# Records scores to .orchystraw/quality-scores.jsonl

_ORCH_QUALITY_SCORER_LOADED=1

# Detected linters (populated by orch_scorer_init)
declare -gA _SCORER_LINTERS=()
_SCORER_PROJECT_ROOT="${PROJECT_ROOT:-}"

# ── orch_scorer_init ────────────────────────────────────────────────────
# Detect available linters in the environment.
orch_scorer_init() {
    _SCORER_PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
    _SCORER_LINTERS=()

    if command -v eslint &>/dev/null; then
        _SCORER_LINTERS[eslint]=1
    fi
    if command -v pylint &>/dev/null; then
        _SCORER_LINTERS[pylint]=1
    fi
    if command -v shellcheck &>/dev/null; then
        _SCORER_LINTERS[shellcheck]=1
    fi
    if command -v swiftlint &>/dev/null; then
        _SCORER_LINTERS[swiftlint]=1
    fi

    mkdir -p "$_SCORER_PROJECT_ROOT/.orchystraw"
}

# ── orch_scorer_lint ────────────────────────────────────────────────────
# Lint changed files for an agent. Returns score 0-100.
# Args: $1 = agent_id
orch_scorer_lint() {
    local agent_id="$1"
    local score=100
    local changed_files
    changed_files=$(git -C "$_SCORER_PROJECT_ROOT" diff --name-only HEAD~1 2>/dev/null || echo "")

    if [[ -z "$changed_files" ]]; then
        echo "100"
        return 0
    fi

    local total_files=0
    local lint_errors=0

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$_SCORER_PROJECT_ROOT/$file" ]] && continue
        total_files=$((total_files + 1))

        local ext="${file##*.}"
        case "$ext" in
            js|jsx|ts|tsx)
                if [[ -n "${_SCORER_LINTERS[eslint]:-}" ]]; then
                    local errs
                    errs=$(eslint "$_SCORER_PROJECT_ROOT/$file" --format compact 2>/dev/null | grep -c "Error" || echo 0)
                    lint_errors=$((lint_errors + errs))
                fi
                ;;
            py)
                if [[ -n "${_SCORER_LINTERS[pylint]:-}" ]]; then
                    local errs
                    errs=$(pylint "$_SCORER_PROJECT_ROOT/$file" --score=n 2>/dev/null | grep -cE "^[CEFW]:" || echo 0)
                    lint_errors=$((lint_errors + errs))
                fi
                ;;
            sh|bash)
                if [[ -n "${_SCORER_LINTERS[shellcheck]:-}" ]]; then
                    local errs
                    errs=$(shellcheck "$_SCORER_PROJECT_ROOT/$file" 2>/dev/null | grep -c "^In " || echo 0)
                    lint_errors=$((lint_errors + errs))
                fi
                ;;
            swift)
                if [[ -n "${_SCORER_LINTERS[swiftlint]:-}" ]]; then
                    local errs
                    errs=$(swiftlint lint --path "$_SCORER_PROJECT_ROOT/$file" --quiet 2>/dev/null | grep -c "error:" || echo 0)
                    lint_errors=$((lint_errors + errs))
                fi
                ;;
        esac
    done <<< "$changed_files"

    if [[ "$total_files" -gt 0 ]]; then
        # Deduct 10 points per lint error, floor at 0
        local deduction=$((lint_errors * 10))
        score=$((100 - deduction))
        [[ "$score" -lt 0 ]] && score=0
    fi

    echo "$score"
}

# ── orch_scorer_tests ───────────────────────────────────────────────────
# Run project test suite and return score 0-100.
orch_scorer_tests() {
    local score=100

    # Try project tests first, fallback to ORCH_ROOT tests
    local test_runner=""
    if [[ -x "$_SCORER_PROJECT_ROOT/tests/core/run-tests.sh" ]]; then
        test_runner="$_SCORER_PROJECT_ROOT/tests/core/run-tests.sh"
    elif [[ -n "${ORCH_ROOT:-}" && -x "$ORCH_ROOT/tests/core/run-tests.sh" ]]; then
        test_runner="$ORCH_ROOT/tests/core/run-tests.sh"
    fi

    if [[ -n "$test_runner" ]]; then
        local test_output
        test_output=$(/opt/homebrew/bin/bash "$test_runner" 2>&1) || true
        local pass_count fail_count
        pass_count=$(echo "$test_output" | grep -c "PASS" 2>/dev/null || echo 0)
        fail_count=$(echo "$test_output" | grep -c "FAIL" 2>/dev/null || echo 0)
        local total=$((pass_count + fail_count))

        if [[ "$total" -gt 0 ]]; then
            score=$(( (pass_count * 100) / total ))
        fi
    else
        # No test runner available — neutral score
        score=50
    fi

    echo "$score"
}

# ── orch_scorer_diff_quality ────────────────────────────────────────────
# Analyze git diff quality. Returns score 0-100.
# Penalizes: huge diffs, too many files, generated/binary content.
# Args: $1 = agent_id
orch_scorer_diff_quality() {
    local agent_id="$1"
    local score=100

    local diff_stat
    diff_stat=$(git -C "$_SCORER_PROJECT_ROOT" diff --stat HEAD~1 2>/dev/null || echo "")

    if [[ -z "$diff_stat" ]]; then
        echo "50"  # No diff — neutral
        return 0
    fi

    # Count lines changed
    local insertions deletions files_changed
    insertions=$(git -C "$_SCORER_PROJECT_ROOT" diff --numstat HEAD~1 2>/dev/null | awk '{s+=$1} END{print s+0}')
    deletions=$(git -C "$_SCORER_PROJECT_ROOT" diff --numstat HEAD~1 2>/dev/null | awk '{s+=$2} END{print s+0}')
    files_changed=$(git -C "$_SCORER_PROJECT_ROOT" diff --name-only HEAD~1 2>/dev/null | wc -l | tr -d ' ')

    local total_loc=$((insertions + deletions))

    # Penalize oversized diffs (>2000 LOC = likely generated)
    if [[ "$total_loc" -gt 2000 ]]; then
        score=$((score - 20))
    elif [[ "$total_loc" -gt 5000 ]]; then
        score=$((score - 40))
    fi

    # Penalize too many files (>20 files = shotgun commit)
    if [[ "$files_changed" -gt 20 ]]; then
        score=$((score - 15))
    elif [[ "$files_changed" -gt 50 ]]; then
        score=$((score - 30))
    fi

    # Bonus for balanced insertions/deletions (refactoring, not just adding)
    if [[ "$total_loc" -gt 0 && "$deletions" -gt 0 ]]; then
        local ratio=$((insertions * 100 / (insertions + deletions)))
        # Perfect ratio is 50/50 for refactoring. Slightly penalize pure additions.
        if [[ "$ratio" -gt 30 && "$ratio" -lt 70 ]]; then
            score=$((score + 5))
        fi
    fi

    # Check for binary/generated files
    local binary_count
    binary_count=$(git -C "$_SCORER_PROJECT_ROOT" diff --name-only HEAD~1 2>/dev/null | grep -cE '\.(png|jpg|svg|woff|ttf|lock)$' || echo 0)
    if [[ "$binary_count" -gt 3 ]]; then
        score=$((score - 10))
    fi

    [[ "$score" -lt 0 ]] && score=0
    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# ── orch_scorer_output_quality ──────────────────────────────────────────
# Score agent output log quality. Returns 0-100.
# Args: $1 = agent_id
orch_scorer_output_quality() {
    local agent_id="$1"
    local score=50  # Default neutral

    local log_dir
    if [[ -n "${AGENT_PROMPTS[$agent_id]:-}" ]]; then
        log_dir="$(dirname "$_SCORER_PROJECT_ROOT/${AGENT_PROMPTS[$agent_id]}")/logs"
    else
        echo "$score"
        return 0
    fi

    local latest_log
    latest_log=$(ls -t "$log_dir/${agent_id}-"*.log 2>/dev/null | head -1)
    if [[ -z "$latest_log" || ! -f "$latest_log" ]]; then
        echo "$score"
        return 0
    fi

    local log_size
    log_size=$(wc -c < "$latest_log" | tr -d ' ')

    # Tiny output = likely failed
    if [[ "$log_size" -lt 100 ]]; then
        score=10
    elif [[ "$log_size" -lt 500 ]]; then
        score=30
    elif [[ "$log_size" -gt 1000 ]]; then
        score=70
    fi

    # Check for error indicators
    local error_count
    error_count=$(grep -ciE "error|exception|fatal|panic" "$latest_log" 2>/dev/null || echo 0)
    if [[ "$error_count" -gt 5 ]]; then
        score=$((score - 20))
    elif [[ "$error_count" -gt 0 ]]; then
        score=$((score - 10))
    fi

    # Check for success indicators
    local success_count
    success_count=$(grep -ciE "completed|success|done|finished" "$latest_log" 2>/dev/null || echo 0)
    if [[ "$success_count" -gt 0 ]]; then
        score=$((score + 15))
    fi

    [[ "$score" -lt 0 ]] && score=0
    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# ── orch_scorer_ownership ───────────────────────────────────────────────
# Score whether agent stayed within ownership boundaries. Returns 0-100.
# Args: $1 = agent_id
orch_scorer_ownership() {
    local agent_id="$1"
    local score=100

    local ownership="${AGENT_OWNERSHIP[$agent_id]:-}"
    if [[ -z "$ownership" || "$ownership" == "none" ]]; then
        echo "100"
        return 0
    fi

    # Parse ownership paths
    local -a include_paths=()
    IFS=' ' read -ra _own_arr <<< "$ownership"
    for path in "${_own_arr[@]}"; do
        [[ "$path" == !* ]] && continue
        include_paths+=("$path")
    done

    # Check changed files against ownership
    local changed_files
    changed_files=$(git -C "$_SCORER_PROJECT_ROOT" diff --name-only HEAD~1 2>/dev/null || echo "")

    if [[ -z "$changed_files" ]]; then
        echo "100"
        return 0
    fi

    local total=0
    local outside=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        total=$((total + 1))
        local in_ownership=false
        for path in "${include_paths[@]}"; do
            if [[ "$file" == ${path}* ]]; then
                in_ownership=true
                break
            fi
        done
        if [[ "$in_ownership" == false ]]; then
            outside=$((outside + 1))
        fi
    done <<< "$changed_files"

    if [[ "$total" -gt 0 ]]; then
        local pct_outside=$(( (outside * 100) / total ))
        score=$((100 - pct_outside))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# ── orch_scorer_run ─────────────────────────────────────────────────────
# Run all scoring dimensions and return composite score 0-100.
# Weights: lint 25%, tests 25%, diff quality 20%, output quality 15%, ownership 15%
# Args: $1 = agent_id
orch_scorer_run() {
    local agent_id="$1"

    local lint_score test_score diff_score output_score own_score
    lint_score=$(orch_scorer_lint "$agent_id" 2>/dev/null || echo 50)
    test_score=$(orch_scorer_tests 2>/dev/null || echo 50)
    diff_score=$(orch_scorer_diff_quality "$agent_id" 2>/dev/null || echo 50)
    output_score=$(orch_scorer_output_quality "$agent_id" 2>/dev/null || echo 50)
    own_score=$(orch_scorer_ownership "$agent_id" 2>/dev/null || echo 100)

    # Weighted composite
    local composite=$(( (lint_score * 25 + test_score * 25 + diff_score * 20 + output_score * 15 + own_score * 15) / 100 ))

    [[ "$composite" -lt 0 ]] && composite=0
    [[ "$composite" -gt 100 ]] && composite=100

    echo "$composite"
}

# ── orch_scorer_record ──────────────────────────────────────────────────
# Write score to .orchystraw/quality-scores.jsonl
# Args: $1 = agent_id, $2 = composite score
orch_scorer_record() {
    local agent_id="$1"
    local score="$2"
    local ts
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    local cycle="${CYCLE:-0}"

    local scores_file="$_SCORER_PROJECT_ROOT/.orchystraw/quality-scores.jsonl"
    mkdir -p "$_SCORER_PROJECT_ROOT/.orchystraw"

    echo "{\"agent\":\"$agent_id\",\"score\":$score,\"cycle\":$cycle,\"ts\":\"$ts\"}" >> "$scores_file"
}

# ── orch_scorer_get_recent ──────────────────────────────────────────────
# Get recent scores for an agent.
# Args: $1 = agent_id, $2 = count (default 5)
orch_scorer_get_recent() {
    local agent_id="$1"
    local count="${2:-5}"
    local scores_file="$_SCORER_PROJECT_ROOT/.orchystraw/quality-scores.jsonl"

    if [[ ! -f "$scores_file" ]]; then
        return 0
    fi

    grep "\"agent\":\"$agent_id\"" "$scores_file" | tail -"$count"
}

# ── orch_scorer_get_average ─────────────────────────────────────────────
# Get average score for an agent across recent runs.
# Args: $1 = agent_id, $2 = count (default 10)
orch_scorer_get_average() {
    local agent_id="$1"
    local count="${2:-10}"
    local scores_file="$_SCORER_PROJECT_ROOT/.orchystraw/quality-scores.jsonl"

    if [[ ! -f "$scores_file" ]]; then
        echo "0"
        return 0
    fi

    local sum=0
    local n=0
    while IFS= read -r line; do
        local s
        s=$(echo "$line" | grep -o '"score":[0-9]*' | grep -o '[0-9]*')
        if [[ -n "$s" ]]; then
            sum=$((sum + s))
            n=$((n + 1))
        fi
    done <<< "$(grep "\"agent\":\"$agent_id\"" "$scores_file" | tail -"$count")"

    if [[ "$n" -gt 0 ]]; then
        echo $(( sum / n ))
    else
        echo "0"
    fi
}
