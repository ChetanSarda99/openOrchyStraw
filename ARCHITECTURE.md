# Architecture — How the Orchestrator Works

## Cycle Flow

```
Cycle Start
│
├── git checkout main && git pull
├── Reset shared context (prompts/00-shared-context/context.md)
│   └── Inject progress trend from previous cycle (progress.json)
├── Create feature branch: auto/cycle-N-MMDD-HHMM
│
├── Run eligible agents IN PARALLEL (based on interval in agents.conf)
│   ├── Each agent gets: shared context + SESSION_TRACKER (tail 150) + their prompt
│   ├── Agents write code in their owned directories
│   └── Agents append status to shared context file
│
├── Commit by ownership (script commits, NOT agents)
│   ├── Each agent's changes committed separately
│   └── Rogue write detection (files outside all ownership → discarded)
│
├── Backup all prompts (rotate >7 days)
│
├── Run PM on the feature branch
│   ├── PM reads shared context (cross-agent awareness)
│   ├── PM reviews git log, GitHub issues
│   ├── PM updates TASK SECTIONS in worker prompts (Edit, not Write)
│   ├── PM updates its own prompt (status + milestones only)
│   ├── PM updates SESSION_TRACKER.txt
│   └── PM reads progress.json for velocity trends
│
├── Commit PM's prompt changes
├── Merge feature branch → main (--no-ff)
│   ├── Success → push + delete branch
│   ├── Push fail → pull --rebase → retry
│   └── Conflict → abort merge, keep branch for manual fix
│
├── Validate prompts (restore from backup if corrupted)
├── Auto-update ALL prompt timestamps + file counts (sed, not PM)
├── Save progress checkpoint (progress.json)
│   ├── File counts, commit count, timestamp
│   └── Detect regression (warn if >5 files lost)
├── Send notification
│
└── Brief pause → next cycle (no configurable delay)
```

## Why Parallel + PM (Not Sequential CEO/CTO)

### ChatDev-style (sequential):
```
CEO → CTO → Programmer → Tester → Documenter
     one at a time, each debates the last
     70% of tokens = "I agree, let's proceed"
```

### Our system (parallel + PM):
```
[Backend] [iOS] [Design]  ← all work simultaneously
         ↓
    Script commits by ownership (no conflicts)
         ↓
      [PM reviews]  ← sees everything, replans
         ↓
    New prompts for next cycle
```

**Why this is better:**
1. **3x faster** — parallel vs sequential
2. **Zero wasted tokens** — agents code, they don't debate
3. **PM is the bottleneck by design** — single point of coordination
4. **Git safety** — script controls all git operations
5. **Self-improving** — PM updates task sections based on what happened; script handles timestamps/counts

## Key Design Decisions

### Script Controls Git (Not Agents)
Agents never run git commands. The script:
- Creates branches
- Commits by file ownership
- Merges to main
- Pushes to origin

This eliminates race conditions, prevents agents from corrupting the branch, and ensures clean git history.

### File Ownership = No Conflicts
Each agent has explicit directory ownership. Agent 02-backend can only write to `backend/` and `prisma/`. If it writes to `ios/`, the rogue detection catches it and discards the change.

### Shared Context = Cheap Communication
Instead of agents chatting with each other (expensive, slow), they read/write a shared file. Backend agent appends "Added POST /api/users endpoint" → iOS agent reads it and uses the endpoint. Cost: ~100 tokens vs ~5000 tokens for a debate.

### PM Updates Task Sections (Not Full Rewrites)
After each cycle, PM reads:
- shared context (what agents reported)
- progress.json (velocity trends)
- GitHub issues (what's next)

Then uses the **Edit tool** to update only task-related sections ("What's DONE", "YOUR TASKS", status summaries) in each worker prompt. The script auto-updates timestamps and file counts via `sed` — PM doesn't touch those. This prevents PM from accidentally nuking tech stack, ownership, or design system sections.

## Safety Rails

| Safety | What It Does |
|--------|-------------|
| Feature branches | Work isolated from main until merge |
| Prompt backups | Every prompt saved before PM runs |
| Auto-restore | If PM corrupts a prompt (<50 lines), backup is restored |
| Rogue detection | Files outside ownership are discarded |
| PM branch recovery | If PM switches branches, script force-recovers |
| Progress checkpoint | Saves file counts per cycle to progress.json |
| Regression detection | Warns if >5 files lost between cycles |
| Usage tracking | check-usage.sh writes usage.txt (0-100), orchestrator pauses at 70%+ |
| Auto-update prompts | Script `sed`s timestamps + file counts — PM doesn't manage these |
| Backup rotation | Old backups + context archives deleted after 7 days |
| Windows notifications | Toast notifications for all key events |

## CLAUDE.md Integration

Every project should document the orchestrator in its `CLAUDE.md` file. This is auto-loaded by Claude Code, so all agents (and manual sessions) know the system exists without reading the script.

Key sections to include:
- **Quick commands** — `orchestrate`, `run`, `list`, `check-usage`
- **What the script handles** — timestamps, file counts, usage, qmd, git, rogue detection
- **What PM handles** — task sections, milestone status, session tracker, human actions
- **Monitoring** — log location, don't edit script while running

See `template/CLAUDE.md` for the full template.
