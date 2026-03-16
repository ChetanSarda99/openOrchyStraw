<p align="center">
  <img src="assets/branding/logo-200.png" alt="OrchyStraw" width="120" />
</p>

<h1 align="center">OrchyStraw</h1>

<p align="center">
  <strong>A simple way to get multiple AI coding agents working together on the same project.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

---

## What is this?

If you've ever tried to get two AI agents working on the same codebase, you know the mess — they overwrite each other's files, lose context between sessions, and forget what they were doing.

OrchyStraw fixes that. It's a set of markdown files and one bash script. No framework to install, no Python package, no runtime. You copy a folder into your project and you're up and running.

It keeps agents in their lanes, gives them a shared memory, and has one agent (the PM) coordinate the whole thing.

---

## How it actually works

There are three pieces: **prompts**, **a script**, and **shared context**.

### Prompts — each agent's skill file

Every agent gets its own markdown file. Think of it as a job description — not a chat message, but a complete set of instructions the agent reads fresh every cycle.

```
prompts/
├── 00-shared-context/         ← the team's shared memory
├── 01-pm/                     ← the coordinator
│   └── 01-project-manager.txt
├── 02-backend/                ← backend agent
│   └── 02-backend-dev.txt
├── 03-frontend/               ← frontend agent
│   └── 03-frontend-dev.txt
├── 05-qa/                     ← QA reviewer
│   └── 05-qa-review.txt
└── 99-me/                     ← stuff only you can do
    └── 99-actions.txt
```

A prompt looks like this:

```markdown
# [Project] Backend Developer

**Your Role:** Backend Developer — APIs, database, auth, tests
**Objective:** [what to build this cycle]

## Context
[What the project is, tech stack, where things stand]

## YOUR TASKS (This Cycle)
1. Add POST /api/users endpoint with validation
2. Write 5 integration tests for the auth flow
3. Update shared-context with what you built

## Rules
- Only touch files in: backend/ prisma/
- Don't touch: frontend/ ios/ prompts/
- Read shared-context before you start
- Write what you did to shared-context when you're done
```

Why not just chat with agents? Because chat drifts. Instructions get buried ten messages deep and agents start hallucinating old context. A fresh prompt every cycle means the agent always knows exactly what to do.

### The script — runs everything

`auto-agent.sh` handles the full cycle so you don't have to babysit:

```bash
./scripts/auto-agent.sh orchestrate     # run 10 cycles
./scripts/auto-agent.sh orchestrate 5   # run 5 cycles
./scripts/auto-agent.sh run 02-backend  # run one agent
./scripts/auto-agent.sh list            # see who's registered
```

Each cycle, the script:

1. Pulls latest code
2. Creates a feature branch
3. Runs all the worker agents
4. Commits each agent's work (only files they're allowed to touch)
5. Catches and reverts any rogue writes (agent editing files it shouldn't)
6. Runs the PM last — it reviews everything, then updates all the prompts for the next cycle
7. Merges back to main
8. Backs up all prompts (rotates every 7 days)

The script handles git, file ownership, backups, and rogue detection. Agents just focus on code.

### Shared context — how agents stay in sync

There's one file every agent reads before starting and writes to before finishing:

`prompts/00-shared-context/context.md`

```markdown
## Backend
- Added POST /api/users (3 files, 5 tests)
- NEED: Frontend to build the user creation form

## Frontend
- Built login page and signup form
- BLOCKED: Waiting on /api/auth/refresh from backend
```

That's it. No vector databases, no RAG pipelines, no embeddings. Just a markdown file agents read and append to. It's simple because it doesn't need to be complicated.

### The PM — the brain of the operation

The PM agent is what makes multi-agent actually work. It:

- Runs **last**, after all the workers are done
- Reads shared context to see what everyone built
- Writes new instructions directly into each agent's prompt file for the next cycle
- Keeps a running record in the session tracker
- Drops anything it can't handle into `99-me/` for you

Agents never talk to each other. Everything goes through PM via the shared context file. It's a hub, not a mesh.

### Agent configuration

`scripts/agents.conf` is where you define your team:

```bash
# id | prompt_path | ownership | interval | label
01-pm      | prompts/01-pm/01-pm.txt       | prompts/ docs/    | 0 | PM
02-backend | prompts/02-backend/02-be.txt   | backend/ prisma/  | 1 | Backend
03-frontend| prompts/03-front/03-fe.txt     | frontend/ src/    | 1 | Frontend
05-qa      | prompts/05-qa/05-qa.txt        | none              | 5 | QA
```

- **ownership** = what directories this agent can write to. `none` means read-only.
- **interval** = `1` means every cycle. `5` means every 5th. `0` means coordinator (runs last).

---

## Getting started

### 1. Copy the template into your project

```bash
cp -r orchystraw/template/ your-project/
```

### 2. Run the bootstrap prompt

This looks at your codebase and generates all the agent files automatically:

```bash
cd your-project
claude --print "$(cat orchystraw/bootstrap-prompt.txt)"
```

You'll get `agents.conf`, `CLAUDE.md`, and prompt files tailored to your project's stack.

### 3. Let it run

```bash
./scripts/auto-agent.sh orchestrate
```

Or run a single agent to test:

```bash
claude --print < prompts/02-backend/02-backend-dev.txt
```

---

## Agent numbering

```
00-*  → Reserved: shared context, backups, session tracker
01-*  → PM (coordinator — runs last)
02-09 → Core dev agents
10-49 → Specialists (design, docs, security, i18n)
50-98 → Room to grow
99-*  → Reserved: you (manual tasks)
```

---

## Repo structure

```
orchystraw/
├── README.md
├── AGENT-DESIGN.md              ← writing good agent prompts
├── WORKFLOW.md                  ← how a cycle works end to end
├── ARCHITECTURE.md              ← system overview
├── TROUBLESHOOTING.md           ← when things go wrong
├── bootstrap-prompt.txt         ← one prompt to set up any project
├── assets/branding/             ← logo + icons
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
    ├── CONCEPTS.md
    ├── CREATING-CUSTOM-AGENTS.md
    ├── USAGE-CLAUDE-CODE.md
    ├── USAGE-WINDSURF.md
    └── USAGE-CURSOR-CODEX.md
```

---

## Docs

- **[Concepts](docs/CONCEPTS.md)** — every piece explained in detail
- **[Creating Custom Agents](docs/CREATING-CUSTOM-AGENTS.md)** — adding agents, ownership rules, patterns
- **[Claude Code](docs/USAGE-CLAUDE-CODE.md)** — setup and flags
- **[Windsurf](docs/USAGE-WINDSURF.md)** — Cascade integration
- **[Cursor / Codex / Others](docs/USAGE-CURSOR-CODEX.md)** — other CLIs and editors
- **[Agent Design](AGENT-DESIGN.md)** — writing prompts that actually work
- **[Workflow](WORKFLOW.md)** — cycle lifecycle and git operations
- **[Architecture](ARCHITECTURE.md)** — system architecture
- **[Troubleshooting](TROUBLESHOOTING.md)** — common issues and fixes

---

## License

[MIT](LICENSE)

---

Built by [CS](https://github.com/ChetanSarda99).
