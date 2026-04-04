#!/usr/bin/env bash
# pr-review.sh — Auto PR reviewer: checks diffs post-commit for common issues
# Performs static analysis on git diffs without requiring external tools.
# Can be used as a post-commit hook or standalone reviewer.
#
# Usage:
#   bash scripts/pr-review.sh [commit_range] [project_root]
#   bash scripts/pr-review.sh HEAD~1..HEAD     # review last commit
#   bash scripts/pr-review.sh main..feature    # review branch diff
#   bash scripts/pr-review.sh                  # defaults to HEAD~1..HEAD
#
# Output: Review report to stdout + .orchystraw/reviews/<timestamp>.md
# Exit: 0 = clean, 1 = issues found (advisory, non-blocking)

set -euo pipefail

COMMIT_RANGE="${1:-HEAD~1..HEAD}"
PROJECT_ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
REVIEW_DIR="$PROJECT_ROOT/.orchystraw/reviews"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
REVIEW_FILE="$REVIEW_DIR/review-${TIMESTAMP}.md"

mkdir -p "$REVIEW_DIR"

WARNINGS=0
ERRORS=0
INFOS=0

declare -a FINDINGS=()

add_finding() {
    local severity="$1" file="$2" msg="$3"
    FINDINGS+=("[$severity] $file: $msg")
    case "$severity" in
        ERROR)   (( ERRORS++ )) || true ;;
        WARNING) (( WARNINGS++ )) || true ;;
        INFO)    (( INFOS++ )) || true ;;
    esac
}

# Get the diff
DIFF=$(git -C "$PROJECT_ROOT" diff "$COMMIT_RANGE" 2>/dev/null) || {
    echo "pr-review: no diff found for range $COMMIT_RANGE"
    exit 0
}

if [[ -z "$DIFF" ]]; then
    echo "pr-review: empty diff for range $COMMIT_RANGE"
    exit 0
fi

# Get changed files
CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff --name-only "$COMMIT_RANGE" 2>/dev/null) || true

# ── Check 1: Large files ──
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$PROJECT_ROOT/$file"
    [[ ! -f "$filepath" ]] && continue
    size=$(wc -c < "$filepath" 2>/dev/null | tr -d '[:space:]')
    if [[ "$size" -gt 100000 ]]; then
        add_finding "WARNING" "$file" "Large file ($(( size / 1024 ))KB) — consider splitting"
    fi
done <<< "$CHANGED_FILES"

# ── Check 2: Secrets / sensitive patterns ──
SECRET_PATTERNS=(
    'PRIVATE.KEY'
    'BEGIN RSA'
    'BEGIN DSA'
    'BEGIN EC'
    'password\s*=\s*["\x27][^"\x27]'
    'api[_-]?key\s*=\s*["\x27][A-Za-z0-9]'
    'secret\s*=\s*["\x27][A-Za-z0-9]'
    'token\s*=\s*["\x27][A-Za-z0-9]'
    'AWS_SECRET_ACCESS_KEY'
    'ANTHROPIC_API_KEY\s*='
    'OPENAI_API_KEY\s*='
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    matches=$(echo "$DIFF" | grep -nE "^\+" | grep -iE "$pattern" 2>/dev/null) || true
    if [[ -n "$matches" ]]; then
        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            add_finding "ERROR" "(diff)" "Possible secret/credential: ${match:0:80}..."
        done <<< "$matches"
    fi
done

# ── Check 3: Debug/TODO markers left in ──
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$PROJECT_ROOT/$file"
    [[ ! -f "$filepath" ]] && continue
    # Only check added lines in diff for this file
    file_diff=$(echo "$DIFF" | sed -n "/^diff.*${file//\//\\/}/,/^diff/p" 2>/dev/null) || true
    added_lines=$(echo "$file_diff" | grep "^+" | grep -v "^+++" 2>/dev/null) || true

    if echo "$added_lines" | grep -qiE "TODO|FIXME|HACK|XXX|TEMP" 2>/dev/null; then
        add_finding "INFO" "$file" "Contains TODO/FIXME markers"
    fi

    if echo "$added_lines" | grep -qiE "console\.log|debugger|print\(|echo.*DEBUG" 2>/dev/null; then
        add_finding "WARNING" "$file" "Debug statements detected"
    fi
done <<< "$CHANGED_FILES"

# ── Check 4: Shell script issues ──
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" != *.sh ]] && continue
    filepath="$PROJECT_ROOT/$file"
    [[ ! -f "$filepath" ]] && continue

    # Check for Windows line endings (cat -v shows \r as ^M)
    if cat -v "$filepath" 2>/dev/null | grep -q '\^M'; then
        add_finding "WARNING" "$file" "Windows line endings (CRLF) detected"
    fi

    # Check for missing set -e / set -euo pipefail
    if head -5 "$filepath" | grep -q "^#!/" 2>/dev/null; then
        if ! head -10 "$filepath" | grep -qE "set -[euo]|set -euo" 2>/dev/null; then
            add_finding "INFO" "$file" "Missing 'set -euo pipefail' safety guard"
        fi
    fi

    # Check for eval usage
    if grep -qE "^\+.*\beval\b" <(echo "$DIFF" | sed -n "/^diff.*${file//\//\\/}/,/^diff/p" 2>/dev/null) 2>/dev/null; then
        add_finding "WARNING" "$file" "Uses eval — potential injection risk"
    fi
done <<< "$CHANGED_FILES"

# ── Check 5: Ownership violations (if agents.conf exists) ──
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
if [[ -f "$CONF_FILE" ]]; then
    PROTECTED_PATTERNS=("scripts/auto-agent.sh" "scripts/agents.conf" "CLAUDE.md")
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        for protected in "${PROTECTED_PATTERNS[@]}"; do
            if [[ "$file" == "$protected" ]]; then
                add_finding "WARNING" "$file" "Protected file modified — verify this was intentional"
            fi
        done
    done <<< "$CHANGED_FILES"
fi

# ── Check 6: Large diff (too many changes in one commit) ──
added_lines=$(echo "$DIFF" | grep -c "^+" 2>/dev/null) || added_lines=0
removed_lines=$(echo "$DIFF" | grep -c "^-" 2>/dev/null) || removed_lines=0
total_changes=$(( added_lines + removed_lines ))

if [[ "$total_changes" -gt 500 ]]; then
    add_finding "INFO" "(diff)" "Large changeset ($total_changes lines) — consider smaller commits"
fi

# ── Generate report ──
{
    echo "# PR Review: $COMMIT_RANGE"
    echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "> Files changed: $(echo "$CHANGED_FILES" | grep -c '.' 2>/dev/null || echo 0)"
    echo "> Lines changed: +$added_lines / -$removed_lines"
    echo ""

    if [[ ${#FINDINGS[@]} -eq 0 ]]; then
        echo "## Result: CLEAN"
        echo ""
        echo "No issues found."
    else
        echo "## Result: $ERRORS errors, $WARNINGS warnings, $INFOS info"
        echo ""
        echo "### Findings"
        echo ""
        for finding in "${FINDINGS[@]}"; do
            echo "- $finding"
        done
    fi
    echo ""
    echo "---"
    echo "*Advisory review — non-blocking*"
} | tee "$REVIEW_FILE"

# Exit 1 if errors found (advisory signal)
if [[ "$ERRORS" -gt 0 ]]; then
    exit 1
fi
exit 0
