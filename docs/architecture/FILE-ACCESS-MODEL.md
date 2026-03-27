# File Access Model — Protected, Owned, Shared, Free

_Date: March 17, 2026_

---

## Current Model (two lists)

```
PROTECTED (hardcoded in auto-agent.sh):
  scripts/auto-agent.sh     — orchestrator itself
  scripts/agents.conf       — agent config
  scripts/check-usage.sh    — usage checker
  scripts/check-domain.sh   — domain checker
  .orchystraw/              — app data layer
  CLAUDE.md                 — root project instructions

OWNED (from agents.conf):
  06-backend → scripts/ src/core/ src/lib/ benchmarks/
  11-web     → site/
  02-cto     → docs/architecture/
  09-qa      → tests/ reports/
  03-pm      → prompts/ docs/
  ...

ROGUE = anything modified that's NOT in any agent's ownership → discarded
```

### Problem: No "Shared" or "Free" Zone

What if two agents need to write to the same file legitimately?
- `docs/tech-registry/proposals.md` — any worker should be able to append
- `prompts/00-shared-context/context.md` — every agent writes status here
- `docs/anti-patterns.md` — QA and any agent can add entries

Currently these work because PM owns `prompts/` and `docs/` broadly.
But that's a hack — PM shouldn't "own" files that workers need to write to.

---

## Proposed Model (four zones)

```
┌──────────────────────────────────────────────────────┐
│ 🔴 PROTECTED — immutable, auto-restored              │
│                                                      │
│ Files NO agent can ever modify. Not even PM.         │
│ Orchestrator restores these immediately on detect.    │
│                                                      │
│ Default:                                              │
│   scripts/auto-agent.sh                              │
│   scripts/agents.conf                                │
│   scripts/check-*.sh                                 │
│   .orchystraw/                                       │
│   CLAUDE.md                                          │
│   .git/                                              │
│   .gitignore                                         │
│   LICENSE                                            │
│   README.md (optional — user decides)                │
│                                                      │
│ Configurable: user can add/remove via settings       │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ 🟡 OWNED — exclusive write, one agent                 │
│                                                      │
│ Each agent owns specific paths. Only that agent can  │
│ write here. Rogue detection enforces this.           │
│                                                      │
│ Defined in: agents.conf (ownership column)           │
│ Enforced by: commit_by_ownership + detect_rogue      │
│                                                      │
│ Examples:                                            │
│   06-backend → scripts/ src/core/ src/lib/           │
│   11-web → site/                                     │
│   04-tauri-rust → src-tauri/                         │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ 🟢 SHARED — multi-agent write zones                   │
│                                                      │
│ Files any agent can append to. Used for cross-agent  │
│ communication, proposals, shared registries.         │
│                                                      │
│ Default shared zones:                                │
│   prompts/00-shared-context/     — cycle status      │
│   docs/tech-registry/proposals.md — CTO inbox        │
│   docs/anti-patterns.md          — failure log       │
│   docs/patterns/                  — pattern library   │
│   prompts/99-me/99-actions.txt   — human actions     │
│                                                      │
│ Rules:                                               │
│   - APPEND only (no overwrites of existing content)  │
│   - Orchestrator validates: only new lines added     │
│   - If agent overwrites shared file → rogue detected │
│                                                      │
│ Configurable: user adds shared zones in settings     │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ ⚪ UNOWNED — rogue if modified                        │
│                                                      │
│ Everything else. If an agent touches a file here,    │
│ it's a rogue write and gets discarded.               │
│                                                      │
│ This is the default zone — no config needed.         │
│ Anything not PROTECTED, OWNED, or SHARED = UNOWNED.  │
└──────────────────────────────────────────────────────┘
```

---

## Configuration

### In agents.conf (current format extended)

```conf
# Format: id | prompt | ownership | interval | label | shared_write
#
# shared_write: additional paths this agent can APPEND to (beyond ownership)
# Use "all_shared" to grant access to all SHARED zones

06-backend | prompts/06-backend/06-backend.txt | scripts/ src/core/ | 1 | Backend | all_shared
11-web     | prompts/11-web/11-web.txt         | site/              | 1 | Web Dev | docs/tech-registry/proposals.md
09-qa      | prompts/09-qa/09-qa.txt           | tests/ reports/    | 3 | QA      | docs/anti-patterns.md docs/patterns/
```

### In .orchystraw/project.db (future)

```sql
-- Protected paths (user configurable)
CREATE TABLE protected_paths (
    path        TEXT PRIMARY KEY,
    reason      TEXT,
    added_by    TEXT DEFAULT 'system' -- 'system' or 'user'
);

-- Shared zones
CREATE TABLE shared_zones (
    path        TEXT PRIMARY KEY,
    mode        TEXT DEFAULT 'append', -- 'append' or 'readwrite'
    description TEXT
);
```

### User Settings Panel (future)

```
⚙️ File Access

🔴 Protected Files (immutable)
  ☑ scripts/auto-agent.sh    [system — cannot remove]
  ☑ scripts/agents.conf      [system — cannot remove]
  ☑ CLAUDE.md                [system — cannot remove]
  ☑ .orchystraw/             [system — cannot remove]
  ☑ README.md                [user added]        [✕ remove]
  ☑ .env                     [user added]        [✕ remove]
  [+ Add protected file/folder]

🟢 Shared Zones (any agent can append)
  ☑ prompts/00-shared-context/    [system default]
  ☑ docs/tech-registry/proposals.md
  ☑ docs/anti-patterns.md
  ☑ docs/patterns/
  [+ Add shared zone]
```

---

## Enforcement in auto-agent.sh

Current: Two passes (protected + rogue)
Proposed: Three passes

```
Pass 1: PROTECTED — restore immediately, log CRITICAL
Pass 2: SHARED — validate append-only (diff check: only new lines added)
Pass 3: ROGUE — anything modified outside owned + shared → discard
```

### Append-Only Validation for Shared Files

```bash
validate_shared_writes() {
    for shared_file in "${SHARED_FILES[@]}"; do
        if git diff --name-only | grep -q "$shared_file"; then
            # Check that only lines were ADDED (no deletions/modifications)
            local deletions=$(git diff "$shared_file" | grep -c '^-[^-]')
            if [ "$deletions" -gt 0 ]; then
                log "ROGUE: Agent deleted/modified lines in shared file: $shared_file"
                git checkout -- "$shared_file"
            fi
        fi
    done
}
```
