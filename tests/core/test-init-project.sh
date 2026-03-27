#!/usr/bin/env bash
# Test: init-project.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/init-project.sh"

echo "=== init-project.sh tests ==="

# -----------------------------------------------------------------------
# 1. Module loads (guard var set)
# -----------------------------------------------------------------------
if [[ "${_ORCH_INIT_PROJECT_LOADED:-}" == "1" ]]; then
    pass "1 - module loads (guard var set)"
else
    fail "1 - module loads (guard var set)"
fi

# -----------------------------------------------------------------------
# 2. Double-source guard
# -----------------------------------------------------------------------
if source "$PROJECT_ROOT/src/core/init-project.sh"; then
    pass "2 - double-source guard"
else
    fail "2 - double-source guard"
fi

# -----------------------------------------------------------------------
# 3. Create a fake project with known languages and scan
# -----------------------------------------------------------------------
FAKE_PROJECT="$TMPDIR_TEST/fake-project"
mkdir -p "$FAKE_PROJECT/src" "$FAKE_PROJECT/tests" "$FAKE_PROJECT/scripts"
echo '#!/usr/bin/env bash' > "$FAKE_PROJECT/scripts/run.sh"
echo 'console.log("hello")' > "$FAKE_PROJECT/src/index.js"
echo 'const x: number = 1' > "$FAKE_PROJECT/src/app.ts"
echo 'import pytest' > "$FAKE_PROJECT/tests/test_main.py"
# package.json with react
cat > "$FAKE_PROJECT/package.json" <<'EOF'
{
  "name": "test-project",
  "dependencies": { "react": "^18.0.0" }
}
EOF
# GitHub Actions
mkdir -p "$FAKE_PROJECT/.github/workflows"
echo "name: CI" > "$FAKE_PROJECT/.github/workflows/ci.yml"
# Dockerfile
echo "FROM node:18" > "$FAKE_PROJECT/Dockerfile"
# Jest config
echo '{}' > "$FAKE_PROJECT/jest.config.js"

orch_init_scan "$FAKE_PROJECT" 2>/dev/null
if [[ "$_ORCH_INIT_SCANNED" == "1" ]]; then
    pass "3 - scan completes successfully"
else
    fail "3 - scan completes successfully"
fi

# -----------------------------------------------------------------------
# 4. Detected languages
# -----------------------------------------------------------------------
langs=$(orch_init_detected_languages)
if echo "$langs" | grep -q "bash" && echo "$langs" | grep -q "javascript" && echo "$langs" | grep -q "typescript" && echo "$langs" | grep -q "python"; then
    pass "4 - detects bash, javascript, typescript, python"
else
    fail "4 - detects languages (got: $langs)"
fi

# -----------------------------------------------------------------------
# 5. Detected frameworks
# -----------------------------------------------------------------------
frameworks=$(orch_init_detected_frameworks)
if echo "$frameworks" | grep -q "react"; then
    pass "5 - detects react framework"
else
    fail "5 - detects react framework (got: $frameworks)"
fi

# -----------------------------------------------------------------------
# 6. Has feature: CI
# -----------------------------------------------------------------------
if orch_init_has_feature "ci"; then
    pass "6 - has_feature ci"
else
    fail "6 - has_feature ci"
fi

# -----------------------------------------------------------------------
# 7. Has feature: docker
# -----------------------------------------------------------------------
if orch_init_has_feature "docker"; then
    pass "7 - has_feature docker"
else
    fail "7 - has_feature docker"
fi

# -----------------------------------------------------------------------
# 8. Has feature: tests
# -----------------------------------------------------------------------
if orch_init_has_feature "tests"; then
    pass "8 - has_feature tests"
else
    fail "8 - has_feature tests"
fi

# -----------------------------------------------------------------------
# 9. Suggest agents includes core 3 (CEO, CTO, PM)
# -----------------------------------------------------------------------
suggestions=$(orch_init_suggest_agents 2>/dev/null)
if echo "$suggestions" | grep -q "01-ceo" && echo "$suggestions" | grep -q "02-cto" && echo "$suggestions" | grep -q "03-pm"; then
    pass "9 - suggest_agents includes CEO, CTO, PM"
else
    fail "9 - suggest_agents includes CEO, CTO, PM (got: $suggestions)"
fi

# -----------------------------------------------------------------------
# 10. Suggest agents includes backend (python detected)
# -----------------------------------------------------------------------
if echo "$suggestions" | grep -qi "backend"; then
    pass "10 - suggest_agents includes backend agent"
else
    fail "10 - suggest_agents includes backend agent"
fi

# -----------------------------------------------------------------------
# 11. Suggest agents includes frontend (react detected)
# -----------------------------------------------------------------------
if echo "$suggestions" | grep -qi "frontend\|ui"; then
    pass "11 - suggest_agents includes frontend/UI agent"
else
    fail "11 - suggest_agents includes frontend/UI agent"
fi

# -----------------------------------------------------------------------
# 12. Suggest agents includes QA (tests detected)
# -----------------------------------------------------------------------
if echo "$suggestions" | grep -qi "qa"; then
    pass "12 - suggest_agents includes QA agent"
else
    fail "12 - suggest_agents includes QA agent"
fi

# -----------------------------------------------------------------------
# 13. Generate conf file
# -----------------------------------------------------------------------
CONF_OUT="$TMPDIR_TEST/agents.conf"
if orch_init_generate_conf "$CONF_OUT" 2>/dev/null; then
    if [[ -f "$CONF_OUT" ]]; then
        pass "13 - generate_conf creates file"
    else
        fail "13 - generate_conf creates file (file missing)"
    fi
else
    fail "13 - generate_conf returns 0"
fi

# -----------------------------------------------------------------------
# 14. Generated conf has pipe-delimited format
# -----------------------------------------------------------------------
if grep -q '|' "$CONF_OUT" 2>/dev/null; then
    pass "14 - generated conf has pipe-delimited format"
else
    fail "14 - generated conf has pipe-delimited format"
fi

# -----------------------------------------------------------------------
# 15. Generate prompts
# -----------------------------------------------------------------------
PROMPTS_OUT="$TMPDIR_TEST/prompts-out"
count=$(orch_init_generate_prompts "$PROMPTS_OUT" 2>/dev/null)
if [[ "$count" -gt 0 ]]; then
    pass "15 - generate_prompts creates $count prompts"
else
    fail "15 - generate_prompts creates prompts (count=$count)"
fi

# -----------------------------------------------------------------------
# 16. Generated prompt files exist
# -----------------------------------------------------------------------
prompt_files=$(find "$PROMPTS_OUT" -name "*.txt" 2>/dev/null | wc -l)
if [[ "$prompt_files" -gt 0 ]]; then
    pass "16 - prompt files exist ($prompt_files files)"
else
    fail "16 - prompt files exist"
fi

# -----------------------------------------------------------------------
# 17. Report produces output
# -----------------------------------------------------------------------
report_output=$(orch_init_report 2>/dev/null)
if [[ -n "$report_output" ]]; then
    pass "17 - report produces output"
else
    fail "17 - report produces output"
fi

# -----------------------------------------------------------------------
# 18. Scan with no files — no crash
# -----------------------------------------------------------------------
EMPTY_PROJECT="$TMPDIR_TEST/empty-project"
mkdir -p "$EMPTY_PROJECT"
# Need to reset state — since guard prevents re-source, manually reset
_ORCH_INIT_SCANNED=0
_ORCH_INIT_LANGUAGES=()
_ORCH_INIT_FRAMEWORKS=()
_ORCH_INIT_SUGGESTED_AGENTS=()
if orch_init_scan "$EMPTY_PROJECT" 2>/dev/null; then
    pass "18 - scan empty project doesn't crash"
else
    fail "18 - scan empty project doesn't crash"
fi

# -----------------------------------------------------------------------
# 19. Feature check on non-existent feature
# -----------------------------------------------------------------------
if ! orch_init_has_feature "nonexistent"; then
    pass "19 - has_feature returns 1 for unknown feature"
else
    fail "19 - has_feature returns 1 for unknown feature"
fi

# -----------------------------------------------------------------------
# 20. Scan detects npm package manager
# -----------------------------------------------------------------------
# Re-scan original project
_ORCH_INIT_SCANNED=0
_ORCH_INIT_LANGUAGES=()
_ORCH_INIT_FRAMEWORKS=()
_ORCH_INIT_PKG_MANAGERS=()
_ORCH_INIT_SUGGESTED_AGENTS=()
orch_init_scan "$FAKE_PROJECT" 2>/dev/null
if [[ "${_ORCH_INIT_PKG_MANAGERS[npm]:-}" == "1" ]]; then
    pass "20 - detects npm package manager"
else
    fail "20 - detects npm package manager"
fi

# -----------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed (total: $((PASS + FAIL)))"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
