# Team Norms & Conventions

> Standards every agent must follow. Read CLAUDE.md first — these norms supplement it.

## Communication

1. **Read shared context before starting.** Every cycle begins with reading `prompts/00-shared-context/context.md`.
2. **Write shared context before finishing.** Append what you built, what you need, and what's blocked.
3. **Be specific.** Not "updated backend" — instead "Added POST /api/notes/batch endpoint".
4. **Flag blockers immediately.** If you can't proceed, say so in Blockers section.
5. **Don't clear shared context.** Only APPEND under the right section.

## File Ownership

1. **Stay in your lane.** Only write to paths listed in your `agents.conf` ownership.
2. **No git operations.** Never run checkout, switch, merge, push, reset, rebase. The orchestrator handles git.
3. **Don't update your own prompt.** PM handles all prompt updates.
4. **Don't commit.** The orchestrator script handles commits.

## Code Standards

1. **Read before writing.** Use Edit, not Write, for existing files.
2. **No external dependencies** for core orchestrator (bash + markdown only).
3. **Bash 5.0 minimum** per BASH-001 ADR.
4. **`set -euo pipefail`** in all new bash scripts.
5. **Double-source guards** on all bash modules.

## Prompt Standards

Every agent prompt must include:
- Standard header block (agent ID, role, timestamps)
- Role section (what they do and DON'T do)
- Auto-Cycle Mode section (standard block)
- File Ownership section (explicit MAY/MUST NOT)
- PROTECTED FILES section (files they must not touch)
- Shared context instructions
- Git safety rules (no checkout/switch/merge/push/reset/rebase)

## Quality

1. **QA findings are not optional.** If QA flags something in your domain, address it next cycle.
2. **Security findings are P0.** HIGH-severity security issues block release.
3. **Test your work.** If you write code, verify it runs/builds/passes.

## Escalation Path

1. **Technical blocker** → Write to shared context Blockers section
2. **Cross-agent conflict** → HR mediates, PM resolves
3. **Architecture decision needed** → CTO
4. **Strategic/priority question** → CEO
5. **Needs human action** → Write to `prompts/99-me/`
6. **Protected file changes needed** → CS (human) must apply

## Cycle Etiquette

- Don't redo work that already shipped (check cross-cycle history)
- STANDBY is a valid status — don't create busywork
- If your interval says skip this cycle, skip it
- Respect the priority order in CLAUDE.md
