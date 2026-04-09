# Model Allocation — Agent-to-Model Mapping

## Current Allocation

| Agent | ID | Model Tier | Rationale |
|-------|----|-----------|-----------|
| Co-Founder | 00-cofounder | Opus | Operational reasoning, multi-factor decisions |
| CEO | 01-ceo | Opus | Strategic thinking, market analysis |
| CTO | 02-cto | Opus | Architecture decisions, complex technical judgment |
| PM Coordinator | 03-pm | Sonnet | Task routing, backlog management — structured work |
| Backend Developer | 06-backend | Opus | Multi-file code changes, system design |
| Pixel Agents | 08-pixel | Haiku | JSONL generation, narrow scope |
| QA Code Review | 09-qa-code | Sonnet | Code analysis, pattern matching |
| QA Visual Audit | 09-qa-visual | Sonnet | Screenshot comparison, layout checks |
| Security | 10-security | Sonnet | Audit checklists, scanning reports |
| Web Developer | 11-web | Sonnet | Component implementation, site updates |
| HR | 13-hr | Haiku | Team docs, low-complexity updates |

## Tier Definitions

### Opus (claude-opus-4-20250514)
- **Cost:** ~$15/M input, ~$75/M output tokens
- **Use for:** Complex reasoning, multi-file changes, architecture, strategy
- **Budget impact:** High — reserve for agents that need deep thinking

### Sonnet (claude-sonnet-4-20250514)
- **Cost:** ~$3/M input, ~$15/M output tokens
- **Use for:** Routine implementation, reviews, structured tasks
- **Budget impact:** Medium — good default for most agents

### Haiku (claude-haiku-4-5)
- **Cost:** ~$0.25/M input, ~$1.25/M output tokens
- **Use for:** Simple/repetitive tasks, narrow scope, high-frequency agents
- **Budget impact:** Low — use when quality ceiling is acceptable

### OpenAI Models
| Model | Cost/M | Use for |
|-------|--------|---------|
| gpt-4o | ~$2.50 | Alternative to Sonnet — good at structured output |
| o3 | ~$10 | Complex reasoning — alternative to Opus |
| o4-mini | ~$1.10 | Fast, cheap — alternative to Haiku |

### Google Gemini Models
| Model | Cost/M | Use for |
|-------|--------|---------|
| gemini-2.5-pro | ~$1.25 | Long context, research tasks |
| gemini-2.5-flash | ~$0.15 | Cheapest cloud option |

### Local LLMs (via Ollama / llama.cpp)
| Model | Cost | Use for |
|-------|------|---------|
| llama3.3 (8B) | $0 | Simple tasks, high-frequency agents, privacy |
| qwen3:32b | $0 | Medium complexity, local GPU required |
| Any GGUF | $0 | Custom models via llama.cpp server |

**Setup:** `ollama pull llama3.3` or point `ORCH_LOCAL_URL` to any OpenAI-compatible server.

## Reallocation History

| Date | Agent | From | To | Reason |
|------|-------|------|----|--------|
| 2026-04-07 | — | — | — | Initial allocation established |

## Budget Impact Estimation

Assuming ~50K tokens/agent/run average:

| Tier | Agents | Runs/Day (est) | Daily Cost (est) |
|------|--------|----------------|-----------------|
| Opus | 4 | ~8 | ~$36 |
| Sonnet | 5 | ~12 | ~$10.80 |
| Haiku | 2 | ~4 | ~$0.30 |
| **Total** | **11** | **~24** | **~$47.10** |

> Note: These are rough estimates. Actual cost depends on prompt size, output length,
> and how many cycles run per day. Monitor `.orchystraw/audit.jsonl` for real numbers.
