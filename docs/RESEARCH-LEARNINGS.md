# Research & Learnings — OrchyStraw Improvement Roadmap

_Last updated: March 17, 2026_

---

## Sources

1. **"3 Advanced AI Agent Design Patterns" — Google Cloud Tech** (YouTube, saved to Notion Mar 17, 2026)
   - Loop review & critique, coordinator/router, agent-as-tool patterns
   - Google ADK implementation examples

2. **cmux vs Conductor vs Windsurf comparison** (Mar 17, 2026)
   - cmux: macOS terminal multiplexer for parallel agent sessions (Ghostty-based)
   - Conductor: macOS GUI for isolated agent workspaces with diff viewer + PR flow
   - Windsurf: Full IDE with single-agent AI coding

3. **"I Tried Every AI Coding Agent... Here's My 2026 Setup"** (YouTube, saved to Notion Feb 10, 2026)
   - Branchlet CLI for git worktrees, parallel agents, plan-first workflow
   - claude.md per feature, Gemini 3 Pro for UI, no one-shotting

4. **Reddit r/ClaudeCode discussions** (Mar 2026)
   - Agent teams/orchestrators vs parallel sessions (cmux)
   - Multi-agent orchestration patterns and tooling

---

## Part 1: Smart Cycle System (Agent Execution Patterns)

### Current State
OrchyStraw runs agents in parallel per cycle, PM coordinates last. Workers have fixed intervals (every N cycles). No dynamic routing, no feedback loops, no conditional execution.

### Pattern 1: Loop Review & Critique (from Google ADK)

**What it is:** Generator agent creates output → Critique agent evaluates against conditions → Loop back with feedback until approved or max iterations reached.

**Why OrchyStraw needs it:** Currently QA runs once per cycle and writes findings to shared context. Fixes happen _next cycle_. This means:
- Minimum 1 full cycle delay for any QA finding to be fixed
- PM has to manually assign the fix
- The fix might introduce new issues, requiring yet another cycle

**Proposed implementation:**
- After QA runs, if it writes structured rejection (`REJECT: <agent-id> | <reason>`) to a new file `prompts/00-shared-context/qa-rejections.json`, auto-agent.sh re-runs the rejected agent with QA feedback appended
- Max 2 retries per agent per cycle (prevent infinite loops)
- Cost guard: only loop if usage.txt < 50% (save headroom for retries)

**Expected impact:** 1-2 fewer cycles needed per bug, ~30% faster convergence on quality.

### Pattern 2: Dynamic Routing / Coordinator Mode (from Google ADK)

**What it is:** A coordinator LLM analyzes the request and dynamically decides which sub-agents to activate, rather than running everyone every cycle.

**Why OrchyStraw needs it:** Currently every eligible agent runs every cycle (based on interval). If a commit only touched `backend/`, iOS, Design, and Web agents still run — wasting tokens reading context and saying "nothing to do."

**Proposed implementation:**
- Add `--smart` flag to auto-agent.sh
- PM runs first in a lightweight "routing" pass: reads git diff + shared context, outputs `run-list.json` specifying which agents to activate
- auto-agent.sh reads run-list instead of running all eligible agents
- Fallback: if PM doesn't produce a run-list, run all eligible (current behavior)

**Expected impact:** 40-60% token reduction on cycles where only 1-2 domains changed.

### Pattern 3: Agent-as-Tool (from Google ADK)

**What it is:** Primary agent treats sub-agents as stateless function calls — call, get result, retain control. Unlike coordinator where sub-agents take full control.

**Why OrchyStraw could use it:** PM currently can't invoke a quick check from another agent mid-cycle. For example, PM wants to verify a design token exists before assigning a frontend task — currently has to wait for the design agent's next cycle.

**Proposed implementation:**
- Add a lightweight `tool-call` mode: `./auto-agent.sh tool <agent-id> "<question>"`
- Agent runs with a minimal prompt (just the question + shared context), returns answer to stdout
- PM prompt can reference: "If unsure about X, run tool-call to agent Y"
- No git operations during tool calls (read-only)

**Expected impact:** Better PM decisions, fewer wasted tasks, tighter cross-agent coordination.

### Pattern 4: Parallel Execution with Dependency Awareness

**Current state:** auto-agent.sh already runs workers in parallel (v3).

**What's missing:** No dependency graph. If iOS agent depends on Backend agent's API output, running them in parallel means iOS might code against a non-existent endpoint.

**Proposed improvement:**
- Add `depends_on` column to agents.conf: `03-ios | ... | 02-backend | 1 | iOS Dev`
- Agents with dependencies wait for their dependency to finish
- Independent agents still run in parallel
- Topological sort determines execution order

### Pattern 5: Git Worktree Isolation (from Conductor)

**What it is:** Each agent gets its own git worktree — a full, isolated copy of the repo on a separate branch. No file ownership conflicts possible.

**Why it's better than file ownership:** Current rogue write detection is reactive (detect and discard). Worktrees prevent conflicts by construction. Each agent literally can't see other agents' changes until merge.

**Proposed implementation:**
- Before cycle: create worktree per agent (`git worktree add /tmp/orchy-agent-02 -b agent/02-backend`)
- Agent runs in its worktree directory
- After all agents finish: merge worktrees back to cycle branch
- Conflict resolution: PM reviews conflicts, or auto-prefer the agent who owns the file

**Trade-offs:** More disk I/O, more complex merge logic, but eliminates entire class of bugs.

---

## Part 2: Smart Agent Provisioning (Project Bootstrap)

### The Problem
When bootstrapping a new project (like my-other-app), someone has to manually decide: how many agents? What roles? What ownership? This is currently done by the bootstrap-prompt.txt template, which always creates the same 10 agents.

But a simple landing page doesn't need 10 agents. A complex full-stack app might need 12. The agent count should match the project.

### Proposed: Project Analyzer → Agent Blueprint

**Input:** Project description, tech stack, repo structure (if existing), complexity estimate
**Output:** Recommended agent team with roles, ownership, intervals, and rationale

**Scoring criteria:**
| Factor | Fewer Agents (3-5) | More Agents (8-12) |
|--------|--------------------|--------------------|
| Surfaces | 1 (API only, or landing page) | 3+ (iOS + Backend + Web + Hardware) |
| Languages | 1 | 3+ |
| External integrations | 0-2 | 5+ (Stripe, Supabase, NFC, RevenueCat, OpenAI) |
| Team size | Solo | 2+ humans |
| Estimated files | <50 | 200+ |
| Compliance/QA needs | Low | High (payments, auth, health data) |

**Agent archetypes:**

| Archetype | When to include | When to skip |
|-----------|----------------|--------------|
| PM | Always | Never skip |
| Backend | Any server-side code | Static site |
| Frontend/iOS/Android | Per client surface | API-only project |
| Design | UI-heavy apps | CLI tools, APIs |
| QA | Always (but interval varies) | Never skip |
| CEO | Products with market strategy | Internal tools |
| CTO | Multi-stack, architecture decisions | Single-stack simple app |
| Brand | Consumer-facing products | Internal tools, B2B |
| Web/Landing | Products needing marketing site | Internal tools |
| HR | 8+ agent teams | Small teams (overhead > value) |
| DevOps/Infra | K8s, multi-env deploys | Single Vercel/Supabase deploy |
| Docs | Developer-facing products, APIs | Consumer apps |
| Data/ML | ML models, data pipelines | Standard CRUD |

**Implementation:**
- `./scripts/auto-agent.sh init` — interactive project analyzer
- Asks 5-7 questions (or reads from a project spec file)
- Generates: agents.conf, prompt directory structure, CLAUDE.md skeleton
- Human reviews and adjusts before first cycle

**Minimum viable team (always):** PM + 1 Worker + QA = 3 agents
**Maximum recommended:** 12 agents (beyond this, PM can't coordinate effectively in one cycle)

---

## Part 3: Token Reduction Strategies

### Already Implemented
- **QMD (BM25 + vector search):** Agents search docs/code instead of reading entire files. Reduces context window usage significantly.
- **Shared context file:** ~100 tokens for inter-agent communication vs ~5000 for agent debates.
- **File ownership enforcement:** Prevents agents from reading/writing files outside their domain.

### Strategy 1: Prompt Compression — Tiered Context Loading

**Problem:** Every agent gets its full prompt (200-380 lines) every cycle, even if only the task section changed.

**Solution:** Split prompts into stable vs. dynamic layers:
- **Stable layer** (CLAUDE.md + ownership + standards): loaded once, cached in agent memory via `/compact` or project-level instructions
- **Dynamic layer** (tasks + shared context): injected fresh each cycle
- **Reference layer** (architecture docs, design tokens): loaded on-demand via QMD search

**Expected savings:** 40-60% prompt token reduction per agent per cycle.

### Strategy 2: Differential Context — Only What Changed

**Problem:** Shared context is reset and fully re-read each cycle. If Backend shipped 3 endpoints last cycle, every agent re-reads those same 3 endpoints even if irrelevant.

**Solution:** Tag shared context entries by relevance:
```markdown
## Backend Status [relevant-to: 03-frontend, 05-qa]
Added POST /api/tokens — returns { id, tag_uid, name }

## Design Status [relevant-to: 03-frontend]
Updated color tokens in ios/Styles/Colors.swift
```
auto-agent.sh filters context per agent, only injecting sections tagged as relevant.

**Expected savings:** 20-30% context reduction for agents in large teams.

### Strategy 3: Progressive Task Decomposition

**Problem:** PM writes detailed task descriptions (30-50 lines per task) for all tasks, but agents only complete 1-3 tasks per cycle. Remaining tasks are context overhead.

**Solution:** PM writes one-line summaries for backlog tasks, detailed specs only for THIS CYCLE's tasks:
```markdown
## YOUR TASKS

### Task 1: Add NFC tag registration endpoint — P0
[Full 20-line spec with acceptance criteria, file paths, schema...]

### Backlog (next cycles, DO NOT START)
- P1: Add streak calculation endpoint
- P1: Add body-doubling audio streaming
- P2: Add micro-stakes Stripe webhook
```

**Expected savings:** 15-25% prompt reduction for agents with deep backlogs.

### Strategy 4: Conditional Agent Activation (overlaps with Smart Routing)

**Problem:** Agents like CEO, Brand, HR run every 3 cycles regardless of whether they have work. They read full context, produce "no changes needed," and exit.

**Solution:** PM's routing pass determines if each leadership agent has actionable work. If not, skip entirely (don't even start the agent process).

**Expected savings:** 100% token savings for skipped agents (typically 2-4 agents per cycle).

### Strategy 5: Output Budgets

**Problem:** Some agents are verbose — QA writes 200-line reports, Design writes elaborate justifications. Tokens spent on output are as real as input tokens.

**Solution:** Add output guidance to prompts:
```markdown
## Output Budget
- Status update to shared context: MAX 10 lines
- Code changes: unlimited (this is the work)
- Explanations: MAX 3 sentences per decision
- DO NOT write essays justifying why you chose X over Y
```

**Expected savings:** 10-20% output token reduction, faster cycles.

### Strategy 6: Smart Session Tracker Windowing

**Problem:** SESSION_TRACKER grows indefinitely. Currently injecting "last 150 lines" — but as the project matures, 150 lines may cover only 2 recent cycles, losing historical context.

**Solution:** Smart windowing:
- Last 2 cycles: full detail
- Cycles 3-10: one-line summaries (auto-compressed by PM)
- Cycles 11+: milestone markers only
- Total injection: ~80 lines regardless of project age

**Expected savings:** Prevents context bloat as projects mature. Fixed ~80 line overhead vs. growing.

### Strategy 7: Model Tiering per Agent

**Problem:** All agents run on the same model (typically Opus 4.6). But QA review and HR team health reports don't need the same reasoning power as Backend architecture.

**Solution:** Add `model` column to agents.conf:
```
02-backend | ... | 1 | Backend Dev | opus
05-qa      | ... | 5 | QA Engineer | sonnet
06-ceo     | ... | 3 | CEO         | opus
10-hr      | ... | 3 | HR          | sonnet
```
auto-agent.sh passes model flag to Claude Code CLI per agent.

**Expected savings:** Sonnet is ~5x cheaper than Opus. Running 3-4 agents on Sonnet saves 40-60% cost.

### Strategy 8: Incremental File Indexing

**Problem:** When agents need to understand the codebase, they read files (expensive). QMD helps but requires manual `qmd embed` to update the index.

**Solution:** Auto-run `qmd embed --incremental` at the start of each cycle (only re-indexes changed files). Add to auto-agent.sh as a pre-cycle step.

**Expected savings:** Keeps QMD index fresh without manual intervention, agents find answers via search instead of file reads.

### Strategy 9: Prompt Template Inheritance

**Problem:** Every agent prompt repeats the same boilerplate: auto-cycle mode block, skills block, file ownership format. If these change, you update 10 prompts.

**Solution:** Extract common sections into shared template files:
```
prompts/00-shared-context/templates/
  auto-cycle-mode.md
  skills-block.md
  output-budget.md
```
auto-agent.sh assembles the full prompt by concatenating: template sections + agent-specific prompt.

**Expected savings:** Smaller individual prompt files, single-point updates, ~20% less prompt maintenance overhead.

---

## Summary: Priority Order

| # | Improvement | Impact | Effort | Token Savings |
|---|------------|--------|--------|---------------|
| 1 | Loop Review & Critique | High | Medium | Fewer wasted cycles |
| 2 | Dynamic Routing / Smart Mode | High | Medium | 40-60% per cycle |
| 3 | Model Tiering per Agent | High | Low | 40-60% cost |
| 4 | Prompt Compression (tiered loading) | High | Medium | 40-60% per prompt |
| 5 | Smart Agent Provisioning (init) | High | High | Right-sized teams |
| 6 | Conditional Agent Activation | Medium | Low | Skip idle agents |
| 7 | Progressive Task Decomposition | Medium | Low | 15-25% per prompt |
| 8 | Output Budgets | Medium | Low | 10-20% output |
| 9 | Git Worktree Isolation | Medium | High | Eliminates rogue writes |
| 10 | Differential Context | Medium | Medium | 20-30% context |
| 11 | Prompt Template Inheritance | Medium | Medium | Maintenance savings |
| 12 | Smart Session Tracker Windowing | Low | Low | Prevents future bloat |
| 13 | Incremental File Indexing | Low | Low | Fresher QMD index |
| 14 | Agent-as-Tool | Low | Medium | Better PM decisions |
