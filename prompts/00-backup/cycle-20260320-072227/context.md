# Shared Context — Cycle 8 — 2026-03-20 07:16:30
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=0
overall=0

## Progress (last cycle → this cycle)
- Previous cycle: 7 (0 backend, 0 frontend, 2 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- `src/core/vcs-adapter.sh` — VCS abstraction layer: git/svn/none backends (#59 CLOSED)
- `src/core/single-agent.sh` — Single-agent mode, skip PM/multi-agent overhead (#51 CLOSED)
- `src/core/review-phase.sh` — Enhanced with 4 efficient review functions: checklist, batch, prioritize, auto-verdict (#68 CLOSED)
- `tests/core/test-vcs-adapter.sh` — 22 assertions, all pass
- `tests/core/test-single-agent.sh` — 40 assertions, all pass
- `tests/core/test-review-phase.sh` — 37 assertions (20 existing + 17 new), all pass
- Integration guide updated with Steps 25-27
- **CODEBASE: src/core/ now has 27 modules, tests/core/ has 33 test files, 99 new assertions this cycle**

## iOS Status
- (fresh cycle)

## Design Status
- Phase 2.5 XSS Hardening COMPLETE: sanitizeText applied to labels, speech, file paths; 10 XSS tests added (50/50 pass)
- Phase 3 Landing Page Demo COMPLETE: `src/pixel/demo.html` (standalone) + `src/pixel/demo-embed.js` (embeddable UMD module)
- Demo shows 18-second looping cycle: agents walk to desks, code, review, PM updates, cycle resets
- 11-web can embed via `<canvas>` + `<script src="demo-embed.js">` + `PixelDemo.start(canvas)` or import as CommonJS module
- NEED: 11-web to integrate demo embed into landing page hero or features section

## Web Status (11-web, Cycle 8)
- Plausible analytics script added to layout.tsx (privacy-respecting, no cookies, GDPR-compliant)
- /changelog page created with v0.1.0 + v0.2.0 release notes, linked from footer
- Below-fold components lazy-loaded via next/dynamic (code splitting for smaller initial JS bundle)
- Sitemap updated with /changelog route (6 static routes total)
- Build verified: 6 routes static, 0 errors
- BLOCKED: #44 GitHub Pages deploy — CS must enable Pages (Settings → Pages → Source: GitHub Actions)
- NEXT: Pixel Agents demo embed — 08-pixel has demo-embed.js ready, integration pending

## QA Findings
- (fresh cycle)

## CTO Review (Cycle 8)
- **file-access.sh (#66) — PASS.** 4-zone access model, clean prefix matching, no injection vectors. 28 tests. Note: `can_read` blocks protected files for non-orchestrator agents — integration should use `can_write` for enforcement, `can_read` for audit only.
- **agent-as-tool.sh (#26) — PASS.** Read-only inter-agent invocations, self-invoke prevention, mock support. 22 tests. Note: read-only enforcement is advisory (prompt-level), not sandboxed. Acceptable for v0.2.
- **model-budget.sh (#69) — PASS.** Fallback chains + per-agent/global budgets, CLI availability check, cycle-aware reset. 24 tests. No issues.
- **All 24 src/core/ modules now reviewed and PASSED.** Integration steps 1-24 documented.
- Hardening doc updated with full cycle 8 review section.
- Proposals inbox: empty (no pending decisions).
- NEED: CS to integrate Steps 22-24 into auto-agent.sh (file-access, agent-as-tool, model-budget)

## Blockers
- (none)

## Notes
- Recommended integration order for Steps 22-24: file-access → model-budget → agent-as-tool
- Recurring pattern: unquoted `$paths` in for-loops across file-access, self-healing, quality-gates. All LOW risk (controlled inputs). Batch fix recommended for v0.3.
