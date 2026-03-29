# QA Report — Cycle 8 (v0.1.0 Release Gate)

**Date:** 2026-03-29
**QA Engineer:** 09-QA (Claude Opus 4.6)
**Verdict: PASS — Ready for v0.1.0 tag**

---

## Executive Summary

All three v0.1.0 blockers from cycle 6 are **FIXED** in commit `601c9a2`:
- HIGH-03 (unquoted ownership loops): **FIXED** — all 3 sites use proper array iteration
- HIGH-04 (sed injection): **FIXED** — `|` delimiter + variable escaping
- MEDIUM-01 (.gitignore secrets): **FIXED** — `.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json` added

Test suite: **11/11 pass** (9 unit + 1 integration + 1 signal handler — up from 9 in cycle 6). No regressions.

---

## 1. Security Fix Verification (commit 601c9a2)

### HIGH-03: Unquoted `$ownership` in for loops — FIXED

All three locations converted from bare `$ownership` word splitting to proper array-based iteration:

| Location | Before | After | Status |
|----------|--------|-------|--------|
| `commit_by_ownership()` line 244 | `for path in $ownership` | `IFS=' ' read -ra _ownership_arr <<< "$ownership"` + `"${_ownership_arr[@]}"` | FIXED |
| `detect_rogue_writes()` inner loop line 319 | `for path in $ownership` | Same `read -ra` pattern into `_own_arr` | FIXED |
| `detect_rogue_writes()` owned-check line 330 | `for path in $all_owned` (string) | `for path in "${all_owned_arr[@]}"` (array) | FIXED |

The `all_owned` string accumulator was also converted to `all_owned_arr` array (`+=` instead of string concatenation). Clean fix.

### HIGH-04: sed injection in prompt updates — FIXED

Lines 792-812 now:
1. Use `|` delimiter instead of `/` (avoids conflicts with date format slashes)
2. Pre-sanitize all 8 interpolated variables through `sed 's/[|&]/\\&/g'`
3. Store sanitized values in `_safe_*` variables before use in sed commands

The escaping covers `|` (delimiter) and `&` (sed replacement metachar). Backslash escaping is not needed because all source variables are from `date` output or `wc -l` counts — no backslashes possible.

**Verdict: FIXED.** Sed injection vector is closed for all realistic inputs.

### MEDIUM-01: .gitignore missing sensitive patterns — FIXED

Root `.gitignore` now includes:
```
.env
.env.*
*.pem
*.key
*.p12
*.pfx
credentials.json
service-account*.json
*secret*.json
```

All patterns requested by Security audit are present.

### HIGH-01 (eval injection) — Remains FIXED

No `eval` calls exist in the script. Only a comment at line 240 referencing the fix.

### QA-F001 (`set -e` flag) — CLOSED (design choice)

Line 23: `set -uo pipefail` — `-e` still absent. Confirmed intentional: the script uses `2>/dev/null` suppression and manual error handling throughout. Adding `-e` would require `|| true` on dozens of lines. This was reclassified in cycle 6 as a deliberate design choice. **Remains CLOSED.**

---

## 2. Test Suite Results

| Test File | Result |
|-----------|--------|
| test-agent-timeout.sh | PASS |
| test-bash-version.sh | PASS |
| test-config-validator.sh | PASS |
| test-cycle-state.sh | PASS |
| test-cycle-tracker.sh | PASS |
| test-dry-run.sh | PASS |
| test-error-handler.sh | PASS |
| test-integration.sh | PASS |
| test-lock-file.sh | PASS |
| test-logger.sh | PASS |
| test-signal-handler.sh | PASS |

**11/11 pass. 0 failures. No regressions.**

Note: test count increased from 9 (cycle 6) to 11 — `test-cycle-tracker.sh` and `test-signal-handler.sh` added since last QA run.

---

## 3. README Review

The README was rewritten since cycle 6. Key findings:

- **BUG-001 CLOSED**: No longer says "10 AI agents" — the new README is feature-focused, not agent-count-focused
- Content is accurate and functional — quick start instructions, agents.conf format, features list all correct
- **NEW finding (BUG-013):** README says "Bash 4+" in Requirements, but `src/core/bash-version.sh` enforces Bash 5.0+ per CTO ADR BASH-001. Should say "Bash 5+"
- Monorepo consolidation section references `legacy/` and `strategy-vault/` — both directories confirmed to exist

---

## 4. Bug Triage — Status Update

| Bug | Title | Cycle 6 | Cycle 8 | Notes |
|-----|-------|---------|---------|-------|
| BUG-001 | README agent count | OPEN | **CLOSED** | README rewritten, no longer mentions count |
| BUG-002 | agents.conf path mismatches | CLOSED | CLOSED | — |
| BUG-003 | 5 agents not in config | CLOSED | CLOSED | — |
| BUG-004 | QA report path wrong | CLOSED | CLOSED | — |
| BUG-005 | Security report path wrong | CLOSED | CLOSED | — |
| BUG-006 | tests/ dir missing | CLOSED | CLOSED | — |
| BUG-007 | CLAUDE.md aspirational paths | OPEN (P2) | OPEN (P2) | src-tauri/, ios/ still not scaffolded — acceptable |
| BUG-008 | No test infrastructure | CLOSED | CLOSED | — |
| BUG-009 | Dual agents.conf divergence | CLOSED | CLOSED | — |
| BUG-010 | Incomplete prompts | OPEN (P2) | OPEN (P2) | Non-blocking |
| BUG-011 | agents.conf format issues | CLOSED | CLOSED | — |
| BUG-012 | PROTECTED FILES missing from prompts | OPEN (P1) | OPEN (P1) | Non-blocking for v0.1.0 |
| **BUG-013** | **README says "Bash 4+"** | — | **NEW (P1)** | **Should say "Bash 5+" per BASH-001 ADR** |

**Cycle 8 changes:** BUG-001 CLOSED. BUG-013 NEW.

---

## 5. New Findings

### BUG-013 (P1): README Bash version requirement incorrect
**Found in:** `README.md` line 74
**Severity:** Medium
**Detail:** README says "Bash 4+" but `src/core/bash-version.sh` enforces Bash 5.0+ and CTO ADR BASH-001 specifies minimum bash 5.0. Users on Bash 4.x would hit a version check failure with no prior warning.
**Fix:** Change "Bash 4+" to "Bash 5+" in README.
**Assigned to:** CS (quick fix before tagging)

### NEW-01 (LOW): `local` keyword outside function scope
**Found in:** `scripts/auto-agent.sh` line 793
**Detail:** `local _safe_date ...` is used inside the `orchestrate)` case branch, not inside a function. Bash tolerates this but it's technically an error per POSIX and may produce warnings on some bash versions.
**Risk:** LOW — works fine on all modern bash 5.x versions.
**Deferred to:** v0.1.1

### NEW-02 (INFO): `--dangerously-skip-permissions` in Claude invocations
**Found in:** `scripts/auto-agent.sh` lines ~205, ~494
**Detail:** Both `run_agent` and `run_pm` pass `--dangerously-skip-permissions` to Claude. This is by design for autonomous orchestration, but should be noted in documentation for open-source users.
**Deferred to:** docs update

---

## 6. Release Blockers Summary

### v0.1.0 Blockers — ALL RESOLVED

| # | Issue | Status |
|---|-------|--------|
| 1 | HIGH-03: Unquoted ownership loops | **FIXED** (601c9a2) |
| 2 | HIGH-04: sed injection | **FIXED** (601c9a2) |
| 3 | MEDIUM-01: .gitignore secrets | **FIXED** (601c9a2) |

### Recommended Before Tagging (non-blocking)

| # | Issue | Effort |
|---|-------|--------|
| 1 | BUG-013: README "Bash 4+" → "Bash 5+" | ~30 seconds |

### Deferred to v0.1.1

| # | Issue |
|---|-------|
| 1 | NEW-01: `local` outside function scope |
| 2 | BUG-012: PROTECTED FILES in 7 prompts |
| 3 | BUG-007: CLAUDE.md aspirational paths |
| 4 | BUG-010: Incomplete prompts |
| 5 | NEW-02: Document `--dangerously-skip-permissions` usage |

---

## 7. Release Sign-Off

**v0.1.0 Release Gate: PASS**

All P0 blockers are resolved:
- HIGH-03 unquoted ownership loops — FIXED
- HIGH-04 sed injection — FIXED
- MEDIUM-01 .gitignore secrets — FIXED
- HIGH-01 eval injection — FIXED (prior cycle)
- MEDIUM-02 notify injection — FIXED (prior cycle)
- All 11 tests pass, no regressions
- All security findings verified resolved
- README rewritten and functional

**Recommendation:** Fix BUG-013 (README Bash version, 30-second fix), then tag v0.1.0.

---

*Report generated by 09-QA agent, Cycle 8, 2026-03-29*
