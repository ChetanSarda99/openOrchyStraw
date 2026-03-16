# Agent Design — How to Write Good Agent Prompts
# Agent Design Guide

---

## Prompt Structure (Required Sections)

Every worker agent prompt MUST follow this structure. Sections are ordered for maximum agent effectiveness — don't reorder.

```markdown
# [Project] [Role] Prompt
## For Claude Code (Opus 4.6) — [Role Title]

**Date:** [auto-updated by PM each cycle]
**Your Role:** [specific role]
**Project Owner:** [human name + context]
**Objective:** [what to accomplish this cycle — be specific, include counts]

---

## Context
[2-3 sentences: what this project is, who it's for, core value prop]
[Tech stack summary — only parts relevant to this agent]
[Key constraint: "DO NOT CHANGE" for stack decisions]

## What Exists — [N] Files
[Current file tree or summary of this agent's domain]
[Test status: N files, N tests, all passing / N failing]
[Docs to read: list 2-3 key docs the agent should read first]

## What's DONE (Previous Cycles)
[Acknowledge completed work — prevents agents from redoing it]
[List specific: "OAuth state signing — utils/oauthState.ts" not "auth stuff"]

## YOUR TASKS — [Phase/Focus Area]

### Task 1: [Name] — P[0-2]
[Context: why this task matters]
[Specific steps: what to do, what files to create/modify]
[Acceptance criteria: how to know it's done]

### Task 2: [Name] — P[0-2]
[Same pattern...]

## Code Standards
[Formatting, naming, patterns specific to this domain]
[Reference: "Read CLAUDE.md first — it governs all code quality"]

## Skills & Working Style
[See Skills section below]

## File Ownership (STRICT — Do NOT Violate)
**YOU MAY WRITE TO:** [explicit paths]
**YOU MUST NOT WRITE TO:** [explicit exclusions]

## Auto-Cycle Mode
[See Auto-Cycle section below]
```

---

## Rules for Good Prompts (Learned the Hard Way)

### 1. Be Specific About What Exists
**Bad:** "There's a backend with some endpoints"
**Good:** "88 TypeScript source + 18 test files = 106 total. 297 tests all passing."
**Why:** Agents that know the scale make better decisions about where to add code.

### 2. Explicit Ownership Boundaries
**Bad:** "Work on the frontend"
**Good:** "YOU MAY WRITE TO: ios/ | YOU MUST NOT WRITE TO: backend/ prompts/ scripts/ docs/"
**Why:** Without this, agents write to each other's files. In early cycles, an agent modified auto-agent.sh (rogue write caught by QA).

### 3. Tasks Are Actionable with Context
**Bad:** "Improve the app"
**Good:** "Task 1: Notion internal rate limiting — P1\nQA found: Notion API calls in notionTasks.ts have no internal rate limit. A user spamming sync could exhaust the API.\nFix: Add per-user rate limit (max 5/min) via Redis key `notion-sync:${userId}` with TTL 60s."
**Why:** Agents with context make better implementation choices. Without "why", they guess.

### 4. Include File Counts (Auto-Updated by Script)
The orchestrator auto-updates file counts in all prompts via `sed` after each cycle merge.
PM does NOT need to manually update these — the script handles it.
Use consistent patterns in prompts: "88 TypeScript source + 18 test files = 106 total" so `sed` can match and replace.

### 5. Acknowledge Completed Work
List what shipped last cycle under "What's DONE". This prevents:
- Agents redoing finished tasks
- Prompt bloat from old task lists accumulating
- Confusion about current state vs. planned state

### 6. Reference Other Agents' Output
"02-Backend added OAuth state signing (utils/oauthState.ts) — verify it in your QA audit."
"04-Design replaced 38 hardcoded fonts — audit all 20 changed component files."
The shared context file (`00-shared-context/context.md`) carries this across agents.

### 7. Order Tasks by Priority AND Dependencies
Put unblocked tasks first. If Task 3 depends on Task 1's output, say so explicitly.
Use P0/P1/P2 consistently: P0 = must do this cycle, P1 = should do, P2 = nice to have.

---

## Prompt Length Guidelines

| Agent Type | Lines | Why |
|------------|-------|-----|
| PM | 150-300 | Full project context for decision-making |
| Backend/iOS Workers | 200-380 | Enough context + tasks without overwhelming |
| Design | 150-250 | Fewer tasks, more standards/patterns |
| QA | 150-250 | Focused on review criteria + verification |

**Real-world final prompts:** PM 289, Backend 199, iOS 211, Design 172, QA 196 — all in range.

---

## Skills & Tools Layer

Every agent prompt MUST include a "Skills & Working Style" section. Six layers:

### Layer 1: Slash Commands (Claude Code Built-in)
Always available. No installation needed.

| Command | What It Does | Token Cost |
|---------|-------------|------------|
| `/test` | Run/generate tests for current code | Medium |
| `/review` | Multi-pass code review (bugs, security, perf, readability) | High |
| `/security` | OWASP Top 10 security audit | High |
| `/debug` | Structured debugging with hypothesis testing | Medium |
| `/refactor` | Improve code structure without changing behavior | Medium |

**Per-agent defaults:**
| Agent Type | Commands |
|-----------|----------|
| PM | None (PM doesn't code) |
| Backend/Core | `/test`, `/review`, `/security`, `/debug`, `/refactor` |
| Frontend/iOS | `/test`, `/review`, `/debug`, `/refactor` |
| Design | `/review` |
| QA | `/security`, `/review`, `/test`, `/debug` |

**⚠️ Only these 5 are Claude Code built-ins.** Do NOT invent commands like `/plan`, `/deploy`, `/lint`, `/build` — they don't exist and waste tokens.

**Custom commands:** Your project's `CLAUDE.md` can define additional commands. For example, `~/Projects/CLAUDE.md` defines `/monitor` (tracks orchestrator cycles, background tasks, long-running operations). These are real — check `CLAUDE.md` before assuming a command is invalid.

### Layer 2: Superpowers Plugin (v4.3.0)
Install: `/plugin marketplace add obra/superpowers-marketplace` → `/plugin install superpowers@superpowers-marketplace`

**Core workflow (agents trigger these in sequence):**

| Skill | What It Does | Best For |
|-------|-------------|----------|
| `brainstorming` | Refine idea into design doc | PM |
| `writing-plans` | Break design into 2-5 min tasks with file paths | All agents |
| `subagent-driven-development` | Dispatch sub-agents per task, two-stage review | Backend, iOS |
| `test-driven-development` | RED→GREEN→REFACTOR enforcement | Backend |
| `verification-before-completion` | Verify everything works before marking done | All agents |

**Additional skills:**

| Skill | What It Does | Best For |
|-------|-------------|----------|
| `executing-plans` | Batch execution with checkpoints (alt to SDD) | Any |
| `dispatching-parallel-agents` | Run multiple sub-agents simultaneously | QA, complex tasks |
| `systematic-debugging` | Hypothesis-driven debugging, root cause tracing | Backend, QA |
| `requesting-code-review` / `receiving-code-review` | Code review flow | Optional |

**Platform-specific (add if applicable):**

| Skill | When to Add |
|-------|-------------|
| `supabase-backend-platform` | Project uses Supabase |
| `swiftui-skills` + `ios-design` | iOS/SwiftUI project |

**⚠️ Do NOT use with auto-agent.sh:**
- `using-git-worktrees` — script manages branches
- `finishing-a-development-branch` — script handles merge

**Commands:** `/brainstorm`, `/write-plan`, `/execute-plan`

**Per-agent assignment:**
```
PM:       brainstorming, writing-plans
Backend:  writing-plans, test-driven-development, systematic-debugging,
          subagent-driven-development, verification-before-completion
iOS:      writing-plans, subagent-driven-development, verification-before-completion,
          systematic-debugging
Design:   writing-plans, verification-before-completion
QA:       systematic-debugging, verification-before-completion,
          dispatching-parallel-agents
```

### Layer 3: Agent Teams (Sub-Agent Patterns)

| Team | What It Does | Best For |
|------|-------------|----------|
| `agent-teams:team-implementer` | Parallel feature builds with file ownership | Large builds |
| `agent-teams:team-lead` | Decompose and coordinate complex tasks | PM, complex features |
| `agent-teams:team-reviewer` | Parallel multi-dimension review (security, accessibility, performance) | Design, QA |
| `agent-teams:team-debugger` | Hypothesis-driven parallel debugging | QA, Backend |

**Proven pattern:** Split large builds → Foundation → Navigation → Onboarding → Tabs → Features. Each sub-agent group runs in parallel, owns specific files, no cross-agent conflicts. 5× faster than sequential.

### Layer 4: MCP Servers (Project-Specific)
Configured in `.mcp.json`. Template includes context7 by default.

| MCP | Config | When to Add |
|-----|--------|-------------|
| **context7** | `{"command":"npx","args":["-y","@upstash/context7-mcp"]}` | ✅ Always (framework docs) |
| **supabase** | `{"type":"http","url":"https://mcp.supabase.com/mcp?project_ref=XXX"}` | If using Supabase |
| **qmd** | `{"command":"qmd","args":["mcp"]}` | ✅ Recommended for all projects (reduces tokens) |

**QMD setup (local markdown search — BM25 + vector):**
```bash
npm install -g @tobilu/qmd
qmd collection add docs --name project-docs
qmd collection add prompts --name project-prompts
qmd collection add src --name project-source   # optional: index source code
qmd embed
```
Add to `.mcp.json` so ALL agents can search docs without reading entire files.
Additionally install as PM agent skill (`.agents/skills/qmd/SKILL.md`) for prompt-generation searches.
**All agents benefit:** Backend searches API docs, iOS searches design tokens, QA searches prior reports, PM searches everything.

### Layer 5: CLAUDE.md (Project Config)
Auto-loaded by Claude Code. Contains design system, code standards, anti-slop rules.
Every agent prompt should say: "Read `CLAUDE.md` first — it governs all code quality standards."

**Root `~/Projects/CLAUDE.md`** applies to ALL projects under ~/Projects/. It defines:
- Agent-teams orchestration as default
- Browser testing strategy (Playwright → Chrome DevTools)
- Notion access rules (REST API, not MCP)
- Proactive skill usage

### Layer 6: Copy-Paste Prompt Block

Include this (customized) in every agent prompt:

```markdown
## Skills & Working Style

**Skills:** /test after new logic, /review after features, /security before auth code, /debug when stuck, /refactor when complexity grows
Read `CLAUDE.md` first — it has code standards and anti-slop rules that apply to all agents.
**Superpowers:** test-driven-development, verification-before-completion, writing-plans, subagent-driven-development, systematic-debugging
**Orchestration:** team-implementer (parallel builds), team-reviewer (multi-dim review), team-debugger (hypothesis-driven debugging)

**99-me protocol:** If blocked, append to `prompts/99-me/99-actions.txt` with date, status, priority, context.

**[OWNER] prefers:** Action over questions. Concise. Working code, not TODOs. Complete solutions.

**When building:** Read existing code first. Follow established patterns. Use agent teams for multi-file work. Append to 99-me if blocked.
```

---

## Infrastructure Files

### Shared Context (`00-shared-context/context.md`)
Reset each cycle. Every agent reads it at start, appends their status before finishing.
Sections: Usage, Backend Status, iOS Status, Design Status, QA Findings, Blockers, Notes.
PM archives old context as `context-cycle-N.md` before reset.

### Session Tracker (`00-session-tracker/SESSION_TRACKER.txt`)
Long-lived changelog. Tracks: file inventory, milestone dashboard, what shipped per cycle, next priorities, decisions log.
PM updates this every cycle. This is the project's memory across sessions.

### 99-me (`99-me/99-actions.txt`)
Human escalation file. Any agent can append items the human must do manually.
Format:
```markdown
### P0: [Title] (blocking [what])
**From:** [agent-id] | **Added:** [date]

1. [Step the human takes]
2. [Next step]

**Why:** [Why the agent can't do this itself]
```

### Prompt Backups (`00-backup/`)
auto-agent.sh backs up all prompts before each cycle. 7-day rotation.
If an agent writes a bad prompt, restore from backup.

### Usage Tracking (`00-shared-context/usage.txt`)
Single integer: 0 = ok, 80 = overage warning, 90+ = pause.
`check-usage.sh` probes Claude's API for rate limit events, updates this file.
PM reads it each cycle. Agents should check before heavy AI calls.

---

## Auto-Cycle Mode Block

Include this EXACT block (customized) at the bottom of every agent prompt:

```markdown
## Auto-Cycle Mode

You are running in an automated loop. After you finish, the PM agent reviews your work and writes your next prompt. There is no human between cycles.

- **Do NOT run git commit, git push, git checkout, git branch, or git switch** — the orchestrator script handles ALL git operations
- **Close completed GitHub issues** with `gh issue close`
- **Do NOT self-update your prompt** — the PM handles that
- If blocked, append to `prompts/99-me/99-actions.txt`
- Complete everything you can. The next cycle starts in ~10 minutes.
- Stay on the current branch. Do not switch branches.
- **Read** `prompts/00-shared-context/context.md` at the start — it has what other agents built/need.
- **Append** your updates to shared context before finishing (under [Your Section]).
```

---

## PM-Specific: Prompt Generation Workflow

The PM follows this 7-step process EVERY cycle when updating agent prompts:

### Step 1: Read Shared Context
`prompts/00-shared-context/context.md` — what each agent built, needs, blockers.

### Step 2: Read the Current Prompt
Understand what was assigned last cycle.

### Step 3: Review What Got Done
```bash
git log --oneline -20
git diff main..HEAD --stat
git status --short
gh issue list --milestone "MILESTONE" --state closed
```
Skim key files the agent was supposed to build/modify.

### Step 4: Identify Gaps & Drift
- Which tasks completed? Partially done? Not touched?
- Did the agent build anything NOT in the prompt? (This happens — agents are creative)
- Did any blocker get resolved? (Check 99-me)

### Step 5: Update Task Sections (Edit, Not Write)
Use the **Edit tool** to modify only these sections in each prompt:
- "What's DONE" — add what this cycle completed
- "YOUR TASKS" / "YOUR NEXT TASKS" — assign next work from open issues
- "Agent Status Summary" (PM prompt only) — update per-agent status

**Do NOT rewrite entire prompts.** The orchestrator script auto-updates:
- `**Date:**` timestamps
- File counts (TypeScript, Swift, components, totals)
Keep all other sections intact (tech stack, file ownership, design system, auto-cycle mode).

### Step 6: Cross-Check Across Agents
- No two agents assigned overlapping file ownership
- APIs that one agent depends on are actually built by another
- Issue numbers are real (run `gh issue list`)
- No agent references non-existent commands or tools

### Step 7: Update Session Tracker
Update `SESSION_TRACKER.txt` with: what shipped, milestone counts, next priorities.

---

## Common Mistakes (All Hit During Production Use)

| Mistake | Example | Fix |
|---------|---------|-----|
| Agent writes outside ownership | Backend agent edited auto-agent.sh | Explicit "MUST NOT WRITE TO" with all other agents' paths |
| Agent runs git commands | Agent did `git checkout -b feature` | "Do NOT run git commands" in Auto-Cycle block |
| Agent updates its own prompt | PM's prompt got self-modified | "Do NOT update your own prompt — PM handles that" |
| Prompt references nonexistent files | "Wire up PaymentService.swift" (doesn't exist) | PM verifies file existence before prompting |
| Two agents own same directory | iOS and Design both edit `ios/Components/` | Use exclusions: `ios/ !ios/Components/` vs `ios/Components/` |
| Ghost commands in prompts | `/plan`, `/deploy`, `/lint` referenced as built-in | Only 5 built-ins (/test, /review, /security, /debug, /refactor) + any defined in CLAUDE.md (e.g., /monitor) |
| Stale task lists | Prompt says "build X" but X shipped last cycle | PM MUST acknowledge completed work + remove done tasks |
| No shared context | Agents duplicate work or build conflicting APIs | Use 00-shared-context/context.md — read at start, append at end |
| No 99-me escalation | Agent silently fails on blocker | Add 99-me protocol to every prompt |
| PM writes code | PM "helps" by writing a small fix | PM prompt says "you NEVER write code" — enforce strictly |

---

## Validation Checklist (Run Before First Cycle)

- [ ] Every agent prompt follows the structure above
- [ ] Every `/command` is a real Claude Code built-in (only: /test, /review, /security, /debug, /refactor)
- [ ] Every superpower referenced is installed
- [ ] Every MCP in prompts matches an entry in `.mcp.json`
- [ ] No two agents own overlapping directories
- [ ] CLAUDE.md exists and is referenced in every prompt
- [ ] `scripts/agents.conf` lists all agents with correct prompt paths + ownership
- [ ] `prompts/00-shared-context/context.md` exists with section headers for each agent
- [ ] `prompts/99-me/99-actions.txt` exists (can be empty)
- [ ] `prompts/00-session-tracker/SESSION_TRACKER.txt` exists with milestone dashboard
- [ ] `.mcp.json` exists with at least context7
- [ ] No agent prompt references `using-git-worktrees` or `finishing-a-development-branch`
