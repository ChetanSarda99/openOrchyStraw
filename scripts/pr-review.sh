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

# ── Check 6: Unused imports (JS/TS/Python) ──
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$PROJECT_ROOT/$file"
    [[ ! -f "$filepath" ]] && continue

    case "$file" in
        *.ts|*.tsx|*.js|*.jsx)
            # Find import statements and check if the imported name is used elsewhere
            while IFS= read -r import_line; do
                [[ -z "$import_line" ]] && continue
                # Extract imported names: import { Foo, Bar } from '...'
                imported_names=$(echo "$import_line" | grep -oP '(?<=\{)[^}]+(?=\})' 2>/dev/null | tr ',' '\n' | sed 's/[[:space:]]//g; s/ as .*//') || true
                # Also handle: import Foo from '...'
                default_import=$(echo "$import_line" | grep -oP '(?<=import )\w+(?= from)' 2>/dev/null) || true
                all_names="$imported_names $default_import"
                for name in $all_names; do
                    [[ -z "$name" ]] && continue
                    [[ "$name" == "type" ]] && continue
                    # Count occurrences (excluding the import line itself)
                    local_count=$(grep -c "\b${name}\b" "$filepath" 2>/dev/null || echo 0)
                    if [[ "$local_count" -le 1 ]]; then
                        add_finding "INFO" "$file" "Possibly unused import: '$name'"
                    fi
                done
            done < <(grep -nE "^import " "$filepath" 2>/dev/null)
            ;;
        *.py)
            while IFS= read -r import_line; do
                [[ -z "$import_line" ]] && continue
                # from x import y, z
                imported_names=$(echo "$import_line" | grep -oP '(?<=import )\w+' 2>/dev/null) || true
                for name in $imported_names; do
                    [[ -z "$name" ]] && continue
                    local_count=$(grep -c "\b${name}\b" "$filepath" 2>/dev/null || echo 0)
                    if [[ "$local_count" -le 1 ]]; then
                        add_finding "INFO" "$file" "Possibly unused import: '$name'"
                    fi
                done
            done < <(grep -nE "^(from |import )" "$filepath" 2>/dev/null)
            ;;
    esac
done <<< "$CHANGED_FILES"

# ── Check 7: Large functions (> 50 lines) ──
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$PROJECT_ROOT/$file"
    [[ ! -f "$filepath" ]] && continue

    case "$file" in
        *.ts|*.tsx|*.js|*.jsx)
            # Detect function declarations and count lines until closing brace
            func_name="" func_start=0 brace_depth=0 in_func=false
            line_num=0
            while IFS= read -r code_line; do
                line_num=$((line_num + 1))
                if [[ "$in_func" == false ]]; then
                    if echo "$code_line" | grep -qE '(function\s+\w+|const\s+\w+\s*=\s*(async\s*)?\(|^\s*(async\s+)?[a-zA-Z]+\s*\()' 2>/dev/null; then
                        func_name=$(echo "$code_line" | grep -oP '(function\s+)\K\w+|(?<=const\s)\w+' 2>/dev/null | head -1) || func_name="anonymous"
                        func_start=$line_num
                        brace_depth=0
                        in_func=true
                    fi
                fi
                if [[ "$in_func" == true ]]; then
                    opens=$(echo "$code_line" | tr -cd '{' | wc -c)
                    closes=$(echo "$code_line" | tr -cd '}' | wc -c)
                    brace_depth=$((brace_depth + opens - closes))
                    if [[ "$brace_depth" -le 0 && "$line_num" -gt "$func_start" ]]; then
                        func_length=$((line_num - func_start))
                        if [[ "$func_length" -gt 50 ]]; then
                            add_finding "WARNING" "$file" "Large function '$func_name' ($func_length lines at L${func_start}) — consider splitting"
                        fi
                        in_func=false
                    fi
                fi
            done < "$filepath"
            ;;
        *.py)
            local func_name="" func_start=0 func_indent=0 in_func=false
            local line_num=0
            while IFS= read -r code_line; do
                line_num=$((line_num + 1))
                if echo "$code_line" | grep -qE '^\s*def\s+\w+' 2>/dev/null; then
                    if [[ "$in_func" == true ]]; then
                        local func_length=$((line_num - func_start))
                        if [[ "$func_length" -gt 50 ]]; then
                            add_finding "WARNING" "$file" "Large function '$func_name' ($func_length lines at L${func_start}) — consider splitting"
                        fi
                    fi
                    func_name=$(echo "$code_line" | grep -oP '(?<=def\s)\w+' 2>/dev/null) || func_name="unknown"
                    func_start=$line_num
                    func_indent=$(echo "$code_line" | grep -oP '^\s*' 2>/dev/null | wc -c)
                    in_func=true
                fi
            done < "$filepath"
            if [[ "$in_func" == true ]]; then
                local func_length=$((line_num - func_start))
                if [[ "$func_length" -gt 50 ]]; then
                    add_finding "WARNING" "$file" "Large function '$func_name' ($func_length lines at L${func_start}) — consider splitting"
                fi
            fi
            ;;
        *.sh)
            local func_name="" func_start=0 in_func=false
            local line_num=0
            while IFS= read -r code_line; do
                line_num=$((line_num + 1))
                if echo "$code_line" | grep -qE '^\s*\w+\s*\(\)\s*\{' 2>/dev/null; then
                    if [[ "$in_func" == true ]]; then
                        local func_length=$((line_num - func_start))
                        if [[ "$func_length" -gt 50 ]]; then
                            add_finding "WARNING" "$file" "Large function '$func_name' ($func_length lines at L${func_start}) — consider splitting"
                        fi
                    fi
                    func_name=$(echo "$code_line" | grep -oP '^\s*\K\w+(?=\s*\(\))' 2>/dev/null) || func_name="unknown"
                    func_start=$line_num
                    in_func=true
                fi
            done < "$filepath"
            if [[ "$in_func" == true ]]; then
                local func_length=$((line_num - func_start))
                if [[ "$func_length" -gt 50 ]]; then
                    add_finding "WARNING" "$file" "Large function '$func_name' ($func_length lines at L${func_start}) — consider splitting"
                fi
            fi
            ;;
    esac
done <<< "$CHANGED_FILES"

# ── Check 8: Dead code patterns ──
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$PROJECT_ROOT/$file"
    [[ ! -f "$filepath" ]] && continue

    # Unreachable code after return/exit
    case "$file" in
        *.ts|*.tsx|*.js|*.jsx|*.py|*.sh)
            file_diff=$(echo "$DIFF" | sed -n "/^diff.*${file//\//\\/}/,/^diff/p" 2>/dev/null) || true
            added_lines=$(echo "$file_diff" | grep "^+" | grep -v "^+++" 2>/dev/null) || true

            # Code after unconditional return/exit (simple pattern)
            if echo "$added_lines" | grep -qE "^\+\s*(return|exit)\s" 2>/dev/null; then
                # Check if line immediately after return has non-comment code
                local prev_was_return=false
                echo "$added_lines" | while IFS= read -r aline; do
                    aline_clean="${aline#+}"
                    if [[ "$prev_was_return" == true ]]; then
                        if echo "$aline_clean" | grep -qE '^\s*[^#//\s}]' 2>/dev/null; then
                            add_finding "INFO" "$file" "Possible dead code after return/exit statement"
                            break
                        fi
                        prev_was_return=false
                    fi
                    if echo "$aline_clean" | grep -qE '^\s*(return|exit)\s' 2>/dev/null; then
                        prev_was_return=true
                    fi
                done
            fi

            # Commented-out code blocks (3+ consecutive commented lines with code-like content)
            local comment_streak=0
            while IFS= read -r aline; do
                aline_clean="${aline#+}"
                if echo "$aline_clean" | grep -qE '^\s*(//|#)\s*[a-zA-Z].*[;(){}=]' 2>/dev/null; then
                    comment_streak=$((comment_streak + 1))
                else
                    if [[ "$comment_streak" -ge 3 ]]; then
                        add_finding "INFO" "$file" "Commented-out code block ($comment_streak lines) — consider removing"
                        break
                    fi
                    comment_streak=0
                fi
            done <<< "$added_lines"
            ;;
    esac
done <<< "$CHANGED_FILES"

# ── Check 9: Large diff (too many changes in one commit) ──
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
