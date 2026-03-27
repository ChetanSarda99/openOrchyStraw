# Core Modules — Integration Guide

> For CS (the human operator) to integrate `src/core/*.sh` into `auto-agent.sh`.
> Agents cannot modify `auto-agent.sh` — this guide documents exactly what to change.

## Module Overview

| Module | File | Purpose | Dependencies |
|--------|------|---------|-------------|
| bash-version | `bash-version.sh` | Exit early if bash < 4.2 | None (source first) |
| logger | `logger.sh` | Structured leveled logging | None |
| error-handler | `error-handler.sh` | Agent failure tracking + retry | None |
| cycle-state | `cycle-state.sh` | Persist/resume cycle number | None |
| agent-timeout | `agent-timeout.sh` | Per-agent timeout with SIGTERM→SIGKILL | None |
| dry-run | `dry-run.sh` | `--dry-run` preview mode | None |
| config-validator | `config-validator.sh` | Validate agents.conf syntax | None |
| lock-file | `lock-file.sh` | Prevent concurrent orchestrators | None |
| signal-handler | `signal-handler.sh` | Graceful shutdown with SHUTTING_DOWN flag | None (optional: logger) |
| cycle-tracker | `cycle-tracker.sh` | Smart empty cycle detection | None |
| usage-checker | `usage-checker.sh` | Model rate-limit checking + graduated backoff | None |
| qmd-refresher | `qmd-refresher.sh` | Auto-refresh QMD index each cycle | None |
| context-filter | `context-filter.sh` | Differential context per agent | None |
| prompt-template | `prompt-template.sh` | Prompt template inheritance | None |
| dynamic-router | `dynamic-router.sh` | Dependency-aware parallel execution | None |
| worktree-isolator | `worktree-isolator.sh` | Git worktree isolation per agent | None |
| model-router | `model-router.sh` | Model tiering per agent | None |
| review-phase | `review-phase.sh` | Loop review & critique | None |
| self-healing | `self-healing.sh` | Auto-detect and fix agent failures | None |
| quality-gates | `quality-gates.sh` | Scripted quality gates | None |
| init-project | `init-project.sh` | Project analyzer → agent blueprint | None |
| file-access | `file-access.sh` | 4-zone file access enforcement | None |
| agent-as-tool | `agent-as-tool.sh` | Lightweight read-only agent invocations | None |
| model-budget | `model-budget.sh` | Fallback chains + budget controls | None |
| vcs-adapter | `vcs-adapter.sh` | VCS abstraction layer (git/svn/none) | None |
| single-agent | `single-agent.sh` | Single-agent mode (skip PM/multi-agent) | None |

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
source "$SCRIPT_DIR/../src/core/usage-checker.sh"
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

## Step 8: Replace check-usage.sh call with usage-checker module (#73)

The old `check-usage.sh` had two problems:
1. **Threshold too high** — paused at 90, but by then you've already hit 98%
2. **Non-portable** — used `grep -oP` (Perl regex) which doesn't exist on macOS

The new `usage-checker.sh` module fixes both. Replace the usage check block in
`auto-agent.sh` (around lines 627-647):

**Old:**
```bash
bash "$PROJECT_ROOT/scripts/check-usage.sh" 2>/dev/null
if [ -f "$usage_file" ]; then
    claude_usage=$(grep '^claude=' "$usage_file" 2>/dev/null | cut -d= -f2 || echo 0)
    # ... read other statuses ...
    if [ -n "$claude_usage" ] && [ "$claude_usage" -ge 90 ] 2>/dev/null; then
        log "PAUSED: Claude at ${claude_usage} (threshold: 90)"
        sleep 60
        continue
    fi
fi
```

**New:**
```bash
orch_check_usage "$PROJECT_ROOT"
if orch_should_pause; then
    local backoff
    backoff=$(orch_get_backoff_seconds)
    log "PAUSED: Claude at $(orch_model_status claude) — backing off ${backoff}s"
    notify "Paused: Claude at $(orch_model_status claude) — ${backoff}s backoff" "warning"
    sleep "$backoff"
    continue
fi
if orch_all_models_down; then
    log "ALL MODELS DOWN — stopping"
    notify "All models unavailable — stopping" "error"
    break
fi
```

**Key improvements:**
- Pause threshold lowered from 90 → 80 (catches overages before hitting hard limit)
- Graduated backoff: 70→10s, 80→30s, 90→120s, 100→300s
- No more `grep -oP` — works on macOS/BSD
- Threshold configurable via `ORCH_PAUSE_THRESHOLD` env var

---

## Step 9: Update check-usage.sh portability (#65)

`scripts/check-usage.sh` uses `grep -oP` (lines 54-56) which requires GNU grep.
macOS ships BSD grep which doesn't support `-P`.

**CS should replace lines 53-56:**

```bash
    status=$(echo "$rate_event" | grep -oP '"status"\s*:\s*"\K[^"]+')
    overage=$(echo "$rate_event" | grep -oP '"isUsingOverage"\s*:\s*\K(true|false)')
    overage_status=$(echo "$rate_event" | grep -oP '"overageStatus"\s*:\s*"\K[^"]+')
```

**With:**
```bash
    status=$(echo "$rate_event" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
    overage=$(echo "$rate_event" | grep -o '"isUsingOverage"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | sed 's/.*:[[:space:]]*//')
    overage_status=$(echo "$rate_event" | grep -o '"overageStatus"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
```

**Also update the shebang** from `#!/bin/bash` to `#!/usr/bin/env bash` per BASH-001 ADR.

Or, better: since `usage-checker.sh` replaces `check-usage.sh` entirely,
CS can leave check-usage.sh as-is and just use the module (Step 8 above).

---

## Security Fixes for CS to Apply

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

## Step 10: Replace inline QMD refresh with qmd-refresher module (#37)

The old inline QMD logic (auto-agent.sh lines 703-716) checks for qmd, runs update,
and conditionally embeds on QA cycles. The new module provides a cleaner API with
state tracking and configurable embed intervals.

**Old (lines 703-716):**
```bash
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

**New:**
```bash
source "$SCRIPT_DIR/../src/core/qmd-refresher.sh"

# At cycle start (replaces lines 703-716):
orch_qmd_auto_refresh "false" "$PROJECT_ROOT"
# Force embed on first cycle:
# orch_qmd_auto_refresh "true" "$PROJECT_ROOT"
```

**Key improvements:**
- State tracking: timestamps in `.orchystraw/` prevent redundant embeds
- Configurable interval: `ORCH_QMD_EMBED_INTERVAL` env var (default 300s)
- No more coupling to agent intervals — embeds based on elapsed time
- Status reporting: `orch_qmd_status` for diagnostics

---

## Step 11: Use context-filter for differential context (#33)

Instead of feeding the full `context.md` to every agent, filter it so each agent
only receives sections relevant to them. This reduces tokens significantly for
scoped agents (backend, iOS, pixel, etc.).

**Integration in auto-agent.sh (in the agent invocation loop):**

```bash
source "$SCRIPT_DIR/../src/core/context-filter.sh"
orch_context_filter_init

# Before invoking each agent, generate filtered context:
for id in "${AGENT_IDS[@]}"; do
    local filtered_ctx="/tmp/orchystraw-ctx-${id}.md"
    orch_context_write_filtered "$id" "$CONTEXT_FILE" "$filtered_ctx"
    # Use $filtered_ctx instead of $CONTEXT_FILE when building the prompt
done
```

**Token savings:** ~30-70% per scoped agent (backend, iOS, pixel, web).
Full-picture agents (CEO, CTO, PM, QA, Security) still receive everything.

---

## Step 12: Use prompt-template for inherited boilerplate (#38)

Instead of duplicating git rules, protected files list, and auto-cycle instructions
in every agent prompt, use template variables that expand at runtime.

**Integration in auto-agent.sh (during prompt assembly):**

```bash
source "$SCRIPT_DIR/../src/core/prompt-template.sh"
orch_template_init "$PROJECT_ROOT"
orch_template_set_defaults

# When building prompt content for an agent:
# Option A: If prompts use {{VAR}} placeholders:
local rendered_prompt
rendered_prompt=$(orch_template_render "$prompt_file")

# Option B: Append boilerplate after prompt content:
local git_rules
git_rules=$(orch_template_get "GIT_RULES")
prompt_content="${prompt_content}
${git_rules}"
```

**Migration path:** Agent prompts can gradually adopt `{{GIT_RULES}}`, `{{PROTECTED_FILES}}`,
`{{AUTO_CYCLE_RULES}}` placeholders, replacing the repeated boilerplate blocks.
The `orch_template_estimate_savings` function shows per-prompt token savings.

---

## Step 13: Conditional agent activation — skip idle agents (#32)

Instead of running every eligible agent every cycle, check whether each agent
actually has work to do. Agents with no changes in their owned paths and a long
idle streak are skipped, saving tokens and API calls.

**Integration in auto-agent.sh (before the agent invocation loop):**

```bash
source "$SCRIPT_DIR/../src/core/conditional-activation.sh"

# At cycle start:
orch_activation_init "$CYCLE" "$PROJECT_ROOT" 3

# Parse PM force-flags from shared context:
orch_activation_parse_forces "$CONTEXT_FILE"

# Check each agent:
for id in "${AGENT_IDS[@]}"; do
    local interval="${AGENT_INTERVALS[$id]}"
    local ownership="${AGENT_OWNERSHIP[$id]}"
    orch_activation_check "$id" "$interval" "$CYCLE" "$ownership"
done

# Get list of agents to actually run:
local eligible
eligible=$(orch_activation_eligible_list)

# Only invoke eligible agents:
for id in $eligible; do
    run_agent "$id" &
done
wait

# After each agent completes, record outcome:
for id in $eligible; do
    local commits
    commits=$(git log --oneline --since="10 minutes ago" --author="$id" 2>/dev/null | wc -l)
    if [[ $commits -gt 0 ]]; then
        orch_activation_record_outcome "$id" "active"
    else
        orch_activation_record_outcome "$id" "idle"
    fi
done

# Optional: print report
orch_activation_report
```

**PM force-flag:** To force an idle agent to run, the PM writes `FORCE: <agent_id>`
in the Notes section of `context.md`. The activation module scans for these directives.

**Key improvements:**
- Agents with 3+ consecutive idle cycles (no output) AND no changes in owned paths → skipped
- PM can override with FORCE: directive in shared context
- Coordinators (interval=0) always run
- Token/API savings: ~20-40% on typical cycles with 2-3 idle agents

---

## Step 14: Prompt compression — tiered prompt loading (#31)

Reduce token usage by loading only the sections of agent prompts that are needed.
First invocation gets the full prompt; subsequent runs skip boilerplate like
"What is OrchyStraw?" and "Tech Stack" since the agent already has that context.

**Integration in auto-agent.sh (during prompt assembly):**

```bash
source "$SCRIPT_DIR/../src/core/prompt-compression.sh"
orch_compress_init

# For each agent, determine the appropriate tier:
for id in "${AGENT_IDS[@]}"; do
    local tier
    tier=$(orch_compress_tier_for_agent "$id")

    # Compress the prompt:
    local compressed_prompt
    compressed_prompt=$(orch_compress_prompt "$tier" "${AGENT_PROMPTS[$id]}")

    # Use $compressed_prompt instead of raw file content when invoking the agent
    # ...

    # After invocation, record the run:
    orch_compress_record_run "$id"
done

# Optional: print savings report
orch_compress_report
```

**Tiers:**
- `full` — complete prompt (first run, or after config change)
- `standard` — skips project overview + tech stack sections (~20% savings)
- `minimal` — tasks + rules + protected files only (~30%+ savings)

**Auto-selection logic:**
- Run count 0-1 → full (agent needs full context)
- Run count 2-4 → standard (knows the project, needs task + history)
- Run count 5+ → minimal (veteran agent, just needs tasks + rules)

**Reset:** Call `orch_compress_reset_run_count "all"` when agents.conf or prompts change
significantly (e.g., after a version bump or major restructure).

---

## Step 15: Dependency-aware parallel execution (#27)

Instead of running all eligible agents simultaneously, group them by dependency order.
Agents with no dependencies run first (group 0), then agents that depend on group 0
(group 1), and so on. Coordinators (depends_on="all") always run last.

**Integration in auto-agent.sh (replace the flat agent loop):**

```bash
source "$SCRIPT_DIR/../src/core/dynamic-router.sh"

# At startup, after parsing agents.conf:
orch_router_init
orch_router_parse_config "$CONF_FILE"

# Check for circular dependencies (fail-fast):
if orch_router_has_cycle; then
    log "FATAL: Circular dependency detected in agents.conf"
    orch_lock_release
    exit 1
fi

orch_router_build_groups

# Replace the flat loop with group-based execution:
local group_count
group_count=$(orch_router_group_count)

for (( g=0; g<group_count; g++ )); do
    local group_agents
    group_agents=$(orch_router_get_groups | sed -n "$((g+1))p")
    IFS=',' read -ra agents <<< "$group_agents"

    # Run group in parallel
    for id in "${agents[@]}"; do
        run_agent "$id" &
    done
    wait

    # Commit group's work before next group starts
    for id in "${agents[@]}"; do
        commit_by_ownership "$id" "${AGENT_OWNERSHIP[$id]}"
    done
done
```

**agents.conf v2 format (backward compatible):**
If columns 6-7 are present, they are parsed as `priority` and `depends_on`.
If missing, defaults apply: priority=5, depends_on=none.

```
# id | prompt | ownership | interval | label | priority | depends_on
06-backend | ... | src/core/ | 1 | Backend | 10 | none
09-qa      | ... | tests/    | 3 | QA      | 5  | 06-backend
03-pm      | ... | prompts/  | 0 | PM      | 0  | all
```

**Key improvements:**
- Agents that depend on builders (QA, Security, CTO) wait until builders finish
- Builders within the same group still run in parallel
- Circular dependencies caught at config-validate time
- Priority ordering within groups (higher priority agents listed first)
- `orch_router_report` shows the execution plan for diagnostics

---

## Step 16: Git worktree isolation per agent (#28)

Each agent gets its own git worktree so they can work on files without conflicting
with each other during parallel execution. After all agents finish, worktrees are
merged back to the main branch.

**Integration in auto-agent.sh:**

```bash
source "$SCRIPT_DIR/../src/core/worktree-isolator.sh"

# At cycle start:
orch_worktree_init "$PROJECT_ROOT" "$CYCLE"

# Before running each agent, create a worktree:
for id in "${agents[@]}"; do
    if orch_worktree_create "$id"; then
        local wt_path
        wt_path=$(orch_worktree_get_path "$id")
        # Run agent in the worktree directory instead of project root
        run_agent "$id" "$wt_path" &
    else
        log "WARN: Failed to create worktree for $id, running in-place"
        run_agent "$id" &
    fi
done
wait

# Merge all worktrees back:
local merged
merged=$(orch_worktree_merge_all)
log "Merged $merged worktree(s) back to main"

# Cleanup:
orch_worktree_cleanup_all
```

**Key improvements:**
- Agents can't conflict on shared files (each has isolated working copy)
- Merge conflicts are detected and reported (not auto-resolved)
- Worktrees are cleaned up every cycle (no disk bloat)
- Branch naming: `auto/agent-<id>-cycle-<N>` for easy identification
- Falls back to in-place execution if worktree creation fails

**Note:** This pairs well with dependency groups (Step 15). Run group 0 in worktrees,
merge back, then run group 1 in fresh worktrees that see group 0's merged output.

---

## Step 17: Model tiering per agent (#30)

Different agents can use different AI CLI tools based on their task type.
Backend/architecture agents use Claude, UI agents use Gemini, review agents use Codex.

**Integration in auto-agent.sh:**

```bash
source "$SCRIPT_DIR/../src/core/model-router.sh"

# At startup:
orch_model_init
orch_model_parse_config "$CONF_FILE"

# In run_agent(), replace the hardcoded "claude" invocation:
run_agent() {
    local agent_id="$1"
    local cli
    cli=$(orch_model_get_cli "$agent_id")

    # Check availability, fallback if needed
    local model_name
    model_name=$(orch_model_get_name "$agent_id")
    if ! orch_model_is_available "$model_name"; then
        cli=$(orch_model_fallback "$agent_id")
        log "WARN: $model_name unavailable for $agent_id, falling back to $cli"
    fi

    # Invoke the agent with the appropriate CLI
    $cli --prompt "$prompt_content" ...
}
```

**agents.conf with model column:**
```
# id | prompt | ownership | interval | label | model
06-backend | ... | src/core/ | 1 | Backend | claude
05-tauri-ui | ... | src/ | 1 | Tauri UI | gemini
09-qa | ... | tests/ | 3 | QA | codex
```

**Default mappings (registered in orch_model_init):**
- `claude` → `claude` (Opus 4.6 — architecture, complex decisions)
- `codex` → `codex exec` (GPT-5.4 — research, code review)
- `gemini` → `gemini -p` (Gemini 3.1 Pro — UI tasks)

**Key improvements:**
- Per-agent model selection instead of one-size-fits-all
- Automatic fallback to default model if assigned model unavailable
- Config-driven — no code changes needed to reassign models
- `orch_model_report` shows current assignments and availability

---

## Step 18: Loop review & critique (#24)

After agents execute and commit, selected reviewer agents critique the diffs.
Reviews are read-only markdown — reviewers write critiques, they cannot modify code.

**Integration in auto-agent.sh (after commit phase, before PM):**

```bash
source "$SCRIPT_DIR/../src/core/review-phase.sh"

# At startup:
orch_review_init "$CYCLE" "$PROJECT_ROOT"
orch_review_parse_config "$CONF_FILE"

# After agents commit (between group execution and PM phase):
for reviewer_id in $(orch_review_get_reviewers_list); do
    local targets
    targets=$(orch_review_get_assignments "$reviewer_id")
    IFS=',' read -ra target_arr <<< "$targets"

    for target_id in "${target_arr[@]}"; do
        # Only review if target produced commits
        if ! orch_review_should_run "$target_id"; then
            continue
        fi

        # Generate diff and build review prompt
        local diff_text
        diff_text=$(orch_review_generate_diff "$target_id" "HEAD~1")
        local review_prompt
        review_prompt=$(orch_review_build_prompt "$reviewer_id" "$target_id" "$diff_text" \
            "${AGENT_PROMPTS[$target_id]}")

        # Invoke reviewer agent with review prompt
        local cli
        cli=$(orch_model_get_cli "$reviewer_id")
        local review_output
        review_output=$($cli --prompt "$review_prompt" 2>/dev/null)

        # Save review
        orch_review_save "$reviewer_id" "$target_id" "$review_output"
    done
done

# Print review summary
orch_review_report

# Check for blocking reviews
if orch_review_has_blocking "09-qa"; then
    log "WARN: QA has blocking reviews — PM should address next cycle"
fi
```

**agents.conf with reviews column:**
```
# id | prompt | ownership | interval | label | priority | depends_on | reviews
09-qa  | ... | tests/ | 3 | QA  | 5 | 06-backend | 06-backend,08-pixel
02-cto | ... | docs/  | 2 | CTO | 7 | none       | 06-backend
```

**Key improvements:**
- Structured review output: approve / request-changes / comment
- Reviews saved as markdown in `prompts/<reviewer>/reviews/`
- Only reviews agents that produced commits (saves tokens)
- Blocking reviews flagged for PM attention
- Review phase is optional — only runs if review assignments exist in config

---

## Step 19: Self-healing agents — auto-detect and fix failures (#72)

When an agent fails, the self-healing module diagnoses the failure, classifies it,
and applies automatic remediation before retrying. Conservative by design — only
fixes things it's confident about, never modifies files outside ownership.

**Integration in auto-agent.sh (in run_agent error handling):**

```bash
source "$SCRIPT_DIR/../src/core/self-healing.sh"

# At startup:
orch_heal_init 2 10   # max 2 retries, 10s cooldown

# In run_agent(), after agent failure:
run_agent_with_healing() {
    local agent_id="$1"
    local exit_code

    # Run the agent
    run_agent "$agent_id"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        local log_file="$LOG_DIR/${agent_id}.log"
        local failure_class
        failure_class=$(orch_heal_diagnose "$agent_id" "$exit_code" "$log_file")

        if orch_heal_can_fix "$failure_class"; then
            orch_heal_apply "$agent_id" "$failure_class" "$PROJECT_ROOT"
            orch_heal_record "$agent_id" "$failure_class" "auto-remediated" "true"

            # Retry if within budget
            if orch_heal_should_retry "$agent_id"; then
                log "HEAL: retrying $agent_id after $failure_class remediation"
                run_agent "$agent_id"
                exit_code=$?
                if [[ $exit_code -eq 0 ]]; then
                    orch_heal_record "$agent_id" "$failure_class" "retry-succeeded" "true"
                else
                    orch_heal_record "$agent_id" "$failure_class" "retry-failed" "false"
                fi
            fi
        else
            orch_heal_record "$agent_id" "$failure_class" "manual-investigation-needed" "false"
            log "HEAL: $agent_id failed with $failure_class — requires manual investigation"
        fi
    fi
}

# At cycle end:
orch_heal_report
orch_heal_stats
```

**Failure classes and remediations:**
- `rate-limit` → exponential backoff (10s × 2^n, cap 300s)
- `timeout` → recommend increased timeout for next run
- `context-overflow` → write flag file for prompt-compression to pick up
- `permission` → `chmod u+rw` on owned files
- `git-conflict` → `git checkout --theirs` on conflicting files in ownership only
- `crash` / `unknown` → log diagnostic, recommend manual investigation

**Key improvements:**
- Automatic diagnosis from exit codes and log patterns
- Conservative remediation — only fixes what it's confident about
- Full audit trail via `orch_heal_history` and `orch_heal_report`
- Integrates with prompt-compression via flag files

---

## Step 20: Quality gates — scripted validation before acceptance (#67)

Quality gates validate agent work before it's accepted into the main branch.
Gates can be blocking (must pass) or warning (logged but non-blocking).

**Integration in auto-agent.sh (after agent commits, before merge):**

```bash
source "$SCRIPT_DIR/../src/core/quality-gates.sh"

# At startup:
orch_gate_init "$PROJECT_ROOT"
orch_gate_register_defaults   # syntax, shellcheck, test, ownership

# After each agent commits:
for id in "${AGENT_IDS[@]}"; do
    # Run all gates for this agent
    if ! orch_gate_run_all "$id"; then
        log "GATE: $id failed quality gates — work not accepted"
        orch_gate_report
        # Optionally trigger self-healing or flag for next cycle
        continue
    fi

    # Ownership gate (specialized)
    local ownership="${AGENT_OWNERSHIP[$id]}"
    if ! orch_gate_check_ownership "$id" "$ownership"; then
        log "GATE: $id has rogue writes outside ownership!"
        # Could auto-revert or flag for PM
    fi
done

# Print gate report at cycle end
orch_gate_report
```

**Built-in gates:**
- `syntax` (blocking) — `bash -n` on all `.sh` files in `src/core/`
- `shellcheck` (warning) — runs shellcheck if installed
- `test` (blocking) — runs `tests/core/run-tests.sh` if it exists
- `ownership` (blocking) — validates no file writes outside agent ownership

**Custom gates:**
```bash
# Register a command-based gate
orch_gate_register "no-secrets" "! grep -r 'API_KEY\|SECRET' src/" "blocking"

# Register a function-based gate
my_lint_check() { shellcheck -S error "src/core/$1.sh"; }
orch_gate_add_custom "agent-lint" "my_lint_check" "warning"

# Skip a gate for this cycle
orch_gate_skip "shellcheck"
```

**Key improvements:**
- Extensible gate system — register custom gates via commands or functions
- Ownership validation prevents cross-agent file conflicts
- Blocking vs warning severity controls flow
- Gate results stored for reporting and audit

---

## Step 21: Project init — auto-generate agents.conf from codebase (#29)

When bootstrapping a new project, the init module scans the codebase and suggests
an agent configuration. This is the `./auto-agent.sh init` command.

**Integration in auto-agent.sh (as a subcommand):**

```bash
source "$SCRIPT_DIR/../src/core/init-project.sh"

# Handle "init" subcommand
if [[ "${1:-}" == "init" ]]; then
    local target_dir="${2:-.}"
    local output_dir="${3:-./generated}"

    orch_init_scan "$target_dir"
    orch_init_report

    echo ""
    echo "Generating configuration..."
    orch_init_generate_conf "${output_dir}/agents.conf"
    local prompt_count
    prompt_count=$(orch_init_generate_prompts "${output_dir}/prompts")

    echo ""
    echo "Generated:"
    echo "  agents.conf  → ${output_dir}/agents.conf"
    echo "  prompts      → ${output_dir}/prompts/ ($prompt_count files)"
    echo ""
    echo "Review and copy to your project when ready."
    exit 0
fi
```

**What it detects:**
- 9 languages (bash, python, javascript, typescript, rust, go, swift, java, ruby)
- 10 frameworks (react, next, vue, svelte, django, flask, fastapi, express, tauri, ios)
- 9 package managers, 6 test frameworks, 4 CI systems
- Features: monorepo, docker, database

**Agent suggestion logic:**
- Always: CEO, CTO, PM (core coordination)
- Backend agent if backend language detected
- Frontend agent if frontend framework detected (separate Tauri-Rust + Tauri-UI for Tauri)
- iOS agent if iOS framework detected
- QA agent if tests or test framework detected
- DevOps agent if CI detected
- Infrastructure agent if monorepo
- Security agent if > 3 agents total

**Key improvements:**
- Zero-config bootstrap — scan and generate in one command
- Scaffold prompts with ownership boundaries pre-configured
- Suggestions only — never auto-applies, user reviews first

---

## Step 22: 4-zone file access enforcement (#66)

Enforce file access zones so agents can only modify files they own. Four zones
checked in priority order: protected → owned → shared → unowned.

**Integration in auto-agent.sh (at startup and before commits):**

```bash
source "$SCRIPT_DIR/../src/core/file-access.sh"

# At startup, after parsing agents.conf:
orch_access_init "$PROJECT_ROOT"
orch_access_parse_config "$CONF_FILE"

# Before accepting agent commits, validate writes:
for id in "${AGENT_IDS[@]}"; do
    local changed_files
    changed_files=$(git diff --name-only HEAD 2>/dev/null)
    if [[ -n "$changed_files" ]]; then
        if ! orch_access_validate_writes "$id" "$changed_files"; then
            log "ACCESS: $id wrote outside ownership — rejecting"
            git checkout -- . 2>/dev/null   # revert unauthorized changes
            continue
        fi
    fi
done

# Optional: print access report
orch_access_report
```

**Zones:**
- `protected` — no agent can modify (auto-agent.sh, agents.conf, CLAUDE.md, .orchystraw/)
- `owned` — files the agent owns per agents.conf (read-write)
- `shared` — cross-agent communication files (prompts/00-shared-context/, prompts/99-me/)
- `unowned` — files owned by another agent (read-only)
- `unknown` — files not assigned to any agent (read-only)

**Key features:**
- Exclusion support: `!path` in ownership removes a subtree from an agent's owned paths
- Protected zone includes orchestrator infrastructure by default
- `orchestrator` agent ID bypasses protected read restrictions
- `orch_access_zone_for` returns zone without agent context (useful for reporting)

---

## Step 23: Agent-as-tool — lightweight read-only invocations (#26)

Let agents invoke other agents for quick lookups without file writes. The target
agent runs in a restricted read-only mode and returns its answer via stdout.

**Integration in auto-agent.sh:**

```bash
source "$SCRIPT_DIR/../src/core/agent-as-tool.sh"

# At startup:
orch_tool_init "$PROJECT_ROOT"
orch_tool_set_timeout 30

# Register agents that can be invoked as tools:
for id in "${AGENT_IDS[@]}"; do
    local cli
    cli=$(orch_model_get_cli "$id")
    orch_tool_register "$id" "${AGENT_PROMPTS[$id]}" "$cli"
done

# During agent execution, agents can call:
#   orch_tool_invoke "06-backend" "02-cto" "What's the ADR for bash version?"
# Returns the CTO's answer via stdout (read-only, no file mutations)

# At cycle end:
orch_tool_report
```

**Key features:**
- Self-invoke prevention (agent can't call itself — avoids infinite loops)
- Configurable timeout (default 30s) using `timeout` command
- Read-only prompt wrapper instructs target to not modify files
- Invocation history tracked per caller
- Error codes: 1=timeout, 2=unknown target, 3=self-invoke
- Mockable for testing via `_ORCH_TOOL_MOCK_CMD`

---

## Step 24: Model fallback chains + budget controls (#69)

Companion module to model-router.sh. Adds ordered fallback chains per agent and
per-agent/global invocation budget limits.

**Integration in auto-agent.sh (alongside model-router):**

```bash
source "$SCRIPT_DIR/../src/core/model-router.sh"
source "$SCRIPT_DIR/../src/core/model-budget.sh"

# At startup:
orch_model_init
orch_budget_init

# Set fallback chains per agent:
orch_budget_set_chain "06-backend" "claude,codex,gemini"
orch_budget_set_chain "05-tauri-ui" "gemini,claude"
orch_budget_set_chain "09-qa" "codex,claude"

# Set budget limits:
orch_budget_set_limit "08-pixel" 3        # max 3 invocations per cycle
orch_budget_set_global_limit 50           # max 50 total invocations per cycle

# In run_agent(), resolve the model dynamically:
run_agent() {
    local agent_id="$1"
    local model
    model=$(orch_budget_resolve "$agent_id")
    if [[ $? -ne 0 ]]; then
        log "BUDGET: $agent_id has no available models — skipping"
        return 1
    fi

    local cli
    orch_model_assign "$agent_id" "$model"
    cli=$(orch_model_get_cli "$agent_id")

    # Run agent...
    $cli --prompt "$prompt_content" ...

    # Record the invocation:
    orch_budget_record "$agent_id" "$model"
}

# At cycle start:
orch_budget_reset_cycle   # resets counters, keeps chains and limits

# At cycle end:
orch_budget_report
```

**Key features:**
- Ordered fallback: if preferred model CLI is not in PATH, tries next in chain
- Per-agent budget: limit costly agents to N invocations per cycle
- Global budget: cap total invocations across all agents
- `orch_budget_resolve` combines availability check + budget check
- Cycle reset preserves configuration but zeros counters
- Default chain: claude,codex,gemini (configurable per agent)

---

## Step 25: Source `vcs-adapter.sh` — VCS abstraction layer (#59)

Add near other module sources:
```bash
source "$SCRIPT_DIR/../src/core/vcs-adapter.sh"
```

### Usage in auto-agent.sh

```bash
# At startup (auto-detects git/svn/none):
orch_vcs_init

# Replace raw git calls with VCS adapter:
orch_vcs_status          # replaces: git -C "$PROJECT_ROOT" status
orch_vcs_diff "HEAD~1"   # replaces: git -C "$PROJECT_ROOT" diff HEAD~1
orch_vcs_commit "msg"    # replaces: git -C "$PROJECT_ROOT" commit -m "msg"
orch_vcs_log 5           # replaces: git -C "$PROJECT_ROOT" log --oneline -5
orch_vcs_branch          # get current branch name
orch_vcs_stash           # stash changes
orch_vcs_unstash         # pop stash
```

**Key features:**
- Auto-detects backend by checking for `.git`/`.svn` directories
- `none` backend: all operations are no-ops (safe for non-VCS projects)
- `svn` backend: maps operations to svn equivalents (stash uses patch files)
- `orch_vcs_report` shows which backend is active

---

## Step 26: Source `single-agent.sh` — Single-agent mode (#51)

Add near other module sources:
```bash
source "$SCRIPT_DIR/../src/core/single-agent.sh"
```

### Usage in auto-agent.sh

```bash
# Check if --single-agent flag was passed:
if [[ "${SINGLE_AGENT_FLAG:-0}" == "1" ]]; then
    orch_single_init "$PROJECT_ROOT"
fi

# Or auto-detect:
if orch_single_detect "$AGENTS_CONF"; then
    orch_single_init "$PROJECT_ROOT"
fi

# In the main loop:
if orch_single_is_active; then
    local agent_id
    agent_id=$(orch_single_get_agent "$AGENTS_CONF")
    orch_single_run "$agent_id" "$PROMPT_PATH" "$PROJECT_ROOT"
else
    # Normal multi-agent loop...
fi
```

**Key features:**
- Skips: review-phase, dynamic-router, worktree-isolator, conditional-activation
- Keeps: quality-gates, file-access, logger, error-handler, model-router, vcs-adapter
- `orch_single_detect` recommends single mode for 1-agent configs or <5-file projects
- `orch_single_run` integrates with quality-gates and model-router if loaded

---

## Step 27: Enhanced review-phase.sh — Efficient review patterns (#68)

No new source needed (review-phase.sh already sourced in Step 18). Four new functions added:

### Usage in auto-agent.sh

```bash
# Batch reviews (one prompt for N targets):
orch_review_batch "09-qa" "06-backend,11-web,08-pixel" "$CYCLE_START_REF"

# Prioritize by change volume + security relevance:
orch_review_prioritize "06-backend,11-web,08-pixel" "$CYCLE_START_REF"

# Auto-approve trivial changes (< 5 lines, prompts/docs only):
if orch_review_auto_verdict "08-pixel" "$CYCLE_START_REF" 5; then
    echo "Auto-approved — skipping full review"
fi

# Structured checklists instead of freeform:
orch_review_checklist "10-security" "06-backend" "$diff" "security"
# Types: "security", "correctness", "style", "full"
```

**Key features:**
- `orch_review_batch`: one combined prompt for N targets (replaces N separate invocations)
- `orch_review_prioritize`: sorts by change volume + security relevance
- `orch_review_auto_verdict`: skips review for trivial prompt/doc edits
- `orch_review_checklist`: structured pass/fail items replace open-ended freeform debate
