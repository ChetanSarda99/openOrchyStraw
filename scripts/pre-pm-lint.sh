#!/usr/bin/env bash
# pre-pm-lint.sh — Pre-PM lint pass that digests cycle results
# Runs BEFORE PM agent. Outputs structured markdown report.
# PM consumes this instead of doing raw git/issue analysis.
#
# Usage: bash scripts/pre-pm-lint.sh <cycle_num> [project_root]
# Output: Structured markdown to stdout (pipe to file or PM context)

set -euo pipefail

CYCLE="${1:?Usage: pre-pm-lint.sh <cycle_num>}"
PROJECT_ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
CONTEXT_FILE="$PROJECT_ROOT/prompts/00-shared-context/context.md"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

if [[ ! -f "$CONF_FILE" ]]; then
    echo "**ERROR:** agents.conf not found at $CONF_FILE" >&2
    exit 1
fi

# ── Parse agents.conf ──
declare -a AGENT_IDS=()
declare -A AGENT_OWNERSHIP=()
declare -A AGENT_LABELS=()

while IFS='|' read -r id prompt ownership interval label; do
    [[ "$id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${id// /}" ]] && continue
    id=$(echo "$id" | xargs)
    ownership=$(echo "$ownership" | xargs)
    label=$(echo "$label" | xargs)
    AGENT_IDS+=("$id")
    AGENT_OWNERSHIP["$id"]="$ownership"
    AGENT_LABELS["$id"]="$label"
done < "$CONF_FILE"

# ── Git stats per agent ──
echo "# Pre-PM Lint Report — Cycle $CYCLE"
echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S') | Auto-generated, not by an agent"
echo ""

echo "## Agent Commit Summary"
echo ""
echo "| Agent | Label | Files Changed | Lines +/- | Commits |"
echo "|-------|-------|---------------|-----------|---------|"

TOTAL_COMMITS=0
TOTAL_FILES=0
for id in "${AGENT_IDS[@]}"; do
    # Count commits by this agent on current branch (not on main)
    commits=$(git log --oneline --grep="feat($id)" main..HEAD 2>/dev/null | wc -l | tr -d ' ')

    # Count files in owned paths
    IFS=' ' read -ra paths <<< "${AGENT_OWNERSHIP[$id]}"
    files_changed=0
    lines_delta=""
    for path in "${paths[@]}"; do
        [[ "$path" == !* ]] && continue
        fc=$(git diff --name-only main..HEAD -- "$path" 2>/dev/null | wc -l | tr -d ' ')
        files_changed=$((files_changed + fc))
    done

    if [[ "$commits" -gt 0 ]]; then
        lines_delta=$(git log --grep="feat($id)" main..HEAD --format="" --shortstat 2>/dev/null | awk '{ins+=$4; del+=$6} END {printf "+%d/-%d", ins, del}')
    else
        lines_delta="—"
    fi

    echo "| $id | ${AGENT_LABELS[$id]} | $files_changed | $lines_delta | $commits |"
    TOTAL_COMMITS=$((TOTAL_COMMITS + commits))
    TOTAL_FILES=$((TOTAL_FILES + files_changed))
done

echo ""
echo "**Totals:** $TOTAL_COMMITS commits, $TOTAL_FILES files touched"
echo ""

# ── Shared context contribution check ──
echo "## Shared Context Contributions"
echo ""

if [ -f "$CONTEXT_FILE" ]; then
    context_lines=$(wc -l < "$CONTEXT_FILE")
    fresh_entries=$(grep -c "^- " "$CONTEXT_FILE" 2>/dev/null || echo 0)
    fresh_cycle=$(grep -c "(fresh cycle)" "$CONTEXT_FILE" 2>/dev/null || echo 0)

    echo "- Context file: $context_lines lines, $fresh_entries entries"
    if [[ "$fresh_cycle" -gt 3 ]]; then
        echo "- **WARNING:** $fresh_cycle sections still say '(fresh cycle)' — agents may not have written back"
    else
        echo "- All sections populated"
    fi
else
    echo "- **ERROR:** No shared context file found"
fi
echo ""

# ── Prompt health check ──
echo "## Prompt Health"
echo ""
echo "| Agent | Lines | Has Tasks | Has Ownership | Status |"
echo "|-------|-------|-----------|---------------|--------|"

for id in "${AGENT_IDS[@]}"; do
    pf="$PROJECT_ROOT/prompts/$id/$id.txt"
    # Try alternate path from agents.conf
    if [ ! -f "$pf" ]; then
        # Parse from conf
        prompt_path=$(grep "^${id}" "$CONF_FILE" 2>/dev/null | head -1 | cut -d'|' -f2 | xargs)
        pf="$PROJECT_ROOT/$prompt_path"
    fi

    if [ -f "$pf" ]; then
        lines=$(wc -l < "$pf")
        has_tasks=$(grep -c -i "YOUR.*TASK\|NEXT.*TASK\|Current Tasks" "$pf" 2>/dev/null || echo 0)
        has_ownership=$(grep -c -i "File Ownership\|YOU MAY WRITE\|ownership" "$pf" 2>/dev/null || echo 0)

        status="OK"
        [[ "$lines" -lt 50 ]] && status="SHORT"
        [[ "$lines" -gt 500 ]] && status="BLOATED"
        [[ "$has_tasks" -eq 0 ]] && status="NO TASKS"

        echo "| $id | $lines | $([[ $has_tasks -gt 0 ]] && echo 'Yes' || echo '**No**') | $([[ $has_ownership -gt 0 ]] && echo 'Yes' || echo '**No**') | $status |"
    else
        echo "| $id | — | — | — | **MISSING** |"
    fi
done
echo ""

# ── GitHub issue sync ──
echo "## GitHub Issues"
echo ""

if command -v gh &>/dev/null; then
    open_count=$(gh issue list --state open --limit 200 --json number -q 'length' 2>/dev/null || echo "?")
    recent_closed=$(gh issue list --state closed --limit 10 --json number,title,closedAt --jq '.[] | select(.closedAt > (now - 3600 | todate)) | "#\(.number) \(.title)"' 2>/dev/null)

    echo "- Open issues: $open_count"
    if [ -n "$recent_closed" ]; then
        echo "- Closed this cycle:"
        echo "$recent_closed" | while read -r line; do echo "  - $line"; done
    else
        echo "- No issues closed this cycle"
    fi
else
    echo "- gh CLI not available — skipping issue sync"
fi
echo ""

# ── Agent log analysis ──
echo "## Agent Logs (errors/warnings)"
echo ""

had_issues=false
for id in "${AGENT_IDS[@]}"; do
    log_dir="$PROMPTS_DIR/$id/logs"
    [ ! -d "$log_dir" ] && continue
    latest_log=$(ls -t "$log_dir/"*.log 2>/dev/null | head -1)
    [ -z "$latest_log" ] && continue

    log_size=$(wc -c < "$latest_log" 2>/dev/null || echo 0)
    if [[ "$log_size" -lt 100 ]]; then
        echo "- **$id**: Tiny output ($log_size bytes) — may have failed silently"
        had_issues=true
    fi

    errors=$(grep -c -i "error\|exception\|fatal\|panic" "$latest_log" 2>/dev/null || echo 0)
    if [[ "$errors" -gt 0 ]]; then
        echo "- **$id**: $errors error(s) in log"
        had_issues=true
    fi
done

if [ "$had_issues" = false ]; then
    echo "- All agent logs clean"
fi
echo ""

# ── Blocker detection ──
echo "## Blockers"
echo ""

actions_file="$PROMPTS_DIR/99-me/99-actions.txt"
if [ -f "$actions_file" ]; then
    pending=$(grep -c "^### P0\|^### P1" "$actions_file" 2>/dev/null || echo 0)
    if [[ "$pending" -gt 0 ]]; then
        echo "- **$pending P0/P1 blockers** in 99-actions.txt — check before next cycle"
        grep "^### P0\|^### P1" "$actions_file" 2>/dev/null | while read -r line; do
            echo "  - $line"
        done
    else
        echo "- No P0/P1 blockers"
    fi
else
    echo "- No actions file found"
fi
echo ""

# ── Cycle verdict ──
echo "## Verdict"
echo ""

if [[ "$TOTAL_COMMITS" -eq 0 ]]; then
    echo "**QUIET CYCLE** — No commits. Consider skipping PM review."
    echo "Recommendation: PM SKIP"
elif [[ "$TOTAL_COMMITS" -le 2 ]] && [[ "$fresh_cycle" -gt 3 ]]; then
    echo "**LOW ACTIVITY** — Few commits, agents may not have engaged."
    echo "Recommendation: PM LIGHT REVIEW (check prompts only)"
else
    echo "**ACTIVE CYCLE** — $TOTAL_COMMITS commits, $TOTAL_FILES files."
    echo "Recommendation: PM FULL REVIEW"
fi
