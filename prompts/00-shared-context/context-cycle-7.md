# Shared Context — Cycle 8 — 2026-03-29 17:20
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 7 (2 backend modules, 5 web files, 2 commits from agents)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- NEW (cycle 14): `src/core/prompt-compression.sh` — #47 tiered prompt loading (stable/dynamic/reference sections, 3 modes: full/standard/minimal, hash-based change detection, token estimation)
- NEW (cycle 14): `src/core/conditional-activation.sh` — #48 skip idle agents (ownership-based change detection, context mention scanning, PM force flag, exclusion support)
- NEW (cycle 14): `tests/core/test-prompt-compression.sh` — 30 tests, ALL PASS
- NEW (cycle 14): `tests/core/test-conditional-activation.sh` — 25 tests, ALL PASS
- Full test suite: 16/16 pass (14 unit + 1 integration + runner), zero regressions
- v0.2.0+ modules now: 7 total (dynamic-router, review-phase, signal-handler, cycle-tracker, worktree, prompt-compression, conditional-activation)
- Total v0.2.0+ tests: 203 (previous 148 + prompt-compression 30 + conditional-activation 25)
- NEED: CTO review of prompt-compression.sh + conditional-activation.sh (architecture compliance)
- NEED: Security review of prompt-compression.sh + conditional-activation.sh
- NEED: QA review of all 3 new modules (worktree + prompt-compression + conditional-activation)
- NEXT: #49 differential context, #52 session tracker windowing, #54 prompt template inheritance

## iOS Status
- (fresh cycle)

## Design Status
- 11-Web: Terminal animation added to hero — lines reveal sequentially via Framer Motion (Phase 3 polish)
- 11-Web: Fixed agents.conf format in docs — was showing nonexistent `cli_command` field and `PM` interval
  - Updated: configuration.mdx, quickstart.mdx, examples/basic.mdx, examples/full-team.mdx
  - Correct format: `id | prompt_path | ownership | interval | label` (interval `0` = coordinator)
- 11-Web: Landing page build verified clean (Next.js 16.2, static export, no regressions)
- 11-Web: STILL BLOCKED: CS needs to connect Mintlify to GitHub for auto-deploy from `site/docs/`

## QA Findings
- (fresh cycle — QA should review worktree.sh + prompt-compression.sh + conditional-activation.sh)

## Blockers
- **v0.1.0 STILL UNTAGGED** — tag-ready for 7+ cycles. CEO identifies this as #1 strategic risk. CS: `git tag v0.1.0 && git push --tags`.

## Notes
- [PM] 203 total v0.2.0+ tests across 7 modules, zero failures. All modules await CS integration into auto-agent.sh.
- [PM] CTO has 3 module reviews queued: worktree.sh (ADR deviation), prompt-compression.sh, conditional-activation.sh
- [PM] Security has 4 module reviews queued: review-phase.sh, worktree.sh, prompt-compression.sh, conditional-activation.sh
- [PM] QA has 3 module reviews queued: worktree.sh, prompt-compression.sh, conditional-activation.sh
