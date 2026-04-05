# Shared Context — Cycle 2 — 2026-04-03 17:30:00
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle -> this cycle)
- Previous cycle: 5 agents ran, 4 commits produced
- 5-cycle orchestration sprint: benchmark suite, docs site, demo script, test expansion, PM update
- All 3 P0/P1 priorities from 99-actions.txt addressed: demo, benchmark, docs site

## CTO Queue — CLEARED (2026-04-05)
CS batch-approved all 7 previously-blocked items on 2026-04-05:
- single-agent.sh (#10), agents.conf v3 parser, SWE-bench scaffold (#4)
- qmd-refresher.sh (#53), prompt-template.sh (#54)
- task-decomposer.sh (#50), init-project.sh (#45)
HARD PAUSE lifted. All 7 modules now wired.

## Backend Status (Cycles 1+3)
- Orchestration benchmark runner DONE: `scripts/benchmark/run-orchestration-bench.sh` — measures per-agent wall time, token estimates, files changed, commit counts across N cycles. JSON + markdown output.
- Benchmark comparison tool DONE: `scripts/benchmark/run-comparison.sh` — diffs two runs, text/markdown/json output, per-agent deltas.
- Demo script DONE: `scripts/demo/run-demo.sh` — self-contained demo with 3 agents (PM, Developer, QA), simulates 2 cycles with colorful terminal output. Zero API calls.
- Demo recorder DONE: `scripts/demo/record-demo.sh` — wraps asciinema/script for terminal capture, ready for GIF conversion.
- Stall detector DONE: `src/core/stall-detector.sh` + wired into auto-agent.sh — prevents future idle-cycle loops by tracking meaningful commits and auto-pausing after 3 idle cycles.
- All new scripts follow project conventions: set -euo pipefail, bash 5.0+ check, no external deps.
- BUG-026 STILL OPEN (from prior cycle)

## Web Status (Cycle 2)
- Mintlify docs site foundation DONE: `docs-site/` directory with 7 files
  - `mint.json` — Mintlify config with OrchyStraw branding (orange #F97316), navigation, topbar
  - `introduction.mdx` — project overview with feature cards
  - `quickstart.mdx` — 5-minute guide (clone, configure agents.conf, write prompts, run)
  - `concepts/agents.mdx` — agent lifecycle, ownership, intervals, communication
  - `concepts/orchestrator.mdx` — auto-agent.sh cycle anatomy, smart features
  - `concepts/modules.mdx` — all 20+ modules documented with accordions
  - `api/agents-conf.mdx` — full format reference (v1/v2/v2+/v3)
- Ready for CS to connect Mintlify to GitHub for auto-deploy

## QA Status (Cycle 4)
- 42 new extended v0.2.0 tests DONE: `tests/core/test-v020-extended.sh`
  - Dynamic-router model selection: 7 tests (per-agent config, env overrides, CLI override precedence)
  - Review-phase QA gate: 10 tests (init, plan filtering, verdict recording, path traversal rejection)
  - Worktree isolation: 10 tests (create, branch, merge, cleanup, non-git rejection)
  - Prompt-compression tiering: 15 tests (classify, stable/dynamic detection, hash round-trip, compress modes)
- All 42/42 pass. No regressions to existing suite.
- Pre-existing failures: test-e2e-dry-run.sh (15 failures — output format mismatch), test-prompt-template.sh (partial) — both pre-date this sprint.

## Blockers
- BUG-026 (#190) STILL OPEN — `prev` uninitialized in agent-health-report.sh:48

## Notes
- Demo script ready for GIF recording — run `bash scripts/demo/run-demo.sh` and capture
- Docs site needs Mintlify GitHub connection for deployment
- 5 feature request drafts in `.github/ISSUE_DRAFTS/` — stall detector (done), CTO output protocol, PM force-pause signal, wire dormant v0.2.0 modules, Telegram alerts
