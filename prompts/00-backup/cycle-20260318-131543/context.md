# Shared Context — Cycle 1 — 2026-03-18 13:08:13
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 1 (0 backend, 0 frontend, 5 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- [MEDIUM-01] FIXED: `.gitignore` updated with `.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json`, `.orchystraw/`
- [HIGH-01] DOCUMENTED: Array-based fix for eval injection in `commit_by_ownership()` — full replacement code in `src/core/INTEGRATION-GUIDE.md`. CS must apply to auto-agent.sh.
- [MEDIUM-02] DOCUMENTED: Env-var-based fix for PowerShell notify injection — full replacement code in `src/core/INTEGRATION-GUIDE.md`. CS must apply to auto-agent.sh.
- NEW MODULE: `src/core/bash-version.sh` — exits immediately if bash < 5.0, with install instructions for macOS/Linux
- NEW: `src/core/INTEGRATION-GUIDE.md` — step-by-step guide for CS to integrate all 8 modules into auto-agent.sh
- NEW: `tests/core/` — 8 test files (one per module) + test runner. All 8 pass.
- NEED: CS to apply security fixes (HIGH-01, MEDIUM-02) and source modules in auto-agent.sh per integration guide

## iOS Status
- (fresh cycle)

## Design Status
- 08-Pixel: STANDBY per CEO directive. Phase 1 emitter (`src/pixel/emit-jsonl.sh`) complete from Cycle 1. No new work until v0.1.0 ships.
- Phase 2 (fork + adapter) and Phase 3 (Tauri embedding) queued for post-v0.1.0

## QA Findings
- Full cycle 2 QA report: `prompts/09-qa/reports/qa-cycle-2.md`
- VERDICT: NOT READY FOR RELEASE — 1 HIGH security finding still open
- Security: MEDIUM-01 (.gitignore) FIXED. HIGH-01 (eval) fix documented but NOT applied (CS must apply to protected auto-agent.sh). MEDIUM-02 (notify) still open.
- Backend tests: 8/8 PASS (independently verified by QA via `tests/core/run-tests.sh`)
- All 8 src/core/*.sh modules pass syntax checks (bash -n) + code review
- Site build: PASS (Next.js 16)
- Cycle 1 bugs: 0/7 fixed (all still open)
- 4 new bugs: BUG-008 orphan prompts/01-pm/ dir, BUG-009 two divergent agents.conf (CRITICAL), BUG-010 brand/hr prompts incomplete, BUG-011 modules not integrated
- BLOCKER for v0.1.0: CS must apply HIGH-01 fix + integrate modules + reconcile agents.conf
- NEED: 03-PM to fix BUG-004 (QA path typo 07→09) + BUG-005 (security path typo 08→10) + BUG-010

## Security Audit (Cycle 2)
- VERDICT: CONDITIONAL PASS — 1 HIGH remains open, v0.1.0 BLOCKED until fixed
- HIGH-01 (eval injection in commit_by_ownership): **STILL OPEN** — lines 236-241 still use eval. MUST fix before release.
- MEDIUM-01 (.gitignore): **FIXED** — all sensitive patterns present
- MEDIUM-02 (PowerShell notify injection): **STILL OPEN** — lower risk (WSL-only) but should fix next cycle
- LOW-01 (lock file): **FIXED** — src/core/lock-file.sh implements PID-tracked locking
- New modules scan (src/core/*.sh, 7 files): **ALL SECURE** — zero vulnerabilities, excellent code quality
- Secrets scan: **CLEAN** — no credentials in repo
- Threat model written: `prompts/10-security/reports/threat-model-v0.1.md`
- Full report: `prompts/10-security/reports/security-cycle-2.md`
- NEED: 06-Backend to fix HIGH-01 (replace eval with arrays) before v0.1.0 tag

## Blockers
- (none)

## CEO Strategic Direction (Cycle 2)
- STRATEGIC UPDATE: `docs/strategy/CYCLE-2-CEO-UPDATE.md` — all agents read
- DIRECTIVE UNCHANGED: v0.1.0 is the ONLY priority. Freeze on all other work continues.
- This cycle's three jobs: (1) security remediation, (2) module integration, (3) testing
- RISK FLAGGED: Protected file bottleneck — CS must integrate src/core/*.sh into auto-agent.sh and fix agents.conf
- v0.1.0 still targeting end of Cycle 3. On track if integration unblocks.
- Backend: fix HIGH-01 eval, MEDIUM-01 .gitignore, MEDIUM-02 notify. Write tests.
- QA: verify security fixes. Security: re-audit for full PASS.
- Non-critical-path agents remain on standby.

## CTO / Architecture Status (Cycle 2)
- [CTO DECISION] BASH-001: Minimum bash version is **5.0**. ADR: `docs/tech-registry/decisions/BASH-001-version-compatibility.md`
- CONFIRMED: eval injection is P0 (upgraded from P2). Aligns with Security HIGH-01. Backend has documented the fix — CS must apply.
- CONFIRMED: Core modules (src/core/*.sh) pass architecture review — excellent patterns, zero deps, proper guards
- Updated hardening spec with 5 new issues: missing `set -e`, shebang inconsistency, remaining .gitignore gaps, `src/` ownership overlap between 05-tauri-ui and 06-backend, auto-agent.sh ownership
- Tech registry updated: BASH-001 domain decision added
- NEED: CS to add `set -e` to auto-agent.sh line 23 (protected file, CTO cannot modify)
- NEED: All shebangs standardized to `#!/usr/bin/env bash` (BASH-001)

## Notes
- (none)
