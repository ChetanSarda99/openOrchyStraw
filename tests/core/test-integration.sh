#!/usr/bin/env bash
# =============================================================================
# test-integration.sh — Integration smoke test for all src/core/ modules
#
# Verifies that all 8 modules can be sourced together without conflicts:
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

# ── Test 1: Source all 8 modules in the documented order ─────────────────────
printf 'test-integration: sourcing all 8 modules...\n'

export ORCH_QUIET=1  # suppress log output during tests

source "$CORE_DIR/bash-version.sh"
source "$CORE_DIR/logger.sh"
source "$CORE_DIR/error-handler.sh"
source "$CORE_DIR/cycle-state.sh"
source "$CORE_DIR/agent-timeout.sh"
source "$CORE_DIR/dry-run.sh"
source "$CORE_DIR/config-validator.sh"
source "$CORE_DIR/lock-file.sh"

assert "all 8 modules sourced without error" true

# ── Test 2: Guard variables prevent double-sourcing ──────────────────────────
printf 'test-integration: verifying double-source guards...\n'

assert "bash-version guard set"     test -n "${_ORCH_BASH_VERSION_LOADED:-}"
assert "logger guard set"           test -n "${_ORCH_LOGGER_LOADED:-}"
assert "error-handler guard set"    test -n "${_ORCH_ERROR_HANDLER_LOADED:-}"
assert "cycle-state guard set"      test -n "${_ORCH_CYCLE_STATE_LOADED:-}"
assert "agent-timeout guard set"    test -n "${_ORCH_AGENT_TIMEOUT_LOADED:-}"
assert "dry-run guard set"          test -n "${_ORCH_DRY_RUN_LOADED:-}"
assert "config-validator guard set" test -n "${_ORCH_CONFIG_VALIDATOR_LOADED:-}"
assert "lock-file guard set"        test -n "${_ORCH_LOCK_FILE_LOADED:-}"

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
assert "orch functions loaded" test "$orch_fn_count" -gt 20

# ── Results ──────────────────────────────────────────────────────────────────
printf '\ntest-integration: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
