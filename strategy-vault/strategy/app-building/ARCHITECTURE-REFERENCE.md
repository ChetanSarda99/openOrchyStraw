# Architecture - How the Orchestrator Works

## System Overview

```mermaid
flowchart TD
    You["👤 You (99-me)"] -->|runs| Script["🎬 auto-agent.sh"]
    Script -->|reads| Conf["agents.conf"]
    Script -->|creates branch| Git["🌿 git"]

    Script -->|runs in parallel| W1["02-backend"]
    Script -->|runs in parallel| W2["03-frontend"]
    Script -->|runs in parallel| W3["04-design"]
    Script -->|runs in parallel| W4["05-qa"]

    W1 -->|reads & writes| SC["📋 shared context"]
    W2 -->|reads & writes| SC
    W3 -->|reads & writes| SC
    W4 -->|reads & writes| SC

    Script -->|runs last| PM["01-pm"]
    PM -->|reads| SC
    PM -->|writes new tasks to| W1p["02 prompt"]
    PM -->|writes new tasks to| W2p["03 prompt"]
    PM -->|writes new tasks to| W3p["04 prompt"]
    PM -->|writes new tasks to| W4p["05 prompt"]

    Script -->|commits by ownership| Git
    Script -->|merges to main| Git
    Script -->|backs up| Backup["00-backup/"]
```

## Cycle Flow

```mermaid
flowchart TD
    A["🔄 Cycle Start"] --> B["check-usage.sh = usage.txt"]
    B -->|"≥70%"| Pause["⏸️ Pause (re-check every 60s)"]
    Pause --> B
    B -->|"<70%"| C["git checkout main && git pull"]
    C --> D["Archive old context = context-cycle-N.md"]
    D --> E["Reset shared context + inject progress trend"]
    E --> F["Create branch: auto/cycle-N-MMDD-HHMM"]
    F --> G["Run eligible workers in parallel"]

    G --> G1["02-backend\n reads prompt = codes"]
    G --> G2["03-frontend\n reads prompt = codes"]
    G --> G3["04-design\n reads prompt = codes"]
    G --> G4["05-qa (if interval hit)\n reviews code"]

    G1 --> H["Commit by file ownership"]
    G2 --> H
    G3 --> H
    G4 --> H

    H --> I{"Rogue writes\ndetected?"}
    I -->|Yes| J["Discard files outside ownership"]
    I -->|No| K["Backup all prompts"]
    J --> K

    K --> L["Run PM (coordinator)"]
    L --> L1["Read shared context"]
    L1 --> L2["Review git log + issues"]
    L2 --> L3["Edit task sections in worker prompts"]
    L3 --> L4["Update SESSION_TRACKER"]
    L4 --> L5["Update 99-me actions"]
    L5 --> M["Commit PM changes"]

    M --> N{"Merge = main"}
    N -->|Success| O["Push + delete branch"]
    N -->|Conflict| P["Abort merge, keep branch\n(manual fix needed)"]
    N -->|Push fail| Q["Pull --rebase = retry"]
    Q --> O

    O --> R["Validate prompts (restore if <50 lines)"]
    R --> S["Save progress.json checkpoint"]
    S --> T["Auto-update timestamps + file counts via sed"]
    T --> U["Commit auto-updates + push"]
    U --> V["🔔 Notify = next cycle"]
```

## Data Flow Between Cycles

```mermaid
flowchart LR
    subgraph CycleN["Cycle N"]
        A1["Workers code"] --> A2["context.md\n(agent status)"]
        A2 --> A3["PM reviews"]
        A3 --> A4["Updates prompts"]
        A3 --> A5["SESSION_TRACKER\n(append)"]
        A3 --> A6["progress.json\n(snapshot)"]
    end

    subgraph CycleN1["Cycle N+1"]
        B1["Workers code"] --> B2["context.md\n(fresh reset)"]
        B2 --> B3["PM reviews"]
        B3 --> B4["Updates prompts"]
        B3 --> B5["SESSION_TRACKER\n(append)"]
        B3 --> B6["progress.json\n(snapshot)"]
    end

    A2 -->|archived as\ncontext-cycle-N.md| B2
    A5 -->|persists| B5
    A6 -->|trend injected\ninto reset| B2
    A4 -->|tasks carry over| B1
```

## Agent Input Assembly

What each worker agent sees when it runs:

```mermaid
flowchart TD
    subgraph Input["Agent Input (piped to CLI)"]
        S1["📋 Section 1: Shared Context\nWhat other agents built/need\n(full context.md)"]
        S2["📜 Section 2: Cross-Cycle History\nLast 150 lines of SESSION_TRACKER\n(what shipped previously)"]
        S3["📝 Section 3: Agent Prompt\nFull prompt file (200-380 lines)\nContext, tasks, ownership, standards"]
        S4["✏️ Section 4: Post-Work Instructions\nAppend what you built to context.md"]
    end

    S1 --> S2 --> S3 --> S4
```

What PM sees (different input):

```mermaid
flowchart TD
    subgraph PMInput["PM Input (piped to CLI)"]
        P1["🤖 Autonomous Mode Header\nYou are running FULLY AUTONOMOUSLY\nTake ALL actions yourself"]
        P2["👥 Registered Agents\nAgent list from agents.conf\n(id, prompt, ownership)"]
        P3["📝 PM Prompt\nFull PM prompt (150-300 lines)"]
        P4["📋 7-Step Cycle Tasks\n0: Read shared context + progress\n1: Review git log\n2: Check GitHub issues\n3: Update worker prompts (Edit only)\n4: Update own prompt\n5: Update SESSION_TRACKER\n6: Update 99-me actions"]
    end

    P1 --> P2 --> P3 --> P4
```

## Why Parallel Workers + PM (Not Sequential)

```mermaid
flowchart LR
    subgraph Sequential["❌ ChatDev-style (sequential)"]
        direction LR
        CEO2["CEO"] --> CTO2["CTO"] --> Prog["Programmer"] --> Test["Tester"] --> Doc["Documenter"]
    end

    subgraph Parallel["✅ OrchyStraw (parallel + PM)"]
        direction TB
        Back["Backend"] & Front["Frontend"] & Design["Design"] --> Commit["Script commits\nby ownership"]
        Commit --> PMR["PM reviews\n& replans"]
        PMR --> Next["Next cycle"]
    end
```

**Sequential:** each agent waits for the previous one, 70% of tokens are "I agree." **Parallel:** all workers run simultaneously, PM coordinates after.

## Safety Layers

```mermaid
flowchart TD
    subgraph L1["Layer 1: File Ownership"]
        O1["agents.conf defines strict boundaries"]
        O2["!path exclusions carve subfolders"]
        O3["'none' = read-only"]
    end

    subgraph L2["Layer 2: Rogue Write Detection"]
        R1["Scan all unstaged changes after agents finish"]
        R2["Check each file against all ownerships"]
        R3["No match = git checkout (discard)"]
    end

    subgraph L3["Layer 3: Git Safety"]
        G1["Agents cannot run: checkout, switch, merge, push, reset, rebase"]
        G2["Script handles ALL branch management"]
        G3["PM branch recovery if PM wanders"]
    end

    subgraph L4["Layer 4: Prompt Validation"]
        V1["<50 lines = corrupted = auto-restore from backup"]
        V2["PM uses Edit (not Write) for task sections only"]
        V3["Script sed-updates dates + file counts"]
    end

    subgraph L5["Layer 5: Usage & Regression Guards"]
        U1["check-usage.sh = usage.txt (0-100)"]
        U2["≥70% = orchestrator pauses"]
        U3[">5 files lost = regression warning"]
        U4["3 empty cycles = auto-stop"]
    end

    L1 --> L2 --> L3 --> L4 --> L5
```

## Key Design Decisions

### Script Controls Git (Not Agents)
Agents never run git commands. The script creates branches, commits by file ownership, merges to main, and pushes to origin. This eliminates race conditions and ensures clean history.

### File Ownership = No Conflicts
Each agent has explicit directory ownership in `agents.conf`. If an agent writes outside its directories, rogue detection catches it and discards the change.

### Shared Context = Cheap Communication
Instead of agents chatting with each other (expensive, slow), they read/write a shared markdown file. Backend appends "Added POST /api/users" = Frontend reads it and uses the endpoint. Cost: ~100 tokens vs ~5000 for a debate.

### PM Updates Task Sections (Not Full Rewrites)
PM uses the Edit tool to modify only "What's DONE" and "YOUR TASKS" sections. The script auto-updates timestamps and file counts via `sed`. This prevents PM from accidentally nuking tech stack or ownership sections.

### Parallel Workers, Sequential Review
Workers run simultaneously (3x faster than sequential). PM runs last as the single coordination point. This is intentionally a hub-and-spoke topology - not a mesh.

## CLAUDE.md Integration

Every project should document the orchestrator in its `CLAUDE.md` file. This is auto-loaded by Claude Code, so all agents (and manual sessions) know the system exists.

Key sections to include:
- **Quick commands** - `orchestrate`, `run`, `list`, `check-usage`
- **What the script handles** - timestamps, file counts, usage, git, rogue detection
- **What PM handles** - task sections, milestone status, session tracker, human actions
- **Monitoring** - log location, don't edit script while running

See `template/CLAUDE.md` for the full template.
