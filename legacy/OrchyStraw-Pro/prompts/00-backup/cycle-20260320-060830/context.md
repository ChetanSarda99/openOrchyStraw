# Shared Context — Cycle 4 — 2026-03-20 05:57:44
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=0
overall=0

## Progress (last cycle → this cycle)
- Previous cycle: 3 (0 backend, 0 frontend, 4 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- `dynamic-router.sh` — dependency-aware parallel execution (#27 CLOSED): topological sort into execution groups, circular dep detection, priority ordering, agents.conf v2 parsing (backward compatible)
- `worktree-isolator.sh` — git worktree isolation per agent (#28 CLOSED): per-agent worktrees, merge-back, conflict detection, cleanup
- `model-router.sh` — model tiering per agent (#30 CLOSED): per-agent CLI routing (claude/codex/gemini), availability check, fallback, config-driven
- `review-phase.sh` — loop review & critique (#24 CLOSED): structured review phase, diff generation, review templates, approve/request-changes/comment verdicts, blocking detection
- Tests: 24/24 pass (20 existing + 4 new: dynamic-router 20, worktree-isolator 17, model-router 20, review-phase 20 = 77 new assertions)
- Integration guide updated with Steps 15-18
- **SMART CYCLE SYSTEM COMPLETE: all 4 modules built**
- NEED: CS to integrate Steps 15-18 into auto-agent.sh
- NEED: CS to add priority/depends_on/model/reviews columns to agents.conf

## iOS Status
- (fresh cycle)

## Design Status
- Phase 2 Fork complete: `pixel-agents/` directory with full server scaffold
- `pixel-agents/server.js` — Express + WebSocket server, wires `orchystraw-adapter.js` via `attachToServer(wss, opts)`
- `pixel-agents/public/index.html` + `pixel-agents/public/app.js` — Canvas-based pixel art renderer with desks, characters, speech bubbles, HUD overlay
- `pixel-agents/test-e2e.js` — 13 assertions, all pass (HTTP health, WS init, JSONL detection, speech events, multi-client state)
- `pixel-agents/package.json` — deps: express, ws (zero other deps)
- Adapter unit tests: 40/40 pass (unchanged from cycle 2)
- READY for QA review + CTO architecture review of fork integration
- NEXT: Phase 3 — embed visualization in Tauri dashboard via webview

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## CTO Review (Cycle 4)
- ✅ **conditional-activation.sh** (#32) — PASS: safe regex, array-based git pathspec, no injection vectors. 24 tests. NOT INTEGRATED yet (CS: Steps 13-14).
- ✅ **prompt-compression.sh** (#31) — PASS: three-tier loading, safe section parsing, no eval. 27 tests. NOT INTEGRATED yet.
- ✅ **context-filter.sh** — PASS: declarative section mapping, safe regex. 18 tests.
- ✅ **prompt-template.sh** — PASS: awk-based multiline substitution, no eval. 17 tests.
- ✅ **qmd-refresher.sh** — PASS: subshell isolation, timestamp-based refresh. 15 tests.
- ⚠️ **Pixel Phase 2 adapter** — CONDITIONAL PASS: clean architecture (Watcher→StateTracker→WebSocket→Canvas), but XSS risk in speech text broadcast (sanitize before DOM consumers), 3/11 agents unmapped (04/05/07 — acceptable, deferred agents).
- ✅ All 12 v0.2.0 backend modules now reviewed and PASSED
- ✅ Hardening doc updated with full cycle 4 review section
- ✅ Proposals inbox: empty
- NEED: CS to integrate Steps 13-14 (conditional-activation + prompt-compression) into auto-agent.sh

## Web Status
- #43 Mintlify docs site setup COMPLETE — `site/docs/` with 12 MDX pages + mint.json
- Pages: introduction, quickstart, configuration, writing-prompts, shared-context, auto-cycle, pixel-agents, examples/basic, examples/full-team, faq, contributing, changelog
- Content ported from ARCHITECTURE-REFERENCE.md, AGENT-DESIGN-REFERENCE.md, README.md
- All Mintlify built-in components used (Steps, Cards, Tabs, Accordion, Note, Warning)
- Theme: OrchyStraw orange (#F97316), dark mode (#0a0a0a), GitHub topbar link
- BLOCKED: #44 deploy still waiting on CS to enable GitHub Pages
- NEXT: CS to connect Mintlify to GitHub (mintlify.com/start → point to site/docs/)

## Notes
- (none)
