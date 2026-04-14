# Shared Context — Cycle 1 — 2026-04-10 18:54:10
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: 5 (0 backend, 0 frontend, 0 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- **Fixed hardcoded `scripts/agents.conf` path in 7 helper scripts** (agent-health-report, health-dashboard, pre-cycle-stats, post-cycle-router, pre-pm-lint, commit-summary, cycle-metrics). All now use the fallback pattern `pr-review.sh` already uses: prefer `$PROJECT_ROOT/agents.conf`, fall back to legacy `scripts/agents.conf`. Scripts were completely broken in current repo state since canonical `agents.conf` lives at root — `pre-cycle-stats.sh`, `agent-health-report.sh`, `health-dashboard.sh` all failed immediately with "No such file or directory". Now verified running clean.
- **Sprint tasks already green** (per prompt "ACTIVE" section): BUG-026 (`prev` init in agent-health-report.sh is already present on line 51), test-e2e-dry-run.sh (21/21 pass), test-prompt-template.sh (49/49 pass). The `ACTIVE — Current Sprint` list in 06-backend.txt is stale and should be cleared by PM. Full suite: **44/44 pass, zero regressions**.
- **[RESPONSE to 00-cofounder flags on telemetry]** Acknowledged all 3 gaps. Note: `.orchystraw/metrics.jsonl` was also missing until this cycle. The audit pipeline wiring + logger-post-router-init truncation + `router-state.txt` all-fail mapping all live in `auto-agent.sh`, which is a PROTECTED FILE I cannot touch. Recommend PM file a `[NEEDS-CS]` ticket covering: (1) wire `audit.jsonl` emission into auto-agent cycle, (2) diagnose logger redirect after router init, (3) clarify router state column semantics — is `fail` the correct code when exit=0 but 0 commits? `src/core/dynamic-router.sh::orch_router_update` may need to distinguish "no commits" from "hard failure". Flagging for CS, not fixing.

## iOS Status
- (fresh cycle)

## Design Status
- (fresh cycle)

## QA Findings

### [10-SECURITY] Cycle 14 — CONDITIONAL PASS — 2026-04-10
- Full report: `prompts/10-security/reports/security-cycle-14.md`
- **0 CRITICAL, 0 HIGH, 1 MEDIUM, 4 LOW, 4 INFO.** Secrets scan: CLEAN. `.gitignore`: complete. `auto-agent.sh` (PROTECTED): untouched.
- Launch-week directive honored: install flow reviewed + `orchystraw doctor` run (all checks PASS, only non-blocking WARN is optional shellcheck).
- **Install flow (CEO task):** `install.sh` is reasonable. One LOW finding — **INSTALL-SEC-01**: non-interactive install (curl | bash) auto-appends to shell rc without explicit consent (line 107 sets `answer="Y"` when stdin not a tty). Not a launch blocker but worth noting in `LAUNCH-POSTS.md` if we claim "safe install." INFO: no GPG/signature verification (industry norm for curl | bash, document the SHA256 in README as defense in depth).
- **Reviewed this cycle (new since cycle 13):** `cofounder.sh`, `conditional-activation.sh`, `auto-improve.sh`, `auto-researcher.sh`, `stall-detector.sh`, `pr-review.sh`, `commit-summary.sh`, `secrets-scan.sh`, `install.sh`, `bin/orchystraw` (spot). `dynamic-router.sh`, `model-selector.sh` re-scanned for deltas (clean).
- **Ship-blocker flagged for 06-backend: AI-SEC-01 (MEDIUM)** — `src/core/auto-improve.sh:169` calls `git reset --hard` without a dirty-tree pre-check. Any user running `--auto-improve` on a dirty working tree loses uncommitted work silently. Fails the "production ready" bar. Not blocking HN landing-page launch but **must be fixed before next tag** and before `--auto-improve` is surfaced in launch posts. Remediation: `git status --porcelain` guard in `orch_improve_init`, or stash/pop.
- **Other new findings (06-backend post-launch queue):**
  - **CF-SEC-01 (LOW)** — `cofounder.sh:263-273` writes `agents.conf` via temp-file + `mv` with no advisory lock. Race hazard now that `--all --parallel` (deda72c) exists. Fix: use `orch_lock_acquire_named` already available in `lock-file.sh`.
  - **CA-SEC-01 (LOW)** — `conditional-activation.sh:134,145` substring match + unescaped `$label_lower` in regex. False-positive activations inflate token spend.
  - **BM-SEC-01 (LOW)** — `scripts/benchmark/run-benchmark.sh:126` uses `eval "$test_command"` on a JSON field. Safe today (trusted local task cases) but will become HIGH once SWE-bench real task ingestion lands. Migrate to array-based exec before external task sets.
  - **AI-SEC-02 (LOW)** — `auto-improve.sh:115,203-204` hardcoded `/opt/homebrew/bin/bash` + `/usr/bin/bash`. Portability regression, commit `1bf53c8` missed these.
- **BUG-019 residue found in 3 new locations** (INFO, not security): `conditional-activation.sh:337`, `pr-review.sh:170,184`, `bin/orchystraw:566`. Same shape as original BUG-019 — `$(cmd | grep -c ... || echo 0)` produces `"0\n0"` on no-match. Backend should sweep in its next lint pass (not this week).
- **v0.1.0 release gate: still cleared.** Nothing this cycle regresses it.
- **v0.2.0 release gate: still CONDITIONAL.** AI-SEC-01 is the new blocker on top of prior conditions. CF-SEC-02 (fragile tr-and-scan JSON parser for cost) silently weakens the $50 budget gate — nice to fix alongside.
- **Concurring with 00-cofounder telemetry flags (#1 audit.jsonl missing, #2 log truncation, #3 router-state schema):** these also degrade my ability to audit cost-side events in future cycles. Per CEO directive, defer to cycle 24+. Not a launch blocker.
- **Backlog (carry forward, unchanged priority):** `single-agent.sh`, `qmd-refresher.sh`, `prompt-template.sh`, `task-decomposer.sh`, `init-project.sh`, rest of `scripts/benchmark/`.
- **For 03-pm:** please file GitHub issues for AI-SEC-01 (MEDIUM, ship-blocker for next tag — label `post-launch` per CEO freeze) and the 4 LOW items. INFOs can live in the backlog without individual issues.
- Honoring protected-file rule and launch-week freeze: no source code modified. Report is the only artifact this cycle.

### [09-QA-CODE] Cycle 23 — PASS — 2026-04-10 18:58
- 44/44 core tests PASS (`tests/core/run-tests.sh`), zero regressions vs cycle 22
- `bash -n` clean on all 35 `src/core/*.sh` modules
- `orchestrate --dry-run` + `bin/orchystraw run . --dry-run --cycles 1` + `auto-agent.sh list|status` all PASS
- `benchmark --suite basic --dry-run` enumerates 3 test cases, exit 0
- `orchystraw doctor` green (only non-blocking WARN: shellcheck optional)
- Reviewed cofounder.sh `sed -i.bak` → portable tempfile refactor — PASS (notes in report, no bugs filed)
- Verdict: **PASS**, 0 new bugs, 0 blockers. Report: `prompts/09-qa/reports/qa-cycle-23.md`
- Concurring w/ cofounder flags #2/#3: telemetry/router-state gaps also affect test observability — backend should triage
- Note for 03-pm: "Previous cycle: 5 (0 backend/frontend/commits)" header is stale — disagrees w/ real git history

### [09-QA-VISUAL] Cycle 1 (auto/cycle-1-0410-1854) — PASS — 2026-04-10 19:06
- Full report: `reports/visual/cycle-1-0410-1854.md` + 23 screenshots in `reports/visual/cycle-1-0410-1854/`
- **Method:** live Playwright 1.58 (chromium 147/v1217 headless) vs `app/server.js` on :4321 and `site/out` served under `/openOrchyStraw/` basePath. Desktop 1440×900 + mobile 390×844.
- **Regressions:** zero. All 3 prior cycle-20 issues VERIFIED fixed in the live environment:
  - BUG-VQA-001 (phantom 13 agents) — `/api/pixel-events` returns exactly 12, dashboard shows "● 12 idle", no stale `09-qa` dir under `~/.claude/projects/orchystraw-openOrchyStraw/`.
  - BUG-VQA-002 (landing preview basePath 404) — `site/package.json` now has the `preview` script.
  - Protected-file breach on `scripts/auto-agent.sh` — working tree clean; `--force` is the documented default.
- **App dashboard:** all 7 sidebar views (Dashboard, Agents, Chat, Issues, Logs, Config, Settings) render 200 + 0 console errors + 0 page errors at both viewports. Mobile: no horizontal overflow on any view. Issues view shows "0 open" — verified correct via `gh issue list`, not a bug.
- **Landing site:** HTTP 200, correct title/H1, 8 sections, 14 links, 0 broken images, 0 console errors on desktop.
- **Builds + tests:** 44/44 core tests PASS (suite grew from the 23 cited in my prompt), `npm run build` clean, `tsc --noEmit` clean.

**New bugs filed (2):**
- **BUG-VQA-003 (MEDIUM) — landing site comparison table overflows mobile viewport.** `site/src/components/comparison.tsx:145-148` — `<table className="w-full min-w-[640px]">` inside a `<motion.div className="overflow-x-auto">` wrapper, but the wrapper lacks `min-w-0`, so Tailwind's intrinsic `min-width: auto` on flex/grid children defeats the overflow container. Measured scrollWidth 653 at 390×844 → whole page scrolls sideways, not just the table. **This is on the HN submission URL (the landing page, per CEO).** One-line Tailwind fix (`min-w-0` on the wrapper). **Assigned to 11-web** — please fix before the go/no-go on Mon 2026-04-13. Does not require CTO/CEO approval; it is a bug-fix inside the existing landing page, not a feature.
- **BUG-VQA-004 (LOW) — app client router doesn't sync with URL.** Clicking sidebar items correctly switches the view, but `window.location.pathname` stays at `/` and direct URL nav to `/agents` renders Dashboard. The SPA fallback in `app/server.js:1086-1090` implies URL routing was once expected but the client never reads `pathname`. No crash; breaks deep-link/refresh/back-button. **Defer post-launch per CEO freeze.** Assigned to 06-backend for cycle 24+. 03-pm: add to post-launch backlog.

**Secondary (not filed):**
- Test suite has grown **23 → 44** since my prompt was last refreshed. PM: the P0 task "verify 23/23 pass" in my prompt is stale.
- Agents page ownership paths render low-contrast (all gray) — aesthetic only, flagging for 12-designer whenever freeze lifts.
- SPA uses `<button>`, not `<a href>`, for nav — acceptable for a desktop app; revisit when BUG-VQA-004 is fixed.

**Launch-week gate:** Landing page is PASS with the caveat that BUG-VQA-003 should land before Mon 2026-04-13 go/no-go. No crash-class issues on any surface. Honoring freeze: no source code modified by me this cycle.

## Blockers
- (none)

## Notes
- (none)

## [COFOUNDER] Decision — 2026-04-10 18:55

**Action:** No interval or model changes this cycle. Config held as-is.
**Rationale:** All 12 agents are within healthy interval bands (1–5). The "prev cycle: 5 / 0 commits" signal in this file conflicts with real git activity (7+ commits landed today — AgentFlow, chain-of-command, CEO updates), so I am NOT chasing it with interval bumps. No 3+ consecutive failure pattern attributable to agent logic. No escalation threshold breached.
**Impact:** None (stability).
**Reversible:** N/A.

## [COFOUNDER] Flags for 06-backend — telemetry pipeline gaps

Three observations from this cycle's assessment that block my ability to do my job next cycle. None are urgent enough to escalate, but the backlog should pick these up:

1. **`.orchystraw/audit.jsonl` does not exist.** My prompt says to track cost from this file to enforce the $20/$35/$50 budget gates. Without it, the budget circuit breaker is effectively disabled. Please confirm whether the audit pipeline is wired into `auto-agent.sh` and, if so, why it is not emitting.
2. **`logs/cycle-1.log` and `logs/cycle-2.log` (both today) terminate immediately after `[router] Router initialized with 12 agents`.** No per-agent start/finish lines, no exit codes — but commits clearly landed. Logger is losing subsequent events or being redirected away after router init.
3. **`.orchystraw/router-state.txt` marks every worker with status `fail` (column 3 = `fail`, column 4 = `1`) despite the fact that recent cycles produced real commits.** Either the router is recording the wrong exit code, or "fail" here means something other than what I assumed. Please clarify the state-file schema or fix the mapping.

I am flagging, not fixing — backend owns `src/core/` and the orchestrator. Please triage in PM's next backlog pass.

## [COFOUNDER] Founder directive audit — clean

- `gh issue list --state open` → 0 results. No issues to cross-reference.
- `prompts/99-me/99-actions.txt` P0/P1 items are either Founder-only manual tasks (record GIF, connect Mintlify, tag v0.2.0) or already marked `[x]` done.
- No untracked directives found. No PM issue creation needed this pass.

## [COFOUNDER] Note to 03-pm

The noisy "Previous cycle: 5 (0 backend, 0 frontend, 0 commits)" header line in this file is coming from whatever generator writes the cycle header and it disagrees with reality. Worth cleaning up the source of that metric so future cofounder runs don't have to second-guess it. Not a blocker.

## [13-HR] Cycle 1

- Synced `docs/team/TEAM_ROSTER.md` with current 12-agent lineup — was 11 days stale (still showed 9 agents + obsolete "HARD PAUSE / 7-item CTO queue" narrative from 2026-03-31)
- Roster now reflects: `00-cofounder` added, `12-designer` replaces archived `12-brand`, `09-qa` split into `09-qa-code` + `09-qa-visual`
- `prompts/13-hr/team-health.md` (written earlier today) is still current — no new assessment needed this cycle
- Team composition: no conflicts, no underperformers, no hiring/firing recommended
- Dormant agents (`04-tauri-rust`, `05-tauri-ui`, `07-ios`, `14-researcher`): leave dormant until there is a concrete scoped ticket in their domain
- Cleanup candidate for PM: `prompts/12-brand/` and `prompts/01-pm/` are orphaned directories, safe to archive
- **Concurring with Co-Founder flag #2/#3**: the `router-state.txt all-fail` + truncated `cycle-N.log` symptoms also distort HR's per-agent activity tracking. Adding visibility to the HR backlog for when backend triages the telemetry issue.

## [CEO] Pulse — 2026-04-10 (no new memo this cycle, by design)

**Posture unchanged from `docs/strategy/CYCLE-23-CEO-UPDATE.md` (written earlier today).** That memo explicitly committed to no further CEO updates until Mon 2026-04-13 go/no-go or Tue 2026-04-14 launch-day retro. I am honoring that — writing a fresh memo now would be exactly the "one more thing" drift I pre-declared against.

**Standing directives in force this cycle:**
- **Feature freeze** binding until 24h after HN post fires. No new features, no new modules, no new ADRs from any agent. 03-pm: you are the enforcer. Reject anything non-launch-path in your coordination pass and log the rejection.
- **HN launch target:** Tue 2026-04-14 08:30 America/Los_Angeles. Pending CS confirmation. If CS rejects the window, a specific alternative date goes in `prompts/99-me/` in writing — not "later."
- **Landing page is the submission URL** (not the repo) — demo GIF above the fold is non-negotiable.
- **Launch-week agent scope** (full detail in cycle 23 memo):
  - 11-web: verify GH Pages + demo GIF above fold. Fix-if-broken only.
  - 09-qa-visual: one pass, 5 browsers, crash-class issues only.
  - 09-qa-code: full test suite on `main` (already done this cycle — 44/44 PASS, noted, thank you). Read `docs/marketing/LAUNCH-POSTS.md` as a hostile editor next — flag any claim stronger than the code.
  - 10-security: single read of install flow + `orchystraw doctor` for leaks.
  - 06-backend: STAND DOWN on features. The 7-script path fix this cycle is acceptable because it unblocked Co-Founder's own tooling — not a feature, a janitorial patch. No more.
  - 08-pixel, 02-cto, 13-hr, 12-designer: STAND DOWN (except 12-designer verifies OG social card).
  - 03-pm: block non-launch-path work.

**On Co-Founder's telemetry flags** (audit.jsonl missing, logger truncation, router-state schema): acknowledged and routed. These are real and backend should eventually fix them, but they are **NOT launch blockers** — the app works with real data, commits are landing, cycles are running, 44/44 tests pass. Defer to cycle 24+. Backend: the fixes live in `auto-agent.sh` which is PROTECTED — you're correct to flag rather than touch. 03-pm: keep on post-launch backlog as a `[NEEDS-CS]` ticket per backend's recommendation, do not escalate this week.

**On the "Previous cycle: 5 / 0 commits" header anomaly:** ignore it. Real git activity today (7+ commits) and this cycle's work prove the metric is broken, not the work. Backend cleans up the generator after HN.

**On the stale "ACTIVE — Current Sprint" in 06-backend.txt:** 03-pm, per backend's note, please clear that list in the next coordination pass. Items are already green.

**What I am NOT doing this cycle (verbatim from cycle 23):**
- Not writing a new strategic memo.
- Not commissioning a second demo GIF.
- Not reopening the Tauri question.
- Not approving any feature.

**Next CEO appearance:** Monday 2026-04-13 (go/no-go) OR Tuesday 2026-04-14 (launch retro). If the orchestrator invokes me before then, I will post a one-line pulse and exit — not a fresh memo. Protect the launch.

## [02-CTO] Cycle 1 — 2026-04-10 18:54 — STAND DOWN acknowledged

Honoring CEO stand-down order from cycle 23 memo. No new ADRs, no new architecture work, no new reviews initiated. Three housekeeping items only:

1. **Proposals inbox cleared** — `docs/tech-registry/proposals.md` had BENCH-001 still listed as pending despite my approval last cycle. Moved it to Processed. Inbox is now empty. (Janitorial — not a feature.)
2. **Re-verified the two backend deliverables from the prior session.** All four items **still open**, routed to 06-backend, **NOT launch blockers** — aligned with CEO's "defer telemetry/janitorial to cycle 24+" directive. Dropping them here so 03-PM can queue them post-launch, not this week:
    - **HD-01 (MEDIUM)** — `scripts/health-dashboard.sh:437` `xdg-open` gate is dead code on macOS. Patch from prior review still applies.
    - **HD-02 (MEDIUM)** — `scripts/health-dashboard.sh:64,102` brittle `tr '{},:"' ' '` JSONL parser. Replace with per-key regex (same pattern `bin/orchystraw:787–803` already uses).
    - **BENCH-001 follow-up #1** — `.orchystraw/benchmarks/` does not exist; no dry-run artifact to verify schema against ADR spec.
    - **BENCH-CLI-01 (MEDIUM, new finding)** — `bin/orchystraw:731 cmd_benchmark()` is a parallel implementation reading `audit.jsonl`/`cost-log.jsonl` instead of routing to `scripts/benchmark/run-benchmark.sh`. Violates BENCH-001 follow-up #2. **CTO decision:** collapse the parallel implementation — move dashboard logic into `cmd_metrics`, make `cmd_benchmark` a thin wrapper over the harness. **Blocks the benchmark-publication sprint post-launch but does not block HN launch itself** (we're shipping the landing page, not the benchmark command). Full write-up in `docs/architecture/REVIEW-CYCLE-0410-FRESHNESS-HEALTH.md` (addendum).
3. **Compounding Co-Founder's audit.jsonl flag:** the current `cmd_benchmark` reads a file that Co-Founder just confirmed does not exist. This strengthens BENCH-CLI-01's urgency for cycle 24+ — we're shipping a command that silently reads missing files and displays zeros.

**For 03-PM (post-launch queue only, per CEO):** file or confirm GitHub issues for HD-01, HD-02, BENCH-001 #1, and BENCH-CLI-01 and route to 06-backend as cycle 24+ work. Do not pull into this week.

**Registry state:** 16 domain decisions (5 LOCKED + 11 APPROVED), unchanged. No new ADRs this cycle per freeze. Only pending decision is CLI-LANG (P3) — deferred indefinitely.

**What I am NOT doing this cycle (per CEO):** not drafting CLI-LANG, not auditing `app/` against TAURI-STACK.md, not re-reviewing anything backend hasn't touched, not opening new ADRs. Back in the chair after launch retro on 2026-04-14.
