<p align="center">
  <img src="assets/branding/logo-200.png" alt="OrchyStraw" width="120" />
</p>

<h1 align="center">OrchyStraw</h1>

<p align="center">
  <strong>Drop-in multi-agent prompt system for AI coding agents.</strong><br/>
  Zero dependencies. Works with any AI agent that has a CLI.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/works_with-Claude_Code_%7C_Windsurf_%7C_Cursor_%7C_Codex-blue" alt="Works With" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

---

## What This Is

A **prompt scaffold** — not a framework, not a library, not another `pip install`. Just markdown files and a bash script that orchestrate multiple AI coding agents working on the same codebase without stepping on each other.

---

## How It Works

OrchyStraw has three moving parts: **prompts** (skills), **a script** (orchestrator), and **shared context** (team memory).

### The Prompts (Agent Skills)

Each agent gets a **prompt file** — a markdown document that acts as its standing orders. Not a chat message. A complete instruction set.

```
prompts/
├── 00-shared-context/         ← every agent reads + writes to this
├── 01-pm/                     ← PM coordinator (writes all other prompts)
│   └── 01-project-manager.txt
├── 02-backend/                ← backend dev prompt
│   └── 02-backend-dev.txt
├── 03-frontend/               ← frontend dev prompt
│   └── 03-frontend-dev.txt
├── 05-qa/                     ← QA reviewer prompt
│   └── 05-qa-review.txt
└── 99-me/                     ← human action items
    └── 99-actions.txt
```

Every prompt follows the same structure:

```markdown
# [Project] Backend Developer Prompt

**Your Role:** Backend Developer — APIs, database, auth, tests
**Objective:** [specific tasks for this cycle]

## Context
[What the project is, tech stack, current state]

## YOUR TASKS (This Cycle)
1. Add POST /api/users endpoint with validation
2. Write 5 integration tests for auth flow
3. Update shared-context with what you built

## Rules
- Only modify files in: backend/ prisma/
- DO NOT touch: frontend/ ios/ prompts/
- Read shared-context before starting
- Append what you did to shared-context when done
```

**Why standing orders instead of chat?** Chat drifts. Context gets buried. Agents hallucinate old messages. Standing orders are deterministic — the agent reads the full prompt from scratch every cycle. No memory issues.

### The Script (Orchestrator)

`scripts/auto-agent.sh` runs the full cycle:

```bash
./scripts/auto-agent.sh orchestrate     # run 10 cycles (default)
./scripts/auto-agent.sh orchestrate 5   # run 5 cycles
./scripts/auto-agent.sh run 02-backend  # run single agent once
./scripts/auto-agent.sh list            # show registered agents
```

**What the script does each cycle:**

```
1. Pull latest from main
2. Create feature branch for this cycle
3. Reset shared context
4. Run all worker agents (parallel or sequential)
5. Commit each agent's changes by file ownership
6. Detect rogue writes (agent wrote outside its boundaries) → revert
7. Run PM coordinator last (reviews work, updates all prompts for next cycle)
8. Merge → main, push
9. Backup all prompts (7-day rotation)
10. Repeat
```

**What the script handles that agents shouldn't:**
- Git branching and merging (agents mess this up)
- File ownership enforcement (prevents agent A from editing agent B's files)
- Backup rotation (recovers from prompt corruption)
- Rogue write detection and rollback
- Timestamp and file count injection into prompts

### Agent Configuration

`scripts/agents.conf` defines who runs:

```bash
# id | prompt_path | ownership | interval | label
01-pm      | prompts/01-pm/01-pm.txt       | prompts/ docs/    | 0 | PM Coordinator
02-backend | prompts/02-backend/02-be.txt   | backend/ prisma/  | 1 | Backend Dev
03-frontend| prompts/03-front/03-fe.txt     | frontend/ src/    | 1 | Frontend Dev
05-qa      | prompts/05-qa/05-qa.txt        | none              | 5 | QA Engineer
```

| Column | Meaning |
|--------|---------|
| `id` | Unique agent identifier |
| `prompt_path` | Path to the prompt file |
| `ownership` | Directories this agent can write to. `!path` excludes. `none` = read-only. |
| `interval` | `0` = coordinator (runs last). `1` = every cycle. `5` = every 5th cycle. |
| `label` | Human-readable name |

### The Shared Context (Team Memory)

`prompts/00-shared-context/context.md` is the single file all agents share:

- Every agent **reads it** before starting (knows what others did)
- Every agent **appends to it** before finishing (tells others what it did)

```markdown
## Backend Status
- Added POST /api/users endpoint (3 files, 5 tests)
- NEED: Frontend to add user creation form

## Frontend Status
- Built login page and signup form
- BLOCKER: Waiting for /api/auth/refresh endpoint from backend
```

No vector databases. No RAG. No embeddings. Just a markdown file.

### The PM Pattern

The PM agent is the key to everything. It:

1. **Runs last** (after all workers finish)
2. **Reads shared context** to see what everyone built
3. **Writes new standing orders** directly to each agent's prompt file
4. **Updates the session tracker** (permanent record across cycles)
5. **Adds human tasks** to `99-me/99-actions.txt`

The PM doesn't chat with agents. It reads their output, plans the next cycle, and overwrites their prompt files with new instructions. Agents never talk to each other — everything goes through PM.

---

## Quick Start

### 1. Copy the template

```bash
cp -r orchystraw/template/ your-project/
```

### 2. Bootstrap

Run the bootstrap prompt to auto-generate agents for your stack:

```bash
cd your-project
claude --print "$(cat orchystraw/bootstrap-prompt.txt)"
```

This scans your codebase and creates: `agents.conf`, `CLAUDE.md`, and all agent prompt files — tailored to your project's languages and structure.

### 3. Run

```bash
./scripts/auto-agent.sh orchestrate
```

Or run agents manually:

```bash
claude --print < prompts/02-backend/02-backend-dev.txt
```

---

## Agent Numbering

```
00-*  → Reserved: shared-context, backups, session-tracker
01-*  → PM coordinator (runs last, writes to all prompts)
02-09 → Core dev agents
10-49 → Specialty agents (design, docs, security, i18n)
50-98 → Expansion
99-*  → Reserved: YOU (human manual tasks)
```

---

## What You Get

```
orchystraw/
├── README.md
├── AGENT-DESIGN.md              ← how to write prompts that work
├── WORKFLOW.md                  ← full cycle lifecycle reference
├── ARCHITECTURE.md              ← system architecture
├── TROUBLESHOOTING.md           ← common failures + fixes
├── bootstrap-prompt.txt         ← one prompt to scaffold any project
├── assets/branding/             ← logo + icon variants
├── template/                    ← copy this into your project
│   ├── CLAUDE.md
│   ├── prompts/
│   │   ├── 00-shared-context/
│   │   ├── 00-session-tracker/
│   │   ├── 00-backup/
│   │   ├── 01-pm/
│   │   └── 99-me/
│   └── scripts/
│       ├── agents.conf.example
│       ├── auto-agent.sh
│       └── check-usage.sh
├── examples/
│   ├── sample-agents.conf
│   └── sample-pm-prompt.txt
└── docs/
    ├── CONCEPTS.md              ← detailed explainer of every component
    ├── CREATING-CUSTOM-AGENTS.md ← add new agents, patterns, ownership
    ├── USAGE-CLAUDE-CODE.md
    ├── USAGE-WINDSURF.md
    └── USAGE-CURSOR-CODEX.md
```

---

## Docs

### Getting Started
- **[Concepts](docs/CONCEPTS.md)** — what every piece is, why it exists, how they fit together
- **[Creating Custom Agents](docs/CREATING-CUSTOM-AGENTS.md)** — add agents, ownership rules, design patterns

### Usage Guides
- **[Claude Code](docs/USAGE-CLAUDE-CODE.md)** — setup, flags, model selection
- **[Windsurf](docs/USAGE-WINDSURF.md)** — Cascade integration, Flows, hybrid setup
- **[Cursor / Codex / Others](docs/USAGE-CURSOR-CODEX.md)** — Cursor, Codex, Aider, any CLI agent

### Reference
- **[Agent Design](AGENT-DESIGN.md)** — how to write prompts that actually work
- **[Workflow](WORKFLOW.md)** — full cycle lifecycle, git ops, safety
- **[Architecture](ARCHITECTURE.md)** — system architecture overview
- **[Troubleshooting](TROUBLESHOOTING.md)** — common failures and fixes

---

## License

[MIT](LICENSE)

---

Built by [CS](https://github.com/ChetanSarda99).
