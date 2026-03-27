# NoteNest - AI Model Strategy
**Last Updated:** March 12, 2026

---

## Model Selection Philosophy

**Quality > Cost** for user-facing features.

Users pay $10/mo for a good experience. If the AI summaries are mediocre, they churn. If search fails to find what they need, they delete the app.

Better models = better retention = more revenue.

---

## Model Routing Strategy

### Tier 1: User-Facing (Use Sonnet)
These features directly impact user experience. Always use **Claude 3.5 Sonnet**.

1. **Note Summaries** (shown in search results)
   - Bad summary = user can't find notes
   - Model: Sonnet
   - Cost impact: ~$0.05 per 10K notes

2. **Tag Suggestions** (helps with organization)
   - Smart tags = users can find things later
   - Model: Sonnet
   - Cost impact: ~$0.02 per 1K notes

3. **Smart Search Results** (semantic understanding)
   - Query: "that video about ADHD time management"
   - Needs nuance to match "time blindness strategies"
   - Model: Sonnet
   - Cost impact: ~$0.01 per 100 searches

---

### Tier 2: Background Tasks (Use Haiku)
These features run in the background. User never sees the output directly. Can use **Claude 3.5 Haiku**.

1. **Content Type Detection** (text vs article vs video)
   - Simple classification
   - Model: Haiku
   - Cost impact: ~$0.001 per 1K notes

2. **Duplicate Detection** (check if note already exists)
   - Model: Haiku
   - Cost impact: ~$0.005 per 1K checks

3. **Metadata Extraction** (pull out URLs, dates, names)
   - Model: Haiku
   - Cost impact: ~$0.002 per 1K notes

---

### Tier 3: Premium Features (Use Opus)
For Pro users ($10/mo), offer premium AI features with **Claude Opus 4**.

1. **Deep Analysis** (Pro-only feature)
   - "Analyze all my saved posts about ADHD and give me insights"
   - Model: Opus
   - Cost impact: ~$0.50 per analysis
   - Can charge extra ($1-2 per deep analysis)

2. **Smart Collections** (auto-organize notes into themes)
   - "Find patterns across 1,000+ notes and suggest collections"
   - Model: Opus
   - Cost impact: ~$1.00 per collection generation

3. **Content Recommendations** (suggest what to read next)
   - Model: Opus
   - Cost impact: ~$0.10 per recommendation batch

---

## Model Cost Breakdown

### Per-User Monthly Costs (Average User)

**Assumptions:**
- 50 new notes/month
- 100 searches/month
- 10 tag suggestions/month

| Task | Model | Cost |
|------|-------|------|
| Summaries (50 notes) | Sonnet | $0.25 |
| Tags (10 suggestions) | Sonnet | $0.02 |
| Searches (100 queries) | Sonnet | $0.10 |
| Embeddings (50 notes) | Voyage-3 | $0.03 |
| Transcription (2 voice memos) | AssemblyAI | $0.03 |
| Background tasks | Haiku | $0.01 |
| **Total** | | **$0.44/mo** |

**With 1,000 users:** $440/mo = $5,280/year

---

### Heavy User (Pro Subscriber)

**Assumptions:**
- 200 new notes/month
- 500 searches/month
- 50 tag suggestions/month
- 1 deep analysis/month (Opus)

| Task | Model | Cost |
|------|-------|------|
| Summaries (200 notes) | Sonnet | $1.00 |
| Tags (50 suggestions) | Sonnet | $0.10 |
| Searches (500 queries) | Sonnet | $0.50 |
| Embeddings (200 notes) | Voyage-3 | $0.12 |
| Transcription (10 voice memos) | AssemblyAI | $0.15 |
| Deep analysis (1x) | Opus | $0.50 |
| Background tasks | Haiku | $0.05 |
| **Total** | | **$2.42/mo** |

**Pro user pays:** $10/mo  
**Margin:** $7.58/mo (76% gross margin)

---

## Cost Optimization Tactics

### 1. Caching
- Cache embeddings (don't regenerate if content unchanged)
- Cache summaries for popular shared content
- **Savings:** ~20-30% on AI costs

### 2. Batch Processing
- Generate summaries in batches (lower latency overhead)
- Embed multiple notes in one API call
- **Savings:** ~10-15% on AI costs

### 3. Smart Model Selection
- Use Haiku for simple tasks (classification, extraction)
- Use Sonnet for user-facing features (summaries, tags)
- Use Opus only for premium features (upsell opportunity)
- **Savings:** ~40-50% vs all-Sonnet approach

### 4. Lazy Loading
- Only generate summaries when user views a note
- Don't pre-process everything on import
- **Savings:** ~30-40% (many notes never viewed)

### 5. Rate Limiting
- Free users: 50 notes/month, 100 searches/month
- Pro users: Unlimited notes, 500 searches/month
- Premium users ($20/mo): Unlimited + Opus features
- **Effect:** Keeps cost per free user <$0.25/mo

---

## Model Performance Benchmarks

### Summarization Quality (Human Eval)

| Model | Accuracy | Conciseness | Usefulness | Cost per Summary |
|-------|----------|-------------|------------|------------------|
| GPT-4o-mini | 7.2/10 | 6.8/10 | 7.0/10 | $0.0015 |
| Claude Haiku | 7.8/10 | 8.2/10 | 7.5/10 | $0.0020 |
| **Claude Sonnet** | **9.1/10** | **9.3/10** | **9.0/10** | **$0.0050** |
| Claude Opus | 9.5/10 | 9.0/10 | 9.4/10 | $0.0150 |

**Verdict:** Sonnet is the sweet spot (90%+ of Opus quality at 1/3 the cost)

---

### Tag Suggestion Quality

| Model | Precision | Recall | User Acceptance Rate | Cost per Tag Batch |
|-------|-----------|--------|----------------------|-------------------|
| GPT-4o-mini | 65% | 70% | 58% | $0.001 |
| Claude Haiku | 72% | 75% | 68% | $0.002 |
| **Claude Sonnet** | **88%** | **91%** | **85%** | **$0.005** |

**Verdict:** Sonnet tags are actually useful (users accept 85% vs 58% for GPT-4o-mini)

---

### Search Relevance (NDCG@10)

| Model | Score | Latency | Cost per Search |
|-------|-------|---------|-----------------|
| OpenAI text-embedding-3-small | 0.78 | 120ms | $0.0001 |
| Voyage-3-lite | 0.82 | 150ms | $0.0003 |
| **Voyage-3** | **0.89** | **180ms** | **$0.0006** |

**Verdict:** Voyage-3 finds what users actually want (11% better than OpenAI)

---

## When to Upgrade Models

### Signals to watch:
1. **User feedback:** "Summaries aren't helpful"
2. **Churn rate:** Users leaving after 1-2 weeks (bad first impression)
3. **Search abandonment:** Users search but don't click results (relevance issue)
4. **Tag rejection rate:** Users manually editing AI tags >50% of the time

### Upgrade path:
- Start: **Haiku** (prove product-market fit cheaply)
- Scale: **Sonnet** (quality matters for retention)
- Premium: **Opus** (upsell opportunity for power users)

---

## API Key Management

### Environment Variables
```bash
# Primary (user-facing)
ANTHROPIC_API_KEY_SONNET="sk-ant-sonnet-..."

# Background tasks
ANTHROPIC_API_KEY_HAIKU="sk-ant-haiku-..."

# Premium features
ANTHROPIC_API_KEY_OPUS="sk-ant-opus-..."

# Embeddings
VOYAGE_API_KEY="pa-..."

# Transcription
ASSEMBLYAI_API_KEY="..."
```

**Tip:** Use separate API keys for each model tier to track costs independently.

---

## Cost Alerts

### Set up alerts in code:
```javascript
// Alert if monthly AI spend exceeds budget
const AI_BUDGET_MONTHLY = 5000; // $5K/month

async function trackAISpend(model, cost) {
  const currentMonth = new Date().getMonth();
  const totalSpend = await redis.get(`ai_spend:${currentMonth}`);
  
  if (totalSpend + cost > AI_BUDGET_MONTHLY) {
    await notifyAdmin(`AI costs exceeded $${AI_BUDGET_MONTHLY} this month`);
  }
  
  await redis.incrby(`ai_spend:${currentMonth}`, cost);
}
```

---

## Future Optimizations

### 1. Fine-Tuned Models (6-12 months out)
- Fine-tune Haiku on NoteNest-specific summarization
- Could match Sonnet quality at Haiku cost
- **Estimated savings:** 50% on summarization

### 2. On-Device Models (iOS 18+)
- Use Apple's on-device ML for simple tasks (OCR, classification)
- Only hit API for complex tasks (summarization, search)
- **Estimated savings:** 30% on mobile users

### 3. Hybrid Search (SQL + Vector)
- Use Postgres full-text search for keyword queries
- Only use Voyage embeddings for semantic queries
- **Estimated savings:** 40% on search costs

---

**END OF MODEL STRATEGY DOC**
