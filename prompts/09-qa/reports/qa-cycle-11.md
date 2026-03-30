# QA Report — Cycle 11 (v0.2.0+ Module Review: worktree, prompt-compression, conditional-activation, differential-context)

**Date:** 2026-03-29
**QA Engineer:** 09-QA (Claude Opus 4.6)
**Verdict: PASS — all 4 modules reviewed, 145/145 tests pass, 17/17 full suite PASS**

---

## Executive Summary

Deep code review and test verification of the 4 remaining v0.2.0+ modules:
worktree.sh (48 tests), prompt-compression.sh (30 tests), conditional-activation.sh
(25 tests), differential-context.sh (42 tests). All pass with high quality. One LOW
finding: dead code in conditional-activation.sh. Two notes on minor inconsistencies.
Combined with the previous QA cycle 10 PASS (dynamic-router + review-phase), all
v0.2.0+ modules have now been QA-reviewed.

---

## 1. Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| run-tests.sh (full suite) | 17/17 files | ALL PASS |
| test-worktree.sh | 48/48 tests | ALL PASS |
| test-prompt-compression.sh | 30/30 tests | ALL PASS |
| test-conditional-activation.sh | 25/25 tests | ALL PASS |
| test-differential-context.sh | 42/42 tests | ALL PASS |
| bash -n syntax check (4 modules) | 4/4 | ALL PASS |

**Total v0.2.0+ test assertions:** 245 (48+30+25+42 + 41+36+9+14 from prior cycles)
**Regressions:** 0

---

## 2. Module Reviews

### worktree.sh — PASS

**Quality:** High. Clean implementation of WORKTREE-001 ADR with full lifecycle coverage.

**Verified:**
- Path traversal prevention (rejects `..` and `/` in agent_id, numeric-only cycle_num)
- Stale worktree auto-cleanup on re-create
- Crash recovery via `orch_worktree_cleanup` + `git worktree prune`
- Git 2.15+ version check
- Merge conflict detection returns non-zero (caller handles)
- `--no-ff` merge strategy matches ADR spec
- Filesystem isolation verified: agents cannot see each other's in-progress changes
- No-op merge when branch has zero commits ahead

**ADR Deviation (beneficial):** WORKTREE-001 specified inline implementation in
`auto-agent.sh`. Actual implementation is a standalone module — this is better (modular,
testable, matches the architecture pattern of all other v0.2.0 modules). Not a bug.

**Test coverage gap (non-blocking):** No test for ORCH_WORKTREE_TMPDIR pointing to
nonexistent directory. The `git worktree add` would fail and the error path handles it
correctly, but explicit coverage would be nice.

### prompt-compression.sh — PASS

**Quality:** High. Three-tier classification with three compression modes.

**Verified:**
- Tier classification: stable (tech stack, ownership, rules), dynamic (tasks, done, status),
  reference (git safety, auto-cycle, research protocol)
- Compression modes: full (everything), standard (stable condensed), minimal (dynamic only)
- Hash-based stable section change detection (SHA-256, deterministic)
- Token estimation (~4 chars/token, documented approximation)
- State persistence: save/load hash round-trip works
- Mode decision logic: first run → full, stable unchanged → standard, stable changed → full,
  over 2x budget → minimal
- Edge cases: empty file, missing file, no stable sections, nonexistent hash file

**No issues found.**

### conditional-activation.sh — PASS

**Quality:** High. Three activation criteria with fail-open design.

**Verified:**
- Owned files changed → activate
- Context mentions (agent ID or label + keyword) → activate
- PM force flag → always activate
- No changes + no mentions → skip
- Coordinator (interval=0) automatically excluded from activation checks
- Fail-open: returns "run" if not initialized
- Ownership exclusion support (`!path` syntax)
- Reason tracking for each decision

**BUG-018 NEW (LOW):** Dead code — `_ORCH_ACTIVATION_MENTION_PATTERNS` array (lines 34-42)
is declared but never referenced. The actual mention detection uses inline `=~` checks.
Not harmful but should be removed.
**Assigned to:** 06-backend

### differential-context.sh — PASS

**Quality:** High. Well-designed section→agent mapping with cross-cycle history filtering.

**Verified:**
- Default mappings: universal (usage, progress, blockers, notes, QA findings) and
  role-mapped (backend-status → backend/cto/qa/security/pm)
- PM bypass: gets everything (both context and history)
- Fail-open: unmapped sections included by default
- Dependency-aware history: QA sees backend entries when depends_on=06-backend
- Cross-reference detection: mentions of agent in unrelated blocks are caught
- Key normalization: strips emoji, lowercases, spaces→dashes
- Custom mapping override works
- Error handling: parse/filter before init returns error

**Notes:**
1. Uses `sed` and `awk` for key normalization and column counting — minor deviation from
   "no external deps" philosophy. Both are POSIX-standard and universally available.
2. History filtering uses `###` headers to detect agent blocks — format-coupled to
   orchestrator's history output, which is acceptable since the orchestrator controls both.

---

## 3. Cross-Module Observations

### Test File Consistency
- 16/17 test files use `set -euo pipefail`
- `test-worktree.sh` uses `set -uo pipefail` (missing `-e`) — intentional: its assertion
  pattern uses functions that return non-zero on expected failures, which `-e` would abort on.
  The other tests use `fail()` with explicit `exit 1`. No action needed.

### Architecture Pattern
All 4 modules follow the established pattern:
- `#!/usr/bin/env bash` shebang ✅
- Double-source guard (`_LOADED` variable) ✅
- Internal `_orch_*_log()` helper that delegates to `orch_log` if available ✅
- Public API functions with `orch_*` prefix ✅
- Input validation on public functions ✅
- No global side effects on source ✅

### Security
- worktree.sh: Path traversal blocked (agent_id and cycle_num validated)
- conditional-activation.sh: No security concerns (read-only analysis)
- prompt-compression.sh: No security concerns (read-only prompt parsing)
- differential-context.sh: No security concerns (filtering only)

---

## 4. Known Bug Status

| Bug | Status | Notes |
|-----|--------|-------|
| BUG-013 | STILL OPEN | README "Bash 4+" → "Bash 5+". Non-blocking, v0.1.1 item. |
| BUG-012 | STILL OPEN | 4 prompts missing PROTECTED FILES section. v0.1.1 item. |
| QA-F001 | STILL OPEN | `auto-agent.sh` line 23: `set -uo pipefail` missing `-e`. v0.1.1 item. |
| BUG-018 | NEW (LOW) | Dead code `_ORCH_ACTIVATION_MENTION_PATTERNS` in conditional-activation.sh. |

---

## 5. Verdict

**PASS** — All 4 v0.2.0+ modules pass QA review with 145/145 tests, clean syntax,
correct architecture patterns, and proper security practices. One LOW finding (dead code).

With this cycle, **all 8 v0.2.0+ modules have been QA-reviewed:**

| Module | Tests | QA Cycle | Status |
|--------|-------|----------|--------|
| dynamic-router.sh | 41 | Cycle 9 | PASS |
| review-phase.sh | 36 | Cycle 10 | PASS |
| worktree.sh | 48 | Cycle 11 | PASS |
| prompt-compression.sh | 30 | Cycle 11 | PASS |
| conditional-activation.sh | 25 | Cycle 11 | PASS |
| differential-context.sh | 42 | Cycle 11 | PASS |
| signal-handler.sh | 9 | Cycle 2 | PASS |
| cycle-tracker.sh | 14 | Cycle 2 | PASS |

**Total v0.2.0+ tests: 245 — ALL PASS**

---

## 6. Recommendations

1. **CS: Tag v0.1.0** — Fix BUG-013 and tag. All P0 blockers cleared for 8+ cycles.
2. **06-backend:** Remove dead `_ORCH_ACTIVATION_MENTION_PATTERNS` array (BUG-018).
3. **10-security:** Security review of worktree.sh + prompt-compression.sh +
   conditional-activation.sh + differential-context.sh — QA review passed, security
   review still needed for 5 modules.
4. **CS: Integrate v0.2.0 modules** — All 8 modules QA-PASS. Ready for integration.

---

## 7. Full Test Inventory

| File | Tests | Status |
|------|-------|--------|
| test-agent-timeout.sh | unit | PASS |
| test-bash-version.sh | unit | PASS |
| test-conditional-activation.sh | 25 unit | PASS |
| test-config-validator.sh | unit | PASS |
| test-cycle-state.sh | unit | PASS |
| test-cycle-tracker.sh | 14 unit | PASS |
| test-differential-context.sh | 42 unit | PASS |
| test-dry-run.sh | unit | PASS |
| test-dynamic-router.sh | 41 unit | PASS |
| test-error-handler.sh | unit | PASS |
| test-integration.sh | integration (42 assertions) | PASS |
| test-lock-file.sh | unit | PASS |
| test-logger.sh | unit | PASS |
| test-prompt-compression.sh | 30 unit | PASS |
| test-review-phase.sh | 36 unit | PASS |
| test-signal-handler.sh | 9 unit | PASS |
| test-worktree.sh | 48 unit (real git repos) | PASS |
