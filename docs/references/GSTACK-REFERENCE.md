# Garry Tan's gstack — Reference

**Source:** https://github.com/garrytan/gstack (68K+ stars)
**Author:** Garry Tan, Y Combinator President & CEO

## What It Is
23 opinionated Claude Code skills that act as a virtual engineering team:
CEO, Designer, Eng Manager, Release Manager, Doc Engineer, QA, CSO.

## Workflow: Think → Plan → Build → Review → Test → Ship → Reflect

## Key Skills (mapped to OrchyStraw agents)

| gstack Skill | Purpose | OrchyStraw Agent |
|---|---|---|
| `/office-hours` | Product interrogation, forcing questions | 01-ceo |
| `/plan-ceo-review` | Strategic scope review | 01-ceo |
| `/plan-eng-review` | Architecture lock-in + diagrams | 02-cto |
| `/plan-design-review` | Design audit with 0-10 ratings | 12-designer |
| `/review` | Staff-engineer code review | 09-qa-code |
| `/cso` | OWASP + STRIDE security audit | 10-security |
| `/qa` | Real browser testing + regression | 09-qa-visual |
| `/ship` | Sync, test, audit, PR automation | 03-pm |
| `/investigate` | Root-cause debugging | 06-backend |
| `/retro` | Weekly retrospective with metrics | 00-cofounder |
| `/benchmark` | Performance + Core Web Vitals | benchmarks/ |
| `/browse` | Real Chromium browser (100ms latency) | Chrome DevTools MCP |

## What OrchyStraw Can Learn
1. **Structured decision roles** — each agent embodies specific expertise, not generic
2. **Accept/reject gates** — CEO challenges scope, engineer locks architecture
3. **Real browser testing** — QA uses actual browser, not just code audit
4. **Ship workflow** — automated sync → test → audit → PR → deploy → canary
5. **Retrospectives** — per-agent metrics, weekly review cycle

## What OrchyStraw Does Differently
- **Multi-project** — gstack is single-project; orchystraw runs 8 projects
- **Autonomous cycles** — gstack is command-driven; orchystraw auto-cycles
- **Budget-aware** — model selection + cost tracking built in
- **No framework** — pure bash + markdown; gstack needs Claude Code skills system
