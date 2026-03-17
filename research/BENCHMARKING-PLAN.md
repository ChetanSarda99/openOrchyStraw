# Benchmarking Plan — Orchystraw
**Last Updated:** March 16, 2026  
**Author:** CS + Chai

---

## Available Benchmarks

### Tier 1: Industry Standard (Must-Have for Credibility)

**SWE-bench Verified** — THE benchmark for AI coding agents
- 500 real GitHub issues from 12 Python repos (Django, Flask, scikit-learn, etc.)
- Task: Given an issue description → produce a patch that makes tests pass
- Docker-based evaluation harness — deterministic, reproducible
- Leaderboard at swebench.com — Claude, Devin, Codex all submit here
- **How to run:** `pip install swebench`, Docker required, ~2-4 hours for Lite (300 instances)
- **Orchystraw integration:** Write a scaffold that wraps Orchystraw's multi-agent cycle around each issue
- **What we'd prove:** Multi-agent (Orchystraw) vs single-agent (Ralph/raw Claude) on the same tasks
- **Cost estimate:** ~$50-100 for SWE-bench Lite with Sonnet, ~$200-400 with Opus

**SWE-bench Lite** — Smaller subset (300 instances), faster to run, still credible
- Same harness, same format, just fewer tasks
- Good for initial benchmarking before submitting to the full leaderboard

### Tier 2: Feature-Level (Better Fit for Orchystraw)

**FeatureBench** (Feb 2026, arxiv 2602.10975)
- 200 evaluation instances from 24 real GitHub repos
- Focus: Complex **feature development** spanning multiple files and modules
- Unlike SWE-bench (single bug fix), FeatureBench requires multi-file coordination
- **This is Orchystraw's home turf** — multi-file features are exactly where multi-agent shines
- Execution-based evaluation (tests must pass)
- Newer benchmark = less saturated leaderboard = easier to stand out

**SWE-bench Pro** (Scale AI)
- Longer-horizon tasks than standard SWE-bench
- More realistic — closer to actual development work
- Hosted by Scale Labs, separate leaderboard

### Tier 3: Additional Credibility

**Code Arena** (LMArena)
- ELO-based ranking from blind comparisons
- Users judge which agent produced better code
- Agentic behavior: planning, scaffolding, iteration
- Less deterministic but high visibility

**DevBench**
- Telemetry-driven benchmark, 1800 instances, 6 languages
- Good for breadth claims (not just Python)

---

## The Benchmark Strategy

### Phase 1: Internal Benchmarking (This Week)

**Goal:** Prove to ourselves (and for README claims) that Orchystraw multi-agent > single-agent Ralph loop on the same tasks.

**Setup:**
```
Test A: Ralph loop (single Claude Code agent, one task per loop)
Test B: Orchystraw (3 agents: backend, QA, PM — coordinated cycles)
Same tasks. Same model (Sonnet for cost). Same repo.
```

**Tasks (custom, not SWE-bench):**
1. Add a REST API endpoint + tests + docs to an existing Flask app
2. Refactor a module into 3 sub-modules without breaking tests
3. Add auth middleware + tests + update existing routes
4. Build a CLI tool from scratch with subcommands + tests
5. Fix 5 related bugs across multiple files simultaneously

**Metrics:**
- Resolve rate (did it work?)
- Cycles to completion
- Token cost (total API spend)
- Time to completion
- Code quality (tests pass, no rogue writes, clean git history)
- Regressions introduced (did fixing one thing break another?)

**Expected outcome:** Orchystraw should win on multi-file tasks (3, 5). Ralph should win on single-file tasks (4). This proves the "Ralph for small tasks, Orchystraw for coordination" positioning.

### Phase 2: SWE-bench Lite (Month 1)

**Goal:** Get a credible number on the industry-standard benchmark.

**How it works:**
1. Clone SWE-bench repo, install harness
2. Write an Orchystraw scaffold — a Python wrapper that:
   - Receives an issue description from SWE-bench
   - Sets up Orchystraw agents (backend agent reads codebase + issue, QA agent runs tests, PM coordinates)
   - Runs N cycles until tests pass or max iterations hit
   - Outputs the diff as a prediction
3. Run evaluation: `python -m swebench.harness.run_evaluation --predictions_path orchystraw_predictions.jsonl`
4. Compare against published baselines (raw Claude, SWE-agent, Agentless, etc.)

**The scaffold wrapper:**
```python
# orchystraw_scaffold.py (simplified)
def solve_issue(instance):
    # 1. Clone repo at the right commit
    # 2. Set up Orchystraw prompts from issue description
    # 3. Run auto-agent.sh for N cycles
    # 4. Capture git diff
    # 5. Return prediction in SWE-bench format
    return {
        "instance_id": instance["instance_id"],
        "model_name_or_path": "orchystraw-v1",
        "model_patch": git_diff
    }
```

**Cost estimate for SWE-bench Lite (300 instances):**
- 3 agents × 3 cycles average × 300 instances = 2,700 agent runs
- At Sonnet pricing (~$0.05/run): ~$135
- At Opus: ~$500-800
- **Start with Sonnet.** Opus only if results are promising.

### Phase 3: FeatureBench (Month 1-2)

**Goal:** Benchmark on multi-file feature tasks where Orchystraw SHOULD shine.

FeatureBench is newer (Feb 2026) and specifically tests feature-level development spanning multiple files — this is exactly Orchystraw's differentiation over single-agent systems.

If Orchystraw beats single-agent baselines on FeatureBench while performing similarly on SWE-bench, that's the perfect story: *"For bug fixes, any agent works. For features, you need a team."*

### Phase 4: Leaderboard Submission (Month 2-3)

**Goal:** Appear on swebench.com and FeatureBench leaderboards.

Requirements for SWE-bench submission:
- Open scaffold (code must be public)
- Reproducible results
- Standard prediction format (JSONL)
- Submit via their form at swebench.com/submit

---

## Orchystraw vs Ralph: Head-to-Head Benchmark Design

This is the most important benchmark for positioning.

### Setup
```
Environment: Same machine, same model, same repos
Agent A: Ralph loop (while :; do cat PROMPT.md | claude --print; done)
Agent B: Orchystraw (3 agents: coder, QA, PM — standard cycle)
Agent C: Orchystraw (5 agents: backend, frontend, QA, docs, PM)
```

### Task Categories

**Category 1: Single-file bug fixes (Ralph's strength)**
- Expect: Ralph wins (less overhead, faster)
- This proves we're honest about trade-offs

**Category 2: Multi-file feature development (Orchystraw's strength)**
- Add a feature spanning backend + frontend + tests + docs
- Expect: Orchystraw wins (specialization, parallel work)

**Category 3: Large codebase navigation (tie-breaker)**
- Fix a bug in a 500+ file repo where you need to find the right files first
- Expect: Orchystraw wins (QA agent reads while coder codes)

**Category 4: Continuous iteration (marathon test)**
- 20+ cycles on a real project
- Track: quality degradation over time, context drift, rogue writes
- Expect: Orchystraw wins (file ownership prevents drift)

### Metrics to Report
| Metric | What It Measures |
|--------|-----------------|
| Resolve rate | % of tasks completed successfully |
| Cycles to resolution | How many iterations needed |
| Total tokens consumed | Cost efficiency |
| Wall-clock time | Real-world speed |
| Regression rate | % of cycles that broke something |
| Rogue write rate | % of cycles with unauthorized file changes |
| Code quality score | Tests pass + lint clean + no dead code |

---

## Implementation Checklist

- [ ] Set up SWE-bench locally (Python 3.11 + Docker)
- [ ] Write the Orchystraw SWE-bench scaffold wrapper
- [ ] Run on 10 SWE-bench Lite instances as a pilot
- [ ] Design 10 custom multi-file tasks for Ralph vs Orchystraw head-to-head
- [ ] Run Ralph baseline on custom tasks
- [ ] Run Orchystraw on same custom tasks
- [ ] Compare results, write up findings
- [ ] If results are good: run full SWE-bench Lite (300 instances)
- [ ] If results are great: submit to SWE-bench leaderboard
- [ ] Run FeatureBench evaluation

---

## Expected Narrative

**Best case:** "Orchystraw resolves X% of SWE-bench Verified, competitive with single-agent systems on bug fixes, and outperforms them by Y% on multi-file feature tasks."

**Realistic case:** "On single tasks, Orchystraw performs similarly to a single Ralph loop (the overhead doesn't help for small tasks). On multi-file features, Orchystraw resolves 30-50% more tasks because specialization reduces context overload and file ownership prevents regressions."

**Worst case (still useful):** "Orchystraw's overhead doesn't help for SWE-bench-style bug fixes, but the file ownership and rogue detection prevent the quality degradation that single-agent loops show after 10+ cycles."

Any of these narratives is publishable and honest.
