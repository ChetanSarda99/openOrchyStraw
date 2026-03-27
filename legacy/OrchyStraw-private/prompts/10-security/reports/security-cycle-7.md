# Security Audit — Cycle 7 (Session Cycle 13)
**Date:** 2026-03-18
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** Full re-audit — secrets scan, ownership boundaries, script review, new code review, release gate

---

## Verdict: NO CHANGE — v0.1.0 STILL BLOCKED (or tag AS-IS per Option B)

No source code changes since cycle 6 audit. All three blockers remain unfixed.
Zero new vulnerabilities introduced. Zero regressions.

---

## Finding Status

| ID | Finding | Severity | Status | Line(s) |
|----|---------|----------|--------|---------|
| HIGH-01 | `eval` injection in `commit_by_ownership()` | HIGH | **FIXED** (d130de7) | — |
| HIGH-02 | `--dangerously-skip-permissions` | HIGH | **ACCEPTED RISK** | 198, 488 |
| HIGH-03 | Unquoted `$ownership` in for loops | HIGH | **OPEN** | 236, 310, 320 |
| HIGH-04 | Sed injection via unescaped variables | HIGH | **OPEN — deferred to v0.1.1** | 785–791 |
| MEDIUM-01 | `.gitignore` missing sensitive patterns | MEDIUM | **OPEN (regression)** | — |
| MEDIUM-02 | PowerShell notify injection | MEDIUM | **FIXED** (d130de7) | — |
| LOW-01 | No lock file mechanism | LOW | **FIXED** | — |
| LOW-02 | Missing `set -e` | LOW | **ACCEPTED** | — |

---

## Detailed Review

### HIGH-03: Unquoted Variable Expansion — STILL OPEN

**File:** `scripts/auto-agent.sh` — Lines 236, 310, 320

No changes since cycle 6. All three instances remain unquoted:

```bash
for path in $ownership; do      # Line 236 — commit_by_ownership()
for path in $ownership; do      # Line 310 — detect_rogue_writes()
for path in $all_owned; do      # Line 320 — detect_rogue_writes()
```

**Risk:** Glob expansion + word splitting on paths from agents.conf. Low exploitability in practice (agents.conf values are controlled), but unsafe pattern.

**Required fix:** Array-based iteration:
```bash
IFS=' ' read -ra ownership_arr <<< "$ownership"
for path in "${ownership_arr[@]}"; do
```

**Assigned to:** CS (protected file)

---

### HIGH-04: Sed Injection — STILL OPEN (deferred to v0.1.1 per CEO)

**File:** `scripts/auto-agent.sh` — Lines 785–791

No changes. Sed commands use `/` delimiter with unescaped variables.

**Risk assessment update:** Variables involved (`date`, numeric counts) come from controlled sources (stat, wc, find). Actual exploitation requires attacker control over file counts or date format — very unlikely in practice. **Deferral to v0.1.1 is reasonable.**

**Assigned to:** CS (protected file, v0.1.1)

---

### MEDIUM-01: .gitignore — STILL INCOMPLETE

Root `.gitignore` unchanged:
```
.DS_Store, Thumbs.db, logs/, *.log, prompts/00-backup/*.md, .orchystraw.lock, node_modules/
```

**Missing:** `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json`, `.orchystraw/`

**Mitigating factor:** No secret files exist in repo. `site/.gitignore` covers `.env*` and `*.pem` for the Next.js project.

**Assigned to:** CS

---

## New Observations — Cycle 7

### 1. No Source Code Changes
Git log shows only prompt/tracker updates since last security audit (commits `5b17005` through `d0b7cb2`). No new attack surface.

### 2. New Untracked Files
- `src/core/cycle-tracker.sh` — Smart empty cycle detection. **Reviewed: SAFE.** Pure bash, no external calls, proper quoting.
- `src/core/signal-handler.sh` — Graceful shutdown (SIGTERM→SIGKILL). **Reviewed: SAFE.** Proper signal handling, no injection vectors.
- `src/core/SMART-CYCLE-DESIGN.md` — v0.2.0 design doc. Documentation only.
- `tests/core/test-cycle-tracker.sh` — Test file. No security concerns.
- `tests/core/test-signal-handler.sh` — Test file. No security concerns.

### 3. BUG-009 (Dual agents.conf) — STILL PRESENT
Both `agents.conf` (root) and `scripts/agents.conf` exist and are identical. Script reads `scripts/agents.conf` only. Root file is dead code — should be deleted to avoid future divergence.

### 4. Agent Boundary Compliance
No agent has written outside its declared ownership in recent commits. Protected file enforcement (two-pass detection in auto-agent.sh) remains intact.

---

## Secrets Scan

**Result: CLEAN**

- Scanned all `.txt`, `.md`, `.sh`, `.conf`, `.ts`, `.tsx`, `.json` files
- All matches are documentation references or design token mentions
- No `.env`, `.pem`, `.key`, `.p12`, `.pfx` files exist in the repo
- No credentials, API keys, or real secrets found

---

## Supply Chain Check

- Core orchestrator: zero external dependencies (pure bash)
- `site/` (Next.js): all packages are well-known public npm packages — no changes since last audit
- No `curl|bash` patterns anywhere
- No new dependencies added

---

## Release Gate Assessment

### Option A (Fix then tag):
| Requirement | Status |
|-------------|--------|
| No eval on untrusted input | **PASS** |
| No command injection in notify | **PASS** |
| Unquoted variable loops fixed | **FAIL** — HIGH-03 open |
| Sed injection fixed | **DEFERRED** — v0.1.1 (CEO approved) |
| No secrets in repo | **PASS** |
| .gitignore covers sensitive patterns | **FAIL** — MEDIUM-01 open |
| Core modules secure | **PASS** |
| Lock file mechanism | **PASS** |
| Threat model documented | **PASS** |

**If CS fixes HIGH-03 + MEDIUM-01:** Security gives **FULL PASS** for v0.1.0 (HIGH-04 → v0.1.1).

### Option B (Tag AS-IS):
**Security position:** Acceptable with documented known issues. Rationale:
- HIGH-03 is low exploitability (agents.conf values are human-controlled)
- HIGH-04 is deferred per CEO, not RCE
- MEDIUM-01 is preventive (no secrets exist)
- All actual RCE vectors (HIGH-01, MEDIUM-02) are FIXED

**If Option B: include these in release notes:**
```
## Known Security Issues (v0.1.0)
- HIGH-03: Unquoted variable expansion in for loops (lines 236, 310, 320) — fix in v0.1.1
- HIGH-04: Sed injection in prompt updates (lines 785-791) — fix in v0.1.1
- MEDIUM-01: Root .gitignore missing sensitive file patterns — fix in v0.1.1
```

---

## Summary

13 cycles. No source code changes since audit cycle 6. Same 3 findings remain.
Security is not blocking the decision — CS should choose Option A or B and ship.

**Next security audit:** After v0.1.0 ships (verify tag) or after v0.1.1 fixes land.
