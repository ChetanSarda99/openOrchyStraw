# Agent Onboarding Guide

> How to add a new agent to the OrchyStraw orchestrator.

## Prerequisites

- CEO approval for team composition change (or PM if tactical)
- HR proposal in `docs/team/proposals/` with justification
- No file ownership conflicts with existing agents

## Step-by-Step

### 1. Choose Agent ID

Format: `XX-name` where XX is a two-digit number.
- 01–03: Leadership (CEO, CTO, PM)
- 04–08: Implementation (Tauri, Backend, iOS, Pixel)
- 09–10: Quality (QA, Security)
- 11–12: Presentation (Web, Brand)
- 13+: Operations (HR, future ops agents)

Pick the next available number in the appropriate range.

### 2. Create Prompt File

Create `prompts/XX-name/XX-name.txt` following this template:

```
# ══════════════════════════════════════════════════
# AGENT: XX-name — [Role Title]
# UPDATED: [auto-updated by orchestrator]
# FILE COUNT: [auto-updated by orchestrator]
# ══════════════════════════════════════════════════

## Role
[2-3 sentences: what they do, what they DON'T do]

## Auto-Cycle Mode
You are running autonomously in OrchyStraw's multi-agent orchestrator.
- Do all work, commit nothing (the script handles git).
- Do NOT update your own prompt (PM handles that).
- Write status to prompts/00-shared-context/context.md before finishing.
- Read CLAUDE.md first for project-wide standards.

## File Ownership
YOU MAY WRITE TO:
- [list specific paths]

YOU MUST NOT WRITE TO:
- Other agents' prompt directories
- scripts/ — orchestrator code
- Any git operations (checkout, switch, merge, push, reset, rebase)

## [Role-Specific Sections]
[Standards, patterns, domain knowledge]

## Integration Points
[Who they depend on, who depends on them]

## YOUR TASKS (PM updates this section)
- [ ] [Initial tasks]

## AFTER YOU FINISH — Update Shared Context
Append what you built to: prompts/00-shared-context/context.md
```

### 3. Define File Ownership

- List exact directories the agent may write to
- Verify NO overlap with existing agents (check `agents.conf`)
- Add exclusion rules (`!path`) if needed
- When in doubt, narrower is better — can expand later

### 4. Add to agents.conf

Add a line in the appropriate section:
```
XX-name | prompts/XX-name/XX-name.txt | ownership/paths/ | interval | Label
```

Interval guide:
- `0` = Coordinator (runs LAST) — only PM
- `1` = Every cycle — core implementation agents
- `2` = Every 2nd cycle — review/support agents
- `3` = Every 3rd cycle — strategic/audit agents
- `5` = Every 5th cycle — infrequent audits

### 5. Update Supporting Files

- [ ] PM updates their prompt to include new agent in team roster
- [ ] Session tracker updated (`prompts/00-session-tracker/`)
- [ ] CLAUDE.md agent list updated (if permanent addition)
- [ ] TEAM_ROSTER.md updated (`docs/team/`)

### 6. Test Run

- Run a single cycle with ONLY the new agent enabled
- Verify: no rogue writes outside ownership, shared context updated, no git operations
- Check orchestrator logs for ownership violations

### 7. Go Live

- Enable in normal cycle rotation
- Monitor first 3 cycles closely
- HR reviews output quality after 3 cycles

## Removing an Agent

Removal requires HR recommendation + CEO approval.

1. HR writes removal proposal to `docs/team/proposals/` with 3+ cycles of evidence
2. CEO approves in shared context
3. PM removes from `agents.conf` (NOT mid-cycle)
4. Prompt directory archived to `prompts/00-backup/`
5. TEAM_ROSTER.md and CLAUDE.md updated
