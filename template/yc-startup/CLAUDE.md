# {{PROJECT_NAME}} — Development Guide

## Project Overview
{{PROJECT_NAME}} is an early-stage startup project managed by OrchyStraw multi-agent orchestration.
Lean team, fast iteration, ship-first mentality. Markdown prompts + bash script. No framework dependencies for orchestration.

## Agent Team

| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 00-founder | Founder | agents.conf docs/ | 0 (last) | Strategy, ops, coordination — runs LAST each cycle |
| 01-engineer | Full-Stack Engineer | src/ scripts/ tests/ lib/ api/ | 1 | Ships everything — backend, frontend, infra |
| 02-designer | Product Designer | site/ assets/ styles/ | 2 | UI/UX, brand, visual assets |
| 03-qa | QA Engineer | tests/ reports/ | 3 | Testing, code review, bug reports |
| 04-researcher | Auto Researcher | research/ | 5 | GitHub intelligence, competitive analysis, pattern discovery |

## File Structure
```
agents.conf              — Agent configuration
CLAUDE.md                — This file (project guide for all agents)
research-sources.conf    — GitHub sources for auto-researcher
prompts/                 — All agent prompts and shared context
  00-shared-context/     — Cross-agent communication (reset each cycle)
  00-founder/            — Founder prompt
  01-engineer/           — Engineer prompt
  02-designer/           — Designer prompt
  03-qa/                 — QA prompt
  04-researcher/         — Researcher prompt
  99-me/                 — Human action items (escalations)
src/                     — Application source code
scripts/                 — Build and automation scripts
lib/                     — Shared utilities
api/                     — API definitions
site/                    — Marketing site / landing page
assets/                  — Brand assets, images, icons
styles/                  — Design tokens, stylesheets
tests/                   — Test files
reports/                 — QA reports, audit findings
research/                — Research briefs and competitive intelligence
  briefs/                — Auto-generated research briefs
docs/                    — Documentation
```

## Quality Pipeline

1. **Research** — Check current best practices before building. Use the auto-researcher's briefs.
2. **Build** — Ship fast, but with tests. Engineer owns the full stack.
3. **Test** — QA reviews every cycle. Fix P0/P1 before new features.
4. **Iterate** — Founder sets priorities. Designer refines UX. Ship again.

## Shared Reference Documents

| Document | Path | Used By |
|----------|------|---------|
| Best Practices | `~/Projects/shared/docs/BEST-PRACTICES-2026.md` | All agents |
| Landing Page Design | `~/Projects/shared/docs/LANDING-PAGE-DESIGN-GUIDE-2026.md` | Designer |

## Rules

1. **Read your prompt first** — it has your current tasks and role boundaries
2. **Ship fast, fix fast** — early stage means velocity matters
3. **Stay in your lane** — respect file ownership in agents.conf
4. **Write to shared context** — prompts/00-shared-context/ for cross-agent communication
5. **Never touch git branch operations** — orchestrator handles that
6. **Flag blockers** — write to prompts/99-me/ for human intervention needs
7. **Research before building** — check researcher briefs and search online for current patterns
