# QA Report — Cycle 13
**Date:** 2026-03-30
**Verdict:** CONDITIONAL PASS — core modules clean, SWE-bench scaffold needs security fixes

---

## Test Results

| Suite | Result | Details |
|-------|--------|---------|
| Full test suite | **20/20 PASS** | 0 regressions |
| Syntax check (src/core/*.sh) | **PASS** | 18 modules clean |
| Syntax check (scripts/*.sh) | **PASS** | All scripts clean |
| Syntax check (scripts/benchmark/**/*.sh) | **PASS** | 6 scripts clean |

---

## P0 Verifications

### BUG-019 (#175): VERIFIED FIXED ✅
All 8 `grep -c` instances across 3 scripts use the correct `var=$(grep -c ...) || var=0` pattern:
- `scripts/pre-pm-lint.sh` — 6 instances (lines 85, 86, 116, 117, 168, 186) ✅
- `scripts/post-cycle-router.sh` — 1 instance (line 85) ✅
- `scripts/agent-health-report.sh` — 1 instance (line 77, with `tr` pipe + fallback) ✅
- `scripts/commit-summary.sh` — no `grep -c` usage (not affected)

No `grep -c ... || echo 0` pattern remains in production scripts. Legacy code in `/legacy/` is out of scope.

### qmd-refresher.sh (#53): QA PASS ✅
- 17/17 tests pass independently
- Double-source guard present (`_ORCH_QMD_REFRESHER_LOADED`)
- All public functions use `orch_` prefix (6 public, 3 internal `_orch_`)
- No external deps beyond bash builtins + POSIX utils + `qmd` CLI
- State tracking via `.orchystraw/qmd-last-update` and `.orchystraw/qmd-last-embed` — correct
- Error handling: all functions check `orch_qmd_available` before invoking `qmd`
- No eval, proper quoting, safe subshells — **zero injection risks**
- Test assertions: 42 meaningful assertions (timestamps, return codes, state persistence, edge cases)

**Minor finding (LOW):** qmd-refresher.sh is NOT included in `tests/core/test-integration.sh`. Integration test still only sources the original 8 v0.1.0 modules. Recommend adding it.

### SWE-bench Scaffold: CONDITIONAL PASS ⚠️
Syntax clean. Structure sound. 4 security findings filed:

| Bug | Severity | File | Issue |
|-----|----------|------|-------|
| BUG-020 (#176) | HIGH | instance-runner.sh:21, scaffold.py:43 | URL regex allows `..` in org/repo names |
| BUG-021 (#177) | HIGH | instance-runner.sh:132 | test_command whitelist bypassable via args |
| BUG-022 (#178) | MEDIUM | run-benchmark.sh:88, compare-ralph.sh:92 | Hardcoded /tmp paths, no mktemp |
| BUG-023 (#179) | MEDIUM | run-benchmark.sh:112, instance-runner.sh:76 | jq parsing lacks malformed JSON handling |

**What works well:**
- `lib/cost-estimator.sh` — correct edge case handling (0 instances → $0.00)
- `swebench/scaffold.py` — secure tempfile handling, safe subprocess (list args)
- `lib/results-collector.sh` — path validation implemented
- `custom/tasks.jsonl` — valid JSONL, consistent schema, 6 entries
- All scripts have `set -euo pipefail`

**Recommendation:** BUG-020 and BUG-021 should be fixed before running benchmarks against untrusted repos. For trusted-only usage (internal tasks.jsonl), current state is acceptable.

---

## Bug Tracker

| Bug | Status | Notes |
|-----|--------|-------|
| BUG-019 (#175) | **CLOSED** | Verified fixed this cycle |
| BUG-020 (#176) | NEW (HIGH) | SWE-bench URL validation |
| BUG-021 (#177) | NEW (HIGH) | SWE-bench test_command bypass |
| BUG-022 (#178) | NEW (MEDIUM) | SWE-bench hardcoded /tmp |
| BUG-023 (#179) | NEW (MEDIUM) | SWE-bench jq error handling |

---

## Carry-Forward

- Integration test should be updated to include qmd-refresher.sh + v0.2.0 modules (LOW priority)
- BUG-020/021 should block untrusted benchmark execution; acceptable for internal use
