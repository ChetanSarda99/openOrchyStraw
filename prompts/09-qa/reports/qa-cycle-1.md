# QA Report — Cycle 1
**Date:** 2026-03-18
**Agent:** 09-QA
**Scope:** Full checklist pass — orchestrator, docs, prompts, builds

---

## Summary

First QA cycle. Project is in early stage — mostly prompts, docs, and the orchestrator script exist. No application code (no Tauri, no React, no iOS, no site/). No tests exist yet. Found **7 bugs** (2 critical, 3 high, 2 medium).

---

## Checklist Results

### Orchestrator Script (`scripts/auto-agent.sh`)
- [x] `agents.conf` parsing handles edge cases (blank lines, comments, spaces)
- [x] Cycle count increments correctly
- [x] Agent spawn order matches config
- [x] PM runs last (cycle_interval=0)
- [x] Shared context is reset between cycles
- [x] Backup of previous context is saved
- [x] Error in one agent doesn't crash entire cycle
- [x] SIGINT cleanup works (no orphan processes)
- [x] Protected file enforcement (two-pass rogue detector)

### Documentation
- [x] README structure is coherent
- [ ] **BUG-001:** README says "10 AI agents" but agents.conf has 8 entries
- [ ] **BUG-002:** README agent table lists 04-Tauri-Rust, 05-Tauri-UI, 07-iOS — none are in agents.conf
- [x] All linked research docs exist
- [x] agents.conf format matches what the script expects

### Tauri App
- [ ] N/A — `src-tauri/` does not exist yet (no Cargo.toml, no Rust source)
- [ ] N/A — No React app (`package.json` missing, `src/` is empty of app code)
- Cannot run `cargo check` or `npm run build`

### Pixel Agents
- [ ] N/A — `src/pixel/` and `pixel-agents/` do not exist yet

### Prompts
- [x] All 11 agent prompts have git safety rules
- [x] All prompts reference correct repo URL
- [ ] **BUG-003:** Ownership mismatches between agents.conf and prompt files (see bugs below)
- [ ] **BUG-004:** 3 agents have prompts but are missing from agents.conf entirely
- [ ] **BUG-005:** QA prompt says `prompts/07-qa/reports/` (wrong agent number — should be 09)
- [ ] **BUG-006:** Security prompt says `prompts/08-security/reports/` (wrong agent number — should be 10)

### Tests
- [ ] **BUG-007:** No `tests/` directory exists. Zero test files in the project.

---

## Bugs Filed

### BUG-001: README agent count mismatch (Medium)
**Found in:** README.md
**Severity:** medium
**Problem:** README says "10 AI agents coordinate" but agents.conf only registers 8 agents. Agents 04-tauri-rust, 05-tauri-ui, 07-ios are listed in README but not in agents.conf (intentionally deferred per current priorities).
**Fix:** Update README to say "8 active agents" or add a note that 04/05/07 are planned but not yet active.
**Assigned to:** 03-pm

### BUG-002: 5 agents have prompts but are missing from agents.conf (Critical)
**Found in:** agents.conf vs prompts/
**Severity:** critical
**Problem:** These agents have fully written prompts but will NEVER run because they're not in agents.conf:
- 04-tauri-rust (has `prompts/04-tauri-rust/04-tauri-rust.txt`)
- 05-tauri-ui (has `prompts/05-tauri-ui/05-tauri-ui.txt`)
- 07-ios (has `prompts/07-ios/07-ios.txt`)
- 12-brand (has prompt)
- 13-hr (has prompt)
**Expected:** Either add them to agents.conf with appropriate intervals, or document them as "planned/deferred" in README.
**Assigned to:** 06-backend (agents.conf is protected — human action item)

### BUG-003: Ownership mismatches between agents.conf and prompts (High)
**Found in:** agents.conf vs individual prompt files
**Severity:** high
**Details:**
| Agent | agents.conf says | Prompt says | Mismatch |
|-------|-----------------|-------------|----------|
| 01-ceo | `docs/strategy/` | `prompts/01-ceo/` + `docs/strategy/` | Missing `prompts/01-ceo/` in conf |
| 02-cto | `docs/architecture/` | `prompts/02-cto/` + `docs/architecture/` | Missing `prompts/02-cto/` in conf |
| 06-backend | `scripts/ src/core/ src/lib/ benchmarks/` | `src/api/ src/core/ src/lib/ scripts/ prisma/` | Missing `src/api/`, `prisma/` in conf; extra `benchmarks/` |
| 09-qa | `tests/ reports/` | `tests/` + `prompts/07-qa/reports/` | Wrong agent number (07 vs 09) |
| 10-security | `reports/` | `prompts/08-security/reports/` | Wrong agent number (08 vs 10) |
**Fix:** Sync agents.conf and prompts to match. Fix the wrong agent numbers in QA and Security prompts.
**Assigned to:** 06-backend (conf) + 03-pm (prompts)

### BUG-004: QA prompt references wrong directory path (High)
**Found in:** prompts/09-qa/09-qa.txt
**Severity:** high
**Problem:** QA prompt says it owns `prompts/07-qa/reports/` — the "07" is wrong. QA is agent 09, not 07. Should be `prompts/09-qa/reports/`.
**Assigned to:** 03-pm

### BUG-005: Security prompt references wrong directory path (High)
**Found in:** prompts/10-security/10-security.txt
**Severity:** high
**Problem:** Security prompt says it owns `prompts/08-security/reports/` — the "08" is wrong. Security is agent 10, not 08. Should be `prompts/10-security/reports/`.
**Assigned to:** 03-pm

### BUG-006: No test files exist (Medium)
**Found in:** tests/
**Severity:** medium
**Problem:** The `tests/` directory doesn't exist. QA agent owns it but there's nothing to run. No unit tests, no integration tests, no script tests.
**Expected:** At minimum, a basic test for agents.conf parsing and orchestrator dry-run.
**Assigned to:** 09-qa (test creation) + 06-backend (testable interfaces)

### BUG-007: CLAUDE.md agent list out of date (Critical)
**Found in:** CLAUDE.md
**Severity:** critical
**Problem:** CLAUDE.md lists 11 agents (including 04, 05, 07) and references file paths (`src-tauri/`, `ios/`, `site/`) that don't exist yet. agents.conf only has 8 active agents. The agent team section and file structure are aspirational, not current.
**Expected:** CLAUDE.md should reflect current state OR clearly mark planned items as "(planned)".
**Assigned to:** 03-pm (CLAUDE.md is protected — human action item)

---

## Script Quality Notes (auto-agent.sh)

The orchestrator is well-structured. Observations:
1. **Protected file enforcement** works correctly (two-pass: restore protected first, then check rogue writes)
2. **Config parsing** handles comments, blank lines, and whitespace trimming properly
3. **SIGINT trap** kills child PIDs and cleans up
4. **Backup rotation** (7-day) prevents disk bloat
5. **Prompt validation** restores from backup if a prompt drops below 50 lines
6. **Usage-based pause** with dynamic threshold is a good safety valve
7. **eval usage** on lines 236-237, 241 — works for the ownership patterns but is a potential injection vector if agents.conf ever contains untrusted input. Low risk since conf is human-only.

---

## Anti-Pattern Check
Reviewed `docs/anti-patterns.md` — 5 patterns documented, all still valid. No new anti-patterns to add this cycle.

---

## Recommendations for Next Cycle
1. **Human action:** Fix agents.conf ownership mismatches (BUG-003) — this file is protected
2. **Human action:** Update CLAUDE.md to reflect 8 active agents, mark 04/05/07 as planned
3. **PM:** Fix wrong agent numbers in QA and Security prompts (BUG-004, BUG-005)
4. **Backend:** Create a basic `tests/test-config-parser.sh` to validate agents.conf parsing
5. **All:** No builds to validate yet — Tauri/React/iOS scaffolding hasn't started
