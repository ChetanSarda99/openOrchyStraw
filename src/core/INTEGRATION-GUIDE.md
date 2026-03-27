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
