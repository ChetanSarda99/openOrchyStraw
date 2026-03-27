# QA Report — Cycle 5 (v0.1.0 Release Gate)
**Date:** 2026-03-18
**Agent:** 09-QA
**Scope:** Verify HIGH-03, HIGH-04, MEDIUM-01 from Security cycle 5; full regression; bug triage; release sign-off

---

## Executive Summary

**Verdict: NOT READY — All 3 security blockers from cycle 5 remain OPEN**

No fixes have been applied to `auto-agent.sh` since commit `0025b1d` (stray `local` removal). HIGH-03 (unquoted variable loops), HIGH-04 (sed injection), and MEDIUM-01 (.gitignore regression) are all still present exactly as Security cycle 5 reported them.

**No regressions** — 9/9 tests pass, site build passes, syntax check passes. The codebase is stable but unfixed.

---

## 1. Security Blocker Verification

### HIGH-03: Unquoted Variable Expansion in For Loops — STILL OPEN

**Lines 236, 310, 320** of `scripts/auto-agent.sh`:
```bash
# Line 236 — commit_by_ownership()
for path in $ownership; do    # UNQUOTED — glob expansion risk

# Line 310 — detect_rogue_writes()
for path in $ownership; do    # UNQUOTED

# Line 320 — detect_rogue_writes()
for path in $all_owned; do    # UNQUOTED
```

**Status:** All three locations still use unquoted expansion. Note: `commit_by_ownership()` (line 236) does feed into arrays for the final pathspec (HIGH-01 eval fix), but the initial for loop itself is still subject to glob expansion. `detect_rogue_writes()` lines 310/320 have no array protection at all.

**Practical risk:** LOW — current agents.conf paths (`scripts/`, `src/core/`, `site/`, etc.) contain no glob characters. But any path containing `*`, `?`, or `[` would silently expand.

CS must apply `IFS=' ' read -ra` array-based iteration fix.

### HIGH-04: Sed Injection in Prompt Updates — STILL OPEN

**Lines 785-791** of `scripts/auto-agent.sh`:
```bash
sed -i "s/\*\*Date:\*\* .*/\*\*Date:\*\* ... — ${current_time}/" "$pf"
sed -i "s/[0-9]* TypeScript source.../${backend_src} TypeScript..." "$pf"
sed -i "s/Total:.*source files/Total: $total source files/" "$pf"
```

**Status:** Still uses `/` delimiter with unescaped variables. No change since Security cycle 5.

### MEDIUM-01: .gitignore Missing Sensitive Patterns — STILL OPEN

Current root `.gitignore` (complete contents):
```
.DS_Store
Thumbs.db
logs/
*.log
prompts/00-backup/*.md
.orchystraw.lock
node_modules/
```

**Missing:** `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json`

**Mitigating factor:** No sensitive files currently exist in the repo. Risk is future accidental commits.

---

## 2. Test Suite Results

### Unit Tests (run-tests.sh)

| Test | Result |
|------|--------|
| test-agent-timeout.sh | PASS |
| test-bash-version.sh | PASS |
| test-config-validator.sh | PASS |
| test-cycle-state.sh | PASS |
| test-dry-run.sh | PASS |
| test-error-handler.sh | PASS |
| test-integration.sh | PASS |
| test-lock-file.sh | PASS |
| test-logger.sh | PASS |

**9/9 pass. No regressions.**

### Other Checks

| Check | Result |
|-------|--------|
| `bash -n scripts/auto-agent.sh` | PASS — syntax valid |
| `site/` Next.js build | PASS — static export, 4 pages |
| agents.conf (root vs scripts/) | IDENTICAL — no divergence |

---

## 3. Bug Tracker (Updated)

| Bug | Severity | Cycle 4 Status | Cycle 5 Status | Notes |
|-----|----------|----------------|----------------|-------|
| BUG-001 | Medium | OPEN | **OPEN** | README says "10 AI agents" — agents.conf has 9 active, CLAUDE.md says 11 |
| BUG-002 | Critical | CLOSED | CLOSED | agents.conf reconciled |
| BUG-003 | High | CLOSED | CLOSED | Root/scripts agents.conf identical |
| BUG-004 | High | CLOSED | CLOSED | QA prompt paths fixed |
| BUG-005 | High | CLOSED | CLOSED | Security prompt paths fixed |
| BUG-006 | Low | CLOSED | CLOSED | tests/ exists |
| BUG-007 | Medium | OPEN | **OPEN** | CLAUDE.md lists aspirational paths (src-tauri/, ios/, etc.) |
| BUG-008 | Medium | OPEN | **OPEN** | Orphaned `prompts/01-pm/logs/` directory |
| BUG-009 | Critical | CLOSED | CLOSED | agents.conf reconciled |
| BUG-010 | High | OPEN | **DOWNGRADED→Medium** | 12-brand not in agents.conf — only matters if re-added |
| BUG-011 | High | CLOSED | CLOSED | All 8 modules integrated |
| BUG-012 | High | OPEN | **OPEN (improved)** | 3/9 active agents missing PROTECTED FILES section |
| QA-F001 | Medium | NEW | **OPEN** | `set -uo pipefail` missing `-e` flag |

### BUG-012 Detail — PROTECTED FILES Section

Of 9 active agents in agents.conf:

| Agent | Has PROTECTED FILES? |
|-------|---------------------|
| 01-ceo | NO |
| 02-cto | YES |
| 03-pm | NO |
| 06-backend | YES |
| 08-pixel | YES |
| 09-qa | YES |
| 10-security | NO |
| 11-web | YES |
| 13-hr | YES |

**6/9 have it. Missing: 01-ceo, 03-pm, 10-security.** Improved from cycle 4 (was 5/9).

---

## 4. New Findings

### QA-F002: README Agent Count Mismatch (Expansion of BUG-001)

**File:** `README.md`, line 4
**Severity:** Medium

README intro says "10 AI agents" but:
- agents.conf has **9 active** agents
- README table lists **11** agents (01-11)
- CLAUDE.md says **11 agents** but lists 04-Tauri, 05-Tauri-UI, 07-iOS which are not in agents.conf
- agents.conf includes 13-hr which is NOT in the README table

All three numbers (9, 10, 11) are different. Need a single source of truth.

**Assigned to:** CS / PM

---

## 5. Release Blockers Summary (v0.1.0)

### P0 — Must Fix (blocks release)
1. **HIGH-03:** Unquoted `$ownership` in for loops (auto-agent.sh lines 236, 310, 320) — **CS**
2. **HIGH-04:** Sed injection in prompt updates (auto-agent.sh lines 785-791) — **CS**

### P1 — Should Fix Before Release
3. **MEDIUM-01:** Root `.gitignore` missing sensitive patterns — **CS**
4. **QA-F001:** Add `-e` flag to `set -uo pipefail` (or document why omitted) — **CS**
5. **BUG-001/QA-F002:** README agent count mismatch — **CS/PM**
6. **BUG-012:** Add PROTECTED FILES to 01-ceo, 03-pm, 10-security prompts — **PM**

### P2 — Can Ship Without
7. **BUG-007:** CLAUDE.md aspirational paths
8. **BUG-008:** Orphaned prompts/01-pm/logs/
9. **BUG-010:** 12-brand prompt missing standard blocks (inactive agent)

---

## 6. Release Sign-Off

**v0.1.0 Release Gate: NOT READY**

All 3 security blockers from cycle 5 remain unfixed. The orchestrator is functionally stable (all tests pass, no regressions) but the ownership enforcement system has known integrity issues (HIGH-03, HIGH-04) and the .gitignore is incomplete (MEDIUM-01).

**Required before tagging v0.1.0:**
1. CS fixes HIGH-03 + HIGH-04 in `auto-agent.sh`
2. CS fixes MEDIUM-01 in root `.gitignore`
3. QA re-verifies all 3 fixes
4. Security final sign-off

**Timeline:** These are all straightforward fixes — likely completable in one CS session + one QA/Security verification cycle.

---

*Report generated by 09-QA agent, Cycle 5, 2026-03-18*
