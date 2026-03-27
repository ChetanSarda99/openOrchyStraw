#!/usr/bin/env bash
# ============================================
# OrchyStraw — SWE-bench Lite Benchmark Harness
# ============================================
#
# Runs OrchyStraw on SWE-bench Lite tasks and evaluates results.
#
# Usage:
#   ./scripts/benchmark/run-swebench.sh                  # Run all tasks
#   ./scripts/benchmark/run-swebench.sh --task <id>      # Run single task
#   ./scripts/benchmark/run-swebench.sh --list            # List available tasks
#   ./scripts/benchmark/run-swebench.sh --sample          # Run 1 sample task (smoke test)
#
# Requirements:
#   - git, jq, python3 (for SWE-bench eval)
#   - claude CLI available on PATH
#
# Output:
#   logs/benchmark/          — Per-task logs
#   logs/benchmark/results/  — JSON results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASKS_DIR="$SCRIPT_DIR/tasks"
WORKDIR="$PROJECT_ROOT/logs/benchmark/workspaces"
RESULTS_DIR="$PROJECT_ROOT/logs/benchmark/results"
LOG_DIR="$PROJECT_ROOT/logs/benchmark"

# ── Helpers ──────────────────────────────────────────────────────────────
_log()  { printf '[swebench] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err()  { _log "ERROR: $*" >&2; }
_die()  { _err "$*"; exit 1; }

_check_deps() {
    local missing=()
    for cmd in git jq python3 claude; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _die "missing dependencies: ${missing[*]}"
    fi
}

# ── Task format ──────────────────────────────────────────────────────────
# Each task is a JSON file in tasks/ with:
#   {
#     "instance_id":  "repo__issue_number",
#     "repo":         "owner/repo",
#     "base_commit":  "abc123",
#     "problem_statement": "...",
#     "test_patch":   "diff to apply for evaluation",
#     "gold_patch":   "reference fix (for scoring only)"
#   }

_list_tasks() {
    if [[ ! -d "$TASKS_DIR" ]] || [[ -z "$(ls "$TASKS_DIR"/*.json 2>/dev/null)" ]]; then
        _log "no tasks found in $TASKS_DIR"
        return 0
    fi
    for f in "$TASKS_DIR"/*.json; do
        local id repo
        id="$(jq -r '.instance_id' "$f")"
        repo="$(jq -r '.repo' "$f")"
        printf '  %-40s  %s\n' "$id" "$repo"
    done
}

_validate_repo() {
    local repo="$1"
    if [[ ! "$repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        _die "invalid repo format: '$repo' — must match owner/repo with safe characters only"
    fi
}

_validate_patch() {
    local patch="$1" label="$2"
    [[ -z "$patch" ]] && return 0
    # Reject patches containing shell metacharacters in exec/run directives
    if printf '%s' "$patch" | grep -qE '(--exec|;\s*[a-z]|`|\$\(|&&|\|\|)'; then
        _die "$label contains unsafe content (--exec, shell metacharacters, or command substitution)"
    fi
    # Reject paths that escape the workspace (directory traversal)
    if printf '%s' "$patch" | grep -qE '^\+\+\+ [ab]/\.\./'; then
        _die "$label contains directory traversal (../)"
    fi
}

_load_task() {
    local task_file="$1"
    [[ -f "$task_file" ]] || _die "task file not found: $task_file"

    TASK_ID="$(jq -r '.instance_id' "$task_file")"
    TASK_REPO="$(jq -r '.repo' "$task_file")"
    TASK_COMMIT="$(jq -r '.base_commit' "$task_file")"
    TASK_PROBLEM="$(jq -r '.problem_statement' "$task_file")"
    TASK_TEST_PATCH="$(jq -r '.test_patch // empty' "$task_file")"
    TASK_GOLD_PATCH="$(jq -r '.gold_patch // empty' "$task_file")"

    # CRITICAL-02: Validate repo format to prevent URL injection
    _validate_repo "$TASK_REPO"
    # HIGH-01: Validate patch content to prevent command injection via git apply
    _validate_patch "$TASK_TEST_PATCH" "test_patch"
    _validate_patch "$TASK_GOLD_PATCH" "gold_patch"
}

# ── Core: run one task ───────────────────────────────────────────────────
_run_task() {
    local task_file="$1"
    _load_task "$task_file"

    _log "── task: $TASK_ID ──"
    _log "repo: $TASK_REPO  commit: ${TASK_COMMIT:0:10}"

    local workspace="$WORKDIR/$TASK_ID"
    local task_log="$LOG_DIR/${TASK_ID}.log"
    local result_file="$RESULTS_DIR/${TASK_ID}.json"

    mkdir -p "$WORKDIR" "$RESULTS_DIR" "$LOG_DIR"

    # Step 1: Clone and checkout
    if [[ -d "$workspace" ]]; then
        _log "workspace exists, resetting..."
        (cd "$workspace" && git checkout -f "$TASK_COMMIT" 2>/dev/null) || {
            rm -rf "$workspace"
        }
    fi
    if [[ ! -d "$workspace" ]]; then
        _log "cloning https://github.com/$TASK_REPO..."
        git clone --quiet "https://github.com/$TASK_REPO.git" "$workspace" 2>>"$task_log" || {
            _write_result "$result_file" "$TASK_ID" "error" "clone_failed" 0
            return 1
        }
    fi
    (cd "$workspace" && git checkout -f "$TASK_COMMIT" 2>/dev/null) || {
        _write_result "$result_file" "$TASK_ID" "error" "checkout_failed" 0
        return 1
    }

    # Step 2: Build the prompt for OrchyStraw
    local agent_prompt
    agent_prompt="$(_build_prompt "$TASK_PROBLEM" "$workspace")"

    # Step 3: Run OrchyStraw (single-agent mode or direct claude)
    _log "running agent on task..."
    local start_time end_time duration agent_exit=0
    start_time="$(date +%s)"

    (cd "$workspace" && claude -p "$agent_prompt" --output-format text) \
        >"$task_log.agent-output" 2>&1 || agent_exit=$?

    end_time="$(date +%s)"
    duration=$(( end_time - start_time ))
    _log "agent finished in ${duration}s (exit: $agent_exit)"

    # Step 4: Capture the diff (what the agent changed)
    local agent_diff
    agent_diff="$(cd "$workspace" && git diff 2>/dev/null || true)"

    # Step 5: Evaluate — apply test patch and run tests
    local eval_status="unknown"
    local tests_passed=0

    if [[ -n "$TASK_TEST_PATCH" ]]; then
        eval_status="$(_evaluate_task "$workspace" "$TASK_TEST_PATCH")"
        [[ "$eval_status" == "pass" ]] && tests_passed=1
    else
        # No test patch — check if agent produced any diff
        if [[ -n "$agent_diff" ]]; then
            eval_status="diff_produced"
        else
            eval_status="no_changes"
        fi
    fi

    # Step 6: Score against gold patch (if available)
    local patch_match=0
    if [[ -n "$TASK_GOLD_PATCH" ]] && [[ -n "$agent_diff" ]]; then
        patch_match="$(_compare_patches "$agent_diff" "$TASK_GOLD_PATCH")"
    fi

    # Step 7: Write result
    _write_result "$result_file" "$TASK_ID" "$eval_status" "$agent_exit" "$duration" \
        "$tests_passed" "$patch_match" "$agent_diff"

    _log "result: $eval_status (tests=$tests_passed, patch_match=$patch_match, ${duration}s)"
    _log "── done: $TASK_ID ──"
}

_build_prompt() {
    local problem="$1"
    local workspace="$2"
    cat <<PROMPT
You are a software engineer fixing a bug in an open-source project.

## Problem Statement
$problem

## Instructions
1. Read the problem statement carefully.
2. Explore the codebase to understand the relevant code.
3. Implement a fix for the described issue.
4. Make minimal, focused changes — fix the bug, nothing else.
5. Do NOT run tests yourself — the harness will evaluate your changes.
6. Do NOT commit — just leave your changes as unstaged modifications.

Working directory: $workspace
PROMPT
}

_evaluate_task() {
    local workspace="$1"
    local test_patch="$2"

    # Apply the test patch (adds/modifies test files to verify the fix)
    if ! (cd "$workspace" && echo "$test_patch" | git apply --allow-empty 2>/dev/null); then
        echo "test_patch_failed"
        return 0
    fi

    # Try to run tests (heuristic: look for common test runners)
    local test_exit=0
    if [[ -f "$workspace/pytest.ini" ]] || [[ -f "$workspace/setup.py" ]] || [[ -f "$workspace/pyproject.toml" ]]; then
        (cd "$workspace" && python3 -m pytest --tb=short -q 2>/dev/null) || test_exit=$?
    elif [[ -f "$workspace/package.json" ]]; then
        (cd "$workspace" && npm test 2>/dev/null) || test_exit=$?
    else
        echo "no_test_runner"
        return 0
    fi

    if [[ "$test_exit" -eq 0 ]]; then
        echo "pass"
    else
        echo "fail"
    fi
}

_compare_patches() {
    local agent_diff="$1"
    local gold_patch="$2"

    # Simple heuristic: check if the same files were modified
    local agent_files gold_files
    agent_files="$(echo "$agent_diff" | grep '^diff --git' | sort)"
    gold_files="$(echo "$gold_patch" | grep '^diff --git' | sort)"

    if [[ "$agent_files" == "$gold_files" ]]; then
        echo 1
    else
        echo 0
    fi
}

_write_result() {
    local file="$1" id="$2" status="$3" exit_code="${4:-0}" duration="${5:-0}"
    local tests_passed="${6:-0}" patch_match="${7:-0}" diff="${8:-}"

    jq -n \
        --arg id "$id" \
        --arg status "$status" \
        --arg exit_code "$exit_code" \
        --arg duration "$duration" \
        --arg tests_passed "$tests_passed" \
        --arg patch_match "$patch_match" \
        --arg diff "$diff" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            instance_id: $id,
            status: $status,
            agent_exit_code: ($exit_code | tonumber),
            duration_seconds: ($duration | tonumber),
            tests_passed: ($tests_passed | tonumber),
            patch_match: ($patch_match | tonumber),
            timestamp: $timestamp,
            diff_length: ($diff | length)
        }' > "$file"
}

# ── Dry-run validation ────────────────────────────────────────────────────
_validate_task_json() {
    local task_file="$1"
    [[ -f "$task_file" ]] || { _err "file not found: $task_file"; return 1; }

    # Validate JSON structure
    if ! jq empty "$task_file" 2>/dev/null; then
        _err "invalid JSON: $task_file"
        return 1
    fi

    # Check required fields
    local missing=()
    for field in instance_id repo base_commit problem_statement; do
        local val
        val="$(jq -r ".$field // empty" "$task_file")"
        if [[ -z "$val" ]]; then
            missing+=("$field")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        _err "$task_file: missing required fields: ${missing[*]}"
        return 1
    fi
    return 0
}

_dry_run_task() {
    local task_file="$1"
    if ! _validate_task_json "$task_file"; then
        return 1
    fi

    local id repo commit problem
    id="$(jq -r '.instance_id' "$task_file")"
    repo="$(jq -r '.repo' "$task_file")"
    commit="$(jq -r '.base_commit' "$task_file")"
    problem="$(jq -r '.problem_statement' "$task_file" | head -1)"
    local has_test has_gold
    has_test="$(jq -r 'if (.test_patch // "") == "" then "no" else "yes" end' "$task_file")"
    has_gold="$(jq -r 'if (.gold_patch // "") == "" then "no" else "yes" end' "$task_file")"

    printf '  %-40s  %-25s  %s\n' "$id" "$repo" "${commit:0:10}"
    printf '    problem:    %s\n' "$problem"
    printf '    test_patch: %s  gold_patch: %s\n' "$has_test" "$has_gold"
    printf '    would:      clone → checkout %s → run agent → evaluate\n' "${commit:0:10}"
}

_dry_run_all() {
    local task_files=("$@")
    local valid=0 invalid=0

    _log "dry-run: validating ${#task_files[@]} task(s)"
    printf '\n'
    for f in "${task_files[@]}"; do
        if _dry_run_task "$f"; then
            valid=$(( valid + 1 ))
        else
            invalid=$(( invalid + 1 ))
        fi
        printf '\n'
    done
    _log "dry-run complete: $valid valid, $invalid invalid"
}

# ── Report ────────────────────────────────────────────────────────────────
_report() {
    local summary="$RESULTS_DIR/summary.json"
    if [[ ! -f "$summary" ]]; then
        _die "no summary found at $summary — run benchmark first"
    fi

    local total passed failed errors resolve_rate ts
    total="$(jq -r '.total' "$summary")"
    passed="$(jq -r '.passed' "$summary")"
    failed="$(jq -r '.failed' "$summary")"
    errors="$(jq -r '.errors' "$summary")"
    resolve_rate="$(jq -r '.resolve_rate' "$summary")"
    ts="$(jq -r '.timestamp' "$summary")"

    printf '\n'
    printf '╔══════════════════════════════════════════════════════════════╗\n'
    printf '║  SWE-bench Benchmark Results  %-30s║\n' "$ts"
    printf '╠══════════════════════════════════════════════════════════════╣\n'
    printf '║  Total: %-5s  Passed: %-5s  Failed: %-5s  Errors: %-5s  ║\n' \
        "$total" "$passed" "$failed" "$errors"
    printf '║  Resolve Rate: %-5s%%                                       ║\n' "$resolve_rate"
    printf '╠══════════════════════════════════════════════════════════════╣\n'
    printf '║  %-30s %-10s %-8s %-6s ║\n' "INSTANCE" "STATUS" "TIME(s)" "MATCH"
    printf '╠══════════════════════════════════════════════════════════════╣\n'

    for f in "$RESULTS_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        [[ "$(basename "$f")" == "summary.json" ]] && continue
        local rid rstatus rdur rmatch
        rid="$(jq -r '.instance_id' "$f")"
        rstatus="$(jq -r '.status' "$f")"
        rdur="$(jq -r '.duration_seconds' "$f")"
        rmatch="$(jq -r '.patch_match' "$f")"
        printf '║  %-30s %-10s %-8s %-6s ║\n' \
            "${rid:0:30}" "$rstatus" "$rdur" "$rmatch"
    done

    printf '╚══════════════════════════════════════════════════════════════╝\n'
    printf '\n'
}

# ── Aggregator ───────────────────────────────────────────────────────────
_aggregate_results() {
    _log "── aggregate results ──"
    local total=0 passed=0 failed=0 errors=0

    for f in "$RESULTS_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        total=$(( total + 1 ))
        local status
        status="$(jq -r '.status' "$f")"
        case "$status" in
            pass)  passed=$(( passed + 1 )) ;;
            fail|no_changes) failed=$(( failed + 1 )) ;;
            *)     errors=$(( errors + 1 )) ;;
        esac
    done

    _log "total=$total  passed=$passed  failed=$failed  errors=$errors"

    if [[ "$total" -gt 0 ]]; then
        local pct=$(( (passed * 100) / total ))
        _log "resolve rate: ${pct}% ($passed/$total)"
    fi

    # Write summary
    jq -n \
        --arg total "$total" \
        --arg passed "$passed" \
        --arg failed "$failed" \
        --arg errors "$errors" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            total: ($total | tonumber),
            passed: ($passed | tonumber),
            failed: ($failed | tonumber),
            errors: ($errors | tonumber),
            resolve_rate: (if ($total | tonumber) > 0 then (($passed | tonumber) * 100 / ($total | tonumber)) else 0 end),
            timestamp: $timestamp
        }' > "$RESULTS_DIR/summary.json"

    _log "summary written to $RESULTS_DIR/summary.json"
}

# ── Main ─────────────────────────────────────────────────────────────────
main() {
    local mode="all"
    local task_id=""
    local dry_run=0
    local parallel=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task)     mode="single"; task_id="$2"; shift 2 ;;
            --list)     mode="list"; shift ;;
            --sample)   mode="sample"; shift ;;
            --dry-run)  dry_run=1; shift ;;
            --parallel) parallel="$2"; shift 2 ;;
            --report)   mode="report"; shift ;;
            --help|-h)  _usage; exit 0 ;;
            *) _die "unknown arg: $1" ;;
        esac
    done

    # --report doesn't need dep check
    if [[ "$mode" == "report" ]]; then
        _report
        return 0
    fi

    _check_deps

    # Validate --parallel value
    if [[ "$parallel" -gt 0 ]] 2>/dev/null; then
        :
    elif [[ "$parallel" != "0" ]]; then
        _die "--parallel requires a positive integer"
    fi

    case "$mode" in
        list)
            _log "available tasks:"
            _list_tasks
            ;;
        single)
            [[ -n "$task_id" ]] || _die "--task requires a task ID"
            local task_file="$TASKS_DIR/${task_id}.json"
            if [[ "$dry_run" -eq 1 ]]; then
                _dry_run_all "$task_file"
            else
                _run_task "$task_file"
                _aggregate_results
            fi
            ;;
        sample)
            local sample="$TASKS_DIR/sample__django-11099.json"
            if [[ ! -f "$sample" ]]; then
                _die "sample task not found: $sample (run from project root)"
            fi
            if [[ "$dry_run" -eq 1 ]]; then
                _dry_run_all "$sample"
            else
                _run_task "$sample"
                _aggregate_results
            fi
            ;;
        all)
            if [[ ! -d "$TASKS_DIR" ]] || [[ -z "$(ls "$TASKS_DIR"/*.json 2>/dev/null)" ]]; then
                _die "no tasks in $TASKS_DIR — add .json task files or use --sample"
            fi

            local task_files=()
            for f in "$TASKS_DIR"/*.json; do
                task_files+=("$f")
            done

            if [[ "$dry_run" -eq 1 ]]; then
                _dry_run_all "${task_files[@]}"
                return 0
            fi

            if [[ "$parallel" -gt 0 ]]; then
                # Parallel execution with job slot limiter
                _log "running ${#task_files[@]} tasks with parallelism=$parallel"
                local running=0
                local pids=()
                for f in "${task_files[@]}"; do
                    _run_task "$f" &
                    pids+=($!)
                    running=$(( running + 1 ))
                    if [[ "$running" -ge "$parallel" ]]; then
                        # Wait for at least one job to finish
                        wait -n 2>/dev/null || true
                        running=$(( running - 1 ))
                    fi
                done
                # Wait for all remaining jobs
                for pid in "${pids[@]}"; do
                    wait "$pid" 2>/dev/null || true
                done
            else
                # Sequential execution
                for f in "${task_files[@]}"; do
                    _run_task "$f" || true
                done
            fi
            _aggregate_results
            ;;
    esac
}

_usage() {
    cat <<'EOF'
Usage: run-swebench.sh [OPTIONS]

Options:
  --task <id>       Run a single task by instance ID
  --list            List available tasks
  --sample          Run 1 sample task (smoke test)
  --dry-run         Validate task JSON and print plan without executing
  --parallel N      Run up to N tasks concurrently (default: sequential)
  --report          Print formatted results table from last run
  --help            Show this help

Tasks are JSON files in scripts/benchmark/tasks/.
Results go to logs/benchmark/results/.
EOF
}

main "$@"
