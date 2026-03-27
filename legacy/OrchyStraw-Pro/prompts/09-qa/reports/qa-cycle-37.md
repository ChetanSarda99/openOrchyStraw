# QA Report — Cycle 37 (Session 6 Cycle 1)
**Date:** 2026-03-20
**Verdict:** CONDITIONAL PASS

---

## Test Results

| Suite | Pass | Fail | Notes |
|-------|------|------|-------|
| Unit tests | 39/40 | 1 | agent-kpis fails (jq not installed — pre-existing) |
| Integration test | PASS | — | 39/39 modules sourced, 7 test groups, 0 failures |
| Site build | PASS | — | 27/27 pages, 0 errors (font warnings cosmetic) |
| Tauri build | SKIP | — | src-tauri/ directory not yet created |

---

## P0 Task Status

### QA-F004: Integration Test Expansion
**Status:** DONE — integration test now sources 39/39 modules (was 8 in cycle 2).
All modules listed in src/core/ are covered. No gaps found.
Note: test header comment says "38 modules" but sources 39 — minor doc inconsistency.

### BENCH-SEC-01/02/03 Verification
**Status:** ALL 3 FULLY FIXED.

| Finding | Status | Details |
|---------|--------|---------|
| BENCH-SEC-01 (prompt injection via bash -c) | FIXED | instance-runner.sh:99-102 — env vars instead of string interpolation |
| BENCH-SEC-02 (eval of test_command from JSON) | FIXED | Changed `eval` → `bash -c` + added `_validate_test_command()` allowlist/blocklist (line 38-56). Blocks dangerous patterns, requires known test runners. |
| BENCH-SEC-03 (Python shell escape in file paths) | FIXED | results-collector.sh:13-17 — env vars instead of Python string interpolation |

---

## P1 Task: Cycle 5 Module Code Review

All 3 modules reviewed. **ALL PASS.**

| Module | orch_* Naming | No eval | Quoting | Error Handling | Verdict |
|--------|--------------|---------|---------|----------------|---------|
| founder-mode.sh | PASS (orch_founder_*) | PASS | PASS | PASS | PASS |
| knowledge-base.sh | PASS (orch_kb_*) | PASS | PASS | PASS | PASS |
| compare-ralph.sh | MINOR (uses _* prefix, not orch_*) | PASS | PASS | PASS | PASS |

Note: compare-ralph.sh is in scripts/benchmark/custom/ (not src/core/), so naming convention deviation is acceptable — it's a standalone script, not a sourced module.

---

## Module Count Audit

| Location | Count |
|----------|-------|
| src/core/*.sh | 39 |
| tests/core/test-*.sh | 40 |
| Integration test sources | 39/39 |

1 extra test file (`test-compare-ralph.sh` or similar) — not an issue, tests can exceed modules.
Shared context claims 38 modules — **should be updated to 39** (model-registry.sh was added).

---

## Known Issues (Unchanged)

| Issue | Severity | Status |
|-------|----------|--------|
| agent-kpis.sh test fails (jq missing) | LOW | Pre-existing, env-dependent |
| BUG-012 (4 prompts missing PROTECTED FILES) | P2 | 5/9 done, PM batch pending |
| BENCH-SEC-02 | CLOSED | Fully hardened with _validate_test_command() allowlist |
| Integration test header says "38" not "39" | LOW | Doc cosmetic |

---

## Recommendations
1. Install jq on CI/test environments to unblock agent-kpis tests
2. Update shared context module count from 38 → 39
3. BENCH-SEC-02 fully resolved — `_validate_test_command()` allowlist already shipped by Backend
