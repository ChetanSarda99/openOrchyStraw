# QA Cycle 22 Report

**Date:** 2026-04-10 13:54
**Cycle:** 1 (session) / 22 (cumulative QA cycle)
**Reviewer:** 09-qa-code
**Branch:** auto/cycle-1-0410-1351
**Verdict:** **PASS** — 44/44 test files, all priority dry-run flows clean, one minor cosmetic bug filed (LOW)

---

## Summary

| Gate | Result |
|------|--------|
| `bash -n scripts/auto-agent.sh` | PASS |
| `bash -n src/core/*.sh` (35 modules) | PASS |
| `tests/core/run-tests.sh` | **44 passed, 0 failed** |
| `auto-agent.sh orchestrate --dry-run` | PASS — 12 agents, preview table rendered, no side effects |
| `auto-agent.sh list` | PASS — 12 agents loaded from agents.conf |
| `auto-agent.sh status` | PASS — shows branch + last-run times |
| `test-single-agent.sh` (40 assertions) | PASS |
| `scripts/benchmark/run-benchmark.sh --suite basic --dry-run` | PASS — 3 test cases enumerated |

**Regressions since cycle 21:** none.

---

## P0 — Full Test Suite

`bash tests/core/run-tests.sh` → **44 passed, 0 failed**.

Covers: agent-timeout, audit-cost, bash-version, conditional-activation, config-validator,
cycle-state, cycle-tracker, decision-store, differential-context, dry-run, dynamic-router,
e2e-dry-run, e2e-orchestration, error-handler, freshness-detector (×2), global-cli,
health-dashboard, init-project (×2), integration, lock-file, logger, memory, model-fallback,
model-selector, observability, pr-review, project-registry, prompt-compression,
prompt-template (×2), qmd-refresher, quality-gates, quality-scorer, review-phase,
session-tracker, signal-handler, single-agent (×2), task-decomposer (×2), v020-extended,
worktree.

No flakes, no skips. Total ~44 suites held by `run-tests.sh`.

---

## P1 — `orchestrate --dry-run`

Command: `bash scripts/auto-agent.sh orchestrate --dry-run`

- All 12 agents load from agents.conf.
- Preview table lists all 12 agents with EXISTS=yes, OK=YES, LINES>30 for each.
- Parallel groups computed correctly: 3 groups of 4 agents.
- File ownership paths listed per agent.
- "Nothing was executed" banner present — no side effects.
- Exit code: 0.

**Observation (minor):** The INTERVAL column in the preview table prints `every` (without
the number) when `interval == 1`, while `interval == 2/3/5` print `every 2`, `every 3`, etc.
See **BUG-026** below.

---

## P1 — Single-Agent Mode

- `auto-agent.sh list` — loads 12 agents, correct labels + ownerships + intervals.
- `auto-agent.sh status` — shows current branch, config path, per-agent last-run timestamps.
- `tests/core/test-single-agent.sh` — **40/40 assertions PASS** (v3 config parsing, cycle counting, agent routing, double-source guard, etc.).

`src/core/single-agent.sh` module behavior verified via its unit suite; no side effects observed.

---

## P2 — Benchmark Dry-Run

Command: `bash scripts/benchmark/run-benchmark.sh --suite basic --dry-run`

- Discovers 3 test cases: `bugfix-calculator`, `missing-tests`, `outdated-readme`.
- Opens results JSONL path under `scripts/benchmark/results/`.
- Reports max_cycles=3, timeout=300s, compare=no.
- Exits cleanly under dry-run mode; nothing executed. Exit code: 0.

---

## New Bugs Filed

### BUG-026 (LOW) — Dry-run preview table shows `every` instead of `every 1` for interval=1
- **File:** `src/core/dry-run.sh:230`
- **Code:**
  ```bash
  case "$interval" in
      0) interval_label="last"    ;;
      1) interval_label="every"   ;;          # ← inconsistent
      *) interval_label="every ${interval}" ;;
  esac
  ```
- **Expected:** `every 1` (to match "every 2", "every 3", "every 5").
- **Actual:** bare `every` — easy to misread as "malformed" or "missing value" at a glance,
  especially since `auto-agent.sh list` output *above* the table says `every 1 cycles`.
- **Impact:** Cosmetic only — functionality unaffected. Intent was likely "every cycle", but
  inconsistency with the rest of the column makes the table look truncated.
- **Severity:** LOW
- **Assigned to:** 06-backend
- **Suggested fix:** change line 230 to `1) interval_label="every 1" ;;` (keeps grid aligned
  and matches `auto-agent.sh list` wording).

No other new bugs this cycle.

---

## Verification of Previously Filed Bugs

All items from cycle 21 remain closed. No new regressions detected in the 44-test suite.
`test-conditional-activation.sh` still passes 35/35 (no regression of T5 fix).

---

## Recommendations for Next Cycle

1. **06-backend** — fix BUG-026 one-line cosmetic in `src/core/dry-run.sh:230`. Add a small
   dry-run assertion if desired (grep the preview output for `| every  |` → should be
   `| every 1 |`).
2. **09-qa-code next cycle** — repeat full suite + add an end-to-end smoke that runs
   `auto-agent.sh orchestrate --dry-run` and greps the preview table for consistent INTERVAL
   column values.
3. No release-blocking items. Orchestrator and all scaffold paths are green for v0.5.0
   continued work.

---

## Sign-Off

**Verdict:** PASS.
Full test suite, orchestrator dry-run, list/status commands, single-agent mode, and
benchmark dry-run all green. One minor cosmetic bug filed (LOW, non-blocking).

— 09-qa-code
