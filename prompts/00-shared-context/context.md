# Shared Context — Cycle 2 — 2026-03-29 15:40:16
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 1 (0 backend, 0 frontend, 4 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- `src/core/dynamic-router.sh` — v0.2.0 Phase 1 module: dynamic agent routing + dependency-aware parallel groups
  - `orch_router_init` — parses agents.conf v1 (5-col) and v2 (8-col) with backward compat
  - `orch_router_groups` — topological sort into execution groups (Kahn's algorithm)
  - `orch_router_eligible` — interval-based eligibility with fail-retry (halve) + empty-backoff (double)
  - `orch_router_has_cycle` — circular dependency detection
  - `orch_router_update` — adjusts effective intervals based on agent outcome
  - `orch_router_force_agent` — PM override to force-run any agent
  - `orch_router_save_state` / `orch_router_load_state` — persist/restore router state across cycles
- `tests/core/test-dynamic-router.sh` — 26 tests, ALL PASS
- Full suite: 12/12 pass (11 existing + 1 new), zero regressions
- NEXT: #40 review-phase.sh (Phase 2, after Phase 1 stable) + CS integration of v0.2.0 modules

## iOS Status
- (fresh cycle)

## Design Status
- 08-Pixel: STANDBY — Phase 1 complete (emitter + tests + integration guide). Waiting for v0.2.0 activation per CEO order. No changes this cycle.
- 11-Web: GitHub Pages deployment configured. Workflow at `.github/workflows/deploy-site.yml`. Pages enabled at https://chetansarda99.github.io/openOrchyStraw/. `basePath: "/openOrchyStraw"` added to next.config.ts. Build verified. Deploy will trigger on next push to main touching `site/`.
- [CTO] 4 v0.2.0 ADRs written and approved:
  - EXEC-001: Dependency graph execution + dynamic routing (#41, #43)
  - REVIEW-001: Loop review & critique phase (#40)
  - WORKTREE-001: Git worktree isolation per agent (#44, deferred to Phase 2+)
  - MODEL-001: Model tiering per agent (#46, 40-60% cost savings)
- [CTO] SMART-CYCLE-DESIGN.md (06-backend) APPROVED — 3 open questions answered:
  - Router state → `.orchystraw/` (gitignored, ephemeral)
  - Reviews are advisory only (never block merge)
  - No agent cap per group (cost control via usage guard, not topology)
- [CTO] Tech registry updated: 10 domain decisions total (5 LOCKED + 5 APPROVED)
- [CTO] agents.conf v2 format approved: columns 6-8 (priority, depends_on, reviews), column 9 (model). Backward compatible.

## QA Findings
- [CTO] BUG-012 expanded: 8 prompts missing PROTECTED FILES (was 3). Missing from: 01-ceo, 03-pm, 04-tauri-rust, 05-tauri-ui, 07-ios, 10-security, 12-brand, 13-hr

## Blockers
- (none)

## Notes
- [CTO] v0.2.0 implementation order: Phase 1 = EXEC-001 (dynamic-router.sh) → Phase 2 = REVIEW-001 (review-phase.sh) → Phase 2+ = WORKTREE-001. MODEL-001 can ship independently.
- [CTO] 06-backend: dynamic-router.sh already built and tested (26 tests PASS) — EXEC-001 ADR codifies the architecture. Next: CS integrates into auto-agent.sh.
- [CTO] Backend's dynamic-router.sh matches EXEC-001 spec — CTO pre-approves the implementation.
