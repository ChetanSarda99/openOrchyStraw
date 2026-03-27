# Shared Context — Cycle 5 — 2026-03-20 16:09:06
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=100
overall=100

## Progress (last cycle → this cycle)
- Previous cycle: 4 (? backend, ? frontend, 1 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- ✅ `scripts/benchmark/custom/compare-ralph.sh` — head-to-head OrchyStraw vs Ralph comparison runner (#48)
  - Runs both approaches (Ralph single-agent + OrchyStraw multi-agent) on same tasks
  - CLI: --limit, --model, --agents, --cycles, --timeout, --dry-run
  - Generates side-by-side markdown report with per-task winners + delta metrics
  - Tests: 15/15 pass (2 skipped, jq-dependent)
- ✅ `src/core/founder-mode.sh` — always-on front agent with triage/delegation (#61)
  - 6 functions: init, triage, delegate, should_run, override_priority, status
  - Keyword-based triage into 6 categories (bug/feature/refactor/docs/infra/security)
  - Routes to correct agent, interval-aware scheduling, priority overrides
  - Tests: 70/70 pass
- ✅ `src/core/knowledge-base.sh` — cross-project knowledge persistence (#76)
  - 8 functions: init, store, retrieve, search, list, delete, merge_on_init, export
  - Persists to ~/.orchystraw/knowledge/ across projects
  - Domain/key organization, index file, merge (newer wins), markdown export
  - Tests: 45/45 pass
- All syntax checks PASS. Existing test suite: 38/39 pass (agent-kpis jq issue pre-existing)
- CODEBASE: src/core/ now has 36 modules, tests/core/ has 38 test files

## iOS Status
- (fresh cycle)

## Design Status
- 11-Web: STANDBY — build verified (25 pages, 0 errors), Phase 17 blocked on benchmark results (scripts/benchmark/results/ still missing), Phase 18 blocked on #48, deploy blocked on CS enabling GitHub Pages (#44, 19th cycle asking)

## QA Findings
- QA cycle 35 report: `prompts/09-qa/reports/qa-cycle-35.md`
- Verdict: CONDITIONAL PASS — no regressions, 36/37 unit tests pass, site build PASS
- test-agent-kpis FAIL: jq not installed in env (not a code bug) — filed QA-F006
- QA-F004 STILL OPEN: integration test covers 8/36 modules
- Benchmark harness: syntax PASS, dry-run PASS, **3 HIGH security findings** (BENCH-SEC-01/02/03)
  - BENCH-SEC-01: command injection in instance-runner.sh (prompt escaping)
  - BENCH-SEC-02: unsafe eval in instance-runner.sh (test_command from JSON)
  - BENCH-SEC-03: Python shell escape in results-collector.sh (file path)
- All 5 new modules code reviewed: ALL PASS (178/178 assertions, proper orch_* prefix, no eval)
- NEED: 06-Backend fix BENCH-SEC-01/02/03 before real benchmark runs
- NEED: 06-Backend expand test-integration.sh to 36 modules (QA-F004)

## Blockers
- (none)

## Notes
- (none)
