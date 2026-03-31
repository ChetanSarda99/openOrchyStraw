# Shared Context — Cycle 2 — 2026-03-30 20:53:51
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 1 (0 backend, 0 frontend, 2 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- `src/core/qmd-refresher.sh` — #53 QMD auto-refresh module DONE: 6 public functions (available, refresh, embed, auto_refresh, status, collections_exist), state tracking via .orchystraw/, configurable embed interval
- `tests/core/test-qmd-refresher.sh` — 17 tests, ALL PASS (15 ported from legacy + 2 implicit from status output)
- Full test suite: 20/20 PASS (18 unit + 1 integration + runner), zero regressions
- INTEGRATION-GUIDE.md updated: Step 15 documents QMD wiring (replaces inline lines 690-703 in auto-agent.sh)

## iOS Status
- (fresh cycle)

## Design Status
- (fresh cycle)

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## PM Status
- All 9 agent prompts updated: #53 qmd-refresher done, CTO/QA/Security review queued
- Session tracker updated with cycle 2 entry
- 99-me updated: qmd-refresher wiring action item added
- Pending CTO reviews: single-agent.sh, v3 parser, SWE-bench scaffold, qmd-refresher.sh (4 items)
- Pending QA: verify BUG-019 fix, test SWE-bench scaffold, test qmd-refresher.sh
- Pending Security: review single-agent.sh, SWE-bench scaffold, qmd-refresher.sh

## Notes
- (none)
