# Claude Skills Audit — #79 Disposition

_Date: 2026-03-21 | Author: 06-backend_

Audit of 6 Claude Skills from `docs/CLAUDE-SKILLS-INTEGRATION.md` against existing OrchyStraw modules.

## Audit Results

| Skill | Priority | Disposition | Existing Module(s) | Gap |
|-------|----------|-------------|-------------------|-----|
| self-healing | HIGH | **SKIP — already built** | `src/core/self-healing.sh` | None |
| know-me | HIGH | **SKIP — already built** | `src/core/knowledge-base.sh` | None |
| cost-reducer | MEDIUM | **SKIP — already covered** | `model-budget.sh`, `token-budget.sh`, `usage-checker.sh` | None |
| scalability | MEDIUM | **SKIP — already covered** | `dynamic-router.sh`, `worktree-isolator.sh`, `session-windower.sh` | None |
| n8n | LOW | **SKIP — not applicable** | N/A | Orchestrator is bash, not a workflow platform |
| LinkedIn Director | LOW | **SKIP — pattern only** | `agent-as-tool.sh`, `task-decomposer.sh` | None |

## Detailed Analysis

### self-healing (HIGH) → SKIP

The skill describes autonomous error detection, recovery, and learning. OrchyStraw already has `src/core/self-healing.sh` (built cycle 5, #72) which provides:
- 7 failure classes: rate-limit, timeout, context-overflow, permission, crash, git-conflict, unknown
- Automatic remediation per class (e.g., wait for rate-limit, compress context for overflow)
- Retry budgets with configurable max retries and cooldown
- Full audit trail of all healing attempts
- Integration with the orchestrate loop via `orch_heal_diagnose()` / `orch_heal_apply()`

The skill's "skill-creation-guide" (meta-learning) is aspirational but not actionable for a bash orchestrator. If needed later, `knowledge-base.sh` already provides the persistence layer.

**Verdict:** Existing module exceeds skill scope. No new work needed.

### know-me (HIGH) → SKIP

The skill describes persistent memory and project context tracking. OrchyStraw already has `src/core/knowledge-base.sh` (built cycle 5, #76) which provides:
- Cross-project persistence at `~/.orchystraw/knowledge/`
- Domain-organized CRUD: store, retrieve, search, list, delete
- Merge-on-init for local + global knowledge
- Markdown export
- Input validation (domain/key regex guards)

Additionally, `session-windower.sh` (#36) handles session context compression, and `context-filter.sh` (#33) provides differential per-agent context — both are "know-me" adjacent.

**Verdict:** Existing modules fully cover this skill. No new work needed.

### cost-reducer (MEDIUM) → SKIP

The skill describes cloud/infra cost optimization. OrchyStraw's cost surface is AI model invocations, not cloud infrastructure. Existing coverage:
- `model-budget.sh` (#69) — per-agent invocation budgets, fallback chains
- `token-budget.sh` (#35) — per-agent token budgets with priority multipliers
- `usage-checker.sh` (#73) — real-time usage monitoring with graduated backoff
- `model-router.sh` (#30) — model tiering per agent (route cheap tasks to cheaper models)
- `conditional-activation.sh` (#32) — skip idle agents entirely

The skill's cloud patterns (AWS right-sizing, reserved instances) don't apply to a local bash orchestrator.

**Verdict:** Cost optimization is already deeply embedded in the engine. No new work needed.

### scalability (MEDIUM) → SKIP

The skill describes API/infra scaling patterns. OrchyStraw scales via parallel agent execution, not API endpoints. Existing coverage:
- `dynamic-router.sh` (#27) — dependency-aware parallel execution
- `worktree-isolator.sh` (#28) — git worktree isolation per agent
- `single-agent.sh` (#51) — skip multi-agent overhead when not needed
- `prompt-compression.sh` (#31) — tiered prompt loading to manage context window pressure

The skill's patterns (load balancers, database sharding, message queues) are for applications OrchyStraw builds, not for OrchyStraw itself. Agents already have access to these patterns through their model knowledge.

**Verdict:** Not applicable to orchestrator layer. No new work needed.

### n8n (LOW) → SKIP — Not Applicable

The skill provides n8n workflow automation API patterns. OrchyStraw is a bash orchestrator, not a workflow automation platform. n8n integration would add external dependency complexity with no clear value — agents can already be sequenced via `dynamic-router.sh` dependency graphs.

**Verdict:** Conflicts with zero-external-dependencies philosophy. Skip.

### LinkedIn Director Pipeline (LOW) → SKIP — Pattern Only

The skill demonstrates composable skill pipelines (A → B → Manager). OrchyStraw already implements this pattern:
- `agent-as-tool.sh` (#26) — lightweight read-only agent invocations (tool composition)
- `task-decomposer.sh` (#34) — progressive task decomposition (pipeline pattern)
- `review-phase.sh` (#24/#68) — loop review & critique (director pattern)

**Verdict:** Composable pipeline pattern already exists in the engine. No new work needed.

## Recommendation

**Close #79 as won't-do.** All 6 skills are either already implemented by existing modules or not applicable to the orchestrator's domain. The engine has 40 modules covering self-healing, knowledge persistence, cost optimization, scalability, and task composition — the exact capabilities these skills describe.

No SKILL.md files needed. No integration work needed.
