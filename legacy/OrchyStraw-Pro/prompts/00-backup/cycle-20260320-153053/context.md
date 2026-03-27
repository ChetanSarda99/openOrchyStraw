# Shared Context — Cycle 3 — 2026-03-20 15:20:42
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=100
overall=100

## Progress (last cycle → this cycle)
- Previous cycle: 2 (? backend, ? frontend, 1 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- ✅ **#47 P0: BENCH-001 benchmark harness** — Steps 1-5 COMPLETE
  - `scripts/benchmark/run-benchmark.sh` — main entry point (--suite, --limit, --model, --parallel, --dry-run, --resume, --report)
  - `scripts/benchmark/lib/instance-runner.sh` — single-instance execution (clone, agent, eval, rogue write detection)
  - `scripts/benchmark/lib/cost-estimator.sh` — pre-run cost estimation (sonnet/opus/haiku pricing)
  - `scripts/benchmark/lib/results-collector.sh` — JSONL aggregation + markdown report generation
  - `scripts/benchmark/custom/tasks.jsonl` — 5 custom tasks (3 Django, 1 DRF, 1 SymPy)
  - `scripts/benchmark/custom/ralph-baseline.sh` — single-agent comparison runner
  - Security: repo URL validation (CRITICAL-02), patch validation, no eval injection
- ✅ **#75 P1: prompt-adapter.sh** — 3 model adapters (claude/openai/gemini) + detection + agents.conf lookup. 41 tests pass.
- ✅ **#82 P1: model-fallback.sh** — Auto-fallback routing (primary→secondary→tertiary). Reads usage from env/context file. Custom chains. 23 tests pass.
- ✅ **#81 P2: max-cycles.sh** — Override via MAX_CYCLES env or .orchystraw/max-cycles file. Validation + clamping (1-100). 30 tests pass.
- **Tests:** 35/35 pass (32 existing + 3 new modules). 94 new assertions total.
- **CODEBASE:** src/core/ now has 34 modules, tests/core/ has 36 test files
- NEED: CTO review of new modules. QA verify benchmark harness with jq installed.

## iOS Status
- (fresh cycle)

## Design Status
- 11-Web: STANDBY — build verified (25 pages, 0 errors), no new work this cycle
- Deploy still BLOCKED on CS enabling GitHub Pages (#44)
- Benchmarks page ready for real data when backend ships #47
- 08-Pixel: P0 e2e validation of #16 integration — COMPLETE
  - New: `src/pixel/test-e2e-validation.sh` — 55/55 pass (all 9 agents, PM visits, PIXEL_ENABLED guard, character map coverage, timestamp format)
  - Existing: `test-adapter.js` 50/50 pass, `test-pipeline.js` 27/27 pass
  - Full pipeline validated: bash emitter → JSONL → adapter → WebSocket → browser
  - All 9 agents in agents.conf have matching character-map.json entries
  - Ready for Phase 4 (interactive features) when CEO lifts feature freeze

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## CTO Status
- Architecture review: run-swebench.sh CRITICAL-02 + HIGH-01 fix — **PASS** (regex whitelist, metachar rejection, directory traversal block)
- Architecture review: auto-agent.sh #52 + #16 + QA-F005 — **PASS** (set -euo pipefail, printf migration, pixel hooks, re-protected)
- Hardening doc updated with cycle 3 review section
- Proposals inbox: empty — no pending decisions
- All v0.2.0 shipped code architecture-reviewed and approved

## Notes
- (none)
