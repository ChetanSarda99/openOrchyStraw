# OrchyStraw (Private)

Private development repo for OrchyStraw — multi-agent AI coding orchestration.

This repo dogfoods OrchyStraw to develop OrchyStraw. 10 AI agents coordinate via the same markdown prompt + bash script system we're building.

## Agent Team

| # | Agent | Cycle | What They Do |
|---|-------|-------|-------------|
| 01 | CEO | 3rd | Vision, strategy, open-source vs proprietary decisions |
| 02 | CTO | 2nd | Architecture, tech standards, dependency governance |
| 03 | PM | Last | Coordination, task assignment, prioritized issue backlog |
| 04 | Tauri Rust | 1st | Desktop app backend — IPC commands, state, SQLite |
| 05 | Tauri UI | 1st | Desktop app frontend — React + Tailwind dashboard |
| 06 | Backend | 1st | Core orchestrator engine (auto-agent.sh), scripts |
| 07 | iOS | 1st | Mobile companion app (SwiftUI) |
| 08 | Pixel Agents | 2nd | Pixel art visualization of agents at work |
| 09 | QA | 3rd | Testing, code review, quality gates |
| 10 | Security | 3rd | Threat modeling, secret scanning (read-only) |

## Products Being Built

### Core Orchestrator (v0.1.0 — in progress)
The bash script that reads `agents.conf`, spawns AI agents, manages cycles, and coordinates via shared context. Hardening: error handling, signal trapping, config validation, lock files, logging.

### Tauri Desktop App (v0.2.0 — planned)
Cross-platform desktop GUI for OrchyStraw. Dashboard showing agent status, cycle management, log viewer, agents.conf visual editor. Tauri 2.0 (Rust backend + React frontend).

### Pixel Agents Integration (v0.2.0 — planned)
Pixel art office visualization showing agents coding, reading, talking. Adapted from [pixel-agents-standalone](https://github.com/rolandal/pixel-agents-standalone). Synthetic JSONL emitter in auto-agent.sh feeds real-time events. Embedded in Tauri dashboard.

### iOS Companion (future)
Native mobile app for monitoring cycles and getting push notifications.

## Repo Structure

```
agents.conf          — 10-agent configuration
CLAUDE.md            — Project guide for all agents
prompts/             — Agent prompts + shared context
scripts/             — Orchestrator (auto-agent.sh) + helpers
src-tauri/           — Tauri Rust backend
src/                 — Tauri React frontend
src/pixel/           — Pixel Agents OrchyStraw adapter
ios/                 — iOS companion app
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

- **v0.1.0** — Orchestrator hardening (13 issues, 8 backend + QA + security + release)
- **v0.2.0** — Pixel Agents + Tauri desktop MVP (8 issues)
- **v0.3.0** — Benchmarks (SWE-bench, Ralph, FeatureBench)
- **v1.0.0** — Public launch + distribution
