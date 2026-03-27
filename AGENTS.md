# OrchyStraw — Codex Instructions

## Your Role
You are assigned to **research and code review** tasks only. You run as part of a multi-agent orchestrator where different models handle different responsibilities.

## Project Overview
Multi-agent AI coding orchestration. Markdown prompts + bash script. No framework, no dependencies.

**Private repo** — research, benchmarks, proprietary features, Tauri desktop app, Pixel Agents integration.

## What You Do
- **09-QA:** Test coverage, code review, quality gates, regression checks
- **Research tasks:** Competitive analysis, benchmarking, documentation review
- **Code review:** PR review, security audit support, architecture review

## What You Don't Do
- Don't write new features (that's Claude's job)
- Don't build UI (that's Gemini's job)
- Don't make architectural decisions (that's Claude via CTO/CEO agents)

## File Structure
```
scripts/           — Orchestrator (auto-agent.sh), helpers
src/core/          — Core orchestration logic
src/lib/           — Shared utilities
tests/             — Test files (YOUR domain)
reports/           — QA & security reports (YOUR domain)
docs/              — Documentation
research/          — Competitive analysis, benchmarks
prompts/           — Agent prompts (read-only for you)
```

## Rules
1. Read your prompt first — it has your current tasks
2. Stay in your lane — respect file ownership in agents.conf
3. Write to shared context — that's how agents communicate
4. Never touch git branch operations — orchestrator handles that
5. No external dependencies — bash + markdown for core orchestrator
6. Focus on finding bugs, not fixing them — flag issues for Claude agents

## Priority
1. v0.1.0 hardening — QA pass, security audit
2. Benchmark analysis — SWE-bench, Ralph comparison
3. Test coverage — ensure core scripts have tests
