# QA Report — Cycle 1 (v0.2.0 Sprint)
**Date:** 2026-03-20
**QA Engineer:** 09-qa (Claude Opus 4.6)
**Verdict:** PASS — v0.1.0 tagged, no regressions, project advancing

---

## What Changed Since Last QA (Cycle 30)

Two commits landed since cycle 30:
1. `1ffa281` — Fixed all agent prompts to point to OrchyStraw-Pro repo
2. `65e78f5` — v0.2.0 sprint context + repo fixes

**v0.1.0 tag now EXISTS.** This was the primary blocker for 22+ cycles. Confirmed: `git tag -l v*` returns `v0.1.0`.

---

## Test Results

| Suite | Result |
|-------|--------|
| Unit tests (run-tests.sh) | 11/11 PASS |
| Integration tests | 42/42 PASS (included in run-tests.sh) |
| Site build (Next.js) | PASS (static export, 4 pages) |
| Tauri (Rust) | N/A — src-tauri/ not scaffolded yet |

**No regressions.**

---

## Open Issues — Status Update

### BUG-013 — agents.conf ownership paths (P1, CS)
**Status:** STILL OPEN
- `09-qa` ownership: `tests/ reports/` → should be `tests/ prompts/09-qa/reports/`
- `10-security` ownership: `reports/` → should be `prompts/10-security/reports/`
- **Impact:** Downgraded to P1 (was P0). v0.1.0 is tagged. This is now a v0.1.1 fix.
- **Assigned to:** CS (human) — ~2 min fix

### BUG-012 — PROTECTED FILES section missing from prompts (P2, v0.1.1)
**Status:** PROGRESS — 6/9 prompts now have it (was 4/9 at cycle 30)
- **Have it (6):** 02-cto, 06-backend, 08-pixel, 09-qa, 11-web, 13-hr
- **Missing (3):** 01-ceo, 03-pm, 10-security
- **Assigned to:** v0.1.1

### #73 — check-usage.sh threshold bug (v0.1.0 label, backend)
**Status:** OPEN — 70% threshold didn't prevent hitting 98%
- Filed as GitHub issue. Should be relabeled to v0.1.1 or v0.2.0.

---

## README Audit

README.md: 80 lines, proper project README (not boilerplate). Minor issues persist:
- Says "10 AI agents" but agents.conf has 9 active entries
- Lists `agents.conf — 11-agent configuration` but only 9 are configured
- Lists `src-tauri/`, `ios/` in structure but neither exists yet
- **Verdict:** Cosmetic only. Not blocking.

---

## agents.conf Audit

9 agents configured. Format consistent. Parsing OK.
- PM (03) interval=0 (runs last) OK
- Core workers (06, 11) interval=1 OK
- BUG-013 ownership paths still wrong for 09-qa and 10-security

---

## Uncommitted Changes

4 files modified but not committed:
- `docs/team/TEAM_ROSTER.md`
- `prompts/00-shared-context/context-cycle-0.md`
- `prompts/00-shared-context/context.md`
- `prompts/13-hr/team-health.md`

These appear to be v0.2.0 sprint context updates. No concern.

---

## GitHub Issues

50+ open issues. No new bugs filed this cycle. Issue #73 (check-usage.sh) is labeled v0.1.0 but should be relabeled since v0.1.0 is tagged.

---

## v0.1.1 Queue (updated)

1. **BUG-013:** agents.conf ownership paths — CS must fix
2. **BUG-012:** 3 prompts still missing PROTECTED FILES (01-ceo, 03-pm, 10-security)
3. **LOW-02:** Unquoted `$all_owned` line 358 in auto-agent.sh
4. **QA-F001:** `set -e` missing from auto-agent.sh line 23
5. **#73:** check-usage.sh threshold — relabel to v0.1.1

---

## Summary

v0.1.0 is tagged. 22-cycle blocker resolved. All tests pass (11/11 unit, 42/42 integration, site build PASS). No regressions. BUG-012 improved (6/9 prompts now have PROTECTED FILES, up from 4/9). BUG-013 still open but downgraded since v0.1.0 shipped.

**Recommendation:** Ship v0.1.1 with BUG-013 + BUG-012 fixes, then proceed with v0.2.0 sprint (Tauri scaffold, landing page deploy, Pixel Agents). No QA blockers for v0.2.0 development to begin.
