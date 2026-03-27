#!/usr/bin/env bash
# Test: onboarding.sh — Comprehensive tests for the onboarding module
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

_assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  PASS: %s\n' "$desc"; PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected=%s actual=%s)\n' "$desc" "$expected" "$actual"; FAIL=$(( FAIL + 1 ))
    fi
}

_assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        printf '  PASS: %s\n' "$desc"; PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected to contain: %s)\n' "$desc" "$needle"; FAIL=$(( FAIL + 1 ))
    fi
}

_assert_file_exists() {
    local desc="$1" filepath="$2"
    if [[ -f "$filepath" ]]; then
        printf '  PASS: %s\n' "$desc"; PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file not found: %s)\n' "$desc" "$filepath"; FAIL=$(( FAIL + 1 ))
    fi
}

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/onboarding.sh"

echo "=== onboarding.sh tests ==="

# -----------------------------------------------------------------------
# 1. Module loads (guard var set)
# -----------------------------------------------------------------------
_assert "1 - module loads (guard var set)" "1" "${_ORCH_ONBOARD_LOADED}"

# -----------------------------------------------------------------------
# 2. Double-source guard
# -----------------------------------------------------------------------
if source "$PROJECT_ROOT/src/core/onboarding.sh"; then
    _assert "2 - double-source guard returns 0" "0" "0"
else
    _assert "2 - double-source guard returns 0" "0" "1"
fi

# -----------------------------------------------------------------------
# 3. orch_onboard_init resets state
# -----------------------------------------------------------------------
orch_onboard_init
_assert "3 - init sets initialized flag" "1" "$_ORCH_ONBOARD_INITIALIZED"

# -----------------------------------------------------------------------
# 4-9. Project type detection
# -----------------------------------------------------------------------

# 4. JavaScript detection (package.json)
JS_PROJECT="$TMPDIR_TEST/js-project"
mkdir -p "$JS_PROJECT"
echo '{"name":"test"}' > "$JS_PROJECT/package.json"
result="$(orch_onboard_detect_project "$JS_PROJECT" 2>/dev/null)"
_assert "4 - detect JavaScript (package.json)" "javascript" "$result"

# 5. Python detection (requirements.txt)
PY_PROJECT="$TMPDIR_TEST/py-project"
mkdir -p "$PY_PROJECT"
echo "flask==2.0" > "$PY_PROJECT/requirements.txt"
result="$(orch_onboard_detect_project "$PY_PROJECT" 2>/dev/null)"
_assert "5 - detect Python (requirements.txt)" "python" "$result"

# 6. Python detection (pyproject.toml)
PY2_PROJECT="$TMPDIR_TEST/py2-project"
mkdir -p "$PY2_PROJECT"
echo '[build-system]' > "$PY2_PROJECT/pyproject.toml"
result="$(orch_onboard_detect_project "$PY2_PROJECT" 2>/dev/null)"
_assert "6 - detect Python (pyproject.toml)" "python" "$result"

# 7. Rust detection (Cargo.toml)
RS_PROJECT="$TMPDIR_TEST/rs-project"
mkdir -p "$RS_PROJECT"
echo '[package]' > "$RS_PROJECT/Cargo.toml"
result="$(orch_onboard_detect_project "$RS_PROJECT" 2>/dev/null)"
_assert "7 - detect Rust (Cargo.toml)" "rust" "$result"

# 8. Go detection (go.mod)
GO_PROJECT="$TMPDIR_TEST/go-project"
mkdir -p "$GO_PROJECT"
echo 'module example.com/test' > "$GO_PROJECT/go.mod"
result="$(orch_onboard_detect_project "$GO_PROJECT" 2>/dev/null)"
_assert "8 - detect Go (go.mod)" "go" "$result"

# 9. Java detection (pom.xml)
JAVA_PROJECT="$TMPDIR_TEST/java-project"
mkdir -p "$JAVA_PROJECT"
echo '<project></project>' > "$JAVA_PROJECT/pom.xml"
result="$(orch_onboard_detect_project "$JAVA_PROJECT" 2>/dev/null)"
_assert "9 - detect Java (pom.xml)" "java" "$result"

# 10. Java detection (build.gradle)
JAVA2_PROJECT="$TMPDIR_TEST/java2-project"
mkdir -p "$JAVA2_PROJECT"
echo 'apply plugin: java' > "$JAVA2_PROJECT/build.gradle"
result="$(orch_onboard_detect_project "$JAVA2_PROJECT" 2>/dev/null)"
_assert "10 - detect Java (build.gradle)" "java" "$result"

# 11. Multi-language detection
MULTI_PROJECT="$TMPDIR_TEST/multi-project"
mkdir -p "$MULTI_PROJECT"
echo '{}' > "$MULTI_PROJECT/package.json"
echo '[package]' > "$MULTI_PROJECT/Cargo.toml"
result="$(orch_onboard_detect_project "$MULTI_PROJECT" 2>/dev/null)"
_assert "11 - detect multi-language project" "multi" "$result"

# 12. Unknown project
EMPTY_PROJECT="$TMPDIR_TEST/empty-project"
mkdir -p "$EMPTY_PROJECT"
result="$(orch_onboard_detect_project "$EMPTY_PROJECT" 2>/dev/null)"
_assert "12 - detect unknown project (empty dir)" "unknown" "$result"

# 13. Non-existent directory returns error
if orch_onboard_detect_project "$TMPDIR_TEST/no-such-dir" 2>/dev/null; then
    _assert "13 - non-existent dir returns error" "1" "0"
else
    _assert "13 - non-existent dir returns error" "1" "1"
fi

# -----------------------------------------------------------------------
# 14-19. Agent suggestions per project type
# -----------------------------------------------------------------------
agents="$(orch_onboard_suggest_agents "javascript" 2>/dev/null)"
_assert "14 - JS agents include backend" "yes" "$( [[ "$agents" == *backend* ]] && echo yes || echo no )"
_assert "15 - JS agents include frontend" "yes" "$( [[ "$agents" == *frontend* ]] && echo yes || echo no )"
_assert "16 - JS agents include pm" "yes" "$( [[ "$agents" == *pm* ]] && echo yes || echo no )"

agents="$(orch_onboard_suggest_agents "python" 2>/dev/null)"
_assert "17 - Python agents include data-science" "yes" "$( [[ "$agents" == *data-science* ]] && echo yes || echo no )"

agents="$(orch_onboard_suggest_agents "rust" 2>/dev/null)"
_assert "18 - Rust agents include systems" "yes" "$( [[ "$agents" == *systems* ]] && echo yes || echo no )"

agents="$(orch_onboard_suggest_agents "go" 2>/dev/null)"
_assert "19 - Go agents include api" "yes" "$( [[ "$agents" == *api* ]] && echo yes || echo no )"

agents="$(orch_onboard_suggest_agents "java" 2>/dev/null)"
_assert "20 - Java agents include devops" "yes" "$( [[ "$agents" == *devops* ]] && echo yes || echo no )"

agents="$(orch_onboard_suggest_agents "unknown" 2>/dev/null)"
_assert "21 - Unknown type gives generic agents" "backend qa pm" "$agents"

# -----------------------------------------------------------------------
# 22-25. agents.conf generation
# -----------------------------------------------------------------------

# Set project type for conf generation
orch_onboard_detect_project "$JS_PROJECT" >/dev/null 2>&1

conf="$(orch_onboard_generate_conf "$JS_PROJECT" "backend frontend qa pm" 2>/dev/null)"
_assert_contains "22 - conf header present" "# OrchyStraw Agent Configuration" "$conf"
_assert_contains "23 - conf has project type" "# Project type: javascript" "$conf"
_assert_contains "24 - conf has agent block" "[agent:01-backend]" "$conf"
_assert_contains "25 - conf has role line" "role = Backend Developer" "$conf"

# -----------------------------------------------------------------------
# 26-28. agents.conf structure details
# -----------------------------------------------------------------------
_assert_contains "26 - conf has frequency" "frequency = every_cycle" "$conf"
_assert_contains "27 - conf has prompt path" "prompt = prompts/01-backend/01-backend.txt" "$conf"
_assert_contains "28 - conf has PM agent" "[agent:04-pm]" "$conf"

# -----------------------------------------------------------------------
# 29-33. Prompt file generation
# -----------------------------------------------------------------------
PROMPT_OUT="$TMPDIR_TEST/prompt-output"
orch_onboard_detect_project "$RS_PROJECT" >/dev/null 2>&1
orch_onboard_generate_prompts "$PROMPT_OUT" "backend systems qa pm" 2>/dev/null

_assert_file_exists "29 - backend prompt file created" "$PROMPT_OUT/01-backend/01-backend.txt"
_assert_file_exists "30 - systems prompt file created" "$PROMPT_OUT/02-systems/02-systems.txt"
_assert_file_exists "31 - qa prompt file created" "$PROMPT_OUT/03-qa/03-qa.txt"
_assert_file_exists "32 - pm prompt file created" "$PROMPT_OUT/04-pm/04-pm.txt"

prompt_content="$(cat "$PROMPT_OUT/01-backend/01-backend.txt")"
_assert_contains "33 - prompt contains role" "Backend Developer" "$prompt_content"

# -----------------------------------------------------------------------
# 34-35. Prompt content details
# -----------------------------------------------------------------------
_assert_contains "34 - prompt contains project type" "Project type: rust" "$prompt_content"
_assert_contains "35 - prompt contains tasks section" "Current Tasks" "$prompt_content"

# -----------------------------------------------------------------------
# 36-40. Full pipeline (orch_onboard_run)
# -----------------------------------------------------------------------
PIPELINE_OUT="$TMPDIR_TEST/pipeline-output"
PY_PIPELINE="$TMPDIR_TEST/py-pipeline"
mkdir -p "$PY_PIPELINE"
echo 'requests==2.28' > "$PY_PIPELINE/requirements.txt"

run_result="$(orch_onboard_run "$PY_PIPELINE" "$PIPELINE_OUT" 2>/dev/null)"
_assert "36 - run returns detected type" "python" "$run_result"
_assert_file_exists "37 - run creates agents.conf" "$PIPELINE_OUT/agents.conf"
_assert_file_exists "38 - run creates backend prompt" "$PIPELINE_OUT/prompts/01-backend/01-backend.txt"
_assert_file_exists "39 - run creates data-science prompt" "$PIPELINE_OUT/prompts/03-data-science/03-data-science.txt"

pipeline_conf="$(cat "$PIPELINE_OUT/agents.conf")"
_assert_contains "40 - pipeline conf has python type" "# Project type: python" "$pipeline_conf"

# -----------------------------------------------------------------------
# 41. Python detection via setup.py
# -----------------------------------------------------------------------
PY3_PROJECT="$TMPDIR_TEST/py3-project"
mkdir -p "$PY3_PROJECT"
echo 'from setuptools import setup' > "$PY3_PROJECT/setup.py"
result="$(orch_onboard_detect_project "$PY3_PROJECT" 2>/dev/null)"
_assert "41 - detect Python (setup.py)" "python" "$result"

# -----------------------------------------------------------------------
# 42. Multi-type suggests devops
# -----------------------------------------------------------------------
agents="$(orch_onboard_suggest_agents "multi" 2>/dev/null)"
_assert_contains "42 - multi agents include devops" "devops" "$agents"

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if (( FAIL > 0 )); then
    exit 1
fi
