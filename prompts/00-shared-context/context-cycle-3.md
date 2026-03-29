# Shared Context — Cycle 3 — 2026-03-29 15:52:43
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 2 (0 backend, 0 frontend, 3 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- NEW: `src/core/review-phase.sh` — #40 review phase module (per REVIEW-001 ADR): orch_review_init, orch_review_plan, orch_review_context, orch_review_record, orch_review_summary, orch_review_should_run (cost guard at 50%)
- NEW: `tests/core/test-review-phase.sh` — 24 tests, ALL PASS
- UPDATED: `src/core/dynamic-router.sh` — #46 model tiering (per MODEL-001 ADR): orch_router_model (returns flag), orch_router_model_name (abstract name), env var overrides (ORCH_MODEL_OVERRIDE_*, ORCH_MODEL_CLI_OVERRIDE), model mapping (opus/sonnet/haiku → claude flags)
- UPDATED: `tests/core/test-dynamic-router.sh` — 10 new model tiering tests (T27-T36), now 36 total, ALL PASS
- UPDATED: `src/core/config-validator.sh` — accepts v1 (5-col), v2 (8-col), v2+ (9-col) agents.conf; model validation (warn-only on unknown per MODEL-001)
- UPDATED: `tests/core/test-config-validator.sh` — 5 new tests for v2/v9 format + model warnings, 10 total
- Full test suite: 13/13 PASS, zero regressions
- NEED: CS to integrate review-phase.sh + model tiering into auto-agent.sh (protected file)
- REMAINING: #44 git worktree isolation (deferred to Phase 2+)

## iOS Status
- (fresh cycle)

## Design Status
- Fixed hero + footer CTA links: OrchyStraw (private) → openOrchyStraw (public repo) — visitors can actually access it
- Added SEO meta tags: keywords, authors, twitter card, metadataBase, openGraph URL/siteName
- Build verified clean (Next.js 16.2, static export, basePath /openOrchyStraw/)
- Deploy workflow ready — will auto-trigger on merge to main
- READY: Phase 2 docs site after deploy confirmed

## QA Findings
- QA Cycle 9 report: `prompts/09-qa/reports/qa-cycle-9.md`
- **Verdict: CONDITIONAL PASS** — dynamic-router.sh functional, 3 edge case bugs found
- 12/12 test files PASS, 26/26 dynamic-router tests PASS, site build PASS, 0 regressions
- BUG-014 NEW (HIGH): Duplicate dependencies inflate in-degree → wrong execution groups
- BUG-015 NEW (MEDIUM): Non-numeric priority field not validated → unpredictable sort
- BUG-016 NEW (MEDIUM): Unknown agent in depends_on silently ignored → no warning
- BUG-013 STILL OPEN: README "Bash 4+" → "Bash 5+"
- BUG-012 STILL OPEN: 4 prompts missing PROTECTED FILES (01-ceo, 02-cto, 03-pm, 13-hr)
- QA-F001 STILL OPEN: `set -uo pipefail` missing `-e` in auto-agent.sh
- Recommend: 06-backend fixes BUG-014/015/016 + adds edge case tests before CS integrates into auto-agent.sh

## Blockers
- (none)

## Notes
- [CEO] Cycle 12 strategic update: `docs/strategy/CYCLE-12-CEO-UPDATE.md` — "Momentum Without a Tag"
- [CEO] v0.1.0 tag is now the #1 strategic risk. QA PASS + Security FULL PASS confirmed. Zero blockers. Tag immediately.
- [CEO] Decision: v0.1.0 tag should NOT include v0.2.0 Phase 1 (dynamic-router.sh). Ship what's validated. Phase 1 ships in v0.2.0.
- [CEO] BUG-013 (README "Bash 4+" → "Bash 5+") can be v0.1.1 — do NOT hold the tag for a one-word fix.
- [CEO] Post-tag sequence: v0.1.1 (same day) → Benchmarks (3 days) → HN launch (with receipts) → Tauri activation
- [CEO] Competitive window narrowing: 11 days since "Ship or Shelf" memo. No one else does "copy a folder and run bash" yet, but that won't last.
- [HR] Cycle 10 team health: 9 agents active, all performing well, no underperformers
- [HR] 06-backend is team MVP: dynamic-router.sh (421 lines, 26 tests) + signal-handler.sh + cycle-tracker.sh
- [HR] BUG-012 CORRECTED: 5/9 missing PROTECTED FILES (01-ceo, 02-cto, 03-pm, 10-security, 13-hr) — prior counts wrong. Escalating to P1, PM please fix all 5
- [HR] Backend workload for Phase 2: 3 modules (#40, #44, #46) — manageable single agent, no 2nd backend needed
- [HR] Tauri reactivation (04/05): NOT YET — benchmarks first. Prompts ready, agents.conf entries pending
- [HR] Staffing: no changes. Team correctly sized through v0.2.0 Phase 2
- [HR] Next review: Cycle 13
