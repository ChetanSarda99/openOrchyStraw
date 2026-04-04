#!/usr/bin/env bash
# Test: observability.sh — metrics, traces, dashboards
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

source "$PROJECT_ROOT/src/core/observability.sh"

echo "=== observability.sh tests ==="

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

# Test 1: Module loads
[[ -n "${_ORCH_OBS_LOADED:-}" ]] && pass "module loads" || fail "module loads"

# Test 2: Init creates directory
orch_obs_init "$TEST_DIR/project"
[[ -d "$TEST_DIR/project/.orchystraw/observability" ]] && pass "init: dir created" || fail "init: dir created"
[[ "$_ORCH_OBS_INITED" == "true" ]] && pass "init: flag set" || fail "init: flag set"

# Test 3: Set cycle
orch_obs_set_cycle 5
[[ $_ORCH_OBS_CYCLE -eq 5 ]] && pass "set_cycle: 5" || fail "set_cycle: 5"

# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------

# Test 4: Record and get metric
orch_obs_record_metric "06-backend" "tokens_used" 15000
val=$(orch_obs_get_metric "06-backend" "tokens_used")
[[ "$val" == "15000" ]] && pass "metric: record and get" || fail "metric: record and get (got $val)"

# Test 5: Metrics accumulate
orch_obs_record_metric "06-backend" "tokens_used" 5000
val=$(orch_obs_get_metric "06-backend" "tokens_used")
[[ "$val" == "20000" ]] && pass "metric: accumulates" || fail "metric: accumulates (got $val)"

# Test 6: Default metric is 0
val=$(orch_obs_get_metric "06-backend" "nonexistent")
[[ "$val" == "0" ]] && pass "metric: default 0" || fail "metric: default 0 (got $val)"

# Test 7: Record error
orch_obs_record_error "06-backend" "timeout after 30s"
errors=$(orch_obs_get_metric "06-backend" "errors")
[[ "$errors" == "1" ]] && pass "record_error: count=1" || fail "record_error: count=1 (got $errors)"

# ---------------------------------------------------------------------------
# Spans (timing)
# ---------------------------------------------------------------------------

# Test 8: Start and end span
orch_obs_start_span "06-backend" "execute"
sleep 0.1
latency=$(orch_obs_end_span "06-backend" "execute")
[[ "$latency" -ge 0 ]] && pass "span: latency recorded ($latency ms)" || fail "span: latency recorded"

# Test 9: Get latency after span
stored=$(orch_obs_get_latency "06-backend" "execute")
[[ "$stored" -ge 0 ]] && pass "get_latency: returns value" || fail "get_latency: returns value"

# Test 10: End span without start warns
result=$(orch_obs_end_span "06-backend" "nonexistent" 2>/dev/null || true)
[[ "$result" == "0" ]] && pass "end_span: no start returns 0" || fail "end_span: no start returns 0"

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

# Test 11: Events are recorded
count=$(orch_obs_event_count)
[[ $count -ge 3 ]] && pass "event_count: $count events" || fail "event_count: expected >= 3 (got $count)"

# Test 12: Export JSON outputs events
json=$(orch_obs_export_json)
echo "$json" | grep -q "span_start" && pass "export: has span_start" || fail "export: has span_start"
echo "$json" | grep -q "metric" && pass "export: has metric" || fail "export: has metric"
echo "$json" | grep -q "error" && pass "export: has error" || fail "export: has error"

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

# Test 13: Dashboard output
orch_obs_record_metric "11-web" "tokens_used" 8000
orch_obs_record_metric "11-web" "cost_usd" 0
dashboard=$(orch_obs_dashboard)
echo "$dashboard" | grep -q "Observability Dashboard" && pass "dashboard: has title" || fail "dashboard: has title"
echo "$dashboard" | grep -q "06-backend" && pass "dashboard: has agent" || fail "dashboard: has agent"
echo "$dashboard" | grep -q "TOTALS" && pass "dashboard: has totals" || fail "dashboard: has totals"

# Test 14: Dashboard with no data
orch_obs_init "$TEST_DIR/empty"
dashboard=$(orch_obs_dashboard)
echo "$dashboard" | grep -q "No metrics" && pass "dashboard: empty state" || fail "dashboard: empty state"

# ---------------------------------------------------------------------------
# Flush
# ---------------------------------------------------------------------------

# Test 15: Flush persists to disk
orch_obs_init "$TEST_DIR/flush-test"
orch_obs_set_cycle 1
orch_obs_record_metric "agent" "tokens" 100
orch_obs_start_span "agent" "work"
orch_obs_end_span "agent" "work" > /dev/null

before_count=$(orch_obs_event_count)
orch_obs_flush
after_count=$(orch_obs_event_count)

[[ -f "$TEST_DIR/flush-test/.orchystraw/observability/events-cycle-1.jsonl" ]] && pass "flush: file created" || fail "flush: file created"
[[ $after_count -eq 0 ]] && pass "flush: events cleared" || fail "flush: events cleared (got $after_count)"
[[ $before_count -gt 0 ]] && pass "flush: had events before" || fail "flush: had events before"

# Test 16: Flush without init warns
_ORCH_OBS_INITED=false
if ! orch_obs_flush 2>/dev/null; then
    pass "flush: without init fails"
else
    fail "flush: without init fails"
fi

# Test 17: Multiple agents in dashboard
orch_obs_init "$TEST_DIR/multi"
orch_obs_record_metric "agent-1" "tokens_used" 1000
orch_obs_record_metric "agent-2" "tokens_used" 2000
orch_obs_record_metric "agent-3" "tokens_used" 3000
dashboard=$(orch_obs_dashboard)
echo "$dashboard" | grep -q "agent-1" && pass "multi-agent: agent-1 in dashboard" || fail "multi-agent: agent-1"
echo "$dashboard" | grep -q "agent-3" && pass "multi-agent: agent-3 in dashboard" || fail "multi-agent: agent-3"

echo ""
echo "observability: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
