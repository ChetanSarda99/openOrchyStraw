# Architecture Decision Records (ADR) — [Your App]

> Track every significant technical or product decision here.
> Each ADR captures: what was decided, why, alternatives considered, and consequences.

---

## Template

```
## ADR-XXX: [Decision Title]
**Date:** YYYY-MM-DD
**Status:** Proposed | Decided | Superseded
**Decision:** [One sentence: what did you choose?]

**Context:** [Why did this decision need to be made?]

**Alternatives:**
- Option A (name) — pros/cons
- Option B (name) — pros/cons

**Rationale:**
- [Reason 1]
- [Reason 2]

**Consequences:**
- [What changes because of this?]
- [What risks does this introduce?]
```

---

## ADR-001: [Example: Frontend Framework]
**Date:** YYYY-MM-DD
**Status:** Decided
**Decision:** Build with [Framework], not [Alternative].

**Context:** [Your context here]

**Alternatives:**
- [Option A] — [brief assessment]
- [Option B] — [brief assessment]

**Rationale:**
- [Reason 1]
- [Reason 2]

**Consequences:**
- [Consequence 1]

---

## ADR-002: [Example: Database Choice]
**Date:** YYYY-MM-DD
**Status:** Decided
**Decision:** Use PostgreSQL as primary database.

**Context:** Need a reliable relational store for user data. Evaluating managed options.

**Alternatives:**
- MongoDB — flexible schema, but no joins/transactions for free
- MySQL — viable, less feature-rich than Postgres
- Supabase (hosted Postgres) — adds auth + storage on top

**Rationale:**
- ACID compliance, mature tooling, JSON support
- pgvector extension for semantic search (avoids separate vector DB at MVP)
- Supabase adds auth and storage without separate services

**Consequences:**
- Supabase dependency for hosted plan — can self-host if needed
- pgvector migration to Pinecone if vectors exceed 1M at scale

---

## ADR-003: [Example: Auth Approach]
**Date:** YYYY-MM-DD
**Status:** Decided
**Decision:** Use [Auth provider] for authentication.

**Context:** Need email/password + optional social login. Evaluating build vs. buy.

**Alternatives:**
- Custom JWT — full control, significant maintenance
- Auth0 — feature-rich, expensive at scale
- Firebase Auth — Google ecosystem, generous free tier
- Supabase Auth — open-source, free <50K MAU, good SDKs

**Rationale:**
- [Your reasons]

**Consequences:**
- [Your consequences]

---

## ADR-004: [Example: AI Provider]
**Date:** YYYY-MM-DD
**Status:** Decided
**Decision:** Use Anthropic Claude for LLM tasks.

**Context:** Need AI for [summarization / classification / generation]. Evaluating providers.

**Alternatives:**
- OpenAI GPT-4o — strong, expensive for high-volume
- OpenAI GPT-4o-mini — cheap, weaker instruction-following
- Claude 3.5 Sonnet — best structured output, 200K context
- Local models — free, require GPU infra

**Rationale:**
- Best instruction-following for structured JSON output
- Haiku available as cheap fallback for simple tasks
- 200K context window handles long documents in one shot

**Consequences:**
- Anthropic vendor dependency — abstract AI service layer to allow swap

---

## ADR-005: [Example: Hosting]
**Date:** YYYY-MM-DD
**Status:** Decided
**Decision:** Start on Railway; migrate to AWS at 10K+ users.

**Context:** Need affordable, low-ops hosting for MVP. Growth path needed.

**Alternatives:**
- Fly.io — similar pricing, global edge network
- Heroku — higher cost, slower deploys
- AWS ECS/RDS — production-grade, $120+/mo

**Rationale:**
- Railway: GitHub integration, Postgres + Redis included, $15/mo total
- Migrate to AWS when Railway limitations (scaling, multi-region) hit

**Consequences:**
- Possible migration work at scale — containerize early (Dockerfile)

---

## Decisions Log Summary

| ADR | Decision | Date | Status |
|-----|----------|------|--------|
| 001 | [Framework] | - | Decided |
| 002 | PostgreSQL | - | Decided |
| 003 | [Auth provider] | - | Decided |
| 004 | Anthropic Claude | - | Decided |
| 005 | Railway → AWS | - | Decided |

---

*Add new ADRs at the bottom. Never delete old ones — supersede them.*
