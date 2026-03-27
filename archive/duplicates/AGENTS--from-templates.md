# [PROJECT NAME] — Codex / Agent Instructions

## Project Overview
[One paragraph: what this project is, who it's for, what problem it solves.]

## Tech Stack
- [List main stack: language, framework, DB, platform]

## Agent Team
| Agent | Role | Frequency |
|-------|------|-----------|
| CEO | Vision, strategy, market positioning | Every 3rd cycle |
| CTO | Architecture, tech standards, code quality | Every 2nd cycle |
| PM | Coordination, task assignment, milestone tracking | Every cycle (runs last) |
| iOS | Native app development | Every cycle |
| QA | Testing, code review, quality gates | Every 3rd cycle |

## File Structure
```
[Fill in key directories and what lives where]
src/
docs/
tests/
scripts/
prompts/        — Agent prompts (read-only)
```

## Your Role (when running as an agent)
- Read your specific prompt in `prompts/[your-number]/` first
- Stay in your lane — respect file ownership
- Write to shared context — that's how agents communicate
- Don't make git branch decisions — orchestrator handles that

## Rules
1. Read your prompt before acting
2. Check `prompts/00-shared-context/context.md` for latest state
3. Stay focused on your assigned tasks
4. Flag blockers clearly in shared context
5. No external dependencies without CTO sign-off

## Priority (fill in for each cycle)
1. [Current top priority]
2. [Second priority]
3. [Third priority]

---
*Adapted from OrchyStraw Strategy Vault · `templates/AGENTS.md`*
