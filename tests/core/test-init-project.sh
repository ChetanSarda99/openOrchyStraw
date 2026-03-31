#!/usr/bin/env bash
# Test: init-project.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/init-project.sh"

echo "=== init-project.sh tests ==="

# Test 1: Module loads
[[ -n "${_ORCH_INIT_PROJECT_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Double-source guard
source "$PROJECT_ROOT/src/core/init-project.sh"
pass "double-source guard"

# ---------------------------------------------------------------------------
# Create a temp project with known structure
# ---------------------------------------------------------------------------
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# --- Project A: Node.js + React + Jest ---
PROJ_A="$TMPDIR_BASE/proj-a"
mkdir -p "$PROJ_A/src" "$PROJ_A/.github/workflows"
echo '{"dependencies":{"react":"^19.0.0","express":"^4.0.0"},"devDependencies":{"jest":"^29.0.0"}}' > "$PROJ_A/package.json"
echo "lockfileVersion: 1" > "$PROJ_A/package-lock.json"
touch "$PROJ_A/src/app.js" "$PROJ_A/src/App.tsx"
echo "module.exports={}" > "$PROJ_A/next.config.js"
echo "FROM node:20" > "$PROJ_A/Dockerfile"
mkdir -p "$PROJ_A/prisma"
echo 'generator client {}' > "$PROJ_A/prisma/schema.prisma"

# Test 3: Scan Node.js project
orch_init_scan "$PROJ_A" 2>/dev/null
[[ $_ORCH_INIT_SCANNED -eq 1 ]] && pass "scan sets scanned flag" || fail "scan sets scanned flag"

# Test 4: Detects JavaScript
langs=$(orch_init_detected_languages)
echo "$langs" | grep -q "javascript" && pass "detects javascript" || fail "detects javascript"

# Test 5: Detects TypeScript
echo "$langs" | grep -q "typescript" && pass "detects typescript" || fail "detects typescript"

# Test 6: Detects React framework
fws=$(orch_init_detected_frameworks)
echo "$fws" | grep -q "react" && pass "detects react" || fail "detects react"

# Test 7: Detects Next.js
echo "$fws" | grep -q "next" && pass "detects next" || fail "detects next"

# Test 8: Detects Express
echo "$fws" | grep -q "express" && pass "detects express" || fail "detects express"

# Test 9: Detects npm
[[ -n "${_ORCH_INIT_PKG_MANAGERS[npm]:-}" ]] && pass "detects npm" || fail "detects npm"

# Test 10: Detects jest
[[ -n "${_ORCH_INIT_TEST_FRAMEWORKS[jest]:-}" ]] && pass "detects jest" || fail "detects jest"

# Test 11: Detects GitHub Actions
orch_init_has_feature ci && pass "detects CI" || fail "detects CI"

# Test 12: Detects Docker
orch_init_has_feature docker && pass "detects docker" || fail "detects docker"

# Test 13: Detects database
orch_init_has_feature database && pass "detects database" || fail "detects database"

# Test 14: Suggests agents
agent_count=$(orch_init_suggest_agents | wc -l)
[[ $agent_count -ge 5 ]] && pass "suggests >= 5 agents" || fail "suggests >= 5 agents (got $agent_count)"

# Test 15: Always suggests CEO, CTO, PM
agents_out=$(orch_init_suggest_agents)
echo "$agents_out" | grep -q "ceo" && pass "suggests CEO" || fail "suggests CEO"
echo "$agents_out" | grep -q "cto" && pass "suggests CTO" || fail "suggests CTO"
echo "$agents_out" | grep -q "pm" && pass "suggests PM" || fail "suggests PM"

# Test 16: Suggests backend (express detected)
echo "$agents_out" | grep -q "backend" && pass "suggests backend" || fail "suggests backend"

# Test 17: Suggests frontend (react/next detected)
echo "$agents_out" | grep -q "frontend" && pass "suggests frontend" || fail "suggests frontend"

# Test 18: Suggests QA (jest detected)
echo "$agents_out" | grep -q "qa" && pass "suggests QA" || fail "suggests QA"

# Test 19: Suggests DevOps (GitHub Actions detected)
echo "$agents_out" | grep -q "devops" && pass "suggests DevOps" || fail "suggests DevOps"

# --- Project B: Python + Django ---
PROJ_B="$TMPDIR_BASE/proj-b"
mkdir -p "$PROJ_B"
touch "$PROJ_B/manage.py" "$PROJ_B/app.py"
echo -e "django==5.0\npytest==8.0" > "$PROJ_B/requirements.txt"
mkdir "$PROJ_B/migrations"

# Test 20: Scan Python project
orch_init_scan "$PROJ_B" 2>/dev/null
langs=$(orch_init_detected_languages)
echo "$langs" | grep -q "python" && pass "detects python" || fail "detects python"

# Test 21: Detects Django
fws=$(orch_init_detected_frameworks)
echo "$fws" | grep -q "django" && pass "detects django" || fail "detects django"

# Test 22: Detects pytest
[[ -n "${_ORCH_INIT_TEST_FRAMEWORKS[pytest]:-}" ]] && pass "detects pytest" || fail "detects pytest"

# Test 23: Detects pip
[[ -n "${_ORCH_INIT_PKG_MANAGERS[pip]:-}" ]] && pass "detects pip" || fail "detects pip"

# Test 24: Detects database (migrations dir)
orch_init_has_feature database && pass "detects database (migrations)" || fail "detects database (migrations)"

# --- Project C: Rust + Tauri ---
PROJ_C="$TMPDIR_BASE/proj-c"
mkdir -p "$PROJ_C/src-tauri/src" "$PROJ_C/src"
echo '[workspace]' > "$PROJ_C/Cargo.toml"
touch "$PROJ_C/src-tauri/src/main.rs"
echo '{}' > "$PROJ_C/src-tauri/tauri.conf.json"
echo '{"dependencies":{"react":"^19"}}' > "$PROJ_C/package.json"
touch "$PROJ_C/src/App.tsx"

# Test 25: Scan Tauri project
orch_init_scan "$PROJ_C" 2>/dev/null
langs=$(orch_init_detected_languages)
echo "$langs" | grep -q "rust" && pass "detects rust" || fail "detects rust"

# Test 26: Detects Tauri framework
fws=$(orch_init_detected_frameworks)
echo "$fws" | grep -q "tauri" && pass "detects tauri" || fail "detects tauri"

# Test 27: Tauri projects get tauri-rust + tauri-ui instead of generic frontend
agents_out=$(orch_init_suggest_agents)
echo "$agents_out" | grep -q "tauri-rust" && pass "suggests tauri-rust" || fail "suggests tauri-rust"
echo "$agents_out" | grep -q "tauri-ui" && pass "suggests tauri-ui" || fail "suggests tauri-ui"

# Test 28: Detects monorepo (Cargo workspace)
orch_init_has_feature monorepo && pass "detects monorepo (cargo)" || fail "detects monorepo (cargo)"

# --- Project D: Empty ---
PROJ_D="$TMPDIR_BASE/proj-d"
mkdir -p "$PROJ_D"

# Test 29: Scan empty project
orch_init_scan "$PROJ_D" 2>/dev/null
[[ ${#_ORCH_INIT_LANGUAGES[@]} -eq 0 ]] && pass "empty: 0 languages" || fail "empty: 0 languages"
[[ ${#_ORCH_INIT_FRAMEWORKS[@]} -eq 0 ]] && pass "empty: 0 frameworks" || fail "empty: 0 frameworks"

# Test 30: Empty project still suggests base agents (CEO, CTO, PM)
agent_count=$(orch_init_suggest_agents | wc -l)
[[ $agent_count -eq 3 ]] && pass "empty: 3 base agents" || fail "empty: 3 base agents (got $agent_count)"

# --- Generate conf ---
OUTPUT_CONF="$TMPDIR_BASE/output/agents.conf"

# Test 31: Generate conf requires scan
_orch_init_reset
if ! orch_init_generate_conf "$OUTPUT_CONF" 2>/dev/null; then
    pass "generate_conf rejects without scan"
else
    fail "generate_conf rejects without scan"
fi

# Test 32: Generate conf succeeds after scan
orch_init_scan "$PROJ_A" 2>/dev/null
orch_init_generate_conf "$OUTPUT_CONF" 2>/dev/null
[[ -f "$OUTPUT_CONF" ]] && pass "generate_conf creates file" || fail "generate_conf creates file"

# Test 33: Conf file has header
grep -q "# OrchyStraw" "$OUTPUT_CONF" && pass "conf has header" || fail "conf has header"

# Test 34: Conf file has agents
grep -q "ceo" "$OUTPUT_CONF" && pass "conf has ceo" || fail "conf has ceo"
grep -q "backend" "$OUTPUT_CONF" && pass "conf has backend" || fail "conf has backend"

# --- Generate prompts ---
PROMPT_DIR="$TMPDIR_BASE/prompts-out"

# Test 35: Generate prompts succeeds
orch_init_scan "$PROJ_A" 2>/dev/null
count=$(orch_init_generate_prompts "$PROMPT_DIR" 2>/dev/null)
[[ $count -ge 5 ]] && pass "generate_prompts creates >= 5 prompts" || fail "generate_prompts creates >= 5 prompts (got $count)"

# Test 36: Prompt files exist
ls "$PROMPT_DIR"/*/0*.txt >/dev/null 2>&1 && pass "prompt files created" || fail "prompt files created"

# Test 37: Prompt content has role section
first_prompt=$(ls "$PROMPT_DIR"/*/0*.txt 2>/dev/null | head -1)
grep -q "## Role" "$first_prompt" && pass "prompt has Role section" || fail "prompt has Role section"

# Test 38: Prompt content has ownership section
grep -q "## File Ownership" "$first_prompt" && pass "prompt has Ownership section" || fail "prompt has Ownership section"

# --- Report ---

# Test 39: Report output
report=$(orch_init_report 2>/dev/null)
echo "$report" | grep -q "Languages detected" && pass "report shows languages" || fail "report shows languages"
echo "$report" | grep -q "Suggested Agent Team" && pass "report shows agent team" || fail "report shows agent team"

# --- Error handling ---

# Test 40: Scan non-existent directory
if ! orch_init_scan "/nonexistent/path/xyz" 2>/dev/null; then
    pass "scan rejects non-existent dir"
else
    fail "scan rejects non-existent dir"
fi

# Test 41: Scan requires argument
if (orch_init_scan 2>/dev/null); then
    fail "scan requires argument"
else
    pass "scan requires argument"
fi

# Test 42: has_feature rejects unknown
if ! orch_init_has_feature "bogus" 2>/dev/null; then
    pass "has_feature rejects unknown"
else
    fail "has_feature rejects unknown"
fi

# Test 43: suggest_agents requires scan
_orch_init_reset
if ! orch_init_suggest_agents 2>/dev/null; then
    pass "suggest_agents requires scan"
else
    fail "suggest_agents requires scan"
fi

# --- Monorepo detection (npm workspaces) ---
PROJ_E="$TMPDIR_BASE/proj-e"
mkdir -p "$PROJ_E"
echo '{"workspaces":["packages/*"]}' > "$PROJ_E/package.json"

# Test 44: Detects monorepo (npm workspaces)
orch_init_scan "$PROJ_E" 2>/dev/null
orch_init_has_feature monorepo && pass "detects monorepo (npm workspaces)" || fail "detects monorepo (npm workspaces)"

# --- Go project ---
PROJ_F="$TMPDIR_BASE/proj-f"
mkdir -p "$PROJ_F"
echo "module example.com/test" > "$PROJ_F/go.mod"
touch "$PROJ_F/main.go"

# Test 45: Detects Go
orch_init_scan "$PROJ_F" 2>/dev/null
langs=$(orch_init_detected_languages)
echo "$langs" | grep -q "go" && pass "detects go" || fail "detects go"

# Test 46: Detects go package manager
[[ -n "${_ORCH_INIT_PKG_MANAGERS[go]:-}" ]] && pass "detects go pkg manager" || fail "detects go pkg manager"

# Test 47: Detects go-test
[[ -n "${_ORCH_INIT_TEST_FRAMEWORKS[go-test]:-}" ]] && pass "detects go-test" || fail "detects go-test"

# --- No CI, No Docker, No Database ---
orch_init_scan "$PROJ_F" 2>/dev/null

# Test 48: No CI correctly reported
! orch_init_has_feature ci && pass "no ci: reported correctly" || fail "no ci: reported correctly"

# Test 49: No Docker correctly reported
! orch_init_has_feature docker && pass "no docker: reported correctly" || fail "no docker: reported correctly"

# Test 50: No database correctly reported
! orch_init_has_feature database && pass "no database: reported correctly" || fail "no database: reported correctly"

# --- Relative path resolution ---
# Test 51: Relative path gets resolved
cd "$TMPDIR_BASE"
orch_init_scan "proj-a" 2>/dev/null
[[ $_ORCH_INIT_SCANNED -eq 1 ]] && pass "relative path resolved" || fail "relative path resolved"
cd "$PROJECT_ROOT"

echo ""
echo "init-project: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
