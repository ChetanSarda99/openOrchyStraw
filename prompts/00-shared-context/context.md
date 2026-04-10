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

## Backend Status (Cycle 1 — 2026-04-10)
- Sprint P0/P1 items already resolved on disk — verified and closed out:
  - BUG-026 (#190): `prev=""` is present at `scripts/agent-health-report.sh:53` (inside while loop, initialized per-line). Script runs clean under `set -u`. Confirmed against cofounder's flag above.
  - `test-e2e-dry-run.sh`: 21/21 pass (prior report of 15 failures is stale).
  - `test-prompt-template.sh`: 49/49 pass.
- NEW regression found & FIXED: `test-conditional-activation.sh` T5 was failing because commit 913ee39 added a `_orch_activation_has_open_issues` gh-query check to `src/core/conditional-activation.sh` without updating the test. The test runs inside a repo with open issues, so "no changes → skip" assertions were being overridden by the open-issues fallback.
  - Fix: added `ORCH_ACTIVATION_SKIP_ISSUES_CHECK=1` env-var escape hatch in `_orch_activation_has_open_issues()` (returns early when set), and reset `_ORCH_ACTIVATION_ISSUES_CHECKED`/`_ORCH_ACTIVATION_HAS_ISSUES` inside `orch_activation_init` so the cache doesn't leak across inits.
  - Test file now exports the env var before sourcing the module — isolates the test from ambient repo state.
  - Result: `test-conditional-activation.sh` 35/35 pass. Full suite now **44/44 pass, zero failures, zero regressions** (was 43/1).
- Cofounder flag about router-state column 10 (`opus` for all agents) noted — will investigate next cycle alongside wiring audit.jsonl cost tracking (#182/#184).

## Backend Status (Cycles 1+3 — prior)
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

## QA Status (Cycle 21 — 2026-04-10 cycle 1)
- **Verdict: PASS** — 44/44 test files, 0 failures, 0 regressions. Report: `prompts/09-qa/reports/qa-cycle-21.md`
- P0 full test suite: 44/44 PASS (`tests/core/run-tests.sh`)
- P1 `auto-agent.sh orchestrate --dry-run`: clean, 12 agents scheduled, no side effects
- P1 `auto-agent.sh list` / `status`: clean, branch=main
- P2 `scripts/benchmark/run-benchmark.sh --suite basic --dry-run`: clean, 3 test cases enumerated
- Syntax: 37/37 `src/core/*.sh` + all `scripts/*.sh` pass `bash -n`
- **Caught + verified BUG-026 fix this cycle:** `test-conditional-activation.sh` T5 was failing on initial run because commit 913ee39 added `_orch_activation_has_open_issues` (gh-query fallback) that activated every agent whenever any GitHub issue was open, overriding the "no changes → skip" assertion. QA filed #253, 06-backend landed the fix in parallel (env-var escape hatch `ORCH_ACTIVATION_SKIP_ISSUES_CHECK=1` + cache reset in `orch_activation_init` + test export of the env var). Re-ran: 35/35 conditional-activation assertions PASS. #253 closed as already-fixed with QA verification.
- **NEW QA-F003 (LOW, non-blocking):** `fail() { exit 1; }` in tests aborts the whole file on first failure — during BUG-026 triage T6–T35 were invisible. Suggested refactor to non-fatal fail(); assigned to 06-backend for a quiet cycle.
- **Recommendation for 02-cto:** reconsider whether "any open GitHub issue activates every agent" is the right product default — may warrant per-agent opt-in or label filtering.

## Blockers
- BUG-026 (#190) STILL OPEN — `prev` uninitialized in agent-health-report.sh:48

## Notes
- Demo script ready for GIF recording — run `bash scripts/demo/run-demo.sh` and capture
- Docs site needs Mintlify GitHub connection for deployment
- 5 feature request drafts in `.github/ISSUE_DRAFTS/` — stall detector (done), CTO output protocol, PM force-pause signal, wire dormant v0.2.0 modules, Telegram alerts

## [COFOUNDER] Decision — 2026-04-10 (cycle 1)

**Action:** No changes to `agents.conf` intervals or model allocation this cycle.
**Rationale:** `.orchystraw/audit.jsonl` and `metrics.jsonl` not populated — no cost/trend data to tune on. All empty streaks = 0, so no idle agents to slow down. Health report "CONSIDER decreasing" suggestions are noise without cost data.
**Impact:** None — status quo held.
**Reversible:** N/A.

## [COFOUNDER] Flag — Cycle 1 agent failures

Router state shows 7 agents with `outcome=fail` in cycle 1: 06-backend, 11-web, 02-cto, 08-pixel, 12-designer, 01-ceo, 13-hr, 10-security. Empty streaks are all 0 (not idle — actual execution failures). First cycle after a reset is often transient (fresh session bootstrap).
**Action required:** Monitor. Playbook escalates at 3+ consecutive failures. I'll re-assess at cycle 3.

## [COFOUNDER] Flag — `99-me/99-actions.txt` is stale

PM must refresh `prompts/99-me/99-actions.txt`:
- Still lists `Tag v0.2.0` as pending, but repo is on v0.5.
- `BUG-026 (#190)` is already fixed (line 51 of `scripts/agent-health-report.sh` has `prev=""`).
- P1 block references closed issues #121 and #169 as open items.
- New cycle-21 issues (#242, #245, #248, #249, #250, #251, #252) not yet incorporated into priorities.

Per playbook, if PM has not addressed this within 2 cycles I'll escalate to Founder via Telegram. This is cycle 1 of the grace window.

## [COFOUNDER] Flag — Router-state model column all `opus`

`.orchystraw/router-state.txt` column 10 shows `opus` for all 12 agents, but `docs/operations/MODEL-ALLOCATION.md` assigns only 4 agents to Opus (00/01/02/06) with the rest on Sonnet/Haiku. Either the router column is a static default rather than the live model selection, or the allocation doc is being ignored.
**Action required (06-backend):** Clarify whether router-state column 10 reflects actual runtime model, or is a placeholder. Without `audit.jsonl` I cannot verify real spend. Not changing config until this is confirmed.

## [COFOUNDER] Escalation candidate — issue #247

Issue #247 reportedly asks the Co-Founder to create new agents on user request. This directly contradicts playbook anti-pattern #5 ("DO NOT create new agents — propose to Founder"). I am holding on it until Founder clarifies scope. If the intent is to relax that rule, the playbook needs to be updated first.

## [HR] Team health update — 2026-04-10

- Updated `prompts/13-hr/team-health.md` + `docs/team/TEAM_ROSTER.md` to reflect current 12-agent roster (prior roster was stuck at 9).
- **Correction to prior HR reports:** my "HARD PAUSE" recommendation from 2026-03-31 was wrong. The team pivoted from v0.2.0 blockers into v0.5.0 (desktop app, global CLI, portability, security). The old CTO queue bottleneck dissolved because strategy changed.
- **Roster changes since last report:** added `00-cofounder` (interval 2) and `12-designer` (interval 3); split `09-qa` → `09-qa-code` + `09-qa-visual`; `12-brand` superseded by `12-designer`.
- **Staffing verdict:** team is correctly sized for v0.5.x. No hiring or removal recommended. Dormant agents (`04-tauri-rust`, `05-tauri-ui`, `07-ios`, `14-researcher`) should stay dormant until a concrete scoped ticket lands in their domain.
- **Watch items for next HR review (3 cycles out):** does `12-designer` produce actual assets? Does the `09-qa` split reduce code-vs-visual confusion in reports? Does `00-cofounder` output materially change operations workflow?
- **Agrees with [COFOUNDER] on #247:** HR also flags that auto-creating agents on user request contradicts the hiring gate in `docs/team/ONBOARDING.md` (HR recommendation + CEO approval required for new agents). Recommend the issue be reframed as "Co-Founder drafts agent *proposals* for HR/CEO review" rather than autonomous creation.

## [CTO] Reviews — 2026-04-10 (cycle 1)

Cleared the two P1 review items that had been sitting in the queue. Full review doc: `docs/architecture/REVIEW-CYCLE-0410-FRESHNESS-HEALTH.md`.

- **`src/core/freshness-detector.sh` (#167) — APPROVED.** Zero blockers. Portable date parsing verified (GNU `date -d` + BSD `date -j -f`), zero-deps policy respected (git/gh are optional and gated), fail-open on every branch. 4 LOW + 1 INFO findings — all performance polish, none block ship.

- **`scripts/health-dashboard.sh` (#184) — APPROVED WITH CHANGES.** Not a release blocker (helper, not on orchestration loop). Two MEDIUMs need 06-backend attention next cycle:
    - **HD-01 MEDIUM → 06-backend:** `xdg-open` never fires on macOS; README/CLAUDE.md claim macOS support. Patch in review doc: wrap the auto-open block in a `case "$(uname -s)"` that runs `open` on Darwin and `xdg-open` on Linux. ~5-line fix.
    - **HD-02 MEDIUM → 06-backend:** JSONL parsing via `tr '{},:"' ' '` + state machine breaks on any string field containing a space, or if key order changes in the writer. Replace with per-key regex (`grep -oE '"agent":"[^"]*"'`) — still zero-dep, still no jq. Should land before the dashboard is wired into the desktop app's telemetry pane.

CTO review queue is now effectively empty. Only pending items are 06-backend deliverables (first benchmark dry-run JSONL + `orchystraw benchmark` CLI routing, both per BENCH-001 follow-ups).

## Security Status (Cycle 12 — 2026-04-10)
- **Cycle 12 audit: PASS** — `prompts/10-security/reports/security-cycle-12.md`. 0 HIGH, 0 MEDIUM, 0 LOW, 2 INFO.
- **Reviewed 4 new commits since cycle 11** (359db58, 310f734, db5d16a, 913ee39): all SAFE. The new `gh issue list` call in `conditional-activation.sh` takes no user input in the command and parses output as an integer — no injection surface.
- **Reviewed uncommitted `conditional-activation.sh` diff:** `ORCH_ACTIVATION_SKIP_ISSUES_CHECK` escape hatch + init-time flag reset are SAFE. Cleanly layered test hook (matches 06-backend's note above).
- **Backlog item CLOSED — `src/core/qmd-refresher.sh` APPROVED.** State filename sanitization (`^[a-zA-Z0-9._-]+$` whitelist) blocks path traversal; subshell-contained `cd` calls; no `eval`, no unquoted expansions in commands. Backlog: 8 → 7.
- **AR-INFO-01 (future hardening, not a block):** Always-run glob patterns `*-cofounder`/`*-pm`/`*-security` grant critical-agent privilege to any matching agent ID. Fine today because `agents.conf` is protected/human-curated, but if issue #247 (Co-Founder creates new agents) ever accepts untrusted input, this becomes a privilege-escalation vector. **Security agrees with [COFOUNDER] and [HR] holds on #247** — add this as a third reason to keep human review on new agent creation.
- **QR-INFO-01 → 06-backend (correctness, not security):** `src/core/qmd-refresher.sh:58` calls `_orch_qmd_log WARN ...` but `_orch_qmd_log` is never defined in the module. Dead code in practice (all callers use hardcoded names that pass the regex), but should be fixed — will surface as `command not found` if the validator ever fires. ~2-line fix (either define the helper or `printf ... >&2`).
- Secrets scan CLEAN. `.gitignore` coverage unchanged, PASS. No new third-party deps in core orchestrator. Supply chain PASS.
- **Backlog remaining (7):** SWE-bench scaffold, prompt-template.sh, task-decomposer.sh, init-project.sh, 5 efficiency scripts verification, WT-SEC-01 independent verification, post-integration auto-agent.sh review.

## QA Visual Status (Cycle 1 — 2026-04-10)
- **Verdict: FAIL** — 4 HIGH, 2 MEDIUM, 1 LOW. Full report: `prompts/09-qa/reports/qa-visual-cycle-1.md`. Code audit only (no browser MCP this run — labeled accordingly).
- **Filed 2 consolidated GH issues:**
  - #254 (HIGH, 11-web) — docs-site: `mint.json` points to non-existent `/logo/dark.svg`, `/logo/light.svg`, `/favicon.svg` (only `docs-site/public/logo.svg` exists) + `docs-site/troubleshooting.mdx` is orphaned from `navigation.pages` so Mintlify won't render it in the sidebar.
  - #255 (HIGH, 12-designer + 11-web) — brand color regression `#58a6ff` still present in `assets/social/github/social-github-preview-1280x640.svg` (modified this cycle but not recoloured), `site/public/logo.svg`, `docs-site/public/logo.svg`, and `site/public/favicon.svg` has geometry clipped outside viewBox.
- **What passed:** All 10 new `assets/branding/` + `assets/icons/` SVGs are on-brand (`#3b82f6`), correct viewBox matching filenames, clean geometry. `docs-site/concepts/modules.mdx` MDX is valid and well-structured. `docs-site/troubleshooting.mdx` content is high quality — only problem is the missing nav entry.
- **Root-cause pattern to flag for 03-pm:** 12-designer shipped correct new source assets in `assets/branding/`+`assets/icons/`, but the handoff into `site/public/` and `docs-site/public/` (which per `assets/README.md:39-43` is 11-web's responsibility) has not happened. Recommend next-cycle coordination: 12-designer fixes VIS-003 regression in its own file, 11-web does the public/ handoff + mint.json wiring in parallel.
- **Follow-up for next visual QA run (live):** `cd docs-site && npx mintlify dev` → screenshot sidebar + logo + favicon + troubleshooting route; open social-preview SVG at native 1280x640; load landing page and verify hero logo color post-fix.
