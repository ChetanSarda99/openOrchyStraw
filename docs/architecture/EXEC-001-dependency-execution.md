# ADR EXEC-001: Dependency Graph Execution & Dynamic Routing

_Date: March 29, 2026_
_Status: APPROVED_
_Author: CTO_
_Implements: #41 (Dynamic Routing), #43 (Dependency-Aware Parallel Execution)_
_Depends on: BASH-001, OWN-001_

---

## Context

v0.1 runs all eligible agents simultaneously with fixed intervals. This causes:
- QA running before Backend finishes (no code to test)
- Agents with no pending work still consume API tokens
- Failed agents wait their full interval before retry

## Decision

### 1. Dependency Groups (Topological Execution)

Agents declare dependencies via `depends_on` column in agents.conf. The orchestrator builds a DAG and executes in topological order:

```
Group 0 (no deps):    01-ceo, 06-backend, 08-pixel, 11-web
Group 1 (deps on 0):  02-cto, 09-qa, 10-security
Group 2 (deps on 1):  03-pm (coordinator, always last)
```

- Groups run **sequentially** (group 0 finishes → group 1 starts)
- Agents within a group run **in parallel**
- Each group's commits are applied before the next group starts
- PM remains hardcoded as final (group N+1), regardless of config

### 2. Dynamic Routing (Adaptive Intervals)

Replace fixed `CYCLE % interval == 0` with priority-weighted routing:

**Eligibility check per agent per cycle:**
1. Is `depends_on` satisfied? (dependency ran this cycle or has recent output)
2. Is `CYCLE % effective_interval == 0`?
3. Does agent have pending work? (changes in owned paths since last run)

**Interval modifiers (applied after each cycle):**
- Agent failed → `effective_interval = max(1, base_interval / 2)` — retry sooner
- Agent produced no changes for 3+ consecutive runs → `effective_interval = base_interval * 2` — back off
- PM flags agent as `priority` in shared context → force run next cycle
- On success → `effective_interval = base_interval` — reset to default

**Priority sort:** When multiple agents are eligible in the same group, higher priority agents are invoked first (matters for API rate limits, not execution order since they're parallel).

### 3. agents.conf v2 Format

```
# id | prompt | ownership | base_interval | label | priority | depends_on | reviews
06-backend | prompts/06-backend/06-backend.txt | src/core/ src/lib/ scripts/ !scripts/auto-agent.sh | 1 | Backend | 10 | none | none
09-qa | prompts/09-qa/09-qa.txt | prompts/09-qa/ | 3 | QA | 5 | 06-backend | 06-backend,08-pixel
```

**Backward compatible:** Missing columns 6-8 default to `priority=5, depends_on=none, reviews=none`.

### 4. State Management

Router state lives in `.orchystraw/router-state.json` (gitignored):

```json
{
  "06-backend": {
    "last_run_cycle": 5,
    "last_outcome": "success",
    "effective_interval": 1,
    "consecutive_empty": 0
  }
}
```

**Why `.orchystraw/` not shared context:** This is ephemeral per-machine state. Shared context is for inter-agent communication. Router state is orchestrator-internal — agents don't read it, only `dynamic-router.sh` does.

### 5. Implementation

New module: `src/core/dynamic-router.sh`
- `orch_router_init` — parse agents.conf, build DAG, validate (no cycles)
- `orch_router_groups` — return execution groups as pipe-delimited string
- `orch_router_eligible` — filter agents by interval + dependency + pending work
- `orch_router_update` — adjust effective intervals after cycle completes
- Uses: `cycle-tracker.sh` (empty detection), `config-validator.sh` (parse)

Integration point in `auto-agent.sh`:
```bash
# Replace flat loop with grouped execution
if type orch_router_groups &>/dev/null; then
    # v0.2 path: dependency-aware groups
    local groups
    groups=$(orch_router_groups)
    for group in $groups; do
        IFS=',' read -ra agents <<< "$group"
        for id in "${agents[@]}"; do
            run_agent "$id" &
        done
        wait
        for id in "${agents[@]}"; do
            commit_by_ownership "$id"
        done
    done
else
    # v0.1 fallback: flat parallel
    for id in "${AGENT_IDS[@]}"; do
        run_agent "$id" &
    done
    wait
fi
```

## Consequences

- **Positive:** QA always sees Backend's output. Failed agents recover faster. Idle agents waste fewer tokens.
- **Negative:** Groups add sequential waits. Debugging routing decisions requires `--dry-run` inspection.
- **Risk:** Cycle detection at config-validate time is critical — a circular `depends_on` would deadlock.

## Constraints

- No external dependencies. DAG sort is implemented in pure bash (arrays + loops).
- `.orchystraw/` must be in `.gitignore` (already is).
- `--dry-run` must show routing decisions before executing.

## Review

- Design doc: `src/core/SMART-CYCLE-DESIGN.md` (06-Backend, approved by CTO)
- Modules prereq: `signal-handler.sh` and `cycle-tracker.sh` already built and tested
