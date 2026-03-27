# Pixel Agents Integration — Technical Spec
**Last Updated:** March 16, 2026  
**Author:** CS + Chai  
**References:**  
- Pixel Agents (original): https://github.com/pablodelucca/pixel-agents (MIT)  
- Pixel Agents Standalone: https://github.com/rolandal/pixel-agents-standalone (MIT)

---

## The Vision

Every Orchystraw cycle, agents appear in the pixel art office and get to work:

- **Backend agent** sits at their desk and starts typing
- **Frontend agent** walks in, sits down, starts coding
- **QA agent** reads files when their interval hits
- **PM agent** walks around between desks, updating each agent's instructions after workers finish
- **Idle agents** sit still or wander — visually showing they haven't run this cycle
- **Shared context activity** shows as agents "talking" (speech bubble) before moving on

This is zero new infrastructure. It works with existing tools. And it's the early prototype of Agent Factory's visualization layer.

---

## How Pixel Agents Works (Technical)

### What it watches
Pixel Agents reads Claude Code's JSONL transcript files from `~/.claude/projects/`.

Every Claude Code **interactive** session writes to:
```
~/.claude/projects/<project-hash>/claude_messages_<session-id>.jsonl
```

Each line is a JSON object representing a conversation turn or tool use:
```json
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"write_file","input":{"path":"backend/api.py"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"...","content":"OK"}]}}
```

### How it maps to animations
The JSONL parser detects:
| JSONL event | Character state |
|-------------|----------------|
| `tool_use: write_file` | Typing animation |
| `tool_use: read_file / grep` | Reading animation |
| `tool_use: bash` | Running animation |
| No activity for N seconds | Idle / walking |
| `waiting_for_permission` | Speech bubble |
| Turn ends | Walks to idle spot |

### The standalone fork
`rolandal/pixel-agents-standalone` is the key one — runs as a web app at `localhost:3456`. Stack:
- Express + WebSocket server
- **chokidar** watches `~/.claude/projects/` for JSONL file changes
- Parser reads new JSONL lines, extracts agent state, emits WebSocket events
- React + Canvas 2D renders the office

No VS Code required. Works in any browser.

---

## The Problem: Orchystraw Uses `--print` Mode

Orchystraw runs Claude Code like this:
```bash
claude --print --permission-mode bypassPermissions "$(cat prompts/02-backend/02-backend.txt)"
```

`--print` mode is **batch/headless** — it outputs to stdout and likely does NOT write JSONL transcripts to `~/.claude/projects/`. Interactive sessions do. `--print` doesn't.

So Pixel Agents, which watches `~/.claude/projects/`, sees nothing when Orchystraw runs.

**Solution: Orchystraw emits synthetic JSONL events.**

---

## Integration Approach 1 — Synthetic JSONL Emitter (Ship Now)

Add a small bash function to `auto-agent.sh` that writes JSONL events in the exact format Pixel Agents expects — one file per agent, in the directory Pixel Agents already watches.

### How it works

```
~/.claude/projects/orchystraw/
├── 02-backend/
│   └── session.jsonl        ← emitted by auto-agent.sh
├── 03-frontend/
│   └── session.jsonl
├── 05-qa/
│   └── session.jsonl
└── 01-pm/
    └── session.jsonl
```

`auto-agent.sh` writes lines to these files as agents start, work, and finish:

```bash
emit_jsonl() {
  local agent_id="$1"
  local tool_name="$2"
  local input_json="$3"
  local dir="$HOME/.claude/projects/orchystraw/$agent_id"
  mkdir -p "$dir"
  echo "{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"name\":\"$tool_name\",\"input\":$input_json}]}}" >> "$dir/session.jsonl"
}

# Agent starts → write_file (typing)
emit_jsonl "02-backend" "write_file" "{\"path\":\"backend/\"}"

# Agent reads shared context → read_file (reading)
emit_jsonl "02-backend" "read_file" "{\"path\":\"prompts/00-shared-context/context.md\"}"

# Agent finishes → bash (committing)
emit_jsonl "02-backend" "bash" "{\"command\":\"git commit\"}"

# PM updates prompt → write_file at agent's prompt path (PM is "at their desk")
emit_jsonl "01-pm" "write_file" "{\"path\":\"prompts/02-backend/02-backend.txt\"}"
```

### What users see
1. Cycle starts → Backend + Frontend characters appear and walk to desks
2. Backend character types (write_file events)
3. Frontend character reads (shared context read), then types
4. QA reads files (if interval hit)
5. Workers finish → characters go idle
6. PM character walks to each agent's desk one by one (write_file to each prompt)
7. Cycle ends → all characters idle or wander

### Implementation cost
- ~50 lines of bash added to `auto-agent.sh`
- One new section in `agents.conf` for pixel agent IDs (or just use existing agent IDs)
- JSONL files cleared at cycle start, populated during cycle
- Works with Pixel Agents standalone out of the box — no changes to Pixel Agents needed

### Setup for users
```bash
# Install Pixel Agents standalone
git clone https://github.com/rolandal/pixel-agents-standalone
cd pixel-agents-standalone && npm install
cd webview-ui && npm install && cd ..
npm run build && npm start
# Open http://localhost:3456
```
Then run Orchystraw cycles normally — characters appear automatically.

---

## Integration Approach 2 — orchystraw-status.json + WebSocket shim (Better UX)

Instead of synthesizing JSONL, emit a structured status file that a purpose-built watcher reads and translates into precise WebSocket events.

### Status file format
```json
{
  "cycle": 12,
  "phase": "workers_running",
  "started_at": "2026-03-16T18:00:00Z",
  "agents": [
    { "id": "02-backend", "label": "Backend", "state": "typing", "file": "backend/api.py" },
    { "id": "03-frontend", "label": "Frontend", "state": "reading", "file": "prompts/00-shared-context/context.md" },
    { "id": "05-qa", "label": "QA", "state": "idle", "file": null },
    { "id": "01-pm", "label": "PM", "state": "waiting", "file": null }
  ],
  "shared_context_updated_at": "2026-03-16T18:01:30Z"
}
```

Written to: `<project-root>/.orchystraw/status.json`

A small Node.js watcher (`orchystraw-watch.js`) reads this file and injects WebSocket messages directly into Pixel Agents standalone's server.

**More control. Role labels show up correctly. PM visually visits each desk. Speech bubbles say what each agent is working on.**

---

## Integration Approach 3 — Fork + Orchystraw Adapter (Agent Factory Path)

Fork `pixel-agents-standalone`, add a native Orchystraw mode.

### What's different
- **Agent discovery** from `agents.conf` instead of `~/.claude/projects/`
- **Role-aware characters** — PM gets a different sprite or desk (the "manager" chair), QA gets a review desk
- **Cycle timeline** — progress bar showing cycle N of M, phase indicator (workers / PM / committing / done)
- **Shared context panel** — side panel showing latest shared context entries with who wrote what
- **PM path animation** — when PM runs, character physically walks from desk to desk in sequence, spending time at each one
- **Speech bubbles** — agent names + current task (pulled from prompt file's `## YOUR TASKS` section)
- **Error state** — if an agent hits a rogue write and gets reverted, character shows a "confused" animation

### Tech changes needed
- New `orchystraw-adapter.js` alongside `claude-adapter.js` in the server
- New watcher that monitors `agents.conf` + `scripts/cycle-state.json` (add this file to `auto-agent.sh`)
- Character assignment at startup from `agents.conf`
- WebSocket event schema extended with `orchystraw_cycle_start`, `orchystraw_agent_phase`, `orchystraw_pm_visiting`

This is **the Agent Factory visualization layer**, basically ready to be wrapped in Tauri.

---

## Recommended Path

| Approach | Effort | Ships When | What You Get |
|----------|--------|-----------|-------------|
| **1. Synthetic JSONL** | ~2 hours (bash) | This week | Characters appear and animate during cycles, works with existing standalone |
| **2. Status file + shim** | ~1 day (bash + Node.js) | Next week | Role labels, precise animations, speech bubbles with task names |
| **3. Fork + adapter** | ~3-5 days | Month 1 | Full cycle visualization, PM walking between desks, this IS Agent Factory's UI |

**Start with Approach 1.** It requires only bash changes to `auto-agent.sh` and zero changes to Pixel Agents. You get the "living office" experience immediately. Document it in Orchystraw's README as an optional integration.

Then if it resonates with the community (and it will — this is exactly what people want to see), build Approach 3 as the centerpiece of the Agent Factory product.

---

## JSONL Format Reference

Based on Pixel Agents source — the events it detects:

```json
// Agent typing / writing code
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"write_file","input":{"path":"src/api.py","content":"..."}}]}}

// Agent reading a file
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"read_file","input":{"path":"README.md"}}]}}

// Agent running bash
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"bash","input":{"command":"pytest tests/"}}]}}

// Agent waiting for permission (speech bubble in pixel art)
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I need permission to..."}]},"waiting_for_permission":true}

// Turn end (agent goes idle / walks to idle spot)  
{"type":"result","subtype":"success","result":"...","session_id":"..."}
```

---

## GitHub Discussion Opportunity

Opening an issue / discussion on `pablodelucca/pixel-agents` proposing:
> "Orchystraw integration — headless multi-agent orchestration that emits JSONL events for Pixel Agents visualization"

This gets:
- Backlink from Pixel Agents (1.2K upvotes on Reddit, active community)  
- Author's feedback on the JSONL schema (avoid guessing)
- Potential upstream PR for an "orchestration mode" in Pixel Agents itself
- Cross-promotion: Pixel Agents users discover Orchystraw, Orchystraw users discover Pixel Agents

Both projects win.

---

## Notes for Agent Factory

When Agent Factory ships as a Tauri app, Approach 3 becomes its embedded visualization:
- No browser needed — Tauri renders the webview natively
- Characters = actual agents the user has spawned (not watched via JSONL)
- Desk = project (drag agent to desk = assign to project)
- This is exactly the "managing agents feels like playing the Sims" vision from Pixel Agents' README

The author literally wrote: *"The long-term vision is an interface where managing AI agents feels like playing the Sims, but the results are real things built."* — that's Agent Factory's pitch word for word. Reach out to Pablo.
