# Competitive Analysis Guide

> How to research your market and understand the competitive landscape before building.
> Use this framework for any new product. Output: a clear picture of where you fit.

---

## Step 1: Define Your Market

Before researching competitors, define the market you're entering:

```
Primary market: [e.g. "Note-taking apps"]
Sub-market: [e.g. "ADHD productivity tools"]
Adjacent market: [e.g. "Read-later apps"]

TAM (Total Addressable Market): [find industry reports or estimate]
SAM (Serviceable Addressable Market): [your realistic reach]
SOM (Serviceable Obtainable Market): [target for year 1-3]
```

**Finding market size data:**
- Statista, Grand View Research, MarketsandMarkets (paid, but snippets free)
- Crunchbase for VC investment trends
- App Store/Google Play charts for top apps in category

---

## Step 2: Identify Competitors

### Categories
- **Direct competitors:** Same problem, same solution type
- **Indirect competitors:** Same problem, different approach
- **Status quo:** What users do today without a dedicated tool

**Research methods:**
1. Google: `"[your problem]" app`, `best [category] tools 2026`
2. Product Hunt: search your category, filter by "new"
3. App Store: top charts in your category + "customers also bought"
4. Reddit: r/[your niche] — what do people recommend?
5. Alternatives.to: enter a known competitor, see related tools

**Aim to identify:** 5–10 direct competitors, 3–5 indirect.

---

## Step 3: Analyze Each Competitor

For each competitor, fill out this profile:

```markdown
### [Competitor Name]
**Website:** 
**Pricing:** 
**Estimated users:** 
**Founded:** 

**What they do:**
[2-3 sentence summary]

**Strengths (✅):**
- 

**Weaknesses (❌):**
- 

**Gap you can fill:**
[How your product addresses what they miss]

**Key insight:**
[One thing you learned from their approach]
```

---

## Step 4: Feature Matrix

Build a comparison table:

| Feature | Competitor A | Competitor B | Competitor C | Your App |
|---------|-------------|-------------|-------------|----------|
| Feature 1 | ✅ | ✅ | ❌ | ✅ |
| Feature 2 | ❌ | ✅ | ❌ | ✅ |
| Feature 3 | ✅ | ❌ | ✅ | ✅ |
| Pricing | $X/mo | $X/mo | Free | $X/mo |

**Focus on:** Features that your target users care most about. Skip vanity features.

---

## Step 5: Positioning Matrix

Plot competitors on 2 axes that matter to your audience:

```
         Simple ←————————→ Complex
    ^
    |   [Competitor A]     [Competitor C]
    |
Price
    |
    |   [Your App]         [Competitor B]
    ↓
```

Choose axes relevant to your space: price vs. features, simple vs. powerful, ADHD-friendly vs. general, etc.

**Goal:** Find a quadrant with high demand but low competition.

---

## Step 6: Pricing Analysis

| Competitor | Free Tier | Entry Paid | Power Tier |
|-----------|-----------|-----------|-----------|
| A | [details] | $X/mo | $X/mo |
| B | [details] | $X/mo | — |
| C | None | $X/mo | $X/mo |

**Insights:**
- Is there a pricing gap? (Too expensive for target audience?)
- What do Pro tiers include? (What's the upgrade trigger?)
- Are competitors mostly annual or monthly?

---

## Step 7: Synthesize

After research, answer:

1. **What does everyone do well?** (Table stakes — you must have this)
2. **What does nobody do well?** (Your opportunity)
3. **What's the #1 user complaint about existing tools?** (Check App Store reviews, Reddit, Twitter)
4. **What's your unique differentiator?** (One sentence)
5. **Who are you NOT for?** (Narrow the ICP)

---

## Step 8: Differentiation Statement

```
For [target user]
who [problem they have]
unlike [main competitor]
[Your App] [key differentiator].

Example:
"For ADHD creatives who lose track of ideas across 10 apps,
unlike Readwise which only handles articles,
[Your App] aggregates ALL saved content (social, messaging, voice)
in one searchable place."
```

---

## Research Sources

| Source | What You Learn |
|--------|---------------|
| G2.com / Capterra | User reviews, feature lists |
| App Store reviews (1–2 stars) | Real pain points |
| Reddit threads | Authentic user opinions |
| Product Hunt comments | Early adopter reactions |
| Twitter/X search | Ongoing sentiment |
| Competitor onboarding emails | Their conversion pitch |

---

## Red Flags

- **Crowded market with no differentiation:** Need a unique angle
- **No existing competitors:** Check if there's demand, not just absence of competition
- **Big Tech in the space:** Microsoft, Google, Apple — need a niche they can't/won't serve
- **Dying market:** Check Google Trends for search volume over time

---

*Do this research once before building. Revisit when planning v2 or when a new competitor appears.*
