# OrchyStraw

Multi-agent AI coding orchestration — smarter than Conductor, runs anywhere.

10 AI agents coordinate via markdown prompts + bash to build software autonomously. PM auto-assigns GitHub issues, quality gates catch bugs, self-healing retries failures, model routing picks the right AI per task.

## Why OrchyStraw > Conductor

| Feature | OrchyStraw | Conductor |
|---------|-----------|-----------|
| PM auto-assigns from GitHub Issues | ✅ | ❌ Manual |
| Quality gates after each agent | ✅ | ❌ |
| Self-healing (retry on failure) | ✅ | ❌ |
| Model tiering per agent | ✅ | ❌ Same model |
| File ownership boundaries | ✅ | ❌ |
| Agent intervals (CEO 10x, backend 1x) | ✅ | ❌ All equal |
| Cross-platform (Linux/WSL/CI) | ✅ | ❌ Mac only |
| Pixel art visualization | ✅ | ❌ |

## Agent Team

| # | Agent | Interval | What They Do |
|---|-------|----------|-------------|
| 01 | CEO | 10 | Vision, strategy, open-source decisions |
| 02 | CTO | 3 | Architecture, tech standards |
| 03 | PM | Last | Auto-assigns GitHub issues, coordinates all agents |
| 06 | Backend | 1 | Core orchestrator engine (31 modules) |
| 08 | Pixel Agents | 3 | Pixel art office visualization |
| 09 | QA | 5 | Testing, code review, quality gates |
| 10 | Security | 10 | Threat modeling, audit |
| 11 | Web Dev | 1 | Landing page + docs site |
| 13 | HR | 10 | Team health, agent composition |

## Core Engine — 31 Modules, 11,776 lines

The orchestrator (`scripts/auto-agent.sh`) is backed by 31 bash modules covering:

- **Scheduling:** dynamic-router, conditional-activation, model-router, model-budget
- **Per-agent:** context-filter, prompt-compression, prompt-template, session-windower, task-decomposer, token-budget, file-access
- **Quality:** quality-gates, review-phase, self-healing
- **Infrastructure:** cycle-tracker, vcs-adapter, worktree-isolator, signal-handler, logger, error-handler
- **All tested:** 32/32 tests passing

## Products

### Core Orchestrator (v0.2.0 — active)
900-line bash orchestrator + 31 modules. Reads `agents.conf`, spawns agents in parallel, enforces file ownership, auto-commits by agent. 25 issues closed, 35 open.

### Landing Page (v0.2.0 — in progress)
Next.js site with hero terminal animation, features grid, FAQ, docs. 9 routes built.

### Tauri Desktop App (v0.3.0 — planned)
Cross-platform GUI: dashboard, diff viewer, workspace creation from issues, agents.conf editor.

### Pixel Agents (v0.2.0 — in progress)
Pixel art office showing agents coding/talking. JSONL emitter + adapter built, 27 tests passing.

### iOS Companion (future)
Mobile monitoring + push notifications.

## Repo Structure

```
agents.conf          — 11-agent configuration
CLAUDE.md            — Project guide for all agents
prompts/             — Agent prompts + shared context
scripts/             — Orchestrator (auto-agent.sh) + helpers
src-tauri/           — Tauri Rust backend
src/                 — Tauri React frontend
src/pixel/           — Pixel Agents OrchyStraw adapter
ios/                 — iOS companion app
site/                — Landing page + docs site
research/            — Competitive analysis, benchmarks
docs/                — Architecture + strategy docs
tests/               — Test files
```

## Related Repos

- **[openOrchyStraw](https://github.com/ChetanSarda99/openOrchyStraw)** — Public open-source repo (MIT). The coordination scaffold: markdown prompts + bash. Community-facing.
- **OrchyStraw (this repo)** — Private. Tauri app, Pixel Agents, benchmarks, proprietary improvements.

## Research Docs

| Doc | What It Covers |
|-----|---------------|
| `research/COMPETITIVE-LANDSCAPE.md` | Full analysis vs AutoGen, CrewAI, MetaGPT, Devin, gstack, Manus |
| `research/RALPH-LOOP-COMPARISON.md` | Head-to-head vs Geoffrey Huntley's Ralph loop |
| `research/WHY-ORCHYSTRAW-WINS.md` | Differentiation matrix + token cost strategy |
| `research/PATTERN-ANALYSIS.md` | OODA, blackboard, stigmergy, MapReduce patterns |
| `research/MARKET-RESEARCH.md` | Target user, pain points, moat, risks |
| `research/PIXEL-AGENTS-INTEGRATION.md` | Technical spec for Pixel Agents (3 approaches) |
| `research/BENCHMARKING-PLAN.md` | SWE-bench + FeatureBench + Ralph benchmark strategy |
| `research/FOUNDERS-LOG.md` | Origin, design decisions, pivot history |

## Milestones

- **v0.1.0** ✅ — Orchestrator hardening (13 closed)
- **v0.2.0** 🔄 — Module integration + landing page + pixel agents (25 closed, 35 open)
- **v0.3.0** — Tauri desktop app + benchmarks (SWE-bench, Ralph, FeatureBench)
- **v1.0.0** — Public launch + distribution
