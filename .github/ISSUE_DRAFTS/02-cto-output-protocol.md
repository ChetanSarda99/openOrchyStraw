---
title: "[BUG] CTO agent can't clear review queue — no output protocol"
labels: bug, agent-prompt, P0
---

## Problem

The CTO agent ran every other cycle for 4+ sessions trying to clear a 7-item review queue but produced zero approval commits. Queue stayed at 7 items unchanged. This was the primary cause of the orchestrator stall (see issue #1).

## Root Cause

`prompts/02-cto/02-cto.txt` says "Clear at least 3-4 reviews THIS cycle" but never specifies:
- HOW to record approvals (file? commit message? JSON?)
- WHAT "approval" looks like in the repo
- Where the review queue state is actually stored

The agent produces analysis in logs, but nothing makes it into git commits that the orchestrator can see.

## Fix

Define a strict CTO output protocol:

1. **Review queue file:** `docs/architecture/CTO-REVIEW-QUEUE.md` — authoritative list of items waiting for review
2. **Decision format:** Each review produces a file at `docs/architecture/decisions/ADR-NNN-slug.md` with frontmatter: `decision: approve|reject|defer`
3. **Commit message pattern:** `review: ADR-NNN approve/reject <slug>` — orchestrator can grep for these
4. **Queue clearance:** CTO must git-rm the queue entry after each decision

The CTO prompt should include concrete example output and file paths.

## Related

- Caused the 21+ idle cycle stall (issue #1)
- HR flagged it: `prompts/13-hr/team-health.md` cycle 3 session 6
