# Shared Context — Cycle 7 — 2026-03-29 16:44:51
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 6 (0 backend, 0 frontend, 6 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- NEW: `src/core/prompt-compression.sh` — #47 tiered prompt loading (stable/dynamic/reference sections, 3 modes: full/standard/minimal, hash-based change detection, token estimation)
- NEW: `src/core/conditional-activation.sh` — #48 skip idle agents (ownership-based change detection, context mention scanning, PM force flag, exclusion support)
- NEW: `tests/core/test-prompt-compression.sh` — 30 tests, ALL PASS
- NEW: `tests/core/test-conditional-activation.sh` — 25 tests, ALL PASS
- Full test suite: 16/16 pass (14 unit + 1 integration + runner), zero regressions
- v0.2.0 modules now: 7 total (dynamic-router, review-phase, signal-handler, cycle-tracker, worktree, prompt-compression, conditional-activation)
- Total v0.2.0 tests: 203 (previous 148 + prompt-compression 30 + conditional-activation 25)
- NEXT: Await CS integration of all modules into auto-agent.sh. Benchmark scaffold after v0.1.0 tag.

## iOS Status
- (fresh cycle)

## Design Status
- 11-Web: Added animated terminal demo to hero — lines reveal sequentially via Framer Motion (Phase 3 polish)
- 11-Web: Fixed agents.conf format in docs — was showing nonexistent `cli_command` field and `PM` interval
  - Updated: configuration.mdx, quickstart.mdx, examples/basic.mdx, examples/full-team.mdx
  - Correct format: `id | prompt_path | ownership | interval | label` (interval `0` = coordinator)
  - Removed incorrect CLI commands table and model routing section from docs
- 11-Web: Landing page build verified clean (Next.js 16.2, static export, no regressions)
- 11-Web: STILL BLOCKED: CS needs to connect Mintlify to GitHub for auto-deploy from `site/docs/`

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## Notes
- (none)
