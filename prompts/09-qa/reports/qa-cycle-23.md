# QA Cycle 23 Report

**Date:** 2026-04-10 18:58
**Cycle:** 1 (session) / 23 (cumulative QA cycle)
**Reviewer:** 09-qa-code
**Branch:** auto/cycle-1-0410-1854
**Verdict:** **PASS** — 44/44 tests, all dry-run flows clean, zero regressions since cycle 22, zero new blockers.

---

## Summary

| Gate | Result |
|------|--------|
| `bash -n` all 35 `src/core/*.sh` modules | PASS |
| `tests/core/run-tests.sh` | **44 passed, 0 failed** |
| `scripts/auto-agent.sh orchestrate --dry-run` | PASS — 12 agents, preview table rendered, no side effects |
| `scripts/auto-agent.sh list` | PASS — 12 agents loaded |
| `scripts/auto-agent.sh status` | PASS — branch + last-run shown |
| `bin/orchystraw run . --dry-run --cycles 1` | PASS |
| `bin/orchystraw doctor` | PASS (shellcheck WARN only — optional) |
| `scripts/benchmark/run-benchmark.sh --suite basic --dry-run` | PASS — 3 test cases enumerated |

**Regressions since cycle 22:** none.
**New bugs filed this cycle:** 0.

---

## P0 — Full Test Suite

`bash tests/core/run-tests.sh` → **44 passed, 0 failed.**

Run covered all 44 test files (agent-timeout, audit-cost, bash-version,
conditional-activation, config-validator, cycle-state, cycle-tracker,
decision-store, differential-context, dry-run, dynamic-router, e2e-dry-run,
e2e-orchestration, error-handler, freshness-detector ×2, global-cli,
health-dashboard, init-project ×2, integration, lock-file, logger, memory,
model-fallback, model-selector, observability, pr-review, project-registry,
prompt-compression, prompt-template ×2, qmd-refresher, quality-gates,
quality-scorer, review-phase, session-tracker, signal-handler, single-agent ×2,
task-decomposer ×2, v020-extended, worktree). No flakes, no skips.

Syntax check: `bash -n` passes for all 35 `src/core/*.sh` modules.

---

## P1 — Dry-Run Modes

### `scripts/auto-agent.sh orchestrate --dry-run`
- Loads 12 agents from `agents.conf`.
- Preview shows cycle count, scheduled agents, parallel grouping (Group 1–3, 4 each), file ownership paths.
- Zero side effects confirmed (`Nothing was executed` trailer).
- Exit 0.

### `bin/orchystraw run . --dry-run --cycles 1`
- Same preview, reached through the global CLI path.
- Exit 0.

### `bin/orchystraw doctor`
- bash 5.3, claude 2.1.101, git 2.50.1, gh present.
- `src/core/` reports 35 modules, `template/` 6 templates, registry has 8 projects.
- Only non-blocking item: `shellcheck not found (optional)` — WARN, not FAIL.

---

## P1 — Single-Agent Mode

`src/core/single-agent.sh` sourced cleanly via `test-single-agent.sh` (PASS in the main run). Module syntax clean, behaviour unchanged since cycle 22.

---

## P2 — Benchmark Dry-Run

`bash scripts/benchmark/run-benchmark.sh --suite basic --dry-run`
- 3 test cases discovered and enumerated:
  - `[easy]` Fix calculator bugs (bugfix)
  - `[medium]` Create tests for user_auth module (test-generation)
  - `[easy]` Update README to match actual code (docs-update)
- Exit 0, zero side effects.

Note: invoking the runner without `--suite` correctly errors (`ERROR: missing --suite`) and exits with status 1. This is by-design CLI ergonomics — usage string lists `--suite basic --dry-run` as the canonical invocation. Not a bug.

---

## Cross-Cycle Delta (vs cycle 22)

Only the following code/test paths changed since the cycle-22 report (`1c585c8` and the commits that preceded it within the cycle-22 window):

| File | Change | Review |
|------|--------|--------|
| `scripts/auto-agent.sh` | 18 lines — protected, skipped per rules | N/A |
| `src/core/cofounder.sh` | 26 lines — replaced `sed -i.bak` with portable tempfile loop | PASS (see note below) |
| `scripts/analyze-prompts.sh` | Widened bash-5 auto-detect PATH | PASS |
| `scripts/benchmark/run-cross-project.sh` | Widened bash-5 auto-detect PATH | PASS |
| `tests/core/run-tests.sh` | Widened bash-5 auto-detect PATH + dual-OS install hint | PASS |
| `tests/visual/run-app-qa-full.py` | 17 lines — visual QA suite (out of scope for code QA) | deferred to 09-qa-visual |

### Cofounder refactor review — `src/core/cofounder.sh:243-284`

The `orch_cofounder_adjust_intervals()` function previously used `sed -i.bak`,
which is non-portable (macOS BSD sed vs GNU sed). The new implementation uses
`mktemp` + a `while IFS= read` loop + `mv`. This is correct and portable.

Observations (all accepted, no bugs filed):
- `escaped_id` (line 247) is still used on line 249 for the `grep -E` lookup; not dead code.
- Bash regex on line 267 uses raw `$id`; safe because agent IDs are constrained to kebab-case (`[0-9a-z-]+`).
- `mktemp` defaults to `$TMPDIR`, which may be on a different filesystem than
  `agents.conf`; `mv` falls back to copy+unlink, so this is fine on all supported
  platforms. If it ever fails, the original file is preserved (atomic on same-FS,
  safe on cross-FS).
- `mv` may silently change `agents.conf` permissions from 644 → 600 (mktemp
  default). Low impact — the file is user-owned and not published. Noted, not
  filed.

---

## Bug Ledger Status

Same as cycle 22 — no new bugs filed, no old bugs regressed. Open items inherited from prior cycles remain tracked in their respective GitHub issues (#225, #226, #230, etc.).

---

## Verdict

**PASS.** No blockers, no regressions, all priority gates green. Branch is safe to continue.

---

**Next cycle focus:**
1. Rerun full suite after any cofounder.sh follow-ups.
2. Code-audit any new `src/core/` modules if they land.
3. Watch for unreviewed changes to `scripts/auto-agent.sh` (protected — only CS touches it).
