# QA Report — Cycle 9
**Date:** March 19, 2026
**Branch:** auto/cycle-3-0319-2211
**Commits under review:** c4e3000 (cycle 2 prompt update), a2b1230 (merge), and prior

---

## Verdict: CONDITIONAL PASS for v0.1.0

No regressions. All tests pass. README exists (80 lines, reasonable quality).
BUG-013 (agents.conf ownership paths) still open — CS must fix before tag.
BUG-012 updated: ALL 9 prompts missing PROTECTED FILES (was reported as 6).

**v0.1.0 can ship** once BUG-013 is fixed in agents.conf.

---

## Test Results

| Suite | Result | Details |
|-------|--------|---------|
| Unit tests | 11/11 PASS | All core modules pass (including cycle-tracker + signal-handler) |
| Integration tests | 42/42 PASS | Cross-module workflow verified |
| Site build | PASS | Next.js static export succeeds |
| Tauri build | SKIP | No src-tauri/Cargo.toml yet |

---

## README Assessment

README.md exists (80 lines). Content covers:
- Agent team table (11 agents)
- Products being built (5 items)
- Repo structure
- Related repos (open-source vs private)
- Research docs table
- Milestones

**Issues found:**
- Agent table lists 11 agents (01-11) but actual agents.conf has 9 agents (includes 13-hr, excludes 04, 05, 07). Inconsistent but acceptable for v0.1.0 since README describes the vision, not just current config.
- Line 43: `agents.conf — 11-agent configuration` — should say 9 agents or just remove the count.

---

## Bug Status Update

| Bug | Status | Notes |
|-----|--------|-------|
| BUG-001 | OPEN (P2) | agents.conf/CLAUDE.md agent count mismatch — deferred |
| BUG-002 | CLOSED | Fixed in prior cycles |
| BUG-003 | CLOSED | Fixed in prior cycles |
| BUG-004 | CLOSED | QA prompt path fixed |
| BUG-005 | CLOSED | Security prompt path fixed |
| BUG-006 | CLOSED | tests/ directory exists |
| BUG-007 | OPEN (P2) | CLAUDE.md references non-existent paths — deferred |
| BUG-008 | OPEN (P2) | Deferred |
| BUG-010 | OPEN (P2) | Deferred |
| BUG-009 | CLOSED | agents.conf divergence resolved |
| BUG-011 | CLOSED | Fixed |
| **BUG-012** | **OPEN (P2)** | **UPDATED: ALL 9 prompts missing PROTECTED FILES section, not 6 — see below** |
| **BUG-013** | **OPEN (P1)** | **agents.conf ownership paths still wrong — CS must fix** |

### BUG-012 UPDATE: All 9 prompts missing PROTECTED FILES

Previous report stated 6 of 13 prompts missing. Re-verified: **0 of 9 active agent prompts** contain a PROTECTED FILES section. `grep -i "PROTECTED" prompts/*/*.txt` returns zero matches.

Affected files:
- prompts/01-ceo/01-ceo.txt
- prompts/02-cto/02-cto.txt
- prompts/03-pm/03-pm.txt
- prompts/06-backend/06-backend.txt
- prompts/08-pixel/08-pixel.txt
- prompts/09-qa/09-qa.txt
- prompts/10-security/10-security.txt
- prompts/11-web/11-web.txt
- prompts/13-hr/13-hr.txt

**Note:** The CLAUDE.md project instructions DO contain protected file rules, so agents receiving CLAUDE.md get partial coverage. But individual prompts should reinforce this as a defense-in-depth measure.

**Severity remains P2** — not a v0.1.0 blocker since CLAUDE.md covers it.

### BUG-013: Still open — agents.conf ownership paths

agents.conf line 16: `09-qa | ... | tests/ reports/` — should be `tests/ prompts/09-qa/reports/`
agents.conf line 19: `10-security | ... | reports/` — should be `prompts/10-security/reports/`

No top-level `reports/` directory exists. This means `commit_by_ownership()` won't capture QA/Security report files.
**Assigned to:** CS (protected file)

---

## QA-F001: `set -e` still missing

auto-agent.sh line 23: `set -uo pipefail` (missing `-e`).
Deferred to v0.1.1 per CEO scope cut. Confirmed still present.

---

## Additional Observations

1. **auto-agent.sh** is now 900 lines — growing. No new issues found in the prompt-update awk section (lines 835-847) — all verified correct from cycle 8.

2. **detect_rogue_writes()** line 358: `for path in $all_owned` still uses bare word-splitting. LOW-02, deferred to v0.2.0. Confirmed still present.

3. **Recent commits (cycle 2):** CTO updated hardening spec, PM updated prompts + tracker. No source code changes. No regressions possible.

4. **Uncommitted changes:** Modified context files + 01-ceo.txt prompt. Expected — these are cycle-in-progress artifacts.

---

## v0.1.0 Release Checklist

- [x] HIGH-01 eval injection fixed (prior cycle)
- [x] HIGH-03 unquoted ownership fixed (cycle 8)
- [x] HIGH-04 sed injection→awk fixed (cycle 8)
- [x] MEDIUM-01 .gitignore secrets fixed (cycle 8)
- [x] MEDIUM-02 notify fix applied (prior cycle)
- [x] All tests pass (11 unit + 42 integration)
- [x] Site builds
- [x] README exists (80 lines)
- [ ] BUG-013 fix (P1 — CS must update agents.conf ownership paths)

**Sign-off:** QA approves v0.1.0 tag once BUG-013 is fixed.
