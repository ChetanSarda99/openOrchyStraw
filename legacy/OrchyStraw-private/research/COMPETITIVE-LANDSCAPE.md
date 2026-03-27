# Competitive Landscape — OrchyStraw
**Last Updated:** March 16, 2026  
**Author:** CS + Chai

---

## The One-Line Position

**CrewAI and AutoGen are frameworks. Orchystraw is a convention. No install. No dependencies. Works with tools you already have.**

---

## Tools CS Evaluated (March 16, 2026)

| Tool | What it is | Competes with Orchystraw? | Why Not |
|------|-----------|--------------------------|---------|
| **AutoGen Studio** (Microsoft) | Visual drag-and-drop multi-agent builder. Requires Python, setup, config. | ❌ | Framework with infra — you build a system *on top of* it |
| **Manus / OpenManus-RL** | Autonomous web-browsing agent (went viral). RL-based, cloud infra required. | ❌ | Single autonomous agent, not coordination |
| **Claude computer-use demo** | Anthropic's computer control via screenshots. Research-grade. | ❌ | Capability demo, not a coordination system |
| **Crawl4AI** | Web scraping library for AI pipelines | ❌ | Completely different space |
| **Devin** | Autonomous AI engineer, $500/mo, 85% real-world fail rate | ❌ | Solo agent — different problem |
| **OpenDevin** | Open-source Devin clone. Research-grade, single agent. | ❌ | Same as Devin — one giant context-overloaded agent |
| **Factory.ai** | Enterprise "droids" for dev tasks. $50M funded, enterprise-only. | ❌ | Different tier, different buyer |
| **CrewAI** | Python framework for multi-agent pipelines. Requires coding to use. | Closest | Still a framework — developer hours barrier |
| **Greptile** | AI code understanding / codebase Q&A | ❌ | Not orchestration |

---

## The Real Gap

### What frameworks require (AutoGen / CrewAI / LangGraph)
- Python install + package management
- Writing orchestration code
- Often: configuration files, API wrappers, custom agents
- Learning a new paradigm before writing a single line of product code

### What single agents fail at (Devin / Manus / OpenDevin)
- One agent trying to hold an entire codebase in context → overload → hallucinations
- No specialization (the same brain writes backend, frontend, tests, docs)
- 85% real-world fail rate (Devin) precisely because one context window is never enough

### What existing coding tools lack (Cursor / Windsurf / Claude Code)
- Brilliant individually, but single-session, single-agent
- No mechanism to coordinate across agents
- No shared memory between agents
- No file ownership enforcement

### What Orchystraw does that nothing else does
You already have Claude Code. You already have Windsurf. You don't need to install a framework, write Python, configure agents.json, or learn a new paradigm.

**You copy a folder. Fill in markdown prompts (same as you already write for any AI chat). Run one bash script.**

Multiple specialized agents. Coordinating on your codebase. Right now.

---

## Why CrewAI Is the Closest (And Still Not Competition)

CrewAI is the most similar product in intent. But:

| | CrewAI | Orchystraw |
|--|--------|-----------|
| Setup | `pip install crewai`, write Python | Copy a folder |
| Agent definition | Python class with role/goal/backstory | Markdown file |
| Coordination | Python orchestration code | Shared context file (markdown) |
| Works with Windsurf? | No | Yes |
| Works with Claude Code? | No | Yes |
| Dependencies | Python + crewai + provider SDKs | bash |
| Target user | Developer building an agent system | Developer who wants agents on their project NOW |

Orchystraw is a **convention**, not a framework. The difference: a convention requires no adoption ceremony. You read the prompts, you understand it immediately, you modify it immediately.

---

## Positioning Statement (Draft)

> "If you've ever tried to get two AI agents working on the same codebase, you know the mess — they overwrite each other's files, lose context between sessions, and forget what they were doing.
>
> OrchyStraw fixes that. It's a set of markdown files and one bash script. No framework to install, no Python package, no runtime. You copy a folder into your project and you're up and running.
>
> Works with Claude Code, Windsurf, Cursor, Codex, Gemini CLI, Aider — anything that takes a prompt."

---

## Go-to-Market Priority (March 2026)

1. **GitHub discoverability** — Add topics: `multi-agent`, `llm-orchestration`, `claude-code`, `codex`, `ai-agents`, `zero-dependencies`, `windsurf`, `cursor`
2. **Demo GIF** — 1 command → 3 agents → actual code being produced. Table stakes.
3. **Claude Code Discord** — Post in the community. They're the most active agent users right now.
4. **Windsurf community** — Second target. They know multi-agent pain.
5. **Hacker News** — "Show HN: Multi-agent coordination for your existing AI coding tools — no framework, just markdown + bash"

---

## The Bigger Picture

Orchystraw is the open-source foundation. Agent Factory (the full Tauri app with visualization, company lifecycle, agent hiring/firing) builds on top of Orchystraw's coordination model once there's an audience.

**Orchystraw = low effort, community-building, genuine differentiation.**  
**Agent Factory = high effort, builds on Orchystraw's proven audience.**

The risk isn't competition. It's obscurity. Ship it, then distribute it.
