# Token Efficiency & Model Configuration

_Date: March 17, 2026_

---

## Problem: Multi-Agent Debate is Expensive

3 agents debating = 3x token cost for marginal quality improvement.
Most decisions don't need a boardroom — they need a checklist.

### Cost Comparison

| Pattern | Input Tokens | Output Tokens | Opus Cost | Quality |
|---------|-------------|---------------|-----------|---------|
| 3-agent debate (pro/con/decide) | ~10K | ~6K | ~$0.23 | High but overkill for 90% of decisions |
| Self-critique (one agent, two passes) | ~5K | ~4K | ~$0.13 | 85% as good |
| Structured checklist (one pass) | ~2K | ~2K | ~$0.06 | Good enough for most decisions |
| Diff-only review (QA on changed lines) | ~1K | ~1K | ~$0.03 | Best for code review |

---

## Better Patterns (Ranked by Efficiency)

### 1. Structured Decision Matrix (CHEAPEST — one pass)

Instead of free-form debate, agent fills a forced template:

```markdown
## Decision: [topic]
**Options:** A, B, C
**Evaluation:**
| Criteria        | Option A | Option B | Option C |
|-----------------|----------|----------|----------|
| Complexity      | Low      | Medium   | High     |
| Maintenance     | High     | Low      | Medium   |
| Performance     | OK       | Good     | Best     |
| Team can ship   | Yes      | Yes      | No       |
**Decision:** B
**Reasoning:** [2 sentences]
**Reversible?** Yes — can swap later with [effort level]
```

Cost: One agent, one pass, ~2K tokens. Forces structured thinking without a second opinion.

### 2. Self-Critique (one agent, two passes)

Same agent generates solution, then critiques its own output:

```
Pass 1: "Build X using approach A"
Pass 2: "Now critique your own solution. What could go wrong? 
         What would you change? Score 1-10 on: correctness, 
         maintainability, performance."
```

Cost: 2x a single call, but no context duplication between agents.
Research shows self-critique catches 70-80% of what a separate reviewer would find.

### 3. Critique-on-Diff (QA reviews ONLY changed lines)

Don't send QA the whole codebase. Send ONLY the git diff:

```bash
# Instead of: "Review the entire project"
# Do: "Review this diff"
git diff --unified=3 | head -500 | send_to_qa
```

Cost: Tiny input, focused output. Best for code review.

### 4. Threshold-Based Escalation

Not every change needs review. Set thresholds:

```yaml
review_thresholds:
  auto_approve:           # No review needed
    - lines_changed < 20
    - files_changed == 1
    - no_new_dependencies
    - tests_pass
    
  self_critique:          # Agent reviews own work
    - lines_changed < 100
    - files_changed < 5
    
  qa_review:              # QA agent reviews diff
    - lines_changed < 500
    - new_dependency_added
    
  full_debate:            # Multi-agent only for BIG decisions
    - new_framework_choice
    - architecture_change
    - security_sensitive
    - lines_changed > 500
```

**90%+ of changes are auto-approve or self-critique.** 
Full debate happens maybe once per project, not once per cycle.

### 5. Batch Decisions (amortize overhead)

Instead of debating each micro-decision:

```
PM: "Here are 8 open questions from this cycle. 
     CTO: make all 8 decisions in one response."
```

One call handles 8 decisions instead of 8 separate debate rounds.
Cost: 1x call with ~4K input instead of 8x calls with ~2K each.

---

## Model Configuration

### The Insight

Different agents should use different models. 
A QA reviewer and a UI builder have different strengths:

| Role | Best Model Type | Why |
|------|----------------|-----|
| CTO / Architecture | Reasoning model (o3, Opus) | Complex tradeoffs, system design |
| QA / Code Review | Reasoning model (Codex, o3) | Spot bugs, logic errors, edge cases |
| Backend / Worker | Code model (Sonnet, GPT-4o) | Fast, good code gen, follows instructions |
| UI / Frontend | Multimodal (Gemini, Claude) | Visual understanding, CSS/layout intuition |
| PM / Planning | Writing model (Opus, GPT-4o) | Clear specs, good at structured output |
| CEO / Strategy | Reasoning + writing (Opus, o3) | Big picture, connects dots |

### Configuration Format

```yaml
# .orchystraw/models.yaml (or in project.db)

# Default model — used when agent has no specific model
default: anthropic/claude-sonnet-4-6

# Per-role model assignments
models:
  01-ceo:     anthropic/claude-opus-4-6      # Strategy needs depth
  02-cto:     openai/o3                       # Architecture reasoning
  03-pm:      anthropic/claude-sonnet-4-6     # Good enough for specs
  06-backend: anthropic/claude-sonnet-4-6     # Fast code gen
  08-pixel:   google/gemini-2.5-pro           # Visual/UI intuition
  09-qa:      openai/codex                    # Best at finding bugs
  11-web:     google/gemini-2.5-flash         # Fast, cheap, good at HTML/CSS

# Fallback chain — if preferred model unavailable or rate limited
fallbacks:
  openai/o3:                  anthropic/claude-opus-4-6
  openai/codex:               anthropic/claude-sonnet-4-6
  google/gemini-2.5-pro:      anthropic/claude-sonnet-4-6
  anthropic/claude-opus-4-6:  anthropic/claude-sonnet-4-6

# Budget controls
budget:
  max_per_cycle: $2.00        # Hard stop if cycle exceeds this
  max_per_agent: $0.50        # Per-agent cap
  max_daily: $20.00           # Daily budget across all cycles
  alert_at: 80%               # Notify founder at 80% of any limit
```

### The "Not Everyone Has All Models" Problem

OrchyStraw must work with JUST ONE model (free tier / API key for one provider).

```yaml
# Minimal config — one model does everything
default: anthropic/claude-sonnet-4-6
models: {}  # Empty = all agents use default
fallbacks: {}

# OR even simpler:
# User just sets ANTHROPIC_API_KEY and OrchyStraw handles the rest
```

### Model Tiers

```
Tier 1: FREE / SINGLE MODEL
  - One model for all agents
  - No review loop (self-critique only)
  - Works with any provider
  
Tier 2: MULTI-MODEL (power users)
  - Different models per role
  - Fallback chains
  - Budget controls
  - Review loops enabled
  
Tier 3: ENTERPRISE
  - Custom fine-tuned models per role
  - Self-hosted models (Ollama, vLLM)
  - Audit logging
  - Cost allocation per project
```

### API Key Detection

On first run, detect what's available:

```bash
orchystraw init
# Checking API keys...
# ✅ ANTHROPIC_API_KEY found
# ✅ OPENAI_API_KEY found  
# ❌ GOOGLE_API_KEY not found
#
# Recommended config for your keys:
#   CTO/QA → OpenAI o3 (reasoning)
#   Workers → Claude Sonnet (code gen)
#   UI → Claude Sonnet (Gemini unavailable, falling back)
#
# Estimated cost per cycle: $0.30-0.80
# Accept? [Y/n]
```

### How Agents Call Models

Agents don't pick their own model. The orchestrator sets it:

```bash
# In auto-agent.sh (current — bash)
run_agent() {
    local agent_id=$1
    local model=$(get_model_for_agent "$agent_id")  # Looks up models.yaml
    
    claude --model "$model" --print -p "$(cat $prompt_file)" 2>&1
}

# In orchystraw CLI (future — Python)
# orchystraw run --agent 06-backend
# Internally: reads models.yaml, sets model, runs agent
```

---

## Cost Projection

### Current (bash, single model, no gates)
- 10 cycles × 6 agents × ~$0.15/agent = **$9.00 per run**
- No quality gates → wasted cycles on bad output

### Optimized (multi-model, tiered review)
- 10 cycles × 6 agents:
  - 4 workers @ Sonnet ($0.05/agent) = $2.00
  - 1 CTO @ o3 ($0.20/cycle, batched decisions) = $2.00
  - 1 PM @ Sonnet ($0.05/cycle) = $0.50
  - QA: diff-only review @ Codex ($0.03/review × 4 workers) = $1.20
- **Total: ~$5.70 per run** (37% cheaper)
- Quality gates catch bad output early → fewer wasted cycles

### Budget Config Matters
Users need to set a budget. OrchyStraw should REFUSE to run if it would exceed the budget.
"Your 10-cycle run would cost ~$6. Budget is $5. Run 8 cycles instead? [Y/n]"

---

## Implementation Plan

### v0.1 (bash — now)
- [ ] Add model config to agents.conf (new column)
- [ ] Read model from config, pass to claude CLI
- [ ] Replace 3-agent debate with self-critique
- [ ] Add diff-only QA review

### v0.5 (Python CLI)
- [ ] models.yaml config file
- [ ] Fallback chains
- [ ] Budget controls (estimate before run, hard stop on exceed)
- [ ] API key detection on init
- [ ] Threshold-based escalation (auto-approve / self-critique / QA / debate)

### v1.0 (Tauri)
- [ ] Model picker in settings UI
- [ ] Cost dashboard (per agent, per cycle, per day)
- [ ] Recommended configs based on available keys
- [ ] Fine-tuned model support
