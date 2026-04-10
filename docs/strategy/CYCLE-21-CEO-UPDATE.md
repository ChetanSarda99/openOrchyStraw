# CEO Update: Cycle 21 — The App Era. Fix the Bleeding, Then Launch.

**Date:** 2026-04-10
**From:** CEO Agent
**To:** CS, All Agents

---

## Where We Actually Are

My own prompt is 10 days stale. It still reads like we're stuck in a CTO-queue HARD PAUSE from March 31. That narrative is dead. Here's what actually happened while I wasn't looking:

- **v0.5.0 desktop app shipped.** Real data, real cycles, Start/Stop buttons wired, multi-project concurrent, detached processes.
- **4 app features landed in one commit** (#225/226/227/230): Pixel viz, agent chat, live logs, project wizard.
- **Critical regressions squashed**: `local` outside function (cycles crashing), macOS `grep -oP` incompatibilities, invisible cycle failures, pixel events shared across projects.
- **Production-readiness pass**: README, LICENSE, install.sh, contributing, .env.example.
- **`orchystraw update` self-updater** shipped.
- **Agent roster expanded to 12+** — cofounder added to all templates, agent-generator meta-template.

Memory snapshot (Apr 9): "Major build, 9 issues remaining, app works with real data." That matches reality. The pivot from "CLI + landing page + HN" to "desktop app is the product" already happened. I'm catching up.

**Strategic reality:** OrchyStraw is now an app-first product with a working orchestrator underneath. The open questions are no longer "can we ship?" — they're "is the app good enough not to embarrass us on launch day?"

---

## The Open Punch List (10 issues)

| # | What | P | Category |
|---|------|---|----------|
| #245 | Cycles launch and exit — don't actually run all agents | **P0** | Broken core loop |
| #239 | App browser crashes on first start | **P0** | First-impression killer |
| #242 | PixelAgents jump reading→finished, skip intermediate states | P1 | Visual fidelity |
| #250 | Full app audit + feature tracking | P1 | Quality gate |
| #249 | Agent flow visualization with colors + true Pixel integration | P1 | Polish |
| #248 | App: show GitHub issues, track what agents are working on | P2 | Feature |
| #235 | Research UI patterns (Perplexity Comet, Parallel Agents) | P2 | Research |
| #221 | Cross-platform portability (Linux, Intel Mac) | P2 | Reach |
| #191 | Record demo GIF | P2 | Launch prerequisite |
| #133 | Distribution launch posts | P3 | Launch |

## Strategic Call: Fix Before Feature

**#245 is a P0 and non-negotiable.** If our flagship cycle command doesn't actually run all the agents, every demo, every screencast, every benchmark lies. Nothing else matters until this is green.

**#239 is the second P0.** A browser crash on the first app start means 100% of new users bounce before they see anything. This is the #1 thing standing between OrchyStraw and the HN front page.

Everything else — pixel polish, UX research, flow viz, GitHub issue integration — is premature until the product doesn't crash and cycles actually complete.

### Priority Order (this week)

1. **#245** — Fix cycle-launches-and-exits. Diagnose, fix, verify with a real 3-agent cycle. Owner: 06-backend.
2. **#239** — Fix browser crash on first start. Owner: whoever owns `app/` (CS or 06-backend).
3. **#242** — Pixel state machine cycling. Owner: 08-pixel.
4. **#250** — Full app audit so we know what else is broken. Owner: 09-qa-code + 09-qa-visual (parallel).
5. **#235** — UX research pass — copy the best patterns from Perplexity Comet, Parallel Agents, similar tools before we design more. Owner: 11-web or 12-designer.
6. **#249** — Then the flow viz polish.
7. **#191** — Record demo GIF once #245 is actually green. This is the launch asset.
8. **#133 + HN launch** — When #245, #239, #242, #191 are all done. Not before.

### What Is NOT a Priority Right Now

- Benchmarks — SWE-bench comparison is still the proof we want, but not over a crashing app.
- Tauri desktop — the web app is the product; Tauri is a distribution story, not a capability story.
- New agent roles — the 12-agent team is the right size; don't grow the org chart while the product is leaking.
- More templates, more modules — `src/core/` has 33 modules. That's enough. The ceiling isn't orchestration capability anymore, it's app quality.

---

## Autonomous Decisions (No CS Approval Needed)

Per the co-founder model, I'm making these calls without waiting on CS:

1. **GREENLIGHT:** Backend to treat #245 as drop-everything, highest-priority work. Nothing else ships until cycles run all configured agents end-to-end.
2. **GREENLIGHT:** QA agents (both visual and code) to run in parallel on #250 audit. I want both angles.
3. **GREENLIGHT:** 11-web to do the #235 UX research pass — budget up to 30 minutes of an agent cycle on Perplexity Comet, Parallel Agents, and 2-3 peer tools. I want a short report with 5-8 concrete patterns we should steal.
4. **DEFER:** Tauri desktop app activation. Stays paused until web app is stable.
5. **DEFER:** #221 cross-platform. Won't matter if the product crashes on the platform we've tested. Revisit post-launch.

## Escalation to CS (Founder Decisions Needed)

- **Launch timing.** Once #245, #239, #191 land, do we HN-launch immediately or hold for a polish pass? I lean "ship after the bugs are fixed and the GIF is recorded" — but this is reversible, so call it when you want.

---

## Key Strategic Decisions (Running Log Update)

- **Cycle 21 (2026-04-10):** App-first is now the explicit product strategy. CLI remains the backbone, but the desktop web app is the front door. All launch prep pivots to app quality.
- **Cycle 21 (2026-04-10):** Fix-before-feature rule. No new features until #245 (broken cycle loop) and #239 (browser crash) are closed.
- **Cycle 21 (2026-04-10):** CEO prompt rewritten — the March 31 HARD PAUSE narrative was 10 days stale and actively misleading. Fresh priorities replace it.

---

## What Stays the Same

- OrchyStraw is still framework-free, zero-deps, multi-agent orchestration.
- Market position unchanged: only tool that works with any AI coding assistant, no vendor lock-in.
- Open-source-first. openOrchyStraw is still the hook.
- HN launch is still the target; it just needs a product that doesn't crash.

Let's stop shipping features and fix the two bugs that make our product look broken. Then we launch.

— CEO
