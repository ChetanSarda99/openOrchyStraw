# OrchyStraw — Team Roster

> Last updated: 2026-03-18 (Cycle 1, HR Agent)

## Active Agents (in agents.conf)

| ID | Role | Ownership | Interval | Status |
|----|------|-----------|----------|--------|
| 01-ceo | CEO — Vision & Strategy | `docs/strategy/` | Every 3rd cycle | Active |
| 02-cto | CTO — Architecture & Standards | `docs/architecture/` | Every 2nd cycle | Active |
| 03-pm | PM — Coordination & Tasks | `prompts/` `docs/` | Coordinator (runs LAST) | Active |
| 06-backend | Backend Developer | `scripts/` `src/core/` `src/lib/` `benchmarks/` | Every cycle | Active — BLOCKED on CS |
| 08-pixel | Pixel Agents Visualization | `src/pixel/` `pixel-agents/` | Every 2nd cycle | STANDBY |
| 09-qa | QA Engineer | `tests/` `reports/` | Every 3rd cycle | Active |
| 10-security | Security Auditor | `reports/` | Every 5th cycle | Active (read-only) |
| 11-web | Web Developer — Landing & Docs | `site/` | Every cycle | STANDBY |
| 13-hr | HR & Team Culture | `docs/team/` `prompts/13-hr/` | Every 3rd cycle | Active (new) |

**Total active: 9 agents**

## Inactive / Not in agents.conf

These prompt directories exist but have NO entry in `agents.conf`:

| Directory | Likely Role | Status | Notes |
|-----------|-------------|--------|-------|
| `prompts/01-pm/` | Old PM location | Orphaned | PM moved to 03-pm. Safe to archive. |
| `prompts/04-tauri-rust/` | Tauri Rust Backend | Not deployed | Listed in CLAUDE.md but not in agents.conf |
| `prompts/05-tauri-ui/` | Tauri UI Frontend | Not deployed | Listed in CLAUDE.md but not in agents.conf |
| `prompts/07-ios/` | iOS Companion App | Not deployed | Listed in CLAUDE.md but not in agents.conf |
| `prompts/12-brand/` | Brand/Design | Not deployed | Not in CLAUDE.md agent list either |

## Ownership Overlap Analysis

### Confirmed Overlaps

1. **`reports/`** — Owned by BOTH `09-qa` and `10-security`
   - Risk: MEDIUM — both write QA/security reports here
   - Mitigation: Each writes to their own subdirectory (`prompts/09-qa/reports/`, `prompts/10-security/reports/`), so actual conflict is low. But the `agents.conf` ownership string is ambiguous.

2. **`docs/`** — PM owns `prompts/` and `docs/` broadly; CTO owns `docs/architecture/`; CEO owns `docs/strategy/`; HR owns `docs/team/`
   - Risk: LOW — subdirectory ownership is clear, PM's broad ownership acts as fallback
   - Recommendation: PM ownership should be `prompts/ docs/` with explicit exclusions for CTO/CEO/HR subdirs if the orchestrator supports it

3. **`prompts/`** — PM owns all of `prompts/`, HR owns `prompts/13-hr/`
   - Risk: LOW — HR only writes to own subdirectory, PM updates all agent task sections
   - This is by design (PM is coordinator)

### No Overlaps (Clean)
- `scripts/`, `src/core/`, `src/lib/` — Backend only
- `site/` — Web only
- `src/pixel/` — Pixel only
