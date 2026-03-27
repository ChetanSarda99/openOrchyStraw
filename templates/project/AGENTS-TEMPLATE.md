# AGENTS.md — [Your Project] Multi-Agent System

> Generalized template for multi-agent project setups.
> Replace `[Your App]` and role assignments with your actual project structure.

---

## System Overview

[Your App] uses a multi-agent orchestrator where different models handle different responsibilities. Each agent has a clear role, file ownership, and shared context protocol.

---

## Agent Roster

| ID | Model | Role | Interval |
|----|-------|------|----------|
| `01-pm` | Claude | Project Manager — orchestrates, assigns tasks, tracks progress | Every cycle (0) |
| `02-tech` | Claude | Tech Lead — architecture, backend, infrastructure | Every cycle |
| `03-frontend` | Claude | Frontend Dev — UI, client-side code | Every cycle |
| `04-design` | Gemini | Design System — components, styles, UX | Every 2 cycles |
| `05-qa` | Codex | QA — test coverage, code review, regression | Every 2 cycles |
| `06-[other]` | [Model] | [Role description] | Every N cycles |

---

## File Ownership

Each agent may ONLY write to their assigned paths. The orchestrator enforces this.

| Agent | May Write To | Must Not Touch |
|-------|-------------|----------------|
| `01-pm` | `prompts/`, `shared-context.md`, `docs/project/` | Everything else |
| `02-tech` | `backend/`, `infra/`, `scripts/` | `frontend/`, `prompts/` |
| `03-frontend` | `frontend/`, `ios/`, `app/` | `backend/`, `prompts/` |
| `04-design` | `frontend/styles/`, `frontend/components/` | `backend/`, `prompts/` |
| `05-qa` | `tests/`, `*.test.ts`, `*.spec.ts` | `src/` (read-only) |

---

## Shared Context Protocol

Every agent MUST:

1. **Read shared context at start** — understand what others did last cycle
2. **Do their assigned work**
3. **Append to shared context before finishing** — what was built, what's blocked, what's needed

Shared context file: `shared-context.md` (or `SHARED-CONTEXT.md`)

Format for updates:
```
## [Agent ID] — [Date]
**Built:** [what was completed]
**Blocked:** [any blockers]
**Needs from others:** [dependencies]
```

---

## Git Rules (All Agents)

- Do NOT run `git commit`, `git push`, or `git merge`
- Do NOT run `git checkout` or `git reset --hard`
- The orchestrator script handles all git operations
- Use file writes only — the orchestrator commits them

---

## Prompt Files

Each agent's full instructions live in `prompts/XX-name/XX-name.txt`.

Prompts are versioned in git. Only the PM may update prompt files.

---

## Task Assignment

The PM assigns tasks each cycle by updating the `## YOUR TASKS` section in each agent's prompt file.

Task format:
```
## YOUR TASKS
- [ ] P0: [Critical task — must complete this cycle]
- [ ] P1: [High priority task]
- [ ] P2: [Medium — complete if time allows]
```

---

## Adding a New Agent

See `strategy/team/ONBOARDING-TEMPLATE.md` for the full process.

Short version:
1. Choose a role ID and model
2. Write a prompt file in `prompts/XX-name/`
3. Define file ownership (no overlaps)
4. Add to `agents.conf`
5. PM announces to team via shared context
6. Test one cycle before full rotation

---

## Protected Files

These files must not be modified by agents without explicit owner approval:

```
scripts/orchestrator.sh
agents.conf
.env.production
prompts/01-pm/01-pm.txt   # PM prompt — owner only
```

---

*This document is read by all agents at session start. Keep it accurate.*
