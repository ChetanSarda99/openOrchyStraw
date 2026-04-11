# Co-Founder Operating Playbook

## Purpose

This document defines the Co-Founder agent's operating procedures, escalation rules,
and serves as the running decision log.

---

## Operating Cadence

The Co-Founder runs every 2nd cycle, BEFORE the PM coordinator.
Each run follows four phases: Assess → Decide → Document → Verify.

### Pre-Run Checklist
- [ ] Read shared context for current cycle state
- [ ] Check agent health report output
- [ ] Review cost data from audit.jsonl
- [ ] Scan PM backlog for misaligned priorities

### Post-Run Checklist
- [ ] All decisions written to shared context
- [ ] agents.conf changes validated (bash -n safe, comments added)
- [ ] Escalations sent if thresholds breached
- [ ] Decision log updated below

---

## Escalation Rules

### MUST Escalate (Telegram to Founder)
| Trigger | Threshold | Message Template |
|---------|-----------|-----------------|
| Daily spend | > $50/day | `BUDGET BREACH: $X today, limit $50` |
| Agent failure | 3+ consecutive failures | `AGENT FAILING: {id} — {error summary}` |
| Strategic pivot needed | Judgment call | `STRATEGY Q: {question}` |
| New agent proposal | Always | `NEW AGENT PROPOSAL: {role} — {justification}` |
| Security critical | Any P0 from 10-security | `SECURITY: {finding summary}` |

### NEVER Escalate
- Routine interval adjustments
- Model tier changes within budget
- Backlog reordering suggestions
- Agent health warnings (handle autonomously)

---

## Interval Tuning Guide

### Signals That an Agent Needs Higher Interval (slower)
1. Zero commits across 3+ scheduled runs
2. Empty streak > 3 in router state
3. Cost per run is 2x+ the team average with no output
4. Agent's owned files haven't changed in 5+ cycles

### Signals That an Agent Needs Lower Interval (faster)
1. Commits per run > 2x expected (highly productive)
2. Other agents are blocked waiting for this agent's output
3. Critical-path work is assigned to this agent
4. Backlog items in this agent's domain are piling up

### Guardrails
- Never set interval below 1 (except coordinator at 0)
- Never set interval above 10
- Never change more than 2 agents per cycle (stability)
- Always add an inline comment: `# adjusted by cofounder YYYY-MM-DD: reason`

---

## Model Allocation Guide

See `docs/operations/MODEL-ALLOCATION.md` for current assignments.

### Reallocation Triggers
- Agent consistently produces low-quality output → try upgrading model
- Agent produces simple/routine output → safe to downgrade
- Budget pressure → downgrade non-critical agents first
- New complex task assigned → temporarily upgrade

---

## Decision Log

Format: `YYYY-MM-DD | action | rationale | outcome`

<!-- Append decisions below this line -->
| Date | Action | Rationale | Outcome |
|------|--------|-----------|---------|
| 2026-04-07 | Initial setup | Co-Founder agent created (issue #183) | Baseline established |
| 2026-04-10 | No interval/model changes | All 12 agents within healthy interval bands; no 3+ consecutive failures attributable to agent logic; git log confirms active shipping. Held changes to avoid chasing a noisy "prev cycle 0 commits" signal that conflicts with actual commit activity. | Stable config preserved |
| 2026-04-10 | Flagged telemetry gaps to backend | (1) `.orchystraw/audit.jsonl` missing — cannot verify per-agent cost, so budget gate is blind. (2) `logs/cycle-{1,2}.log` today end right after `Router initialized with 12 agents` — no per-agent run lines captured. (3) `router-state.txt` marks every worker status=`fail` despite successful commits landing — exit-code/telemetry mismatch likely. | Written to shared context for 06-backend |
| 2026-04-10 | Founder directive audit: clean | `gh issue list` returns 0 open issues; `99-me/99-actions.txt` P0/P1 items all have either closed issues or are Founder-only manual tasks. No untracked directives. | No flags raised |
