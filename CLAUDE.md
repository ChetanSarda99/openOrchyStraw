# OrchyStraw — Development Guide

## Project Overview
Multi-agent AI coding orchestration. Markdown prompts + bash script. No framework, no dependencies.

**Private repo** — research, benchmarks, proprietary features, and self-development (dogfooding).
**Public repo** — openOrchyStraw (MIT, community-facing).

## Agent Team
8 agents configured in `agents.conf`:
- **01-CEO** — Vision, strategy, market positioning (every 3rd cycle)
- **02-CTO** — Architecture, tech standards, code quality (every 2nd cycle)
- **03-PM** — Coordination, task assignment, milestone tracking (runs LAST)
- **04-Frontend** — Web UI, visualization, Pixel Agents (every cycle)
- **05-Backend** — Core orchestrator, scripts, APIs (every cycle)
- **06-iOS** — Native mobile companion app (every cycle)
- **07-QA** — Testing, code review, quality gates (every 3rd cycle)
- **08-Security** — Threat modeling, vulnerability scanning (every 3rd cycle, read-only)

## File Structure
```
agents.conf              — Agent configuration (who, what, when)
prompts/                 — All agent prompts and shared files
  00-shared-context/     — Cross-agent communication (reset each cycle)
  00-session-tracker/    — Cycle history
  00-backup/             — Context backups
  01-ceo/ through 08-security/  — Individual agent prompts
  99-me/                 — Human action items
src/                     — Source code (when it exists)
  core/                  — Orchestrator logic
  api/                   — Server/API layer
  web/                   — Frontend dashboard
  components/            — Shared UI components
  lib/                   — Shared utilities
  native/                — Shared native code
ios/                     — iOS app (Xcode project)
scripts/                 — Helper scripts, tooling
tests/                   — Test files
docs/                    — Documentation
  strategy/              — CEO strategic docs
  architecture/          — CTO technical specs
research/                — Competitive analysis, benchmarks
```

## Rules
1. **Read your prompt first** — it has your current tasks
2. **Stay in your lane** — respect file ownership in agents.conf
3. **Write to shared context** — that's how agents communicate
4. **Never touch git branch operations** — orchestrator handles that
5. **No external dependencies** — bash + markdown for core
6. **Use Edit, not Write** — for prompt updates (preserve structure)

## Current Milestone: v0.1.0 (Hardening)
Focus: orchestrator reliability, docs accuracy, security audit, QA pass.
No new features — just make what exists bulletproof.
