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

# Source orchestrator if available (for single-agent mode)
ORCHESTRATOR="$PROJECT_ROOT/scripts/auto-agent.sh"

_log() { printf '[instance] %s  %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
_err() { _log "ERROR: $*"; }

# Validate repo URL format (CRITICAL-02 security)
_validate_repo_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(\.git)?$ ]]; then
        _err "invalid repo URL: '$url'"; return 1
    fi
}

# Validate patch content (no shell injection)
_validate_patch() {
    local patch="$1" label="$2"
    [[ -z "$patch" ]] && return 0
    if printf '%s' "$patch" | grep -qE '(--exec|;\s*[a-z]|`|\$\(|&&|\|\|)'; then
        _err "$label contains unsafe content"; return 1
    fi
}

# BENCH-SEC-02: Validate test_command from JSON before execution.
# Only allow known test runner prefixes; reject shell metacharacters.
_validate_test_command() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return 1

    # Reject dangerous shell metacharacters (pipes, subshells, redirects, backticks)
    if printf '%s' "$cmd" | grep -qE '[;|&`$><]|\$\(|#'; then
        _err "test_command contains shell metacharacters: '$cmd'"; return 1
    fi

    # Whitelist known test runner prefixes
    local -a allowed=(
        "pytest" "python -m pytest" "python -m unittest"
        "make test" "make check"
        "npm test" "npm run test" "npx"
        "cargo test" "go test"
        "tox" "nox"
        "bash " "./test" "./run_test"
    )
    local prefix
    for prefix in "${allowed[@]}"; do
        if [[ "$cmd" == "$prefix"* ]]; then
            return 0
        fi
    done

    _err "test_command not in whitelist: '$cmd'"; return 1
}

# Run a single benchmark instance
# Args: $1 = instance JSON file or "-" for stdin
#        $2 = workspace dir
#        $3 = model (default: sonnet)
#        $4 = max_cycles (default: 5)
#        $5 = timeout seconds (default: 600)
run_instance() {
    local instance_file="${1:--}"
    local workspace_base="${2:-/tmp/orchystraw-bench}"
    local model="${3:-sonnet}"
    local max_cycles="${4:-5}"
    local timeout="${5:-600}"

    # Parse instance
    local instance_json
    if [[ "$instance_file" == "-" ]]; then
        instance_json="$(cat)"
    else
        instance_json="$(cat "$instance_file")"
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

    # Step 1: Clone and checkout
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

    # Step 2: Build prompt
    local prompt
    prompt="$(_build_agent_prompt "$issue_text" "$workspace")"

    # Step 3: Run agent with timeout
    local start_time end_time duration agent_exit=0
    start_time="$(date +%s)"

    _log "running agent (model=$model, timeout=${timeout}s)..."
    if command -v claude >/dev/null 2>&1; then
        # BENCH-SEC-01: Use env vars instead of interpolating into bash -c string
        BENCH_WORKSPACE="$workspace" BENCH_PROMPT="$prompt" \
            timeout "$timeout" bash -c 'cd "$BENCH_WORKSPACE" && claude -p "$BENCH_PROMPT" --output-format text' \
            >/dev/null 2>&1 || agent_exit=$?
    else
        _log "WARN: claude CLI not found — skipping agent run (dry-run mode)"
        agent_exit=127
    fi

    end_time="$(date +%s)"
    duration=$(( end_time - start_time ))

    # Step 4: Capture diff
    local agent_diff
    agent_diff="$(cd "$workspace" && git diff 2>/dev/null || true)"

    # Step 5: Evaluate
    local eval_status="unknown" tests_passed=0
    if [[ -n "$test_command" ]] && [[ -n "$agent_diff" ]]; then
        # BENCH-SEC-02: Validate test_command against whitelist before execution.
        # Rejects shell metacharacters and requires a known test runner prefix.
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

    # Step 6: Check rogue writes (files outside expected scope)
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

    # Step 7: Patch match (if gold_patch available)
    local patch_match=0
    local gold_patch
    gold_patch="$(printf '%s' "$instance_json" | jq -r '.gold_patch // empty')"
    if [[ -n "$gold_patch" ]] && [[ -n "$agent_diff" ]]; then
        local agent_files gold_files
        agent_files="$(printf '%s' "$agent_diff" | grep '^diff --git' | sort)"
        gold_files="$(printf '%s' "$gold_patch" | grep '^diff --git' | sort)"
        [[ "$agent_files" == "$gold_files" ]] && patch_match=1
    fi

    # Emit result
    _emit_result "$id" "$eval_status" "$agent_exit" "$duration" "$tests_passed" "$patch_match" "$rogue_writes" "$agent_diff"
    _log "done: $id — $eval_status (${duration}s)"
}

_build_agent_prompt() {
    local problem="$1" workspace="$2"
    # BENCH-SEC-01: Use printf %s to safely interpolate untrusted problem text.
    # Heredoc with unquoted delimiter would interpret $ and \ in problem statements.
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

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_instance "$@"
fi
