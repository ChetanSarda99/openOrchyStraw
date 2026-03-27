# Team Norms & Conventions

> Standards every agent (or contributor) must follow on any project using a multi-agent orchestrator. Read the project's CLAUDE.md first — these norms supplement it.

---

## Communication

1. **Read shared context before starting.** Every cycle begins with reading the current shared context file.
2. **Write shared context before finishing.** Append what you built, what you need, and what's blocked.
3. **Be specific.** Not "updated backend" — instead "Added `POST /api/[resource]/batch` endpoint with rate limiting."
4. **Flag blockers immediately.** If you can't proceed, say so in the Blockers section of shared context.
5. **Don't clear shared context.** Only APPEND under the correct section.

---

## File Ownership

1. **Stay in your lane.** Only write to paths listed in your ownership config.
2. **No git operations.** Never run checkout, switch, merge, push, reset, or rebase. The orchestrator handles git.
3. **Don't update your own prompt.** The PM/coordinator handles all prompt updates.
4. **Don't commit.** The orchestrator script handles commits.

---

## Code Standards

1. **Read before writing.** Use Edit, not Write (overwrite), for existing files.
2. **No unnecessary external dependencies** for core orchestrator (keep it to bash + markdown where possible).
3. **`set -euo pipefail`** in all new bash scripts.
4. **Source guards** on all bash modules to prevent double-sourcing.

---

## Prompt Standards

Every agent prompt must include:
- Standard header block (agent ID, role, last-updated timestamp)
- Role section (what they do AND what they explicitly don't do)
- Auto-Cycle Mode section (autonomous operation instructions)
- File Ownership section (explicit MAY / MUST NOT paths)
- PROTECTED FILES section
- Shared context read/write instructions
- Git safety rules (no checkout / switch / merge / push / reset / rebase)

---

## Quality

1. **QA findings are not optional.** If QA flags something in your domain, address it next cycle.
2. **Security findings are P0.** HIGH-severity issues block release.
3. **Test your work.** If you write code, verify it runs / builds / passes.

---

## Escalation Path

| Situation | Action |
|-----------|--------|
| Technical blocker | Write to shared context Blockers section |
| Cross-agent conflict | HR mediates; PM resolves |
| Architecture decision needed | CTO |
| Strategic or priority question | CEO |
| Needs human action | Write to `prompts/99-[human]/` |
| Protected file change needed | Human must apply |

---

## Cycle Etiquette

- Don't redo work that already shipped (check cross-cycle history first)
- STANDBY is a valid status — don't manufacture busywork
- If your schedule says skip this cycle, skip it
- Respect the priority order in the project's CLAUDE.md
- Don't touch another agent's prompt directory

---

## What "Done" Means

An item is done when:
1. Code written and tested
2. Shared context updated with what was built
3. No rogue writes (files outside your ownership)
4. No git commands run

"I started it" is not done. "I documented it in shared context and it works" is done.
