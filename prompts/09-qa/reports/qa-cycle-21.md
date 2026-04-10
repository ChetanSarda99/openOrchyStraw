# QA Cycle 21 Report

**Date:** 2026-04-10 02:35
**Cycle:** 1 (session) / 21 (cumulative QA cycle)
**Reviewer:** 09-qa-code
**Verdict:** **PASS** — 44/44 test files, all priority dry-run flows clean, one regression caught + verified fixed this cycle

---

## Summary

| Gate | Result |
|------|--------|
| `bash -n src/core/*.sh` (37 modules) | PASS |
| `bash -n scripts/*.sh` | PASS |
| `tests/core/run-tests.sh` | **44 passed, 0 failed** |
| `test-conditional-activation.sh` | **35/35 assertions PASS** (was T5 FAIL, fixed this cycle) |
| `auto-agent.sh orchestrate --dry-run` | PASS — 12 agents, parallel groups computed, no side effects |
| `auto-agent.sh list` / `status` | PASS — branch=main, 12 agents loaded |
| `scripts/benchmark/run-benchmark.sh --suite basic --dry-run` | PASS — 3 test cases enumerated |

No regressions. No open QA blockers.

---

## Priority task results

### P0 — Full test suite (`tests/core/run-tests.sh`)
**44 passed, 0 failed.** All test files PASS:
- agent-timeout, audit-cost, bash-version, conditional-activation, config-validator
- cycle-state, cycle-tracker, decision-store, differential-context, dry-run
- dynamic-router, e2e-dry-run, e2e-orchestration, error-handler
- freshness-detector (+ v04), global-cli, health-dashboard
- init-project (+ v04), integration, lock-file, logger, memory
- model-fallback, model-selector, observability, pr-review, project-registry
- prompt-compression, prompt-template (+ v04), qmd-refresher
- quality-gates, quality-scorer, review-phase, session-tracker
- signal-handler, single-agent (+ v04), task-decomposer (+ v04)
- v020-extended, worktree

### P1 — Dry-run orchestration mode
`bash scripts/auto-agent.sh orchestrate --dry-run` completes cleanly:
- Loads 12 agents, initializes router, observability, memory, decision store
- Prints agent table with line counts and OK status for all 12 prompts
- Prints parallel group plan (3 groups × 4 agents)
- Prints ownership map
- Exits without side effects

### P1 — Single-agent / list / status modes
- `auto-agent.sh list` — 12 agents printed with intervals and ownership labels
- `auto-agent.sh status` — branch, config path, 12-agent table with interval + last-run timestamps
- `src/core/single-agent.sh` sources cleanly

### P2 — Benchmark dry-run
`bash scripts/benchmark/run-benchmark.sh --suite basic --dry-run` runs cleanly:
- Finds 3 test cases (`Fix calculator bugs`, `Create tests for user_auth module`, `Update README to match actual code`)
- Reports target results path, exits without side effects
- Minor UX note: when `--suite` is omitted, script errors with "missing --suite (use: basic, full)" — correct behavior, just could be surfaced in `--help`

---

## Bug lifecycle this cycle

### BUG-026 (HIGH) — Caught, filed, fixed, verified closed in one cycle
**Regression:** commit `913ee39` ("Fix conditional activation properly — open issues + always-run agents (#245)") added a new fallback in `_orch_activation_has_open_issues` that calls `gh issue list --state open` against the current repo. Because the OrchyStraw repo has 250+ open issues, the gh check always returned true, overriding the "no changes → skip" assertion in `test-conditional-activation.sh` T5.

**Symptom on initial run:** `test-conditional-activation.sh` failed at T5, `fail()` called `exit 1`, so T6–T35 (30 assertions) silently did not execute. Full suite reported **43 passed, 1 failed**.

**Timeline:**
1. 09-qa-code discovered the regression during initial `run-tests.sh` pass
2. Traced root cause to `src/core/conditional-activation.sh:306` (untested gh fallback)
3. Filed ChetanSarda99/openOrchyStraw#253 with suggested fix (env-var escape hatch)
4. 06-backend (running in parallel this cycle) landed the same fix independently:
   - `src/core/conditional-activation.sh:330` — `[[ "${ORCH_ACTIVATION_SKIP_ISSUES_CHECK:-}" == "1" ]] && return 1`
   - `src/core/conditional-activation.sh:174-175` — added `_ORCH_ACTIVATION_ISSUES_CHECKED=false` / `_HAS_ISSUES=false` reset inside `orch_activation_init` (bonus: prevents cache leakage across inits)
   - `tests/core/test-conditional-activation.sh:8` — `export ORCH_ACTIVATION_SKIP_ISSUES_CHECK=1` before sourcing
5. 09-qa-code re-ran the suite: **44/44 test files PASS, 35/35 conditional-activation assertions PASS**
6. Closed #253 as already-fixed with QA verification note

**Verification:** production behavior unchanged (no env var set in real cycles → gh fallback still active). Test isolation restored.

### QA-F003 (LOW) — Test failure still aborts remaining assertions
**File:** `tests/core/test-conditional-activation.sh` (and any test using `fail() { exit 1; }`)
**Observation:** during BUG-026 triage, T5 failing meant T6–T35 were invisible. Single-failure-aborts-file is a test ergonomics issue, not a correctness issue.
**Suggested enhancement:** refactor `fail()` to increment FAIL counter without exiting, then `exit $FAIL` at the end. Lets a single run surface all broken assertions.
**Assigned to:** 06-backend (tests/ ownership). **Non-blocking** — queue for a quiet cycle.

---

## What QA verified this cycle
- ✅ 44/44 test files PASS (up from 43/44 pre-BUG-026-fix)
- ✅ 35/35 conditional-activation assertions PASS (up from 4/35 pre-fix)
- ✅ 37/37 `src/core/` modules pass `bash -n`
- ✅ All `scripts/*.sh` pass `bash -n`
- ✅ `auto-agent.sh orchestrate --dry-run` clean for all 12 agents
- ✅ `auto-agent.sh list` / `status` correct
- ✅ Benchmark scaffold `--dry-run` clean
- ✅ BUG-026 fix (06-backend) — behavior, cache reset, and test isolation all verified
- ✅ No regressions elsewhere

---

## Recommendations for next cycle

1. **06-backend:** commit the BUG-026 fix so it lands in git history (currently only in working tree of cycle branch — orchestrator should pick it up at commit phase).
2. **06-backend (quiet cycle):** address QA-F003 — make `fail()` non-fatal so CI surfaces all broken assertions in a single run.
3. **02-cto:** consider whether "open issues fallback" in conditional activation is the right product default. It effectively forces every non-coordinator agent to activate on any repo that has any open GitHub issue. Might warrant:
   - a per-agent opt-in flag in agents.conf, OR
   - a minimum-issue-count or label-filter threshold, OR
   - scoping the check to issues labeled for that specific agent
4. **09-qa-code (next cycle):** add a targeted test that asserts `ORCH_ACTIVATION_SKIP_ISSUES_CHECK=1` actually disables the gh call (regression-prevention).

---

## Git state at review
- Branch: `auto/cycle-1-0410-0232`
- HEAD: `db5d16a Make --force the default — agents run by default, --smart-skip to opt out`
- Fix source: commit `913ee39` (introduced regression); in-progress working-tree edits from 06-backend (this cycle) restore test suite to green
- Working tree: `src/core/conditional-activation.sh` + `tests/core/test-conditional-activation.sh` modified (awaiting orchestrator commit)
