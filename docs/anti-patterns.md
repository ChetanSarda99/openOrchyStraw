# Anti-Pattern Registry — OrchyStraw

_Maintained by: QA (09-qa), CTO (02-cto)_
_See docs/KNOWLEDGE-REPOSITORIES.md for format._

---

## AP-001: Agent writes outside file ownership boundary
**Discovered:** 2026-03-17 (design phase)
**Problem:** Agent modifies files outside its agents.conf ownership — corrupts other agents' work
**What was tried:** Agents drifting into shared directories
**Fix:** Explicit `YOU MUST NOT WRITE TO:` in every prompt + rogue detection in auto-agent.sh
**Affects:** All agents

## AP-002: Agent runs git commands directly
**Discovered:** 2026-03-17 (design phase)
**Problem:** Agent runs `git checkout -b feature` — breaks orchestrator branch management
**Fix:** Hard rule in all prompts: NEVER run git checkout/switch/merge/push/reset/rebase
**Affects:** All agents

## AP-003: Ghost slash commands in prompts
**Discovered:** 2026-03-17 (design phase)
**Problem:** Prompts reference `/plan`, `/deploy`, `/lint` — these don't exist in Claude Code
**Fix:** Only use real built-ins: /test, /review, /security, /debug, /refactor + CLAUDE.md customs
**Affects:** All agent prompts

## AP-004: PM writes code
**Discovered:** 2026-03-17 (design phase)
**Problem:** PM "helps" by writing a small fix inline — breaks separation of concerns
**Fix:** PM prompt hard rule: "You NEVER write code"
**Affects:** 03-pm

## AP-005: No shared context → agents duplicate work
**Discovered:** 2026-03-17 (design phase)
**Problem:** Two agents build conflicting APIs or re-implement the same feature
**Fix:** Agents READ context.md at start, APPEND their status at end, every cycle
**Affects:** All agents

## AP-006: Marking bugs fixed in tracker but not in actual files
**Discovered:** 2026-03-18 by 09-qa
**Problem:** BUG-004/005 were listed as "FIXED by PM (cycle 2)" in action items, but the actual prompt files still contained the wrong paths. Fix appeared confirmed without verifying the source files.
**What was tried:** PM updated tracking docs and session tracker to say "fixed" without editing the prompt files containing the wrong paths.
**Fix:** Bug closure requires file-level verification — read the actual file, confirm the fix is present. Tracking doc updates alone are not sufficient.
**Affects:** All agents, especially PM and QA

