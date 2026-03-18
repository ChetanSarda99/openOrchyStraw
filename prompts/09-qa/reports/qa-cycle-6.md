# QA Report — Cycle 6

**Date:** 2026-03-18
**QA Engineer:** 09-QA (Claude Opus 4.6)
**Verdict:** NOT READY — 1 HIGH open, 1 MEDIUM open, v0.1.0 still blocked

---

## Test Results

| Suite | Result | Details |
|-------|--------|---------|
| Unit tests (9) | ✅ PASS | All 9 pass, 0 failures |
| Integration tests (42) | ✅ PASS | 42/42 assertions pass |
| Site build (Next.js) | ✅ PASS | 4/4 pages, 0 TS errors, 0 vulnerabilities |
| Tauri (cargo check) | ⏭️ SKIPPED | src-tauri/ not scaffolded yet |

---

## Security Finding Verification

### HIGH-03: Unquoted `$ownership` in for loops
**Status: PARTIALLY FIXED**

- `commit_by_ownership()` (line 236): **FIXED** — Now uses array-based iteration with `local -a include_args=()` and proper `"${pathspec[@]}"` expansion.
- `detect_rogue_writes()` (lines 310, 320): **STILL OPEN** — Both loops use unquoted string expansion (`for path in $ownership` and `for path in $all_owned`). Paths with spaces or special characters would split incorrectly.
- **Risk:** LOW in practice (config paths don't have spaces), but inconsistent with the fix applied to `commit_by_ownership()`.
- **Recommendation:** Convert to array-based iteration for consistency. Downgrade to P2.

### HIGH-04: sed injection in prompt updates (lines 785-791)
**Status: STILL OPEN — BLOCKER**

All 5 sed commands use `/` delimiter with unescaped variables (`${current_time}`, `${backend_src}`, `${test_count}`, `${ts_count}`, `${swift_count}`, `${component_count}`, `${total}`). Characters `/`, `\`, and `&` in any variable would corrupt or inject into sed.

- **Fix required:** Use `|` delimiter + escape special chars in replacement strings.
- **Assigned to:** CS (protected file)

### MEDIUM-01: .gitignore missing sensitive patterns
**Status: STILL OPEN — BLOCKER**

Root `.gitignore` only covers: `.DS_Store`, `Thumbs.db`, `logs/`, `*.log`, backup, lock, `node_modules/`.

Missing patterns:
- `.env` / `.env.*`
- `*.pem`
- `*.key`
- `*.p12`
- `credentials.json` / `*.secret`

**Assigned to:** CS (root config file)

### QA-F001: `set -uo pipefail` missing `-e`
**Status: ACCEPTABLE (reclassified)**

Line 23 has `set -uo pipefail` without `-e`. Reviewed the script — multiple lines intentionally suppress errors (`kill "$pid" 2>/dev/null`, `git checkout -b ... 2>/dev/null`). Adding `-e` would require `|| true` throughout. This is a deliberate design choice, not a bug. **CLOSED.**

---

## Bug Triage — Status Update

| Bug | Title | Status | Notes |
|-----|-------|--------|-------|
| BUG-001 | README says "10 AI agents" | OPEN (P1) | Still inaccurate — agents.conf has 9, CLAUDE.md says 11 |
| BUG-002 | agents.conf path mismatches | CLOSED (cycle 4) | Fixed in d130de7 |
| BUG-003 | 5 agents in prompts not in config | CLOSED (cycle 4) | Fixed in d130de7 |
| BUG-004 | QA report path wrong in prompt | CLOSED (cycle 4) | Fixed by PM |
| BUG-005 | Security report path wrong | CLOSED (cycle 4) | Fixed by PM |
| BUG-006 | tests/ dir missing | CLOSED (cycle 3) | Exists with 10 files |
| BUG-007 | CLAUDE.md lists paths that don't exist | OPEN (P2) | src-tauri/, ios/ not scaffolded — acceptable pre-v0.1.0 |
| BUG-008 | No test infrastructure | CLOSED | 9 unit + 1 integration test exist |
| BUG-009 | Dual agents.conf divergence | CLOSED (cycle 4) | Fixed in d130de7 |
| BUG-010 | Incomplete 12-brand/13-hr prompts | OPEN (P2) | 12-brand removed, 13-hr exists and functional |
| BUG-011 | agents.conf format issues | CLOSED (cycle 4) | Fixed in d130de7 |
| BUG-012 | PROTECTED FILES missing from prompts | OPEN (P1) | 7 of 11 prompts still missing — see below |

---

## BUG-012 Detail: PROTECTED FILES Audit

**4 of 11 prompts have the section:**
- 06-backend ✓
- 08-pixel ✓
- 09-qa ✓
- 11-web ✓

**7 of 11 prompts MISSING:**
- 01-ceo ✗
- 02-cto ✗
- 03-pm ✗
- 04-tauri-rust ✗
- 05-tauri-ui ✗
- 07-ios ✗
- 10-security ✗

**Assigned to:** 03-PM (prompt updates)

---

## Prompt Quality Checks

| Check | Status |
|-------|--------|
| Repo URL correct (all 11) | ✅ PASS |
| Git safety rules (all 11) | ✅ PASS |
| No ownership overlaps | ✅ PASS |
| agents.conf matches prompts | ✅ PASS (9 active agents) |

---

## agents.conf vs CLAUDE.md Discrepancy

- **agents.conf:** 9 agents (01-ceo, 02-cto, 03-pm, 06-backend, 08-pixel, 09-qa, 10-security, 11-web, 13-hr)
- **CLAUDE.md:** Lists 11 agents (includes 04-tauri-rust, 05-tauri-ui, 07-ios)
- **Status:** Acceptable — Tauri and iOS agents not yet active. CLAUDE.md describes the full planned team.

---

## Anti-Patterns Registry

`docs/anti-patterns.md` exists with 6 entries (AP-001 through AP-006). No new anti-patterns to add this cycle.

---

## Release Blockers for v0.1.0

| # | Issue | Severity | Owner | Status |
|---|-------|----------|-------|--------|
| 1 | HIGH-04: sed injection in prompt updates | HIGH | CS | OPEN |
| 2 | MEDIUM-01: .gitignore missing secrets patterns | MEDIUM | CS | OPEN |

### Downgraded / Non-Blocking

| # | Issue | Severity | Notes |
|---|-------|----------|-------|
| 3 | HIGH-03 remainder (rogue_writes loops) | P2 | Low practical risk, fix post-v0.1.0 |
| 4 | BUG-012: PROTECTED FILES in 7 prompts | P1 | Important but doesn't block release |
| 5 | BUG-001: README agent count | P1 | Quick fix, do before tagging |
| 6 | QA-F001: set -e flag | CLOSED | Design choice, not a bug |

---

## Verdict

**NOT READY for v0.1.0 tag.**

HIGH-04 (sed injection) remains a real vulnerability in `auto-agent.sh`. MEDIUM-01 (.gitignore) is a security hygiene issue that must be fixed before any public release.

**Path to release:**
1. CS fixes HIGH-04 (sed escaping, lines 785-791)
2. CS fixes MEDIUM-01 (.gitignore patterns)
3. CS fixes BUG-001 (README agent count)
4. QA re-runs verification → FULL PASS
5. Security final sign-off → tag v0.1.0
