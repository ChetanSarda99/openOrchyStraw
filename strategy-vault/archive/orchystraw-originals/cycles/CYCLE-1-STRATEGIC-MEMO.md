# Strategic Memo: Cycle 1 — Ship or Die
**Date:** 2026-03-18
**From:** CEO Agent
**To:** All agents, CS

---

## Situation

OrchyStraw has strong research, competitive positioning, and architecture — but zero shipped code after Cycle 0. The orchestrator script (`auto-agent.sh`) is the only artifact that runs. Every competitor we've analyzed (CrewAI, MetaGPT, Ralph) has working code in the wild. We don't.

**We are one bad week away from becoming another "great idea, never shipped" repo.**

---

## Strategic Directive: v0.1.0 Is the Only Priority

Everything else — Pixel Agents, Tauri app, benchmarks, landing page — is **frozen** until v0.1.0 ships. No exceptions.

### Why v0.1.0 First

1. **Credibility** — You can't benchmark vaporware. You can't build community around a README.
2. **Feedback loop** — Real users find real bugs. Architecture docs don't.
3. **CS's constraints** — Solo dev with ADHD needs visible progress. A tagged release is the biggest dopamine hit we can deliver.
4. **Market window** — AI orchestration is heating up. Every month we delay, someone else ships something that looks like us.

### What v0.1.0 Looks Like

A reliable orchestrator that:
- Handles agent crashes gracefully (#13)
- Traps signals properly (#14)
- Validates config before running (#19)
- Prevents concurrent runs (#20)
- Persists cycle state (#15)
- Has configurable timeouts (#16)
- Logs structured output (#18)
- Supports --dry-run (#17)
- Passes security audit (#22)
- Passes QA audit (#21)
- Gets a clean release tag (#25)

That's 11 issues. All backend. All well-scoped. This is a 2-3 cycle sprint, not a quarter.

---

## Strategic Decisions

### 1. Open-Source First, Proprietary Later

**Decision:** Ship v0.1.0 to the public openOrchyStraw repo immediately after tagging. Don't hold it back.

**Rationale:** The orchestrator is the hook. It's what makes people try OrchyStraw. Keeping it private gains us nothing — we have no users, no brand, no leverage. Ship it open, build community, then monetize the Tauri app and Pixel Agents visualization layer.

### 2. Benchmarking Moves to P1.5 (Not P4)

**Decision:** After v0.1.0 ships, the VERY NEXT thing is a benchmark run. Not Pixel Agents. Not Tauri.

**Rationale:** "Zero-dependency multi-agent orchestration" is a claim. Without numbers, it's marketing. One SWE-bench Lite run + one head-to-head vs Ralph = proof. That proof goes in the README and becomes our growth engine.

**Updated priority order:**
1. v0.1.0 hardening (P0 — current)
2. Benchmark proof (P1 — immediately after)
3. Pixel Agents integration (P1.5 — differentiator)
4. Tauri desktop app (P2 — paid product foundation)
5. Landing page + docs (P3 — distribution)

### 3. Community Strategy: README-Driven Development

**Decision:** The README is rewritten BEFORE v0.1.0 ships. Not after.

**Rationale:** When someone lands on the repo, they decide in 10 seconds whether to star or bounce. The README needs:
- One-line pitch (convention, not framework)
- 30-second quickstart (clone, run, see agents work)
- Architecture diagram (the PM-last loop)
- Comparison table (vs CrewAI, MetaGPT, Ralph)
- Demo GIF (table stakes — record during v0.1.0 QA)

### 4. Single-Agent Mode = Ralph Compatibility

**Decision:** v0.1.1 adds `--single-agent` mode that makes OrchyStraw act like a Ralph loop.

**Rationale:** This is our on-ramp. Ralph users (there are many) can switch to OrchyStraw with zero risk. When they're ready for multi-agent, they just add an `agents.conf`. No migration. This is how we steal Ralph's market.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CS loses momentum (ADHD) | Medium | Critical | Keep cycles short. Ship v0.1.0 in 2-3 cycles. Celebrate small wins. |
| Over-engineering the orchestrator | Medium | High | The 11 P0 issues are the FULL scope. No feature creep. |
| Competitor ships similar tool | Low | Medium | Our differentiator (convention, not framework) is hard to copy. |
| Benchmarks show poor results | Medium | High | Be honest. Show where multi-agent wins AND where single-agent is better. |

---

## Message to Each Agent

- **06-Backend:** You are the critical path. Ship the 11 P0 issues. Nothing else matters.
- **09-QA:** Prepare your audit checklist NOW so you're ready the moment backend ships.
- **10-Security:** Same — have your threat model and audit plan ready.
- **03-PM:** Track the 11 issues. Flag any that are blocked. Keep the cycle tight.
- **All others (01, 02, 04, 05, 07, 08, 11):** You are on standby. Read context, stay informed, but don't generate work that isn't on the critical path.

---

## Success Metric

**v0.1.0 tagged and pushed to openOrchyStraw by end of Cycle 3 (target: 2026-03-19).**

If we miss that, we reassess scope — not timeline.
