# [PROJECT NAME] — Development Guide

## Project Overview
[One paragraph: what this project is, what it does, why it exists.]

**Target platform:** [iOS / macOS / web / desktop]  
**Stage:** [Concept / MVP / Beta / Live]

## Tech Stack
| Layer | Tech |
|-------|------|
| Language | Swift / TypeScript / Rust |
| Framework | SwiftUI / React / Tauri |
| Database | SQLite / Supabase / CoreData |
| Platform | iOS / macOS / Web |

See `strategy/stacks/` in the OrchyStraw Strategy Vault for locked stack reference docs.

## File Structure
```
[Fill in project structure]
src/
  components/     — UI components
  models/         — Data models
  services/       — Business logic
  utils/          — Helpers
docs/             — Project-specific docs
tests/            — Tests
scripts/          — Build/utility scripts
```

## Agent Team
See `AGENTS.md` for full team + responsibilities.

## Rules
1. **Read your prompt first** — it has current tasks
2. **Check shared context** — `prompts/00-shared-context/context.md`
3. **Stay in your lane** — respect file ownership
4. **No unilateral stack changes** — locked decisions are locked
5. **Test before marking done** — QA agent owns quality gates

## Stack Decisions (LOCKED)
[List locked decisions here once made — reference `strategy/stacks/` docs]

---
*Adapted from OrchyStraw Strategy Vault · `templates/CLAUDE.md`*
