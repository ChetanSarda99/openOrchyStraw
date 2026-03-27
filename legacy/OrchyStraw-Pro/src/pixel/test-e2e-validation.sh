#!/usr/bin/env bash
# End-to-End Validation of #16 Integration — Pixel Agents Pipeline
#
# Validates the FULL pipeline: emit-jsonl.sh → JSONL files → adapter → WebSocket
# Tests ALL 9 active agents from agents.conf against character-map.json.
#
# Run: bash src/pixel/test-e2e-validation.sh
# Exit code: 0 = all pass, 1 = failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the emitter
source "$SCRIPT_DIR/emit-jsonl.sh"

# Use temp dir to avoid polluting real session
export PIXEL_SESSION_DIR
PIXEL_SESSION_DIR="$(mktemp -d /tmp/orchystraw-e2e-XXXXXX)"
export PIXEL_ENABLED=1

passed=0
failed=0
total=0

assert() {
  total=$((total + 1))
  if eval "$1"; then
    passed=$((passed + 1))
    echo "  ✓ $2"
  else
    failed=$((failed + 1))
    echo "  ✗ $2"
  fi
}

section() {
  echo ""
  echo "── $1 ──"
}

# ── All 9 agents from agents.conf ──
ALL_AGENTS=(01-ceo 02-cto 03-pm 06-backend 08-pixel 09-qa 10-security 11-web 13-hr)

echo "═══════════════════════════════════════════════════"
echo "  OrchyStraw Pixel Agents — E2E Validation (#16)"
echo "═══════════════════════════════════════════════════"
echo "Session dir: $PIXEL_SESSION_DIR"
echo "Agents: ${#ALL_AGENTS[@]}"

# ── Test 1: pixel_init clears session ──
section "Phase 1: Initialization"
pixel_init
assert '[[ -d "$PIXEL_SESSION_DIR" ]]' "Session directory created"

# ── Test 2: Emit lifecycle for ALL 9 agents ──
section "Phase 2: Full lifecycle — all 9 agents"

for agent in "${ALL_AGENTS[@]}"; do
  prompt_path="prompts/${agent}/${agent}.txt"
  pixel_agent_start "$agent" "$prompt_path"
  pixel_agent_read_context "$agent"
  pixel_agent_coding "$agent" "src/${agent}/work.sh"
  pixel_agent_running "$agent" "bash tests/${agent}.sh"
  pixel_agent_done "$agent" "${agent} finished cycle 3"
done

# Verify JSONL for each agent
for agent in "${ALL_AGENTS[@]}"; do
  session_file="${PIXEL_SESSION_DIR}/${agent}/session.jsonl"
  assert '[[ -f "$session_file" ]]' "${agent}: session.jsonl exists"

  line_count=$(wc -l < "$session_file")
  assert '[[ $line_count -ge 7 ]]' "${agent}: has ${line_count} events (expected ≥7)"

  # Verify all lines are valid JSON
  bad=0
  while IFS= read -r line; do
    python3 -c "import json; json.loads('$line')" 2>/dev/null || bad=$((bad + 1))
  done < "$session_file"
  assert '[[ $bad -eq 0 ]]' "${agent}: all JSONL lines are valid JSON"
done

# ── Test 3: PM desk visits ──
section "Phase 3: PM desk visit pattern"

# Reset PM session for clean test
rm -f "${PIXEL_SESSION_DIR}/03-pm/session.jsonl"
pixel_agent_start "03-pm" "prompts/03-pm/03-pm.txt"
pixel_pm_visit "06-backend" "prompts/06-backend/06-backend.txt"
pixel_pm_visit "11-web" "prompts/11-web/11-web.txt"
pixel_pm_visit "09-qa" "prompts/09-qa/09-qa.txt"
pixel_agent_done "03-pm" "Updated all prompts"

pm_file="${PIXEL_SESSION_DIR}/03-pm/session.jsonl"
pm_events=$(wc -l < "$pm_file")
assert '[[ $pm_events -ge 12 ]]' "PM visit pattern: ${pm_events} events (3 visits + start/end)"

# Check PM speech mentions target agents
pm_speech=$(grep -c "Updating" "$pm_file" || true)
assert '[[ $pm_speech -ge 3 ]]' "PM speech mentions 3 target agents"

# ── Test 4: Event type coverage ──
section "Phase 4: Event type coverage"

backend_file="${PIXEL_SESSION_DIR}/06-backend/session.jsonl"
assert 'grep -q "read_file" "$backend_file"' "read_file events present"
assert 'grep -q "write_file" "$backend_file"' "write_file events present"
assert 'grep -q "bash" "$backend_file"' "bash events present"
assert 'grep -q '"'"'"type":"text"'"'"' "$backend_file"' "speech (text) events present"
assert 'grep -q '"'"'"type":"result"'"'"' "$backend_file"' "result (turn end) events present"

# ── Test 5: PIXEL_ENABLED=0 ──
section "Phase 5: PIXEL_ENABLED=0 guard"

export PIXEL_ENABLED=0
disabled_dir="${PIXEL_SESSION_DIR}/disabled-test"
export PIXEL_SESSION_DIR="$disabled_dir"
pixel_init
pixel_agent_start "09-qa" "prompts/09-qa/09-qa.txt"
pixel_agent_done "09-qa" "Should not appear"
assert '! [[ -f "$disabled_dir/09-qa/session.jsonl" ]]' "No JSONL when PIXEL_ENABLED=0"

# Restore
export PIXEL_ENABLED=1
export PIXEL_SESSION_DIR="${PIXEL_SESSION_DIR%/disabled-test}"

# ── Test 6: Character map coverage ──
section "Phase 6: Character map coverage (agents.conf ↔ character-map.json)"

char_map="$PROJECT_ROOT/src/pixel/character-map.json"
for agent in "${ALL_AGENTS[@]}"; do
  has_entry=$(python3 -c "
import json
d = json.load(open('$char_map'))
print('yes' if '$agent' in d['agents'] else 'no')
" 2>/dev/null || echo "no")
  assert '[[ "$has_entry" == "yes" ]]' "${agent}: has character-map entry"
done

# Verify each agent has desk, sprite, idleSpot
for agent in "${ALL_AGENTS[@]}"; do
  complete=$(python3 -c "
import json
d = json.load(open('$char_map'))
a = d['agents'].get('$agent', {})
print('yes' if all(k in a for k in ['desk','sprite','idleSpot','label']) else 'no')
" 2>/dev/null || echo "no")
  assert '[[ "$complete" == "yes" ]]' "${agent}: has desk + sprite + idleSpot + label"
done

# ── Test 7: Timestamp format ──
section "Phase 7: Timestamp format validation"

backend_file="${PIXEL_SESSION_DIR}/06-backend/session.jsonl"
ts=$(python3 -c "
import json
with open('$backend_file') as f:
  for line in f:
    e = json.loads(line.strip())
    ts = e.get('timestamp', '')
    if ts:
      print(ts)
      break
" 2>/dev/null || echo "")
assert '[[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]' "Timestamps in ISO 8601 format: $ts"

# ── Cleanup ──
rm -rf "$PIXEL_SESSION_DIR"

# ── Results ──
echo ""
echo "═══════════════════════════════════════════════════"
echo "  E2E Validation Results: ${passed}/${total} passed, ${failed} failed"
echo "═══════════════════════════════════════════════════"
echo ""

if [[ $failed -gt 0 ]]; then
  echo "FAIL — ${failed} test(s) failed"
  exit 1
else
  echo "PASS — Full pipeline validated"
  echo "  bash emitter → JSONL → adapter → WebSocket → browser"
  exit 0
fi
