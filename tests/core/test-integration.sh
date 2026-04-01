#!/usr/bin/env bash
# =============================================================================
# test-integration.sh — Integration smoke test for all src/core/ modules
#
# Verifies that all 22 modules can be sourced together without conflicts:
#   - No duplicate function names
#   - No guard variable collisions
#   - No associative array clashes
#   - Basic cross-module workflow succeeds
#
# Usage:  bash tests/core/test-integration.sh
# Exit:   0 on success, 1 on any failure
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_ROOT/src/core"

PASS=0
FAIL=0

assert() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s\n' "$desc" >&2
        (( FAIL++ )) || true
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        (( PASS++ )) || true
    else
        printf '  FAIL: %s (expected "%s", got "%s")\n' "$desc" "$expected" "$actual" >&2
        (( FAIL++ )) || true
    fi
}

# ── Use a temp directory for all side effects ────────────────────────────────
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# ── Test 1: Source all 22 modules in documented order ────────────────────────
printf 'test-integration: sourcing all 22 modules...\n'

export ORCH_QUIET=1  # suppress log output during tests

# v0.1.0 modules (8)
source "$CORE_DIR/bash-version.sh"
source "$CORE_DIR/logger.sh"
source "$CORE_DIR/error-handler.sh"
source "$CORE_DIR/cycle-state.sh"
source "$CORE_DIR/agent-timeout.sh"
source "$CORE_DIR/dry-run.sh"
source "$CORE_DIR/config-validator.sh"
source "$CORE_DIR/lock-file.sh"

# v0.2.0 modules (6)
source "$CORE_DIR/signal-handler.sh"
source "$CORE_DIR/cycle-tracker.sh"
source "$CORE_DIR/dynamic-router.sh"
source "$CORE_DIR/review-phase.sh"
source "$CORE_DIR/worktree.sh"
source "$CORE_DIR/prompt-compression.sh"

# v0.2.5 modules (2)
source "$CORE_DIR/conditional-activation.sh"
source "$CORE_DIR/differential-context.sh"

# v0.3.0 modules (4)
source "$CORE_DIR/session-tracker.sh"
source "$CORE_DIR/single-agent.sh"
source "$CORE_DIR/qmd-refresher.sh"
source "$CORE_DIR/prompt-template.sh"

# v0.3.0+ modules (2)
source "$CORE_DIR/task-decomposer.sh"
source "$CORE_DIR/init-project.sh"

assert "all 22 modules sourced without error" true

# ── Test 2: Guard variables prevent double-sourcing ──────────────────────────
printf 'test-integration: verifying double-source guards...\n'

# v0.1.0
assert "bash-version guard set"     test -n "${_ORCH_BASH_VERSION_LOADED:-}"
assert "logger guard set"           test -n "${_ORCH_LOGGER_LOADED:-}"
assert "error-handler guard set"    test -n "${_ORCH_ERROR_HANDLER_LOADED:-}"
assert "cycle-state guard set"      test -n "${_ORCH_CYCLE_STATE_LOADED:-}"
assert "agent-timeout guard set"    test -n "${_ORCH_AGENT_TIMEOUT_LOADED:-}"
assert "dry-run guard set"          test -n "${_ORCH_DRY_RUN_LOADED:-}"
assert "config-validator guard set" test -n "${_ORCH_CONFIG_VALIDATOR_LOADED:-}"
assert "lock-file guard set"        test -n "${_ORCH_LOCK_FILE_LOADED:-}"

# v0.2.0+
assert "signal-handler guard set"       test -n "${_ORCH_SIGNAL_HANDLER_LOADED:-}"
assert "cycle-tracker guard set"        test -n "${_ORCH_CYCLE_TRACKER_LOADED:-}"
assert "dynamic-router guard set"       test -n "${_ORCH_DYNAMIC_ROUTER_LOADED:-}"
assert "review-phase guard set"         test -n "${_ORCH_REVIEW_PHASE_LOADED:-}"
assert "worktree guard set"             test -n "${_ORCH_WORKTREE_LOADED:-}"
assert "prompt-compression guard set"   test -n "${_ORCH_PROMPT_COMPRESSION_LOADED:-}"
assert "conditional-activation guard set" test -n "${_ORCH_CONDITIONAL_ACTIVATION_LOADED:-}"
assert "differential-context guard set" test -n "${_ORCH_DIFFCTX_LOADED:-}"
assert "session-tracker guard set"      test -n "${_ORCH_SESSION_TRACKER_LOADED:-}"
assert "single-agent guard set"         test -n "${_ORCH_SINGLE_AGENT_LOADED:-}"
assert "qmd-refresher guard set"        test -n "${_ORCH_QMD_REFRESHER_LOADED:-}"
assert "prompt-template guard set"      test -n "${_ORCH_PROMPT_TEMPLATE_LOADED:-}"
assert "task-decomposer guard set"      test -n "${_ORCH_TASK_DECOMPOSER_LOADED:-}"
assert "init-project guard set"         test -n "${_ORCH_INIT_PROJECT_LOADED:-}"

# ── Test 3: Key functions exist from each module ─────────────────────────────
printf 'test-integration: verifying public API functions exist...\n'

# logger
assert "orch_log exists"            declare -f orch_log
assert "orch_log_init exists"       declare -f orch_log_init
assert "orch_log_summary exists"    declare -f orch_log_summary

# error-handler
assert "orch_handle_agent_failure exists" declare -f orch_handle_agent_failure
assert "orch_should_retry exists"         declare -f orch_should_retry
assert "orch_failure_report exists"       declare -f orch_failure_report

# cycle-state
assert "orch_state_save exists"     declare -f orch_state_save
assert "orch_state_load exists"     declare -f orch_state_load
assert "orch_state_resume exists"   declare -f orch_state_resume

# agent-timeout
assert "orch_run_with_timeout exists" declare -f orch_run_with_timeout
assert "orch_get_agent_timeout exists" declare -f orch_get_agent_timeout

# dry-run
assert "orch_dry_run_init exists"   declare -f orch_dry_run_init
assert "orch_is_dry_run exists"     declare -f orch_is_dry_run
assert "orch_dry_run_report exists" declare -f orch_dry_run_report

# config-validator
assert "orch_validate_config exists" declare -f orch_validate_config
assert "orch_config_error_count exists" declare -f orch_config_error_count

# lock-file
assert "orch_lock_acquire exists"   declare -f orch_lock_acquire
assert "orch_lock_release exists"   declare -f orch_lock_release

# bash-version
assert "orch_check_bash_version exists" declare -f orch_check_bash_version

# signal-handler
assert "orch_signal_init exists"        declare -f orch_signal_init
assert "orch_is_shutting_down exists"   declare -f orch_is_shutting_down
assert "orch_kill_agents exists"        declare -f orch_kill_agents

# cycle-tracker
assert "orch_tracker_init exists"       declare -f orch_tracker_init
assert "orch_tracker_record exists"     declare -f orch_tracker_record
assert "orch_tracker_is_empty exists"   declare -f orch_tracker_is_empty
assert "orch_tracker_summary exists"    declare -f orch_tracker_summary

# dynamic-router
assert "orch_router_init exists"        declare -f orch_router_init
assert "orch_router_eligible exists"    declare -f orch_router_eligible
assert "orch_router_model exists"       declare -f orch_router_model
assert "orch_router_groups exists"      declare -f orch_router_groups

# review-phase
assert "orch_review_init exists"        declare -f orch_review_init
assert "orch_review_plan exists"        declare -f orch_review_plan
assert "orch_review_record exists"      declare -f orch_review_record
assert "orch_review_should_run exists"  declare -f orch_review_should_run

# worktree
assert "orch_worktree_init exists"      declare -f orch_worktree_init
assert "orch_worktree_create exists"    declare -f orch_worktree_create
assert "orch_worktree_merge exists"     declare -f orch_worktree_merge
assert "orch_worktree_cleanup exists"   declare -f orch_worktree_cleanup

# prompt-compression
assert "orch_prompt_init exists"        declare -f orch_prompt_init
assert "orch_prompt_compress exists"    declare -f orch_prompt_compress
assert "orch_prompt_estimate_tokens exists" declare -f orch_prompt_estimate_tokens

# conditional-activation
assert "orch_activation_init exists"    declare -f orch_activation_init
assert "orch_activation_check exists"   declare -f orch_activation_check
assert "orch_activation_stats exists"   declare -f orch_activation_stats

# differential-context
assert "orch_diffctx_init exists"       declare -f orch_diffctx_init
assert "orch_diffctx_filter exists"     declare -f orch_diffctx_filter
assert "orch_diffctx_stats exists"      declare -f orch_diffctx_stats

# session-tracker
assert "orch_session_init exists"       declare -f orch_session_init
assert "orch_session_window exists"     declare -f orch_session_window
assert "orch_session_stats exists"      declare -f orch_session_stats

# single-agent
assert "orch_single_init exists"        declare -f orch_single_init
assert "orch_single_detect exists"      declare -f orch_single_detect
assert "orch_single_report exists"      declare -f orch_single_report

# qmd-refresher
assert "orch_qmd_available exists"      declare -f orch_qmd_available
assert "orch_qmd_refresh exists"        declare -f orch_qmd_refresh
assert "orch_qmd_status exists"         declare -f orch_qmd_status

# prompt-template
assert "orch_tpl_init exists"           declare -f orch_tpl_init
assert "orch_tpl_render exists"         declare -f orch_tpl_render
assert "orch_tpl_validate exists"       declare -f orch_tpl_validate

# task-decomposer
assert "orch_select_tasks exists"       declare -f orch_select_tasks
assert "orch_decompose_tasks exists"    declare -f orch_decompose_tasks
assert "orch_task_report exists"        declare -f orch_task_report

# init-project
assert "orch_init_scan exists"          declare -f orch_init_scan
assert "orch_init_suggest_agents exists" declare -f orch_init_suggest_agents
assert "orch_init_report exists"        declare -f orch_init_report

# ── Test 4: Cross-module workflow ────────────────────────────────────────────
printf 'test-integration: running cross-module workflow...\n'

# 4a. Logger → init and log a message
orch_log_init "$WORK_DIR/logs"
assert "log file created" test -f "$WORK_DIR/logs/cycle-1.log"

orch_log INFO test-integration "Cross-module test started"

# 4b. Cycle state → save and load
orch_state_save 1 running
orch_state_load
assert_eq "cycle state saved/loaded" "1" "$ORCH_LAST_CYCLE"
assert_eq "cycle status running" "running" "$ORCH_LAST_STATUS"

# 4c. Cycle state → resume returns same cycle on 'running' status
local_resume=$(orch_state_resume)
assert_eq "resume from running returns same cycle" "1" "$local_resume"

# 4d. Cycle state → complete and resume increments
orch_state_save 1 completed
local_resume=$(orch_state_resume)
assert_eq "resume from completed returns next cycle" "2" "$local_resume"

# 4e. Lock file → acquire and release
orch_lock_acquire
assert "lock acquired" orch_lock_check
orch_lock_release
assert "lock released" test ! -f "$WORK_DIR/.orchystraw/orchestrator.lock"

# 4f. Dry-run → not active by default
if orch_is_dry_run; then
    printf '  FAIL: dry-run inactive by default\n' >&2
    (( FAIL++ )) || true
else
    (( PASS++ )) || true
fi

# 4g. Dry-run → activated by flag
orch_dry_run_init --dry-run
assert "dry-run activated by flag" orch_is_dry_run

# 4h. Agent timeout → default is 300
timeout_val=$(orch_get_agent_timeout "06-backend")
assert_eq "default timeout is 300" "300" "$timeout_val"

# 4i. Error handler → record and check retry
orch_handle_agent_failure "test-agent" 1 "" >/dev/null 2>&1
assert "should retry on first failure" orch_should_retry "test-agent" 1

# 4j. Error handler → report runs without error
orch_failure_report 1 >/dev/null 2>&1
assert "failure report generated" true

# 4k. Logger summary runs after all operations
orch_log_summary >/dev/null 2>&1
assert "log summary generated" true

# ── Test 5: No namespace collisions ──────────────────────────────────────────
printf 'test-integration: checking for namespace collisions...\n'

# All public functions should start with orch_
# All internal functions should start with _orch_
# Count total orch functions — should be a reasonable number (not duplicated)
orch_fn_count=$(declare -F | grep -c ' orch_\|_orch_' || true)
assert "orch functions loaded (22 modules)" test "$orch_fn_count" -gt 80

# Verify session-tracker and cycle-tracker don't collide (BUG-025 fix)
assert "orch_tracker_init is cycle-tracker (not overwritten)" \
    bash -c "source '$CORE_DIR/cycle-tracker.sh' && source '$CORE_DIR/session-tracker.sh' && declare -f orch_tracker_init | grep -q _ORCH_TRACKER_CYCLE"
assert "orch_session_init is session-tracker" \
    bash -c "source '$CORE_DIR/session-tracker.sh' && declare -f orch_session_init | grep -q _ORCH_SESSION_RECENT"

# ── Results ──────────────────────────────────────────────────────────────────
printf '\ntest-integration: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
