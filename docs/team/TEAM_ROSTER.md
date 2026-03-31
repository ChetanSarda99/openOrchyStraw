# OrchyStraw — Team Roster

> Last updated: 2026-03-30 (Cycle 1 Session 4, HR Agent)

## Active Agents (in agents.conf)

| ID | Role | Ownership | Interval | Status |
|----|------|-----------|----------|--------|
| 01-ceo | CEO — Vision & Strategy | `docs/strategy/` | Every 3rd cycle | Active |
| 02-cto | CTO — Architecture & Standards | `docs/architecture/` | Every 2nd cycle | **7 reviews pending** — backlog critical |
| 03-pm | PM — Coordination & Tasks | `prompts/` `docs/` | Coordinator (runs LAST) | Active |
| 06-backend | Backend Developer | `scripts/` `src/core/` `src/lib/` `benchmarks/` | Every cycle | Active — 13 modules, 23 test files, 21st productive cycle |
| 08-pixel | Pixel Agents Visualization | `src/pixel/` `pixel-agents/` | Every 2nd cycle | STANDBY — per CEO |
| 09-qa | QA Engineer | `tests/` `reports/` | Every 3rd cycle | Active — review queue growing |
| 10-security | Security Auditor | `reports/` | Every 5th cycle | Interval 5, scheduled |
| 11-web | Web Developer — Landing & Docs | `site/` | Every cycle | Active — site stable |
| 13-hr | HR & Team Culture | `docs/team/` `prompts/13-hr/` | Every 3rd cycle | Active (C1) |

**Total active: 9 agents**

## Inactive / Not in agents.conf

| Directory | Likely Role | Status | Notes |
|-----------|-------------|--------|-------|
| `prompts/01-pm/` | Old PM location | Orphaned | PM moved to 03-pm. Safe to archive. |
| `prompts/04-tauri-rust/` | Tauri Rust Backend | Planned | Activate after benchmark sprint (Phase 2) |
| `prompts/05-tauri-ui/` | Tauri UI Frontend | Planned | Activate after benchmark sprint (Phase 2) |
| `prompts/07-ios/` | iOS Companion App | Planned | Activate after Tauri scaffold stable (Phase 3) |
| `prompts/12-brand/` | Brand/Design | **RECOMMEND ARCHIVE** | CEO silent 20+ cycles. Deadline passed (C16). |

## Ownership Overlap Analysis

### Confirmed Overlaps

1. **`reports/`** — Owned by BOTH `09-qa` and `10-security`
   - Risk: MEDIUM — both write QA/security reports here
   - Mitigation: Each writes to their own subdirectory (`prompts/09-qa/reports/`, `prompts/10-security/reports/`), so actual conflict is low. But the `agents.conf` ownership string is ambiguous.

2. **`docs/`** — PM owns `prompts/` and `docs/` broadly; CTO owns `docs/architecture/`; CEO owns `docs/strategy/`; HR owns `docs/team/`
   - Risk: LOW — subdirectory ownership is clear, PM's broad ownership acts as fallback

3. **`prompts/`** — PM owns all of `prompts/`, HR owns `prompts/13-hr/`
   - Risk: LOW — HR only writes to own subdirectory, PM is coordinator by design

### No Overlaps (Clean)
- `scripts/`, `src/core/`, `src/lib/` — Backend only
- `site/` — Web only
- `src/pixel/` — Pixel only
