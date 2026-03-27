# Architecture Decision Log — [Your App]

> Track major technical and product decisions. Every decision captures context, alternatives, rationale, and consequences. Prevents "why did we do this?" questions later.

---

## How to Use This Log

1. Make a decision → write it down **immediately**
2. Include alternatives you rejected (and why) — future-you needs this
3. Mark status: `Decided` | `Proposed` | `Superseded`
4. Link related ADRs when decisions interact

---

## ADR-001: [Decision Title]
**Date:** YYYY-MM-DD
**Status:** Decided
**Decision:** [One sentence: what was chosen]

**Context:** [What problem were you solving? What constraints existed?]

**Alternatives Considered:**
- Option A — [brief pro/con]
- Option B — [brief pro/con]

**Rationale:** [Why did the chosen option win? Be specific.]

**Consequences:** [What does this trade off? What future decisions does this constrain?]

---

## Common Decision Categories

### Language & Framework
- iOS: SwiftUI vs React Native vs Flutter
- Backend: Node.js vs Python vs Go
- Web: Astro vs Next.js vs plain HTML

### Data Layer
- Primary DB: PostgreSQL vs SQLite vs MongoDB
- Vector search: pgvector vs Pinecone vs Weaviate
- Cache: Redis vs Memcached vs in-memory
- ORM: Prisma vs Drizzle vs raw SQL

### Auth
- Supabase Auth vs Auth0 vs Clerk vs custom JWT

### AI Services
- LLM: Claude vs GPT vs Gemini
- Embeddings: Voyage AI vs OpenAI vs Cohere
- Transcription: AssemblyAI vs Whisper vs Deepgram

### Infrastructure
- Hosting: Railway vs Fly.io vs EC2
- File storage: S3 vs Supabase Storage vs Cloudflare R2
- Queue: BullMQ vs SQS vs Inngest

### Payments / Monetization
- iOS subscriptions: RevenueCat vs native StoreKit
- Pricing: freemium vs trial vs paid-only

### Analytics
- PostHog vs Mixpanel vs Amplitude

---

## Decision Principles

When stuck, apply these tie-breakers (in order):

1. **Cheapest at MVP scale** — don't pay for 100K users when you have 100
2. **Best developer experience** — you'll interact with this daily
3. **Easiest to replace** — build behind an abstraction, switch later
4. **Recommended by the community you're in** — leverage others' battle scars

---

## Superseded Decisions

| ADR | Superseded By | Date | Reason |
|-----|--------------|------|--------|
| ADR-001 | ADR-007 | YYYY-MM-DD | [why we changed] |
