# OrchyStraw — App Architecture (The Real Product)

_Date: March 17, 2026_
_Status: DESIGN — not implemented_

---

## The Core Insight

OrchyStraw isn't a "developer tool that runs in terminal." It's a **project management app where the employees are AI agents.** The user is the CEO. They shouldn't need to know bash, git, or markdown to run their team.

---

## Where Things Live (Data Layer)

Everything currently lives in flat files inside the project repo. That works for v0.1 dogfooding but breaks as a real product. Here's the split:

### Three Storage Layers

```
┌─────────────────────────────────────────────────────────┐
│ LAYER 1: App Data (SQLite — ~/.orchystraw/orchystraw.db)│
│                                                         │
│ • User preferences & settings                          │
│ • Global knowledge registry (default tech decisions)   │
│ • Service catalog (all researched APIs/services)       │
│ • Anti-pattern registry (global, not project-specific) │
│ • Prompt template library                              │
│ • Architecture blueprints                              │
│ • Cost models                                          │
│ • License keys, usage stats                            │
│ • Agent performance history (across all projects)      │
│ • User's "approved vendors" list                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ LAYER 2: Project Data (SQLite — <project>/.orchystraw/) │
│                                                         │
│ • Project-specific tech decisions (overrides global)   │
│ • Project agents.conf (which agents, what intervals)   │
│ • Cycle history (who ran, what changed, when)          │
│ • Agent prompts (current + version history)            │
│ • Proposals inbox (worker → CTO pipeline)              │
│ • Project-specific patterns & anti-patterns            │
│ • Issue/task tracker (built-in, no GitHub required)    │
│ • File ownership map                                   │
│ • Shared context (current cycle state)                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ LAYER 3: Project Source (the actual code — any VCS)     │
│                                                         │
│ • User's source code (the thing being built)           │
│ • NOT managed by OrchyStraw — just pointed at          │
│ • VCS adapter: git, svn, mercurial, or NONE            │
│ • OrchyStraw reads from here, writes via agents        │
│ • The user's code never depends on OrchyStraw          │
└─────────────────────────────────────────────────────────┘
```

### Why This Matters

- **Layer 1** persists across projects. When user starts project #4, all their knowledge travels with them. This is the "institutional memory."
- **Layer 2** is project-specific. Project A uses Supabase, Project B uses Firebase — both are valid because each project has its own override.
- **Layer 3** is the user's code. OrchyStraw is a tool pointing at it, not embedded in it. User can delete OrchyStraw and their code is untouched.

### The Override Cascade

```
Global Default (Layer 1)
  └── Project Override (Layer 2)
        └── Agent Override (per-cycle context)
              └── User Override (manual "use this instead")
```

Example:
- Global: "Use Clerk for auth" (decision AUTH-001)
- Project B override: "Use Supabase Auth" (this project is full Supabase stack)
- Agent override: none (follows project decision)
- User override: "Actually use Firebase Auth for this feature" (one-time)

---

## VCS Abstraction (Git Is Optional)

### Current Problem
```
auto-agent.sh → hardcoded: git status, git diff, git log, gh issue
CTO prompt → "check recent commits"
QA prompt → "review recent commits"
PM prompt → "close GitHub issues"
```

Everything assumes git + GitHub. That's wrong for a product.

### Solution: VCS Adapter Layer

```
┌──────────────────────────────────┐
│        OrchyStraw Core           │
│                                  │
│  vcs.status()                    │
│  vcs.diff(since)                 │
│  vcs.log(n)                      │
│  vcs.save(message)    ← "commit" │
│  vcs.tag(name)                   │
│  issues.list()                   │
│  issues.create(title, body)      │
│  issues.close(id)                │
│  issues.comment(id, text)        │
└──────────┬───────────────────────┘
           │
     ┌─────┴─────┐
     │ VCS Adapter│
     └─────┬─────┘
           │
    ┌──────┼──────────┬──────────┐
    │      │          │          │
  ┌─┴─┐ ┌─┴──┐ ┌────┴───┐ ┌──┴───┐
  │git│ │svn │ │mercurial│ │ none │
  └───┘ └────┘ └────────┘ └──────┘

  Issue Adapters:
  ┌────────┐ ┌───────┐ ┌───────┐ ┌────────┐
  │ GitHub │ │GitLab │ │ Jira  │ │Built-in│
  └────────┘ └───────┘ └───────┘ └────────┘
```

### The "None" VCS Adapter
For users who just have a folder of files:
- `vcs.status()` → `find . -newer .orchystraw/last-cycle -type f` (files changed since last cycle)
- `vcs.diff()` → diff against `.orchystraw/snapshots/cycle-N/` (OrchyStraw snapshots the project between cycles)
- `vcs.save()` → copy current state to `.orchystraw/snapshots/cycle-N+1/`
- `vcs.log()` → read `.orchystraw/history.jsonl` (OrchyStraw's own change log)

### The "Built-in" Issue Tracker
For users without GitHub/GitLab:
- Issues stored in `<project>/.orchystraw/issues.db` (SQLite)
- PM creates/closes issues through OrchyStraw's API, not `gh` CLI
- UI shows issues in the dashboard
- Optional sync: push to GitHub/GitLab if configured

### Agent Prompts Become VCS-Agnostic
Instead of:
```
Check recent commits: git log --oneline -20
```
Prompts say:
```
Check recent changes: orchystraw changes --last 20
```
OrchyStraw CLI wraps the VCS adapter. Agents never touch git directly.

---

## User-Facing Features (The App Part)

### Settings Panel

```
┌─────────────────────────────────────────────┐
│ ⚙️  OrchyStraw Settings                     │
│                                             │
│ 📦 Knowledge Repositories                   │
│   ☑ Tech Stack Registry     [Configure →]  │
│   ☑ Service Catalog         [Configure →]  │
│   ☑ Code Patterns           [Configure →]  │
│   ☑ Anti-Patterns           [Configure →]  │
│   ☐ Prompt Templates        [Configure →]  │
│   ☐ Architecture Blueprints [Configure →]  │
│   ☐ Cost Models             [Configure →]  │
│                                             │
│ 🔗 Version Control                          │
│   Provider: [Git ▾]                         │
│   Remote:   [GitHub ▾]                      │
│   Repo URL: [.........................]     │
│   ☐ Auto-commit after each cycle            │
│   ☐ Auto-push after each cycle              │
│                                             │
│ 📋 Issue Tracker                             │
│   Provider: [Built-in ▾]                    │
│   ☐ Sync to GitHub Issues                   │
│   ☐ Sync to Jira                            │
│                                             │
│ 🤖 AI Provider                               │
│   Default: [Claude Code ▾]                  │
│   Per-agent overrides: [Configure →]        │
│                                             │
│ 💰 Token Budget                              │
│   Monthly limit: [$50     ]                 │
│   Per-cycle limit: [$2    ]                 │
│   ☑ Pause when budget exceeded              │
│                                             │
│ 🔔 Notifications                             │
│   ☐ Telegram  ☑ Desktop  ☐ Slack            │
│   Notify on: ☑ Cycle complete ☑ Error       │
│              ☐ Each agent  ☐ Proposals      │
└─────────────────────────────────────────────┘
```

### Project Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│ 🏗️  Momentum — Cycle 7 of 10                    [▶ Run] [⏸] │
│                                                             │
│ ┌──────────┬──────────┬──────────┬──────────┬──────────┐   │
│ │ Backend  │   Web    │   CTO    │    QA    │    PM    │   │
│ │ ✅ Done   │ ⏳ Active │ 💤 Skip  │ 💤 Skip  │ ⏳ Queue │   │
│ │ 2m 14s   │ 1m 02s   │ (cyc 8) │ (cyc 9) │ (last)  │   │
│ └──────────┴──────────┴──────────┴──────────┴──────────┘   │
│                                                             │
│ 📊 This Cycle                                               │
│ Files changed: 14  │  Tokens used: 42K  │  Cost: $0.38     │
│                                                             │
│ 📬 Proposals (2 pending)                                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 🟡 Backend: Use Astro for landing page (vs Next.js)     │ │
│ │    ↳ CTO will review cycle 8                            │ │
│ │ 🟡 Web: Use Shiki for code highlighting (vs Prism)      │ │
│ │    ↳ CTO will review cycle 8                            │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 📋 Issues: 12 open │ 3 closed this session │ 2 blocked      │
│ 📚 Knowledge: 8 decisions │ 14 patterns │ 5 anti-patterns   │
│                                                             │
│ [View Agents] [View Issues] [View Knowledge] [View Logs]   │
└─────────────────────────────────────────────────────────────┘
```

### Knowledge Browser

```
┌─────────────────────────────────────────────────────────────┐
│ 📚 Knowledge Browser                    [🔍 Search...]      │
│                                                             │
│ ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐    │
│ │ Global  │ │ Momentum │ │ Memo     │ │ OrchyStraw   │    │
│ └─────────┘ └──────────┘ └──────────┘ └──────────────┘    │
│                                                             │
│ Tech Decisions                                              │
│ ┌───────────────────────────────────────────────────────┐   │
│ │ AUTH-001  │ Clerk      │ Global   │ 2026-03-17       │   │
│ │ AUTH-002  │ Supabase   │ Memo     │ 2026-04-02  (!)  │   │
│ │ DB-001    │ Supabase   │ Global   │ 2026-03-17       │   │
│ │ STYLE-001 │ Tailwind   │ Global   │ 2026-03-18       │   │
│ └───────────────────────────────────────────────────────┘   │
│                                          (!) = overrides    │
│ Patterns (14)          Anti-Patterns (5)                    │
│ ├── auth/              ├── AP-001: Ownership drift          │
│ │   ├── clerk-next     ├── AP-002: Direct git commands      │
│ │   └── supabase-rls   ├── AP-003: Ghost slash commands     │
│ ├── api/               ├── AP-004: PM writes code           │
│ │   ├── error-handler  └── AP-005: No shared context        │
│ │   └── rate-limiting                                       │
│ └── database/                                               │
│     └── soft-delete                                         │
│                                                             │
│ [Export All] [Import from Template] [Share with Project →]  │
└─────────────────────────────────────────────────────────────┘
```

---

## The Database Schema

### Layer 1: Global (SQLite at ~/.orchystraw/orchystraw.db)

```sql
-- Global tech decisions (travel across projects)
CREATE TABLE tech_decisions (
    id          TEXT PRIMARY KEY,     -- 'AUTH-001'
    domain      TEXT NOT NULL,        -- 'auth'
    solution    TEXT NOT NULL,        -- 'Clerk'
    version     TEXT,                 -- '6.x'
    status      TEXT DEFAULT 'approved', -- approved|deprecated|superseded
    rationale   TEXT,                 -- why this was chosen
    cost_model  TEXT,                 -- JSON: pricing tiers
    decided_by  TEXT,                 -- 'CTO' or 'user'
    decided_at  DATETIME,
    metadata    JSON                  -- flexible extra data
);

-- Service catalog (all services ever evaluated)
CREATE TABLE services (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,        -- 'Supabase'
    category    TEXT NOT NULL,        -- 'database', 'auth', 'payments'
    free_tier   TEXT,                 -- '500MB, 50K MAU'
    pricing     JSON,                 -- tiered pricing
    sdk_quality TEXT,                 -- 'excellent', 'good', 'poor'
    auth_method TEXT,                 -- 'API key', 'OAuth', etc.
    notes       TEXT,
    last_evaluated DATETIME,
    url         TEXT
);

-- Anti-patterns (global lessons)
CREATE TABLE anti_patterns (
    id          TEXT PRIMARY KEY,     -- 'AP-001'
    title       TEXT NOT NULL,
    problem     TEXT NOT NULL,
    fix         TEXT NOT NULL,
    discovered  DATETIME,
    severity    TEXT DEFAULT 'medium' -- low|medium|high|critical
);

-- Code patterns (reusable across projects)
CREATE TABLE patterns (
    id          INTEGER PRIMARY KEY,
    domain      TEXT NOT NULL,        -- 'auth', 'api', 'database'
    name        TEXT NOT NULL,        -- 'clerk-next'
    code        TEXT NOT NULL,        -- the actual pattern/snippet
    language    TEXT,                 -- 'typescript', 'swift', 'bash'
    tested      BOOLEAN DEFAULT 0,
    projects_using TEXT,              -- JSON array of project names
    notes       TEXT
);

-- Architecture blueprints
CREATE TABLE blueprints (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,        -- 'Consumer iOS SaaS'
    stack       JSON NOT NULL,        -- full tech stack
    description TEXT,
    proven_in   TEXT                  -- which project validated this
);

-- Prompt templates
CREATE TABLE prompt_templates (
    id          INTEGER PRIMARY KEY,
    role        TEXT NOT NULL,        -- 'backend', 'ios', 'qa'
    name        TEXT NOT NULL,        -- 'backend-api-agent'
    template    TEXT NOT NULL,
    variables   JSON,                 -- placeholders to fill
    effectiveness_score REAL          -- 0-10, based on cycle results
);

-- User settings
CREATE TABLE settings (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL,
    updated_at  DATETIME
);

-- Agent performance history (across all projects)
CREATE TABLE agent_stats (
    id          INTEGER PRIMARY KEY,
    project     TEXT NOT NULL,
    agent_id    TEXT NOT NULL,
    cycle       INTEGER NOT NULL,
    tokens_in   INTEGER,
    tokens_out  INTEGER,
    cost_usd    REAL,
    files_changed INTEGER,
    duration_sec INTEGER,
    issues_closed INTEGER,
    errors      INTEGER,
    timestamp   DATETIME
);
```

### Layer 2: Project (SQLite at <project>/.orchystraw/project.db)

```sql
-- Project-specific tech decision overrides
CREATE TABLE tech_overrides (
    domain      TEXT PRIMARY KEY,     -- 'auth'
    decision_id TEXT,                 -- references global or NULL
    solution    TEXT NOT NULL,        -- 'Supabase Auth'
    reason      TEXT                  -- why override global
);

-- Built-in issue tracker
CREATE TABLE issues (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    title       TEXT NOT NULL,
    body        TEXT,
    status      TEXT DEFAULT 'open', -- open|in_progress|closed
    priority    TEXT DEFAULT 'medium',
    assigned_to TEXT,                -- agent id
    labels      JSON,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    closed_at   DATETIME,
    external_id TEXT,                -- GitHub issue #, Jira key, etc.
    external_url TEXT
);

-- Agent config (replaces agents.conf flat file)
CREATE TABLE agents (
    id          TEXT PRIMARY KEY,     -- '06-backend'
    label       TEXT NOT NULL,        -- 'Backend Developer'
    prompt_path TEXT NOT NULL,        -- relative path to prompt file
    ownership   JSON NOT NULL,        -- ["scripts/", "src/core/"]
    interval    INTEGER DEFAULT 1,
    model       TEXT,                 -- override default AI model
    timeout_sec INTEGER DEFAULT 600,
    enabled     BOOLEAN DEFAULT 1,
    last_run    DATETIME,
    total_runs  INTEGER DEFAULT 0
);

-- Cycle history
CREATE TABLE cycles (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    cycle_num   INTEGER NOT NULL,
    started_at  DATETIME,
    ended_at    DATETIME,
    total_tokens INTEGER,
    total_cost  REAL,
    agents_run  JSON,                -- ["06-backend", "11-web"]
    summary     TEXT,                -- PM's cycle summary
    status      TEXT DEFAULT 'running' -- running|completed|failed|paused
);

-- Proposals pipeline
CREATE TABLE proposals (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id    TEXT NOT NULL,
    domain      TEXT NOT NULL,
    problem     TEXT NOT NULL,
    options     JSON NOT NULL,       -- [{name, pros, cons, cost}]
    recommendation TEXT,
    status      TEXT DEFAULT 'pending', -- pending|approved|rejected
    cto_decision TEXT,               -- CTO's response
    decided_at  DATETIME,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- VCS config
CREATE TABLE vcs_config (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL
    -- 'provider' = 'git'|'svn'|'mercurial'|'none'
    -- 'remote' = 'github'|'gitlab'|'bitbucket'|'none'
    -- 'repo_url' = '...'
    -- 'auto_commit' = '0'|'1'
    -- 'auto_push' = '0'|'1'
);

-- File snapshots (for VCS=none mode)
CREATE TABLE snapshots (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    cycle_num   INTEGER NOT NULL,
    file_path   TEXT NOT NULL,
    hash        TEXT NOT NULL,       -- SHA256 of file contents
    size_bytes  INTEGER,
    captured_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## VCS Adapter: Implementation Plan

### orchystraw CLI (new commands)

```bash
# VCS-agnostic commands that agents use instead of raw git
orchystraw changes --last 20        # replaces: git log --oneline -20
orchystraw diff                     # replaces: git diff
orchystraw diff --since cycle-5     # replaces: git diff HEAD~5
orchystraw status                   # replaces: git status
orchystraw save "message"           # replaces: git add -A && git commit -m "..."
orchystraw tag v0.1.0               # replaces: git tag v0.1.0

# Issue tracker (built-in or synced)
orchystraw issue list               # replaces: gh issue list
orchystraw issue create "title"     # replaces: gh issue create
orchystraw issue close 15           # replaces: gh issue close 15
orchystraw issue assign 15 backend  # no gh equivalent

# Knowledge queries
orchystraw knowledge search "auth"  # search all registries
orchystraw knowledge decide AUTH    # show current AUTH decision
orchystraw knowledge propose        # interactive proposal flow

# Project init
orchystraw init                     # creates .orchystraw/ + project.db
orchystraw init --from blueprint "Consumer iOS SaaS"  # from template
orchystraw init --import-knowledge ~/Projects/_shared-knowledge/
```

### How Agents Interact

Current (hardcoded git):
```
# In auto-agent.sh
git diff HEAD~1 --stat
gh issue list --state open
git add -A && git commit -m "cycle $N"
```

Future (adapter):
```
# In auto-agent.sh
orchystraw diff --since last-cycle
orchystraw issue list --status open
orchystraw save "cycle $N: $SUMMARY"
```

The adapter reads `vcs_config` from project.db and routes to the right backend.

---

## Onboarding Flow (New User Experience)

```
$ orchystraw init

👋 Welcome to OrchyStraw!

What kind of project are you building?
  1. Web app (Next.js, React, etc.)
  2. Mobile app (iOS/Android)
  3. CLI tool
  4. API/Backend service
  5. Other / I'll configure manually

> 1

Do you use version control?
  1. Git (GitHub)
  2. Git (GitLab)
  3. Git (other remote)
  4. Git (local only, no remote)
  5. No version control — OrchyStraw will track changes for you

> 5

Do you want a built-in issue tracker, or sync with an external one?
  1. Built-in (recommended for getting started)
  2. GitHub Issues
  3. GitLab Issues
  4. Jira
  5. Linear

> 1

Setting up your team...
✅ Created: PM (coordinator)
✅ Created: Backend Developer
✅ Created: Frontend Developer
✅ Created: QA Engineer
✅ Created: CTO (reviews tech decisions)

📚 Importing global knowledge (8 tech decisions, 14 patterns)...
✅ Imported. Your agents will build on your existing research.

🚀 Ready! Run `orchystraw start` to begin your first cycle.
   Or open the dashboard: `orchystraw ui`
```

---

## Migration Path (v0.1 → v1.0)

### v0.1 (current): Bash + flat files
- agents.conf (text file)
- Markdown prompts in prompts/
- Git + GitHub hardcoded
- No UI

### v0.5: CLI + SQLite (migration layer)
- `orchystraw init` creates .orchystraw/project.db
- Imports existing agents.conf → agents table
- Imports existing prompts (still markdown, now version-tracked in DB)
- VCS adapter wraps existing git calls
- Built-in issue tracker available (optional)
- `orchystraw ui` opens web dashboard (localhost)

### v1.0: Tauri desktop app
- Full GUI: settings, dashboard, knowledge browser
- SQLite is the source of truth
- Markdown prompts still exist (agents read them) but managed via UI
- VCS adapter fully abstracted
- Cross-project knowledge sharing built into app
- Onboarding wizard

### Key Principle: Markdown Prompts Never Go Away
Agents still READ markdown prompts. That's the interface.
But the app GENERATES and VERSION-TRACKS them via the database.
Power users can still hand-edit prompts. The app syncs both ways.
