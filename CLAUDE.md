# OrchyStraw — Development Guide

## Project Overview
Multi-agent AI coding orchestration. Markdown prompts + bash script. No framework, no dependencies.

**Private repo** — research, benchmarks, proprietary features, Tauri desktop app, Pixel Agents integration.
**Public repo** — openOrchyStraw (MIT, community-facing scaffold).

## Agent Team

### Active Agents (9 — configured in agents.conf)
| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 01-ceo | CEO | docs/strategy/ | 3 | Vision & market direction |
| 02-cto | CTO | docs/architecture/ | 2 | Architecture & standards |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Coordination, runs LAST each cycle |
| 06-backend | Backend | scripts/ src/core/ | 1 | Core orchestrator engine |
| 08-pixel | Pixel Agents | src/pixel/ | 2 | Visual agent visualization layer |
| 09-qa | QA | tests/ | 3 | Testing & quality gates |
| 10-security | Security | (read-only) | 5 | Security audits |
| 11-web | Web Dev | site/ | 1 | Landing page + docs site |
| 13-hr | HR | docs/team/ prompts/13-hr/ | 3 | Team health & composition |

### Future Agents (prompts exist, not yet activated)
- **04-Tauri-Rust** — Desktop app Rust backend (activate when Tauri work starts)
- **05-Tauri-UI** — Desktop app React frontend (activate when Tauri work starts)
- **07-iOS** — Native mobile companion app (activate when iOS work starts)

## File Structure
```
agents.conf              — Agent configuration (who, what, when)
CLAUDE.md                — This file (project guide for all agents)

prompts/                 — All agent prompts and shared files
  00-shared-context/     — Cross-agent communication (reset each cycle)
  00-session-tracker/    — Cycle history
  00-backup/             — Context backups (gitignored)
  01-ceo/ → 13-hr/       — Individual agent prompts
  99-me/                 — Human action items

scripts/                 — Orchestrator (auto-agent.sh) + helper scripts
src/core/                — Core orchestration modules (24 bash modules)
src/pixel/               — Pixel Agents JSONL emitter + integration

site/                    — Landing page (Next.js 15 + shadcn/ui v4)
  src/                   — Pages, components, layouts
  out/                   — Static build output (deployed to GitHub Pages)

tests/                   — Test files
  core/                  — 26 test scripts + runner

docs/                    — Documentation
  architecture/          — ADRs and technical specs (14 files)
  strategy/              — CEO strategic memos (9 files)
  team/                  — Team norms, onboarding, roster
  references/            — Locked stack decisions (Tauri, landing page, docs)
  tech-registry/         — Technology decision records

research/                — Competitive analysis, benchmarks
template/                — Agent prompt templates for new projects
examples/                — Sample agents.conf
```

## Current Status

### v0.1.0 — Hardened Release (DONE — ready to tag)
All 8 core modules built, tested, integrated. QA PASS. Security FULL PASS. CTO approved.

### v0.2.0 — Smart Cycle System (FULLY WIRED)
10 modules wired into auto-agent.sh. CTO 8/8, QA 8/8, Security 6/6.
26/26 test scripts pass. Ready to tag.

### v0.3.0 — Extended Modules (IN PROGRESS)
5 modules built and wired: single-agent, qmd-refresher, prompt-template, task-decomposer, init-project.
1 module (freshness-detector) built but not yet wired.

### Next Up
1. Tag v0.1.0 + v0.2.0
2. Wire freshness-detector + token optimization (#50, #53, #54)
3. Pixel Agents integration
4. Tauri desktop app
5. Benchmarks & distribution

## Stack Reference Docs (LOCKED — read before building)

| Surface | Reference Doc | Agents |
|---------|--------------|--------|
| Tauri Desktop App | `docs/references/TAURI-STACK.md` | 04-tauri-rust, 05-tauri-ui |
| Landing Page | `docs/references/LANDING-PAGE-STACK.md` | 11-web |
| Documentation Site | `docs/references/DOCS-STACK.md` | 11-web |

### Summary
- **Tauri app:** dannysmith/tauri-template → React 19 + shadcn/ui v4 + Zustand + TanStack Query + tauri-specta
- **Landing page:** memextech/nextjs-shadcn-landing-page-template → Next.js 15 + shadcn/ui v4 + Framer Motion
- **Docs site:** Mintlify (same as Claude Code docs + Conductor docs)
- **Shared:** shadcn/ui v4, Tailwind v4, Lucide React, JetBrains Mono, Inter/Geist, dark mode (#0a0a0a)

## Rules
1. **Read your prompt first** — it has your current tasks
2. **Read your reference doc** — locked stack decisions per surface
3. **Stay in your lane** — respect file ownership in agents.conf
4. **Write to shared context** — that's how agents communicate
5. **Never touch git branch operations** — orchestrator handles that
6. **No external dependencies** — bash + markdown for core orchestrator
7. **Use Edit, not Write** — for prompt updates (preserve structure)
8. **Check the PM's prioritized backlog** — prompts/03-pm/03-pm.txt has the full ordered issue list

## Shared Resources
- **Image Generation:** `~/Projects/shared/scripts/generate-image.sh` — AI image gen (Gemini free / OpenAI DALL-E)
- **Batch Images:** `~/Projects/shared/scripts/batch-generate-images.sh` — Batch image gen from prompt files
- **Telegram:** `~/Projects/shared/scripts/send-telegram.sh` — Send messages via Bot API
- **OrchyStraw Core:** `~/Projects/shared/orchystraw-core/` — Reusable orchestration modules (logger, error handler, cycle state, timeouts, lock file, config validator, signal handler, dry-run, cycle tracker, bash version gate)
- **OrchyStraw Templates:** `~/Projects/shared/orchystraw-templates/` — Agent design reference, anti-patterns, knowledge repos, sample agents.conf
- **Synced State:** `~/Projects/shared/shared-state/` — Cross-project health, alerts, API usage
