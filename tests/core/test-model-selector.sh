#!/usr/bin/env bash
# Test: model-selector.sh — intelligent model selection (#199)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Suppress log output during tests
log() { :; }
ORCH_QUIET=1

# Mock agent config arrays needed by dynamic-router.sh
declare -A AGENT_PROMPTS=()
declare -A AGENT_OWNERSHIP=()
declare -A AGENT_INTERVALS=()
declare -A AGENT_LABELS=()

# Create minimal agents.conf for router
mkdir -p "$TEST_DIR/scripts"
cat > "$TEST_DIR/agents.conf" << 'CONF'
06-backend | prompts/06-backend.txt | scripts/ | 1 | Backend Developer
09-qa-code | prompts/09-qa.txt      | tests/   | 3 | QA Code Review
11-web     | prompts/11-web.txt     | site/    | 1 | Web Developer
CONF

# Source dependencies
source "$PROJECT_ROOT/src/core/dynamic-router.sh"
orch_router_init "$TEST_DIR/agents.conf"

source "$PROJECT_ROOT/src/core/model-selector.sh"

echo "=== model-selector.sh tests ==="

# ---------------------------------------------------------------------------
# Test 1: Module loads
# ---------------------------------------------------------------------------
[[ -n "${_ORCH_MODEL_SELECTOR_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# ---------------------------------------------------------------------------
# Test 2: Init without scores file
# ---------------------------------------------------------------------------
export PROJECT_ROOT="$TEST_DIR"
orch_model_selector_init "$TEST_DIR/nonexistent.jsonl" 2>/dev/null
[[ "$_MS_INITIALIZED" == "true" ]] && pass "init without scores file" || fail "init without scores file"

# ---------------------------------------------------------------------------
# Test 3: Complexity estimation — simple text
# ---------------------------------------------------------------------------
echo "Fix a typo in the readme" > "$TEST_DIR/simple.md"
complexity=$(orch_model_estimate_complexity "$TEST_DIR/simple.md")
[[ "$complexity" == "low" ]] && pass "simple text = low complexity ($complexity)" || fail "simple text = low complexity (got: $complexity)"

# ---------------------------------------------------------------------------
# Test 4: Complexity estimation — complex text with many files
# ---------------------------------------------------------------------------
cat > "$TEST_DIR/complex.md" << 'EOF'
This is a critical security vulnerability that affects multiple files.
We need to update src/core/router.sh, src/core/logger.sh, src/core/error-handler.sh,
scripts/auto-agent.sh, scripts/benchmark/run.sh, tests/test-router.sh,
tests/test-logger.sh, tests/test-error.sh, docs/architecture.md,
docs/security.md, agents.conf, and many more files across the codebase.

The vulnerability is a blocker for production deployment and requires
refactoring the authentication flow, updating the authorization middleware,
patching the session handler, and ensuring all API endpoints validate tokens.

This involves src/api/auth.ts, src/api/session.ts, src/middleware/auth.ts,
src/middleware/rate-limit.ts, src/handlers/login.ts, src/handlers/register.ts,
src/handlers/oauth.ts, src/models/user.ts, src/models/session.ts,
src/utils/crypto.ts, src/utils/jwt.ts, config/security.json, and
.env.production settings.

Additional files that need review: src/api/admin.ts, src/api/health.ts,
src/services/email.ts, src/services/notification.ts, src/types/auth.ts,
src/types/user.ts, scripts/migrate.sh, scripts/seed.sh, tests/auth.test.ts,
tests/session.test.ts, tests/integration/auth.test.ts
EOF
complexity=$(orch_model_estimate_complexity "$TEST_DIR/complex.md")
[[ "$complexity" == "high" ]] && pass "complex text = high complexity ($complexity)" || fail "complex text = high complexity (got: $complexity)"

# ---------------------------------------------------------------------------
# Test 5: Complexity estimation from string (not file)
# ---------------------------------------------------------------------------
complexity=$(orch_model_estimate_complexity "Fix minor cosmetic typo")
[[ "$complexity" == "low" ]] && pass "string input = low complexity" || fail "string input = low complexity (got: $complexity)"

# ---------------------------------------------------------------------------
# Test 6: Quality matrix loading
# ---------------------------------------------------------------------------
mkdir -p "$TEST_DIR/.orchystraw"
cat > "$TEST_DIR/.orchystraw/quality-scores.jsonl" << 'EOF'
{"agent":"06-backend","score":85,"cycle":1,"ts":"2026-04-07T10:00:00Z","model":"opus"}
{"agent":"06-backend","score":90,"cycle":2,"ts":"2026-04-07T11:00:00Z","model":"opus"}
{"agent":"06-backend","score":75,"cycle":3,"ts":"2026-04-07T12:00:00Z","model":"sonnet"}
{"agent":"06-backend","score":80,"cycle":4,"ts":"2026-04-07T13:00:00Z","model":"sonnet"}
{"agent":"06-backend","score":70,"cycle":5,"ts":"2026-04-07T14:00:00Z","model":"sonnet"}
{"agent":"06-backend","score":60,"cycle":6,"ts":"2026-04-07T15:00:00Z","model":"haiku"}
{"agent":"06-backend","score":55,"cycle":7,"ts":"2026-04-07T16:00:00Z","model":"haiku"}
{"agent":"06-backend","score":65,"cycle":8,"ts":"2026-04-07T17:00:00Z","model":"haiku"}
{"agent":"11-web","score":80,"cycle":1,"ts":"2026-04-07T10:00:00Z","model":"sonnet"}
{"agent":"11-web","score":85,"cycle":2,"ts":"2026-04-07T11:00:00Z","model":"sonnet"}
{"agent":"11-web","score":82,"cycle":3,"ts":"2026-04-07T12:00:00Z","model":"sonnet"}
{"agent":"11-web","score":78,"cycle":4,"ts":"2026-04-07T13:00:00Z","model":"sonnet"}
EOF
orch_model_selector_init "$TEST_DIR/.orchystraw/quality-scores.jsonl"

opus_q=$(orch_model_quality_for "06-backend" "opus")
[[ "$opus_q" -eq 87 || "$opus_q" -eq 88 ]] && pass "opus quality for 06-backend ($opus_q)" || fail "opus quality for 06-backend (expected ~87, got: $opus_q)"

sonnet_q=$(orch_model_quality_for "06-backend" "sonnet")
[[ "$sonnet_q" -eq 75 ]] && pass "sonnet quality for 06-backend ($sonnet_q)" || fail "sonnet quality for 06-backend (expected 75, got: $sonnet_q)"

# ---------------------------------------------------------------------------
# Test 7: Quality for unknown agent returns -1
# ---------------------------------------------------------------------------
unknown_q=$(orch_model_quality_for "99-unknown" "opus")
[[ "$unknown_q" -eq -1 ]] && pass "unknown agent quality = -1" || fail "unknown agent quality = -1 (got: $unknown_q)"

# ---------------------------------------------------------------------------
# Test 8: Budget pressure — no spend = none
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=0
_MS_DAILY_BUDGET=50
pressure=$(orch_model_budget_pressure)
[[ "$pressure" == "none" ]] && pass "no spend = no pressure" || fail "no spend = no pressure (got: $pressure)"

# ---------------------------------------------------------------------------
# Test 9: Budget pressure — 85% = downgrade
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=4250  # $42.50 of $50 = 85%
pressure=$(orch_model_budget_pressure)
[[ "$pressure" == "downgrade" ]] && pass "85% spend = downgrade" || fail "85% spend = downgrade (got: $pressure)"

# ---------------------------------------------------------------------------
# Test 10: Budget pressure — 96% = critical
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=4800  # $48 of $50 = 96%
pressure=$(orch_model_budget_pressure)
[[ "$pressure" == "critical" ]] && pass "96% spend = critical" || fail "96% spend = critical (got: $pressure)"

# ---------------------------------------------------------------------------
# Test 11: Model selection under critical budget = haiku
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=4800
selected=$(orch_model_select "06-backend")
[[ "$selected" == "haiku" ]] && pass "critical budget -> haiku" || fail "critical budget -> haiku (got: $selected)"

# ---------------------------------------------------------------------------
# Test 12: Model selection under downgrade — critical agent gets sonnet
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=4250
selected=$(orch_model_select "06-backend")
[[ "$selected" == "sonnet" ]] && pass "downgrade + critical agent -> sonnet" || fail "downgrade + critical agent -> sonnet (got: $selected)"

# ---------------------------------------------------------------------------
# Test 13: Model selection under downgrade — non-critical agent gets haiku
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=4250
selected=$(orch_model_select "11-web")
[[ "$selected" == "haiku" ]] && pass "downgrade + non-critical -> haiku" || fail "downgrade + non-critical -> haiku (got: $selected)"

# ---------------------------------------------------------------------------
# Test 14: Env var override takes priority
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=0
export ORCH_MODEL_OVERRIDE_06_BACKEND="haiku"
selected=$(orch_model_select "06-backend")
[[ "$selected" == "haiku" ]] && pass "env var override -> haiku" || fail "env var override -> haiku (got: $selected)"
unset ORCH_MODEL_OVERRIDE_06_BACKEND

# ---------------------------------------------------------------------------
# Test 15: Quality-aware selection — sonnet with good track record
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=0
# 11-web has sonnet quality 81+ with 4 samples — should select sonnet for medium complexity
selected=$(orch_model_select "11-web")
[[ "$selected" == "sonnet" ]] && pass "quality-aware -> sonnet for 11-web" || fail "quality-aware -> sonnet for 11-web (got: $selected)"

# ---------------------------------------------------------------------------
# Test 16: A/B test assignment is deterministic per agent
# ---------------------------------------------------------------------------
_MS_AB_ENABLED=1
_MS_AB_PERCENTAGE=50
_MS_AB_ASSIGNMENT=()
group1=$(orch_model_ab_assign "test-agent-1")
group2=$(orch_model_ab_assign "test-agent-1")  # same agent = same result
[[ "$group1" == "$group2" ]] && pass "A/B assignment is sticky" || fail "A/B assignment is sticky (got: $group1 vs $group2)"
_MS_AB_ENABLED=0

# ---------------------------------------------------------------------------
# Test 17: Critical agent list check
# ---------------------------------------------------------------------------
_ms_is_critical_agent "06-backend" && pass "06-backend is critical" || fail "06-backend is critical"
_ms_is_critical_agent "11-web" && fail "11-web should not be critical" || pass "11-web is not critical"

# ---------------------------------------------------------------------------
# Test 18: Record spend updates daily spend
# ---------------------------------------------------------------------------
_MS_DAILY_SPEND=0
orch_model_record_spend "06-backend" 100000 "sonnet"
[[ "$_MS_DAILY_SPEND" -gt 0 ]] && pass "record_spend updates daily total ($_MS_DAILY_SPEND cents)" || fail "record_spend updates daily total"

# ---------------------------------------------------------------------------
# Test 19: Selector report runs without error
# ---------------------------------------------------------------------------
report_output=$(orch_model_selector_report 2>&1)
[[ "$report_output" == *"Model Selector Report"* ]] && pass "report generates output" || fail "report generates output"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "test-model-selector: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
