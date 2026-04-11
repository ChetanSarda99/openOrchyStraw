# OrchyStraw — Team Roster

> Last updated: 2026-04-10 (Cycle 1, v0.5.0 era, HR Agent)
> Source of truth: `agents.conf`. This document is a human-readable mirror.

## Active Agents (12 in agents.conf)

| ID | Role | Ownership | Interval | Status |
|----|------|-----------|---------:|--------|
| 00-cofounder | Co-Founder Operations | `agents.conf` `docs/operations/` | 2 | Active — autonomous ops, runs BEFORE PM |
| 01-ceo | CEO — Vision & Strategy | `docs/strategy/` | 3 | Active |
| 02-cto | CTO — Architecture & Standards | `docs/architecture/` | 2 | Active (no longer blocked — old CTO queue dissolved with v0.2.0 ship) |
| 03-pm | PM — Coordination & Tasks | `prompts/` `docs/` | 0 (last) | Active — coordinator, runs LAST |
| 06-backend | Backend Developer | `scripts/` `src/core/` `src/lib/` `benchmarks/` | 1 | Sustained MVP — v0.5.0 desktop app, global CLI, portability fixes |
| 08-pixel | Pixel Agents Visualization | `src/pixel/` `pixel-agents/` | 2 | Active — shipped dashboard wiring (#240/241/243), fixed shared-events bug (#250) |
| 09-qa-code | QA Code Review | `tests/` `reports/` | 3 | Active — split from 09-qa (code/test quality) |
| 09-qa-visual | QA Visual Audit | `reports/visual/` | 3 | Active — split from 09-qa (Playwright/browser audit) |
| 10-security | Security Auditor | `reports/` | 5 | Active (read-only) |
| 11-web | Web Developer — Landing & Docs | `site/` | 1 | Active — site + docs site stable |
| 12-designer | Visual Designer | `assets/` `images/` `public/images/` | 3 | NEW — replaces archived 12-brand. Logos, icons, carousels, thumbnails |
| 13-hr | HR & Team Culture | `docs/team/` `prompts/13-hr/` | 3 | Active |

## Inactive / Not in agents.conf

| Directory | Likely Role | Status | Notes |
|-----------|-------------|--------|-------|
| `prompts/01-pm/` | Old PM location | Orphaned | PM moved to 03-pm. Safe to archive. |
| `prompts/04-tauri-rust/` | Tauri Rust Backend | Dormant | Current `app/` is React + Node API, not Tauri. Activate only when there's a concrete Tauri ticket. |
| `prompts/05-tauri-ui/` | Tauri UI Frontend | Dormant | Same as above. |
| `prompts/07-ios/` | iOS Companion App | Dormant | Phase 3 — activate when iOS work is scoped. |
| `prompts/12-brand/` | Old brand role | **Archive** | Superseded by `12-designer`. |
| `prompts/14-researcher/` | Researcher (optional) | Dormant | Not on critical path. |

## Changes Since 2026-03-31 Snapshot

- **Added:** `00-cofounder`, `12-designer`
- **Split:** `09-qa` → `09-qa-code` + `09-qa-visual` (code audit vs live browser audit are distinct disciplines — never conflate)
- **Corrected narrative:** The "7-item CTO review queue / HARD PAUSE" from late March is obsolete. The team pivoted through v0.2 → v0.3 → v0.4 → v0.5 and the old blocker dissolved because strategy changed, not because the escalation worked. See `prompts/13-hr/team-health.md` for the post-mortem.

## Ownership Overlap Analysis

### Known Overlaps

1. **`reports/`** — shared by `09-qa-code`, `09-qa-visual`, `10-security`
   - Risk: LOW in practice (each writes to its own subdirectory: `reports/visual/`, `reports/qa-code/`, `reports/security/`)
   - Cleanup opportunity: make subdirectory ownership explicit in `agents.conf`. Not urgent.

2. **`docs/`** — PM owns `prompts/` and `docs/` broadly; CTO owns `docs/architecture/`; CEO owns `docs/strategy/`; HR owns `docs/team/`; Co-Founder owns `docs/operations/`
   - Risk: LOW — subdirectory ownership is clear, PM's broad ownership acts as fallback

3. **`prompts/`** — PM owns all of `prompts/`; HR owns `prompts/13-hr/`
   - Risk: LOW — HR only writes to own subdirectory, PM is coordinator by design

### No Overlaps (Clean)
- `scripts/`, `src/core/`, `src/lib/`, `benchmarks/` — Backend only
- `site/` — Web only
- `src/pixel/`, `pixel-agents/` — Pixel only
- `assets/`, `images/`, `public/images/` — Designer only
