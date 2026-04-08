# {{PROJECT_NAME}} — Development Guide

## Project Overview
{{PROJECT_NAME}} is a SaaS application managed by OrchyStraw multi-agent orchestration.
Markdown prompts + bash script. No framework dependencies for orchestration.

## Agent Team

| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 01-ceo | CEO | docs/strategy/ | 3 | Vision, market direction, competitive analysis |
| 02-cto | CTO | docs/architecture/ | 2 | Architecture, ADRs, tech stack, standards |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Coordination, loop-closing, runs LAST each cycle |
| 06-backend | Backend | src/ lib/ api/ | 1 | API, business logic, database, auth |
| 07-frontend | Frontend | app/ components/ pages/ styles/ | 1 | UI, state management, accessibility |
| 09-qa | QA | tests/ reports/ | 3 | Testing, code review, bug reports |
| 10-security | Security | reports/security/ | 5 | Security audits (read-only) |

## File Structure
```
agents.conf              — Agent configuration
CLAUDE.md                — This file (project guide for all agents)
prompts/                 — All agent prompts and shared context
  00-shared-context/     — Cross-agent communication (reset each cycle)
  01-ceo/ .. 10-security/ — Individual agent prompts
  99-me/                 — Human action items (escalations)
scripts/                 — Orchestrator scripts
src/                     — Backend source code
  services/              — Business logic layer
  models/                — Data models
  middleware/            — Auth, logging, error handling
lib/                     — Shared utilities
api/                     — API route definitions
app/                     — Frontend application
components/              — Reusable UI components
pages/                   — Page components
styles/                  — Stylesheets and design tokens
tests/                   — Test files
docs/                    — Documentation
  architecture/          — ADRs, data model, API design, code standards
  strategy/              — Vision, competitive analysis, revenue model, personas
reports/                 — QA bug reports
  security/              — Security audit findings
```

## Quality Pipeline

Every significant feature follows this research-first workflow:
1. **Research** — Research online best practices BEFORE implementing. Do NOT use stale AI knowledge. Use WebSearch/WebFetch to find current approaches.
2. **Design** — Plan approach based on research. Reference design guides for UI work. Write ADRs for architectural decisions.
3. **Implement** — Build it following CTO's standards and PM's task assignments.
4. **Test** — Write tests. Run the test suite. No merging with failing tests.
5. **QA Review** — 09-qa reviews code for bugs, edge cases, accessibility, performance.
6. **Security Review** — 10-security audits for OWASP Top 10, secrets, dependencies.

## Shared Reference Documents

All agents must check these before making decisions in their domain:

| Document | Path | Used By |
|----------|------|---------|
| Best Practices | `~/Projects/shared/docs/BEST-PRACTICES-2026.md` | All agents |
| Landing Page Design | `~/Projects/shared/docs/LANDING-PAGE-DESIGN-GUIDE-2026.md` | Frontend, QA |
| iOS App Design | `~/Projects/shared/docs/IOS-APP-DESIGN-GUIDE-2026.md` | Frontend (mobile UI) |
| Viral Content Strategy | `~/Projects/shared/docs/VIRAL-CONTENT-STRATEGY-2026.md` | CEO (market research) |

## Rules

1. **Read your prompt first** — it has your current tasks and role boundaries
2. **Research before building** — use WebSearch for current best practices, not training data
3. **Stay in your lane** — respect file ownership in agents.conf
4. **Write to shared context** — prompts/00-shared-context/ for cross-agent communication
5. **Never touch git branch operations** — orchestrator handles that
6. **Use Edit, not Write** — for prompt updates (preserve structure)
7. **Log decisions** — document why, not just what
8. **Check PM's assignments** — PM's task list is your work queue
9. **Flag blockers** — write to prompts/99-me/ for human intervention needs
10. **No silent failures** — errors must be caught, logged, and surfaced
