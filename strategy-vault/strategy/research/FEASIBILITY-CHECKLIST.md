# Feasibility Checklist — Before You Build

> Run through this before committing to a product idea.
> Goal: surface hidden costs, blockers, and risks early.

---

## 1. Technical Feasibility

### AI / ML Costs (if applicable)
Calculate cost at scale before writing a line of code:

| Service | Unit | Cost | At 100 users | At 1,000 users |
|---------|------|------|-------------|----------------|
| LLM API | per 1K tokens | | | |
| Embeddings | per 1K tokens | | | |
| Transcription | per minute | | | |
| Storage | per GB/mo | | | |
| **Total** | per user/mo | | | |

**Key question:** At what user count does AI cost exceed revenue per user?

**Cost optimization levers:**
- Prompt caching (Anthropic: 90% discount on cached input)
- Batch API (Anthropic: 50% discount for async tasks)
- Cheaper model for simple tasks (Haiku vs Sonnet)
- On-device models (free, private — iOS Vision, Speech)

---

### API Integrations
For each external API you plan to use:

| API | Rate Limit | Free Tier | Paid Cost | OAuth Required? | Restrictions |
|-----|-----------|-----------|-----------|----------------|-------------|
| [API 1] | | | | | |
| [API 2] | | | | | |
| [API 3] | | | | | |

**Red flags:**
- No public API (must scrape — ToS risk)
- Rate limits that throttle core features
- OAuth scope limitations (e.g. Instagram doesn't expose saved posts)
- Paid tier required before you can launch

---

### Platform Constraints
- [ ] Does the platform (iOS App Store, Chrome Extension, etc.) allow what you need?
- [ ] Any review guideline risks? (App Store is strict on certain categories)
- [ ] Background execution limitations? (iOS: 30 sec background limit)
- [ ] Required hardware? (e.g. Mac for iOS development, GPU for local models)

---

## 2. Market Feasibility

### Demand Signals
Before building, validate demand:

- [ ] Reddit: Do people ask for this? Do threads get traction?
- [ ] Twitter/X: Are people complaining about the problem?
- [ ] Product Hunt: Has anything similar launched? What reception?
- [ ] Google Trends: Is search volume stable, growing, or declining?
- [ ] App Store: Are similar apps getting reviews? What are users asking for?

**Minimum signal:** 3+ independent sources of people expressing the problem.

---

### ICP (Ideal Customer Profile)
```
Who has this problem most acutely?
- Demographics: [age, profession, situation]
- Pain intensity: [1-10 — will they pay to solve it?]
- Current workaround: [what do they do today?]
- Willingness to pay: [$/mo they'd consider]
- Where to find them: [subreddits, communities, newsletters]
```

---

### Competition
- [ ] Identify 3–5 direct competitors
- [ ] Is there a clear gap they don't fill?
- [ ] Can you outcompete on price, niche, or UX?
- [ ] Is there a "killer competitor" (Google, Apple, Notion) entering this space?

---

## 3. Business Feasibility

### Unit Economics

| Metric | Target |
|--------|--------|
| Monthly price (Pro) | $X/mo |
| Cost per user/mo (infra + AI) | $X/mo |
| Gross margin | ≥70% |
| Break-even (# users) | [revenue / margin] |

**Rule of thumb:** If cost per user >30% of revenue, the margin is tight.

---

### Conversion Path
```
Awareness → Landing page → Signup → Free tier → Paid conversion

Target funnel:
- Landing page conversion: 15–30%
- Free → Paid: 3–10%
- Churn: <5%/mo
```

---

### Growth Channel
- [ ] What's your primary acquisition channel? (SEO, Twitter, communities, ads)
- [ ] Is it sustainable and controllable?
- [ ] Do you have access to the channel? (Community trust, audience, or budget)

---

## 4. Founder Feasibility

### Skill Gaps
| Skill Required | Your Level | Gap Closing Plan |
|----------------|-----------|-----------------|
| [Frontend stack] | | |
| [Backend stack] | | |
| [Marketing] | | |

### Time Commitment
- Hours/week available: ___
- At this pace, MVP ready in: ___ months
- Will you still be motivated in 6 months? ___

### Solo vs. Co-founder
- Going solo: full control, slower build, no equity split
- Co-founder: faster, but finding a good fit is hard
- Freelancer: specific tasks, paid cost

---

## 5. Go / No-Go

| Check | Status |
|-------|--------|
| Technical: can it be built within budget? | ✅ / ❌ |
| Market: clear ICP with real pain | ✅ / ❌ |
| Business: path to $1K MRR in 12 months | ✅ / ❌ |
| Founder: skills + time + motivation | ✅ / ❌ |

**Decision rule:** 4/4 → Build. 3/4 → Address the gap. 2/4 or less → Reconsider.

---

*This checklist surfaces expensive surprises early. Do it in a day, not a week.*
