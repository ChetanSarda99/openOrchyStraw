# QA Report — Cycle 8
**Date:** March 19, 2026
**Branch:** auto/cycle-1-0319-2152
**Commit under review:** 23895de (fix: HIGH-03, HIGH-04, MEDIUM-01)

---

## Verdict: CONDITIONAL PASS for v0.1.0

All three targeted fixes (HIGH-03, HIGH-04, MEDIUM-01) are verified correct.
11/11 unit tests pass. 42/42 integration assertions pass. Site build passes.
One new bug found (BUG-013). BUG-012 still open but downgraded — not a v0.1.0 blocker.

**v0.1.0 can ship** once README is updated (per CEO scope).

---

## Fix Verification

### HIGH-03: Unquoted $ownership in for loops — FIXED
- `commit_by_ownership()` (line 268): Converted to safe `while IFS= read -r` + `tr ' ' '\n'` pattern
- `detect_rogue_writes()` (line 347): Same safe pattern applied
- No remaining bare `for path in $ownership` loops
- **Minor note:** `for path in $all_owned` at line 358 uses bare word-splitting on an internally-built string. Low risk (not user input), but stylistically inconsistent. P3, defer to v0.2.0.

### HIGH-04: sed injection → awk — FIXED
- All 5 sed commands in prompt-update section (lines 835-847) replaced with safe `awk -v` + `gsub` pattern
- Uses `${pf}.tmp && mv` (atomic write) — no in-place mutation
- Only remaining `sed` is in `notify()` (line 75) for XML entity escaping — hardcoded patterns, safe
- **Verdict: PASS**

### MEDIUM-01: .gitignore missing secrets patterns — FIXED
- `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx` all present in root `.gitignore`
- **Verdict: PASS**

---

## Test Results

| Suite | Result | Details |
|-------|--------|---------|
| Unit tests | 11/11 PASS | All core modules pass |
| Integration tests | 42/42 PASS | Cross-module workflow verified |
| Site build | PASS | Next.js static export succeeds |
| Tauri build | SKIP | No src-tauri/Cargo.toml in Pro repo yet |

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
| BUG-009 | CLOSED | agents.conf divergence resolved |
| BUG-010 | OPEN (P2) | Deferred |
| BUG-011 | CLOSED | Fixed |
| BUG-012 | OPEN (P2) | 6 prompts missing PROTECTED FILES section — downgraded, not v0.1.0 blocker |
| **BUG-013** | **NEW (P1)** | **agents.conf ownership mismatch for QA/Security reports — see below** |

### BUG-013: agents.conf ownership paths don't match actual report directories

**Found in:** agents.conf lines 17, 20
**Severity:** high (P1) — affects commit_by_ownership correctness
**Details:**
- 09-qa ownership: `tests/ reports/` — but QA writes to `prompts/09-qa/reports/`, not `reports/`
- 10-security ownership: `reports/` — but Security writes to `prompts/10-security/reports/`, not `reports/`
- No top-level `reports/` directory exists
- Result: `commit_by_ownership()` won't capture QA/Security report files in their commits
**Fix:** Update agents.conf ownership:
- 09-qa: `tests/ prompts/09-qa/reports/`
- 10-security: `prompts/10-security/reports/`
**Assigned to:** CS (protected file)

---

## Additional Observations

1. **Model router** (new in this commit): `run_with_model()` function added — routes agents to claude/codex/gemini per agents.conf `model` column. Not tested in isolation but code structure is clean.

2. **agents.conf format** now has 6 columns (added `model`). Parser updated to match. Consistent.

3. **QA-F001** (`set -uo pipefail` missing `-e`): Still open from cycle 4. Deferred to v0.1.1 per CEO scope cut. Confirmed still present at line 6 of auto-agent.sh.

---

## v0.1.0 Release Checklist

- [x] HIGH-03 fixed and verified
- [x] HIGH-04 fixed and verified (bonus — was deferred but CS fixed it anyway)
- [x] MEDIUM-01 fixed and verified
- [x] All tests pass (11 unit + 42 integration)
- [x] Site builds
- [ ] README rewrite (CS TODO — last item before tag)
- [ ] BUG-013 fix (P1 — should ship with v0.1.0 if possible)

**Sign-off:** QA approves v0.1.0 tag once README is updated and BUG-013 is addressed.
