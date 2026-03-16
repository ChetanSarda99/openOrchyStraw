# Workflow — Complete Orchestrator Reference

How the multi-agent system works, end to end.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AUTO-AGENT ORCHESTRATOR v3                      │
│                                                                     │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│   │ Backend  │  │ Frontend │  │  Design  │  │    QA    │          │
│   │  Agent   │  │  Agent   │  │  Agent   │  │  Agent   │          │
│   │ (02-XX)  │  │ (03-XX)  │  │ (04-XX)  │  │ (05-XX)  │          │
│   └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│        │              │              │              │               │
│        └──────────────┴──────┬───────┴──────────────┘               │
│                              │                                      │
│                     ┌────────▼────────┐                             │
│                     │   PM (01-pm)    │                             │
│                     │  Coordinator    │                             │
│                     └────────┬────────┘                             │
│                              │                                      │
│              ┌───────────────┼───────────────┐                      │
│              │               │               │                      │
│       ┌──────▼──────┐ ┌─────▼──────┐ ┌──────▼──────┐              │
│       │  Git Ops    │ │  Backups   │ │  Validate   │              │
│       │  (script)   │ │  (script)  │ │  (script)   │              │
│       └─────────────┘ └────────────┘ └─────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

**Key principle:** Workers code in parallel → script commits by ownership → PM reviews + updates tasks → merge → repeat.

---

## Cycle Lifecycle (One Complete Loop)

```
╔═══════════════════════════════════════════════════════════════════════╗
║                         CYCLE N                                      ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  ┌─ PRE-FLIGHT ───────────────────────────────────────────────────┐  ║
║  │ 1. check-usage.sh → usage.txt (pause if ≥70%)                 │  ║
║  │ 2. git checkout main && git pull                               │  ║
║  │ 3. Archive old context → context-cycle-(N-1).md                │  ║
║  │ 4. Reset shared context (inject progress from last cycle)      │  ║
║  │ 5. Create feature branch: auto/cycle-N-MMDD-HHMM              │  ║
║  │ 6. qmd update (+ qmd embed on QA cycles if installed)         │  ║
║  └────────────────────────────────────────────────────────────────┘  ║
║                              │                                        ║
║                              ▼                                        ║
║  ┌─ WORKERS (parallel) ──────────────────────────────────────────┐  ║
║  │                                                                │  ║
║  │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐      │  ║
║  │  │ 02-back │   │ 03-ios  │   │ 04-dsgn │   │ 05-qa   │      │  ║
║  │  │ every 1 │   │ every 1 │   │ every 1 │   │ every 5 │      │  ║
║  │  └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘      │  ║
║  │       │              │              │              │           │  ║
║  │  Each agent receives:                                          │  ║
║  │  ┌──────────────────────────────────────────────────────┐     │  ║
║  │  │ 1. Shared context (what other agents built/need)     │     │  ║
║  │  │ 2. SESSION_TRACKER tail 150 (cross-cycle history)    │     │  ║
║  │  │ 3. Their prompt (tasks, ownership, standards)        │     │  ║
║  │  │ 4. "Append your status to shared context when done"  │     │  ║
║  │  └──────────────────────────────────────────────────────┘     │  ║
║  └────────────────────────────────────────────────────────────────┘  ║
║                              │                                        ║
║                              ▼                                        ║
║  ┌─ COMMIT BY OWNERSHIP ─────────────────────────────────────────┐  ║
║  │ For each agent:                                                │  ║
║  │   git add [owned-dirs] → git commit -m "feat(agent): ..."     │  ║
║  │   Rogue detection: files outside ALL ownership → discarded    │  ║
║  └────────────────────────────────────────────────────────────────┘  ║
║                              │                                        ║
║                              ▼                                        ║
║  ┌─ PM REVIEW ───────────────────────────────────────────────────┐  ║
║  │ 1. Backup all prompts → 00-backup/cycle-YYYYMMDD-HHMM/       │  ║
║  │ 2. PM reads: shared context + agent logs + progress.json      │  ║
║  │ 3. PM checks GitHub (issues, milestones)                      │  ║
║  │ 4. PM updates TASK SECTIONS in worker prompts (Edit, not      │  ║
║  │    Write — keeps tech stack, ownership, standards intact)      │  ║
║  │ 5. PM updates its own prompt (status + milestones)            │  ║
║  │ 6. PM updates SESSION_TRACKER (what shipped)                  │  ║
║  │ 7. PM updates 99-actions (human action items)                 │  ║
║  │ 8. Script force-recovers if PM switched branches              │  ║
║  │ 9. Script commits PM's changes                                │  ║
║  └────────────────────────────────────────────────────────────────┘  ║
║                              │                                        ║
║                              ▼                                        ║
║  ┌─ POST-MERGE ──────────────────────────────────────────────────┐  ║
║  │ 1. Merge feature branch → main (--no-ff)                      │  ║
║  │    • Push fail? → pull --rebase → retry                       │  ║
║  │    • Conflict? → abort, keep branch for manual fix            │  ║
║  │ 2. Validate prompts (restore from backup if <50 lines)        │  ║
║  │ 3. Save progress checkpoint (progress.json)                   │  ║
║  │    • Detect regression (warn if >5 files lost)                │  ║
║  │ 4. Auto-update ALL prompts via sed:                           │  ║
║  │    • **Date:** timestamps                                     │  ║
║  │    • File counts (backend, frontend, components, total)       │  ║
║  │ 5. Commit auto-updates + push                                │  ║
║  │ 6. Delete merged branch                                       │  ║
║  │ 7. Notify (Windows toast + log)                               │  ║
║  │ 8. 5s pause → next cycle                                      │  ║
║  └────────────────────────────────────────────────────────────────┘  ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## File System Layout

```
project/
│
├── CLAUDE.md                          ← Project config (auto-loaded by Claude Code)
├── .mcp.json                          ← MCP servers (context7, qmd, etc.)
│
├── scripts/
│   ├── auto-agent.sh                  ← The orchestrator (793 lines)
│   ├── agents.conf                    ← Agent registry (who, what, where)
│   └── check-usage.sh                 ← API rate limit checker → usage.txt
│
├── prompts/
│   ├── 00-backup/                     ← Prompt snapshots per cycle (7-day rotation)
│   │   └── cycle-YYYYMMDD-HHMM/      ← One dir per backup
│   │       ├── 02-backend-dev.txt
│   │       ├── 03-ios-dev.txt
│   │       └── ...
│   │
│   ├── 00-session-tracker/
│   │   └── SESSION_TRACKER.txt        ← Long-term changelog (survives prompt rewrites)
│   │
│   ├── 00-shared-context/
│   │   ├── context.md                 ← Inter-agent communication (reset each cycle)
│   │   ├── context-cycle-N.md         ← Archived contexts (auto-cleaned after 7 days)
│   │   ├── usage.txt                  ← API status: 0/80/90/100
│   │   └── progress.json              ← File counts + velocity (cycle-over-cycle)
│   │
│   ├── 01-pm/
│   │   ├── 01-project-manager.txt     ← PM prompt (self-updating)
│   │   └── logs/
│   │       ├── orchestrator.log       ← Master log (all cycles)
│   │       └── 01-pm-YYYYMMDD-*.log   ← Per-run PM output
│   │
│   ├── 02-backend/
│   │   ├── 02-backend-dev.txt         ← Backend agent prompt
│   │   └── logs/
│   │       └── 02-backend-*.log       ← Per-run output
│   │
│   ├── 03-frontend/
│   │   ├── 03-frontend-dev.txt        ← Frontend agent prompt
│   │   └── logs/
│   │
│   ├── 04-design/
│   │   ├── 04-design-system.txt       ← Design agent prompt
│   │   └── logs/
│   │
│   ├── 05-qa/
│   │   ├── 05-qa-review.txt           ← QA agent prompt (read-only reviewer)
│   │   ├── reports/                   ← QA writes findings here
│   │   └── logs/
│   │
│   └── 99-me/
│       └── 99-actions.txt             ← Human action items (any agent can append)
│
└── [source code directories]          ← What agents actually build
```

---

## Data Flow Between Cycles

```
                    CYCLE N                              CYCLE N+1
              ┌──────────────────┐                 ┌──────────────────┐
              │                  │                 │                  │
              │  Agents work     │                 │  Agents work     │
              │       │          │                 │       │          │
              │       ▼          │                 │       ▼          │
              │  context.md      │──── archive ───▶│  context.md      │
              │  (agent status)  │  context-N.md   │  (fresh reset)   │
              │       │          │                 │       │          │
              │       ▼          │                 │       ▼          │
              │  PM reviews      │                 │  PM reviews      │
              │       │          │                 │       │          │
              │       ▼          │                 │       ▼          │
              │  SESSION_TRACKER ├────persists─────▶  SESSION_TRACKER │
              │  (append-only)   │                 │  (grows forever) │
              │       │          │                 │       │          │
              │       ▼          │                 │       ▼          │
              │  progress.json   ├────persists─────▶  progress.json   │
              │  (overwritten)   │  (prev values   │  (new snapshot)  │
              │                  │   injected into  │                  │
              │                  │   context reset) │                  │
              │       │          │                 │                  │
              │       ▼          │                 │                  │
              │  Agent prompts   ├──── tasks ──────▶  Agent prompts   │
              │  (PM edits tasks │   updated by PM │  (new tasks,     │
              │   script updates │   + script sed   │   fresh counts)  │
              │   dates/counts)  │                 │                  │
              └──────────────────┘                 └──────────────────┘

What resets:          context.md (archived first)
What persists:        SESSION_TRACKER, progress.json, prompts (updated), 99-actions
What rotates:         backups (7 days), context archives (7 days), old logs
```

---

## Agent Input Assembly

Every agent run pipes a composite prompt to `claude -p`. Here's what each agent sees:

```
┌──────────────────────────────────────────────────────────┐
│                    AGENT INPUT (piped to claude -p)       │
│                                                          │
│  ┌─ Section 1: Shared Context ─────────────────────────┐ │
│  │ "## SHARED CONTEXT (what other agents built/need)"  │ │
│  │ Full contents of context.md (inter-agent comms)     │ │
│  │ Usage status, backend/iOS/design/QA status sections │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Section 2: Cross-Cycle History ────────────────────┐ │
│  │ "## CROSS-CYCLE HISTORY (read-only)"                │ │
│  │ Last 150 lines of SESSION_TRACKER.txt               │ │
│  │ What shipped in ALL previous cycles                 │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Section 3: Agent Prompt ───────────────────────────┐ │
│  │ The full agent prompt file (200-380 lines)          │ │
│  │ Has: context, tech stack, done work, tasks,         │ │
│  │      code standards, file ownership, auto-cycle     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Section 4: Post-Work Instructions ─────────────────┐ │
│  │ "Append what you built to context.md"               │ │
│  │ Format instructions + examples                      │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**PM gets a different input:**

```
┌──────────────────────────────────────────────────────────┐
│                    PM INPUT (piped to claude -p)          │
│                                                          │
│  ┌─ Section 1: Autonomous Mode Header ─────────────────┐ │
│  │ "You are running FULLY AUTONOMOUSLY in cycle N"     │ │
│  │ "Take ALL actions yourself. Never ask."             │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Section 2: Registered Agents ──────────────────────┐ │
│  │ Agent list from agents.conf (id, prompt, ownership) │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Section 3: PM Prompt ──────────────────────────────┐ │
│  │ Full PM prompt file (150-300 lines)                 │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Section 4: Cycle N Tasks (7 Steps) ────────────────┐ │
│  │ Step 0: Read shared context + progress.json         │ │
│  │ Step 1: Review what agents built (git log, status)  │ │
│  │ Step 2: Commit remaining uncommitted work           │ │
│  │ Step 3: Check GitHub (milestones, issues)           │ │
│  │ Step 4: Update TASK SECTIONS (Edit, not Write)      │ │
│  │ Step 5: Update own prompt (status only)             │ │
│  │ Step 6: Update SESSION_TRACKER (what shipped)       │ │
│  │ Step 7: Update 99-actions (human items)             │ │
│  │                                                      │ │
│  │ GIT SAFETY RULES: never checkout/switch/merge/push  │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## Safety Systems

```
┌─────────────────────────────────────────────────────────────────┐
│                        SAFETY LAYERS                             │
│                                                                   │
│  ┌─ Layer 1: File Ownership ───────────────────────────────────┐ │
│  │                                                              │ │
│  │  agents.conf defines strict boundaries:                      │ │
│  │                                                              │ │
│  │  02-backend  → backend/ prisma/                              │ │
│  │  03-ios      → ios/ !ios/Components/ !ios/Theme.swift        │ │
│  │  04-design   → ios/Components/ ios/Theme.swift               │ │
│  │  05-qa       → prompts/05-qa/reports/ (or "none")            │ │
│  │  01-pm       → prompts/ docs/ (via script, not agents.conf)  │ │
│  │                                                              │ │
│  │  Exclusions: !path syntax carves out subfolders              │ │
│  │  "none" = read-only (QA can review but not modify code)      │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─ Layer 2: Rogue Write Detection ───────────────────────────┐  │
│  │                                                              │ │
│  │  After all agents finish:                                    │ │
│  │  1. Scan ALL unstaged changes                                │ │
│  │  2. Check each file against ALL agents' ownership            │ │
│  │  3. Files matching no agent → git checkout (discard)         │ │
│  │  4. Log warning with file path + sizes                       │ │
│  │                                                              │ │
│  │  Catches: agent editing auto-agent.sh, config files,         │ │
│  │           another agent's directories                        │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─ Layer 3: Git Safety ──────────────────────────────────────┐  │
│  │                                                              │ │
│  │  Agents CANNOT run git commands (enforced by prompt rules):  │ │
│  │  ✗ git checkout, switch, merge, push, reset, rebase          │ │
│  │  ✓ git add, commit, status, log, diff (allowed)              │ │
│  │                                                              │ │
│  │  Script handles ALL branch management:                       │ │
│  │  • Creates feature branch per cycle                          │ │
│  │  • Commits by ownership (not by agent)                       │ │
│  │  • Merges to main (--no-ff)                                  │ │
│  │  • PM branch recovery (if PM switches, force back)           │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─ Layer 4: Prompt Validation ───────────────────────────────┐  │
│  │                                                              │ │
│  │  After merge, check every prompt:                            │ │
│  │  • < 50 lines? → CORRUPTED → restore from backup            │ │
│  │  • Backup rotation: 7-day window, auto-cleanup               │ │
│  │                                                              │ │
│  │  PM Edit-not-Write rule:                                     │ │
│  │  • PM uses Edit tool for task sections only                  │ │
│  │  • Script auto-updates dates + file counts via sed           │ │
│  │  • Prevents PM from nuking tech stack, ownership, standards  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─ Layer 5: Usage & Regression Guards ───────────────────────┐  │
│  │                                                              │ │
│  │  Usage:                                                      │ │
│  │  • check-usage.sh probes API → writes usage.txt (0-100)     │ │
│  │  • ≥70% → orchestrator pauses (re-checks every 60s)         │ │
│  │                                                              │ │
│  │  Regression:                                                 │ │
│  │  • progress.json tracks file counts per cycle                │ │
│  │  • If >5 files lost → warning + notification                 │ │
│  │  • Prevents silent deletion of project files                 │ │
│  │                                                              │ │
│  │  Failure handling:                                           │ │
│  │  • ALL agents fail → skip PM, retry in 30s                  │ │
│  │  • 3 consecutive empty cycles → auto-stop                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## agents.conf Format

```
# AGENT_ID | PROMPT_FILE | FILE_OWNERSHIP | CYCLE_INTERVAL | LABEL
#
# CYCLE_INTERVAL:
#   0 = coordinator (runs LAST, after all workers)
#   1 = every cycle
#   5 = every 5th cycle
#
# FILE_OWNERSHIP:
#   Space-separated dirs the agent may write to
#   !path = exclusion (carve out subfolders for another agent)
#   "none" = read-only (for QA / reviewers)

# ── Coordinator (runs after all workers) ──
01-pm      | prompts/01-pm/01-pm.txt       | prompts/ docs/            | 0 | PM Coordinator

# ── Workers (run in parallel) ──
02-backend | prompts/02-backend/02-be.txt  | backend/ prisma/           | 1 | Backend Dev
03-ios     | prompts/03-ios/03-ios.txt     | ios/ !ios/Components/      | 1 | iOS Dev
04-design  | prompts/04-design/04-ds.txt   | ios/Components/ ios/Theme  | 1 | Design
05-qa      | prompts/05-qa/05-qa.txt       | none                       | 5 | QA Engineer
```

**Ownership resolution order:**
1. Check if file matches any `!exclusion` → skip that agent
2. Check if file matches any `owned-dir/` → assign to that agent
3. File matches no agent → rogue write → discarded

---

## Shared Context Protocol

Each cycle, `context.md` is the communication bus:

```
CYCLE START
│
├── Script resets context.md with:
│   ├── Cycle number + timestamp
│   ├── Usage status (from usage.txt)
│   ├── Progress trend (from previous progress.json)
│   └── Empty sections: Backend / iOS / Design / QA / Blockers / Notes
│
├── Worker agents (parallel):
│   ├── READ context.md at start (see what others need)
│   └── APPEND to their section before finishing:
│       "- Added POST /api/notes/batch (accepts array of note IDs)"
│       "- NEED: GET /api/search endpoint from backend"
│       "- BREAKING: Changed theme spacing from 16 to 14"
│
├── PM agent (after workers):
│   └── READS context.md to understand what happened
│       Uses this to write accurate task updates
│
└── Script archives context.md → context-cycle-N.md
    (cleaned up after 7 days)
```

**Cross-cycle memory lives in SESSION_TRACKER.txt** (not context.md):

```
SESSION_TRACKER.txt (append-only, persists forever)
├── FILES — inventory of all files in the project
├── MILESTONE DASHBOARD — open/closed counts per phase
├── CODEBASE SIZE — file counts by language
├── WHAT SHIPPED — per-cycle changelog (PM appends each cycle)
│   ├── Cycle 1 — [timestamp]
│   │   ├── Backend: Added auth routes, Prisma schema
│   │   ├── iOS: Built 12 screens, navigation
│   │   └── QA: Found 5 issues, 3 fixed same cycle
│   ├── Cycle 2 — [timestamp]
│   │   └── ...
│   └── ...
├── DECISIONS LOG — architectural choices
└── NEXT CYCLE PRIORITIES — what PM plans to assign
```

---

## Progress Tracking

```
progress.json (overwritten each cycle)
{
  "cycle": 11,
  "timestamp": "2026-03-15 14:12:00",
  "backend_files": 170,
  "frontend_files": 170,
  "test_files": 35,
  "total_files": 340,
  "commits": 4
}

                    Cycle-over-cycle comparison
                    ┌────────────────────────────┐
  Cycle 1:  88 TS │████████░░░░░░░░░░░░░░░░░░░░│  120 Swift
  Cycle 5: 130 TS │████████████░░░░░░░░░░░░░░░░│  145 Swift
  Cycle 11: 170 TS│████████████████░░░░░░░░░░░░│  170 Swift
                    └────────────────────────────┘

  Regression alert: total_files drops by >5 → warning + notification
```

---

## Prompt Auto-Update (Step 5.6)

After merge, the script updates ALL prompts mechanically — PM doesn't do this:

```
For each prompt file:
│
├── sed "s/**Date:** .*/**Date:** March 15, 2026 — 14:30/"
│
├── sed "s/[0-9]* TypeScript source + [0-9]* test files = [0-9]* total/
│        135 TypeScript source + 35 test files = 170 total/"
│
├── sed "s/[0-9]* Swift files/170 Swift files/"
│
├── sed "s/[0-9]* components/51 components/"
│
└── sed "s/Total:.*source files/Total: 340 source files/"

Then: git add prompts/ && git commit -m "chore: auto-update all prompts"
```

**Why the script does this (not PM):**
- PM got file counts wrong constantly (hallucinated numbers)
- PM sometimes overwrote entire prompts, nuking tech stack + ownership sections
- Mechanical task → script is 100% reliable, zero tokens

---

## Error Handling

```
                         ERROR SCENARIOS
┌────────────────────┬──────────────────────────────────────┐
│ Scenario           │ What Happens                         │
├────────────────────┼──────────────────────────────────────┤
│ Agent fails        │ Exit code logged, other agents       │
│                    │ continue. PM still runs.             │
├────────────────────┼──────────────────────────────────────┤
│ ALL agents fail    │ Skip PM. Retry in 30s.               │
│                    │ 3 consecutive → auto-stop + notify.  │
├────────────────────┼──────────────────────────────────────┤
│ PM switches branch │ Script detects, force-checkout back  │
│                    │ to feature branch. Log WARNING.      │
├────────────────────┼──────────────────────────────────────┤
│ Merge conflict     │ Abort merge. Keep feature branch.    │
│                    │ Human fixes manually.                │
├────────────────────┼──────────────────────────────────────┤
│ Push fails         │ Pull --rebase, retry push once.      │
│                    │ If still fails, keep local.          │
├────────────────────┼──────────────────────────────────────┤
│ Prompt corrupted   │ Validate (<50 lines = corrupted).    │
│ (PM nuked it)      │ Auto-restore from 00-backup/.        │
├────────────────────┼──────────────────────────────────────┤
│ Rogue write        │ Files outside ownership → discarded  │
│                    │ via git checkout. Log warning.        │
├────────────────────┼──────────────────────────────────────┤
│ Usage ≥70%         │ Pause orchestrator. Re-check every   │
│                    │ 60s. Resume when usage drops.         │
├────────────────────┼──────────────────────────────────────┤
│ File regression    │ >5 files lost → warning + notify.    │
│ (>5 files lost)    │ Does NOT auto-stop (could be legit). │
└────────────────────┴──────────────────────────────────────┘
```

---

## Setup Checklist (New Project)

```
1. Copy template/           → your-project/
2. Run bootstrap-prompt.txt → generates all config
3. Verify:

   ✓ CLAUDE.md exists with orchestrator section
   ✓ scripts/agents.conf has all agents + correct ownership
   ✓ scripts/auto-agent.sh is executable
   ✓ scripts/check-usage.sh is executable
   ✓ prompts/<each-agent>/<prompt>.txt exists (>50 lines)
   ✓ prompts/00-shared-context/context.md exists
   ✓ prompts/00-shared-context/usage.txt exists (contains "0")
   ✓ prompts/00-session-tracker/SESSION_TRACKER.txt exists
   ✓ prompts/99-me/99-actions.txt exists
   ✓ prompts/00-backup/.gitkeep exists
   ✓ .mcp.json exists (at least context7)
   ✓ No agent owns overlapping directories
   ✓ QA agent has "none" or report-only ownership

4. Run:  ./scripts/auto-agent.sh list          # verify agents
5. Run:  ./scripts/auto-agent.sh orchestrate   # start building
```

---

## Quick Reference

| Command | What |
|---------|------|
| `./scripts/auto-agent.sh orchestrate` | Run 10 cycles |
| `./scripts/auto-agent.sh orchestrate 5` | Run 5 cycles |
| `./scripts/auto-agent.sh run 02-backend` | Single agent, one shot |
| `./scripts/auto-agent.sh list` | Show configured agents |
| `./scripts/check-usage.sh` | Check API rate limits |
| `tail -f prompts/01-pm/logs/orchestrator.log` | Watch live |
| `ls prompts/00-backup/` | See backups |
| `cat prompts/00-shared-context/progress.json` | Current stats |
| `cat prompts/00-shared-context/usage.txt` | API status |
| `cat prompts/99-me/99-actions.txt` | Human TODOs |

---

*Built from 15+ production cycles — 441 source files, 1877 tests, 0 data-loss incidents.*
