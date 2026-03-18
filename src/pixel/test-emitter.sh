#!/usr/bin/env bash
# Test script — simulates an OrchyStraw cycle and verifies JSONL output.
# Run: bash src/pixel/test-emitter.sh
#
# After running, check the output at ~/.claude/projects/orchystraw/
# or start pixel-agents-standalone to see characters animate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the emitter
source "$SCRIPT_DIR/emit-jsonl.sh"

echo "=== OrchyStraw Pixel Emitter Test ==="
echo "Session dir: $PIXEL_SESSION_DIR"
echo ""

# ── Initialize ──
echo "1. Initializing pixel session..."
pixel_init
echo "   Done. Cleared old JSONL files."

# ── Simulate a cycle ──
echo ""
echo "2. Simulating cycle with 3 agents..."
echo ""

# Backend agent starts
echo "   [06-backend] Starting..."
pixel_agent_start "06-backend" "prompts/06-backend/06-backend.txt"
pixel_agent_read_context "06-backend"
sleep 0.2

# Backend codes
echo "   [06-backend] Coding..."
pixel_agent_coding "06-backend" "src/core/engine.sh"
pixel_agent_coding "06-backend" "src/lib/utils.sh"
sleep 0.2

# Web agent starts (parallel)
echo "   [11-web] Starting..."
pixel_agent_start "11-web" "prompts/11-web/11-web.txt"
pixel_agent_read_context "11-web"
pixel_agent_coding "11-web" "site/src/pages/index.tsx"
sleep 0.2

# Backend runs tests
echo "   [06-backend] Running tests..."
pixel_agent_running "06-backend" "bash tests/run.sh"
sleep 0.2

# Backend finishes
echo "   [06-backend] Done."
pixel_agent_done "06-backend" "Added engine improvements"

# Web finishes
echo "   [11-web] Done."
pixel_agent_done "11-web" "Updated landing page"

# PM runs last — visits each agent
echo ""
echo "   [03-pm] PM coordinator starting..."
pixel_agent_start "03-pm" "prompts/03-pm/03-pm.txt"
pixel_agent_read_context "03-pm"
sleep 0.1

echo "   [03-pm] Visiting 06-backend..."
pixel_pm_visit "06-backend" "prompts/06-backend/06-backend.txt"
sleep 0.1

echo "   [03-pm] Visiting 11-web..."
pixel_pm_visit "11-web" "prompts/11-web/11-web.txt"
sleep 0.1

echo "   [03-pm] Done."
pixel_agent_done "03-pm" "Updated all agent prompts"

# ── Verify output ──
echo ""
echo "=== Results ==="
echo ""

for agent_dir in "$PIXEL_SESSION_DIR"/*/; do
  agent_id=$(basename "$agent_dir")
  session_file="$agent_dir/session.jsonl"
  if [[ -f "$session_file" ]]; then
    line_count=$(wc -l < "$session_file")
    echo "  $agent_id: $line_count events"
    echo "    First event: $(head -1 "$session_file" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['message']['content'][0].get('name', d['message']['content'][0].get('text','?')[:40]))" 2>/dev/null || head -c 80 "$session_file")"
    echo "    Last event:  $(tail -1 "$session_file" | python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('type','?'); print(f\"{t} ({d.get('subtype','')})\" if t=='result' else d['message']['content'][0].get('name', d['message']['content'][0].get('text','?')[:40]))" 2>/dev/null || tail -c 80 "$session_file")"
  fi
done

echo ""
echo "JSONL files ready at: $PIXEL_SESSION_DIR"
echo "Start pixel-agents-standalone to see the visualization."
echo ""
echo "=== Test complete ==="
