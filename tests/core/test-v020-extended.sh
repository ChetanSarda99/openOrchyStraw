#!/usr/bin/env bash
# Test: v0.2.0 module edge cases — dynamic-router model selection,
# review-phase QA gate, worktree isolation, prompt-compression tiering
#
# These tests cover cross-module interactions and edge cases that the
# individual module tests may not exercise.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PASS=0
FAIL=0

assert() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $desc"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $desc (expected '$expected', got '$actual')"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $desc (expected to contain '$needle')"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: $desc (expected NOT to contain '$needle')"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ══════════════════════════════════════════
# SECTION 1: Dynamic Router — Model Selection Edge Cases
# ══════════════════════════════════════════

unset _ORCH_DYNAMIC_ROUTER_LOADED
source "$PROJECT_ROOT/src/core/dynamic-router.sh"

# ── Helper configs ──
create_mixed_model_conf() {
    cat > "$TMPDIR_TEST/agents-mixed.conf" << 'EOF'
06-backend | prompts/06-backend/06-backend.txt | src/ | 1 | Backend | 10 | none | none | opus
09-qa      | prompts/09-qa/09-qa.txt           | tests/ | 3 | QA    | 5  | 06-backend | 06-backend | sonnet
13-hr      | prompts/13-hr/13-hr.txt           | docs/ | 3 | HR     | 2  | none | none | haiku
03-pm      | prompts/03-pm/03-pm.txt           | prompts/ | 0 | PM  | 0  | all | none | sonnet
EOF
}

create_no_model_conf() {
    cat > "$TMPDIR_TEST/agents-nomodel.conf" << 'EOF'
06-backend | prompts/06-backend/06-backend.txt | src/ | 1 | Backend | 10 | none | none
09-qa      | prompts/09-qa/09-qa.txt           | tests/ | 3 | QA    | 5  | none | none
EOF
}

create_single_agent_conf() {
    cat > "$TMPDIR_TEST/agents-single.conf" << 'EOF'
06-backend | prompts/06-backend/06-backend.txt | src/ | 1 | Backend
EOF
}

# T1: Model selection respects per-agent config
create_mixed_model_conf
orch_router_init "$TMPDIR_TEST/agents-mixed.conf"
assert_eq "T1a: backend=opus" "opus" "${_ORCH_ROUTER_MODEL[06-backend]}"
assert_eq "T1b: qa=sonnet" "sonnet" "${_ORCH_ROUTER_MODEL[09-qa]}"
assert_eq "T1c: hr=haiku" "haiku" "${_ORCH_ROUTER_MODEL[13-hr]}"
assert_eq "T1d: pm=sonnet" "sonnet" "${_ORCH_ROUTER_MODEL[03-pm]}"

# T2: 8-col config (no model) defaults to ORCH_DEFAULT_MODEL
create_no_model_conf
orch_router_init "$TMPDIR_TEST/agents-nomodel.conf"
assert_eq "T2: 8-col default model" "$_ORCH_DEFAULT_MODEL" "${_ORCH_ROUTER_MODEL[06-backend]}"

# T3: 5-col config also defaults
create_single_agent_conf
orch_router_init "$TMPDIR_TEST/agents-single.conf"
assert_eq "T3: 5-col default model" "$_ORCH_DEFAULT_MODEL" "${_ORCH_ROUTER_MODEL[06-backend]}"

# T4: Per-agent env override takes highest precedence
create_mixed_model_conf
orch_router_init "$TMPDIR_TEST/agents-mixed.conf"
export ORCH_MODEL_OVERRIDE_09_QA=haiku
resolved=$(orch_router_model "09-qa")
assert_eq "T4: per-agent env override" "claude-haiku-4-5" "$resolved"
unset ORCH_MODEL_OVERRIDE_09_QA

# T5: CLI override applies globally but per-agent beats it
create_mixed_model_conf
orch_router_init "$TMPDIR_TEST/agents-mixed.conf"
export ORCH_MODEL_CLI_OVERRIDE=haiku
export ORCH_MODEL_OVERRIDE_06_BACKEND=sonnet
resolved_backend=$(orch_router_model "06-backend")
resolved_qa=$(orch_router_model "09-qa")
assert_eq "T5a: per-agent beats CLI" "claude-sonnet-4-6" "$resolved_backend"
assert_eq "T5b: CLI override applies to others" "claude-haiku-4-5" "$resolved_qa"
unset ORCH_MODEL_CLI_OVERRIDE
unset ORCH_MODEL_OVERRIDE_06_BACKEND

# T6: model_name returns abstract name even with override
create_mixed_model_conf
orch_router_init "$TMPDIR_TEST/agents-mixed.conf"
export ORCH_MODEL_OVERRIDE_13_HR=opus
resolved_name=$(orch_router_model_name "13-hr")
assert_eq "T6: model_name with override" "opus" "$resolved_name"
unset ORCH_MODEL_OVERRIDE_13_HR

# T7: Coordinator (interval=0) model is correctly parsed
create_mixed_model_conf
orch_router_init "$TMPDIR_TEST/agents-mixed.conf"
assert_eq "T7: coordinator model" "sonnet" "${_ORCH_ROUTER_MODEL[03-pm]}"

# ══════════════════════════════════════════
# SECTION 2: Review Phase — QA Gate Edge Cases
# ══════════════════════════════════════════

unset _ORCH_REVIEW_PHASE_LOADED
source "$PROJECT_ROOT/src/core/review-phase.sh"

create_review_conf() {
    cat > "$TMPDIR_TEST/review.conf" << 'EOF'
06-backend | prompts/06-backend/06-backend.txt | src/ | 1 | Backend | 10 | none | none
09-qa      | prompts/09-qa/09-qa.txt           | tests/ | 3 | QA    | 5  | 06-backend | 06-backend
02-cto     | prompts/02-cto/02-cto.txt         | docs/ | 2 | CTO    | 7  | none | 06-backend
03-pm      | prompts/03-pm/03-pm.txt           | prompts/ | 0 | PM  | 0  | all | none
EOF
}

create_no_review_conf() {
    cat > "$TMPDIR_TEST/no-review.conf" << 'EOF'
06-backend | prompts/06-backend/06-backend.txt | src/ | 1 | Backend
09-qa      | prompts/09-qa/09-qa.txt           | tests/ | 3 | QA
03-pm      | prompts/03-pm/03-pm.txt           | prompts/ | 0 | PM
EOF
}

# T8: Review init with valid config
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
assert_eq "T8: review initialized" "true" "$_ORCH_REVIEW_INITIALIZED"

# T9: Review map parsed correctly (09-qa reviews 06-backend)
assert_eq "T9: qa reviews backend" "06-backend" "${_ORCH_REVIEW_MAP[09-qa]}"

# T10: CTO also reviews 06-backend
assert_eq "T10: cto reviews backend" "06-backend" "${_ORCH_REVIEW_MAP[02-cto]}"

# T11: Plan only includes committed agents
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
orch_review_plan 1 "06-backend"
assert_eq "T11: 2 reviews planned" "2" "${#_ORCH_REVIEW_PLAN[@]}"

# T12: Plan is empty when no reviewed agents committed
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
orch_review_plan 1 "03-pm"
assert_eq "T12: 0 reviews when target not committed" "0" "${#_ORCH_REVIEW_PLAN[@]}"

# T13: v1 config (no reviews column) — no reviews configured
create_no_review_conf
orch_review_init "$TMPDIR_TEST/no-review.conf" "$TMPDIR_TEST/output"
assert_eq "T13: no reviewers in v1" "0" "${#_ORCH_REVIEW_MAP[@]}"

# T14: Record verdict — valid verdicts accepted
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
mkdir -p "$TMPDIR_TEST/output"
orch_review_record "09-qa" "06-backend" "approve" "Code looks good"
assert_eq "T14: verdict recorded" "approve" "${_ORCH_REVIEW_VERDICTS[09-qa|06-backend]}"

# T15: Record verdict — invalid verdict rejected
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
if orch_review_record "09-qa" "06-backend" "invalid-verdict" "test" 2>/dev/null; then
    echo "FAIL: T15 invalid verdict should be rejected"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

# T16: Summary includes findings
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
orch_review_plan 1 "06-backend"
orch_review_record "09-qa" "06-backend" "approve" "All tests pass"
summary=$(orch_review_summary 2>/dev/null)
assert_contains "T16: summary has findings" "$summary" "Summary"

# T17: Path traversal in agent IDs rejected
create_review_conf
orch_review_init "$TMPDIR_TEST/review.conf" "$TMPDIR_TEST/output"
if orch_review_context "../etc" "06-backend" "$TMPDIR_TEST" 2>/dev/null; then
    echo "FAIL: T17 path traversal should be rejected"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

# ══════════════════════════════════════════
# SECTION 3: Worktree Isolation Edge Cases
# ══════════════════════════════════════════

# Set env vars BEFORE sourcing so the module picks them up
export ORCH_WORKTREE_TMPDIR="$TMPDIR_TEST"
export ORCH_WORKTREE="true"

unset _ORCH_WORKTREE_LOADED
source "$PROJECT_ROOT/src/core/worktree.sh"

# Setup a temp git repo for worktree tests
WT_REPO="$TMPDIR_TEST/wt-repo"
mkdir -p "$WT_REPO"
git -C "$WT_REPO" init -b main >/dev/null 2>&1
git -C "$WT_REPO" config user.email "test@test.com"
git -C "$WT_REPO" config user.name "Test"
echo "initial" > "$WT_REPO/file.txt"
git -C "$WT_REPO" add file.txt
git -C "$WT_REPO" commit -m "initial" >/dev/null 2>&1

# T18: Init succeeds with valid git repo
assert "T18: worktree init" orch_worktree_init "$WT_REPO"

# T19: Init fails with non-git directory
if orch_worktree_init "$TMPDIR_TEST" 2>/dev/null; then
    echo "FAIL: T19 non-git dir should fail"
    FAIL=$(( FAIL + 1 ))
else
    PASS=$(( PASS + 1 ))
fi

# T20: Worktree enabled when ORCH_WORKTREE=true
assert "T20: worktree enabled" orch_worktree_enabled

# T21: Create worktree for agent (call without subshell to preserve _ACTIVE array)
orch_worktree_init "$WT_REPO"
wt_expected=$(orch_worktree_path "06-backend" 1)
orch_worktree_create "06-backend" 1 >/dev/null
if [[ -d "$wt_expected" ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T21 worktree directory not created at $wt_expected"
    FAIL=$(( FAIL + 1 ))
fi

# T22: Worktree has correct branch
wt_branch=$(orch_worktree_branch "06-backend" 1)
assert_contains "T22: branch name has agent id" "$wt_branch" "06-backend"

# T23: Active worktree tracked in array
assert_eq "T23: 1 active worktree tracked" "1" "${#_ORCH_WORKTREE_ACTIVE[@]}"

# T24: List shows active worktree (path contains agent name)
wt_list=$(orch_worktree_list 2>/dev/null || true)
assert_contains "T24: list includes active worktree" "$wt_list" "06-backend"

# T25: Merge worktree back
echo "backend changes" > "$wt_expected/backend.txt"
git -C "$wt_expected" add backend.txt
git -C "$wt_expected" commit -m "backend work" >/dev/null 2>&1
assert "T25: merge worktree" orch_worktree_merge "06-backend" 1

# T26: After merge, file exists in main repo
if [[ -f "$WT_REPO/backend.txt" ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T26 merged file not in main repo"
    FAIL=$(( FAIL + 1 ))
fi

# T27: Cleanup removes all worktrees
orch_worktree_create "09-qa" 2 >/dev/null
orch_worktree_cleanup 2>/dev/null
wt_list_after=$(orch_worktree_list 2>/dev/null || true)
if [[ -z "$wt_list_after" ]] || [[ "$wt_list_after" == *"0 active"* ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T27 cleanup didn't remove all worktrees"
    FAIL=$(( FAIL + 1 ))
fi

# ══════════════════════════════════════════
# SECTION 4: Prompt Compression Tiering
# ══════════════════════════════════════════

unset _ORCH_PROMPT_COMPRESSION_LOADED
source "$PROJECT_ROOT/src/core/prompt-compression.sh"

# Create a sample prompt file with known sections
cat > "$TMPDIR_TEST/sample-prompt.txt" << 'PROMPT'
# Backend Developer
## For Claude Code — Backend Role

## What is OrchyStraw?
Multi-agent AI coding orchestration.

## Tech Stack
Bash, markdown, no dependencies.

## File Ownership (STRICT)
You own: src/ scripts/
You never touch: site/ prompts/

## Current Tasks
1. Build the REST API
2. Add validation
3. Write tests

## What's DONE (Cycle 1-5)
- Built logger module
- Built error handler

## Auto-Cycle Mode
When running in auto-cycle mode:
1. Read tasks
2. Execute
3. Write status
PROMPT

# T28: Classify sections
orch_prompt_init
orch_prompt_classify "test-agent" "$TMPDIR_TEST/sample-prompt.txt"
sec_count="${_ORCH_PROMPT_SEC_COUNT[test-agent]:-0}"
if [[ "$sec_count" -gt 0 ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T28 no sections classified (count=$sec_count)"
    FAIL=$(( FAIL + 1 ))
fi

# T29: Stable sections identified (Tech Stack, File Ownership)
found_stable=0
for (( i=0; i<sec_count; i++ )); do
    tier="${_ORCH_PROMPT_SEC_TIER[test-agent:$i]:-}"
    header="${_ORCH_PROMPT_SEC_HEADERS[test-agent:$i]:-}"
    if [[ "$tier" == "stable" ]]; then
        found_stable=$(( found_stable + 1 ))
    fi
done
if [[ "$found_stable" -ge 2 ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T29 expected 2+ stable sections, found $found_stable"
    FAIL=$(( FAIL + 1 ))
fi

# T30: Dynamic sections identified (Current Tasks, What's DONE)
found_dynamic=0
for (( i=0; i<sec_count; i++ )); do
    tier="${_ORCH_PROMPT_SEC_TIER[test-agent:$i]:-}"
    if [[ "$tier" == "dynamic" ]]; then
        found_dynamic=$(( found_dynamic + 1 ))
    fi
done
if [[ "$found_dynamic" -ge 1 ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T30 expected 1+ dynamic sections, found $found_dynamic"
    FAIL=$(( FAIL + 1 ))
fi

# T31: Token estimation is reasonable
tokens=$(orch_prompt_estimate_tokens "$TMPDIR_TEST/sample-prompt.txt")
if [[ "$tokens" -gt 0 && "$tokens" -lt 10000 ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T31 token estimate unreasonable: $tokens"
    FAIL=$(( FAIL + 1 ))
fi

# T32: Stable hash is deterministic
hash1=$(orch_prompt_stable_hash "test-agent")
hash2=$(orch_prompt_stable_hash "test-agent")
assert_eq "T32: stable hash deterministic" "$hash1" "$hash2"

# T33: Hash changes when stable content changes
orch_prompt_classify "test-agent" "$TMPDIR_TEST/sample-prompt.txt"
hash_before=$(orch_prompt_stable_hash "test-agent")
# Modify a stable section
cat > "$TMPDIR_TEST/sample-prompt-v2.txt" << 'PROMPT2'
# Backend Developer
## For Claude Code — Backend Role

## What is OrchyStraw?
Multi-agent AI coding orchestration. Now with benchmarks!

## Tech Stack
Bash, markdown, Python for tooling.

## File Ownership (STRICT)
You own: src/ scripts/ benchmarks/

## Current Tasks
1. Build the REST API

## What's DONE
- Built logger
PROMPT2
orch_prompt_classify "test-agent" "$TMPDIR_TEST/sample-prompt-v2.txt"
hash_after=$(orch_prompt_stable_hash "test-agent")
if [[ "$hash_before" != "$hash_after" ]]; then
    PASS=$(( PASS + 1 ))
else
    echo "FAIL: T33 hash should change after stable content change"
    FAIL=$(( FAIL + 1 ))
fi

# T34: Compress mode=full returns all content
full_output=$(orch_prompt_compress "test-agent" "full")
assert_contains "T34: full mode has stable" "$full_output" "Tech Stack"

# T35: Compress mode=minimal returns only dynamic
minimal_output=$(orch_prompt_compress "test-agent" "minimal")
assert_contains "T35: minimal has dynamic" "$minimal_output" "Tasks"

# T36: Empty file doesn't crash
touch "$TMPDIR_TEST/empty-prompt.txt"
orch_prompt_classify "empty-agent" "$TMPDIR_TEST/empty-prompt.txt"
empty_count="${_ORCH_PROMPT_SEC_COUNT[empty-agent]:-0}"
assert_eq "T36: empty file has 0 sections" "0" "$empty_count"

# T37: Save and load hashes round-trips
# stable_hash stores in _ORCH_PROMPT_STABLE_HASH only when NOT called in subshell
# save_hashes persists _ORCH_PROMPT_STABLE_HASH, load_hashes populates _ORCH_PROMPT_PREV_HASH
orch_prompt_classify "test-agent" "$TMPDIR_TEST/sample-prompt.txt"
# Call directly (not in $()) so array mutation is preserved in current shell
orch_prompt_stable_hash "test-agent" >/dev/null
original_hash="${_ORCH_PROMPT_STABLE_HASH[test-agent]:-}"
orch_prompt_save_hashes "$TMPDIR_TEST/hashes.state"
# Clear prev hashes and reload from saved file
_ORCH_PROMPT_PREV_HASH=()
orch_prompt_load_hashes "$TMPDIR_TEST/hashes.state"
loaded_hash="${_ORCH_PROMPT_PREV_HASH[test-agent]:-}"
assert_eq "T37: hash round-trips via save/load" "$original_hash" "$loaded_hash"

# T38: mode_for_agent returns correct mode
orch_prompt_classify "test-agent" "$TMPDIR_TEST/sample-prompt.txt"
_ORCH_PROMPT_PREV_HASH=()
mode=$(orch_prompt_mode_for_agent "test-agent")
assert_eq "T38: first run is full mode" "full" "$mode"

# ══════════════════════════════════════════
# Results
# ══════════════════════════════════════════

printf '\nv0.2.0 Extended Tests: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
