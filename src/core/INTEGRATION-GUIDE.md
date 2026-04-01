# Core Modules — Integration Guide

> For CS (the human operator) to integrate `src/core/*.sh` into `auto-agent.sh`.
> Agents cannot modify `auto-agent.sh` — this guide documents exactly what to change.

## Module Overview

| Module | File | Purpose | Dependencies |
|--------|------|---------|-------------|
| bash-version | `bash-version.sh` | Exit early if bash < 5.0 | None (source first) |
| logger | `logger.sh` | Structured leveled logging | None |
| error-handler | `error-handler.sh` | Agent failure tracking + retry | None |
| cycle-state | `cycle-state.sh` | Persist/resume cycle number | None |
| agent-timeout | `agent-timeout.sh` | Per-agent timeout with SIGTERM→SIGKILL | None |
| dry-run | `dry-run.sh` | `--dry-run` preview mode | None |
| config-validator | `config-validator.sh` | Validate agents.conf syntax | None |
| lock-file | `lock-file.sh` | Prevent concurrent orchestrators | None |
| signal-handler | `signal-handler.sh` | Graceful shutdown with SHUTTING_DOWN flag | None (optional: logger) |
| cycle-tracker | `cycle-tracker.sh` | Smart empty cycle detection | None |
| dynamic-router | `dynamic-router.sh` | Dynamic routing + dependency groups + model tiering | config-validator, cycle-tracker |
| review-phase | `review-phase.sh` | QA auto-rerun with cost guard | logger, config-validator |
| worktree | `worktree.sh` | Git worktree isolation per agent (WORKTREE-001) | None (optional: logger) |
| prompt-compression | `prompt-compression.sh` | Tiered prompt loading (stable/dynamic/reference) | None (optional: logger) |
| conditional-activation | `conditional-activation.sh` | Skip agents with no work (change detection) | None (optional: logger) |
| differential-context | `differential-context.sh` | Per-agent context filtering (#49) | None (optional: logger) |
| session-tracker | `session-tracker.sh` | Smart session tracker windowing (#52) | None (optional: logger) |
| qmd-refresher | `qmd-refresher.sh` | Auto-refresh QMD index each cycle (#53) | None |
| prompt-template | `prompt-template.sh` | Template inheritance for prompts (#54) | None (optional: logger) |
| task-decomposer | `task-decomposer.sh` | Progressive task decomposition (#50) | None |
| init-project | `init-project.sh` | Project analyzer & agent blueprint (#45) | None |

All modules are independently sourceable. No module depends on another.

---

## Step 0: Add `set -e` at auto-agent.sh line 23

CTO requested (BASH-001 ADR) that `set -e` be added early in `auto-agent.sh` so any
uncaught error terminates the script immediately instead of silently continuing.

Add this line at **line 23** of `auto-agent.sh` (after the shebang and initial comments,
before any logic):

```bash
set -euo pipefail
```

- `set -e` — exit on any command failure
- `set -u` — treat unset variables as errors
- `set -o pipefail` — propagate failures through pipelines

**Important:** After adding this, verify that every function in `auto-agent.sh` that
intentionally handles errors uses `|| true` or `|| return` to suppress `set -e` tripping.
The core modules already follow this pattern (e.g., `(( count++ )) || true`).

---

## Step 1: Source modules at the top of auto-agent.sh

Add these lines near the top of `auto-agent.sh`, after the `SCRIPT_DIR` variable is set:

```bash
# ── Core modules ─────────────────────────────────────────────────────────
source "$SCRIPT_DIR/../src/core/bash-version.sh"   # exits if bash < 5.0
source "$SCRIPT_DIR/../src/core/logger.sh"
source "$SCRIPT_DIR/../src/core/error-handler.sh"
source "$SCRIPT_DIR/../src/core/cycle-state.sh"
source "$SCRIPT_DIR/../src/core/agent-timeout.sh"
source "$SCRIPT_DIR/../src/core/dry-run.sh"
source "$SCRIPT_DIR/../src/core/config-validator.sh"
source "$SCRIPT_DIR/../src/core/lock-file.sh"
```

## Step 2: Initialize modules before the main loop

```bash
# Initialize logging
orch_log_init "$SCRIPT_DIR/../logs"

# Initialize dry-run mode (pass through CLI args)
orch_dry_run_init "$@"

# Acquire lock (prevents concurrent runs)
orch_lock_acquire || exit 1

# Validate config before running
if ! orch_validate_config "$CONF_FILE"; then
    orch_log ERROR orchestrator "Config validation failed ($(orch_config_error_count) errors)"
    orch_lock_release
    exit 1
fi

# Load cycle state for resume logic
orch_state_load

# Dry-run: show preview and exit
if orch_is_dry_run; then
    orch_dry_run_report "$CONF_FILE" "${ORCH_LAST_CYCLE:-1}"
    orch_lock_release
    exit 0
fi
```

## Step 3: Replace the existing `log()` calls

The existing `log()` function (line 45-49) can be replaced by the logger module.

**Old:**
```bash
log() {
    local msg="[$(timestamp)] $1"
    echo "$msg"
    echo "$msg" >> "$CYCLE_LOG"
}
```

**New:** Replace `log "message"` calls with `orch_log INFO orchestrator "message"` throughout.

## Step 4: Add cleanup trap

```bash
cleanup() {
    orch_log INFO orchestrator "Shutting down..."
    orch_lock_release
    orch_log_summary
}
trap cleanup EXIT INT TERM
```

## Step 5: Use cycle-state for resume

Replace the hardcoded cycle counter with:

```bash
local cycle_num
cycle_num=$(orch_state_resume)

# At cycle start:
orch_state_save "$cycle_num" running

# At cycle end (success):
orch_state_save "$cycle_num" completed

# At cycle end (failure):
orch_state_save "$cycle_num" failed
```

## Step 6: Use agent-timeout in run_agent()

Wrap the Claude Code invocation with the timeout function:

```bash
local timeout_secs
timeout_secs=$(orch_get_agent_timeout "$agent_id")
orch_run_with_timeout "$timeout_secs" claude --prompt "$prompt_content" ...
local exit_code=$?

if [[ $exit_code -eq 124 ]]; then
    _orch_record_timeout "$agent_id"
    orch_log WARN orchestrator "$agent_id timed out after ${timeout_secs}s"
fi
```

## Step 7: Use error-handler in run_agent()

After an agent fails:

```bash
if [[ $exit_code -ne 0 ]]; then
    orch_handle_agent_failure "$agent_id" "$exit_code" "$agent_log"
    local fail_count="${_ORCH_FAILURES["${agent_id}:count"]:-0}"
    if orch_should_retry "$agent_id" "$fail_count"; then
        # re-queue the agent
    fi
fi
```

At cycle end, print the failure report:

```bash
orch_failure_report "$cycle_num"
```

---

## Step 8: Source v0.2.0 modules

Add after the v0.1.0 sources in Step 1:

```bash
# ── v0.2.0 modules ──────────────────────────────────────────────────────
source "$SCRIPT_DIR/../src/core/signal-handler.sh"
source "$SCRIPT_DIR/../src/core/cycle-tracker.sh"
source "$SCRIPT_DIR/../src/core/dynamic-router.sh"
source "$SCRIPT_DIR/../src/core/review-phase.sh"
source "$SCRIPT_DIR/../src/core/worktree.sh"
source "$SCRIPT_DIR/../src/core/prompt-compression.sh"
source "$SCRIPT_DIR/../src/core/conditional-activation.sh"
source "$SCRIPT_DIR/../src/core/differential-context.sh"
```

## Step 9: Initialize worktree mode (opt-in)

Parse `--worktree` CLI flag and initialize:

```bash
# Parse CLI flag
ORCH_WORKTREE=false
for arg in "$@"; do
    [[ "$arg" == "--worktree" ]] && ORCH_WORKTREE=true
done
export ORCH_WORKTREE

# Initialize if enabled
if orch_worktree_enabled; then
    orch_worktree_init "$PROJECT_ROOT" || exit 1
fi
```

## Step 10: Use worktrees in the execution loop

Replace the shared-tree agent loop with worktree-aware execution:

```bash
if orch_worktree_enabled; then
    # Per execution group (from dynamic-router):
    for group in $(orch_router_groups); do
        IFS=',' read -ra agents <<< "$group"

        # 1. Create worktrees for all agents in group
        declare -A agent_wt_paths=()
        for id in "${agents[@]}"; do
            agent_wt_paths["$id"]=$(orch_worktree_create "$id" "$cycle_num")
        done

        # 2. Run agents in parallel (each in its own worktree)
        for id in "${agents[@]}"; do
            PROJECT_ROOT="${agent_wt_paths[$id]}" run_agent "$id" &
        done
        wait

        # 3. Merge back sequentially (order matters for conflict detection)
        for id in "${agents[@]}"; do
            if ! orch_worktree_merge "$id" "$cycle_num"; then
                orch_log WARN orchestrator "Merge conflict for $id — flagging for PM"
            fi
        done
    done
else
    # v0.1 shared-tree execution (existing code)
    ...
fi
```

**IMPORTANT (DR-SEC-02):** When passing `orch_router_model` output to claude CLI,
always quote it: `--model "$(orch_router_model "$id")"`. Unquoted model output could
allow injection if the model field in agents.conf is tampered with.

## Step 11: Register worktree cleanup with signal handler

```bash
# In the cleanup/shutdown handler:
if orch_worktree_enabled; then
    orch_worktree_cleanup "$cycle_num"
fi
```

This ensures worktrees are removed on SIGTERM/SIGINT (crash recovery).

## Step 12: Use differential context for per-agent context filtering

Initialize once before the agent loop, then filter context per-agent:

```bash
# Initialize with agents.conf (parses dependencies for history filtering)
orch_diffctx_init "$CONF_FILE"

# Parse shared context once per cycle
orch_diffctx_parse "$PROJECT_ROOT/prompts/00-shared-context/context.md"
```

In the `run_agent()` function, pass filtered context instead of the full file:

```bash
# Instead of injecting full context.md into the prompt:
local filtered_context
filtered_context=$(orch_diffctx_filter "$agent_id")

# If using cross-cycle history, filter that too:
local history_content
history_content=$(cat "$PROJECT_ROOT/prompts/00-shared-context/context-cycle-*.md" 2>/dev/null)
local filtered_history
filtered_history=$(orch_diffctx_filter_history "$agent_id" "$history_content")

# Inject filtered_context + filtered_history into the agent's prompt
```

This saves 30-60% of context tokens for agents that don't need all sections.
PM always gets the full unfiltered context.

---

## Step 13: Use session tracker windowing for cross-cycle history

Replace the static `tail -150` on SESSION_TRACKER.txt (line 185) with smart windowing:

```bash
source "$SCRIPT_DIR/../src/core/session-tracker.sh"

# Initialize once before the agent loop (after sourcing modules)
orch_session_init 2 8  # 2 recent cycles full, 8 summary rows
```

In the prompt assembly section, replace:

```bash
# OLD (static):
tail -150 "$tracker_file"
```

With:

```bash
# NEW (smart windowing):
orch_session_window "$tracker_file"
```

This replaces the static `tail -150` with dynamic windowing:
- Last 2 cycles: full "WHAT SHIPPED" detail
- Next 8 cycles: one-line table row summaries
- Older cycles: omitted entirely
- MILESTONE DASHBOARD, CODEBASE SIZE, NEXT CYCLE PRIORITIES: always preserved

Result: ~80 lines output regardless of project age (vs 500+ lines at cycle 50).

---

## Step 14: Single-Agent Mode (`--single-agent`)

Source the single-agent module and add a new subcommand:

```bash
# ── v0.2.1 modules ─────────────────────────────────────────────────────
source "$SCRIPT_DIR/../src/core/single-agent.sh"
```

### Add `single` subcommand to the `case` block (line ~599)

```bash
    single)
        parse_config
        local AGENT_ID="${3:-}"
        local SA_MAX="${4:-$MAX_CYCLES}"

        # Source single-agent module
        source "$PROJECT_ROOT/src/core/single-agent.sh"
        orch_single_init "$PROJECT_ROOT" "$CONF_FILE"

        # Resolve agent (explicit or auto-detect)
        local SINGLE_AGENT
        if [[ -n "$AGENT_ID" ]]; then
            SINGLE_AGENT=$(orch_single_get_agent "$CONF_FILE" "$AGENT_ID")
        else
            SINGLE_AGENT=$(orch_single_get_agent "$CONF_FILE")
        fi
        orch_single_set_agent "$SINGLE_AGENT"

        echo "╔══════════════════════════════════════════════════╗"
        echo "║  orchystraw — single-agent mode                  ║"
        echo "║  Agent: $SINGLE_AGENT │ Max: $SA_MAX cycles      ║"
        echo "╚══════════════════════════════════════════════════╝"
        notify "Single-agent mode: $SINGLE_AGENT, max $SA_MAX cycles"

        CYCLE=1
        declare -a AGENT_PIDS=()

        while true; do
            log "━━━ CYCLE $CYCLE (single: $SINGLE_AGENT) ━━━"

            # Usage check
            bash "$PROJECT_ROOT/scripts/check-usage.sh" 2>/dev/null
            usage_file="$PROMPTS_DIR/00-shared-context/usage.txt"
            if [ -f "$usage_file" ]; then
                usage_pct=$(cat "$usage_file" 2>/dev/null | grep -oE '[0-9]+' | head -1)
                if [ -n "$usage_pct" ] && [ "$usage_pct" -ge 70 ] 2>/dev/null; then
                    log "PAUSED: usage at ${usage_pct}%"
                    sleep 60
                    continue
                fi
            fi

            # Create cycle branch
            git checkout main 2>/dev/null
            git pull origin main 2>/dev/null || true
            CYCLE_BRANCH=$(create_cycle_branch "$CYCLE")

            # Run the single agent (no PM, no review, no routing)
            run_agent "$SINGLE_AGENT"

            # Commit by ownership
            commit_by_ownership "$SINGLE_AGENT" && COMMITS=1 || COMMITS=0
            detect_rogue_writes

            # Merge to main
            merge_cycle_branch "$CYCLE_BRANCH" "$CYCLE"

            # Track cycle
            orch_single_increment_cycle
            log "CYCLE $CYCLE DONE — $COMMITS commits"
            notify "Cycle $CYCLE done (single-agent: $SINGLE_AGENT)"

            if [ "$SA_MAX" -gt 0 ] && [ "$CYCLE" -ge "$SA_MAX" ]; then
                log "Max cycles reached ($CYCLE/$SA_MAX)"
                break
            fi
            CYCLE=$((CYCLE + 1))
            sleep 5
        done

        orch_single_report
        ;;
```

### Usage

```bash
# Auto-detect single agent from agents.conf (must have exactly 1 worker)
./scripts/auto-agent.sh single

# Specify agent explicitly (works with multi-agent configs)
./scripts/auto-agent.sh single 06-backend

# With max cycles
./scripts/auto-agent.sh single 06-backend 5
```

### Update help text

Add to the help `case` block:

```bash
echo "  single [agent-id] [max-cycles=10]            Single-agent loop (Ralph-compatible)"
```

### What's skipped in single-agent mode

| Module | Skipped? | Reason |
|--------|----------|--------|
| review-phase | Yes | No QA review needed for 1 agent |
| dynamic-router | Yes | No routing with 1 agent |
| worktree | Yes | No isolation needed |
| conditional-activation | Yes | Single agent always runs |
| differential-context | Yes | No cross-agent filtering |
| logger | No | Still useful |
| error-handler | No | Still useful |
| cycle-state | No | Resume support |
| agent-timeout | No | Timeout protection |
| prompt-compression | No | Token savings still apply |
| session-tracker | No | History tracking still useful |
| signal-handler | No | Graceful shutdown |
| cycle-tracker | No | Empty cycle detection |

---

## Security Fixes — Status

All v0.1.0 security fixes have been applied by CS.

| Issue | Status | Commit |
|-------|--------|--------|
| HIGH-01 | ✅ APPLIED | d130de7 — array-based pathspec, no eval |
| HIGH-03 | ✅ APPLIED | 601c9a2 — IFS+read -ra for ownership loops |
| HIGH-04 | ✅ APPLIED | 601c9a2 — \| delimiter + & escaping in sed |
| MEDIUM-01 | ✅ APPLIED | 601c9a2 — .gitignore secrets patterns |
| MEDIUM-02 | ✅ APPLIED | d130de7 — env var for PowerShell notify |

All 11 tests pass (10 unit + 1 integration, 42+ assertions). No regressions.

---

## Security Fix Reference (for audit trail)

### [HIGH-01] Fix eval injection in commit_by_ownership()

**Location:** `auto-agent.sh` lines 222-241

**Problem:** `eval` on user-controlled ownership paths allows command injection.

**Current (vulnerable):**
```bash
local changes=$(eval "git diff --name-only -- $include_paths $exclude_paths" 2>/dev/null | wc -l | tr -d ' ')
local untracked=$(eval "git ls-files --others --exclude-standard -- $include_paths $exclude_paths" 2>/dev/null | wc -l | tr -d ' ')
# ...
eval "git add -- $include_paths $exclude_paths" 2>/dev/null
```

**Fixed (array-based):**
```bash
commit_by_ownership() {
    local agent_id="$1"
    local ownership="$2"

    # Build arrays instead of strings
    local -a include_args=()
    local -a exclude_args=()

    for path in $ownership; do
        if [[ "$path" == !* ]]; then
            exclude_args+=(":(exclude)${path#!}")
        else
            include_args+=("$path")
        fi
    done

    if [[ ${#include_args[@]} -eq 0 ]]; then return 0; fi

    local -a pathspec=("--" "${include_args[@]}" "${exclude_args[@]}")

    local changes untracked
    changes=$(git diff --name-only "${pathspec[@]}" 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git ls-files --others --exclude-standard "${pathspec[@]}" 2>/dev/null | wc -l | tr -d ' ')
    local total=$((changes + untracked))

    if [[ "$total" -gt 0 ]]; then
        git add "${pathspec[@]}" 2>/dev/null
        git commit -m "feat($agent_id): auto-cycle $(date '+%m-%d %H:%M') — $total files" 2>/dev/null
        log "[$agent_id] Committed $total files"
        return 0
    fi
    return 1
}
```

**Key changes:**
- Replace `eval "git ... $include_paths $exclude_paths"` with array expansion `"${pathspec[@]}"`
- Use git's `:(exclude)` pathspec syntax instead of shell-quoted `':!path'`
- No `eval` anywhere — paths are never interpreted as shell code

### [MEDIUM-02] Fix PowerShell notify unescaped variable

**Location:** `auto-agent.sh` line 62

**Problem:** `$escaped_title` is interpolated inside a double-quoted string passed to PowerShell. If the title contains PowerShell metacharacters (e.g., `$(...)`, `` ` ``), they could be executed.

**Current:**
```bash
\$template = '...<text id=\"2\">$escaped_title</text>...'
```

**Fixed:** Use printf to inject the value into the PowerShell command safely:
```bash
notify() {
    local title="${1:-orchystraw}"
    local level="${2:-info}"
    local ps_exe="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

    if [ -x "$ps_exe" ]; then
        # Sanitize for XML: escape &, <, >, ", '
        local safe_title
        safe_title=$(printf '%s' "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')

        # Pass title via environment variable to avoid shell injection
        ORCH_TOAST_TITLE="$safe_title" "$ps_exe" -NoProfile -Command '
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
$title = $env:ORCH_TOAST_TITLE
$template = "<toast><visual><binding template=`"ToastText02`"><text id=`"1`">orchystraw</text><text id=`"2`">$title</text></binding></visual></toast>"
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("orchystraw").Show($toast)
' 2>/dev/null &
    fi

    log "NOTIFY [$level]: $title"
}
```

**Key changes:**
- Pass the title via `$env:ORCH_TOAST_TITLE` (environment variable) instead of shell interpolation
- Use single-quoted PowerShell command block so bash doesn't expand anything
- Added `-NoProfile` for faster startup

---

### [HIGH-03] Fix unquoted `$ownership` in for loops (Cycle 6)

**Location:** `auto-agent.sh` lines 236, 310, 320
**Problem:** `for path in $ownership` is unquoted — shell performs word-splitting AND glob expansion. A path like `src/*.sh` in agents.conf would expand to actual filenames.

**Fix — Line 236** (in `commit_by_ownership()`):

Replace:
```bash
    for path in $ownership; do
```

With:
```bash
    IFS=' ' read -ra _ownership_arr <<< "$ownership"
    for path in "${_ownership_arr[@]}"; do
```

**Fix — Lines 306-313** (in `detect_rogue_writes()`):

Replace:
```bash
    local all_owned=""
    for id in "${AGENT_IDS[@]}"; do
        local ownership="${AGENT_OWNERSHIP[$id]}"
        [ "$ownership" = "none" ] && continue
        for path in $ownership; do
            [[ "$path" == !* ]] && continue
            all_owned+=" $path"
        done
    done
```

With:
```bash
    local -a all_owned_arr=()
    for id in "${AGENT_IDS[@]}"; do
        local ownership="${AGENT_OWNERSHIP[$id]}"
        [ "$ownership" = "none" ] && continue
        IFS=' ' read -ra _own_arr <<< "$ownership"
        for path in "${_own_arr[@]}"; do
            [[ "$path" == !* ]] && continue
            all_owned_arr+=("$path")
        done
    done
```

**Fix — Line 320** (also in `detect_rogue_writes()`):

Replace:
```bash
        for path in $all_owned; do
```

With:
```bash
        for path in "${all_owned_arr[@]}"; do
```

**Why this works:** `read -ra` splits the string into an array at read time, then `"${arr[@]}"` iterates without glob expansion. Each element is individually quoted.

---

### [HIGH-04] Fix sed injection in prompt updates (Cycle 6)

**Location:** `auto-agent.sh` lines 785-791
**Problem:** Variables interpolated in sed with `/` delimiter. If any variable contains `/` or `&`, the sed command breaks or injects unintended content.

**Fix — Replace lines 785-791** with:

```bash
                # Escape sed special chars in variables
                local _safe_date _safe_time _safe_bsrc _safe_tc _safe_ts _safe_sw _safe_comp _safe_total
                _safe_date=$(printf '%s\n' "$(date '+%B %d, %Y')" | sed 's/[|&]/\\&/g')
                _safe_time=$(printf '%s\n' "${current_time}" | sed 's/[|&]/\\&/g')
                _safe_bsrc=$(printf '%s\n' "${backend_src}" | sed 's/[|&]/\\&/g')
                _safe_tc=$(printf '%s\n' "${test_count}" | sed 's/[|&]/\\&/g')
                _safe_ts=$(printf '%s\n' "${ts_count}" | sed 's/[|&]/\\&/g')
                _safe_sw=$(printf '%s\n' "${swift_count}" | sed 's/[|&]/\\&/g')
                _safe_comp=$(printf '%s\n' "${component_count}" | sed 's/[|&]/\\&/g')
                _safe_total=$(printf '%s\n' "$total" | sed 's/[|&]/\\&/g')

                # Use | delimiter to avoid / conflicts in date strings
                sed -i "s|\*\*Date:\*\* .*|\*\*Date:\*\* ${_safe_date} — ${_safe_time}|" "$pf" 2>/dev/null
                sed -i "s|[0-9]* TypeScript source + [0-9]* test files = [0-9]* total|${_safe_bsrc} TypeScript source + ${_safe_tc} test files = ${_safe_ts} total|" "$pf" 2>/dev/null
                sed -i "s|[0-9]* Swift files|${_safe_sw} Swift files|" "$pf" 2>/dev/null
                sed -i "s|[0-9]* components|${_safe_comp} components|" "$pf" 2>/dev/null
                sed -i "s|Total:.*source files|Total: ${_safe_total} source files|" "$pf" 2>/dev/null
```

**Why this works:**
- `|` delimiter means `/` in date strings (e.g., "March 18, 2026") won't break sed
- `&` is escaped so it won't be interpreted as "insert match"
- Numeric variables are sanitized too (defense in depth — if state files are corrupted)

---

### [MEDIUM-01] Fix .gitignore regression (Cycle 6)

**Location:** Root `.gitignore`
**Problem:** Missing patterns for secrets. Was reportedly fixed in cycle 2 but not present in current file.

**Fix — Append to root `.gitignore`:**

```gitignore
# Secrets & credentials
.env
.env.*
*.pem
*.key
*.p12
*.pfx
credentials.json
service-account*.json
*secret*.json

# App data
.orchystraw/
```

**Note:** `site/.gitignore` already covers `.env*` and `*.pem` for the Next.js project, but the root `.gitignore` must also cover repo-root files.

---

## Step 15: QMD Auto-Refresh (#53)

**Added:** Cycle 2, session 3 (March 30, 2026)
**Depends on:** None (optional: logger)

Source the module alongside the other v0.2.0+ modules:

```bash
source "$SCRIPT_DIR/../src/core/qmd-refresher.sh"
```

### Replace inline QMD logic (lines 690–703)

**Old** (inline in auto-agent.sh):
```bash
# ── Step 1.5: Refresh qmd index on QA cycles ──
if command -v qmd &>/dev/null; then
    qmd update 2>/dev/null
    for id_check in "${AGENT_IDS[@]}"; do
        interval_check="${AGENT_INTERVALS[$id_check]}"
        if [ "$interval_check" -gt 1 ] && { [ $((CYCLE % interval_check)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; }; then
            qmd embed 2>/dev/null
            log "qmd re-indexed + re-embedded for QA cycle"
            break
        fi
    done
fi
```

**New** (module call):
```bash
# ── Step 1.5: Refresh qmd index ──
orch_qmd_auto_refresh "false"
```

For QA cycles or forced re-embeds, pass `"true"`:
```bash
orch_qmd_auto_refresh "true"
```

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ORCH_STATE_DIR` | `.orchystraw` | State directory for timestamp files |
| `ORCH_QMD_EMBED_INTERVAL` | `300` | Seconds between vector re-embeds |

### State files

- `.orchystraw/qmd-last-update` — epoch of last `qmd update`
- `.orchystraw/qmd-last-embed` — epoch of last `qmd embed`

---

## Step 16: Benchmark Harness (BENCH-001)

**Added:** Cycle 3, session 2 (March 30, 2026)
**Depends on:** None (standalone, uses `claude` CLI directly)

The benchmark scaffold lives in `scripts/benchmark/` and runs independently of the orchestrator. No integration into `auto-agent.sh` needed.

### Directory structure

```
scripts/benchmark/
├── run-benchmark.sh          — Main entry point (all suites)
├── .gitignore                — Ignores results/ and reports/
├── lib/
│   ├── instance-runner.sh    — Runs one benchmark instance end-to-end
│   ├── cost-estimator.sh     — Estimates cost before running
│   └── results-collector.sh  — Aggregates JSONL → summary + markdown
├── custom/
│   ├── tasks.jsonl           — 5 custom tasks (Django, DRF, SymPy)
│   ├── ralph-baseline.sh     — Single-agent comparison runner
│   └── compare-ralph.sh      — Head-to-head OrchyStraw vs Ralph
├── swebench/
│   ├── scaffold.py           — Python bridge to SWE-bench evaluation
│   └── README.md             — Setup and usage
├── tasks/                    — Local task JSON files (SWE-bench format)
├── results/                  — Output JSONL (gitignored)
└── reports/                  — Output markdown reports (gitignored)
```

### Quick start

```bash
# Cost estimate (no API calls)
./scripts/benchmark/run-benchmark.sh --suite custom --limit 5 --dry-run

# Run custom benchmark
./scripts/benchmark/run-benchmark.sh --suite custom --limit 3 --model sonnet

# Head-to-head comparison
./scripts/benchmark/custom/compare-ralph.sh --limit 3 --model sonnet --dry-run

# SWE-bench (Python, optional pip install)
python3 scripts/benchmark/swebench/scaffold.py --tasks-jsonl scripts/benchmark/custom/tasks.jsonl --dry-run --limit 3
```

### Dependencies

- Required: `bash 5.0+`, `git`, `jq`, `python3`, `claude` CLI
- Optional: `pip install swebench datasets` (for HuggingFace dataset loading + leaderboard evaluation)

---

## Step 17: Prompt Template Inheritance (#54)

**Added:** Cycle 3, session 3 (March 30, 2026)
**Depends on:** None (optional: logger for log output)

Template inheritance reduces prompt duplication. Shared sections (PROTECTED FILES,
Git Safety, etc.) live in a base template. Each agent has a small overlay that
overrides blocks and sets variables. The orchestrator renders the merged prompt.

### Module: `src/core/prompt-template.sh`

**Functions:**
| Function | Purpose |
|----------|---------|
| `orch_tpl_init <dir>` | Set template directory root |
| `orch_tpl_set <name> <value>` | Set variable for `{{VAR}}` substitution |
| `orch_tpl_set_from_file <name> <path>` | Set variable from file contents |
| `orch_tpl_render <base> [overlay]` | Merge base + overlay → stdout |
| `orch_tpl_resolve_includes <text>` | Resolve `<!-- include: path -->` directives |
| `orch_tpl_validate <text>` | Check for unresolved `{{VAR}}` placeholders |
| `orch_tpl_list_vars <file>` | List all `{{VAR}}` in a file (deduplicated) |
| `orch_tpl_stats <base> [overlay]` | Print block/var/include counts |

### Template syntax

```markdown
# {{AGENT_NAME}} — {{AGENT_ROLE}}
Date: {{DATE}}

<!-- include: shared/protected-files.md -->
<!-- include: shared/git-safety.md -->

<!-- begin: OWNERSHIP -->
Default ownership (overridden by overlay).
<!-- end: OWNERSHIP -->

<!-- begin: TASKS -->
Default tasks.
<!-- end: TASKS -->
```

### Overlay syntax

```markdown
AGENT_NAME=06-backend
AGENT_ROLE=Backend Developer
DATE=2026-03-30

<!-- begin: OWNERSHIP -->
You OWN: src/core/, scripts/
You NEVER touch: src-tauri/, prompts/
<!-- end: OWNERSHIP -->

<!-- begin: TASKS -->
1. Build prompt-template.sh
2. Write tests
<!-- end: TASKS -->
```

### Wiring into auto-agent.sh

1. Source the module:

```bash
source "$SCRIPT_DIR/../src/core/prompt-template.sh"
```

2. In the agent-spawning loop, replace direct prompt file reading with template rendering:

```bash
# Before (current):
local prompt_file="prompts/${agent_id}/${agent_id}.txt"

# After (template mode):
local template_dir="prompts/00-templates"
if [[ -d "$template_dir" && -f "$template_dir/base.md" ]]; then
    orch_tpl_init "$template_dir"
    local overlay="prompts/${agent_id}/${agent_id}-overlay.md"
    [[ -f "$overlay" ]] || overlay=""
    local rendered_prompt
    rendered_prompt=$(orch_tpl_render "base.md" "$overlay")
    # Write to temp file or pass directly
    local tmp_prompt=$(mktemp)
    printf '%s' "$rendered_prompt" > "$tmp_prompt"
    prompt_file="$tmp_prompt"
fi
```

3. Clean up temp file after agent finishes.

### Migration plan

Phase 1: Create `prompts/00-templates/` with shared sections:
- `base.md` — PROTECTED FILES, Git Safety, auto-cycle instructions
- `shared/protected-files.md` — the protected files list
- `shared/git-safety.md` — git safety rules

Phase 2: Convert one agent (e.g., 06-backend) to overlay format as a pilot.

Phase 3: Convert remaining agents. Old `.txt` files become overlays.

### Safety

- Path traversal: rejected (includes cannot escape template dir)
- Max include depth: 5 (prevents infinite recursion)
- Max file size: 100KB per include
- Backward-compatible: if `00-templates/` doesn't exist, falls back to direct prompt files

## Step 18: Task Decomposer (#50)

**Added:** Cycle 1, session 3 (March 30, 2026)
**Depends on:** None

Progressive task decomposition — breaks large agent task lists into prioritized
chunks. P0 tasks are always included. Remaining slots filled by priority order.
Overflow deferred to next cycle.

### Module: `src/core/task-decomposer.sh`

**Functions:**
| Function | Purpose |
|----------|---------|
| `orch_select_tasks <max> <tasks...>` | Select top N tasks by priority (P0 always included) |
| `orch_extract_tasks <prompt_file>` | Parse tasks from markdown prompt file |
| `orch_decompose_tasks <file> [max]` | Full pipeline: extract + select + report |
| `orch_selected_count` | Number of selected tasks |
| `orch_deferred_count` | Number of deferred tasks |
| `orch_task_report <agent_id>` | Print selected/deferred summary |

### Task format

Tasks use `PRIORITY:description` format:
- `P0:` — critical, always included (doesn't count against limit)
- `P1:` — high priority
- `P2:` — medium (default if no prefix)
- `P3:` — low priority

### Wiring into auto-agent.sh

1. Source the module:

```bash
source "$SCRIPT_DIR/../src/core/task-decomposer.sh"
```

2. Before spawning each agent, decompose its tasks:

```bash
local prompt_file="prompts/${agent_id}/${agent_id}.txt"
orch_decompose_tasks "$prompt_file" 5  # max 5 non-P0 tasks

# Log what was selected/deferred
orch_task_report "$agent_id"

# If all tasks deferred (0 selected), consider skipping agent
if [[ $(orch_selected_count) -eq 0 ]]; then
    log_info "No tasks for $agent_id — skipping"
    continue
fi
```

3. Optionally write deferred tasks to shared context for PM visibility:

```bash
if [[ $(orch_deferred_count) -gt 0 ]]; then
    echo "- ${agent_id}: deferred $(orch_deferred_count) tasks" >> "$CONTEXT_FILE"
fi
```

### Env override

`ORCH_MAX_TASKS_PER_AGENT=3` — override default max (5) globally.

## Step 19: Project Init / Agent Blueprint (#45)

**Added:** Cycle 1, session 3 (March 30, 2026)
**Depends on:** None

Scans a target project directory to detect languages, frameworks, package managers,
test frameworks, and CI/CD. Generates a suggested agents.conf and scaffold prompt files.

### Module: `src/core/init-project.sh`

**Functions:**
| Function | Purpose |
|----------|---------|
| `orch_init_scan <dir>` | Scan project directory (detects languages, frameworks, etc.) |
| `orch_init_suggest_agents` | List suggested agents (one per line, pipe-delimited) |
| `orch_init_generate_conf <path>` | Generate agents.conf at given path |
| `orch_init_generate_prompts <dir>` | Generate scaffold prompt files, returns count |
| `orch_init_report` | Print full analysis report to stdout |
| `orch_init_detected_languages` | List detected languages (space-separated) |
| `orch_init_detected_frameworks` | List detected frameworks (space-separated) |
| `orch_init_has_feature <name>` | Check feature: monorepo, ci, tests, docker, database |

### Detection coverage

**Languages:** bash, python, javascript, typescript, rust, go, swift, java, ruby
**Frameworks:** react, next, vue, svelte, tauri, express, django, flask, fastapi, ios
**Package managers:** npm, yarn, pnpm, pip, cargo, go, cocoapods, gradle, maven
**Test frameworks:** jest, vitest, pytest, cargo-test, go-test, xctest
**CI systems:** GitHub Actions, GitLab CI, CircleCI, Jenkins
**Features:** monorepo, docker, database

### Usage (standalone)

```bash
source src/core/init-project.sh

orch_init_scan "/path/to/project"
orch_init_report                              # human-readable report
orch_init_generate_conf "./agents.conf"       # generate config
orch_init_generate_prompts "./prompts"        # scaffold prompts
```

### Wiring into auto-agent.sh (for `--init` flag)

1. Source the module:

```bash
source "$SCRIPT_DIR/../src/core/init-project.sh"
```

2. Add `--init <dir>` flag to arg parsing:

```bash
--init)
    local target_dir="${2:?--init requires a project directory}"
    shift
    orch_init_scan "$target_dir"
    orch_init_report
    orch_init_generate_conf "${target_dir}/agents.conf"
    orch_init_generate_prompts "${target_dir}/prompts"
    echo "Scaffold created. Review agents.conf and prompts/ before running."
    exit 0
    ;;
```

### Safety

- Scans max depth 3 (avoids deep node_modules etc.)
- Excludes: node_modules, .git, vendor, __pycache__, .venv, dist, build, target, .next, .nuxt
- Non-destructive: only reads existing files, never modifies the scanned project
- Generated files go to specified output paths, not the scanned project
