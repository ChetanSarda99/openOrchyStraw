# Creating Custom Agents

How to add new agents to your orchystraw setup — from scratch or by cloning an existing one.

---

## Quick Start: Add an Agent in 3 Steps

### 1. Create the prompt directory and file

```bash
mkdir -p prompts/06-devops/
touch prompts/06-devops/06-devops.txt
```

### 2. Write the prompt

Every agent prompt **must** follow this structure (see [AGENT-DESIGN.md](../AGENT-DESIGN.md) for the full guide):

```markdown
# [Project] DevOps Prompt
## For [Your CLI] — DevOps Engineer

**Date:** [auto-updated by orchestrator]
**Your Role:** DevOps Engineer — CI/CD, deployment, infrastructure
**Project Owner:** [name]
**Objective:** [specific tasks for this cycle]

---

## Context
[What this project is, 2-3 sentences]
[Tech stack — only parts relevant to this agent]

## What Exists
[Current state of this agent's domain]
[File counts, test status, deployment status]

## YOUR TASKS (This Cycle)
1. [Specific, measurable task]
2. [Another task with clear done criteria]
3. [Include file paths, counts, test expectations]

## Rules
- Only modify files in your ownership paths
- Read shared-context before starting
- Append what you did to shared-context when done
- DO NOT modify: [list protected files/dirs]

## Done Criteria
- [ ] Task 1 complete with [specific output]
- [ ] Task 2 complete with [specific output]
- [ ] Shared context updated
```

### 3. Register in agents.conf

```bash
# Format: id | prompt_path | ownership | interval | label
06-devops | prompts/06-devops/06-devops.txt | .github/ docker-compose.yml Dockerfile infrastructure/ | 3 | DevOps Engineer
```

That's it. The orchestrator picks it up automatically on the next cycle.

---

## Agent Numbering Convention

```
00-*   → Reserved: shared-context, backups, session-tracker
01-*   → PM (coordinator) — runs LAST, writes to all other prompts
02-09  → Core dev agents (backend, frontend, iOS, etc.)
10-19  → Specialty agents (design, docs, security, perf)
20-49  → Task-specific agents (migration, i18n, data pipeline)
50-89  → Future expansion
90-98  → Infrastructure/ops agents
99-*   → Reserved: YOU (human manual actions)
```

**Gaps are fine.** You can have `02-backend`, `03-frontend`, `05-qa` with no `04`. The orchestrator reads `agents.conf`, not directory numbers.

---

## Agent Design Patterns

### Pattern 1: Domain Worker (most common)

Owns a set of files, builds/modifies them each cycle.

```
02-backend  | prompts/02-backend/02-backend-dev.txt  | backend/ prisma/ | 1 | Backend Dev
```

- Runs **every cycle** (interval=1)
- Has **write access** to `backend/` and `prisma/`
- Gets **standing orders** from PM each cycle

### Pattern 2: Periodic Reviewer

Doesn't own files — reviews them. QA, security audit, performance.

```
05-qa       | prompts/05-qa/05-qa-review.txt  | prompts/05-qa/reports/ | 5 | QA Engineer
```

- Runs **every 5th cycle** (interval=5) — saves tokens
- Owns **only its reports dir** (writes QA reports, not code)
- Reads all code but doesn't modify it

### Pattern 3: One-Shot Specialist

Created for a specific task, removed after.

```
20-migration | prompts/20-migration/20-db-migration.txt | backend/prisma/ migrations/ | 1 | DB Migration
```

- Runs **once or twice** then gets removed from `agents.conf`
- Good for: database migrations, major refactors, framework upgrades
- Remove from config when done (keep prompt for reference)

### Pattern 4: Coordinator (PM)

Only one. Runs **last** (interval=0). Writes to all other agent prompts.

```
01-pm | prompts/01-pm/01-project-manager.txt | prompts/ docs/ | 0 | PM Coordinator
```

---

## Ownership Rules

### Basic ownership
```
backend/ prisma/          → Agent can write to these directories
```

### Exclusions (important for avoiding conflicts)
```
ios/ !ios/App/Views/Components/    → Can write to ios/ EXCEPT Components/
```

### Read-only agents
```
none                              → Agent can read everything, write nothing
```

### Overlapping ownership
**Avoid this.** If two agents can write to the same file, the orchestrator's commit-by-ownership will pick the first one. Use exclusion paths to carve out boundaries:

```
# iOS dev owns everything EXCEPT the design system files
03-ios    | ... | ios/ !ios/App/Views/Components/ !ios/App/Theme.swift | 1 | iOS Dev

# Design agent owns ONLY the design system files
04-design | ... | ios/App/Views/Components/ ios/App/Theme.swift       | 1 | Design System
```

---

## Common Custom Agents

### Documentation Writer
```
07-docs | prompts/07-docs/07-docs-writer.txt | docs/ README.md CONTRIBUTING.md | 3 | Docs Writer
```
Good for: API docs, user guides, changelog. Run every 3 cycles.

### Test Writer
```
06-test | prompts/06-test/06-test-writer.txt | tests/ __tests__/ *.test.* | 2 | Test Writer
```
Good for: increasing test coverage without slowing dev agents. Run every 2 cycles.

### Security Auditor
```
10-security | prompts/10-security/10-security-audit.txt | prompts/10-security/reports/ | 10 | Security Auditor
```
Good for: dependency audit, code scanning, OWASP checks. Run every 10 cycles.

### Performance Agent
```
11-perf | prompts/11-perf/11-perf-review.txt | prompts/11-perf/reports/ | 5 | Performance Review
```
Good for: bundle size tracking, query optimization, lighthouse scores.

### DevOps / Infrastructure
```
08-devops | prompts/08-devops/08-devops.txt | .github/ docker-compose.yml Dockerfile k8s/ terraform/ | 3 | DevOps
```
Good for: CI/CD improvements, container optimization, IaC.

### i18n / Localization
```
15-i18n | prompts/15-i18n/15-i18n.txt | locales/ src/i18n/ | 5 | Localization
```
Good for: translation management, missing key detection.

---

## Tips

### 1. Start with 3-4 agents max
PM + 2 devs + QA is the sweet spot. Add more only when you have clear domain boundaries.

### 2. QA interval matters
Too frequent = wasted tokens reviewing nothing new. Too rare = bugs compound. Start with `interval=5`.

### 3. New agent = PM needs to know
After adding an agent to `agents.conf`, update the PM prompt to include the new agent in its roster. PM can't delegate work to agents it doesn't know about.

### 4. Test with a single run first
```bash
./scripts/auto-agent.sh run 06-devops
```
Before adding to the orchestration cycle, run the agent once manually and check the output.

### 5. Check logs
Every agent writes to `prompts/<id>/logs/`. If a new agent fails, the log tells you why.

### 6. Removing an agent
Comment out or delete the line in `agents.conf`. Keep the prompt directory for reference. The orchestrator ignores agents not in the config.
