# CEO Update: Cycle 12 — Momentum Without a Tag

**Date:** 2026-03-29
**From:** CEO Agent
**To:** CS, All Agents

---

## Situation

The team is productive again. v0.2.0 Phase 1 shipped — dynamic-router.sh, 26 tests passing, CTO pre-approved. The CTO wrote four v0.2.0 ADRs. Web configured GitHub Pages deploy. The PM coordinated it all cleanly.

**But v0.1.0 is still not tagged.**

QA PASS and Security FULL PASS landed in commit `b1759bd`. All code blockers were cleared in `601c9a2`. The README exists. The `.gitignore` has secrets patterns. There is nothing left to do except run `git tag v0.1.0 && git push --tags`.

We are building v0.2.0 features on top of a release that hasn't been released. This is backwards.

---

## What Shipped Since Cycle 10

| What | Agent | Status |
|------|-------|--------|
| dynamic-router.sh (v0.2.0 Phase 1) | 06-Backend | SHIPPED, 26 tests |
| EXEC-001 ADR (dependency graph execution) | 02-CTO | APPROVED |
| REVIEW-001 ADR (loop review & critique) | 02-CTO | APPROVED |
| WORKTREE-001 ADR (git worktree isolation) | 02-CTO | APPROVED, deferred Phase 2+ |
| MODEL-001 ADR (model tiering per agent) | 02-CTO | APPROVED |
| GitHub Pages deploy workflow | 11-Web | CONFIGURED |
| agents.conf v2 format spec | 02-CTO | APPROVED |

The team is not idle anymore. That's the good news. The bad news: none of this reaches users without a tag.

---

## Decision: Tag v0.1.0 Now, Include Phase 1

Since v0.2.0 Phase 1 (dynamic-router.sh) shipped before the tag, we have a choice:

**Option A: Tag v0.1.0 as-is (only 601c9a2 fixes).** Clean scope, matches original plan. Phase 1 ships in v0.2.0.

**Option B: Tag v0.1.0 including Phase 1.** More features in the initial release — dynamic routing is a differentiator.

**I recommend Option A.** v0.1.0 was scoped as the "hardened orchestrator." Phase 1 is new functionality that hasn't had a full QA/Security review cycle yet. Ship what's validated. Phase 1 goes in v0.2.0 where it belongs.

---

## The Tag Is Now a Strategic Risk

It has been **11 days** since the "Ship or Shelf" memo. It has been multiple cycles since QA PASS + Security FULL PASS.

Every day without a tagged release:
- **Competitors ship.** Claude's own Agent SDK, Devin's improvements, new entrants — the window shrinks.
- **Benchmarks can't start.** SWE-bench evaluation needs a tagged baseline.
- **HN launch can't happen.** No tag → no benchmarks → no receipts → no launch.
- **Community can't form.** openOrchyStraw has no release for people to try.
- **Team momentum dissipates.** Building features nobody can use erodes purpose.

---

## Revised Post-Tag Sequence

1. **Tag v0.1.0** — Merge to main, tag, push to openOrchyStraw. BUG-013 (README "Bash 4+" → "Bash 5+") can be v0.1.1.
2. **v0.1.1 (same day)** — BUG-013 fix, BUG-012 (PROTECTED FILES in prompts), any nits.
3. **Benchmark sprint (days 1-3)** — SWE-bench Lite + Ralph comparison. Results in README.
4. **v0.2.0 Phase 2 (parallel with benchmarks)** — review-phase.sh (#40), model tiering (#46). CS integrates Phase 1 modules into auto-agent.sh.
5. **HN launch (after benchmarks)** — "Show HN" with benchmark receipts + demo GIF.
6. **Landing page deploy** — GitHub Pages workflow triggers on merge. Verify and iterate.
7. **Tauri desktop app** — After HN launch reception. Paid product foundation.

---

## Competitive Landscape Check

The multi-agent space as of late March 2026:
- **Claude Agent SDK** — Anthropic's official SDK. Different level (SDK vs orchestrator). We complement, not compete.
- **CrewAI** — Still Python-heavy, still requires framework buy-in.
- **AutoGen** — Microsoft-backed but complex setup. Enterprise focus.
- **Devin** — SaaS, not self-hosted. Different market.
- **Ralph loop** — Single-agent, no orchestration. Our `--single-agent` mode (v0.2.0) is the on-ramp.

Our differentiator is unchanged: **zero dependencies, works with any AI tool, markdown + bash.** But a differentiator that isn't released isn't a differentiator.

---

## Message to CS

The team has built past the release boundary. We're stacking v0.2.0 features on an untagged v0.1.0. The validation is done. The code is clean. BUG-013 is a one-word fix ("4+" → "5+") that can go in v0.1.1.

Tag it. Push it. Let the benchmarks begin.

---

*"You can't iterate on something users don't have."*
