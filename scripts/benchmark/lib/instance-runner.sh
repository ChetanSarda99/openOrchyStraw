#!/usr/bin/env bash
# Instance Runner — runs one benchmark instance end-to-end
# Called by run-benchmark.sh with instance JSON on stdin or as arg
#
# Input: Instance JSON (id, repo_url, commit, issue_text, test_command)
# Output: Result JSON to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$BENCH_DIR/../.." && pwd)"

ORCHESTRATOR="$PROJECT_ROOT/scripts/auto-agent.sh"

_log() { printf '[instance] %s  %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
_err() { _log "ERROR: $*"; }

_validate_repo_url() {
    local url="$1"
    if [[ "$url" == *".."* ]]; then
        _err "repo URL contains path traversal: '$url'"; return 1
    fi
    if [[ ! "$url" =~ ^https://github\.com/[a-zA-Z0-9][a-zA-Z0-9_.-]*/[a-zA-Z0-9][a-zA-Z0-9_.-]*(\.git)?$ ]]; then
        _err "invalid repo URL: '$url'"; return 1
    fi
}

_validate_patch() {
    local patch="$1" label="$2"
    [[ -z "$patch" ]] && return 0
    if printf '%s' "$patch" | grep -qE '(--exec|;\s*[a-z]|`|\$\(|&&|\|\|)'; then
        _err "$label contains unsafe content"; return 1
    fi
}

_validate_test_command() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return 1

    if printf '%s' "$cmd" | grep -qE '[;|&`$><]|\$\(|#'; then
        _err "test_command contains shell metacharacters: '$cmd'"; return 1
    fi

    local -a allowed_exact=(
        "pytest" "tox" "nox"
        "make test" "make check"
        "npm test" "npm run test"
    )
    local -a allowed_prefixes=(
        "pytest " "python -m pytest " "python -m unittest "
        "python3 -m pytest " "python3 -m unittest "
        "cargo test " "go test "
        "npx jest " "npx vitest " "npx mocha "
    )
    local item
    for item in "${allowed_exact[@]}"; do
        [[ "$cmd" == "$item" ]] && return 0
    done
    for item in "${allowed_prefixes[@]}"; do
        [[ "$cmd" == "$item"* ]] && return 0
    done

    _err "test_command not in whitelist: '$cmd'"; return 1
}

run_instance() {
    local instance_file="${1:--}"
    local workspace_base="${2:-${TMPDIR:-/tmp}/orchystraw-bench}"
    local model="${3:-sonnet}"
    local max_cycles="${4:-5}"
    local timeout="${5:-600}"

    local instance_json
    if [[ "$instance_file" == "-" ]]; then
        instance_json="$(cat)"
    else
        instance_json="$(cat "$instance_file")"
    fi

    if ! printf '%s' "$instance_json" | jq empty 2>/dev/null; then
        _err "malformed JSON in instance: $instance_file"
        _emit_result "unknown" "error" "1" 0 0 0 0 ""
        return 1
    fi

    local id repo_url commit issue_text test_command
    id="$(printf '%s' "$instance_json" | jq -r '.instance_id // .id')"
    repo_url="$(printf '%s' "$instance_json" | jq -r '.repo_url // ("https://github.com/" + .repo + ".git")')"
    commit="$(printf '%s' "$instance_json" | jq -r '.base_commit // .commit')"
    issue_text="$(printf '%s' "$instance_json" | jq -r '.problem_statement // .issue_text')"
    test_command="$(printf '%s' "$instance_json" | jq -r '.test_command // empty')"

    [[ -z "$id" ]] && { _err "missing instance_id"; return 1; }
    _validate_repo_url "$repo_url" || return 1

    local workspace="$workspace_base/$id"
    _log "starting instance: $id"

    mkdir -p "$workspace_base"
    if [[ -d "$workspace" ]]; then
        _log "resetting existing workspace"
        (cd "$workspace" && git checkout -f "$commit" 2>/dev/null) || rm -rf "$workspace"
    fi
    if [[ ! -d "$workspace" ]]; then
        _log "cloning $repo_url..."
        if ! git clone --quiet --depth 50 "$repo_url" "$workspace" 2>/dev/null; then
            _emit_result "$id" "error" "clone_failed" 0 0 0 0 ""
            return 1
        fi
    fi
    if ! (cd "$workspace" && git checkout -f "$commit" 2>/dev/null); then
        _emit_result "$id" "error" "checkout_failed" 0 0 0 0 ""
        return 1
    fi

    local prompt
    prompt="$(_build_agent_prompt "$issue_text" "$workspace")"

    local start_time end_time duration agent_exit=0
    start_time="$(date +%s)"

    _log "running agent (model=$model, timeout=${timeout}s)..."
    if command -v claude >/dev/null 2>&1; then
        BENCH_WORKSPACE="$workspace" BENCH_PROMPT="$prompt" \
            timeout "$timeout" bash -c 'cd "$BENCH_WORKSPACE" && claude -p "$BENCH_PROMPT" --output-format text' \
            >/dev/null 2>&1 || agent_exit=$?
    else
        _log "WARN: claude CLI not found — skipping agent run (dry-run mode)"
        agent_exit=127
    fi

    end_time="$(date +%s)"
    duration=$(( end_time - start_time ))

    local agent_diff
    agent_diff="$(cd "$workspace" && git diff 2>/dev/null || true)"

    local eval_status="unknown" tests_passed=0
    if [[ -n "$test_command" ]] && [[ -n "$agent_diff" ]]; then
        if ! _validate_test_command "$test_command"; then
            eval_status="error"
            _err "skipping unsafe test_command for $id"
        elif (cd "$workspace" && bash -c "$test_command" >/dev/null 2>&1); then
            eval_status="pass"; tests_passed=1
        else
            eval_status="fail"
        fi
    elif [[ -n "$agent_diff" ]]; then
        eval_status="diff_produced"
    else
        eval_status="no_changes"
    fi

    local rogue_writes=0
    local expected_files
    expected_files="$(printf '%s' "$instance_json" | jq -r '.expected_files_changed[]? // empty' 2>/dev/null)"
    if [[ -n "$expected_files" ]] && [[ -n "$agent_diff" ]]; then
        local changed_files
        changed_files="$(cd "$workspace" && git diff --name-only 2>/dev/null)"
        while IFS= read -r f; do
            if ! printf '%s' "$expected_files" | grep -qF "$f"; then
                rogue_writes=$(( rogue_writes + 1 ))
            fi
        done <<< "$changed_files"
    fi

    local patch_match=0
    local gold_patch
    gold_patch="$(printf '%s' "$instance_json" | jq -r '.gold_patch // empty')"
    if [[ -n "$gold_patch" ]] && [[ -n "$agent_diff" ]]; then
        local agent_files gold_files
        agent_files="$(printf '%s' "$agent_diff" | grep '^diff --git' | sort)"
        gold_files="$(printf '%s' "$gold_patch" | grep '^diff --git' | sort)"
        [[ "$agent_files" == "$gold_files" ]] && patch_match=1
    fi

    _emit_result "$id" "$eval_status" "$agent_exit" "$duration" "$tests_passed" "$patch_match" "$rogue_writes" "$agent_diff"
    _log "done: $id — $eval_status (${duration}s)"
}

_build_agent_prompt() {
    local problem="$1" workspace="$2"
    printf '%s\n' \
        "You are a software engineer fixing a bug in an open-source project." \
        "" \
        "## Problem Statement" \
        "$problem" \
        "" \
        "## Instructions" \
        "1. Read the problem statement carefully." \
        "2. Explore the codebase to understand the relevant code." \
        "3. Implement a fix for the described issue." \
        "4. Make minimal, focused changes — fix the bug, nothing else." \
        "5. Do NOT run tests yourself — the harness will evaluate your changes." \
        "6. Do NOT commit — just leave your changes as unstaged modifications." \
        "" \
        "Working directory: $workspace"
}

_emit_result() {
    local id="$1" status="$2" exit_code="$3" duration="$4"
    local tests_passed="$5" patch_match="$6" rogue_writes="$7" diff="$8"

    jq -n \
        --arg id "$id" \
        --arg status "$status" \
        --arg exit_code "$exit_code" \
        --arg duration "$duration" \
        --arg tests_passed "$tests_passed" \
        --arg patch_match "$patch_match" \
        --arg rogue_writes "$rogue_writes" \
        --arg diff "$diff" \
        --arg model "${BENCH_MODEL:-sonnet}" \
        --arg agents "${BENCH_AGENTS:-1}" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            instance_id: $id,
            resolved: ($status == "pass"),
            status: $status,
            agent_exit_code: ($exit_code | tonumber),
            cycles: 1,
            wall_time_seconds: ($duration | tonumber),
            test_passed: ($tests_passed == "1"),
            patch_match: ($patch_match | tonumber),
            rogue_writes: ($rogue_writes | tonumber),
            model: $model,
            agents: ($agents | tonumber),
            timestamp: $timestamp,
            diff_length: ($diff | length)
        }'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_instance "$@"
fi
