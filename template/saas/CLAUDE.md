# {{PROJECT_NAME}} — Development Guide

## Project Overview
{{PROJECT_NAME}} is a SaaS application managed by OrchyStraw multi-agent orchestration.
Markdown prompts + bash script. No framework dependencies for orchestration.

## Agent Team

| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 01-ceo | CEO | docs/strategy/ | 3 | Vision & market direction |
| 02-cto | CTO | docs/architecture/ | 2 | Architecture & standards |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Coordination, runs LAST each cycle |
| 06-backend | Backend | src/ lib/ api/ | 1 | Core API & business logic |
| 07-frontend | Frontend | app/ components/ pages/ styles/ | 1 | UI & user experience |
| 09-qa | QA | tests/ reports/ | 3 | Testing & quality assurance |
| 10-security | Security | reports/security/ | 5 | Security audits |

## File Structure
```
agents.conf              — Agent configuration
CLAUDE.md                — This file (project guide for all agents)
prompts/                 — All agent prompts and shared context
  00-shared-context/     — Cross-agent communication (reset each cycle)
  01-ceo/ .. 10-security/ — Individual agent prompts
scripts/                 — Orchestrator scripts
src/                     — Backend source code
app/                     — Frontend application
tests/                   — Test files
docs/                    — Documentation
  architecture/          — Technical specs and ADRs
  strategy/              — Strategic direction
```

## Rules
1. **Read your prompt first** — it has your current tasks
2. **Stay in your lane** — respect file ownership in agents.conf
3. **Write to shared context** — prompts/00-shared-context/ for cross-agent communication
4. **Never touch git branch operations** — orchestrator handles that
5. **Log decisions** — document why, not just what
