# ADR WORKTREE-001: Git Worktree Isolation per Agent

_Date: March 29, 2026_
_Status: APPROVED (design phase — implementation deferred to v0.2.0 Phase 2+)_
_Author: CTO_
_Implements: #44 (Git Worktree Isolation)_
_Depends on: EXEC-001 (execution groups)_

---

## Context

v0.1 runs all agents in the same working tree. File ownership boundaries are enforced by the rogue write detector (`detect_rogue_writes()`), which runs **after** agents finish. This is reactive — conflicts are caught, not prevented. The rogue detector also silently discards valid work if an agent accidentally touches a file outside its boundary.

## Decision

### 1. One Worktree per Agent

Before each agent runs, create an isolated git worktree:

```bash
git worktree add "/tmp/orchy-${CYCLE}-${agent_id}" -b "agent/${agent_id}/cycle-${CYCLE}"
```

Each agent operates in its own filesystem copy. No concurrent writes to the same files are possible by construction.

### 2. Lifecycle

```
Per group (from EXEC-001):
  1. Create worktrees for all agents in group
  2. Run agents in parallel (each in its own worktree)
  3. Wait for group completion
  4. Merge worktree branches back to cycle branch (sequential, per agent)
  5. Remove worktrees
```

### 3. Merge Strategy

After an agent completes in its worktree:
```bash
git merge --no-ff "agent/${agent_id}/cycle-${CYCLE}" \
    -m "feat(${agent_id}): cycle ${CYCLE} work"
```

**Conflict handling:**
- If merge conflicts occur, the rogue write detector logic applies: the agent that owns the conflicting path wins
- If neither agent owns the path → conflict is flagged, PM resolves next cycle
- `--no-ff` preserves per-agent commit attribution in history

### 4. What This Eliminates

| Problem | v0.1 (shared tree) | v0.2 (worktrees) |
|---------|-------------------|-------------------|
| Rogue writes | Detected after the fact, silently discarded | Impossible — agents can't see each other's changes |
| File ownership conflicts | Commit order determines winner | Merge resolution is explicit |
| Partial reads | Agent B reads Agent A's half-written file | Impossible — snapshot isolation |
| Rogue write detector | Required (complex, error-prone) | Optional (kept as safety net, rarely triggers) |

### 5. Performance Considerations

- **Disk:** Each worktree is a full checkout (~50MB for OrchyStraw). With 5 concurrent agents = ~250MB in `/tmp/`. Acceptable.
- **Time:** `git worktree add` is fast (~100ms for this repo). Not a bottleneck.
- **Cleanup:** Worktrees removed immediately after merge. Orphan cleanup on crash: `git worktree prune` at orchestrator startup.

### 6. Opt-in via Flag

```bash
./auto-agent.sh --worktree    # Use worktree isolation (v0.2)
./auto-agent.sh               # Shared tree (v0.1 default, backward compatible)
```

The `--worktree` flag sets `ORCH_WORKTREE=true`. When false, the existing shared-tree execution path runs unchanged.

### 7. Implementation

Extend `auto-agent.sh` (CS applies, CTO reviews):
- `create_agent_worktree()` — create worktree + branch
- `merge_agent_worktree()` — merge back + remove worktree
- `cleanup_worktrees()` — crash recovery (called at startup + SIGTERM)

No new module needed — worktree logic is tightly coupled to the orchestrator's git operations and belongs in `auto-agent.sh` directly.

### 8. Interaction with EXEC-001

Worktrees compose naturally with execution groups:
- Group 0 agents get worktrees → run in parallel → merge back
- Group 1 agents get worktrees (now seeing group 0's merged output) → run → merge
- This ensures dependency ordering is respected even with isolation

### 9. What the Rogue Write Detector Becomes

With worktrees, `detect_rogue_writes()` shifts from "enforce boundaries" to "audit boundaries":
- Still runs after merge (catches bugs in merge logic)
- Warnings instead of silent discards
- Can be disabled with `--no-rogue-check` for trusted runs

## Consequences

- **Positive:** Eliminates an entire class of concurrency bugs. Makes ownership enforcement structural instead of behavioral.
- **Negative:** More disk I/O, more complex merge logic, harder to debug when merge conflicts occur.
- **Risk:** Merge conflicts between agents in the same group. Mitigated by: ownership boundaries should prevent this; rogue detector catches edge cases.

## Constraints

- Requires git 2.15+ (worktree improvements). Already satisfied by any modern system.
- `/tmp/` must have sufficient space. OrchyStraw is small — not a practical concern.
- Agent prompts must not hardcode paths — worktree root differs from repo root. Agents already use `$PROJECT_ROOT` which will be set to the worktree path.

## Deferred

Implementation deferred to v0.2.0 Phase 2 or later. EXEC-001 (dependency groups) and REVIEW-001 (review phase) ship first because they deliver value without the complexity of worktree management. Worktrees are an optimization — the rogue detector works well enough for v0.2.0 Phase 1.
