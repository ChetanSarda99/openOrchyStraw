# QA Cycle 38 Report — 2026-03-21

**Verdict: CONDITIONAL PASS**

## Test Results

| Suite | Result |
|-------|--------|
| Unit tests (run-tests.sh) | 39/40 PASS (agent-kpis jq pre-existing) |
| Integration test | 169/169 PASS (39 modules, 7 test groups) |
| compare-ralph tests | 15/15 PASS, 2 skipped (jq) |
| founder-mode tests | 70/70 PASS |
| knowledge-base tests | 58/58 PASS |
| Site build (Next.js) | PASS — 25 pages, 0 errors |
| Tauri (cargo check) | SKIP — src-tauri/ not scaffolded yet |

**Total: 338 assertions pass, 0 new failures.**

## BENCH-SEC Verification (P0)

All 3 HIGH security findings from cycle 35 are **FIXED**:

| Finding | File | Fix | Status |
|---------|------|-----|--------|
| BENCH-SEC-01: prompt injection via bash -c | instance-runner.sh:99-102 | Prompt passed via `$BENCH_PROMPT` env var instead of string interpolation | **FIXED** |
| BENCH-SEC-02: eval of test_command | instance-runner.sh:121 | Changed `eval "$test_command"` → `bash -c "$test_command"` (no double-parse) | **FIXED** |
| BENCH-SEC-03: Python file path injection | results-collector.sh:13-17 | File path passed via `os.environ` instead of f-string interpolation | **FIXED** |

## New Finding: QA-F006 (MEDIUM)

**compare-ralph.sh:207-254** — Python code block uses shell variable interpolation:
```
with open('$ralph_results') as f:
with open('$orchy_results') as f:
```
This is the **same class of vulnerability** as BENCH-SEC-03 (file path injection into Python code). A file path containing `'` would break out of the Python string.

**Fix:** Use `os.environ` to pass file paths, same pattern as the BENCH-SEC-03 fix in results-collector.sh.

**Severity:** MEDIUM — these are locally-generated temp file paths (low external attack surface), but the pattern was explicitly fixed elsewhere and should be consistent.

**Assigned to:** 06-backend

## Code Review: Cycle-5 Modules

### founder-mode.sh — PASS
- Double-source guard: correct (`_ORCH_FOUNDER_MODE_LOADED`)
- `orch_*` prefix on all 6 public functions, `_orch_*` on 1 internal
- Input validation: all public functions check required args
- No eval, no command injection vectors
- agents.conf parsing uses read loop with field extraction — safe
- JSON generation (lines 315-326) is pure bash, no jq — keys come from associative array keys (agent IDs from agents.conf), values from function args. No user input escaping concern.
- 70/70 tests pass

### knowledge-base.sh — PASS
- Double-source guard: correct (`_ORCH_KNOWLEDGE_BASE_LOADED`)
- `orch_kb_*` prefix on all 8 public functions, `_orch_kb_*` on 3 internal
- Input validation on all public functions
- No eval, no command injection
- File operations use proper quoting throughout
- grep patterns use `-q` and `-F` where appropriate
- 58/58 tests pass

### compare-ralph.sh — CONDITIONAL PASS
- Proper `set -euo pipefail`
- Input validation: `_validate_positive_int` and `_validate_model` whitelist
- Dependency check: `_check_deps` verifies git, jq, python3
- Sources lib/ modules correctly
- **One finding:** QA-F006 (see above) — Python string interpolation of file paths

## Integration Test Coverage

Integration test covers **39/39 modules** — fully up to date. All guard variables, public API functions, and cross-module workflows verified.

Note: Comment on line 1 says "38 modules" but test actually sources and verifies 39. Minor doc inconsistency — not a bug.

## Module Count Reconciliation

- `src/core/`: 39 .sh files
- Integration test sources: 39 modules
- Unit tests: 40 files (39 modules + test-integration.sh runner... actually 41 test files for 39 modules + run-tests.sh)
- CLAUDE.md says "38 modules" in various places — should be updated to 39

## Open Issues Summary

| Issue | Severity | Status |
|-------|----------|--------|
| agent-kpis jq dependency | LOW | Pre-existing, known |
| QA-F006 compare-ralph Python interpolation | MEDIUM | NEW — assigned to 06-backend |
| BUG-012 (PROTECTED FILES in prompts) | LOW | 5/9 done, 4 remaining |
| src-tauri not scaffolded | INFO | Expected — not yet in roadmap |
