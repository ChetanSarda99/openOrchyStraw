#!/usr/bin/env bash
# Test: prompt-compression.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/src/core/prompt-compression.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; exit 1; }

# Create a test prompt file
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/test-prompt.txt" << 'PROMPT'
# OrchyStraw — Test Agent
## For Claude Code - Test Role

**Date:** March 29, 2026 — 16:44
**Your Role:** Test Agent

## What is OrchyStraw?

Multi-agent AI coding orchestration. The core is a bash script that reads
agents.conf, spawns AI agents with their prompts, manages cycles, and coordinates
via shared context files. Each agent has a role (backend, frontend, QA, security)
and ownership boundaries that control which files they can modify. The orchestrator
handles branching, committing, merging, and prompt validation automatically.
Philosophy: zero external dependencies for the core engine.

## Tech Stack

- **Orchestrator:** Bash (POSIX-compatible where possible, minimum 5.0)
- **Config:** Markdown + plain text (agents.conf, prompts)
- **Scripts:** Bash, Python (for complex parsing/analysis)
- **AI CLI:** Claude Code (primary), runs with --dangerously-skip-permissions
- **Version Control:** Git, feature branches per cycle, auto-merge to main
- **Testing:** Bash unit tests in tests/core/, 148+ assertions
- **Monitoring:** Structured logging via logger.sh, orchestrator.log per cycle
- **Documentation:** Markdown, ADRs in docs/architecture/

## File Ownership (STRICT)

You OWN and may create/edit:
- src/api/ — API endpoints (if/when we add a server layer)
- src/core/ — core orchestration logic (modules, design docs)
- src/lib/ — shared libraries/utilities
- scripts/ — orchestrator script, helper scripts, tooling
- prisma/ — database schema (if/when needed)
- benchmarks/ — SWE-bench, Ralph comparison, FeatureBench

You NEVER touch:
- src-tauri/ — Tauri Rust backend (04-tauri-rust)
- src/ — Tauri UI components (05-tauri-ui)
- prompts/ — agent prompts except your own
- ios/ — iOS companion app (07-ios)
- docs/ — documentation except architecture (02-cto)
- pixel-agents/ — Pixel Agents fork (08-pixel)

## PROTECTED FILES — Never Touch

Regardless of your ownership, these files are off-limits:
- scripts/auto-agent.sh — the orchestrator (touching this breaks everything)
- scripts/agents.conf — agent config (humans only)
- scripts/check-usage.sh — usage checker
- CLAUDE.md — root project instructions
- .orchystraw/ — app data layer

## Current Tasks

### Task 1: Build the thing
- Do the work
- Ship it

## What's DONE (Cycle 1-5)

- Built module A
- Built module B
- Fixed BUG-001

## Research-First Protocol

Check registry before building.

## Auto-Cycle Mode

When running in auto-cycle mode:
1. Read tasks
2. Execute them
3. Write status

## Git Safety (CRITICAL)

- NEVER run destructive git commands
PROMPT

# ── Test 1: Init ──
orch_prompt_init
[[ "$_ORCH_PROMPT_TOKEN_BUDGET" == "0" ]] || fail "T1: default budget should be 0"
pass "T1: init with default budget"

# ── Test 2: Init with budget ──
orch_prompt_init 5000
[[ "$_ORCH_PROMPT_TOKEN_BUDGET" == "5000" ]] || fail "T2: budget not set"
pass "T2: init with custom budget"

# ── Test 3: Classify sections ──
orch_prompt_classify "test-agent" "$TEST_DIR/test-prompt.txt"
[[ "${_ORCH_PROMPT_SEC_COUNT[test-agent]}" -gt 0 ]] || fail "T3: no sections parsed"
pass "T3: classify parsed sections (${_ORCH_PROMPT_SEC_COUNT[test-agent]})"

# ── Test 4: Stable sections identified ──
found_stable=false
count="${_ORCH_PROMPT_SEC_COUNT[test-agent]}"
for ((i = 0; i < count; i++)); do
    if [[ "${_ORCH_PROMPT_SEC_TIER[test-agent:$i]}" == "stable" ]]; then
        found_stable=true
        break
    fi
done
[[ "$found_stable" == true ]] || fail "T4: no stable sections found"
pass "T4: stable sections identified"

# ── Test 5: Dynamic sections identified ──
found_dynamic=false
for ((i = 0; i < count; i++)); do
    if [[ "${_ORCH_PROMPT_SEC_TIER[test-agent:$i]}" == "dynamic" ]]; then
        found_dynamic=true
        break
    fi
done
[[ "$found_dynamic" == true ]] || fail "T5: no dynamic sections found"
pass "T5: dynamic sections identified"

# ── Test 6: Reference sections identified ──
found_reference=false
for ((i = 0; i < count; i++)); do
    if [[ "${_ORCH_PROMPT_SEC_TIER[test-agent:$i]}" == "reference" ]]; then
        found_reference=true
        break
    fi
done
[[ "$found_reference" == true ]] || fail "T6: no reference sections found"
pass "T6: reference sections identified"

# ── Test 7: Tech Stack classified as stable ──
for ((i = 0; i < count; i++)); do
    if [[ "${_ORCH_PROMPT_SEC_HEADERS[test-agent:$i]}" == "Tech Stack" ]]; then
        [[ "${_ORCH_PROMPT_SEC_TIER[test-agent:$i]}" == "stable" ]] || fail "T7: Tech Stack not stable"
        break
    fi
done
pass "T7: Tech Stack classified as stable"

# ── Test 8: Current Tasks classified as dynamic ──
for ((i = 0; i < count; i++)); do
    if [[ "${_ORCH_PROMPT_SEC_HEADERS[test-agent:$i]}" == "Current Tasks" ]]; then
        [[ "${_ORCH_PROMPT_SEC_TIER[test-agent:$i]}" == "dynamic" ]] || fail "T8: Current Tasks not dynamic"
        break
    fi
done
pass "T8: Current Tasks classified as dynamic"

# ── Test 9: Git Safety classified as reference ──
for ((i = 0; i < count; i++)); do
    if [[ "${_ORCH_PROMPT_SEC_HEADERS[test-agent:$i]}" == *"Git Safety"* ]]; then
        [[ "${_ORCH_PROMPT_SEC_TIER[test-agent:$i]}" == "reference" ]] || fail "T9: Git Safety not reference"
        break
    fi
done
pass "T9: Git Safety classified as reference"

# ── Test 10: Full mode outputs everything ──
full_output=$(orch_prompt_compress "test-agent" "full")
[[ "$full_output" == *"Tech Stack"* ]] || fail "T10: full mode missing Tech Stack"
[[ "$full_output" == *"Current Tasks"* ]] || fail "T10: full mode missing Current Tasks"
[[ "$full_output" == *"Git Safety"* ]] || fail "T10: full mode missing Git Safety"
pass "T10: full mode outputs all sections"

# ── Test 11: Standard mode condenses stable sections ──
std_output=$(orch_prompt_compress "test-agent" "standard")
[[ "$std_output" == *"unchanged since last run"* ]] || fail "T11: standard mode not condensing stable"
[[ "$std_output" == *"Current Tasks"* ]] || fail "T11: standard mode missing dynamic"
[[ "$std_output" == *"Git Safety"* ]] || fail "T11: standard mode missing reference"
pass "T11: standard mode condenses stable, keeps dynamic+reference"

# ── Test 12: Standard mode is shorter than full ──
full_len=${#full_output}
std_len=${#std_output}
[[ "$std_len" -lt "$full_len" ]] || fail "T12: standard ($std_len) not shorter than full ($full_len)"
pass "T12: standard mode saves tokens (full=$full_len, std=$std_len)"

# ── Test 13: Minimal mode only includes dynamic ──
min_output=$(orch_prompt_compress "test-agent" "minimal")
[[ "$min_output" == *"Current Tasks"* ]] || fail "T13: minimal missing dynamic"
[[ "$min_output" != *"Tech Stack"* ]] || fail "T13: minimal should not have stable"
[[ "$min_output" != *"Git Safety"* ]] || fail "T13: minimal should not have reference"
pass "T13: minimal mode only includes dynamic sections"

# ── Test 14: Minimal is shortest ──
min_len=${#min_output}
[[ "$min_len" -lt "$std_len" ]] || fail "T14: minimal ($min_len) not shorter than standard ($std_len)"
pass "T14: minimal is shortest mode"

# ── Test 15: Token estimation ──
tokens=$(orch_prompt_estimate_tokens "Hello world, this is a test string.")
[[ "$tokens" -gt 0 ]] || fail "T15: token estimate should be > 0"
[[ "$tokens" -lt 100 ]] || fail "T15: token estimate too high for short string"
pass "T15: token estimation works ($tokens tokens)"

# ── Test 16: Token estimation from stdin ──
tokens2=$(echo "Hello world, this is a test string." | orch_prompt_estimate_tokens)
[[ "$tokens2" == "$tokens" || "$tokens2" == "$((tokens + 1))" ]] || fail "T16: stdin estimate doesn't match arg estimate"
pass "T16: token estimation from stdin"

# ── Test 17: Stable hash generation ──
# Call directly (not in subshell) to set internal state, then read from state
orch_prompt_stable_hash "test-agent" > /dev/null
hash="${_ORCH_PROMPT_STABLE_HASH[test-agent]:-}"
[[ -n "$hash" ]] || fail "T17: hash is empty"
[[ "$hash" != "empty" ]] || fail "T17: hash should not be empty for prompt with stable sections"
pass "T17: stable hash generated ($hash)"

# ── Test 18: Hash is deterministic ──
orch_prompt_stable_hash "test-agent" > /dev/null
hash2="${_ORCH_PROMPT_STABLE_HASH[test-agent]:-}"
[[ "$hash" == "$hash2" ]] || fail "T18: hash not deterministic ($hash != $hash2)"
pass "T18: hash is deterministic"

# ── Test 19: Save and load hashes ──
orch_prompt_save_hashes "$TEST_DIR/hashes.txt"
[[ -f "$TEST_DIR/hashes.txt" ]] || fail "T19: hash file not created"
pass "T19: save hashes to file"

# ── Test 20: Load hashes and verify ──
unset _ORCH_PROMPT_PREV_HASH; declare -g -A _ORCH_PROMPT_PREV_HASH=()
orch_prompt_load_hashes "$TEST_DIR/hashes.txt"
[[ "${_ORCH_PROMPT_PREV_HASH[test-agent]:-}" == "$hash" ]] || fail "T20: loaded hash doesn't match (got '${_ORCH_PROMPT_PREV_HASH[test-agent]:-}', expected '$hash')"
pass "T20: load hashes from file"

# ── Test 21: Mode decision — first run (no prev hash) ──
unset _ORCH_PROMPT_PREV_HASH; declare -g -A _ORCH_PROMPT_PREV_HASH=()
mode=$(orch_prompt_mode_for_agent "test-agent")
[[ "$mode" == "full" ]] || fail "T21: first run should be full mode (got $mode)"
pass "T21: first run -> full mode"

# ── Test 22: Mode decision — stable unchanged ──
_ORCH_PROMPT_PREV_HASH["test-agent"]="$hash"
mode=$(orch_prompt_mode_for_agent "test-agent")
[[ "$mode" == "standard" ]] || fail "T22: unchanged stable should be standard (got $mode)"
pass "T22: unchanged stable -> standard mode"

# ── Test 23: Mode decision — stable changed ──
_ORCH_PROMPT_PREV_HASH["test-agent"]="different_hash_value"
mode=$(orch_prompt_mode_for_agent "test-agent")
[[ "$mode" == "full" ]] || fail "T23: changed stable should be full (got $mode)"
pass "T23: changed stable -> full mode"

# ── Test 24: Stats output ──
stats=$(orch_prompt_stats "test-agent")
[[ "$stats" == *"stable:"* ]] || fail "T24: stats missing stable line"
[[ "$stats" == *"dynamic:"* ]] || fail "T24: stats missing dynamic line"
[[ "$stats" == *"reference:"* ]] || fail "T24: stats missing reference line"
[[ "$stats" == *"standard mode saves"* ]] || fail "T24: stats missing savings line"
pass "T24: stats output format correct"

# ── Test 25: Classify missing file returns error ──
orch_prompt_classify "missing" "$TEST_DIR/nonexistent.txt" 2>/dev/null && fail "T25: should fail on missing file"
pass "T25: missing file returns error"

# ── Test 26: Compress without classify returns error ──
orch_prompt_compress "unknown-agent" "full" 2>/dev/null && fail "T26: should fail without classify"
pass "T26: compress without classify returns error"

# ── Test 27: Load hashes from nonexistent file (no error) ──
orch_prompt_load_hashes "$TEST_DIR/nonexistent-hashes.txt"
pass "T27: load nonexistent hash file succeeds silently"

# ── Test 28: Empty prompt file ──
touch "$TEST_DIR/empty-prompt.txt"
orch_prompt_classify "empty-agent" "$TEST_DIR/empty-prompt.txt"
[[ "${_ORCH_PROMPT_SEC_COUNT[empty-agent]}" == "0" ]] || fail "T28: empty file should have 0 sections"
pass "T28: empty file classified with 0 sections"

# ── Test 29: Hash for agent with no stable sections ──
# Create a prompt with only dynamic content
cat > "$TEST_DIR/dynamic-only.txt" << 'DYN'
## Current Tasks
- Do stuff

## What's DONE
- Done stuff
DYN
orch_prompt_classify "dynamic-agent" "$TEST_DIR/dynamic-only.txt"
orch_prompt_stable_hash "dynamic-agent" > /dev/null
dyn_hash="${_ORCH_PROMPT_STABLE_HASH[dynamic-agent]:-}"
[[ "$dyn_hash" == "empty" ]] || fail "T29: no-stable agent should have 'empty' hash (got $dyn_hash)"
pass "T29: no-stable-sections -> empty hash"

# ── Test 30: Token budget triggers minimal mode ──
orch_prompt_init 10  # Very small budget
_ORCH_PROMPT_PREV_HASH["test-agent"]="$hash"  # Stable unchanged
mode=$(orch_prompt_mode_for_agent "test-agent")
[[ "$mode" == "minimal" ]] || fail "T30: tiny budget should trigger minimal (got $mode)"
pass "T30: tiny token budget -> minimal mode"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════"
echo "  prompt-compression.sh: $PASS PASSED, $FAIL FAILED"
echo "═══════════════════════════════════════"
[[ "$FAIL" -eq 0 ]] || exit 1
