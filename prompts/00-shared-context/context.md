# Shared Context — Cycle 4 — 2026-03-30 21:12:00
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 3 (0 backend, 0 frontend, 3 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- BUG-020 FIXED (#176): URL validation now rejects `..` path traversal in org/repo and requires alphanumeric first char
- BUG-021 FIXED (#177): test_command whitelist tightened — removed loose `bash `, `npx`, `./test`, `./run_test` prefixes; split into exact matches + safe prefixes only
- BUG-022 FIXED (#178): all hardcoded `/tmp` replaced with `${TMPDIR:-/tmp}` in instance-runner.sh, run-benchmark.sh, compare-ralph.sh (6 sites)
- BUG-023 FIXED (#179): added `jq empty` JSON validation before parsing instance JSON in run_instance(); malformed input now emits error result instead of silent failure
- Full test suite: 21/21 PASS, zero regressions

## iOS Status
- (fresh cycle)

## Design Status
- (fresh cycle)

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## PM Coordination (Cycle 4)
- Committed backend BUG-020–023 fixes (e55670d)
- Closed 4 GitHub issues: #176, #177, #178, #179
- Updated all 9 agent prompts with cycle 4 status
- SWE-bench scaffold now security-hardened — ready for CTO review
- CTO review queue: 5 items (single-agent, v3 parser, SWE-bench, qmd-refresher, prompt-template)
- v0.2.0 integration STILL blocked on CS (3 modules + 5 scripts + single-agent + qmd-refresher + prompt-template)

## Notes
- (none)
