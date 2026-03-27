# Market Research — OrchyStraw
**Last Updated:** March 16, 2026  
**Author:** CS + Chai

---

## Market Context

The AI-assisted software development market is large and growing fast ($25.9B in 2024, projected $97.9B by 2030, 24.8% CAGR). But the tooling is fragmented:

- **Code generators** build once (Lovable, Bolt, Base44)
- **Solo agents** try to do everything (Devin, Manus, OpenDevin)
- **Frameworks** require developers to build their own orchestration (CrewAI, AutoGen, LangGraph)
- **Copilots** amplify humans (Cursor, Windsurf, GitHub Copilot)

**No one has a zero-dependency, drop-in coordination layer for the coding tools developers already use.**

---

## Target User

**Primary:** Solo developer or small team already using Claude Code, Windsurf, Cursor, or Codex.

They've tried running two agents on the same codebase. It's a mess. They want specialization (backend agent, frontend agent, QA agent) but don't want to install a framework or write orchestration code.

**Secondary:** Developer who has heard of multi-agent systems (CrewAI, AutoGen) but bounced because of setup complexity.

**Not:** Enterprise DevOps teams (they have Factory.ai). Pure non-technical users (they have Lovable).

---

## Pain Points Orchystraw Solves

1. **Agent collisions** — Two agents editing the same files → overwrites, merge conflicts
2. **Context loss** — Each agent session starts fresh, losing what happened last cycle
3. **No specialization** — One agent doing backend + frontend + tests = context overload = worse results
4. **Framework fatigue** — "I just want agents to work on my project, not spend a day installing things"
5. **Lock-in** — CrewAI locks you to Python. AutoGen locks you to its runtime. Orchystraw works with whatever you already have.

---

## Competitive Moat

Orchystraw's moat is **convention adoption** + **ecosystem compatibility**:

- Once a team adopts the prompt structure (00-shared-context, 01-pm, 02-backend...), switching costs are real
- Works with EVERY AI coding tool → no risk of "my tool isn't supported"
- Open source → community contributions make it more powerful over time
- First mover on zero-dependency multi-agent coordination for coding tools

---

## Comparable Open Source Trajectories

| Project | Stars at 6 months | What it did |
|---------|------------------|-------------|
| AutoGen | ~30K | Microsoft backing, heavy marketing |
| CrewAI | ~20K | Strong HN post, developer community |
| LangChain | ~50K | First mover on LLM tooling, massive docs |
| **Orchystraw target** | **1-5K** | Niche but loyal: Claude Code + Windsurf users |

Orchystraw doesn't need 50K stars. It needs 500 developers who use it on every project.

---

## Key Risks

1. **Obscurity** — Main risk. Zero distribution without active community posting.
2. **Framework eats the market** — CrewAI adds a zero-config mode. Unlikely given their enterprise direction.
3. **Coding tools add native multi-agent** — Windsurf or Cursor builds this in natively. Possible in 12-18 months. Orchystraw's answer: still useful as the coordination layer above any tool.
4. **Bash script friction** — Some developers on Windows (CS is on WSL) may struggle with bash. Mitigation: document WSL setup, consider PowerShell wrapper later.

---

## Opportunity Size

Not trying to be a $1B company. Orchystraw's goal:

- **GitHub presence** that builds credibility for Agent Factory
- **Community of 1-5K active users** who trust the approach
- **Foundation for the paid product** (Agent Factory) — users who already use Orchystraw are warm leads for the Tauri app with visualization + company lifecycle + cost tracking

Even without monetization, Orchystraw is worth building as the open-source credibility layer.
