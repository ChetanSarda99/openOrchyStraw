# OrchyStraw — Development Guide

## Project Overview
Multi-agent AI coding orchestration. Markdown prompts + bash script. No framework, no dependencies.

**Global CLI** — `orchystraw run <project> --cycles N` orchestrates any project from one place.
**Public repo** — openOrchyStraw (MIT, community-facing scaffold).

## Global CLI (`bin/orchystraw`)
The orchestrator is now a global tool. Install: add `~/Projects/openOrchyStraw/bin` to PATH.

```bash
orchystraw run ~/Projects/Klaro --cycles 5          # Run 5 cycles on Klaro
orchystraw run ~/Projects/AIVA --dry-run             # Preview without executing
orchystraw run . --cycles 1 --review                 # Supervised cycle (approve each commit)
orchystraw run ~/Projects/Klaro --telegram --sync-state  # With notifications + cross-project sync
orchystraw run ~/Projects/Klaro ~/Projects/AIVA --cycles 3  # Multiple projects sequentially
orchystraw run --all --cycles 1 --dry-run            # Run all registered projects
orchystraw run ~/Projects/Klaro --smart-models --budget 20  # Intelligent model selection
orchystraw add ~/Projects/Klaro ~/Projects/AIVA      # Register projects without running
orchystraw status                                     # All registered projects
orchystraw init ~/new-project --template saas         # Bootstrap new project
orchystraw list                                       # Registered projects
orchystraw metrics ~/Projects/Klaro                   # Performance data
orchystraw decisions ~/Projects/Klaro --last 10       # Decision audit trail
orchystraw dashboard                                  # Cross-project HTML dashboard
orchystraw doctor                                     # Validate environment
```

### Two-Root Architecture
- **ORCH_ROOT** = where orchystraw code lives (`~/Projects/openOrchyStraw`) — modules, templates, orchestrator
- **PROJECT_ROOT** = target project being orchestrated — agents.conf, prompts/, .orchystraw/ state

### What Each Target Project Needs (minimal)
```
project/
  agents.conf          # Who runs, what they own, intervals
  prompts/             # Agent prompt files
  CLAUDE.md            # Project context
  .orchystraw/         # Auto-created on first run (metrics, state)
```
No auto-agent.sh or src/core/ needed in target projects.

### Wired Projects
| Project | Agents | Status |
|---------|--------|--------|
| openOrchyStraw | 12 | Self-orchestrating |
| InstagramAutomation | 10 | Wired |
| Klaro | 8 | Wired |
| LinkedInAutomation | 8 | Wired |
| AIVA | 10 | Wired |
| FreelanceWorker | 7 | Wired |
| macro-news-alpha | 5 | Wired (API template) |
| Momentum | 10 | Wired (paused) |

## Agent Team

### Active Agents (12 — configured in agents.conf)
| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 00-cofounder | Co-Founder | agents.conf docs/operations/ | 2 | Autonomous ops — health, budget, intervals |
| 01-ceo | CEO | docs/strategy/ | 3 | Vision & market direction |
| 02-cto | CTO | docs/architecture/ | 2 | Architecture & standards |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Coordination + issue creation from QA findings, runs LAST each cycle |
| 06-backend | Backend | scripts/ src/core/ | 1 | Core orchestrator engine |
| 08-pixel | Pixel Agents | src/pixel/ | 2 | Visual agent visualization layer |
| 09-qa-code | QA Code Review | tests/ reports/ | 3 | Code quality, test coverage, security, functionality |
| 09-qa-visual | QA Visual Audit | reports/visual/ | 3 | Playwright/Chrome DevTools visual audit — screenshots, layout, responsiveness, accessibility |
| 10-security | Security | (read-only) | 5 | Security audits |
| 11-web | Web Dev | site/ | 1 | Landing page + docs site |
| 12-designer | Visual Designer | assets/ images/ public/images/ | 3 | Logos, icons, social graphics, carousels, thumbnails, brand assets |
| 13-hr | HR | docs/team/ prompts/13-hr/ | 3 | Team health & composition |

### Future Agents (prompts exist, not yet activated)
- **04-Tauri-Rust** — Desktop app Rust backend (scaffolded in app/src-tauri/)
- **05-Tauri-UI** — Desktop app React frontend (scaffolded in app/src/)
- **07-iOS** — Native mobile companion app (activate when iOS work starts)

## File Structure
```
bin/orchystraw           — Global CLI entry point (add to PATH)
bin/orch-context         — Context injection wrapper for Claude sessions
agents.conf              — Agent configuration (who, what, when)
CLAUDE.md                — This file (project guide for all agents)

prompts/                 — All agent prompts and shared files
  00-cofounder/          — Co-Founder agent (autonomous ops)
  00-shared-context/     — Cross-agent communication (reset each cycle)
  00-session-tracker/    — Cycle history
  00-backup/             — Context backups (gitignored)
  01-ceo/ → 13-hr/       — Individual agent prompts
  99-me/                 — Human action items

scripts/                 — Orchestrator (auto-agent.sh) + helper scripts
  auto-agent.sh          — Core orchestrator (2100+ lines)
  benchmark/             — Performance benchmarks + test cases
  cross-project-dashboard.sh — Multi-project HTML dashboard
  health-dashboard.sh    — Single-project dashboard

src/core/                — Core orchestration modules (33 bash modules)
  # v0.1 Foundation
  bash-version.sh, logger.sh, error-handler.sh, cycle-state.sh,
  agent-timeout.sh, dry-run.sh, config-validator.sh, lock-file.sh
  # v0.2 Smart Cycle
  signal-handler.sh, cycle-tracker.sh, dynamic-router.sh, review-phase.sh,
  worktree.sh, prompt-compression.sh, conditional-activation.sh
  # v0.3 Extended
  single-agent.sh, qmd-refresher.sh, prompt-template.sh, task-decomposer.sh,
  init-project.sh, freshness-detector.sh
  # v0.4 Observability + Memory
  observability.sh, memory.sh, quality-gates.sh
  # v0.5 Global CLI + Quality + Model Selection
  cofounder.sh, decision-store.sh, project-registry.sh, quality-scorer.sh,
  stall-detector.sh, model-selector.sh, context-injector.sh

src/pixel/               — Pixel Agents JSONL emitter + integration

app/                     — Tauri desktop app (React 19 + Rust + shadcn/ui v4)
  src-tauri/               — Rust backend (commands, models, state, SQLite)
  src/                     — React frontend (dashboard, agents, logs, config)
site/                    — Landing page (Next.js 15 + shadcn/ui v4)
docs/                    — Documentation (architecture, strategy, operations, team, references)
research/                — Competitive analysis, benchmarks
template/                — Project templates (saas, api, content)
tests/core/              — 45+ test scripts + runner
```

## Current Status

### v0.1.0 — Core Foundation (TAGGED + RELEASED)
8 core modules. QA PASS. Security FULL PASS.

### v0.2.0 — Smart Cycle System (TAGGED + RELEASED)
15 modules wired. 58/59 tests pass on bash 5.

### v0.3.0 — Extended Modules (TAGGED + RELEASED)
21 modules. init-project, task-decomposer, prompt-template, freshness-detector.

### v0.4.0 — Observability + Memory (COMPLETE)
Observability spans/events, episodic memory, quality gates wired into orchestration loop.

### v0.5.0 — Global CLI + Desktop App (CURRENT)

**CLI (works):**
- `orchystraw run <project...> --cycles N` — run agents via Claude CLI
- `orchystraw run --all --parallel` — concurrent multi-project
- `orchystraw app` — launch web dashboard (Node server, auto-opens browser)
- `orchystraw scan` / `add` / `remove` / `list` / `status`
- `orchystraw benchmark --all` / `prompt-audit` / `doctor`
- `orchystraw update` — self-updating
- `--smart-models` + `--budget N` — model selection (Claude/OpenAI/Gemini/Ollama)
- `--auto-improve` — Karpathy-style quality-gated improvement loop
- `install.sh` — one-command install for new users

**Desktop App (app/ — works with real data):**
- Node API server reads agents.conf, registry, logs from filesystem
- Dashboard: agent grid, cycle stats, activity feed — all real data
- Agents page: full list with ownership + intervals
- Config editor: visual agents.conf editor — read/write
- Settings: model selector, API keys, Ollama URL
- Multi-project concurrent cycles via Start/Stop buttons
- Detached processes (survive tab switches)

**Not yet working in app:**
- Pixel Agents visualization (JSONL emitting works, no UI)
- Agent chat / co-founder interaction
- New project onboarding wizard
- Real-time log streaming

**Infrastructure:**
- 35 modules, 44/44 tests pass, 8 projects registered
- Portable: #!/usr/bin/env bash, works on macOS ARM/Intel + Linux
- CI: GitHub Actions (lint, test, site build, app typecheck, secrets scan)
- Security: .gitleaks.toml, pre-commit hooks, private data removed from history
- Templates: saas, api, content, yc-startup

### Open Issues
| # | Priority | What |
|---|----------|------|
| #225 | High | Pixel Agents visualization in dashboard |
| #226 | High | Agent chat / co-founder interaction UI |
| #230 | Medium | Real-time log streaming during cycles |
| #227 | Medium | New project onboarding wizard |
| #232 | Medium | Fix remaining grep -oP occurrences (macOS compat) |
| #233 | Low | check-usage.sh wastes tokens on rate limit check |
| #221 | Low | Cross-platform testing (Linux/Intel Mac) |
| #191 | Low | Record demo GIF |
| #133 | Low | Distribution launch posts |

### Next Up
1. Pixel Agents in dashboard (#225)
2. Agent chat UI (#226)
3. Real-time log streaming (#230)
4. Run real cycles on all projects
5. Move to other projects (AIVA, Klaro, etc.)

## Stack Reference Docs (LOCKED — read before building)

| Surface | Reference Doc | Agents |
|---------|--------------|--------|
| Tauri Desktop App | `docs/references/TAURI-STACK.md` | 04-tauri-rust, 05-tauri-ui |
| Landing Page | `docs/references/LANDING-PAGE-STACK.md` | 11-web |
| Documentation Site | `docs/references/DOCS-STACK.md` | 11-web |
| Design Guide | `~/Projects/shared/docs/LANDING-PAGE-DESIGN-GUIDE-2026.md` | 11-web, 12-designer, 09-qa-visual |
| Carousel Design | `~/Projects/shared/docs/CAROUSEL-DESIGN-GUIDE-2026.md` | 12-designer |
| iOS App Design | `~/Projects/shared/docs/IOS-APP-DESIGN-GUIDE-2026.md` | 12-designer, 07-ios |
| Best Practices | `~/Projects/shared/docs/BEST-PRACTICES-2026.md` | all agents |

### Summary
- **Tauri app:** dannysmith/tauri-template → React 19 + shadcn/ui v4 + Zustand + TanStack Query + tauri-specta
- **Landing page:** memextech/nextjs-shadcn-landing-page-template → Next.js 15 + shadcn/ui v4 + Framer Motion
- **Docs site:** Mintlify (same as Claude Code docs + Conductor docs)
- **Shared:** shadcn/ui v4, Tailwind v4, Lucide React, JetBrains Mono, Inter/Geist, dark mode (#0a0a0a)

## Quality Pipeline
Every significant feature follows this research-first workflow:
1. **Research** — Research online best practices BEFORE implementing. Don't use stale AI knowledge.
2. **Design** — Plan approach based on research. Reference the Landing Page Design Guide for site/ work.
3. **Implement** — Build it. No external dependencies for core (bash + markdown).
4. **Test** — Run `tests/core/run_tests.sh`. Don't merge with failing tests.
5. **QA** — 09-qa-code reviews code, 09-qa-visual reviews site.
6. **Deploy** — Tag, push, deploy site to GitHub Pages.

**References:**
- `~/Projects/shared/docs/BEST-PRACTICES-2026.md` — Domain best practices (multi-agent AI, Node.js, open source marketing)
- `~/Projects/shared/docs/LANDING-PAGE-DESIGN-GUIDE-2026.md` — UI/UX patterns for the landing page
- `~/Projects/shared/docs/IOS-APP-DESIGN-GUIDE-2026.md` — iOS SwiftUI design patterns, animations, haptics
- `~/Projects/shared/docs/VIRAL-CONTENT-STRATEGY-2026.md` — Cross-platform viral content, hooks, algorithms
- `~/Projects/shared/docs/CAROUSEL-DESIGN-GUIDE-2026.md` — Instagram/LinkedIn carousel slide design

**Claude fallback:** If primary AI call fails, try alternate model. Never let a single API failure block the pipeline.

## Rules
1. **Read your prompt first** — it has your current tasks
2. **Read your reference doc** — locked stack decisions per surface
3. **Stay in your lane** — respect file ownership in agents.conf
4. **Write to shared context** — that's how agents communicate
5. **Never touch git branch operations** — orchestrator handles that
6. **No external dependencies** — bash + markdown for core orchestrator
7. **Use Edit, not Write** — for prompt updates (preserve structure)
8. **Check the PM's prioritized backlog** — prompts/03-pm/03-pm.txt has the full ordered issue list

## Shared System (~/Projects/shared/)
Shared scripts, modules, and cross-project state. See `~/Projects/shared/CLAUDE.md` for full docs.

**Key paths:**
- **Scripts:** `~/Projects/shared/scripts/` (image gen, Telegram alerts, batch tools)
- **OrchyStraw:** `~/Projects/shared/orchystraw-core/` (orchestration modules) + `orchystraw-templates/`
- **Notion guide:** `~/Projects/shared/NOTION-GUIDE.md` (DB IDs, routing rules)
- **Infra docs:** `~/Projects/shared/infra/` (machines, network, services, API keys)

**Cross-project state** (Syncthing-synced across Asus, Lenovo, MacBook):
`~/Projects/shared/shared-state/` is a symlink → `~/Sync/shared-state/`.
- `claude-activity/` — ACTIVITY-LOG.md, PROJECT-STATUS.md, DECISIONS.md
- `memory/` — structured cross-instance memory (architecture, decisions, playbooks)
- Health, alerts, API usage JSON files

**Protocol:** Read activity log + project status at session start. Update after significant work.
