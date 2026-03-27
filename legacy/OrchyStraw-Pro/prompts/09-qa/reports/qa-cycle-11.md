# QA Report — Cycle 11 (v0.2.0)
**Date:** March 20, 2026
**Branch:** auto/cycle-9-0320-0730
**Commits under review:** ac55d09..HEAD (cycle 8 merge + cycle 9 prompt updates)

---

## Verdict: CONDITIONAL PASS

No regressions. All tests pass. 6 new modules from cycles 7-8 reviewed.
One new finding: **QA-F003** — unquoted CLI variable in single-agent.sh (shell injection risk).

---

## Test Results

| Suite | Result | Details |
|-------|--------|---------|
| Unit tests | 32/32 PASS | All core modules pass (up from 11 in cycle 10) |
| Integration tests | 42/42 PASS | Cross-module workflow verified |
| Site build | PASS | Next.js static export succeeds (dynamic font warning — cosmetic) |
| Tauri build | SKIP | No src-tauri/Cargo.toml yet |

---

## Changes Since Last QA Cycle

Major new work since cycle 10:
- **6 new src/core/ modules:** file-access.sh, agent-as-tool.sh, model-budget.sh, vcs-adapter.sh, single-agent.sh, review-phase.sh
- **6 new test files:** All passing (test-file-access, test-agent-as-tool, test-model-budget, test-vcs-adapter, test-single-agent, test-review-phase)
- **Pixel demo:** demo.html + demo-embed.js (canvas-based animation)
- **Site updates:** Changelog page, social proof component, OG/Twitter images, sitemap
- **Integration guide:** Steps 25-27 added for new modules
- **CTO:** All 24+ modules reviewed PASS, hardening doc updated

---

## Code Review — 3 New Cycle 8 Modules

### vcs-adapter.sh — PASS
- Double-source guard ✅, no eval ✅, proper naming ✅
- Clean backend abstraction (git/svn/none)
- Minor: sed complexity in SVN path extraction, temp file naming could collide under rapid calls
- **No blocking issues**

### single-agent.sh — CONDITIONAL PASS
- Double-source guard ✅, no eval ✅, proper naming ✅
- **QA-F003 (P1):** Line 349 — `$cli` is unquoted in command execution: `$cli "$prompt_content"`. If CLI path contains spaces or metacharacters, shell injection is possible. Must be `"$cli"`.
- Minor: Line 345 — file read after existence check has TOCTOU gap (low risk)

### review-phase.sh — PASS
- Double-source guard ✅, no eval ✅, proper naming ✅
- Minor: Verdict parsing (lines 380-386) uses sequential greps — fragile pattern matching
- Minor: `patch -p0` at line 328 lacks error handling
- **No blocking issues**

---

## Pixel Demo Review — PASS

- **XSS:** SECURE — no innerHTML, document.write, or eval. All rendering via Canvas API (immune to XSS)
- **Input handling:** All data is static/hardcoded, no external sources
- **Code quality:** Clean architecture, proper cleanup functions, requestAnimationFrame loop
- **CSP:** No explicit CSP meta tag (acceptable for standalone file, recommended for landing page embed)
- **No blocking issues**

---

## Integration Guide Review — Steps 25-27

- Step 25 (vcs-adapter.sh): Source instruction correct, usage examples present ✅
- Step 26 (single-agent.sh): Source instruction correct, usage examples present ✅
- Step 27 (review-phase.sh): No new source needed (already in Step 18), documents 4 new functions ✅
- **No issues found**

---

## Bug Status Update

| Bug | Status | Notes |
|-----|--------|-------|
| BUG-001 | OPEN (P2) | agents.conf/CLAUDE.md agent count mismatch — deferred |
| BUG-007 | OPEN (P2) | CLAUDE.md references non-existent paths — deferred |
| BUG-012 | OPEN (P1) | 5/9 prompts have PROTECTED FILES. Missing: 01-ceo, 03-pm, 10-security, 11-web |
| BUG-013 | VERIFIED FIXED | agents.conf ownership paths for QA/Security include reports/ |
| QA-F001 | OPEN (P2) | `set -e` missing from auto-agent.sh line 23 |
| QA-F002 | OPEN (P2) | `set -euo pipefail` missing from 9+ v0.2.0 modules |
| **QA-F003** | **NEW (P1)** | **single-agent.sh:349 — unquoted `$cli` variable, shell injection risk** |

---

## New Finding

### QA-F003: Unquoted CLI variable in single-agent.sh
**Found in:** src/core/single-agent.sh, line 349
**Severity:** P1 (HIGH)
**Problem:** `$cli "$prompt_content"` executes unquoted — if model-router returns a CLI path with spaces or metacharacters, shell word splitting allows command injection.
**Expected:** `"$cli" "$prompt_content"`
**Assigned to:** 06-Backend

---

## PROTECTED FILES Status (BUG-012 Update)

| Prompt | Has Section? |
|--------|-------------|
| 01-ceo | ❌ MISSING |
| 02-cto | ✅ |
| 03-pm | ❌ MISSING |
| 06-backend | ✅ |
| 08-pixel | ✅ |
| 09-qa | ✅ |
| 10-security | ❌ MISSING |
| 11-web | ❌ MISSING |
| 13-hr | ✅ |

**Update:** Recount shows 5/9 (not 6/9 as cycle 11 old report claimed). 11-web does NOT have the section — was incorrectly counted previously.

---

## Summary

- **32/32 unit tests PASS** — significant growth from 11 tests in cycle 10
- **Site build PASS** — changelog, OG images, sitemap all generating correctly
- **6 new modules reviewed** — all structurally sound, one P1 finding (QA-F003)
- **Pixel demo SECURE** — canvas-only rendering, no XSS vectors
- **BUG-013 CLOSED** — agents.conf ownership verified correct
- **QA-F003 NEW** — must fix before v0.2.0 ships
