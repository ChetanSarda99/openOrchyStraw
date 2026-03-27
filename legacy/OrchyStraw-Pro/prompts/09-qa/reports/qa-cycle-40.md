# QA Cycle 40 Report
**Date:** 2026-03-21
**Agent:** 09-QA
**Focus:** issue-tracker.sh review (675 lines) + regression suite
**Commit under review:** 1c3f5d2

---

## Test Results

| Suite | Result | Detail |
|-------|--------|--------|
| test-issue-tracker.sh | **45/45 PASS** | All 9 groups pass |
| Syntax check (`bash -n`) | **PASS** | No errors |
| Full regression (`run-tests.sh`) | **40/41 — 1 FAIL** | test-integration.sh fails (see QA-F008) |

---

## Code Review: issue-tracker.sh

### Input Validation — PASS
- ID: numeric-only regex (`^[0-9]+$`) — correct
- Title: max 200 chars, blocks shell metacharacters (`` ` $ | ; & < > ``), blocks `$(` and `..` — correct
- Priority: `^P[0-4]$` regex whitelist — correct
- Assignee: `^[a-zA-Z0-9_-]+$` regex whitelist — correct
- Labels: `^[a-zA-Z0-9_,:-]+$` regex whitelist — correct
- Status: hardcoded `open`/`closed` check — correct
- Path traversal: `..` check on title, assignee, labels — correct

### Security Patterns — MOSTLY PASS
- Double-source guard: present (line 23) — PASS
- mktemp for temp files: used in close, assign, update — PASS
- No eval: confirmed — PASS
- No jq: confirmed — PASS
- grep patterns use validated numeric IDs only — no regex injection — PASS
- **FINDING: QA-F007** — see below

### CRUD Operations
- Create: writes validated JSONL, auto-increment ID — PASS
- List: awk-based parsing with validated filter values — PASS
- Show: sed field extraction, handles missing issues — PASS
- Close: updates status + closed_at via awk + mktemp — PASS
- Assign: updates assignee via awk + mktemp — PASS
- Update: see QA-F007 below

### Edge Cases
- Empty title/priority rejected — PASS
- Non-existent issue ID returns error — PASS
- Auto-increment after deletions — PASS (uses max ID + 1)

---

## New Findings

### QA-F007 (MEDIUM): Shell execution in orch_issue_update via awk `cmd | getline`

**Found in:** `src/core/issue-tracker.sh:581-591`
**Severity:** MEDIUM

**Problem:** `orch_issue_update` constructs a shell command inside awk:
```awk
cmd = "echo '\''" $0 "'\'' | sed '\''" scmd "'\''"
cmd | getline result
```
This embeds the entire JSONL line (`$0`) into a single-quoted `echo` command. If the JSONL data contains a single quote (e.g., a title like `Fix O'Brien's handler`), the single-quote escaping breaks, causing:
1. Incorrect field updates (silent data corruption)
2. Potential command execution if combined with other characters

**Why this matters:** The title validator (line 54) blocks `` ` $ | ; & < > `` but does **not** block single quotes (`'`). A title with an apostrophe passes `orch_issue_create` validation but breaks `orch_issue_update`.

**Fix options:**
1. Add `'` to the forbidden characters in `_orch_issue_validate_title` (simplest, minor UX cost)
2. Rewrite `orch_issue_update` to use pure awk `gsub()` like `orch_issue_close` and `orch_issue_assign` already do (correct fix, consistent with other functions)

**Assigned to:** 06-Backend

---

### QA-F008 (LOW): Integration test module count stale

**Found in:** `tests/core/test-integration.sh`
**Severity:** LOW

**Problem:** `test-integration.sh` expects 39 modules but `src/core/` now has 40 (issue-tracker.sh added). This causes 1 assertion failure:
```
FAIL: 39 modules in src/core/ (expected "39", got "40")
```
The test's expected count needs updating to 40, and the integration test needs to source and verify issue-tracker.sh's public API functions.

**Assigned to:** 06-Backend

---

### orch_issue_sync — Noted (no new finding)

The sync function (lines 606-675) has unquoted `$label_flags` and `$repo_flag`, but this is intentional for argument expansion. The `--repo` parameter lacks validation, but since it's a developer-facing internal function (not user input), this is acceptable. No finding filed.

---

## Verdict: CONDITIONAL PASS

**issue-tracker.sh** is well-structured with strong input validation that matches the SEC-HIGH patterns established in prior cycles. The JSONL approach is clean and the test coverage is thorough (45 assertions across 9 groups).

**Conditions:**
1. **QA-F007** must be fixed before issue-tracker.sh is used in production orchestration (MEDIUM — silent data corruption risk with apostrophes in titles)
2. **QA-F008** integration test count must be updated to 40

**No blockers for merge.** Both findings are non-critical and can be fixed in the next backend cycle.

---

## Regression Summary

- 40/41 test files pass (only integration count stale — QA-F008)
- issue-tracker.sh: 45/45 pass
- No new regressions in existing modules
