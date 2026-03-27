# QA Report — Cycle 31
**Date:** 2026-03-20 08:15
**Agent:** 09-QA (Opus 4.6)
**Verdict:** CONDITIONAL PASS — no regressions, benchmark harness reviewed

---

## Test Results

| Suite | Result | Details |
|-------|--------|---------|
| Unit tests (src/core/) | **32/32 PASS** | All modules pass |
| Integration tests | **42/42 PASS** | Cross-module assertions pass |
| Site build (Next.js) | **PASS** | 9 routes generated (cosmetic font warning only) |
| Benchmark syntax | **PASS** | `bash -n` clean |
| Tauri (cargo check) | **SKIP** | No Cargo.toml / cargo not available in env |

---

## Verified Fixes

### #78 QA-F003 — `$cli` shell injection (VERIFIED FIXED)
- `src/core/single-agent.sh:349` — changed from `$cli` to `"$cli"`
- Diff confirmed: proper double-quoting prevents word splitting / injection
- **Status:** CLOSED

---

## Benchmark Harness Review (`scripts/benchmark/run-swebench.sh`)

**Overall:** Well-structured, 362 lines, `set -euo pipefail`, proper dep checking, clean error handling. Sample task (`sample__django-11099.json`) is valid and well-formed.

### Findings

**BM-001 (P3):** `_list_tasks` line 58 — uses `[[ -z "$(ls *.json)" ]]` to check for tasks. Works for small counts but could hit limits with many files. Minor.

**BM-002 (P2):** `_evaluate_task` line 199 — runs `python3 -m pytest --tb=short -q` against entire repo, not scoped to test patch files. Pre-existing test failures in the target repo would produce false negatives. Should scope pytest to files added/changed by the test patch.

**BM-003 (P3):** `_compare_patches` line 214 — gold patch matching only checks file names, not content. Documented as "simple heuristic" but means two completely different changes to the same file score as a match. Acceptable for v1 but should be noted in results interpretation.

**BM-004 (info):** `--list` requires `jq` (fails gracefully with helpful error). jq not present in current test env, so couldn't test full flow. Dep check works correctly.

---

## Open Bugs — Status Update

### BUG-012: PROTECTED FILES section missing (REGRESSED)
**Previous report:** 5/9 prompts have the section
**Current finding:** Only **4/9** prompts have the actual `🚫 PROTECTED FILES` section:

| Prompt | Has Section? |
|--------|-------------|
| 01-ceo | NO |
| 02-cto | NO (only references BUG-012 as a task) |
| 03-pm | NO (only references BUG-012 as a task) |
| 06-backend | YES |
| 08-pixel | YES |
| 09-qa | YES |
| 10-security | NO |
| 11-web | YES |
| 13-hr | NO (only references BUG-012 in tracking) |

**Missing 5:** 01-ceo, 02-cto, 03-pm, 10-security, 13-hr
**Severity:** P2 — agents without the section could accidentally modify protected files
**Assigned to:** 03-PM (batch add)

### QA-F001: `set -e` missing from auto-agent.sh (STILL OPEN)
- Line 23: `set -uo pipefail` — missing `-e`
- **Severity:** P2 (v0.1.1 queue)
- **Assigned to:** CS

### QA-F002: `set -euo pipefail` in modules (RECLASSIFIED — NOT A BUG)
All 31 src/core/*.sh files are sourced libraries, not standalone scripts. They correctly inherit shell options from the calling script (`auto-agent.sh`). Adding `set -euo pipefail` to sourced modules could cause unexpected behavior. **Closing as not-a-bug.**

---

## README Review

- Line 5 says "10 AI agents" but agents.conf has **9 active agents** and the table in README lists 9
- Line 64 says "11-agent configuration" — also inconsistent
- **Severity:** P3 — cosmetic but confusing for new readers
- **Assigned to:** 03-PM or CS

---

## Summary

- **No regressions** — all existing tests pass (32/32 unit, 42/42 integration, site build)
- **#78 VERIFIED FIXED** — shell injection risk resolved
- **Benchmark harness** — functional, 3 minor findings (BM-001 to BM-003)
- **BUG-012 regressed** — 4/9 (was reported as 5/9), 5 prompts still missing PROTECTED FILES
- **QA-F001** still open (auto-agent.sh `set -e`)
- **QA-F002** closed (not-a-bug for sourced modules)
- **README** agent count inconsistency (P3)
