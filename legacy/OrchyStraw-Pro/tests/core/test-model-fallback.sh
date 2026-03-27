#!/usr/bin/env bash
# Tests for model-fallback.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/src/core/model-fallback.sh"

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

# ── Availability: all models OK ──────────────────────────────────────────

unset USAGE_CLAUDE USAGE_OPENAI USAGE_GEMINI

assert "claude available when no usage" "claude" "$(orch_model_fallback_find "claude")"
assert "openai available when no usage" "openai" "$(orch_model_fallback_find "openai")"
assert "gemini available when no usage" "gemini" "$(orch_model_fallback_find "gemini")"

# ── CLI mapping ──────────────────────────────────────────────────────────

assert "claude CLI" "claude" "$(orch_model_fallback_cli "claude")"
assert "openai CLI" "codex exec" "$(orch_model_fallback_cli "openai")"
assert "gemini CLI" "gemini -p" "$(orch_model_fallback_cli "gemini")"
assert "unknown CLI defaults claude" "claude" "$(orch_model_fallback_cli "unknown")"

# ── Fallback when primary rate-limited ───────────────────────────────────

export USAGE_CLAUDE=0 USAGE_OPENAI=0 USAGE_GEMINI=100

assert "gemini limited falls back to claude" "claude" "$(orch_model_fallback_find "gemini")"

export USAGE_CLAUDE=100 USAGE_OPENAI=0 USAGE_GEMINI=0
assert "claude limited falls back to openai" "openai" "$(orch_model_fallback_find "claude")"

export USAGE_CLAUDE=0 USAGE_OPENAI=100 USAGE_GEMINI=0
assert "openai limited falls back to claude" "claude" "$(orch_model_fallback_find "openai")"

# ── Multiple models limited ──────────────────────────────────────────────

export USAGE_CLAUDE=100 USAGE_OPENAI=100 USAGE_GEMINI=0
assert "claude+openai limited → gemini" "gemini" "$(orch_model_fallback_find "claude")"

export USAGE_CLAUDE=0 USAGE_OPENAI=100 USAGE_GEMINI=100
assert "openai+gemini limited → claude" "claude" "$(orch_model_fallback_find "openai")"

export USAGE_CLAUDE=100 USAGE_OPENAI=0 USAGE_GEMINI=100
assert "claude+gemini limited → openai" "openai" "$(orch_model_fallback_find "claude")"

# ── All models exhausted ─────────────────────────────────────────────────

export USAGE_CLAUDE=100 USAGE_OPENAI=100 USAGE_GEMINI=100
result="$(orch_model_fallback_find "claude" 2>/dev/null)" && rc=0 || rc=$?
assert "all exhausted returns none" "none" "$result"
assert "all exhausted returns 1" "1" "$rc"

# ── Route function (full pipeline) ───────────────────────────────────────

export USAGE_CLAUDE=0 USAGE_OPENAI=0 USAGE_GEMINI=100
result="$(orch_model_fallback_route "06" "gemini" 2>/dev/null)"
assert "route gemini-limited agent → claude CLI" "claude" "$result"

export USAGE_CLAUDE=0 USAGE_OPENAI=0 USAGE_GEMINI=0
result="$(orch_model_fallback_route "06" "claude" 2>/dev/null)"
assert "route available claude → claude CLI" "claude" "$result"

export USAGE_CLAUDE=100 USAGE_OPENAI=0 USAGE_GEMINI=0
result="$(orch_model_fallback_route "05" "claude" 2>/dev/null)"
assert "route claude-limited → codex exec" "codex exec" "$result"

# ── Context file usage checking ──────────────────────────────────────────

unset USAGE_CLAUDE USAGE_OPENAI USAGE_GEMINI
tmp_ctx="$(mktemp)"
cat > "$tmp_ctx" <<'CTX'
claude=0
codex=0
gemini=95
CTX
export ORCH_CONTEXT_FILE="$tmp_ctx"

assert "ctx: gemini limited" "claude" "$(orch_model_fallback_find "gemini")"

unset ORCH_CONTEXT_FILE
rm -f "$tmp_ctx"

# ── Custom threshold ─────────────────────────────────────────────────────

orch_model_fallback_set_threshold 50
export USAGE_CLAUDE=60 USAGE_OPENAI=0 USAGE_GEMINI=0
assert "threshold 50: claude@60 limited" "openai" "$(orch_model_fallback_find "claude")"

orch_model_fallback_set_threshold 90  # reset

# ── Custom chain ─────────────────────────────────────────────────────────

unset USAGE_CLAUDE USAGE_OPENAI USAGE_GEMINI
orch_model_fallback_set_chain "claude" "gemini openai"
export USAGE_CLAUDE=100 USAGE_OPENAI=0 USAGE_GEMINI=0
assert "custom chain: claude → gemini first" "gemini" "$(orch_model_fallback_find "claude")"

# Reset chain
orch_model_fallback_set_chain "claude" "openai gemini"

# ── Custom CLI ───────────────────────────────────────────────────────────

orch_model_fallback_set_cli "openai" "gpt-cli run"
assert "custom CLI" "gpt-cli run" "$(orch_model_fallback_cli "openai")"
orch_model_fallback_set_cli "openai" "codex exec"  # reset

# ── Double source guard ──────────────────────────────────────────────────

source "$PROJECT_ROOT/src/core/model-fallback.sh"
assert "double source guard" "1" "$_ORCH_MODEL_FALLBACK_LOADED"

# ── Summary ──────────────────────────────────────────────────────────────

unset USAGE_CLAUDE USAGE_OPENAI USAGE_GEMINI
printf '\n── model-fallback tests: %d passed, %d failed ──\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
