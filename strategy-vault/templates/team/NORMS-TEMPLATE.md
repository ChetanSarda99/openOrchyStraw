# Team Norms & Conventions — [Your Project]

> Standards every team member (human or AI agent) must follow.
> Customize per project. These are the defaults.

---

## Communication

1. **Read shared context before starting.** Every session begins with reading the shared context document.
2. **Write shared context before finishing.** Append what you built, what you need, and what's blocked.
3. **Be specific.** Not "updated backend" — instead "Added POST /api/[resource]/batch endpoint".
4. **Flag blockers immediately.** If you can't proceed, say so clearly with a reason.
5. **Don't overwrite shared state.** APPEND under the right section — never clear others' updates.

---

## File Ownership

1. **Stay in your lane.** Only write to paths listed in your ownership config.
2. **No unauthorized git operations.** The orchestrator handles commits, merges, and pushes.
3. **Don't update your own role definition.** The PM/lead handles role updates.
4. **Don't commit from agent context.** The orchestrator script handles commits.

---

## Code Standards

1. **Read before writing.** Use Edit, not Write, for existing files.
2. **No undocumented external dependencies.** Propose new deps in a decision record first.
3. **Consistent tooling:** Follow the language/version standards in TECH-STACK.md.
4. **Script guards.** In bash: `set -euo pipefail` in all new scripts.
5. **Double-source guards** on all reusable modules.

---

## Prompt / Role Standards (multi-agent projects)

Every agent prompt must include:
- Role header (agent ID, role, last updated)
- Role section (what they do AND don't do)
- File ownership (explicit MAY/MUST NOT paths)
- Shared context instructions (read + write protocol)
- Git safety rules

---

## Quality

1. **Review findings are not optional.** If QA flags something in your domain, address it next cycle.
2. **Security findings are P0.** HIGH-severity security issues block release.
3. **Test your work.** If you write code, verify it runs/builds/passes.
4. **No regressions.** Changes in one domain must not break another.

---

## Escalation Path

1. **Technical blocker** → Write to shared context Blockers section
2. **Cross-team conflict** → Mediator (HR / lead) resolves
3. **Architecture decision needed** → CTO / tech lead
4. **Strategic/priority question** → CEO / owner
5. **Needs human action** → Flag clearly in a dedicated section
6. **Protected file changes needed** → Human must apply

---

## Cycle Etiquette

- Don't redo work that already shipped — check history first
- STANDBY is a valid status — don't create busywork
- If your role has no work this cycle, say so and stop
- Respect priority order: P0 (blocking) → P1 (high) → P2 (medium) → P3 (low)

---

## Protected Files

Files that must not be modified without explicit owner approval:
```
# List them here, e.g.:
# scripts/orchestrator.sh
# agents.conf
# .env.production
```

---

*Update this document when new patterns emerge. Keep it short and actionable.*
