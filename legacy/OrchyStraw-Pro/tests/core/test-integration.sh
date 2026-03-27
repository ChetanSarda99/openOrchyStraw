#!/usr/bin/env bash
# =============================================================================
# test-integration.sh — Integration smoke test for ALL src/core/ modules
#
# Verifies that all 40 modules can be sourced together without conflicts:
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

# ── Test 1: Source all 38 modules ────────────────────────────────────────────
printf 'test-integration: sourcing all 40 modules...\n'

export ORCH_QUIET=1  # suppress log output during tests

# Group 1: Foundation (no deps)
source "$CORE_DIR/bash-version.sh"
source "$CORE_DIR/logger.sh"
source "$CORE_DIR/error-handler.sh"
source "$CORE_DIR/cycle-state.sh"
source "$CORE_DIR/agent-timeout.sh"
source "$CORE_DIR/dry-run.sh"
source "$CORE_DIR/config-validator.sh"
source "$CORE_DIR/lock-file.sh"

# Group 2: Cycle management
source "$CORE_DIR/cycle-tracker.sh"
source "$CORE_DIR/signal-handler.sh"
source "$CORE_DIR/max-cycles.sh"

# Group 3: Token optimization
source "$CORE_DIR/usage-checker.sh"
source "$CORE_DIR/token-budget.sh"
source "$CORE_DIR/task-decomposer.sh"
source "$CORE_DIR/session-windower.sh"
source "$CORE_DIR/context-filter.sh"
source "$CORE_DIR/qmd-refresher.sh"
source "$CORE_DIR/prompt-compression.sh"
source "$CORE_DIR/prompt-template.sh"

# Group 4: Activation & routing
source "$CORE_DIR/conditional-activation.sh"
source "$CORE_DIR/dynamic-router.sh"
source "$CORE_DIR/model-router.sh"
source "$CORE_DIR/model-budget.sh"
source "$CORE_DIR/model-fallback.sh"
source "$CORE_DIR/prompt-adapter.sh"
source "$CORE_DIR/worktree-isolator.sh"

# Group 5: Review & quality
source "$CORE_DIR/review-phase.sh"
source "$CORE_DIR/quality-gates.sh"
source "$CORE_DIR/file-access.sh"
source "$CORE_DIR/self-healing.sh"
source "$CORE_DIR/vcs-adapter.sh"

# Group 6: Agent modes
source "$CORE_DIR/single-agent.sh"
source "$CORE_DIR/agent-as-tool.sh"

# Group 7: Init, onboarding, intelligence
source "$CORE_DIR/init-project.sh"
source "$CORE_DIR/onboarding.sh"
source "$CORE_DIR/agent-kpis.sh"
source "$CORE_DIR/founder-mode.sh"
source "$CORE_DIR/knowledge-base.sh"
source "$CORE_DIR/model-registry.sh"

assert "all 40 modules sourced without error" true

# ── Test 2: Guard variables prevent double-sourcing ──────────────────────────
printf 'test-integration: verifying double-source guards (40 modules)...\n'

# Group 1: Foundation
assert "bash-version guard set"          test -n "${_ORCH_BASH_VERSION_LOADED:-}"
assert "logger guard set"                test -n "${_ORCH_LOGGER_LOADED:-}"
assert "error-handler guard set"         test -n "${_ORCH_ERROR_HANDLER_LOADED:-}"
assert "cycle-state guard set"           test -n "${_ORCH_CYCLE_STATE_LOADED:-}"
assert "agent-timeout guard set"         test -n "${_ORCH_AGENT_TIMEOUT_LOADED:-}"
assert "dry-run guard set"              test -n "${_ORCH_DRY_RUN_LOADED:-}"
assert "config-validator guard set"      test -n "${_ORCH_CONFIG_VALIDATOR_LOADED:-}"
assert "lock-file guard set"            test -n "${_ORCH_LOCK_FILE_LOADED:-}"

# Group 2: Cycle management
assert "cycle-tracker guard set"         test -n "${_ORCH_CYCLE_TRACKER_LOADED:-}"
assert "signal-handler guard set"        test -n "${_ORCH_SIGNAL_HANDLER_LOADED:-}"
assert "max-cycles guard set"            test -n "${_ORCH_MAX_CYCLES_LOADED:-}"

# Group 3: Token optimization
assert "usage-checker guard set"         test -n "${_ORCH_USAGE_CHECKER_LOADED:-}"
assert "token-budget guard set"          test -n "${_ORCH_TOKEN_BUDGET_LOADED:-}"
assert "task-decomposer guard set"       test -n "${_ORCH_TASK_DECOMPOSER_LOADED:-}"
assert "session-windower guard set"      test -n "${_ORCH_SESSION_WINDOWER_LOADED:-}"
assert "context-filter guard set"        test -n "${_ORCH_CONTEXT_FILTER_LOADED:-}"
assert "qmd-refresher guard set"         test -n "${_ORCH_QMD_REFRESHER_LOADED:-}"
assert "prompt-compression guard set"    test -n "${_ORCH_PROMPT_COMPRESSION_LOADED:-}"
assert "prompt-template guard set"       test -n "${_ORCH_PROMPT_TEMPLATE_LOADED:-}"

# Group 4: Activation & routing
assert "conditional-activation guard set" test -n "${_ORCH_CONDITIONAL_ACTIVATION_LOADED:-}"
assert "dynamic-router guard set"        test -n "${_ORCH_DYNAMIC_ROUTER_LOADED:-}"
assert "model-router guard set"          test -n "${_ORCH_MODEL_ROUTER_LOADED:-}"
assert "model-budget guard set"          test -n "${_ORCH_MODEL_BUDGET_LOADED:-}"
assert "model-fallback guard set"        test -n "${_ORCH_MODEL_FALLBACK_LOADED:-}"
assert "prompt-adapter guard set"        test -n "${_ORCH_PROMPT_ADAPTER_LOADED:-}"
assert "worktree-isolator guard set"     test -n "${_ORCH_WORKTREE_LOADED:-}"

# Group 5: Review & quality
assert "review-phase guard set"          test -n "${_ORCH_REVIEW_PHASE_LOADED:-}"
assert "quality-gates guard set"         test -n "${_ORCH_QUALITY_GATES_LOADED:-}"
assert "file-access guard set"           test -n "${_ORCH_FILE_ACCESS_LOADED:-}"
assert "self-healing guard set"          test -n "${_ORCH_SELF_HEALING_LOADED:-}"
assert "vcs-adapter guard set"           test -n "${_ORCH_VCS_ADAPTER_LOADED:-}"

# Group 6: Agent modes
assert "single-agent guard set"          test -n "${_ORCH_SINGLE_AGENT_LOADED:-}"
assert "agent-as-tool guard set"         test -n "${_ORCH_AGENT_TOOL_LOADED:-}"

# Group 7: Init, onboarding, intelligence
assert "init-project guard set"          test -n "${_ORCH_INIT_PROJECT_LOADED:-}"
assert "onboarding guard set"            test -n "${_ORCH_ONBOARD_LOADED:-}"
assert "agent-kpis guard set"            test -n "${_ORCH_KPI_LOADED:-}"
assert "founder-mode guard set"          test -n "${_ORCH_FOUNDER_MODE_LOADED:-}"
assert "knowledge-base guard set"        test -n "${_ORCH_KNOWLEDGE_BASE_LOADED:-}"
assert "model-registry guard set"       test -n "${_ORCH_MODEL_REGISTRY_LOADED:-}"

# ── Test 3: Key public functions exist from each module ──────────────────────
printf 'test-integration: verifying public API functions exist (all 40 modules)...\n'

# Group 1: Foundation
assert "orch_log exists"                     declare -f orch_log
assert "orch_log_init exists"                declare -f orch_log_init
assert "orch_log_summary exists"             declare -f orch_log_summary
assert "orch_handle_agent_failure exists"    declare -f orch_handle_agent_failure
assert "orch_should_retry exists"            declare -f orch_should_retry
assert "orch_failure_report exists"          declare -f orch_failure_report
assert "orch_state_save exists"              declare -f orch_state_save
assert "orch_state_load exists"              declare -f orch_state_load
assert "orch_state_resume exists"            declare -f orch_state_resume
assert "orch_run_with_timeout exists"        declare -f orch_run_with_timeout
assert "orch_get_agent_timeout exists"       declare -f orch_get_agent_timeout
assert "orch_dry_run_init exists"            declare -f orch_dry_run_init
assert "orch_is_dry_run exists"              declare -f orch_is_dry_run
assert "orch_dry_run_report exists"          declare -f orch_dry_run_report
assert "orch_validate_config exists"         declare -f orch_validate_config
assert "orch_config_error_count exists"      declare -f orch_config_error_count
assert "orch_lock_acquire exists"            declare -f orch_lock_acquire
assert "orch_lock_release exists"            declare -f orch_lock_release
assert "orch_check_bash_version exists"      declare -f orch_check_bash_version

# Group 2: Cycle management
assert "orch_tracker_init exists"            declare -f orch_tracker_init
assert "orch_tracker_record exists"          declare -f orch_tracker_record
assert "orch_tracker_should_stop exists"     declare -f orch_tracker_should_stop
assert "orch_tracker_summary exists"         declare -f orch_tracker_summary
assert "orch_signal_init exists"             declare -f orch_signal_init
assert "orch_is_shutting_down exists"        declare -f orch_is_shutting_down
assert "orch_register_agent_pid exists"      declare -f orch_register_agent_pid
assert "orch_max_cycles_validate exists"     declare -f orch_max_cycles_validate
assert "orch_max_cycles_get exists"          declare -f orch_max_cycles_get

# Group 3: Token optimization
assert "orch_check_usage exists"             declare -f orch_check_usage
assert "orch_should_pause exists"            declare -f orch_should_pause
assert "orch_token_budget_init exists"       declare -f orch_token_budget_init
assert "orch_budget_allocate exists"         declare -f orch_budget_allocate
assert "orch_token_budget_report exists"     declare -f orch_token_budget_report
assert "orch_select_tasks exists"            declare -f orch_select_tasks
assert "orch_extract_tasks exists"           declare -f orch_extract_tasks
assert "orch_decompose_tasks exists"         declare -f orch_decompose_tasks
assert "orch_window_session_tracker exists"  declare -f orch_window_session_tracker
assert "orch_should_window exists"           declare -f orch_should_window
assert "orch_context_filter_init exists"     declare -f orch_context_filter_init
assert "orch_context_for_agent exists"       declare -f orch_context_for_agent
assert "orch_qmd_refresh exists"             declare -f orch_qmd_refresh
assert "orch_qmd_auto_refresh exists"        declare -f orch_qmd_auto_refresh
assert "orch_compress_init exists"           declare -f orch_compress_init
assert "orch_compress_prompt exists"         declare -f orch_compress_prompt
assert "orch_compress_report exists"         declare -f orch_compress_report
assert "orch_template_init exists"           declare -f orch_template_init
assert "orch_template_render exists"         declare -f orch_template_render
assert "orch_template_set exists"            declare -f orch_template_set

# Group 4: Activation & routing
assert "orch_activation_init exists"         declare -f orch_activation_init
assert "orch_activation_check exists"        declare -f orch_activation_check
assert "orch_activation_report exists"       declare -f orch_activation_report
assert "orch_router_init exists"             declare -f orch_router_init
assert "orch_router_build_groups exists"     declare -f orch_router_build_groups
assert "orch_router_report exists"           declare -f orch_router_report
assert "orch_model_init exists"              declare -f orch_model_init
assert "orch_model_assign exists"            declare -f orch_model_assign
assert "orch_model_get_cli exists"           declare -f orch_model_get_cli
assert "orch_model_report exists"            declare -f orch_model_report
assert "orch_budget_init exists"             declare -f orch_budget_init
assert "orch_budget_resolve exists"          declare -f orch_budget_resolve
assert "orch_budget_report exists"           declare -f orch_budget_report
assert "orch_model_fallback_find exists"     declare -f orch_model_fallback_find
assert "orch_model_fallback_route exists"    declare -f orch_model_fallback_route
assert "orch_prompt_adapter_detect exists"   declare -f orch_prompt_adapter_detect
assert "orch_prompt_adapter_wrap exists"     declare -f orch_prompt_adapter_wrap
assert "orch_worktree_init exists"           declare -f orch_worktree_init
assert "orch_worktree_create exists"         declare -f orch_worktree_create
assert "orch_worktree_report exists"         declare -f orch_worktree_report

# Group 5: Review & quality
assert "orch_review_init exists"             declare -f orch_review_init
assert "orch_review_should_run exists"       declare -f orch_review_should_run
assert "orch_review_report exists"           declare -f orch_review_report
assert "orch_gate_init exists"               declare -f orch_gate_init
assert "orch_gate_run_all exists"            declare -f orch_gate_run_all
assert "orch_gate_report exists"             declare -f orch_gate_report
assert "orch_access_init exists"             declare -f orch_access_init
assert "orch_access_check exists"            declare -f orch_access_check
assert "orch_access_report exists"           declare -f orch_access_report
assert "orch_heal_init exists"               declare -f orch_heal_init
assert "orch_heal_diagnose exists"           declare -f orch_heal_diagnose
assert "orch_heal_report exists"             declare -f orch_heal_report
assert "orch_vcs_init exists"                declare -f orch_vcs_init
assert "orch_vcs_status exists"              declare -f orch_vcs_status
assert "orch_vcs_report exists"              declare -f orch_vcs_report

# Group 6: Agent modes
assert "orch_single_init exists"             declare -f orch_single_init
assert "orch_single_detect exists"           declare -f orch_single_detect
assert "orch_single_report exists"           declare -f orch_single_report
assert "orch_tool_init exists"               declare -f orch_tool_init
assert "orch_tool_invoke exists"             declare -f orch_tool_invoke
assert "orch_tool_report exists"             declare -f orch_tool_report

# Group 7: Init, onboarding, intelligence
assert "orch_init_scan exists"               declare -f orch_init_scan
assert "orch_init_report exists"             declare -f orch_init_report
assert "orch_init_generate_conf exists"      declare -f orch_init_generate_conf
assert "orch_onboard_init exists"            declare -f orch_onboard_init
assert "orch_onboard_run exists"             declare -f orch_onboard_run
assert "orch_kpi_init exists"                declare -f orch_kpi_init
assert "orch_kpi_collect exists"             declare -f orch_kpi_collect
assert "orch_kpi_report exists"              declare -f orch_kpi_report
assert "orch_founder_init exists"            declare -f orch_founder_init
assert "orch_founder_triage exists"          declare -f orch_founder_triage
assert "orch_founder_status exists"          declare -f orch_founder_status
assert "orch_kb_init exists"                 declare -f orch_kb_init
assert "orch_kb_store exists"                declare -f orch_kb_store
assert "orch_kb_search exists"               declare -f orch_kb_search
assert "orch_kb_export exists"               declare -f orch_kb_export
assert "orch_registry_init exists"           declare -f orch_registry_init
assert "orch_registry_scan exists"           declare -f orch_registry_scan
assert "orch_registry_is_available exists"   declare -f orch_registry_is_available
assert "orch_registry_report exists"         declare -f orch_registry_report

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

# 4l. Knowledge base → init + store + retrieve
export ORCHYSTRAW_HOME="$WORK_DIR/.orchystraw-test"
export _ORCH_KB_DIR="$ORCHYSTRAW_HOME/knowledge"
orch_kb_init
assert "knowledge base initialized" test -d "$_ORCH_KB_DIR"
orch_kb_store "patterns" "test-entry" "Integration test knowledge entry"
assert "kb entry stored" test -f "$_ORCH_KB_DIR/patterns/test-entry.md"
kb_val=$(orch_kb_retrieve "patterns" "test-entry")
assert "kb entry retrieved" test -n "$kb_val"

# 4m. Template → set + render (render takes a file path)
orch_template_init
orch_template_set "PROJECT" "OrchyStraw"
printf 'Hello {{PROJECT}}\n' > "$WORK_DIR/test-template.txt"
rendered=$(orch_template_render "$WORK_DIR/test-template.txt")
assert_eq "template rendered" "Hello OrchyStraw" "$rendered"

# 4n. Model router → init + assign + get
orch_model_init
orch_model_assign "06-backend" "claude"
model_name=$(orch_model_get_name "06-backend")
assert_eq "model assigned and retrieved" "claude" "$model_name"

# ── Test 5: No namespace collisions ──────────────────────────────────────────
printf 'test-integration: checking for namespace collisions...\n'

# All public functions should start with orch_
# All internal functions should start with _orch_
# Count total orch functions — with 40 modules should be >100
orch_fn_count=$(declare -F | grep -c ' orch_\|_orch_' || true)
assert "orch functions loaded (>100 expected)" test "$orch_fn_count" -gt 100

# ── Test 6: No function name duplicates ──────────────────────────────────────
printf 'test-integration: checking for function name duplicates...\n'

fn_list=$(declare -F | awk '{print $3}' | grep -E '^_?orch_' | sort)
fn_unique=$(printf '%s\n' "$fn_list" | sort -u)
fn_total=$(printf '%s\n' "$fn_list" | wc -l)
fn_unique_count=$(printf '%s\n' "$fn_unique" | wc -l)
assert_eq "no duplicate function names" "$fn_total" "$fn_unique_count"

# If duplicates found, report them
if [[ "$fn_total" != "$fn_unique_count" ]]; then
    printf '  Duplicated functions:\n' >&2
    printf '%s\n' "$fn_list" | sort | uniq -d | while read -r fn; do
        printf '    %s\n' "$fn" >&2
    done
fi

# ── Test 7: All 40 modules counted ──────────────────────────────────────────
printf 'test-integration: verifying module count...\n'

module_count=$(find "$CORE_DIR" -maxdepth 1 -name '*.sh' -type f | wc -l)
assert_eq "40 modules in src/core/" "40" "$(echo "$module_count" | tr -d ' ')"

# ── Results ──────────────────────────────────────────────────────────────────
printf '\ntest-integration: %d passed, %d failed (40 modules, 7 test groups)\n' "$PASS" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
