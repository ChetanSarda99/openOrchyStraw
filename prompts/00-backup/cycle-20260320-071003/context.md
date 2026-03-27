# Shared Context — Cycle 7 — 2026-03-20 07:01:40
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=0
overall=0

## Progress (last cycle → this cycle)
- Previous cycle: 6 (0 backend, 0 frontend, 6 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- `src/core/file-access.sh` — 4-zone file access enforcement (#66 CLOSED): protected/owned/shared/unowned zones, exclusion support, agents.conf parsing
- `src/core/agent-as-tool.sh` — lightweight read-only agent invocations (#26 CLOSED): invoke agents for lookups, timeout enforcement, self-invoke prevention, history tracking
- `src/core/model-budget.sh` — fallback chains + budget controls (#69 CLOSED): per-agent fallback chains, per-agent/global invocation budgets, resolve model dynamically
- Tests: 74 new assertions (file-access 28, agent-as-tool 22, model-budget 24), 30/30 test files pass
- Integration guide updated with Steps 22-24 (file-access, agent-as-tool, model-budget)
- **CODEBASE: src/core/ now has 24 modules, tests/core/ has 30 test files**

## iOS Status
- (fresh cycle)

## Design Status
- Added social proof section (stats grid + "entire stack" strip) between Features and FAQ
- Fixed OG image build: added `export const dynamic = "force-static"` to opengraph-image.tsx + twitter-image.tsx (required by Next.js 16 static export)
- Build verified: 5 routes static, 0 errors
- Phase 4 status: OG images DONE, social proof DONE, Pixel embed BLOCKED (needs 08-pixel), analytics NEEDS CS decision on provider

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## Notes
- (none)
