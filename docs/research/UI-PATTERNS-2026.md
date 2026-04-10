# UI Patterns for Multi-Agent Tools — 2026 Research

Research notes on how leading AI agent products visualize multi-agent workflows.

## Tools surveyed

| Tool | Source | Notes |
|------|--------|-------|
| Conductor.build | conductor.build | Multi-agent code review dashboard |
| Perplexity Comet | perplexity.ai/comet | Agentic browser |
| Parallel.ai | parallel.ai | Deep research, dataset enrichment |
| Devin | devin.ai | Autonomous coder, Linear/Slack integration |
| Cursor Composer | cursor.sh | Inline agent in editor |
| Manus | manus.im | Autonomous agent platform |

## Common patterns extracted

### 1. Hub-and-spoke layout
Several tools center a "coordinator" or main task and arrange sub-agents/sub-tasks around it. We adopted this in `app/src/components/dashboard/AgentFlow.tsx`.

### 2. Status pulse animations
A working agent typically has a pulsing ring/glow in its color. We use this in PixelAgents.tsx and AgentFlow.tsx (SVG `<animate>` for the glow).

### 3. Real-time activity feed
A scrolling log of "what just happened" — agent X read file Y, agent Z wrote test W. We have this in PixelAgents (Live Activity row format).

### 4. Project switcher in sidebar
All multi-project tools put a project dropdown at the top of the sidebar. We do this.

### 5. Locked color palette per role
Conductor and similar tools assign each agent role a distinct color used across the UI. We locked our palette in AgentFlow.tsx (cofounder=#f97316, CTO=#06b6d4, etc.).

### 6. Hover for agent metadata
Hover over an agent node = tooltip with ID, current tool, last action. We have this.

### 7. Side-by-side detail panel
Click an agent (or issue, log, etc.) → opens a right-side panel with full details, leaving the list visible. We have this in IssuesView.

### 8. SVG for diagrams (no D3)
Modern dashboards use raw SVG with React for graph visualizations — D3 is overkill. We do this.

### 9. Cost / token tracker
Most production tools show cost prominently. **Missing in our app — should add to Header.**

### 10. Pause/resume per task
Conductor lets you pause individual agents mid-cycle. **Missing in our app — we only have stop-all and stop-by-project.**

### 11. Activity timeline (scrubbing)
Some tools show a horizontal timeline of agent activity over time you can scrub. **Missing in our app — would be a great Logs page enhancement.**

### 12. Diff preview before merge
Conductor shows the diff each agent produced, with approve/reject buttons. **Missing in our app — would tie into the existing `--review` flag.**

## Anti-patterns to avoid

- **Loading spinners** — use skeleton states / "in progress" indicators
- **Modal overlays for primary actions** — use side panels or dedicated pages
- **Marketing fluff in product UI** — just show data
- **Generic "AI" branding** — use specific role names
- **Forced light mode** — dev tools should default dark

## Recommendations for orchystraw

**Already done (this session):**
- Hub-and-spoke flow diagram (#249)
- Real-time activity feed (PixelAgents)
- Locked color palette
- Hover tooltips on agent nodes
- Side-by-side issue detail panel (#248)

**Should add next:**
1. **Cost/token tracker in Header** — show daily spend
2. **Pause individual agent** — extend stop API to per-agent
3. **Activity timeline scrubber** — horizontal time view on Logs page
4. **Inline diff preview** — show what each agent wrote before merge
5. **Cycle history graph** — sparkline of recent cycle outcomes

**Don't copy:**
- Devin's "autonomous mode" UI — too opaque, users want to see what's happening
- Parallel's table-only views — not enough visualization
- Conductor's "isolated workspace per agent" — we use git worktrees instead
