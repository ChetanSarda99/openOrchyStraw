#!/usr/bin/env bash
# secrets-scan.sh — Scan committed files for secrets/credentials
# Replaces security agent's manual secrets scanning. If clean, security agent can skip.
#
# Usage: bash scripts/secrets-scan.sh [project_root]
# Exit: 0 = clean, 1 = secrets found

set -uo pipefail

PROJECT_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

# ── Patterns that indicate secrets ──
PATTERNS=(
    'AKIA[0-9A-Z]{16}'                          # AWS access key
    'sk-[a-zA-Z0-9]{20,}'                       # OpenAI/Stripe secret key
    'ghp_[a-zA-Z0-9]{36}'                       # GitHub personal access token
    'github_pat_[a-zA-Z0-9_]{82}'               # GitHub fine-grained PAT
    'glpat-[a-zA-Z0-9\-]{20}'                   # GitLab PAT
    'xoxb-[0-9]{10,}-[a-zA-Z0-9]+'              # Slack bot token
    'xoxp-[0-9]{10,}-[a-zA-Z0-9]+'              # Slack user token
    'AIza[0-9A-Za-z\-_]{35}'                    # Google API key
    'ya29\.[0-9A-Za-z\-_]+'                     # Google OAuth token
    'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}' # JWT token
    'SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}' # SendGrid API key
    'sq0[a-z]{3}-[0-9A-Za-z\-_]{22}'            # Square access token
    'sk_live_[0-9a-zA-Z]{24,}'                  # Stripe live key
    'rk_live_[0-9a-zA-Z]{24,}'                  # Stripe restricted key
    'npm_[a-zA-Z0-9]{36}'                       # npm token
    'PRIVATE KEY-''----'                          # Private key block
    'password\s*[:=]\s*["\x27][^\s"'\'']{8,}'   # password = "..." patterns
)

# Files/dirs to exclude from scanning
EXCLUDE_DIRS=(
    ".git"
    "node_modules"
    ".next"
    "dist"
    "build"
    "target"
    "legacy"
    ".orchystraw"
)

# Build exclude args for grep
EXCLUDE_ARGS=()
for d in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS+=("--exclude-dir=$d")
done

echo "# Secrets Scan Report"
echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "> Scanned: $PROJECT_ROOT"
echo ""

found=0
declare -A FINDINGS=()

for pattern in "${PATTERNS[@]}"; do
    matches=$(grep -rn -E "$pattern" "$PROJECT_ROOT" \
        "${EXCLUDE_ARGS[@]}" \
        --exclude='*.log' \
        --exclude='*.lock' \
        --exclude='secrets-scan.sh' --exclude='*.example' \
        --include='*.sh' --include='*.ts' --include='*.tsx' --include='*.js' \
        --include='*.json' --include='*.yml' --include='*.yaml' --include='*.env' \
        --include='*.md' --include='*.txt' --include='*.toml' --include='*.cfg' \
        --include='*.conf' --include='*.py' --include='*.rs' --include='*.swift' \
        2>/dev/null || true)

    if [[ -n "$matches" ]]; then
        found=$((found + 1))
        while IFS= read -r match; do
            file="${match%%:*}"
            rest="${match#*:}"
            line="${rest%%:*}"
            echo "- **FOUND** [\`$pattern\`]: $file:$line"
        done <<< "$matches"
    fi
done

echo ""

# ── Check .env files ──
echo "## .env File Check"
echo ""

gitignore="$PROJECT_ROOT/.gitignore"
env_files=$(find "$PROJECT_ROOT" -name '.env*' -not -path '*node_modules*' -not -path '*/.git/*' 2>/dev/null || true)

if [[ -n "$env_files" ]]; then
    while IFS= read -r envfile; do
        rel="${envfile#$PROJECT_ROOT/}"
        # Check if in .gitignore
        if [ -f "$gitignore" ] && grep -qF ".env" "$gitignore" 2>/dev/null; then
            # Check if tracked by git
            if git -C "$PROJECT_ROOT" ls-files --error-unmatch "$rel" &>/dev/null; then
                echo "- **WARNING:** \`$rel\` is tracked by git despite .gitignore"
                found=$((found + 1))
            else
                echo "- OK: \`$rel\` (not tracked)"
            fi
        else
            echo "- **WARNING:** \`$rel\` exists but .env not in .gitignore"
            found=$((found + 1))
        fi
    done <<< "$env_files"
else
    echo "- No .env files found"
fi

echo ""

# ── Verdict ──
echo "## Verdict"
echo ""

if [[ $found -eq 0 ]]; then
    echo "**CLEAN** — No secrets detected. Security agent can skip secrets scanning."
    exit 0
else
    echo "**$found finding(s)** — Review required before merge."
    exit 1
fi
