# Agent / Team Member Onboarding Guide — [Your Project]

> How to add a new agent or team member to the orchestrator.
> Customize for your project's structure.

---

## Prerequisites

- Lead approval for team composition change
- Role proposal with justification (what gap does this role fill?)
- No file ownership conflicts with existing agents
- Clear definition of what the role does AND does NOT do

---

## Step-by-Step

### 1. Choose Role ID

Format: `XX-name` where XX is a two-digit number.

Suggested ranges (customize per project):
- 01–03: Leadership (CEO, CTO, PM)
- 04–08: Implementation (frontend, backend, platform)
- 09–10: Quality (QA, security)
- 11–12: Presentation (landing page, brand)
- 13+: Operations (HR, future ops roles)

Pick the next available number in the appropriate range.

---

### 2. Create Role Prompt File

Create `prompts/XX-name/XX-name.txt` using this template:

```
# ══════════════════════════════════════════════════
# AGENT: XX-name — [Role Title]
# UPDATED: [auto-updated by orchestrator or manually]
# ══════════════════════════════════════════════════

## Role
[2-3 sentences: what they do, what they DON'T do]

## Orchestrator Mode
You are running autonomously.
- Do all work; commit nothing (the orchestrator handles git).
- Do NOT update your own prompt (PM handles that).
- Write status to shared context before finishing.
- Read the project's CLAUDE.md/AGENTS.md first for standards.

## File Ownership
YOU MAY WRITE TO:
- [list specific paths]

YOU MUST NOT WRITE TO:
- Other agents' prompt directories
- scripts/ — orchestrator code
- Protected files list (see PROTECTED.md)

## [Role-Specific Sections]
[Standards, patterns, domain knowledge for this role]

## Integration Points
[Who they depend on, who depends on them]

## YOUR TASKS (PM updates this section each cycle)
- [ ] [Initial tasks]

## AFTER YOU FINISH — Update Shared Context
Append what you built to the shared context document.
```

---

### 3. Define File Ownership

- List exact directories/files the agent may write to
- Verify NO overlap with existing agents
- When in doubt, narrower is better — can expand later
- Add explicit exclusions if needed

---

### 4. Add to agents.conf (or equivalent)

```
XX-name | prompts/XX-name/XX-name.txt | ownership/paths/ | interval | Label
```

**Interval guide:**
- `0` = Coordinator (runs last) — only PM
- `1` = Every cycle — core implementation
- `2` = Every 2nd cycle — review/support
- `3` = Every 3rd cycle — strategic/audit
- `5` = Every 5th cycle — infrequent audits

---

### 5. Update Supporting Files

- [ ] PM/lead updates their prompt to include new agent in team roster
- [ ] Session tracker updated
- [ ] CLAUDE.md / AGENTS.md agent list updated (if permanent addition)
- [ ] TEAM_ROSTER.md updated (if it exists)

---

### 6. Test Run

1. Run a single cycle with ONLY the new agent enabled
2. Verify: no rogue writes outside ownership, shared context updated, no unauthorized git ops
3. Check orchestrator logs for ownership violations
4. Review output quality before enabling in full rotation

---

### 7. Go Live

- Enable in normal cycle rotation
- Monitor first 3 cycles closely
- Review output quality at cycle 3, adjust prompt if needed

---

## Removing a Role

Removal requires: evidence of underperformance + lead/owner approval.

1. Write removal justification with 3+ cycles of evidence
2. Owner approves
3. PM removes from rotation config (NOT mid-cycle)
4. Prompt directory archived to `prompts/archive/` or equivalent
5. TEAM_ROSTER.md and AGENTS.md updated
6. Ownership config cleaned up

---

## Role Prompt Checklist

Before marking a prompt as "ready to run", verify:

- [ ] Role description is clear (what it does + doesn't do)
- [ ] File ownership explicitly listed
- [ ] Protected files listed or referenced
- [ ] Shared context read + write protocol included
- [ ] Git safety rules included
- [ ] Initial tasks section filled in by PM

---

*Good onboarding prevents confused agents. Write clear roles.*
