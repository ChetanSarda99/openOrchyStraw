#!/usr/bin/env bash
# commit-summary.sh — Structured diff summary after agents commit
# Generates per-agent summary of what changed. Replaces manual git diff reading.
#
# Usage: bash scripts/commit-summary.sh [since_ref] [project_root]
#   since_ref: git ref to diff from (default: HEAD~10)
# Output: Markdown summary to stdout

set -euo pipefail

SINCE_REF="${1:-HEAD~10}"
PROJECT_ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
# Prefer canonical root agents.conf; fall back to legacy scripts/agents.conf
CONF_FILE="$PROJECT_ROOT/agents.conf"
[[ -f "$CONF_FILE" ]] || CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"

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

echo "# Commit Summary (since $SINCE_REF)"
echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

total_files=0
total_insertions=0
total_deletions=0

for id in "${AGENT_IDS[@]}"; do
    IFS=' ' read -ra paths <<< "${AGENT_OWNERSHIP[$id]}"
    local_include=()
    for path in "${paths[@]}"; do
        [[ "$path" == !* ]] && continue
        local_include+=("$path")
    done
    [[ ${#local_include[@]} -eq 0 ]] && continue

    # Get changed files in owned paths
    changed_files=$(git -C "$PROJECT_ROOT" diff --name-only "$SINCE_REF"..HEAD -- "${local_include[@]}" 2>/dev/null || true)
    [[ -z "$changed_files" ]] && continue

    file_count=$(echo "$changed_files" | wc -l | tr -d ' ')
    total_files=$((total_files + file_count))

    # Get stat summary
    stat_line=$(git -C "$PROJECT_ROOT" diff --stat "$SINCE_REF"..HEAD -- "${local_include[@]}" 2>/dev/null | tail -1 || true)
    insertions=0
    deletions=0
    if [[ "$stat_line" =~ ([0-9]+)\ insertion ]]; then
        insertions="${BASH_REMATCH[1]}"
    fi
    if [[ "$stat_line" =~ ([0-9]+)\ deletion ]]; then
        deletions="${BASH_REMATCH[1]}"
    fi
    total_insertions=$((total_insertions + insertions))
    total_deletions=$((total_deletions + deletions))

    # Separate new vs modified
    new_files=$(git -C "$PROJECT_ROOT" diff --diff-filter=A --name-only "$SINCE_REF"..HEAD -- "${local_include[@]}" 2>/dev/null || true)
    mod_files=$(git -C "$PROJECT_ROOT" diff --diff-filter=M --name-only "$SINCE_REF"..HEAD -- "${local_include[@]}" 2>/dev/null || true)
    del_files=$(git -C "$PROJECT_ROOT" diff --diff-filter=D --name-only "$SINCE_REF"..HEAD -- "${local_include[@]}" 2>/dev/null || true)

    new_count=0
    mod_count=0
    del_count=0
    [[ -n "$new_files" ]] && new_count=$(echo "$new_files" | wc -l | tr -d ' ')
    [[ -n "$mod_files" ]] && mod_count=$(echo "$mod_files" | wc -l | tr -d ' ')
    [[ -n "$del_files" ]] && del_count=$(echo "$del_files" | wc -l | tr -d ' ')

    echo "## $id — ${AGENT_LABELS[$id]}"
    echo "- **Files:** $file_count ($new_count new, $mod_count modified, $del_count deleted)"
    echo "- **Lines:** +$insertions / -$deletions"

    # Key files (top 5 by churn)
    top_files=$(git -C "$PROJECT_ROOT" diff --numstat "$SINCE_REF"..HEAD -- "${local_include[@]}" 2>/dev/null \
        | awk '{print ($1+$2), $3}' | sort -rn | head -5 || true)
    if [[ -n "$top_files" ]]; then
        echo "- **Top changes:**"
        while IFS= read -r line; do
            churn="${line%% *}"
            fname="${line#* }"
            echo "  - \`$fname\` ($churn lines)"
        done <<< "$top_files"
    fi

    # Key function/class names from new files
    if [[ -n "$new_files" ]]; then
        echo "- **New exports:**"
        while IFS= read -r f; do
            [ -f "$PROJECT_ROOT/$f" ] || continue
            case "$f" in
                *.sh)
                    funcs=$(grep -o '^[a-zA-Z_][a-zA-Z0-9_]*()' "$PROJECT_ROOT/$f" 2>/dev/null | head -5 || true)
                    [[ -n "$funcs" ]] && echo "$funcs" | while read -r fn; do echo "  - \`$fn\`"; done
                    ;;
                *.ts|*.tsx|*.js)
                    exports=$(grep -oE 'export[[:space:]]+(default[[:space:]]+)?(function|const|class)[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' "$PROJECT_ROOT/$f" 2>/dev/null | sed 's/.*[[:space:]]//' | head -5 || true)
                    [[ -n "$exports" ]] && echo "$exports" | while read -r ex; do echo "  - \`$ex\`"; done
                    ;;
            esac
        done <<< "$new_files"
    fi
    echo ""
done

echo "---"
echo "**Totals:** $total_files files, +$total_insertions / -$total_deletions lines"
