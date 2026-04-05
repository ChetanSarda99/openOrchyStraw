---
title: "[FEAT] Wire dormant v0.2.0 modules into auto-agent.sh"
labels: enhancement, integration, P1
---

## Problem

Several v0.2.0 modules are sourced in `auto-agent.sh` but never actually called. Functions exist but dormant. This is dead code and defeats the purpose of the modules.

## Modules to Wire

- [ ] `src/core/dynamic-router.sh` — should route tasks to agents based on task type
- [ ] `src/core/review-phase.sh` — should run between agent execution and commit
- [ ] `src/core/worktree.sh` — should isolate agent work in git worktrees
- [ ] `src/core/agent-timeout.sh` — should enforce per-agent time limits
- [ ] `src/core/dry-run.sh` — should respect DRY_RUN env var throughout cycle

## Acceptance Criteria

1. Each module has a "sourced = called" rule enforced by a lint check
2. auto-agent.sh has explicit calls to each module's public functions
3. Tests verify the integration works (not just that functions exist)
4. Add a module-integration test to `tests/core/`

## Related

- CTO approved all 7 modules in queue on 2026-04-05 (batch approval)
- This is the next step to leverage that approval
