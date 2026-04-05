---
title: "[BUG] Orchestrator ran 21+ idle cycles before stall was detected"
labels: bug, orchestrator, P0
---

## Problem

The orchestrator ran 21+ consecutive lint-only / zero-commit cycles between 2026-03-31 and 2026-04-05 without auto-detecting the stall. HR agent eventually flagged it manually on cycle 5 session 6, but by then significant API tokens had been burned with zero output.

## Root Cause

`scripts/auto-agent.sh` only tracks consecutive FAILURES (`MAX_EMPTY_CYCLES=3`), not consecutive idle cycles. A cycle that runs agents, produces lint-only commits, and merges cleanly is counted as "success" — even if no actual work happened.

## Fix (partial, this PR)

- Added `src/core/stall-detector.sh` — tracks meaningful commits (>20 lines, excluding lint-only/auto-update) per cycle
- Wired into orchestrator via `stall_check_cycle` after each commit phase
- Orchestrator auto-pauses after `STALL_MAX_IDLE=3` consecutive idle cycles

## Remaining Work

- [ ] Integration test: run 3 fake idle cycles, verify pause triggers
- [ ] Add alert via Telegram when stall detected
- [ ] Track stall metrics in session tracker

## Related

- Original stall: `prompts/13-hr/team-health.md` cycle 3 session 6 report
- Cleared manually 2026-04-05 after CS batch-approved 7 CTO queue items
