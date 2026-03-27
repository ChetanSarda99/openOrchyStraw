# DB-001: Desktop App Database

_Decision Date: 2026-03-18_
_Status: APPROVED_
_Decided By: CTO_

---

## Domain
Desktop Database — Storage for Tauri app (Layer 1 + Layer 2 data)

## Decision
SQLite (via Tauri's built-in SQLite plugin or rusqlite)

## Rationale
- Tauri apps need local-first storage — SQLite is the standard
- Zero network dependency, works offline
- Python stdlib includes SQLite (for v0.5 CLI)
- Rust has excellent SQLite bindings (rusqlite, sqlx)
- Schema already designed in APP-ARCHITECTURE.md (Layer 1 + Layer 2)
- No server, no auth, no cost — just a file

## Storage Locations
- Global: `~/.orchystraw/orchystraw.db` (Layer 1: user prefs, global knowledge)
- Project: `<project>/.orchystraw/project.db` (Layer 2: project config, cycles, issues)

## Alternatives Considered
- **libsql (Turso)**: Good for sync, but adds network dependency and cost. Overkill for local-first desktop app.
- **IndexedDB**: Web-only, not available in Tauri Rust backend.
- **JSON files**: No query capability, no ACID guarantees, doesn't scale.

## Reversibility
Medium — SQLite is the data layer. Schema migration possible, but switching to a different DB engine would require rewrite of all data access code.
