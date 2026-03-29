# ADR REVIEW-001: Loop Review & Critique Phase

_Date: March 29, 2026_
_Status: APPROVED_
_Author: CTO_
_Implements: #40 (Loop Review & Critique)_
_Depends on: EXEC-001 (dependency groups must ship first)_

---

## Context

Agents run independently. No agent sees another's output until the next cycle via shared context. This means bugs, conflicts, and style violations go undetected for 1+ cycles, wasting tokens on rework.

## Decision

### 1. Review Phase in Cycle Flow

Insert an optional review step between commit and PM coordination:

```
Cycle flow (v0.2):
  1. Run eligible agents in parallel (by group)     — existing
  2. Commit agent work by ownership                  — existing
  3. NEW: Review phase — reviewers critique diffs
  4. PM coordination                                 — existing
  5. Merge to main                                   — existing
```

### 2. Review Configuration

8th column in agents.conf v2: `reviews` — comma-separated agent IDs to review.

```
09-qa  | ... | 3 | QA | 5 | 06-backend | 06-backend,08-pixel
02-cto | ... | 2 | CTO | 7 | none | 06-backend
```

Only agents that ran AND committed get reviewed. If 06-backend produced no commits, 09-qa's review of it is skipped.

### 3. Review Agent Input

Each reviewer receives:
- `git diff` of the reviewed agent's commit(s) this cycle
- The reviewed agent's prompt file (for task context)
- A structured review template

### 4. Review Output

Written to `prompts/<reviewer>/reviews/cycle-<N>-<reviewed-agent>.md`:

```markdown
# Review: 06-backend — Cycle 5
**Reviewer:** 09-qa
**Verdict:** request-changes | approve | comment

## Findings
- [BLOCKING] POST /api/notes missing input validation
- [SUGGESTION] Consider batch endpoint for performance

## Summary
One blocking issue found. Input validation must be added before merge.
```

### 5. Reviews Are Advisory (CRITICAL DECISION)

**Reviews never block the merge.** The PM reads review output and decides whether to:
- Flag the issue for next cycle
- Prioritize the fix in the next agent run
- Dismiss the finding

**Rationale:** Blocking reviews create a tight coupling that undermines the "crash and restart cleanly" principle. If a reviewer hallucinates or times out, it shouldn't stall the entire pipeline. The PM (human-supervised coordinator) is the right decision point.

### 6. Cost Guard

Reviews only execute when:
- API usage < 50% (from `check-usage.sh`)
- The reviewed agent actually produced commits this cycle
- The reviewer is eligible this cycle (interval check still applies)

### 7. Implementation

New module: `src/core/review-phase.sh`
- `orch_review_init` — parse review config from agents.conf column 8
- `orch_run_reviews` — for each reviewer, generate diff context, invoke agent with review prompt
- `orch_review_summary` — aggregate verdicts, write summary to shared context

**Phase 2 delivery:** Ships after EXEC-001 (dependency groups) is stable. Review phase depends on commits being grouped — reviewers must see complete group output, not partial diffs.

## Consequences

- **Positive:** Bugs caught same-cycle instead of next. QA/CTO feedback loop tightens from N cycles to 1.
- **Negative:** Review phase adds 1-3 minutes per cycle when active. Token cost increases ~20% on review cycles.
- **Risk:** Reviewer agent could produce low-quality reviews. Mitigated by: PM filters, structured output format, and reviews being advisory only.

## Constraints

- Reviews are **read-only** — reviewers write markdown, never modify code
- Review output goes in reviewer's own directory (respects file ownership)
- No new dependencies — review prompts are markdown templates
