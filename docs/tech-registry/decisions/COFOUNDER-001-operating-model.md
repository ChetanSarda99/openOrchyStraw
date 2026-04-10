# ADR: COFOUNDER-001 — Co-Founder Agent Operating Model

_Date: 2026-04-10 (cycle 1)_
_Status: **APPROVED**_
_Author: CTO (02-cto)_
_Relates to: #183, OWN-001, EXEC-001_

---

## Context

The Co-Founder agent (`00-cofounder`) was introduced to serve as the
"autonomous operations layer" — adjusting agent intervals, model tiers, and
budget allocations without waking the Founder. It runs every 2nd cycle,
BEFORE the PM coordinator.

`docs/operations/COFOUNDER-PLAYBOOK.md` exists and has already recorded real
decisions. But it is a **playbook**, not an architectural contract. Several
issues surfaced that require a formal decision the other agents can rely on:

1. **Scope conflict.** Issue #247 proposed "Co-founder should create new
   agents on user request" — directly contradicts the existing playbook rule
   ("propose to Founder"). Without a decision, the Co-Founder has no stable
   authority boundary.
2. **Write-authority vs read-authority.** The Co-Founder currently owns
   `agents.conf` and `docs/operations/`. Editing `agents.conf` has side
   effects on EVERY cycle (routing, model selection, ownership). No other
   agent gets to mutate a file with that blast radius — we need the rules in
   one place.
3. **Telemetry requirements.** Playbook reference the 2026-04-10 entry:
   Co-Founder found `audit.jsonl` missing and cycle-tracker unreliable, so
   it correctly held status quo. This points to a missing invariant — the
   Co-Founder MUST have specific signals available or it MUST no-op.
4. **Relationship to PM.** The Co-Founder runs BEFORE the PM each cycle. PM
   then coordinates based on whatever the Co-Founder just changed. We need to
   document why that order matters.

## Decision

**The Co-Founder operates as a bounded autonomous executive, not a creator.**

### Authority boundaries

| Action | Authority | Rationale |
|--------|-----------|-----------|
| Adjust agent interval (within [1,10]) | **Autonomous** | Reversible, low blast radius, telemetry-driven |
| Adjust agent model tier (within budget) | **Autonomous** | Reversible, cost-bounded |
| Reorder PM backlog priorities | **Advisory only** | PM owns backlog; Co-Founder writes suggestions to shared context |
| Pause an agent (set interval=0 or comment out) | **Autonomous with escalation** | Must escalate via Telegram same cycle |
| Create a new agent | **FORBIDDEN** | Requires Founder approval. Propose only. |
| Delete an agent | **FORBIDDEN** | Requires Founder approval. Propose only. |
| Change an agent's ownership paths | **FORBIDDEN** | Ownership is a human-calibrated boundary (OWN-001) |
| Modify protected files | **FORBIDDEN** | Same as every other agent |
| Change the Co-Founder's own config | **FORBIDDEN** | Prevents runaway self-modification |
| Raise daily budget ceiling | **FORBIDDEN** | Requires Founder approval |
| Lower daily budget ceiling (emergency) | **Autonomous with escalation** | Safety brake |

**Resolving #247:** The Co-Founder MUST NOT create new agents, even on user
request. If the user asks for a new agent, the Co-Founder writes a
`NEW AGENT PROPOSAL` to shared context + Telegram escalation, and the
Founder approves. The user and the Founder are not the same actor for this
purpose — "user" in a cycle context is whichever human triggered the run,
which may not have Founder authority. This closes #247 as "proposal-only".

### Required telemetry inputs (no-op rule)

The Co-Founder MAY act on an agent only when **all** of these signals are
present and fresh (< 48h old):

1. `.orchystraw/audit.jsonl` exists and has entries for the agent
2. `.orchystraw/decisions.jsonl` exists (may be empty)
3. Cycle tracker and git log **agree** on commit counts (±1) for the last 7
   days. Disagreement → trust git, flag the tracker as unreliable, and no-op.
4. The agent has run at least 3 times since its last config change

If any input is missing or stale: **no-op + log reason**. The 2026-04-10
playbook entry ("status quo held; flagged tracker discrepancy") is the
reference implementation of this rule and should stand as canonical.

### Scheduling contract

- **Interval:** 2 (runs every second cycle)
- **Order:** BEFORE the PM coordinator in the same cycle
- **Reason for ordering:** PM's backlog and agent activation depend on
  `agents.conf` state. If Co-Founder runs AFTER PM, interval/model changes
  land in the NEXT cycle but PM coordinates on stale config in THIS cycle.
  Running before PM means PM sees the changes immediately and can
  reprioritize accordingly.
- **Exception:** If the previous cycle failed or produced zero commits
  across all agents, Co-Founder should no-op and let the failure surface
  cleanly. Do not mask orchestration bugs with config changes.

### Change velocity limit

- **Maximum 2 agents modified per cycle.** Hard limit from the playbook,
  promoted here because it prevents cascading miscalibration. If the
  Co-Founder believes more than 2 agents need changes, it must escalate.
- **Every change carries an inline comment** in `agents.conf`:
  `# adjusted by cofounder YYYY-MM-DD: <one-line reason>`. Auditability is
  the cost of autonomous write access.

### Escalation contract

The MUST-escalate list in the playbook is now load-bearing — these
escalations must not be suppressed, batched, or deferred:

| Trigger | Channel |
|---------|---------|
| Daily spend > budget ceiling | Telegram + shared context |
| Agent failing 3+ consecutive cycles | Telegram + shared context |
| Strategic pivot judgment call | Telegram |
| New agent / agent removal proposal | Telegram + shared context |
| Any P0 from 10-security | Telegram + shared context |
| User request that requires FORBIDDEN action | Telegram + shared context |

Escalation is not "advice to the Founder later" — it is a required side
effect of the Co-Founder's run when triggered.

### Relationship to PM

- **PM owns backlog ordering.** Co-Founder's priority suggestions go to
  shared context, not directly into PM-owned files.
- **Co-Founder owns operational config** (`agents.conf` intervals/models).
  PM must not edit intervals/models.
- **Disagreements:** If PM and Co-Founder disagree on priorities in the same
  cycle, PM wins on backlog ordering, Co-Founder wins on operational config.
  Escalate only if the disagreement is strategic (product direction).

## Consequences

**Positive:**
- Clear authority boundary closes #247 with a stable "no, propose instead"
  rule. Future user requests to create agents have a canonical answer.
- The no-op telemetry rule prevents the Co-Founder from acting on bad data,
  which is a real risk (cycle tracker has been unreliable before).
- Change velocity limit (2 agents/cycle) prevents cascading miscalibration.
- PM and Co-Founder have non-overlapping mutate-scopes, preventing write
  races on `agents.conf`.

**Negative:**
- The Co-Founder will frequently no-op when telemetry is incomplete. This
  is by design but may look like "idle cycles" to the Founder. Mitigation:
  the decision log entry must explain the no-op reason, not just note it.
- Bounded autonomy means some obviously-good changes will still require
  escalation if they hit FORBIDDEN. Acceptable cost — the blast radius of a
  wrong autonomous creation/deletion is much larger.

**Neutral:**
- This ADR canonicalizes what the playbook already describes. It does not
  expand Co-Founder authority; it formalizes existing boundaries so other
  agents can rely on them and so future changes are conscious.

## Follow-ups

1. **03-pm:** Close #247 with reference to this ADR. The proposal-only rule
   is the canonical answer.
2. **06-backend:** Investigate cycle-tracker vs git log discrepancy flagged
   on 2026-04-10. The no-op rule depends on this signal being trustworthy.
3. **00-cofounder:** Update `COFOUNDER-PLAYBOOK.md` to reference this ADR in
   its header. The playbook remains the operational guide; this ADR is the
   contract it implements.
4. **01-ceo:** Optional — decide whether Co-Founder should gain *proposal*
   authority over the OKR/strategy docs (currently CEO-owned). Not decided
   here; flagged for future.

## References

- `docs/operations/COFOUNDER-PLAYBOOK.md` — operational guide (playbook)
- `docs/tech-registry/decisions/OWN-001-file-ownership.md` — ownership model
- `docs/tech-registry/decisions/EXEC-001-dependency-execution.md` — cycle order
- Issue #183 — original Co-Founder proposal
- Issue #247 — "create agents on user request" (resolved as proposal-only)
- `prompts/00-shared-context/context.md` 2026-04-10 Co-Founder entry —
  canonical no-op reference
