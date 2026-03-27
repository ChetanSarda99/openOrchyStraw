# Why Orchystraw — Honest Competitive Analysis
**Last Updated:** March 16, 2026  
**Author:** CS + Chai

---

## The Two Main Comparisons

### gstack (Garry Tan, YC President)
https://github.com/garrytan/gstack

**What it actually is:** 10 Claude Code slash commands (markdown skill files) that give Claude different cognitive modes. `/plan-ceo-review`, `/review`, `/ship`, `/qa`, `/browse`, etc.

**The critical fact:** It is NOT a multi-agent system. It's **one agent, manually switching modes**. You run `/review`, Claude does a review. You run `/ship`, Claude ships. No automatic coordination between agents. No shared context. No PM writing back to workers. No cycles. For actual parallel sessions, it recommends Conductor (a paid third-party product) — gstack itself provides zero coordination between those sessions.

**Why it has distribution:** Garry Tan is the president of Y Combinator. 90% name, 10% product.

**One-line truth:** gstack = cognitive modes. Orchystraw = a company.

---

### MetaGPT
https://github.com/geekan/MetaGPT (50K+ stars)

**What it actually is:** A Python framework that generates a new software project from a one-line prompt. CEO → PM → Architect → Dev → QA as a pipeline. Run once, get output: user stories, competitive analysis, requirements, data structures, APIs, full codebase.

**The critical fact:** MetaGPT builds **from scratch**. You cannot point it at an existing 441-file project and say "keep building sprint 12." It generates. It doesn't iterate. It doesn't loop. There's no cycle system, no PM writing standing orders back to workers, no file ownership enforcement.

**Why it has 50K stars:**
- 2+ years old (released 2023)
- Academic research backing (ICLR 2025 papers)
- "Build a startup from one prompt" is extremely viral content
- Matthew Berman + major YouTubers covered it
- Massive Chinese developer community engagement
- Has a product (MGX) for non-developers

**One-line truth:** MetaGPT generates once. Orchystraw iterates continuously.

---

## Honest Differentiation Matrix

| Capability | MetaGPT | gstack | **Orchystraw** |
|-----------|---------|--------|---------------|
| Works on existing codebases | ❌ builds fresh only | ✅ | ✅ |
| Automatic multi-agent cycles | ✅ one-shot pipeline | ❌ manual | ✅ continuous loop |
| PM writes new orders back to workers | ❌ | ❌ | ✅ **only system doing this** |
| File ownership enforcement | ❌ | ❌ | ✅ |
| Rogue write detection + revert | ❌ | ❌ | ✅ |
| Zero dependencies | ❌ Python+node+pnpm+YAML config | ❌ Bun+compiled binary | ✅ bash only |
| Works with Windsurf, Cursor, Codex | ❌ Python framework only | ❌ Claude Code only | ✅ any CLI |
| Run 10+ cycles unattended | ❌ | ❌ | ✅ |
| Persistent iteration on same project | ❌ | ❌ | ✅ |

---

## The One Thing Nobody Else Does

**PM closes the loop.**

Every other system — MetaGPT, gstack, CrewAI, AutoGen — either runs a one-shot pipeline OR requires human coordination between agent runs.

Orchystraw's PM:
1. Runs LAST, after all workers finish
2. Reads shared context to see what everyone built
3. Writes NEW standing orders directly into each agent's prompt file
4. Next cycle: agents already know what to do — no human needed

This is the core insight that makes continuous, unattended multi-agent development possible. Nobody else has it in a zero-dependency form.

---

## Where Orchystraw Is Genuinely Weaker (Be Honest)

- **No greenfield capability** — MetaGPT is better for "build me X from scratch" from one prompt
- **No UI** — MetaGPT has MGX (mgx.dev, #1 Product Hunt), gstack integrates seamlessly into Claude Code's UI
- **Zero community right now** — MetaGPT has 50K stars, gstack has Garry Tan's name
- **PM quality = prompt quality** — The loop is only as good as the PM prompt you write. MetaGPT's roles are more sophisticated out of the box.

---

## Token Cost Strategy (Critical for Approach 3 / Agent Factory)

The cost problem: every agent, every cycle, reads a full context window. 5 agents × 10 cycles = 50 full context reads at Opus prices = expensive fast.

### Fix 1: Diff-Only Shared Context
Instead of each agent reading full `context.md`, they only get the **delta since last cycle** — what changed since their last run. PM writes `context-diff.md` alongside the full file. Workers read the diff. ~80% token reduction on context alone.

```bash
# PM writes at end of cycle:
git diff HEAD~1 -- prompts/00-shared-context/context.md > prompts/00-shared-context/context-diff.md
```

### Fix 2: Model Tiering
| Agent | Model | Reasoning |
|-------|-------|-----------|
| PM | Sonnet | Coordination and synthesis, doesn't need Opus |
| Backend/Frontend workers | Sonnet | Standard coding tasks |
| QA | Haiku | Read-only review, fast and cheap |
| CEO/Architecture decisions | Opus | Only for milestone decisions, not every cycle |

Cost drop: **5-10x** vs running Opus on everything.

### Fix 3: Lazy Agent Activation
Agent only runs if its owned directories changed since last cycle:
```bash
# In agents.conf, add ownership check
if git diff --quiet HEAD~1 -- backend/; then
  echo "02-backend: no changes in owned dirs, skipping"
  continue
fi
```
No changes → no tokens. Agents that have nothing new to do don't run.

### Fix 4: Prompt Compression
PM compresses standing orders before writing new ones:
- Completed tasks → 1-line summary bullet
- Drop anything older than 3 cycles
- Keeps prompt files from growing unbounded cycle after cycle

### Fix 5: Token Budget Per Agent
Pass max token limits to each worker (forces concision, agents write to shared context rather than verbose output):
```bash
claude --print --max-tokens 4000 "$(cat prompts/02-backend/02-be.txt)"
```

### Combined Effect
| Scenario | Cost Per Cycle | Notes |
|----------|---------------|-------|
| Naive (Opus, full context, all agents) | ~$2-3 | Baseline |
| With tiering + lazy activation | ~$0.50-0.80 | Model mix + skip idle agents |
| + Diff context + token budgets | ~$0.20-0.40 | Full optimization |

**10 cycles unattended = $2-4 total** instead of $20-30.

---

## The Star Count Question

Stars are a proxy for discoverability and viral content potential — not for whether the underlying system is better for a specific use case.

MetaGPT has 50K stars because "build a startup from one prompt" is inherently shareable. One tweet, one YouTube video, exponential spread. Orchystraw's "PM writes standing orders back to workers in a continuous loop" is more powerful but less tweetable.

**Orchystraw's distribution strategy should be:**
1. Show the *before/after* — project with 0 features → after 10 unattended cycles → actual working features committed. Let the git log speak.
2. The Pixel Agents integration (Approach 3) is what makes it visual and shareable. "Watch your AI team work" is tweetable.
3. Target Claude Code Discord + Windsurf community specifically — these are developers who feel the pain directly.

---

## Bottom Line

Orchystraw doesn't need to beat MetaGPT at its own game (greenfield generation). It solves a different problem for a different user:

**MetaGPT:** "I want to generate a new project from a prompt"  
**gstack:** "I want consistent cognitive modes for my Claude Code sessions"  
**Orchystraw:** "I have an existing project and I want multiple specialized agents iterating on it continuously, unattended, without installing anything"

The Leader quadrant is still empty. Ship it.
