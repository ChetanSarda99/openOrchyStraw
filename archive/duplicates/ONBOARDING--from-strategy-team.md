# Agent Onboarding Guide

> How to add a new agent to any multi-agent orchestrator. Adapt the specifics (IDs, paths) to your project's `agents.conf` format.

---

## Prerequisites

- PM or CEO approval for the new agent
- Justification documented (what gap does this agent fill? who does it replace?)
- No file ownership conflicts with existing agents
- Prompt template ready to adapt

---

## Step 1: Choose Agent ID

Format: `XX-name` where XX is a two-digit number.

Recommended tier structure:
- `01–03`: Leadership (CEO, CTO, PM)
- `04–09`: Implementation (domain-specific)
- `10–11`: Quality (QA, Security)
- `12–13`: Presentation (Web, Brand)
- `14+`: Operations (HR, future agents)

Pick the next available number in the appropriate range.

---

## Step 2: Create Prompt File

Create `prompts/XX-name/XX-name.txt` using this template:

```
# ══════════════════════════════════════════════════
# AGENT: XX-name — [Role Title]
# UPDATED: [auto-updated by orchestrator]
# FILE COUNT: [auto-updated by orchestrator]
# ══════════════════════════════════════════════════

## Role
[2-3 sentences: what they do, what they DON'T do]

## Auto-Cycle Mode
You are running autonomously in [Project]'s multi-agent orchestrator.
- Do all work, commit nothing (the script handles git).
- Do NOT update your own prompt (PM handles that).
- Write status to [shared-context path] before finishing.
- Read CLAUDE.md first for project-wide standards.

## File Ownership
YOU MAY WRITE TO:
- [list specific paths]

YOU MUST NOT WRITE TO:
- Other agents' prompt directories
- Orchestrator scripts
- Any git operations (checkout, switch, merge, push, reset, rebase)

## [Role-Specific Sections]
[Standards, patterns, domain knowledge for this role]

## Integration Points
[Who they depend on — who depends on them]

## YOUR TASKS (PM updates this section)
- [ ] [Initial tasks]

## AFTER YOU FINISH — Update Shared Context
Append to: [shared-context path]
```

---

## Step 3: Define File Ownership

- List exact directories the agent may write to
- Verify NO overlap with existing agents (check `agents.conf`)
- Use exclusion rules (`!path`) if needed
- When in doubt, narrower is better — you can always expand later

---

## Step 4: Add to agents.conf

```
XX-name | prompts/XX-name/XX-name.txt | ownership/paths/ | interval | Label
```

**Interval guide:**
- `0` — Coordinator (runs LAST) — typically PM only
- `1` — Every cycle — core implementation agents
- `2` — Every 2nd cycle — review / support agents
- `3` — Every 3rd cycle — strategic / audit agents
- `5` — Every 5th cycle — infrequent audits

---

## Step 5: Update Supporting Files

- [ ] PM updates their task list to include new agent
- [ ] Session tracker updated
- [ ] CLAUDE.md agent list updated (if permanent)
- [ ] Team roster doc updated

---

## Step 6: Test Run

1. Run a single cycle with ONLY the new agent enabled
2. Verify: no writes outside ownership, shared context updated, no git operations
3. Check orchestrator logs for ownership violations

---

## Step 7: Go Live

- Enable in normal cycle rotation
- Monitor first 3 cycles closely for rogue writes or stale output
- QA reviews output quality after 3 cycles

---

## Removing an Agent

Removal requires PM recommendation + CEO approval.

1. Document reason with 3+ cycles of evidence (underperforming, redundant, pivoted)
2. CEO approves
3. PM removes from `agents.conf` (NOT mid-cycle)
4. Archive prompt directory to `prompts/00-backup/`
5. Update team roster and CLAUDE.md

---

## Common Mistakes

- **Ownership too broad** — Agent starts touching files it shouldn't. Start narrow.
- **Skipping the test run** — First real cycle surprises are expensive. Always test solo.
- **No escalation path in prompt** — Agent gets stuck and writes nothing useful. Add explicit blocked-state instructions.
- **Removing mid-cycle** — Always wait for a cycle boundary to add or remove agents.
