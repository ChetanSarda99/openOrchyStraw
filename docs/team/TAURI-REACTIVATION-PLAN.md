# Tauri Agent Reactivation Plan

> Prepared: 2026-03-29 (Cycle 10, HR Agent)
> Trigger: v0.1.0 tagged AND benchmark sprint complete AND CS approves

## Agents to Activate

### 04-tauri-rust — Desktop App Rust Backend
- **Prompt:** `prompts/04-tauri-rust/` (exists, needs review)
- **Ownership:** `src-tauri/` — no overlap with active agents
- **Interval:** 1 (every cycle)
- **Reference doc:** `docs/references/TAURI-STACK.md` (locked)

### 05-tauri-ui — Desktop App React Frontend
- **Prompt:** `prompts/05-tauri-ui/` (exists, needs review)
- **Ownership:** `src/` (Tauri UI) — no overlap with active agents
- **Interval:** 1 (every cycle)
- **Reference doc:** `docs/references/TAURI-STACK.md` (locked)

## Pre-Activation Checklist

### CS Must Do
- [ ] Add 04-tauri-rust to `agents.conf` with interval 1
- [ ] Add 05-tauri-ui to `agents.conf` with interval 1

### PM Must Do
- [ ] Review 04-tauri-rust prompt against current template standard
- [ ] Review 05-tauri-ui prompt against current template standard
- [ ] Add PROTECTED FILES section to both prompts (BUG-012 compliance)
- [ ] Add current tasks section with initial Tauri scaffold work
- [ ] Update session tracker with activation note

### HR Verifies (First Cycle After Activation)
- [ ] No rogue writes outside owned directories
- [ ] Shared context read/write working
- [ ] CLAUDE.md referenced
- [ ] Git safety rules present
- [ ] No ownership overlap conflicts with 06-backend (`src/core/` vs `src/`)

### CTO Reviews
- [ ] Tauri architecture decisions align with TAURI-STACK.md
- [ ] IPC command patterns approved
- [ ] State management approach confirmed

## Ownership Boundary Notes

The `src/` directory split needs attention:
- **06-backend** owns `src/core/` and `src/lib/`
- **05-tauri-ui** will own `src/` (Tauri UI — components, styles, pages)
- **08-pixel** owns `src/pixel/`

These are non-overlapping subdirectories, but `agents.conf` should use specific paths:
- 05-tauri-ui: `src/components/ src/styles/ src/pages/` (NOT bare `src/`)
- This prevents accidental ownership claim over `src/core/` or `src/pixel/`

## Dependencies

04-tauri-rust and 05-tauri-ui depend on each other:
- Rust backend exposes IPC commands → UI calls them
- `tauri-specta` generates TypeScript bindings from Rust types
- Both must run in same cycle for coherent progress

They also depend on:
- **02-cto** for architecture decisions (interval 2 — may need to bump to 1 during initial Tauri sprint)
- **09-qa** for test coverage (interval 3)

## Timeline Estimate

Based on CEO roadmap:
1. v0.1.0 tag → immediate (CS action)
2. v0.1.1 (same day) → BUG-013 + BUG-012 fixes
3. Benchmark sprint → 3 days post-tag
4. HN launch → with benchmark receipts
5. **Tauri activation → after HN launch** (~4-5 days from now if tag happens today)
