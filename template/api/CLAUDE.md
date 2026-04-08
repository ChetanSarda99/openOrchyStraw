# {{PROJECT_NAME}} — Development Guide

## Project Overview
{{PROJECT_NAME}} is an API/backend service managed by OrchyStraw multi-agent orchestration.
Focused on backend API development with strong quality, security, and operational practices.
No frontend — this is a pure API service.

## Agent Team

| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 02-cto | CTO | docs/architecture/ | 2 | Architecture, API design, data model, standards |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Coordination, loop-closing, runs LAST each cycle |
| 06-backend | Backend | src/ lib/ api/ | 1 | Endpoints, business logic, database, middleware |
| 09-qa | QA | tests/ reports/ | 3 | API testing, code review, bug reports |
| 10-security | Security | reports/security/ | 5 | Security audits (read-only) |

## File Structure
```
agents.conf              — Agent configuration
CLAUDE.md                — This file (project guide for all agents)
prompts/                 — All agent prompts and shared context
  00-shared-context/     — Cross-agent communication (reset each cycle)
  02-cto/ .. 10-security/ — Individual agent prompts
  99-me/                 — Human action items (escalations)
src/                     — Source code
  services/              — Business logic layer
  models/                — Data models
  repositories/          — Data access layer
  middleware/            — Auth, logging, rate limiting, error handling
lib/                     — Shared utilities
api/                     — API route definitions
tests/                   — Test files (unit, integration, contract)
docs/                    — Documentation
  architecture/          — ADRs, API design, data model, performance targets, code standards
reports/                 — QA bug reports
  security/              — Security audit findings
```

## Quality Pipeline

Every significant feature follows this research-first workflow:
1. **Research** — Research online best practices BEFORE implementing. Do NOT use stale AI knowledge. Use WebSearch/WebFetch for current approaches.
2. **Design** — CTO writes ADRs and API specs. Backend implements from specs.
3. **Implement** — Build endpoints, services, and data access per CTO's design.
4. **Test** — Write tests (unit + integration + contract). Run the suite. No merging with failures.
5. **QA Review** — 09-qa tests all endpoints, reviews code, checks contract compliance.
6. **Security Review** — 10-security audits for OWASP Top 10, auth, injection, secrets, dependencies.

## Shared Reference Documents

All agents must check these before making decisions in their domain:

| Document | Path | Used By |
|----------|------|---------|
| Best Practices | `~/Projects/shared/docs/BEST-PRACTICES-2026.md` | All agents |

## API Quality Standards

- Every endpoint has input validation, auth checks, proper HTTP status codes, and tests
- Error responses follow CTO's documented format consistently
- Database queries use parameterized statements only (never string concatenation)
- No hardcoded secrets — environment variables or config files
- All errors caught, logged with correlation IDs, and surfaced to caller
- OpenAPI/Swagger spec maintained and current
- Performance within CTO-defined latency targets

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
