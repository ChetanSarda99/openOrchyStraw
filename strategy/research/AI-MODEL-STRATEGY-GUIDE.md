# AI Model Strategy Guide

> How to choose, route, and cost-optimize AI models for any app. Make these decisions once, write them down, don't revisit until something breaks.

---

## The Core Decision: Quality vs. Cost

Every AI call falls on a spectrum:

```
User sees it / time-sensitive  →  use the best model available
Background task / invisible    →  use the cheapest that works
```

Never default to "always use the best." Never default to "always use the cheapest." Route intentionally.

---

## Model Tiers (2026)

### LLMs

| Tier | Models | Use When |
|------|--------|---------|
| **Flagship** | Claude Sonnet, GPT-4o | User-visible output, complex reasoning, structured JSON |
| **Mid** | Claude Haiku, GPT-4o-mini | Background classification, simple extraction, internal tasks |
| **Local** | Llama 3, Phi-4 | Offline, high-volume, privacy-sensitive |

**Cost reference:**
- Claude Haiku: ~$0.80/$4 per 1M in/out tokens
- Claude Sonnet: ~$3/$15 per 1M in/out tokens
- GPT-4o-mini: ~$0.15/$0.60 per 1M in/out tokens
- GPT-4o: ~$2.50/$10 per 1M in/out tokens

### Embeddings

| Model | Cost | Dims | Use When |
|-------|------|------|---------|
| Voyage AI voyage-3 | $0.06/1M | 1024 | Best retrieval quality; MTEB benchmark leader |
| Voyage AI voyage-3-lite | $0.03/1M | 512 | High-volume, acceptable quality tradeoff |
| OpenAI text-embedding-3-small | $0.02/1M | 1536 | Already in OpenAI ecosystem |
| OpenAI text-embedding-3-large | $0.13/1M | 3072 | Need maximum quality |

**Default recommendation:** voyage-3 for retrieval-focused apps, voyage-3-lite for high-volume with cost pressure.

### Transcription

| Service | Cost | Quality | Use When |
|---------|------|---------|---------|
| AssemblyAI | $0.00025/sec | ★★★★ | Best cost/quality ratio; batch + streaming |
| Deepgram | $0.0043/min | ★★★★★ | Real-time streaming priority |
| OpenAI Whisper | $0.006/min | ★★★★ | Already in OpenAI ecosystem |
| Apple Speech | Free | ★★★ | On-device, <60 sec clips, privacy-first |

---

## Routing Framework

### Decision Tree for Each AI Call

```
Is output user-visible?
├── YES → Is it complex (reasoning, structured output)?
│         ├── YES → Flagship model
│         └── NO  → Mid-tier model
└── NO  → Background task?
          ├── Simple classification/extraction → Mid-tier
          └── High-volume (>1000/day/user)   → Cache or cheapest model
```

### Task → Model Mapping Template

| Task | Model | Justification |
|------|-------|-------------|
| Content summarization (user sees it) | Flagship LLM | Quality matters — user judges output |
| Auto-tagging (invisible) | Mid LLM | Don't need max quality for tags |
| Categorization (background) | Mid LLM | Simple classification |
| Semantic search embeddings | Voyage voyage-3 | Best retrieval quality |
| Voice transcription | AssemblyAI | Cost-effective, accurate |
| On-device short clips | Apple Speech | Free, private |
| Structured JSON extraction | Flagship LLM | Best instruction-following |
| Sentiment analysis | Mid LLM | Simple task |

---

## Cost Modeling

Before shipping any AI feature, model the cost:

```
Cost per user per month =
  Σ (calls_per_day × avg_tokens × price_per_1M / 1,000,000 × 30)
  for each AI call type
```

### Example Model

| Call Type | Calls/day | Avg tokens | Model | $/1M | Cost/user/mo |
|-----------|-----------|-----------|-------|------|-------------|
| Summarize new notes | 10 | 800 in + 150 out | Sonnet | $3/$15 | ~$0.07 |
| Auto-tag | 10 | 300 in + 50 out | Haiku | $0.80/$4 | ~$0.001 |
| Search query embed | 20 | 50 tokens | Voyage lite | $0.03 | ~$0.001 |

**Total: ~$0.07/user/month** → easily absorbed in $10/mo subscription.

### Cost Control Levers

1. **Cache aggressively** — Same input → same output. Cache summaries, embeddings, classifications.
2. **Route to cheaper models first** — Try Haiku; escalate to Sonnet only if output quality gates fail.
3. **Batch where possible** — Don't call the API for each note individually. Batch 10-50 at once.
4. **Set token limits** — Don't let the model write 2,000 tokens when 150 is enough. Hard-code `max_tokens`.
5. **Truncate large inputs** — Chunk or truncate inputs over context window (don't pay for tokens you don't need).

---

## Prompt Engineering Principles

### Structure for Reliability

```
System: [role + rules + output format]
User: [task + input]
```

Always specify output format explicitly — especially for JSON:

```
System: "Return ONLY valid JSON with these fields: { tags: string[], category: string, confidence: number }. No explanation."
```

### Reduce Token Waste

- Remove boilerplate from prompts — every token costs money
- Use short field names in JSON schemas
- For simple classifications, use logprobs or constrained decoding where supported

### Test Prompt Changes with Cost Accounting

Before changing a prompt used at scale: calculate the token delta × calls/day × users. A 100-token increase on a 10K-user app = meaningful monthly spend.

---

## Vendor Risk & Portability

Don't couple your app directly to any one AI provider. Abstract behind a service layer:

```typescript
// services/ai/index.ts
export async function summarize(text: string): Promise<string> {
  // Swap provider here without touching app code
  return await anthropicSummarize(text);  // or openaiSummarize(text)
}

export async function embed(text: string): Promise<number[]> {
  return await voyageEmbed(text);  // or openaiEmbed(text)
}
```

This lets you:
- Switch providers when pricing changes
- Run A/B tests between providers
- Fall back gracefully when one provider has an outage

---

## When to Upgrade / Downgrade

### Upgrade a model when:
- Users complain output quality is "off" or "generic"
- Structured output parsing fails consistently (model not following format)
- Complex reasoning tasks produce wrong answers >5% of the time

### Downgrade a model when:
- AI cost > 30% of subscription revenue per user
- Output quality difference is imperceptible to users
- Latency is acceptable at lower tier

### Switch embedding model when:
- Search recall benchmarks show >10% degradation vs. a competing model
- Pricing delta exceeds quality benefit (recalculate quarterly)

---

## Staying Current

AI model pricing and quality shifts fast. Review this quarterly:

1. Check MTEB leaderboard for embedding model updates
2. Check model provider pricing pages (prices drop over time)
3. Run internal quality evals on your actual use cases (not just benchmarks)
4. Read changelog / release notes from providers you use

**Set a calendar reminder: Quarterly AI model review.**
