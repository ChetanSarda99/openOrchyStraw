# v0.2.0 Smart Cycle System — Design Document

_Date: March 18, 2026_
_Author: 06-Backend_
_Status: DRAFT — awaiting CTO review_

---

## Overview

v0.2.0 introduces three features that make the orchestrator cycle-aware and adaptive:

1. **#40 Loop Review & Critique** — Agents review each other's output before merge
2. **#41 Dynamic Routing** — Skip agents with no work, re-route blocked tasks
3. **#43 Dependency-Aware Parallel Execution** — Respect inter-agent dependencies

All three build on the existing cycle loop in `auto-agent.sh` without changing the core architecture (bash + markdown + agents.conf).

---

## Feature 1: Loop Review & Critique (#40)

### Problem

Agents run independently. No agent sees another's output until the next cycle (via shared context). Bugs, style violations, and conflicts between agents go undetected for 1+ cycles.

### Design

Add an optional **review phase** between agent execution and commit:

```
Cycle flow (v0.2):
  1. Run eligible agents in parallel     (existing)
  2. Commit agent work by ownership       (existing)
  3. NEW: Review phase — selected agents critique others' diffs
  4. PM coordination                      (existing)
  5. Merge to main                        (existing)
```

**Review config in agents.conf:**
```
# agent | prompt | ownership | interval | label | reviews
09-qa   | prompts/09-qa/09-qa.txt | prompts/09-qa/ | 3 | QA | 06-backend,08-pixel
02-cto  | prompts/02-cto/02-cto.txt | docs/architecture/ | 2 | CTO | 06-backend
```

New 6th column `reviews` — comma-separated agent IDs this agent reviews. Empty = no reviews.

**Review agent receives:**
- `git diff` of the reviewed agent's commit
- The reviewed agent's prompt (for context)
- A review template: approve / request-changes / comment

**Review output:** Written to `prompts/<reviewer>/reviews/cycle-<N>-<reviewed-agent>.md`

### Implementation

New module: `src/core/review-phase.sh`
- `orch_review_init` — parse review config from agents.conf
- `orch_run_reviews` — for each reviewer, generate diff + invoke claude with review prompt
- `orch_review_summary` — aggregate results, flag blocking issues

**Scope control:** Reviews are read-only. Reviewers cannot modify code — they write markdown critiques. The PM decides whether to act on critiques in the next cycle.

### Risks
- Review phase doubles cycle time when active
- Mitigation: Only run reviews when the reviewed agent produced commits

---

## Feature 2: Dynamic Routing (#41)

### Problem

Agents run on fixed intervals (e.g., QA every 3 cycles). But:
- An agent may have no work (no new code to QA)
- An agent may be blocked (waiting on CS or another agent)
- An agent that failed should retry sooner, not wait N cycles

### Design

Replace fixed intervals with **priority-based routing**:

```
agents.conf v2:
# agent | prompt | ownership | base_interval | label | priority | depends_on
06-backend | ... | src/core/ src/lib/ | 1 | Backend | 10 | none
09-qa      | ... | prompts/09-qa/ | 3 | QA | 5 | 06-backend
02-cto     | ... | docs/architecture/ | 2 | CTO | 7 | none
```

New columns:
- `priority` — base priority (higher = more important, runs first)
- `depends_on` — comma-separated agent IDs that must run first

**Routing logic (each cycle):**
1. Check each agent's `depends_on` — skip if dependency hasn't run this cycle
2. Check if agent has pending work (changes in owned paths, or forced by PM)
3. Apply interval modifiers:
   - Agent failed last cycle → divide interval by 2 (retry sooner)
   - Agent produced no changes for 3+ cycles → multiply interval by 2 (back off)
   - PM flagged agent as "priority" in shared context → run next cycle regardless
4. Sort eligible agents by priority, run in parallel (respecting dependency groups)

### Implementation

New module: `src/core/dynamic-router.sh`
- `orch_router_init` — load config, build dependency graph
- `orch_router_eligible` — return list of agents to run this cycle
- `orch_router_update` — adjust intervals based on cycle outcome (uses cycle-tracker.sh)

State file: `.orchystraw/router-state.json`
```json
{
  "06-backend": { "last_run": 5, "last_outcome": "success", "effective_interval": 1 },
  "09-qa": { "last_run": 3, "last_outcome": "success", "effective_interval": 3 }
}
```

### Risks
- Complexity: dynamic routing is harder to debug than fixed intervals
- Mitigation: `--dry-run` shows routing decisions; all decisions logged

---

## Feature 3: Dependency-Aware Parallel Execution (#43)

### Problem

Currently all eligible agents run simultaneously. But some agents depend on others:
- QA should run after Backend (needs code to test)
- Security should run after Backend (needs code to audit)
- CTO should run after all builders (needs output to review)

### Design

**Execution groups** derived from the dependency graph:

```
Group 0 (no dependencies): 01-ceo, 06-backend, 08-pixel, 11-web
Group 1 (depends on group 0): 02-cto, 09-qa, 10-security
Group 2 (depends on group 1): 03-pm (coordinator, always last)
```

Groups run sequentially. Agents within a group run in parallel.

**Dependency resolution:**
1. Parse `depends_on` column from agents.conf
2. Topological sort → assign group numbers
3. Cycle detection → error if circular dependencies found

### Implementation

Extend `src/core/dynamic-router.sh`:
- `orch_router_groups` — return execution groups as ordered arrays
- `orch_router_has_cycle` — detect circular dependencies at config-validate time

**Integration with auto-agent.sh:**
```bash
# Current (v0.1):
for id in "${AGENT_IDS[@]}"; do
    run_agent "$id" &
done
wait

# Proposed (v0.2):
groups=$(orch_router_groups)
for group in $groups; do
    IFS=',' read -ra agents <<< "$group"
    for id in "${agents[@]}"; do
        run_agent "$id" &
    done
    wait  # Wait for group to finish before starting next
    # Commit group's work before next group runs
    for id in "${agents[@]}"; do
        commit_by_ownership "$id"
    done
done
```

### Risks
- Groups add latency (sequential waits between groups)
- Mitigation: Most cycles only have 1-2 groups active; net time similar

---

## agents.conf v2 Format

```
# agent_id | prompt_path | ownership | base_interval | label | priority | depends_on | reviews
06-backend | prompts/06-backend/06-backend.txt | src/core/ src/lib/ scripts/ !scripts/auto-agent.sh | 1 | Backend | 10 | none | none
09-qa | prompts/09-qa/09-qa.txt | prompts/09-qa/ | 3 | QA | 5 | 06-backend | 06-backend,08-pixel
02-cto | prompts/02-cto/02-cto.txt | docs/architecture/ | 2 | CTO | 7 | none | 06-backend
03-pm | prompts/03-pm/03-pm.txt | prompts/ docs/ | 0 | PM (coordinator) | 0 | all | none
```

Backward compatible: if columns 6-8 are missing, defaults apply (priority=5, depends_on=none, reviews=none).

---

## New Modules Summary

| Module | File | Depends On | v0.2 Phase |
|--------|------|-----------|------------|
| signal-handler | `signal-handler.sh` | none | **BUILT** (cycle 5) |
| cycle-tracker | `cycle-tracker.sh` | none | **BUILT** (cycle 5) |
| review-phase | `review-phase.sh` | logger, config-validator | Phase 2 |
| dynamic-router | `dynamic-router.sh` | cycle-tracker, config-validator | Phase 1 |

**Phase 1 (after v0.1.0 ships):** dynamic-router + dependency groups
**Phase 2 (after phase 1 stable):** review phase

---

## Open Questions for CTO

1. Should dynamic routing state live in `.orchystraw/` (gitignored) or `prompts/00-shared-context/`?
2. Should review critiques block the merge, or only inform the PM?
3. Max agents per parallel group — should we cap at 4 to manage API costs?
