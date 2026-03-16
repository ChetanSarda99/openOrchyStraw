# CLAUDE.md - [PROJECT_NAME] Project Instructions

**Read this first. Follow it exactly. This overrides defaults.**

---

## Project Overview

**[PROJECT_NAME]** — [one-line description]
[2-3 sentences: what it does, who it's for, core value prop]

**Repo:** [REPO_URL]
**Owner:** [OWNER_NAME] — [context: solo dev, team, experience level]
**Timeline:** [timeline to MVP/launch]

---

## Finalized Tech Stack (All Decided)

[LIST YOUR TECH STACK HERE — be specific about versions, frameworks, patterns]
[Mark as "All Decided" so agents don't change it]

---

## Working Style — FOLLOW STRICTLY

### [Owner] Prefers
- **Action over questions** — Just do it, don't ask for permission
- **Concise responses** — No fluff, no trailing summaries
- **Working code** — Not pseudocode, not TODO comments
- **Complete solutions** — Don't leave half-finished work

### Anti-Slop Rules (CRITICAL)
- **NO** generic gradient backgrounds
- **NO** stock photo placeholders or Lorem ipsum
- **NO** default Material/Bootstrap components without customization
- **NO** emoji in code comments or commit messages
- **NO** over-explaining what you just did
- **NO** adding features, comments, or refactoring beyond what was asked
- **YES** personality in design choices
- **YES** thoughtful micro-interactions
- **YES** custom components that match the project's identity

---

## Design System

[ADD IF UI PROJECT — delete this section for CLI/API-only projects]
[Include: colors, typography, layout rules, animation principles, design inspirations, UX rules]

---

## Code Standards

[ADD YOUR CODE STANDARDS HERE]
[Include: naming conventions, patterns, error handling, testing requirements]
[Add language-specific code examples showing ALWAYS/NEVER patterns]

### REST API Design (if applicable)
- Nouns not verbs: `/notes` not `/getNotes`
- Plural for collections: `/notes`, `/sources`
- Response: `{ data: T }` success, `{ error: { code, message } }` errors
- Paginate everything: `?page=1&limit=20`

### Git
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Branch from main: `feature/*`, `bugfix/*`, `hotfix/*`
- Never force push to main

---

## Project Structure

```
[PROJECT_NAME]/
├── [your directory tree here]
├── prompts/                    # Agent prompts (auto-managed)
├── scripts/                    # Orchestrator + utilities
└── CLAUDE.md                   # This file
```

---

## Current Status (Last Updated: [DATE])

### Codebase: [FILE_COUNTS]

### [MILESTONE_STATUS]

---

## API Endpoints

[ADD IF APPLICABLE — delete for non-API projects]

---

## Common Tasks

### Adding a New Feature
1. Check GitHub issues: `gh issue list --repo [REPO] --milestone "MILESTONE"`
2. Backend first (API + tests)
3. Frontend/iOS second (UI + ViewModel)
4. Test
5. Commit with conventional message

[ADD PROJECT-SPECIFIC WORKFLOWS: new integrations, new routes, new screens, etc.]

---

## Auto-Agent Orchestrator

The project has an autonomous multi-agent build system.

### Quick Commands
```bash
./scripts/auto-agent.sh orchestrate       # Run 10 cycles
./scripts/auto-agent.sh orchestrate 5      # Run 5 cycles
./scripts/auto-agent.sh run 02-backend     # Run single agent once
./scripts/auto-agent.sh list               # Show all agents
./scripts/check-usage.sh                   # Check API rate limits
```

### Architecture
- **Agents** defined in `scripts/agents.conf`: coordinator (01-pm) + workers
- **Each cycle**: workers run in parallel → commits by file ownership → PM reviews + updates tasks → merge to main → push
- **Shared context**: `prompts/00-shared-context/context.md` — agents read/write what they built/need
- **Session tracker**: `prompts/00-session-tracker/SESSION_TRACKER.txt` — long-term changelog
- **Progress**: `prompts/00-shared-context/progress.json` — file counts per cycle, regression detection
- **Backups**: `prompts/00-backup/cycle-*/` — prompt snapshots, 7-day rotation
- **QA reports**: `prompts/0N-qa/reports/` — named by date-time (if QA agent exists)

### What the Script Handles (don't duplicate)
- Timestamps + file counts in all prompts (auto-updated after every merge)
- Usage check via `check-usage.sh` (pauses at 70% rate limit)
- Shared context reset + archive per cycle
- `qmd update` every cycle, `qmd embed` on QA cycles (if installed)
- Git branching, commits by ownership, merge, push
- Rogue write detection (files outside ownership)
- Backup rotation (7 days)

### What PM Agent Handles
- Task assignments (Edit "YOUR TASKS" sections — never rewrite full prompts)
- Milestone status updates
- SESSION_TRACKER what-shipped entries
- Human action items (99-actions)

### Monitoring
- Log: `prompts/01-pm/logs/orchestrator.log`
- Don't edit `scripts/auto-agent.sh` while orchestrator is running

### Key Docs
[LIST YOUR IMPORTANT DOCS HERE — product spec, architecture, decisions, etc.]

---

**Ship fast. Production quality. Not AI slop.**
