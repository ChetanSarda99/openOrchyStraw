# Pixel Agents Integration — Synthetic JSONL Emitter

## What This Does

Emits JSONL events in the format that [pixel-agents-standalone](https://github.com/rolandal/pixel-agents-standalone) expects. Each OrchyStraw agent becomes an animated character in a pixel art office.

## Setup

### 1. Install Pixel Agents Standalone

```bash
git clone https://github.com/rolandal/pixel-agents-standalone
cd pixel-agents-standalone && npm install
cd webview-ui && npm install && cd ..
npm run build && npm start
# Open http://localhost:3456
```

### 2. Wire into auto-agent.sh

Add these lines to `scripts/auto-agent.sh` at the appropriate lifecycle points:

```bash
# At the top (after variable declarations)
source "$(dirname "$0")/../src/pixel/emit-jsonl.sh"

# At cycle start (before agents run)
pixel_init

# Before each agent runs
pixel_agent_start "$AGENT_ID" "$PROMPT_PATH"
pixel_agent_read_context "$AGENT_ID"

# After each agent finishes
pixel_agent_done "$AGENT_ID" "Completed tasks"

# When PM visits each agent
pixel_pm_visit "$TARGET_AGENT_ID" "$TARGET_PROMPT_PATH"
```

### 3. Run a cycle

Start pixel-agents-standalone, then run an OrchyStraw cycle normally. Characters appear and animate.

## API Reference

| Function | Purpose | Animation |
|----------|---------|-----------|
| `pixel_init` | Clear old data, create dirs | — |
| `pixel_emit agent tool input_json` | Raw event | Depends on tool |
| `pixel_say agent "message"` | Speech bubble | Text bubble |
| `pixel_end agent` | Agent done | Walk to idle spot |
| `pixel_agent_start agent prompt` | Agent begins | Read animation |
| `pixel_agent_read_context agent` | Read shared context | Read animation |
| `pixel_agent_coding agent file` | Agent writes code | Typing animation |
| `pixel_agent_running agent cmd` | Agent runs command | Running animation |
| `pixel_agent_update_context agent msg` | Write to shared context | Speech + typing |
| `pixel_pm_visit target prompt` | PM visits agent desk | Speech + read + write |
| `pixel_agent_done agent summary` | Agent finishes | Context update + idle |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PIXEL_SESSION_DIR` | `~/.claude/projects/orchystraw` | Where JSONL files are written |
| `PIXEL_ENABLED` | `1` | Set to `0` to disable all emission |

## JSONL Format

Events match Pixel Agents' expected format:

```json
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"write_file","input":{"path":"src/foo.sh"}}]}}
{"type":"result","subtype":"success","result":"done","session_id":"orchystraw-06-backend"}
```
