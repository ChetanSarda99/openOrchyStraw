# Shared Context — Cycle 2 — 2026-03-20 05:30:39
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=0
overall=0

## Progress (last cycle → this cycle)
- Previous cycle: 1 (0 backend, 0 frontend, 3 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- `qmd-refresher.sh` — auto-refresh QMD index each cycle (#37 CLOSED): state-tracked update/embed, configurable interval, replaces inline logic
- `context-filter.sh` — differential context per agent (#33 CLOSED): per-agent section filtering, 30-70% token savings for scoped agents
- `prompt-template.sh` — prompt template inheritance (#38 CLOSED): {{VAR}} placeholders for shared boilerplate (git rules, protected files, auto-cycle)
- Tests: 18/18 pass (15 existing + 3 new: qmd-refresher 17, context-filter 18, prompt-template 17 = 52 new assertions)
- Integration guide updated with Steps 10-12 for CS to apply

## iOS Status
- (fresh cycle)

## CTO Review (cycle 2)
- Architecture review of 4 new v0.2.0 modules: ALL PASS
  - usage-checker.sh: clean check-usage.sh replacement, graduated backoff, portable
  - task-decomposer.sh: priority-based task selection, P0 always-include
  - token-budget.sh: integer-only arithmetic, history-based reduction, hard cap
  - session-windower.sh: sliding window compression with .bak backup
- Minor: usage-checker.sh lines 102-108 dead branch (codex error handling), not blocking
- NEED from 06-backend: Integration guide Steps 10-12 for task-decomposer, token-budget, session-windower
- Recommended source order for new modules: usage-checker → signal-handler → cycle-tracker → token-budget → task-decomposer → session-windower
- Hardening doc updated with v0.2.0 module status
- Tech registry current, proposals inbox empty

## Design Status
- Phase 2 Pixel Agents adapter — 4 new files in `src/pixel/`:
  - `character-map.json` — maps all 9 agents to desk positions, sprites, idle spots, PM walkPath
  - `orchystraw-adapter.js` — Node.js adapter: agents.conf parser, JSONL watcher, state tracker, WebSocket bridge
  - `cycle-overlay.js` — Canvas HUD overlay (cycle counter, phase, active agents) + speech bubble renderer
  - `test-adapter.js` — 40 assertions, all pass (conf parsing, state tracking, live file watcher)
- Ready for pixel-agents-standalone fork: adapter plugs in via `attachToServer(wss, opts)`
- **11-web (cycle 2):** #44 GitHub Actions workflow for GitHub Pages deploy (`.github/workflows/deploy-site.yml`)
- **11-web (cycle 2):** #39 Hero terminal typing animation — staggered line reveals replace static text
- **11-web (cycle 2):** Fixed GitHub links — "Get Started" → openOrchyStraw, "Star on GitHub" + footer → OrchyStraw-Pro
- **11-web (cycle 2):** Build verified clean
- **11-web NEED:** CS must enable GitHub Pages (Settings → Pages → Source: GitHub Actions) on OrchyStraw-Pro repo

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## Notes
- (none)
