#!/bin/bash
# ============================================
# orchystraw Orchestrator v4
# Configurable agents, PM self-update, per-agent intervals
# ============================================
#
# Usage:
#   ./scripts/auto-agent.sh orchestrate [max-cycles=10]
#   ./scripts/auto-agent.sh orchestrate --dry-run
#   ./scripts/auto-agent.sh orchestrate --cost-limit 5.00
#   ./scripts/auto-agent.sh orchestrate --max-parallel 3
#   ./scripts/auto-agent.sh orchestrate --watch
#   ./scripts/auto-agent.sh run <agent-id>
#   ./scripts/auto-agent.sh run --agent "Backend Developer"
#   ./scripts/auto-agent.sh list
#   ./scripts/auto-agent.sh status
#
# Monitor: /monitor prompts/01-pm/logs/orchestrator.log
#
# Config: scripts/agents.conf (add/remove agents there)
#
# Architecture:
#   1. Read agents.conf for agent list + intervals
#   2. Run eligible agents in parallel (based on cycle interval, max-parallel cap)
#   3. Script commits work by file ownership (no git races)
#   4. PM reviews, writes new prompts, updates itself
#   5. Cycle summary: agents run, tokens, cost, files changed, tests
#   6. Backup, validate, repeat

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT" || exit 1

# ── Core modules (v0.1) ──────────────────────────────────────────────────
if [ -d "$PROJECT_ROOT/src/core" ]; then
    for mod in bash-version logger error-handler cycle-state agent-timeout dry-run config-validator lock-file; do
        [ -f "$PROJECT_ROOT/src/core/${mod}.sh" ] && source "$PROJECT_ROOT/src/core/${mod}.sh"
    done
fi

# ── Smart cycle modules (v0.2) ──────────────────────────────────────────
if [ -d "$PROJECT_ROOT/src/core" ]; then
    for mod in signal-handler cycle-tracker conditional-activation differential-context session-tracker prompt-compression dynamic-router review-phase worktree quality-gates; do
        [ -f "$PROJECT_ROOT/src/core/${mod}.sh" ] && source "$PROJECT_ROOT/src/core/${mod}.sh"
    done
fi

# ── Extended modules (v0.3) ─────────────────────────────────────────────
if [ -d "$PROJECT_ROOT/src/core" ]; then
    for mod in single-agent qmd-refresher prompt-template task-decomposer init-project freshness-detector; do
        [ -f "$PROJECT_ROOT/src/core/${mod}.sh" ] && source "$PROJECT_ROOT/src/core/${mod}.sh"
    done
fi

if [[ -n "${2:-}" && "${2:-}" =~ ^[0-9]+$ ]]; then
    MAX_CYCLES="$2"
elif [[ -n "${ORCH_MAX_CYCLES:-}" ]]; then
    MAX_CYCLES="$ORCH_MAX_CYCLES"
elif [[ -f "$PROJECT_ROOT/.orchystraw/max-cycles" ]]; then
    MAX_CYCLES=$(head -1 "$PROJECT_ROOT/.orchystraw/max-cycles" | tr -d '[:space:]')
else
    MAX_CYCLES=10
fi
PROMPTS_DIR="$PROJECT_ROOT/prompts"
BACKUP_DIR="$PROMPTS_DIR/00-backup"
PM_LOG_DIR="$PROMPTS_DIR/01-pm/logs"
CYCLE_LOG="$PM_LOG_DIR/orchestrator.log"
# PM prompt: check 03-pm first (orchystraw), fall back to 01-pm (momentum/others)
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
# Auto-detect PM prompt location
if [ -f "$PROMPTS_DIR/03-pm/03-pm.txt" ]; then
    PM_PROMPT="$PROMPTS_DIR/03-pm/03-pm.txt"
elif [ -f "$PROMPTS_DIR/01-pm/01-project-manager.txt" ]; then
    PM_PROMPT="$PROMPTS_DIR/01-pm/01-project-manager.txt"
else
    PM_PROMPT="$PROMPTS_DIR/01-pm/01-pm.txt"
fi
EMPTY_CYCLES=0
MAX_EMPTY_CYCLES=3

# ── v4 flags ────────────────────────────────────────────────────────────
COST_LIMIT=""          # --cost-limit: stop when cumulative cost exceeds (dollars)
MAX_PARALLEL=0         # --max-parallel: cap concurrent agents (0=unlimited)
WATCH_MODE=false       # --watch: file-change triggered mode
AGENT_BY_NAME=""       # --agent: resolve agent by label name
CUMULATIVE_COST=0      # running total in microdollars
CUMULATIVE_TOKENS=0    # running total tokens across all cycles
CUMULATIVE_FILES=0     # running total files changed
CUMULATIVE_AGENTS_RUN=0 # running total agents invoked
CYCLE_TEST_PASS=0
CYCLE_TEST_FAIL=0

# Stall detector — pause orchestrator after N idle cycles (lint-only/no meaningful commits)
if [ -f "$PROJECT_ROOT/src/core/stall-detector.sh" ]; then
    source "$PROJECT_ROOT/src/core/stall-detector.sh"
fi

mkdir -p "$BACKUP_DIR" "$PM_LOG_DIR"

# ============================================
# HELPERS
# ============================================

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() {
    local msg
    msg="[$(timestamp)] $1"
    echo "$msg"
    echo "$msg" >> "$CYCLE_LOG"
}

notify() {
    local title="${1:-orchystraw}"
    local level="${2:-info}"  # info, warning, error
    local ps_exe="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

    # Windows Toast Notification (works from WSL) — safe via env var, no shell interpolation
    if [ -x "$ps_exe" ]; then
        local safe_title
        safe_title=$(printf '%s' "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')

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

cleanup() {
    log "SIGINT — killing all agent processes..."
    for pid in "${AGENT_PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null
    log "Cleanup done."
    exit 1
}
trap cleanup INT TERM

# ============================================
# v4 HELPERS
# ============================================

# Resolve agent ID from label name (case-insensitive partial match)
resolve_agent_by_name() {
    local name="$1"
    local name_lower
    name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    for id in "${AGENT_IDS[@]}"; do
        local label_lower
        label_lower=$(echo "${AGENT_LABELS[$id]}" | tr '[:upper:]' '[:lower:]')
        if [[ "$label_lower" == *"$name_lower"* ]]; then
            echo "$id"
            return 0
        fi
    done
    return 1
}

# Estimate cost from agent log (tokens * rate)
estimate_agent_cost() {
    local log_file="$1"
    local tokens=0
    [[ ! -f "$log_file" ]] && echo "0 0" && return
    local size
    size=$(wc -c < "$log_file" 2>/dev/null | tr -d '[:space:]')
    # Rough estimate: ~4 chars per token, input+output
    tokens=$(( size / 4 ))
    # Sonnet ~$3/MTok input + $15/MTok output, avg ~$9/MTok
    # microdollars = tokens * 9 / 1000
    local cost_micro=$(( tokens * 9 / 1000 ))
    echo "$tokens $cost_micro"
}

# Check if cost limit exceeded
check_cost_limit() {
    if [[ -n "$COST_LIMIT" ]]; then
        # Convert dollar limit to microdollars
        local limit_micro
        limit_micro=$(echo "$COST_LIMIT" | awk '{printf "%d", $1 * 1000000}')
        if [[ "$CUMULATIVE_COST" -ge "$limit_micro" ]]; then
            local cost_display
            cost_display=$(awk "BEGIN{printf \"%.2f\", $CUMULATIVE_COST / 1000000}")
            log "COST LIMIT REACHED: \$$cost_display >= \$$COST_LIMIT — stopping"
            notify "Cost limit reached: \$$cost_display >= \$$COST_LIMIT" "warning"
            return 1
        fi
    fi
    return 0
}

# Print cycle summary
print_cycle_summary() {
    local cycle_num="$1" agents_run="$2" commits="$3"
    local cost_display
    cost_display=$(awk "BEGIN{printf \"%.4f\", $CUMULATIVE_COST / 1000000}")
    local test_result="n/a"
    if [[ "$CYCLE_TEST_PASS" -gt 0 || "$CYCLE_TEST_FAIL" -gt 0 ]]; then
        test_result="${CYCLE_TEST_PASS} pass / ${CYCLE_TEST_FAIL} fail"
    fi

    echo ""
    echo "┌──────────────────────────────────────────────────┐"
    echo "│              CYCLE $cycle_num SUMMARY                     │"
    echo "├──────────────────────────────────────────────────┤"
    printf "│  Agents run:    %-33s│\n" "$agents_run"
    printf "│  Commits:       %-33s│\n" "$commits"
    printf "│  Est. tokens:   %-33s│\n" "$CUMULATIVE_TOKENS"
    printf "│  Est. cost:     %-33s│\n" "\$$cost_display"
    printf "│  Files changed: %-33s│\n" "$CUMULATIVE_FILES"
    printf "│  Tests:         %-33s│\n" "$test_result"
    echo "└──────────────────────────────────────────────────┘"
    echo ""
}

# Run tests and capture pass/fail counts
run_cycle_tests() {
    CYCLE_TEST_PASS=0
    CYCLE_TEST_FAIL=0
    local test_runner="$PROJECT_ROOT/tests/core/run-tests.sh"
    if [[ -x "$test_runner" ]]; then
        local test_output
        test_output=$(bash "$test_runner" 2>&1) || true
        CYCLE_TEST_PASS=$(echo "$test_output" | grep -c "PASS" 2>/dev/null || echo 0)
        CYCLE_TEST_FAIL=$(echo "$test_output" | grep -c "FAIL" 2>/dev/null || echo 0)
        log "Tests: $CYCLE_TEST_PASS pass, $CYCLE_TEST_FAIL fail"
    fi
}

# Watch mode: monitor files and trigger relevant agents
run_watch_mode() {
    log "WATCH MODE — monitoring for file changes (Ctrl+C to stop)"
    notify "Watch mode started — monitoring file changes"

    local last_hash=""
    while true; do
        local current_hash
        current_hash=$(git -C "$PROJECT_ROOT" diff --stat 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1)
        current_hash="${current_hash}$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1)"

        if [[ "$current_hash" != "$last_hash" && -n "$last_hash" ]]; then
            local changed_files
            changed_files=$(git -C "$PROJECT_ROOT" diff --name-only 2>/dev/null; git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null)
            log "WATCH: Changes detected"

            # Match changed files to agent ownership
            for id in "${AGENT_IDS[@]}"; do
                local interval="${AGENT_INTERVALS[$id]}"
                [[ "$interval" -eq 0 ]] && continue
                local ownership="${AGENT_OWNERSHIP[$id]}"
                IFS=' ' read -ra own_paths <<< "$ownership"
                local matched=false
                for path in "${own_paths[@]}"; do
                    [[ "$path" == !* ]] && continue
                    if echo "$changed_files" | grep -q "^${path}"; then
                        matched=true
                        break
                    fi
                done
                if [[ "$matched" == true ]]; then
                    log "WATCH: Triggering $id (${AGENT_LABELS[$id]}) — owns changed files"
                    run_agent "$id" &
                    wait $! 2>/dev/null || true
                    commit_by_ownership "$id" 2>/dev/null || true
                fi
            done
        fi
        last_hash="$current_hash"
        sleep 5
    done
}

# Show current cycle state without running anything
show_status() {
    parse_config
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  orchystraw v4 — STATUS                         ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    # Current branch
    local branch
    branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "unknown")
    echo "  Branch: $branch"
    echo "  Config: $CONF_FILE"
    echo ""

    # Agent status
    echo "  AGENTS (${#AGENT_IDS[@]} configured):"
    echo "  ─────────────────────────────────────────"
    local state_file="$PROJECT_ROOT/.orchystraw/router-state.txt"
    declare -A LAST_OUTCOME=()
    if [[ -f "$state_file" ]]; then
        while IFS='|' read -r sid _p outcome _ei _es; do
            [[ "$sid" =~ ^# ]] && continue
            [[ -z "$sid" ]] && continue
            LAST_OUTCOME["$sid"]="$outcome"
        done < "$state_file"
    fi

    for id in "${AGENT_IDS[@]}"; do
        local interval="${AGENT_INTERVALS[$id]}"
        local label="${AGENT_LABELS[$id]}"
        local status="${LAST_OUTCOME[$id]:-unknown}"
        local indicator="?"
        case "$status" in
            success) indicator="+" ;;
            fail)    indicator="!" ;;
            skip)    indicator="-" ;;
        esac
        local log_dir="$(dirname "$PROJECT_ROOT/${AGENT_PROMPTS[$id]}")/logs"
        local last_log
        last_log=$(ls -t "$log_dir/${id}-"*.log 2>/dev/null | head -1)
        local last_run="never"
        if [[ -n "$last_log" ]]; then
            last_run=$(date -r "$last_log" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
        fi
        printf "  [%s] %-14s %-22s int=%-2s last=%s\n" "$indicator" "$id" "$label" "$interval" "$last_run"
    done
    echo ""

    # Audit totals
    local audit_file="$PROJECT_ROOT/.orchystraw/audit.jsonl"
    if [[ -f "$audit_file" ]]; then
        local total_inv=0 total_tok=0 total_cost=0
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local tok=0 cost="" prev=""
            for field in $(echo "$line" | tr '{},:"' ' '); do
                case "$prev" in
                    tokens_est) tok="$field" ;;
                    cost_estimate) cost="$field" ;;
                esac
                prev="$field"
            done
            total_inv=$((total_inv + 1))
            total_tok=$((total_tok + tok))
            if [[ -n "$cost" ]]; then
                local cn="${cost//[^0-9]/}"
                cn="${cn:-0}"
                cn=$(( 10#$cn ))
                total_cost=$((total_cost + cn))
            fi
        done < "$audit_file"
        local cost_disp
        cost_disp=$(printf '$0.%06d' "$total_cost")
        echo "  TOTALS (all time):"
        echo "  ─────────────────────────────────────────"
        echo "    Invocations: $total_inv"
        echo "    Tokens:      $total_tok"
        echo "    Est. cost:   $cost_disp"
    fi

    # Recent cycle log
    echo ""
    echo "  RECENT LOG:"
    echo "  ─────────────────────────────────────────"
    tail -10 "$CYCLE_LOG" 2>/dev/null | sed 's/^/    /' || echo "    (no log yet)"
    echo ""
}

# Improved error messages with suggestions
agent_error_suggest() {
    local agent_id="$1" exit_code="$2" log_file="$3"
    local suggestions=""

    if [[ "$exit_code" -eq 1 ]]; then
        if grep -qiE "rate.limit|429|too many requests" "$log_file" 2>/dev/null; then
            suggestions="Rate limited. Try: (1) increase agent interval in agents.conf, (2) use --cost-limit, (3) switch to a cheaper model via dynamic-router"
        elif grep -qiE "prompt.*not found|no such file" "$log_file" 2>/dev/null; then
            suggestions="Prompt file missing. Check: (1) agents.conf path for $agent_id, (2) run 'ls \$PROJECT_ROOT/${AGENT_PROMPTS[$agent_id]:-}'"
        elif grep -qiE "permission denied" "$log_file" 2>/dev/null; then
            suggestions="Permission denied. Try: (1) chmod +x on script files, (2) check file ownership"
        elif grep -qiE "command not found|not recognized" "$log_file" 2>/dev/null; then
            suggestions="Missing command. Try: (1) install claude CLI, (2) check PATH, (3) run 'which claude'"
        elif grep -qiE "timeout|timed out" "$log_file" 2>/dev/null; then
            suggestions="Agent timed out. Try: (1) increase timeout in agent-timeout.sh, (2) simplify the agent prompt, (3) split task into subtasks"
        elif grep -qiE "context.*length|too long|token limit" "$log_file" 2>/dev/null; then
            suggestions="Context too long. Try: (1) enable prompt-compression, (2) reduce shared context, (3) trim session tracker history"
        else
            suggestions="General failure. Check: (1) $log_file for details, (2) agent prompt for errors, (3) git status for conflicts"
        fi
    elif [[ "$exit_code" -eq 2 ]]; then
        suggestions="Misuse of shell builtin. Check: (1) bash version (need 5.0+), (2) syntax errors in prompt"
    elif [[ "$exit_code" -eq 126 ]]; then
        suggestions="Command not executable. Try: chmod +x on the relevant script"
    elif [[ "$exit_code" -eq 127 ]]; then
        suggestions="Command not found. Install missing dependency or check PATH"
    elif [[ "$exit_code" -eq 137 ]]; then
        suggestions="Killed (OOM or SIGKILL). Try: (1) reduce parallel agents, (2) increase system memory, (3) use --max-parallel"
    fi

    if [[ -n "$suggestions" ]]; then
        log "[$agent_id] SUGGESTION: $suggestions"
    fi
}

# ============================================
# CONFIG PARSER
# ============================================

declare -a AGENT_IDS=()
declare -A AGENT_PROMPTS=()
declare -A AGENT_OWNERSHIP=()
declare -A AGENT_INTERVALS=()
declare -A AGENT_LABELS=()

parse_config() {
    if [ ! -f "$CONF_FILE" ]; then
        log "ERROR: Config not found: $CONF_FILE"
        exit 1
    fi

    while IFS='|' read -r id prompt ownership interval label; do
        # Skip comments and blank lines
        [[ "$id" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${id// /}" ]] && continue

        id=$(echo "$id" | xargs)
        prompt=$(echo "$prompt" | xargs)
        ownership=$(echo "$ownership" | xargs)
        interval=$(echo "$interval" | xargs)
        label=$(echo "$label" | xargs)

        AGENT_IDS+=("$id")
        AGENT_PROMPTS["$id"]="$prompt"
        AGENT_OWNERSHIP["$id"]="$ownership"
        AGENT_INTERVALS["$id"]="$interval"
        AGENT_LABELS["$id"]="$label"
    done < "$CONF_FILE"

    log "Loaded ${#AGENT_IDS[@]} agents from config"
}

# ============================================
# AGENT RUNNER
# ============================================

run_agent() {
    local agent_id=$1
    local prompt_file="$PROJECT_ROOT/${AGENT_PROMPTS[$agent_id]}"
    local agent_log_dir
    agent_log_dir="$(dirname "$prompt_file")/logs"
    mkdir -p "$agent_log_dir"
    local log_file
    log_file="$agent_log_dir/${agent_id}-$(date '+%Y%m%d-%H%M%S').log"

    if [ ! -f "$prompt_file" ]; then
        log "[$agent_id] ERROR: Prompt not found: $prompt_file"
        return 1
    fi

    local lines
    lines=$(wc -l < "$prompt_file")
    if [ "$lines" -lt 30 ]; then
        log "[$agent_id] ERROR: Prompt too short ($lines lines) — skipping"
        return 1
    fi

    log "[$agent_id] Starting (${AGENT_LABELS[$agent_id]}, $lines lines)..."

    local context_file="$PROMPTS_DIR/00-shared-context/context.md"

    # Resolve model before piping (subshell can't export vars back)
    local agent_model=""
    if [[ "$(type -t orch_router_model)" == "function" ]]; then
        agent_model=$(orch_router_model "$agent_id" 2>/dev/null) || true
    fi

    {
        # Inject shared context (v0.2: filtered per-agent if available)
        if [ -f "$context_file" ] && [ "$(wc -l < "$context_file")" -gt 5 ]; then
            echo "## SHARED CONTEXT (what other agents built/need this cycle)"
            echo "Read this to understand cross-agent state. Do NOT delete this section."
            echo ""
            if [[ "$(type -t orch_diffctx_filter)" == "function" ]]; then
                orch_diffctx_filter "$agent_id" 2>/dev/null || cat "$context_file"
            else
                cat "$context_file"
            fi
            echo ""
            echo "---"
            echo ""
        fi

        # Cross-cycle history (v0.2: smart windowing if available)
        local tracker_file="$PROMPTS_DIR/00-session-tracker/SESSION_TRACKER.txt"
        if [ -f "$tracker_file" ]; then
            echo ""
            echo "## CROSS-CYCLE HISTORY (read-only — do NOT edit this file)"
            echo "This shows what shipped in ALL previous cycles. Use it to avoid redoing work."
            echo "---"
            if [[ "$(type -t orch_session_window)" == "function" ]]; then
                orch_session_window "$tracker_file" 2>/dev/null || tail -150 "$tracker_file"
            else
                tail -150 "$tracker_file"
            fi
            echo "---"
            echo ""
        fi

        # Agent's actual prompt
        cat "$prompt_file"

        echo ""
        echo "---"
        echo ""
        echo "## AFTER YOU FINISH — Update Shared Context"
        echo "Append what you built, changed, or need to: prompts/00-shared-context/context.md"
        echo "Format: Under the appropriate section (Backend/iOS/Design/QA Status), add bullet points."
        echo "Example: '- Added POST /api/notes/batch endpoint (accepts array of note IDs)'"
        echo "Example: '- NEED: GET /api/search endpoint from backend'"
        echo "Example: '- BREAKING: Changed API response format for /users endpoint'"
        echo "Do NOT clear the file. Only APPEND under the right section."
    } | {
        # v0.2: model tiering — pass agent-specific model if router available
        local -a claude_args=(-p --dangerously-skip-permissions --output-format text)
        if [[ -n "$agent_model" && "$agent_model" != "default" ]]; then
            claude_args+=(--model "$agent_model")
        fi
        claude "${claude_args[@]}"
    } > "$log_file" 2>&1

    [[ -n "$agent_model" ]] && log "[$agent_id] Used model: $agent_model"

    local exit_code=$?
    local log_size
    log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)

    # v0.3: model fallback — retry with cheaper model on rate-limit (#160)
    if [[ "$exit_code" -ne 0 && "$(type -t orch_router_is_rate_limited)" == "function" ]]; then
        if orch_router_is_rate_limited "$log_file"; then
            local current_model="${agent_model:-}"
            # Map flag back to name if needed
            case "$current_model" in
                claude-opus-4-6)     current_model="opus" ;;
                claude-sonnet-4-6)   current_model="sonnet" ;;
                claude-haiku-4-5)    current_model="haiku" ;;
            esac
            while [[ "$exit_code" -ne 0 && -n "$current_model" ]]; do
                local fallback
                fallback=$(orch_router_model_fallback "$current_model" 2>/dev/null)
                [[ -z "$fallback" ]] && break
                local fallback_flag
                fallback_flag=$(orch_router_fallback_flag "$fallback" 2>/dev/null)
                log "[$agent_id] Rate-limited on $current_model, falling back to: $fallback ($fallback_flag)"
                claude -p --dangerously-skip-permissions --output-format text --model "$fallback_flag" \
                    < "$prompt_file" > "$log_file" 2>&1
                exit_code=$?
                agent_model="$fallback_flag"
                if [[ "$exit_code" -ne 0 ]] && orch_router_is_rate_limited "$log_file"; then
                    current_model="$fallback"
                else
                    break
                fi
            done
        fi
        log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
    fi

    if [ "$exit_code" -ne 0 ]; then
        log "[$agent_id] WARNING: Exit code $exit_code"
        agent_error_suggest "$agent_id" "$exit_code" "$log_file"
    elif [ "$log_size" -lt 100 ]; then
        log "[$agent_id] WARNING: Tiny output ($log_size bytes)"
        log "[$agent_id] SUGGESTION: Agent produced minimal output. Check: (1) prompt has enough content, (2) shared context is not empty, (3) claude CLI is working"
    else
        log "[$agent_id] Finished ($log_size bytes output)"
    fi

    # v4: Track cumulative cost/tokens
    local _est
    _est=$(estimate_agent_cost "$log_file")
    local _tok _cost_m
    _tok=$(echo "$_est" | cut -d' ' -f1)
    _cost_m=$(echo "$_est" | cut -d' ' -f2)
    CUMULATIVE_TOKENS=$((CUMULATIVE_TOKENS + _tok))
    CUMULATIVE_COST=$((CUMULATIVE_COST + _cost_m))
}

# ============================================
# GIT OPERATIONS (script-controlled, no races)
# ============================================

create_cycle_branch() {
    local cycle_num=$1
    local branch_name
    branch_name="auto/cycle-${cycle_num}-$(date '+%m%d-%H%M')"
    git checkout -b "$branch_name" 2>/dev/null
    # IMPORTANT: log to stderr so $() capture only gets the branch name
    log "Created branch: $branch_name" >&2
    echo "$branch_name"
}

commit_by_ownership() {
    local agent_id=$1
    local ownership="${AGENT_OWNERSHIP[$agent_id]}"

    [ "$ownership" = "none" ] && return 0

    # Build arrays instead of eval strings (fixes HIGH-01 eval injection)
    local -a include_args=()
    local -a exclude_args=()

    IFS=' ' read -ra _ownership_arr <<< "$ownership"
    for path in "${_ownership_arr[@]}"; do
        if [[ "$path" == !* ]]; then
            exclude_args+=(":(exclude)${path#!}")
        else
            include_args+=("$path")
        fi
    done

    if [[ ${#include_args[@]} -eq 0 ]]; then return 0; fi

    local -a pathspec=("--" "${include_args[@]}" "${exclude_args[@]}")

    # Check for changes in owned paths
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

detect_rogue_writes() {
    # ── PROTECTED FILES: no agent may ever touch these, even if in their ownership ──
    # These are restored FIRST before ownership checks.
    local PROTECTED_FILES=(
        "scripts/auto-agent.sh"        # The orchestrator itself
        "scripts/agents.conf"           # Agent config — only humans edit this
        "scripts/check-usage.sh"        # Usage checker
        "scripts/check-domain.sh"       # Domain checker
        ".orchystraw/"                  # App data layer (future)
        "CLAUDE.md"                     # Root project instructions
    )

    # Find all modified/untracked files
    local all_changes
    all_changes=$(git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)

    if [ -z "$all_changes" ]; then return 0; fi

    # ── Pass 1: Restore any protected files immediately ──
    local protected_violations=""
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        for protected in "${PROTECTED_FILES[@]}"; do
            if [[ "$file" == ${protected}* ]]; then
                protected_violations+="  $file\n"
                git checkout -- "$file" 2>/dev/null || git rm --cached "$file" 2>/dev/null
                break
            fi
        done
    done <<< "$all_changes"

    if [ -n "$protected_violations" ]; then
        log "CRITICAL: Agent tried to modify PROTECTED files (restored):"
        echo -e "$protected_violations" | while read -r f; do
            [ -n "$f" ] && log "  PROTECTED VIOLATION: $f"
        done
        notify "Agent tried to modify protected files — restored automatically" "warning"
    fi

    # Refresh change list after protected restores
    all_changes=$(git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
    [ -z "$all_changes" ] && return 0

    # ── Pass 2: Rogue writes (outside all ownership boundaries) ──
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

    local rogue_files=""
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local is_owned=false
        for path in "${all_owned_arr[@]}"; do
            if [[ "$file" == ${path}* ]]; then
                is_owned=true
                break
            fi
        done
        if [ "$is_owned" = false ]; then
            rogue_files+="  $file\n"
        fi
    done <<< "$all_changes"

    if [ -n "$rogue_files" ]; then
        log "WARNING: Rogue writes detected (outside all ownership):"
        echo -e "$rogue_files" | while read -r f; do
            [ -n "$f" ] && log "  ROGUE: $f"
        done
        # Discard rogue writes (don't commit them)
        echo -e "$rogue_files" | while read -r f; do
            [ -n "$f" ] && git checkout -- "$f" 2>/dev/null
        done
        notify "Rogue writes detected — agents wrote outside ownership" "warning"
        return 1
    fi
    return 0
}

merge_cycle_branch() {
    local branch_name=$1
    local cycle_num=$2
    local commit_count
    commit_count=$(git log --oneline main.."$branch_name" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$commit_count" -gt 0 ]; then
        git checkout main 2>/dev/null

        # Merge with conflict detection
        if git merge "$branch_name" --no-ff -m "Merge auto/cycle-${cycle_num}: ${commit_count} commits from agents" 2>/dev/null; then
            # Push with retry on failure
            if git push origin main 2>/dev/null; then
                log "Merged + pushed $commit_count commits to main"
            else
                log "Push failed — trying pull --rebase then push"
                git pull --rebase origin main 2>/dev/null && git push origin main 2>/dev/null || log "ERROR: Push still failed after rebase"
            fi
            git branch -d "$branch_name" 2>/dev/null
            return 0
        else
            log "ERROR: Merge conflict on $branch_name. Aborting merge, keeping branch."
            notify "Merge conflict on $branch_name — needs manual fix" "warning"
            git merge --abort 2>/dev/null
            git checkout main 2>/dev/null
            # Don't delete branch — keep it for manual resolution
            return 1
        fi
    else
        git checkout main 2>/dev/null
        git branch -d "$branch_name" 2>/dev/null
        log "No commits on cycle branch — deleted"
        return 1
    fi
}

# ============================================
# PM COORDINATOR
# ============================================

run_pm() {
    local log_file
    log_file="$PM_LOG_DIR/01-pm-$(date '+%Y%m%d-%H%M%S').log"
    local cycle_num=$1

    log "[01-PM] Starting autonomous review (cycle $cycle_num)..."

    # Build agent list for PM context
    local agent_list=""
    for id in "${AGENT_IDS[@]}"; do
        agent_list+="  - $id (${AGENT_LABELS[$id]}): ${AGENT_PROMPTS[$id]} | owns: ${AGENT_OWNERSHIP[$id]}\n"
    done

    {
        echo "## AUTONOMOUS MODE"
        echo ""
        echo "You are running FULLY AUTONOMOUSLY in cycle $cycle_num on branch $(git branch --show-current 2>/dev/null). No human is watching."
        echo "Take ALL actions yourself. Never ask for confirmation."
        echo "Never say 'tell CS' or 'CS should'. Just do it."
        echo ""
        echo "## REGISTERED AGENTS"
        echo ""
        echo -e "$agent_list"
        echo ""
        echo "---"
        echo ""
        cat "$PM_PROMPT"
        echo ""
        echo "---"
        echo ""
        # Inject pre-PM lint report if available (saves PM from doing raw analysis)
        if [ -n "${LINT_REPORT:-}" ]; then
            echo "## PRE-PM LINT REPORT (auto-generated — trust these stats)"
            echo "This report was generated by scripts, not an agent. Use it instead of running git log/status yourself."
            echo ""
            echo "$LINT_REPORT"
            echo ""
            echo "---"
            echo ""
        fi

        echo "## CYCLE $cycle_num TASKS — Execute All Steps"
        echo ""
        echo "### Step 0: Read Shared Context + Lint Report"
        echo "- The LINT REPORT above has per-agent stats, commit counts, and health checks — use it"
        echo "- Read prompts/00-shared-context/context.md for qualitative updates from agents"
        echo "- Only read agent logs if the lint report flags errors"
        echo ""
        echo "### Progress Checkpoint (from last cycle)"
        echo '```json'
        cat "$PROMPTS_DIR/00-shared-context/progress.json" 2>/dev/null || echo '{}'
        echo '```'
        echo ""
        echo "### Step 1: Review what agents built"
        echo "- git log --oneline -20"
        echo "- git status --short"
        echo "- find backend/src -name '*.ts' | wc -l"
        echo "- find ios -name '*.swift' | wc -l"
        echo ""
        echo "### Step 2: Commit any remaining uncommitted work (you are on a feature branch)"
        echo "- git add backend/ && git commit -m 'feat(backend): auto-cycle $cycle_num' (if changes)"
        echo "- git add ios/ && git commit -m 'feat(ios): auto-cycle $cycle_num' (if changes)"
        echo "- Do NOT push or merge — the script handles merging to main after you finish"
        echo ""
        echo "### GIT SAFETY RULES (CRITICAL — NEVER VIOLATE)"
        echo "- NEVER run: git checkout, git switch, git merge, git push, git reset, git rebase"
        echo "- NEVER switch branches — you MUST stay on the current feature branch the entire time"
        echo "- ONLY allowed git commands: git add, git commit, git status, git log, git diff"
        echo "- The orchestrator script handles ALL branch management — if you switch branches you WILL corrupt the cycle"
        echo "- Do NOT delete prompt directories or files — only overwrite prompt .txt file contents"
        echo ""
        echo "### Step 3: Check GitHub"
        echo "- gh api repos/OWNER/REPO/milestones --jq '.[] | select(.open_issues > 0) | \"\\(.title): \\(.open_issues) open / \\(.closed_issues) closed\"'"
        echo "- gh issue list --repo OWNER/REPO --state open --limit 30"
        echo "- Close any completed issues"
        echo ""
        echo "### Step 4: Update TASK SECTIONS in agent prompts"
        echo "IMPORTANT: Do NOT rewrite entire prompts. The script handles timestamps + file counts."
        echo "For each agent prompt, ONLY update these sections:"
        echo "- 'What's DONE' — add what this cycle completed (from shared context)"
        echo "- 'YOUR TASKS' / 'YOUR NEXT TASKS' — assign next work from open GitHub issues"
        echo "- 'Agent Status Summary' (in PM prompt only) — update per-agent status"
        echo "- Keep ALL other sections intact (tech stack, file ownership, design system, auto-cycle mode)"
        echo ""
        echo "Use the Edit tool to modify specific sections. Do NOT use Write to overwrite the file."
        echo ""
        echo "Agent prompts:"
        for id in "${AGENT_IDS[@]}"; do
            echo "  $id: ${AGENT_PROMPTS[$id]} | owns: ${AGENT_OWNERSHIP[$id]}"
        done
        echo ""
        echo "### Step 5: Update YOUR OWN prompt"
        echo "Update prompts/01-pm/01-project-manager.txt:"
        echo "- Update 'Agent Status Summary' with what each agent built"
        echo "- Update milestone open/closed counts"
        echo "- Do NOT change file counts or timestamps (script handles those)"
        echo ""
        echo "### Step 6: Update prompts/00-session-tracker/SESSION_TRACKER.txt"
        echo "- Add a new WHAT SHIPPED section for this cycle with timestamp"
        echo "- List what each agent built (from shared context + git log)"
        echo "- Update MILESTONE DASHBOARD with current open/closed counts"
        echo "- Update CODEBASE SIZE with current file counts"
        echo "- Update NEXT CYCLE priorities based on what's left"
        echo ""
        echo "### Step 7: Update prompts/99-me/99-cs-actions.txt"
        echo "- Review agent logs and shared context for new action items CS needs to do"
        echo "- Append new P0/P1/P2 items under ## PENDING (Xcode tasks, API keys, manual steps)"
        echo "- Move completed items to ## DONE with date"
        echo "- Do NOT delete existing items — only append or move"
        echo ""
        echo "DO NOT ask questions. Write all files and exit."
    } | claude \
        -p \
        --dangerously-skip-permissions \
        --output-format text \
        > "$log_file" 2>&1

    log "[01-PM] Finished"
}

# ============================================
# SAFETY
# ============================================

backup_prompts() {
    local dir
    dir="$BACKUP_DIR/cycle-$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$dir"
    for id in "${AGENT_IDS[@]}"; do
        cp "$PROJECT_ROOT/${AGENT_PROMPTS[$id]}" "$dir/" 2>/dev/null
    done
    cp "$PM_PROMPT" "$dir/" 2>/dev/null
    cp "$PROMPTS_DIR/00-session-tracker/SESSION_TRACKER.txt" "$dir/" 2>/dev/null
    cp "$PROMPTS_DIR/00-shared-context/context.md" "$dir/" 2>/dev/null
    log "Prompts backed up to $dir"

    # Rotate old backups (keep 7 days)
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "cycle-*" -mtime +7 -exec rm -rf {} \; 2>/dev/null

    # Rotate old shared context logs (keep 7 days)
    find "$PROMPTS_DIR/00-shared-context" -name "context-cycle-*.md" -mtime +7 -delete 2>/dev/null
}

validate_prompts() {
    local latest_backup
    latest_backup=$(ls -td "$BACKUP_DIR/"* 2>/dev/null | head -1)
    for id in "${AGENT_IDS[@]}"; do
        local f="$PROJECT_ROOT/${AGENT_PROMPTS[$id]}"
        local dir
        dir=$(dirname "$f")

        # Ensure directory exists (PM may have deleted it)
        if [ ! -d "$dir" ]; then
            log "WARNING: Directory missing for $id — recreating"
            mkdir -p "$dir"
        fi

        # Check file exists and has reasonable content
        local lines=0
        if [ -f "$f" ]; then
            lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        fi

        if [ "$lines" -lt 50 ]; then
            log "WARNING: ${AGENT_PROMPTS[$id]} corrupted or missing ($lines lines). Restoring from backup."
            if [ -n "$latest_backup" ] && [ -f "$latest_backup/$(basename "$f")" ]; then
                cp "$latest_backup/$(basename "$f")" "$f"
                log "Restored ${AGENT_PROMPTS[$id]} from backup"
            else
                log "ERROR: No backup found for ${AGENT_PROMPTS[$id]} — manual fix needed"
            fi
        fi
    done

    # Also validate PM prompt
    local pm_lines=0
    if [ -f "$PM_PROMPT" ]; then
        pm_lines=$(wc -l < "$PM_PROMPT" 2>/dev/null || echo 0)
    fi
    if [ "$pm_lines" -lt 50 ]; then
        log "WARNING: PM prompt corrupted ($pm_lines lines). Restoring from backup."
        local pm_basename
        pm_basename=$(basename "$PM_PROMPT")
        if [ -n "$latest_backup" ] && [ -f "$latest_backup/$pm_basename" ]; then
            cp "$latest_backup/$pm_basename" "$PM_PROMPT"
        fi
    fi
}

# ============================================
# MAIN
# ============================================

# ── Parse --dry-run from CLI args (if module loaded) ──
if [[ "$(type -t orch_dry_run_init)" == "function" ]]; then
    orch_dry_run_init "$@"
fi

case "${1:-help}" in
    orchestrate)
        # v4: Parse orchestrate-specific flags
        shift  # remove 'orchestrate'
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --cost-limit)  COST_LIMIT="$2"; shift 2 ;;
                --max-parallel) MAX_PARALLEL="$2"; shift 2 ;;
                --watch)       WATCH_MODE=true; shift ;;
                --dry-run)     shift ;;  # handled by dry-run module
                [0-9]*)        MAX_CYCLES="$1"; shift ;;
                *)             shift ;;  # skip unknown
            esac
        done

        parse_config

        # v4: watch mode — monitor file changes instead of cycle loop
        if [[ "$WATCH_MODE" == true ]]; then
            run_watch_mode
            exit 0
        fi

        CYCLE=1
        declare -a AGENT_PIDS=()

        # ── Initialize dynamic router (v0.2: model tiering + routing) ──
        if [[ "$(type -t orch_router_init)" == "function" ]]; then
            orch_router_init "$CONF_FILE" 2>/dev/null
            _router_state="$PROJECT_ROOT/.orchystraw/router-state.json"
            [ -f "$_router_state" ] && orch_router_load_state "$_router_state" 2>/dev/null
            log "Dynamic router initialized"
        fi

        echo "╔══════════════════════════════════════════════════╗"
        echo "║  orchystraw v3 — ${#AGENT_IDS[@]} agents configured     ║"
        echo "║  Max: ${MAX_CYCLES:-∞} cycles │ No delay between cycles   ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo ""
        for id in "${AGENT_IDS[@]}"; do
            interval="${AGENT_INTERVALS[$id]}"
            if [ "$interval" -eq 0 ]; then
                echo "  $id (coordinator, runs last) — ${AGENT_LABELS[$id]}"
            else
                echo "  $id (every $interval cycles) — ${AGENT_LABELS[$id]}"
            fi
        done
        echo ""

        # ── Dry-run: print what would happen and exit ──
        if [[ "$(type -t orch_is_dry_run)" == "function" ]] && orch_is_dry_run; then
            orch_dry_run_report "$CONF_FILE" "${CYCLE:-1}"
            exit 0
        fi

        notify "Starting: ${#AGENT_IDS[@]} agents, max ${MAX_CYCLES:-∞} cycles"

        while true; do
            log "━━━ CYCLE $CYCLE ━━━"

            # Check for manual/auto pause signal (from agents, stall detector, or CS)
            if [ -f "$PROJECT_ROOT/.orchestrator-pause" ]; then
                pause_reason=$(cat "$PROJECT_ROOT/.orchestrator-pause" 2>/dev/null || echo "unknown")
                log "ORCHESTRATOR PAUSED: $pause_reason"
                notify "Orchestrator paused: $pause_reason" "error"
                log "Remove .orchestrator-pause file to resume"
                break
            fi

            # Check usage limits before starting cycle
            usage_file="$PROMPTS_DIR/00-shared-context/usage.txt"
            bash "$PROJECT_ROOT/scripts/check-usage.sh" 2>/dev/null
            if [ -f "$usage_file" ]; then
                usage_pct=$(grep -oP '\d+' "$usage_file" 2>/dev/null | head -1)
                if [ -n "$usage_pct" ] && [ "$usage_pct" -ge 70 ] 2>/dev/null; then
                    log "PAUSED: Claude Code usage at ${usage_pct}% (threshold: 70%)"
                    notify "Paused: usage at ${usage_pct}% — waiting for reset" "warning"
                    sleep 60  # re-check every 60s when usage-paused
                    continue
                fi
            fi

            # ── Step 1: Create feature branch for this cycle ──
            git checkout main 2>/dev/null
            git pull origin main 2>/dev/null || true

            # Archive previous cycle's shared context before reset
            context_file="$PROMPTS_DIR/00-shared-context/context.md"
            if [ -f "$context_file" ] && [ "$(wc -l < "$context_file")" -gt 10 ]; then
                cp "$context_file" "$PROMPTS_DIR/00-shared-context/context-cycle-$((CYCLE - 1)).md" 2>/dev/null
            fi

            # Reset shared context for this cycle
            usage_val=$(cat "$usage_file" 2>/dev/null || echo 0)
            prev_progress=$(cat "$PROMPTS_DIR/00-shared-context/progress.json" 2>/dev/null || echo '{}')
            prev_backend=$(echo "$prev_progress" | grep -o '"backend_files": [0-9]*' | grep -o '[0-9]*' || echo '?')
            prev_frontend=$(echo "$prev_progress" | grep -o '"frontend_files": [0-9]*' | grep -o '[0-9]*' || echo '?')
            prev_commits=$(echo "$prev_progress" | grep -o '"commits": [0-9]*' | grep -o '[0-9]*' || echo '?')
            prev_cycle_num=$(echo "$prev_progress" | grep -o '"cycle": [0-9]*' | grep -o '[0-9]*' || echo '?')

            cat > "$context_file" << CTXEOF
# Shared Context — Cycle $CYCLE — $(timestamp)
> Agents: read before starting, append before finishing.

## Usage
- API status: ${usage_val} (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: $prev_cycle_num ($prev_backend backend, $prev_frontend frontend, $prev_commits commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- (fresh cycle)

## iOS Status
- (fresh cycle)

## Design Status
- (fresh cycle)

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## Notes
- (none)
CTXEOF
            log "Shared context reset for cycle $CYCLE"

            CYCLE_BRANCH=$(create_cycle_branch "$CYCLE")
            AGENT_PIDS=()
            AGENTS_RUN=0

            # ── Step 1.5: Refresh qmd index on QA cycles ──
            if command -v qmd &>/dev/null; then
                # Always update index (fast), embed only on QA cycles (slower)
                qmd update 2>/dev/null
                # QA runs every 5 cycles — re-embed before QA for fresh semantic search
                for id_check in "${AGENT_IDS[@]}"; do
                    interval_check="${AGENT_INTERVALS[$id_check]}"
                    if [ "$interval_check" -gt 1 ] && { [ $((CYCLE % interval_check)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; }; then
                        qmd embed 2>/dev/null
                        log "qmd re-indexed + re-embedded for QA cycle"
                        break
                    fi
                done
            fi

            # ── Step 1.6: Pre-cycle stats ──
            [ -x "$SCRIPT_DIR/pre-cycle-stats.sh" ] && bash "$SCRIPT_DIR/pre-cycle-stats.sh" "$PROJECT_ROOT" 2>/dev/null

            # ── Step 1.7: Initialize efficiency modules ──
            # Conditional activation: skip agents with no work
            if [[ "$(type -t orch_activation_init)" == "function" ]]; then
                orch_activation_init "$CONF_FILE" 2>/dev/null
                changed_files=$(git diff --name-only HEAD~3 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
                orch_activation_set_changed "$changed_files" 2>/dev/null
                [ -f "$context_file" ] && orch_activation_set_context "$(cat "$context_file")" 2>/dev/null
            fi

            # Worktree isolation: per-agent git worktrees
            if [[ "$(type -t orch_worktree_init)" == "function" ]]; then
                orch_worktree_init "$PROJECT_ROOT" 2>/dev/null
            fi

            # Differential context: per-agent context filtering
            if [[ "$(type -t orch_diffctx_init)" == "function" ]]; then
                orch_diffctx_init "$CONF_FILE" 2>/dev/null
                [ -f "$context_file" ] && orch_diffctx_parse "$context_file" 2>/dev/null
            fi

            # ── Step 1.8: Freshness check on prompts ──
            if [[ "$(type -t orch_freshness_init)" == "function" ]]; then
                orch_freshness_init 7 2>/dev/null
                orch_freshness_scan "$PROJECT_ROOT/prompts" 2>/dev/null
                local stale_count
                stale_count=$(orch_freshness_stale_count 2>/dev/null)
                if [[ "$stale_count" -gt 0 ]]; then
                    log "[freshness] $stale_count stale references found in prompts/"
                fi
            fi

            # ── Step 2: Run eligible agents in parallel (on feature branch) ──
            # v4: max-parallel cap — use process pool pattern when limit set
            _running_agents=0
            for id in "${AGENT_IDS[@]}"; do
                interval="${AGENT_INTERVALS[$id]}"
                # interval=0 means coordinator — skip in worker loop (runs via run_pm)
                if [ "$interval" -eq 0 ]; then
                    continue
                elif [ $((CYCLE % interval)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; then
                    # v0.2: Check conditional activation (skip agents with no work)
                    if [[ "$(type -t orch_activation_check)" == "function" ]]; then
                        if ! orch_activation_check "$id" 2>/dev/null; then
                            log "[$id] Skipping (no work detected: $(orch_activation_reason "$id" 2>/dev/null))"
                            continue
                        fi
                    fi

                    # v4: wait if max-parallel reached (process pool pattern)
                    if [[ "$MAX_PARALLEL" -gt 0 && "$_running_agents" -ge "$MAX_PARALLEL" ]]; then
                        log "Max parallel ($MAX_PARALLEL) reached — waiting for a slot..."
                        wait -n 2>/dev/null || true
                        _running_agents=$((_running_agents - 1))
                    fi

                    # v0.2: worktree isolation — agent gets its own checkout
                    _use_worktree=false
                    if [[ "$(type -t orch_worktree_enabled)" == "function" ]] && orch_worktree_enabled 2>/dev/null; then
                        if orch_worktree_create "$id" "$CYCLE" 2>/dev/null; then
                            _use_worktree=true
                        fi
                    fi

                    # v0.2: wrap with timeout if available
                    if [[ "$_use_worktree" == true ]]; then
                        _wt_path=$(orch_worktree_path "$id" "$CYCLE" 2>/dev/null)
                        (cd "$_wt_path" && run_agent "$id") &
                    elif [[ "$(type -t orch_run_with_timeout)" == "function" ]]; then
                        _agent_timeout=$(orch_get_agent_timeout "$id" 2>/dev/null || echo 600)
                        orch_run_with_timeout "$_agent_timeout" run_agent "$id" &
                    else
                        run_agent "$id" &
                    fi
                    AGENT_PIDS+=($!)
                    AGENTS_RUN=$((AGENTS_RUN + 1))
                    _running_agents=$((_running_agents + 1))
                else
                    log "[$id] Skipping (runs every $interval cycles)"
                fi
            done

            log "$AGENTS_RUN agents launched on branch $CYCLE_BRANCH"

            # Wait for all and track exit codes
            AGENT_FAILURES=0
            for pid in "${AGENT_PIDS[@]}"; do
                wait "$pid" 2>/dev/null || AGENT_FAILURES=$((AGENT_FAILURES + 1))
            done

            if [ "$AGENT_FAILURES" -eq "$AGENTS_RUN" ] && [ "$AGENTS_RUN" -gt 0 ]; then
                log "ALL $AGENTS_RUN agents FAILED — skipping PM review"
                EMPTY_CYCLES=$((EMPTY_CYCLES + 1))
                git checkout main 2>/dev/null
                git branch -d "$CYCLE_BRANCH" 2>/dev/null
                if [ "$EMPTY_CYCLES" -ge "$MAX_EMPTY_CYCLES" ]; then
                    log "STOPPING: $MAX_EMPTY_CYCLES consecutive failures/empty"
                    notify "Orchestrator stopped: $MAX_EMPTY_CYCLES consecutive failures" "error"
                    break
                fi
                CYCLE=$((CYCLE + 1))
                log "All agents failed — retrying in 30s..."
                sleep 30
                continue
            fi

            log "Agents finished ($AGENT_FAILURES/$AGENTS_RUN failed)"

            # v0.2: Update router state with agent outcomes
            if [[ "$(type -t orch_router_update)" == "function" ]]; then
                for id in "${AGENT_IDS[@]}"; do
                    interval="${AGENT_INTERVALS[$id]}"
                    [ "$interval" -eq 0 ] && continue
                    if [ $((CYCLE % interval)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; then
                        _agent_log_dir="$(dirname "$PROJECT_ROOT/${AGENT_PROMPTS[$id]}")/logs"
                        _latest_log=$(ls -t "$_agent_log_dir/${id}-"*.log 2>/dev/null | head -1)
                        _outcome="success"
                        if [[ -n "$_latest_log" ]]; then
                            _lsize=$(wc -c < "$_latest_log" 2>/dev/null || echo 0)
                            [[ "$_lsize" -lt 100 ]] && _outcome="skip"
                        else
                            _outcome="fail"
                        fi
                        orch_router_update "$id" "$_outcome" "$CYCLE" 2>/dev/null
                    fi
                done
            fi

            # v0.2: Merge worktrees back into cycle branch
            if [[ "$(type -t orch_worktree_enabled)" == "function" ]] && orch_worktree_enabled 2>/dev/null; then
                for id in "${AGENT_IDS[@]}"; do
                    interval="${AGENT_INTERVALS[$id]}"
                    [ "$interval" -eq 0 ] && continue
                    if [ $((CYCLE % interval)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; then
                        orch_worktree_merge "$id" "$CYCLE" 2>/dev/null && log "[$id] Worktree merged"
                    fi
                done
                orch_worktree_cleanup "$CYCLE" 2>/dev/null
            fi

            # ── Step 2.5: Quality gates — validate agent output before commit (#145) ──
            if [[ "$(type -t orch_quality_init)" == "function" ]]; then
                orch_quality_init "$PROJECT_ROOT" "$CONF_FILE" 2>/dev/null
            fi

            # ── Step 3: Commit agent work by ownership (on feature branch) ──
            COMMITS=0
            for id in "${AGENT_IDS[@]}"; do
                interval="${AGENT_INTERVALS[$id]}"
                # Skip coordinator (interval=0) — PM commits handled separately
                [ "$interval" -eq 0 ] && continue
                if [ $((CYCLE % interval)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; then
                    # v0.2: quality gate check before commit
                    if [[ "$(type -t orch_quality_check)" == "function" ]]; then
                        _qg_log_dir="$(dirname "$PROJECT_ROOT/${AGENT_PROMPTS[$id]}")/logs"
                        _qg_log=$(ls -t "$_qg_log_dir/${id}-"*.log 2>/dev/null | head -1)
                        if ! orch_quality_check "$id" "$_qg_log" 2>/dev/null; then
                            log "[$id] Quality gate FAILED — skipping commit"
                            continue
                        fi
                    fi
                    commit_by_ownership "$id" && COMMITS=$((COMMITS + 1))
                fi
            done

            if [ "$COMMITS" -eq 0 ]; then
                log "No commits this cycle (agents ran but produced no file changes)"
            fi

            # ── Step 3.4: Review phase (v0.2: QA auto-review of agent work) ──
            if [[ "$(type -t orch_review_init)" == "function" ]]; then
                orch_review_init "$CONF_FILE" "$PM_LOG_DIR" 2>/dev/null
                # Build list of agents that committed this cycle
                _committed_agents=()
                for id in "${AGENT_IDS[@]}"; do
                    interval="${AGENT_INTERVALS[$id]}"
                    [ "$interval" -eq 0 ] && continue
                    if [ $((CYCLE % interval)) -eq 0 ] || [ "$CYCLE" -eq 1 ]; then
                        _committed_agents+=("$id")
                    fi
                done
                if [[ ${#_committed_agents[@]} -gt 0 ]]; then
                    _review_usage_pct=$(grep -oP '\d+' "$usage_file" 2>/dev/null | head -1 || echo 0)
                    if orch_review_should_run "${_review_usage_pct:-0}" 2>/dev/null; then
                        orch_review_plan "$CYCLE" "${_committed_agents[@]}" 2>/dev/null
                        log "Review phase: $(orch_review_summary 2>/dev/null)"
                    else
                        log "Review phase skipped (usage too high)"
                    fi
                fi
            fi

            # Stall detector — check if we're producing meaningful work
            if type stall_check_cycle &>/dev/null; then
                stall_check_cycle "$CYCLE"
                if stall_should_pause; then
                    log "STALL DETECTED: $STALL_MAX_IDLE consecutive idle cycles — auto-pausing"
                    echo "stall-detector: $STALL_MAX_IDLE idle cycles at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROJECT_ROOT/.orchestrator-pause"
                    notify "Orchestrator auto-paused: $STALL_MAX_IDLE idle cycles" "error"
                    break
                fi
            fi

            # ── Step 3.5: Detect rogue writes + post-commit scans ──
            detect_rogue_writes
            [ -x "$SCRIPT_DIR/commit-summary.sh" ] && bash "$SCRIPT_DIR/commit-summary.sh" "HEAD~${COMMITS:-1}" "$PROJECT_ROOT" > "$PM_LOG_DIR/commit-summary-cycle-${CYCLE}.md" 2>/dev/null
            [ -x "$SCRIPT_DIR/secrets-scan.sh" ] && bash "$SCRIPT_DIR/secrets-scan.sh" "$PROJECT_ROOT" > "$PM_LOG_DIR/secrets-scan-cycle-${CYCLE}.md" 2>/dev/null
            [ -x "$SCRIPT_DIR/agent-health-report.sh" ] && bash "$SCRIPT_DIR/agent-health-report.sh" "$PROJECT_ROOT" > "$PM_LOG_DIR/health-report-cycle-${CYCLE}.md" 2>/dev/null

            # ── Step 3.7: Pre-PM lint (free, instant — digests cycle for PM) ──
            LINT_REPORT=""
            if [ -f "$SCRIPT_DIR/pre-pm-lint.sh" ]; then
                LINT_REPORT=$(bash "$SCRIPT_DIR/pre-pm-lint.sh" "$CYCLE" "$PROJECT_ROOT" 2>/dev/null)
                log "Pre-PM lint complete"

                # Check if lint says to skip PM
                if echo "$LINT_REPORT" | grep -q "Recommendation: PM SKIP"; then
                    log "QUIET CYCLE — lint recommends skipping PM review"
                    # Still backup prompts, but skip expensive PM agent
                    backup_prompts
                    # Write lint report for record
                    echo "$LINT_REPORT" > "$PM_LOG_DIR/lint-cycle-${CYCLE}.md"

                    # Jump to merge (skip run_pm)
                    git add prompts/ docs/ 2>/dev/null
                    git diff --cached --quiet 2>/dev/null || git commit -m "chore: cycle $CYCLE lint-only (PM skipped)" 2>/dev/null
                    merge_cycle_branch "$CYCLE_BRANCH" "$CYCLE"
                    validate_prompts

                    [ -x "$SCRIPT_DIR/cycle-metrics.sh" ] && bash "$SCRIPT_DIR/cycle-metrics.sh" "$CYCLE" "$COMMITS" "$PROJECT_ROOT" 2>/dev/null
                    log "CYCLE $CYCLE DONE (lint-only, PM skipped) — $COMMITS commits"
                    notify "Cycle $CYCLE done (PM skipped — quiet cycle)"

                    if [ "$MAX_CYCLES" -gt 0 ] && [ "$CYCLE" -ge "$MAX_CYCLES" ]; then
                        log "Max cycles reached ($CYCLE/$MAX_CYCLES)"
                        notify "Finished $CYCLE cycles"
                        break
                    fi
                    CYCLE=$((CYCLE + 1))
                    sleep 5
                    continue
                fi
            fi

            # ── Step 4: PM reviews on the feature branch ──
            backup_prompts
            run_pm "$CYCLE"

            # Safety: PM may have switched branches — force back to cycle branch
            current_branch=$(git branch --show-current 2>/dev/null)
            if [ "$current_branch" != "$CYCLE_BRANCH" ]; then
                log "WARNING: PM switched to '$current_branch' — recovering to $CYCLE_BRANCH"
                git checkout "$CYCLE_BRANCH" 2>/dev/null
            fi

            # PM may have written prompt + session tracker + shared context updates
            git add prompts/ docs/ 2>/dev/null
            git diff --cached --quiet 2>/dev/null || git commit -m "chore(pm): cycle $CYCLE prompt + tracker updates" 2>/dev/null

            # ── Step 5: Merge feature branch → main ──
            merge_cycle_branch "$CYCLE_BRANCH" "$CYCLE"
            validate_prompts

            # ── Step 5.5: Post-cycle router adjustment ──
            [ -x "$SCRIPT_DIR/post-cycle-router.sh" ] && bash "$SCRIPT_DIR/post-cycle-router.sh" "$PROJECT_ROOT" 2>/dev/null

            # ── Step 5.6: Progress checkpoint ──
            progress_file="$PROMPTS_DIR/00-shared-context/progress.json"
            prev_progress=$(cat "$progress_file" 2>/dev/null || echo '{}')

            ts_count=$(find "$PROJECT_ROOT/backend/src" -name '*.ts' 2>/dev/null | wc -l | tr -d ' ')
            swift_count=$(find "$PROJECT_ROOT/ios" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
            test_count=$(find "$PROJECT_ROOT" -name '*.test.*' -o -name '*.spec.*' 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
            total=$((ts_count + swift_count))

            cat > "$progress_file" << PEOF
{
  "cycle": $CYCLE,
  "timestamp": "$(timestamp)",
  "backend_files": $ts_count,
  "frontend_files": $swift_count,
  "test_files": $test_count,
  "total_files": $total,
  "commits": $COMMITS
}
PEOF

            # Detect file regression
            prev_total=$(echo "$prev_progress" | grep -o '"total_files": [0-9]*' | grep -o '[0-9]*' || echo 0)
            prev_cycle=$(echo "$prev_progress" | grep -o '"cycle": [0-9]*' | grep -o '[0-9]*' || echo 0)
            if [ "$prev_total" -gt 0 ] && [ "$total" -lt "$((prev_total - 5))" ]; then
                log "WARNING: File count dropped from $prev_total to $total (cycle $prev_cycle → $CYCLE)"
                notify "File regression: $prev_total → $total files" "warning"
            fi

            # ── Step 5.6: Auto-update ALL agent prompt timestamps + file counts ──
            component_count=$(find "$PROJECT_ROOT" -path '*/Views/Components' -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
            backend_src=$((ts_count - test_count))
            current_date=$(date '+%B %d, %Y')
            current_time=$(date '+%H:%M')

            # Escape sed special chars in variables
            # Variable declarations (not local — this runs at top level)
            _safe_date="" _safe_time="" _safe_bsrc="" _safe_tc="" _safe_ts="" _safe_sw="" _safe_comp="" _safe_total=""
            _safe_date=$(printf '%s\n' "$current_date" | sed 's/[|&]/\\&/g')
            _safe_time=$(printf '%s\n' "$current_time" | sed 's/[|&]/\\&/g')
            _safe_bsrc=$(printf '%s\n' "$backend_src" | sed 's/[|&]/\\&/g')
            _safe_tc=$(printf '%s\n' "$test_count" | sed 's/[|&]/\\&/g')
            _safe_ts=$(printf '%s\n' "$ts_count" | sed 's/[|&]/\\&/g')
            _safe_sw=$(printf '%s\n' "$swift_count" | sed 's/[|&]/\\&/g')
            _safe_comp=$(printf '%s\n' "$component_count" | sed 's/[|&]/\\&/g')
            _safe_total=$(printf '%s\n' "$total" | sed 's/[|&]/\\&/g')

            for id in "${AGENT_IDS[@]}"; do
                pf="$PROJECT_ROOT/${AGENT_PROMPTS[$id]}"
                [ ! -f "$pf" ] && continue

                # Use | delimiter to avoid / conflicts in date strings
                sed -i "s|\*\*Date:\*\* .*|\*\*Date:\*\* ${_safe_date} — ${_safe_time}|" "$pf" 2>/dev/null
                sed -i "s|[0-9]* TypeScript source + [0-9]* test files = [0-9]* total|${_safe_bsrc} TypeScript source + ${_safe_tc} test files = ${_safe_ts} total|" "$pf" 2>/dev/null
                sed -i "s|[0-9]* Swift files|${_safe_sw} Swift files|" "$pf" 2>/dev/null
                sed -i "s|[0-9]* components|${_safe_comp} components|" "$pf" 2>/dev/null
                sed -i "s|Total:.*source files|Total: ${_safe_total} source files|" "$pf" 2>/dev/null
            done

            git add prompts/ 2>/dev/null
            git diff --cached --quiet 2>/dev/null || git commit -m "chore: auto-update all prompts — cycle $CYCLE ($total files, $component_count components)" 2>/dev/null
            log "All prompts auto-updated: $total files, $component_count components"

            # ── Step 5.8: Persist router state ──
            if [[ "$(type -t orch_router_save_state)" == "function" ]]; then
                mkdir -p "$PROJECT_ROOT/.orchystraw"
                orch_router_save_state "$PROJECT_ROOT/.orchystraw/router-state.json" 2>/dev/null
            fi

            # ── Step 6: Run tests + cycle metrics + summary ──
            run_cycle_tests

            # Track cumulative files changed
            local _cycle_files
            _cycle_files=$(git -C "$PROJECT_ROOT" diff --name-only HEAD~"${COMMITS:-1}" 2>/dev/null | wc -l | tr -d ' ') || _cycle_files=0
            CUMULATIVE_FILES=$((CUMULATIVE_FILES + _cycle_files))
            CUMULATIVE_AGENTS_RUN=$((CUMULATIVE_AGENTS_RUN + AGENTS_RUN))

            [ -x "$SCRIPT_DIR/cycle-metrics.sh" ] && bash "$SCRIPT_DIR/cycle-metrics.sh" "$CYCLE" "$COMMITS" "$PROJECT_ROOT" 2>/dev/null
            log "CYCLE $CYCLE DONE — $COMMITS commits | ${ts_count} TS + ${swift_count} Swift files"
            notify "Cycle $CYCLE done — $COMMITS commits"

            # v4: Print cycle summary
            print_cycle_summary "$CYCLE" "$AGENTS_RUN" "$COMMITS"

            # v4: Check cost limit
            if ! check_cost_limit; then
                break
            fi

            if [ "$MAX_CYCLES" -gt 0 ] && [ "$CYCLE" -ge "$MAX_CYCLES" ]; then
                log "Max cycles reached ($CYCLE/$MAX_CYCLES)"
                notify "Finished $CYCLE cycles"
                break
            fi

            CYCLE=$((CYCLE + 1))
            # Brief pause for git to settle, then continue immediately
            sleep 5
        done

        # Final summary across all cycles
        echo ""
        echo "╔══════════════════════════════════════════════════╗"
        echo "║            ORCHESTRATION COMPLETE                ║"
        echo "╠══════════════════════════════════════════════════╣"
        local _final_cost
        _final_cost=$(awk "BEGIN{printf \"%.4f\", $CUMULATIVE_COST / 1000000}")
        printf "║  Total cycles:      %-29s║\n" "$((CYCLE))"
        printf "║  Total agents run:  %-29s║\n" "$CUMULATIVE_AGENTS_RUN"
        printf "║  Total tokens:      %-29s║\n" "$CUMULATIVE_TOKENS"
        printf "║  Total est. cost:   %-29s║\n" "\$$_final_cost"
        printf "║  Total files:       %-29s║\n" "$CUMULATIVE_FILES"
        echo "╚══════════════════════════════════════════════════╝"
        ;;

    run)
        parse_config
        shift  # remove 'run'
        # v4: support --agent "name" flag
        if [[ "${1:-}" == "--agent" ]]; then
            AGENT_BY_NAME="${2:?Usage: ./scripts/auto-agent.sh run --agent \"Agent Label\"}"
            AGENT=$(resolve_agent_by_name "$AGENT_BY_NAME") || {
                echo "ERROR: No agent matching '$AGENT_BY_NAME'"
                echo ""
                echo "Available agents:"
                for id in "${AGENT_IDS[@]}"; do
                    echo "  $id — ${AGENT_LABELS[$id]}"
                done
                echo ""
                echo "SUGGESTION: Use a partial name match, e.g. --agent backend, --agent QA, --agent security"
                exit 1
            }
            echo "Resolved '$AGENT_BY_NAME' → $AGENT (${AGENT_LABELS[$AGENT]})"
        else
            AGENT="${1:?Usage: ./scripts/auto-agent.sh run <agent-id> | run --agent \"name\"}"
        fi
        run_agent "$AGENT"
        ;;

    list)
        parse_config
        echo "Configured agents:"
        for id in "${AGENT_IDS[@]}"; do
            interval="${AGENT_INTERVALS[$id]}"
            if [ "$interval" -eq 0 ]; then
                echo "  $id | coordinator (runs last) | ${AGENT_LABELS[$id]} | ${AGENT_OWNERSHIP[$id]}"
            else
                echo "  $id | every $interval cycles | ${AGENT_LABELS[$id]} | ${AGENT_OWNERSHIP[$id]}"
            fi
        done
        ;;

    status)
        show_status
        ;;

    *)
        echo "orchystraw Orchestrator v4"
        echo ""
        echo "  orchestrate [max-cycles=10]                   PM-driven loop (no delay)"
        echo "  orchestrate --dry-run                         Preview what would run"
        echo "  orchestrate --cost-limit 5.00                 Stop when est. cost exceeds \$5"
        echo "  orchestrate --max-parallel 3                  Cap concurrent agents"
        echo "  orchestrate --watch                           File-change triggered mode"
        echo "  run <agent-id>                                Single agent once"
        echo "  run --agent \"Backend Developer\"                Run agent by name"
        echo "  list                                          Show configured agents"
        echo "  status                                        Show cycle state (no run)"
        echo ""
        echo "Config:  scripts/agents.conf"
        echo "Logs:    prompts/<agent>/logs/"
        echo "Backups: prompts/00-backup/"
        ;;
esac
