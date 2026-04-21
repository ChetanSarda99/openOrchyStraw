# OrchyStraw — App Architecture (The Real Product)

_Date: March 17, 2026_
_Status: DESIGN — not implemented_

---

## The Core Insight

OrchyStraw isn't a "developer tool that runs in terminal." It's a **startup in a box.**

### The Org Chart

```
┌──────────────────────────────────────────────┐
│              THE FOUNDERS                     │
│                                               │
│  👤 User (Founder)    🤖 Front Agent (Co-F)  │
│  Has the vision.      Translates vision →     │
│  Makes final calls.   execution. Manages      │
│  Talks naturally.     the entire team.        │
│                                               │
│  "I want a fitness    "Got it. Let me brief   │
│   app that tracks      the team, set up the   │
│   knee-safe exercises" architecture, and get   │
│                        cycles running."        │
└──────────────────┬───────────────────────────┘
                   │
                   │ The Co-Founder manages ↓
                   │
┌──────────────────┴───────────────────────────┐
│              THE EXECUTIVE TEAM               │
│                                               │
│  🤖 CEO Agent        → Vision, strategy,      │
│                        market positioning,     │
│                        revenue model           │
│  🤖 CTO Agent        → Architecture, tech     │
│                        decisions, standards,   │
│                        knowledge curation      │
│  🤖 PM Agent         → Coordination, backlog, │
│                        agent prompts, tracking │
└──────────────────┬───────────────────────────┘
                   │
                   │ Executives direct ↓
                   │
┌──────────────────┴───────────────────────────┐
│              THE WORKERS                      │
│                                               │
│  🤖 Backend  🤖 Frontend  🤖 iOS  🤖 QA      │
│  🤖 Security  🤖 Web  🤖 Pixel  🤖 Brand     │
│                                               │
│  Each owns specific files. Builds, tests,     │
│  proposes tech decisions to CTO, reports       │
│  status to PM. Never steps on another's turf. │
└───────────────────────────────────────────────┘
```

### Why This Matters for the Product

The user NEVER manages agents directly. They don't drag-and-drop agent cards or tweak intervals in a settings panel. They talk to their **co-founder** — the front agent — who:

1. Understands what the user wants (natural language)
2. Briefs the CEO on strategy
3. Tells the PM to plan the work
4. Kicks off cycles
5. Reports back: "Here's what we shipped today"

The dashboard exists for **transparency**, not management. It's like a founder checking their company's Slack — you can see what's happening, but you trust your co-founder to run it.

### What the Founders Do vs What the Team Does

| Task | Who Does It |
|------|-------------|
| "Build me a fitness app" | Founder (user) says it |
| Translate into project plan, agent prompts, backlog | Co-founder (front agent) |
| Market research, competitive positioning | CEO agent |
| Architecture, tech stack decisions | CTO agent |
| Sprint planning, task assignment, status tracking | PM agent |
| Writing code, building features | Worker agents |
| Final approval on major decisions | Founder (user), with co-founder recommendation |

### The Co-Founder's Unique Role

The front agent (co-founder) is NOT another agent in auto-agent.sh. It's the **always-on interface** between the human founder and the AI team. It:

- Has context the agents don't (user's preferences, mood, priorities, budget)
- Can override any agent's decision ("User changed their mind, pivot to X")
- Summarizes progress without drowning the founder in details
- Escalates only what matters ("CTO wants to use Firebase but it's $200/mo — your call")
- Remembers cross-project history (the institutional memory layer)

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

### Project Dashboard (Founder's View)

The dashboard is a **transparency layer** — not a control panel. The founder glances at it like checking Slack. The co-founder runs the team.

```
┌─────────────────────────────────────────────────────────────┐
│ 🏗️  my-other-app                                                │
│                                                             │
│ 💬 Co-founder: "Backend shipped auth + payments today.      │
│    CTO picked Clerk over Supabase Auth — better iOS SDK.    │
│    Web agent is building the landing page. QA runs tonight. │
│    One thing needs your input ↓"                            │
│                                                             │
│ ⚡ Needs Your Input (1)                                      │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ CTO recommends Firebase for push notifications ($75/mo  │ │
│ │ at 10K users). Alternative: free OneSignal but worse DX.│ │
│ │ [Go with Firebase] [Use OneSignal] [Let CTO decide]     │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 📊 Today's Progress                                         │
│ ┌───────────────────────────────────────────────────────┐   │
│ │ Cycle 7/10  │  14 files changed  │  $0.38 spent      │   │
│ │ 3 issues closed  │  2 tech decisions made             │   │
│ └───────────────────────────────────────────────────────┘   │
│                                                             │
│ 🧑‍💼 Team Activity                                           │
│ Backend ████████░░ 80%  │  Web ████░░░░░░ 40%              │
│ CTO ██████████ done     │  QA scheduled tonight            │
│                                                             │
│ [💬 Talk to Co-founder] [📋 Backlog] [📚 Knowledge] [📜 Log]│
└─────────────────────────────────────────────────────────────┘
```

The primary action is always **"Talk to Co-founder"** — that's the main interface. Everything else is optional drill-down for when the founder wants to see under the hood.

### Knowledge Browser

```
┌─────────────────────────────────────────────────────────────┐
│ 📚 Knowledge Browser                    [🔍 Search...]      │
│                                                             │
│ ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐    │
│ │ Global  │ │ my-other-app │ │ my-mobile-app     │ │ OrchyStraw   │    │
│ └─────────┘ └──────────┘ └──────────┘ └──────────────┘    │
│                                                             │
│ Tech Decisions                                              │
│ ┌───────────────────────────────────────────────────────┐   │
│ │ AUTH-001  │ Clerk      │ Global   │ 2026-03-17       │   │
│ │ AUTH-002  │ Supabase   │ my-mobile-app     │ 2026-04-02  (!)  │   │
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

The onboarding is a **conversation with the co-founder**, not a wizard with dropdowns.

```
┌─────────────────────────────────────────────────────────────┐
│ 🤝 Meet your Co-Founder                                     │
│                                                             │
│ Co-F: "Hey! I'm your co-founder — I'll run the team,       │
│  you bring the vision. Tell me about what we're building."  │
│                                                             │
│ You: "A fitness app for people with knee injuries.          │
│  Tracks exercises, suggests knee-safe alternatives,         │
│  maybe AI coaching eventually."                             │
│                                                             │
│ Co-F: "Love it. I'm thinking iOS-first since fitness is     │
│  mobile. Let me set up the team:                            │
│                                                             │
│  🤖 CEO — market research, competitive positioning          │
│  🤖 CTO — architecture, stack decisions                     │
│  🤖 PM — sprint planning, backlog management                │
│  🤖 Backend — API, database, AI coaching logic              │
│  🤖 iOS — SwiftUI app                                       │
│  🤖 QA — testing                                            │
│                                                             │
│  I already know you prefer Supabase + Clerk from your       │
│  last project. Want me to start with that stack, or         │
│  have CTO evaluate fresh?"                                  │
│                                                             │
│ You: "Start with what worked. Let's move fast."             │
│                                                             │
│ Co-F: "Done. Team is set up, backlog is seeded with         │
│  MVP features. First cycle starts in 30 seconds.            │
│  I'll check in when there's something to show you."         │
│                                                             │
│ [📊 View Dashboard]  [Just let me know when it's ready]     │
└─────────────────────────────────────────────────────────────┘
```

### Behind the Scenes (what the co-founder actually does)
1. Parses the user's description → project brief
2. Selects blueprint from `blueprints` table ("Consumer iOS SaaS")
3. Imports global knowledge (tech decisions, patterns, anti-patterns)
4. Generates agent prompts from templates
5. Creates initial backlog (issues) from blueprint
6. Configures VCS adapter (detects git if present, falls back to built-in)
7. Starts first cycle

The user said 3 sentences. The co-founder did everything else.

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
