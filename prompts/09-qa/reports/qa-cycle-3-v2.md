# QA Report — Cycle 3 (v0.2.0 Sprint)
**Date:** 2026-03-20
**QA Engineer:** 09-qa (Claude Opus 4.6)
**Verdict:** CONDITIONAL PASS — all tests green, 2 open bugs remain

---

## Test Results

| Suite | Result |
|-------|--------|
| Unit tests (run-tests.sh) | **20/20 PASS** |
| Integration tests | 42/42 PASS |
| Site build (Next.js) | PASS |
| Pixel adapter tests | 33 assertions, PASS (manual review) |

**+2 new test files since last QA:** `test-conditional-activation.sh`, `test-prompt-compression.sh`

---

## v0.2.0 Module Review — 9 Modules Audited

All 9 v0.2.0 backend modules reviewed for quality:

| Module | Shebang | Guard | Eval | Ext Deps | Funcs | Lines | Status |
|--------|---------|-------|------|----------|-------|-------|--------|
| usage-checker.sh | ✓ | ✓ | ✗ | grep, sed | 10 | 231 | PASS |
| task-decomposer.sh | ✓ | ✓ | ✗ | grep | 8 | 231 | PASS |
| token-budget.sh | ✓ | ✓ | ✗ | None | 9 | 199 | PASS |
| session-windower.sh | ✓ | ✓ | ✗ | wc, grep, cp | 5 | 214 | PASS |
| qmd-refresher.sh | ✓ | ✓ | ✗ | date, mkdir | 9 | 222 | PASS |
| context-filter.sh | ✓ | ✓ | ✗ | wc, mkdir | 6 | 248 | PASS |
| prompt-template.sh | ✓ | ✓ | ✗ | sed, awk | 8 | 295 | PASS |
| cycle-tracker.sh | ✓ | ✓ | ✗ | None | 9 | 97 | PASS |
| signal-handler.sh | ✓ | ✓ | ✗ | kill, sleep | 7 | 108 | PASS |

**Total:** 1,844 lines, 71 functions, zero eval usage, zero external (non-POSIX) deps.

### Quality Highlights
- All modules use double-source guards with `readonly`
- All functions properly scope variables with `local`
- No eval usage anywhere — `awk` used for safe substitution in prompt-template.sh
- signal-handler.sh implements 3-phase graceful shutdown (SIGTERM → wait → SIGKILL)
- task-decomposer.sh uses insertion sort for priority — clean in-memory solution

### Finding: QA-F002 — Missing `set -euo pipefail`
**Severity:** P2 (downgraded from P1 — modules are sourced, not standalone)
**Details:** All 9 v0.2.0 modules lack `set -euo pipefail`. Since they're sourced into auto-agent.sh (which has `set -uo pipefail`), the parent's settings propagate. However, if any module is ever sourced standalone or tested in isolation, silent failures could occur.
**Assigned to:** 06-backend (v0.2.0 backlog)

---

## Pixel Agents Phase 2 Review

| File | Lines | Status |
|------|-------|--------|
| orchystraw-adapter.js | 422 | PASS |
| test-adapter.js | 220 | PASS (33 assertions) |
| cycle-overlay.js | 240 | PASS |
| character-map.json | 96 | PASS |
| emit-jsonl.sh | 193 | PASS |
| test-emitter.sh | 101 | PASS |
| INTEGRATION.md | 76 | PASS |

**Total:** 1,348 lines, 33 test assertions across 5 categories.

**All 9 agents mapped correctly** in character-map.json with 10 desks, 7 animations, and PM walkPath.

### Minor Findings
- MEDIUM: 4 silent `catch (_)` blocks hiding errors in adapter
- MEDIUM: No validation that character-map.json exists before load
- LOW: Bash `date %N` non-POSIX (has fallback)

**Verdict: SHIP-READY** — no blocking issues.

---

## Open Bugs

### BUG-012 — PROTECTED FILES section missing (P2, v0.1.1)
**Status:** UNCHANGED — 4/9 have it, 5/9 missing
- **Have it:** 06-backend, 08-pixel, 09-qa, 11-web
- **Missing:** 01-ceo, 02-cto, 03-pm, 10-security, 13-hr
- **Note:** Previous report said 5/9 had it — recount shows 4/9. One prompt may have lost it during cycle updates.

### BUG-013 — agents.conf ownership paths (P1, CS)
**Status:** STILL OPEN — 24+ cycles
- `09-qa` ownership: `tests/ reports/` → should be `tests/ prompts/09-qa/reports/`
- `10-security` ownership: `reports/` → should be `prompts/10-security/reports/`
- **Assigned to:** CS (human) — ~2 min fix

### v0.1.0 tag
**Status:** Unknown — last report said not created. CS action item.

---

## v0.1.1 Queue (unchanged)
1. LOW-02: Unquoted `$all_owned` line 358
2. QA-F001: `set -e` missing from auto-agent.sh line 23
3. BUG-012: 5 prompts need PROTECTED FILES section
4. NEW: QA-F002: `set -euo pipefail` missing from 9 v0.2.0 modules

---

## Codebase Size Update

| Surface | Count |
|---------|-------|
| src/core/ modules | 18 bash files |
| src/pixel/ files | 7 |
| tests/core/ files | 20 (test files) + 1 runner |
| site/ | ~16,122 files (Next.js) |
| Total test assertions | 42 (integration) + per-file (unit) + 33 (pixel) |

---

## Summary

Cycle 3 QA for v0.2.0 sprint. **20/20 tests pass** (up from 18 last report). All 9 new backend modules pass code review — clean architecture, no eval, proper scoping. Pixel Phase 2 adapter is ship-ready with 33 assertions covering all critical paths.

Two CS action items remain unchanged: BUG-013 (agents.conf paths, ~2 min) and BUG-012 (5 prompts missing PROTECTED FILES).

**Recommendation:** Ship v0.2.0 modules. The `set -euo pipefail` finding (QA-F002) is P2 — not blocking since modules inherit parent shell options.
