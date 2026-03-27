# OrchyStraw — Team Roster

> Last updated: 2026-03-21 (v0.2.0 Sprint, Session 9 Cycle 1 — HR Agent — Engine feature-complete, interval P0 escalation)

## Active Agents (in agents.conf)

| ID | Role | Ownership | Interval | Status | Sprint Total | Current Load |
|----|------|-----------|----------|--------|-------------|--------------|
| 01-ceo | CEO — Vision & Strategy | `docs/strategy/` | Every 3rd cycle | IDLE | Feature Freeze issued | Monitoring. Dry-run data available. |
| 02-cto | CTO — Architecture & Standards | `docs/architecture/` | Every 2nd cycle | IDLE — **P0: interval=3** | ALL modules reviewed PASS | Review migrate.sh. **24th report recommending interval=3** |
| 03-pm | PM — Coordination & Tasks | `prompts/` `docs/` | Coordinator (runs LAST) | ACTIVE | Cycle coordination | Coordination — medium |
| 06-backend | Backend Developer | `scripts/` `src/core/` `src/lib/` `benchmarks/` | Every cycle | **9th consecutive productive cycle** | 40 modules, engine feature-complete | QA-F007/F008 P0 + #79 P1 |
| 08-pixel | Pixel Agents Visualization | `src/pixel/` `pixel-agents/` | Every 2nd cycle | ACTIVE | Phase 5 animation | Medium |
| 09-qa | QA Engineer | `tests/` `reports/` | Every 3rd cycle | ACTIVE | QA-F007/F008 found | Review migrate.sh + dry-run benchmarks |
| 10-security | Security Auditor | `reports/` | Every 5th cycle | ACTIVE | 100% coverage (31/31 + new scripts queued) | Audit migrate.sh + issue-tracker.sh |
| 11-web | Web Developer — Landing & Docs | `site/` | Every cycle — **P0: interval=3** | **UNBLOCKED** | 25 pages shipped | Phase 17 benchmarks + Phase 18 compare. **24th report recommending interval=3** |
| 13-hr | HR & Team Culture | `docs/team/` `prompts/13-hr/` | Every 3rd cycle | ACTIVE | 19 health reports | Health monitoring — light |

**Total active: 9 agents. Engine FEATURE-COMPLETE. Interval changes P0 — 24th report, still not applied.**

## Interval Change Recommendations (Pending CS Approval — P0)

| Agent | Current | Proposed | Reason | Reports Recommending | Estimated Wasted Runs |
|-------|---------|----------|--------|---------------------|----------------------|
| 11-web | 1 | **3** | 25 pages done, deploy blocked, was STANDBY for months | **24** | ~16 |
| 02-cto | 2 | **3** | Review-only role, all modules reviewed PASS | **24** | ~8 |

## Inactive / Not in agents.conf

| Directory | Likely Role | Status | Notes |
|-----------|-------------|--------|-------|
| `prompts/01-pm/` | Old PM location | **ARCHIVE** | PM moved to 03-pm. 19 HR reports recommending archive. |
| `prompts/04-tauri-rust/` | Tauri Rust Backend | Not deployed | Listed in CLAUDE.md but not in agents.conf. P2 — defer. |
| `prompts/05-tauri-ui/` | Tauri UI Frontend | Not deployed | Listed in CLAUDE.md but not in agents.conf. P2 — defer. |
| `prompts/07-ios/` | iOS Companion App | Not deployed | Listed in CLAUDE.md but not in agents.conf. P3. |
| `prompts/12-brand/` | Brand/Design | **ARCHIVE** | Not in CLAUDE.md agent list. 19 HR reports, zero CEO response. |

## Ownership Overlap Analysis

### Confirmed Overlaps

1. **`reports/`** — Owned by BOTH `09-qa` and `10-security`
   - Risk: MEDIUM — both write QA/security reports here
   - Mitigation: Each writes to their own subdirectory (`prompts/09-qa/reports/`, `prompts/10-security/reports/`), so actual conflict is low. But the `agents.conf` ownership string is ambiguous.

2. **`docs/`** — PM owns `prompts/` and `docs/` broadly; CTO owns `docs/architecture/`; CEO owns `docs/strategy/`; HR owns `docs/team/`
   - Risk: LOW — subdirectory ownership is clear, PM's broad ownership acts as fallback

3. **`prompts/`** — PM owns all of `prompts/`, HR owns `prompts/13-hr/`
   - Risk: LOW — HR only writes to own subdirectory, PM updates all agent task sections
