# Founder's Log — OrchyStraw
**Last Updated:** March 16, 2026  
**Author:** CS + Chai

---

## Origin

OrchyStraw started as the scaffold layer inside **Agent Factory** — the bigger product vision (autonomous AI company, Tauri app, org hierarchy, agent lifecycle, pixel art visualization).

After evaluating the competitive landscape on March 16, 2026, the decision was made:

> **Agent Factory as a standalone product is NOT worth building yet. CrewAI and MetaGPT already occupy the multi-agent framework space. Devin has $400M. The market is crowded.**
>
> **What IS worth building: the PM-driven prompt scaffold. It's genuinely novel, battle-tested across 15+ dev cycles (Memo project, 441 source files, 1877 tests), and zero-dependency.**

**Action taken:** Extracted the scaffold into its own repo: `orchystraw`  
- Location: `~/Projects/orchystraw/`  
- GitHub: `ChetanSarda99/orchystraw`  
- License: MIT  

---

## What OrchyStraw Is

A set of markdown files and one bash script that gets multiple AI agents working together on the same codebase.

**No framework to install. No Python package. No runtime. Copy a folder. Run a script.**

Works with: Claude Code, Codex, Gemini CLI, Aider, Windsurf, Cursor — anything that takes a prompt.

---

## Key Design Decisions

### 1. File-Based Coordination (Not Message-Passing)
Agents communicate through a shared markdown file (`00-shared-context/context.md`). No vector databases, no RAG pipelines, no embeddings. Just a file agents read before starting and append to before finishing.

**Why:** Simple systems beat clever systems. Every multi-agent framework that uses message-passing adds infrastructure. Orchystraw adds a text file.

### 2. PM-Last Architecture
Worker agents run in parallel. PM agent runs last, reads shared context, and writes new standing orders into each agent's prompt file for the next cycle.

**Why:** Agents never talk to each other. Everything routes through PM. Hub not mesh. Prevents agents from overwriting instructions mid-cycle.

### 3. File Ownership Enforcement
Each agent has explicit directory ownership in `agents.conf`. The bash script detects and reverts rogue writes.

**Why:** The #1 failure mode of multi-agent coding is agents overwriting each other. Ownership rules + revert logic fix this without any coordination overhead.

### 4. Fresh Prompt Every Cycle
Each agent gets a complete, fresh prompt every cycle — not a chat thread. Instructions can't get buried 50 messages deep.

**Why:** Chat drifts. A fresh prompt means the agent always knows exactly what to do. This is the insight that makes the whole system work.

### 5. Zero Dependencies
Just bash + markdown. No Node, no Python, no package manager.

**Why:** The target user already has Claude Code or Windsurf. They don't want to install a framework to coordinate the tools they already paid for.

---

## Competitive Landscape Review (March 16, 2026)

CS evaluated these tools and asked: *"Does it make sense to do orchystraw with all these different apps?"*

Tools reviewed:
- AutoGen Studio (Microsoft) — Python framework, visual builder, requires setup
- Manus / OpenManus-RL — autonomous web agent, cloud-based, single agent
- Claude computer-use demo — Anthropic research, capability demo
- Crawl4AI — web scraping library, different space
- Devin — $500/mo solo agent, 85% fail rate, enterprise
- OpenDevin — open-source Devin, research-grade
- Factory.ai — enterprise droids, $50M funded
- CrewAI — closest competitor, but still a Python framework
- Greptile — code understanding, not orchestration

**Verdict:** None of these tools occupy Orchystraw's lane. Orchystraw is the only zero-dependency, drop-in coordination layer for AI coding tools developers already use.

Full analysis: `research/COMPETITIVE-LANDSCAPE.md`

---

## CS's Constraints

- Solo developer — mechanical engineering + data analytics background
- ADHD — needs visible progress and fast wins
- Budget: $1-5K to start
- Timeline: Aligned with Dec 16, 2026 "New Man" goal
- IDE: Windsurf
- Action over questions — just ship it

---

## Relationship to Agent Factory

Agent Factory (the bigger vision) stays alive. It becomes the **paid product** that Orchystraw's community feeds into:

```
OrchyStraw (open source, free)
  → builds credibility + community
  → proves the coordination model works
  → warm leads for Agent Factory (Tauri app, visualization, company lifecycle, $29-99/mo)
```

Agent Factory docs/research archived at: `~/Projects/agent-factory/`

---

## Next Actions

- [ ] Add GitHub topics: `multi-agent`, `llm-orchestration`, `claude-code`, `codex`, `ai-agents`, `zero-dependencies`, `windsurf`, `cursor`
- [ ] Create a demo GIF: 1 command → 3 agents → actual code produced
- [ ] Post in Claude Code Discord
- [ ] Post in Windsurf community  
- [ ] Show HN post draft: "Multi-agent coordination for your existing AI coding tools — no framework, just markdown + bash"
- [ ] Link Orchystraw repo from Agent Factory README as "the open-source foundation"
