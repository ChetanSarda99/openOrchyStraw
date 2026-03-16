# Concepts — Understanding OrchyStraw

Everything in orchystraw explained: what each piece is, why it exists, and how they work together.

---

## The Big Picture

```
┌──────────────────────────────────────────────────────┐
│                    YOU (99-me)                        │
│              Review, approve, manual tasks            │
└──────────────────────┬───────────────────────────────┘
                       │ runs
                       ▼
┌──────────────────────────────────────────────────────┐
│              auto-agent.sh (Orchestrator)             │
│     Reads agents.conf → runs agents → commits        │
│     Handles: git, backups, ownership, merging         │
└───────┬──────────┬──────────┬──────────┬─────────────┘
        │          │          │          │
        ▼          ▼          ▼          ▼
   ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │ 01-PM  │ │02-Back │ │03-Front│ │ 05-QA  │
   │Coords  │ │ end    │ │ end    │ │Reviews │
   └───┬────┘ └────────┘ └────────┘ └────────┘
       │ writes to
       ▼
   All agent prompt files
   (standing orders for next cycle)
```

---

## Core Components

### 1. Prompts (the brains)

**Location:** `prompts/<id>/<id>-<name>.txt`

A prompt is a **standing order** — a markdown file that tells an AI agent exactly what to do. It's not a chat message. It's a complete document with:

- **Role** — who this agent is
- **Context** — what the project is, what exists
- **Tasks** — specific objectives for this cycle
- **Rules** — what to touch, what to avoid
- **Done criteria** — how to know when you're finished

**Why markdown?** Because every AI agent reads markdown natively. No parsing, no format conversion, no special SDK. Write a file → agent reads it → agent does the work.

**Why standing orders (not chat)?** Chat is lossy — context drifts, instructions get buried, agents hallucinate previous messages. Standing orders are deterministic: the agent reads the full prompt from scratch every cycle. No memory issues. No drift.

---

### 2. Shared Context (the team's brain)

**Location:** `prompts/00-shared-context/context.md`

The single source of truth across all agents. Every agent:
- **Reads it** before starting (knows what others did)
- **Appends to it** before finishing (tells others what it did)

```markdown
## Backend Status
- Added POST /api/users endpoint (3 files, 5 tests)
- NEED: Frontend to add user creation form

## Frontend Status
- Built login page and signup form
- BLOCKER: Waiting for /api/auth/refresh endpoint from backend

## QA Findings
- Found race condition in /api/sessions — filed issue #47
```

**Why not a database?** Because agents read markdown. A shared markdown file costs ~100 tokens to read. An API call to fetch context from a database costs thousands of tokens just for the retrieval logic. Simple wins.

**Why not agent-to-agent chat?** Because 70% of tokens in agent chat are "I agree, let's proceed" — pure waste. File-based coordination eliminates all of that overhead.

---

### 3. The Orchestrator Script (the conductor)

**Location:** `scripts/auto-agent.sh`

A bash script that runs the entire cycle:

```
1. Pull latest from main
2. Create feature branch for this cycle
3. Reset shared context
4. Run all eligible worker agents in parallel
5. Commit each agent's work by file ownership (no git conflicts)
6. Detect rogue writes (files outside ownership)
7. Run PM coordinator (reviews, updates all prompts)
8. Merge feature branch → main
9. Push
10. Backup prompts, validate, update timestamps
11. Repeat
```

**What it handles that agents shouldn't:**
- Git branching/merging (agents mess this up)
- File ownership enforcement (prevents cross-agent conflicts)
- Backup rotation (7-day prompt history)
- Usage/rate limit checking (pauses at 70%)
- Timestamp + file count updates in prompts
- Rogue write detection and rollback

**Commands:**
```bash
./scripts/auto-agent.sh orchestrate 10   # Run 10 cycles
./scripts/auto-agent.sh orchestrate      # Run 10 cycles (default)
./scripts/auto-agent.sh run 02-backend   # Run single agent once
./scripts/auto-agent.sh list             # Show registered agents
```

---

### 4. Agent Configuration (the roster)

**Location:** `scripts/agents.conf`

Defines who runs, what they own, how often:

```
# id | prompt_path | ownership | interval | label
01-pm      | prompts/01-pm/01-pm.txt      | prompts/ docs/     | 0 | PM Coordinator
02-backend | prompts/02-backend/02-be.txt  | backend/ prisma/   | 1 | Backend Dev
03-frontend| prompts/03-front/03-fe.txt    | frontend/ src/     | 1 | Frontend Dev
05-qa      | prompts/05-qa/05-qa.txt       | prompts/05-qa/reports/ | 5 | QA Engineer
```

**Columns:**
| Column | Meaning |
|--------|---------|
| `id` | Unique identifier (used in git commits, logs, everything) |
| `prompt_path` | Path to the prompt file (relative to project root) |
| `ownership` | Directories this agent can write to. `!path` excludes. `none` = read-only. |
| `interval` | 0 = coordinator (runs last). 1 = every cycle. N = every Nth cycle. |
| `label` | Human-readable name for logs and notifications |

---

### 5. CLAUDE.md (project rules)

**Location:** `CLAUDE.md` (project root)

The project-wide instruction file that **every** agent reads automatically. Contains:
- Tech stack decisions (marked "DO NOT CHANGE")
- Code standards and patterns
- Design system tokens
- Anti-slop rules (no generic gradients, no Lorem ipsum, etc.)
- Git conventions

**Why "CLAUDE.md"?** Claude Code reads it automatically. But it works as a convention for any agent — Windsurf, Cursor, Codex all benefit from a project-rules file.

---

### 6. Session Tracker (long-term memory)

**Location:** `prompts/00-session-tracker/SESSION_TRACKER.txt`

Shared context resets every cycle. Session tracker is the **permanent** record:
- What shipped in each cycle
- Decisions made
- Milestone progress
- File counts over time

PM appends to this every cycle. It's how the PM writes accurate prompts — it reads the tracker to know what's been built across all previous cycles.

---

### 7. The 99-me File (your action items)

**Location:** `prompts/99-me/99-actions.txt`

Agents can't do everything. Some tasks need a human:
- Xcode configuration
- API key setup
- App Store submissions
- Manual testing on devices
- Design review

When an agent encounters something it can't do, it appends to `99-actions.txt`. PM also writes human tasks here during coordination. Check this file regularly.

---

### 8. Bootstrap Prompt (project setup)

**Location:** `bootstrap-prompt.txt`

A one-shot prompt you run **once** to set up orchestration for any project. Give it to any AI agent:

```bash
claude --print "$(cat orchystraw/bootstrap-prompt.txt)"
```

It:
1. Scans your codebase (languages, frameworks, structure)
2. Determines the right agents for your stack
3. Creates all prompt files, agents.conf, CLAUDE.md
4. Sets up the full orchestration system

**You shouldn't need to edit this.** It's a generator, not a config file.

---

### 9. Backups (safety net)

**Location:** `prompts/00-backup/cycle-*/`

Every cycle, the orchestrator snapshots all prompts before PM modifies them. If PM corrupts a prompt (it happens), the orchestrator auto-restores from backup.

Backups auto-rotate after 7 days. You can manually restore:
```bash
cp prompts/00-backup/cycle-20260316-143022/02-backend-dev.txt prompts/02-backend/02-backend-dev.txt
```

---

## How a Cycle Works (Step by Step)

```
Cycle 4 starts
│
├── 1. git pull origin main
├── 2. Create branch: auto/cycle-4-0316-1430
├── 3. Archive last cycle's shared context → context-cycle-3.md
├── 4. Reset shared context for cycle 4
│
├── 5. Run workers IN PARALLEL:
│   ├── 02-backend reads shared-context + its prompt → codes → appends to shared-context
│   ├── 03-frontend reads shared-context + its prompt → codes → appends to shared-context
│   └── (05-qa skips — interval=5, this is cycle 4)
│
├── 6. Commit by ownership:
│   ├── 02-backend's changes in backend/ → commit
│   └── 03-frontend's changes in frontend/ → commit
│
├── 7. Detect rogue writes (files outside all ownerships) → revert
│
├── 8. Run PM (coordinator):
│   ├── Reads shared-context (what agents built)
│   ├── Reads agent logs
│   ├── Updates task sections in all agent prompts
│   ├── Updates session tracker
│   ├── Updates 99-me with human tasks
│   └── Commits prompt changes
│
├── 9. Merge auto/cycle-4 → main
├── 10. Push to origin
├── 11. Backup prompts, validate, update timestamps
│
└── Cycle 5 starts...
```

---

## Key Principles

### 1. Files > Chat
Agents communicate through files, not messages. This is cheaper, more reliable, and deterministic.

### 2. Standing Orders > Conversation
PM writes complete prompts, not incremental messages. Every cycle, every agent reads its full prompt from scratch.

### 3. One Agent, One Domain
No overlapping ownership. Backend doesn't touch frontend files. QA doesn't fix bugs. Clean boundaries prevent conflicts.

### 4. Script Handles Infrastructure
Git, backups, timestamps, usage tracking — all handled by `auto-agent.sh`. Agents focus on code.

### 5. PM is the Only Coordinator
Agents never talk to each other. Everything goes through PM via the shared context file. Hub-and-spoke, not mesh.

### 6. Humans Stay in the Loop
99-me captures what agents can't do. Session tracker captures what they did. You review, approve, and intervene as needed.
