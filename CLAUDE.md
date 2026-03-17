# OrchyStraw — Development Guide

## Project Overview
Multi-agent AI coding orchestration. Markdown prompts + bash script. No framework, no dependencies.

**Private repo** — research, benchmarks, proprietary features, Tauri desktop app, Pixel Agents integration.
**Public repo** — openOrchyStraw (MIT, community-facing scaffold).

## Agent Team (11 agents)
- **01-CEO** — Vision, strategy, market positioning (every 3rd cycle)
- **02-CTO** — Architecture, tech standards, code quality (every 2nd cycle)
- **03-PM** — Coordination, task assignment, milestone tracking (runs LAST)
- **04-Tauri-Rust** — Desktop app Rust backend: IPC commands, state, SQLite (every cycle)
- **05-Tauri-UI** — Desktop app React frontend: dashboard, log viewer, config editor (every cycle)
- **06-Backend** — Core orchestrator scripts, engine, CLI (every cycle)
- **07-iOS** — Native mobile companion app (every cycle)
- **08-Pixel** — Pixel Agents visualization: pixel art office showing agents at work (every 2nd cycle)
- **09-QA** — Testing, code review, quality gates (every 3rd cycle)
- **10-Security** — Threat modeling, vulnerability scanning (every 3rd cycle, read-only)
- **11-Web** — Landing page + docs site, inspired by conductor.build (every 2nd cycle)

## File Structure
```
agents.conf              — Agent configuration (who, what, when)
CLAUDE.md                — This file (project guide for all agents)
prompts/                 — All agent prompts and shared files
  00-shared-context/     — Cross-agent communication (reset each cycle)
  00-session-tracker/    — Cycle history
  00-backup/             — Context backups
  01-ceo/ → 10-security/ — Individual agent prompts
  99-me/                 — Human action items

src-tauri/               — Tauri desktop app (Rust backend)
  src/                   — Rust source: commands, models, state, db
  Cargo.toml             — Rust dependencies
  tauri.conf.json        — Tauri config

src/                     — React frontend for Tauri app
  components/            — Reusable UI components
  styles/                — CSS / Tailwind
public/                  — Static assets

scripts/                 — Orchestrator script (auto-agent.sh), helpers
src/core/                — Core orchestration logic
src/lib/                 — Shared utilities

src/pixel/               — OrchyStraw-specific Pixel Agents code
pixel-agents/            — Forked pixel-agents-standalone (when created)

ios/                     — iOS companion app (Xcode project)
src/native/              — Shared native code

site/                    — Landing page + docs site
  src/                   — Pages, components, layouts
  public/                — Static assets
  content/               — Markdown docs content

tests/                   — Test files
docs/                    — Documentation
  strategy/              — CEO strategic docs
  architecture/          — CTO technical specs
research/                — Competitive analysis, benchmarks
assets/                  — Icons, branding
logs/                    — Cycle logs (gitignored)
```

## Priority Order
1. **v0.1.0** — Harden orchestrator (backend), security audit, QA pass, release tag
2. **Pixel Agents** — Synthetic JSONL emitter, fork + adapter, character mapping
3. **Tauri App** — Scaffold, Rust commands, dashboard, UI inspired by Conductor
3.5. **Landing Page** — Public site inspired by conductor.build + Claude Code docs
4. **Benchmarks** — SWE-bench, Ralph comparison, FeatureBench
5. **Distribution** — Demo GIF, launch posts, community

## Rules
1. **Read your prompt first** — it has your current tasks
2. **Stay in your lane** — respect file ownership in agents.conf
3. **Write to shared context** — that's how agents communicate
4. **Never touch git branch operations** — orchestrator handles that
5. **No external dependencies** — bash + markdown for core orchestrator
6. **Use Edit, not Write** — for prompt updates (preserve structure)
7. **Check the PM's prioritized backlog** — prompts/03-pm/03-pm.txt has the full ordered issue list
