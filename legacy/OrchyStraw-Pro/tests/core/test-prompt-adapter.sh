#!/usr/bin/env bash
# Tests for prompt-adapter.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/src/core/prompt-adapter.sh"

PASS=0 FAIL=0
assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        PASS=$(( PASS + 1 ))
    else
        FAIL=$(( FAIL + 1 ))
        printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$desc" "$expected" "$actual"
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$(( PASS + 1 ))
    else
        FAIL=$(( FAIL + 1 ))
        printf 'FAIL: %s\n  expected to contain: %s\n  actual: %s\n' "$desc" "$needle" "$haystack"
    fi
}

# ── Detection tests ──────────────────────────────────────────────────────

assert "detect claude" "claude" "$(orch_prompt_adapter_detect "claude")"
assert "detect sonnet" "claude" "$(orch_prompt_adapter_detect "sonnet-4")"
assert "detect opus" "claude" "$(orch_prompt_adapter_detect "opus-4")"
assert "detect haiku" "claude" "$(orch_prompt_adapter_detect "haiku-3")"
assert "detect gpt" "openai" "$(orch_prompt_adapter_detect "gpt-5")"
assert "detect openai" "openai" "$(orch_prompt_adapter_detect "openai-gpt4")"
assert "detect codex" "openai" "$(orch_prompt_adapter_detect "codex")"
assert "detect o1" "openai" "$(orch_prompt_adapter_detect "o1-preview")"
assert "detect o3" "openai" "$(orch_prompt_adapter_detect "o3-mini")"
assert "detect gemini" "gemini" "$(orch_prompt_adapter_detect "gemini-2.5-pro")"
assert "detect palm" "gemini" "$(orch_prompt_adapter_detect "palm-2")"
assert "detect unknown" "unknown" "$(orch_prompt_adapter_detect "llama-3")"
assert "detect default" "claude" "$(orch_prompt_adapter_detect "")"

# ── Claude adapter tests ─────────────────────────────────────────────────

result="$(orch_prompt_adapter_wrap "claude" "Fix the bug" "Backend Developer")"
assert_contains "claude has role tag" "<role>" "$result"
assert_contains "claude has task tag" "<task>" "$result"
assert_contains "claude has prompt" "Fix the bug" "$result"
assert_contains "claude has role" "Backend Developer" "$result"
assert_contains "claude has guidelines" "<guidelines>" "$result"

# ── OpenAI adapter tests ─────────────────────────────────────────────────

result="$(orch_prompt_adapter_wrap "gpt-5" "Fix the bug" "Backend Developer")"
assert_contains "openai has system header" "# System" "$result"
assert_contains "openai has instructions" "# Instructions" "$result"
assert_contains "openai has prompt" "Fix the bug" "$result"
assert_contains "openai has role" "Backend Developer" "$result"
assert_contains "openai has output requirements" "# Output Requirements" "$result"

# ── Gemini adapter tests ─────────────────────────────────────────────────

result="$(orch_prompt_adapter_wrap "gemini-2.5-pro" "Fix the bug" "Backend Developer")"
assert_contains "gemini has persona" "**Persona:**" "$result"
assert_contains "gemini has context" "**Context:**" "$result"
assert_contains "gemini has prompt" "Fix the bug" "$result"
assert_contains "gemini has role" "Backend Developer" "$result"
assert_contains "gemini has rules" "**Rules:**" "$result"

# ── Unknown model fallback ───────────────────────────────────────────────

result="$(orch_prompt_adapter_wrap "llama-3" "Fix the bug" "Dev")"
assert_contains "unknown has prompt" "Fix the bug" "$result"
assert_contains "unknown has role" "Dev" "$result"

# ── Empty prompt ─────────────────────────────────────────────────────────

result="$(orch_prompt_adapter_wrap "claude" "" "Dev")"
assert "empty prompt returns empty" "" "$result"

# ── Agent model from conf ────────────────────────────────────────────────

tmp_conf="$(mktemp)"
cat > "$tmp_conf" <<'CONF'
06|Backend|prompts/06-backend/06-backend.txt|1|claude
05|Tauri-UI|prompts/05-tauri-ui/05-tauri-ui.txt|1|gemini-2.5-pro
09|QA|prompts/09-qa/09-qa.txt|3|codex
07|iOS|prompts/07-ios/07-ios.txt|1|
CONF

assert "conf claude" "claude" "$(orch_prompt_adapter_agent_model "06" "$tmp_conf")"
assert "conf gemini" "gemini" "$(orch_prompt_adapter_agent_model "05" "$tmp_conf")"
assert "conf openai" "openai" "$(orch_prompt_adapter_agent_model "09" "$tmp_conf")"
assert "conf empty defaults claude" "claude" "$(orch_prompt_adapter_agent_model "07" "$tmp_conf")"
assert "conf missing agent defaults claude" "claude" "$(orch_prompt_adapter_agent_model "99" "$tmp_conf")"
assert "conf no file defaults claude" "claude" "$(orch_prompt_adapter_agent_model "06" "/nonexistent")"

rm -f "$tmp_conf"

# ── File adapter ─────────────────────────────────────────────────────────

tmp_prompt="$(mktemp)"
echo "Build the feature" > "$tmp_prompt"
result="$(orch_prompt_adapter_file "claude" "$tmp_prompt" "Dev")"
assert_contains "file adapter has content" "Build the feature" "$result"
assert_contains "file adapter has tags" "<task>" "$result"
rm -f "$tmp_prompt"

# Missing file
result="$(orch_prompt_adapter_file "claude" "/nonexistent" "Dev" 2>/dev/null)" && true
assert "missing file fails" "1" "$?"

# ── Double source guard ──────────────────────────────────────────────────

# Source again — should be no-op
source "$PROJECT_ROOT/src/core/prompt-adapter.sh"
assert_contains "double source guard works" "1" "$_ORCH_PROMPT_ADAPTER_LOADED"

# ── Summary ──────────────────────────────────────────────────────────────

printf '\n── prompt-adapter tests: %d passed, %d failed ──\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
