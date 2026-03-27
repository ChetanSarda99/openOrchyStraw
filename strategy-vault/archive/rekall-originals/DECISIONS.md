# Architecture Decision Records — Memo

This document tracks major technical and product decisions for the Memo project. Each entry captures the decision, context, alternatives considered, and rationale.

---

## ADR-001: iOS Native (Swift + SwiftUI) over React Native
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Build the iOS app with Swift + SwiftUI, not React Native.

**Context:** CS is learning Swift. The app is iOS-only for MVP. React Native would allow cross-platform but adds complexity.

**Alternatives:**
- React Native + Expo (cross-platform, JS ecosystem)
- Flutter (cross-platform, Dart)

**Rationale:**
- Better native performance and feel (critical for ADHD UX — every ms matters)
- Access to iOS-specific APIs: Speech, Vision, ShareExtension, BackgroundTasks
- SwiftUI is the future of iOS development (Apple's direction)
- No need for Android at MVP stage
- React Native adds a bridge layer that complicates debugging

**Consequences:** Android support will require separate effort later (possibly React Native or KMM).

---

## ADR-002: Node.js + Express over Python + FastAPI
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Backend built with Node.js, Express, and TypeScript.

**Context:** Both options are viable. CS has some JS experience.

**Alternatives:**
- Python + FastAPI (great for ML/AI, async)
- Go (fast, typed, but steep learning curve)

**Rationale:**
- Rich ecosystem for API integrations (Telegram, Notion SDKs all have JS clients)
- TypeScript provides type safety
- Express is mature, well-documented, huge community
- Single language (TypeScript) for backend + shared types
- Easy deployment on Railway

**Consequences:** AI/ML-heavy features may need Python microservices later.

---

## ADR-003: PostgreSQL + pgvector for MVP (not Pinecone)
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Use PostgreSQL with pgvector extension for vector search in MVP, migrate to Pinecone if needed at scale.

**Context:** Vector search is core to Memo's semantic search. Pinecone is the managed leader but costs $70+/mo. pgvector is free and integrated with our existing PostgreSQL.

**Alternatives:**
- Pinecone (managed, scalable, expensive)
- Weaviate (self-hosted, complex)
- Qdrant (self-hosted, good performance)

**Rationale:**
- Zero additional cost (runs in same PostgreSQL instance)
- Simpler architecture (one fewer service to manage)
- Sufficient for 0-10K users (benchmarks show good perf up to ~1M vectors)
- Easy migration path to Pinecone later if needed

**Consequences:** May need to migrate to Pinecone at 10K+ users. Performance monitoring needed.

---

## ADR-004: Claude 3.5 Sonnet for AI features
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Use Anthropic Claude 3.5 Sonnet for summarization, tagging, and categorization.

**Context:** Need an LLM for note summarization, auto-tagging, and Wheel of Life categorization.

**Alternatives:**
- OpenAI GPT-4o-mini (cheaper but worse instruction-following)
- OpenAI GPT-4 Turbo (expensive, good quality)
- Local models (free but need GPU infrastructure)

**Rationale:**
- Best instruction-following for structured output (JSON schemas for categorization)
- 200K context window (can process entire articles in one shot)
- $3/$15 per 1M tokens (reasonable for MVP scale)
- Claude Haiku available as cost-optimized fallback for internal tasks
- Anthropic recommended by project research

**Consequences:** Vendor lock-in to Anthropic. Should abstract AI service layer for flexibility.

---

## ADR-005: Voyage AI for embeddings
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Use Voyage AI voyage-3 for text embeddings.

**Context:** Need vector embeddings for semantic search.

**Alternatives:**
- OpenAI text-embedding-3-small (cheaper, lower quality)
- Sentence Transformers (self-hosted, free but complex)
- Cohere embed-v3 (competitive quality)

**Rationale:**
- Best retrieval quality (beats OpenAI on MTEB benchmarks)
- Recommended by Anthropic for use with Claude
- 1024-dim vectors (good balance of quality vs. storage)
- voyage-3-lite available as cheaper option ($0.03/1M vs $0.06/1M)

**Consequences:** Cost scales linearly with note volume. Monitor and switch to lite if needed.

---

## ADR-006: Supabase Auth over Auth0 or custom JWT
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Use Supabase Auth for authentication.

**Context:** Need user auth with email/password + potential social login later.

**Alternatives:**
- Auth0 (managed, expensive at scale)
- Custom JWT (full control, more work)
- Firebase Auth (Google ecosystem)
- Clerk (modern, developer-friendly, expensive)

**Rationale:**
- Free tier generous (50K MAU)
- Open-source (no vendor lock-in)
- Supports email/password, magic link, social auth
- Good iOS SDK
- Can self-host if needed

**Consequences:** Adds a dependency. Alternative: start with custom JWT (already scaffolded in backend) and add Supabase later.

---

## ADR-007: Prisma as ORM
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Use Prisma for database access and migrations.

**Context:** Need an ORM for PostgreSQL access in the Node.js backend.

**Alternatives:**
- TypeORM (more flexible, less DX)
- Drizzle (newer, lightweight, SQL-like)
- Knex (query builder, not full ORM)

**Rationale:**
- Best developer experience (auto-completion, type safety)
- Schema-first approach fits well with planning phase
- Auto-generated migrations
- Prisma Studio for visual database inspection
- Already scaffolded in the project

**Consequences:** Prisma has known performance limitations at high scale. Acceptable for MVP through 10K users.

---

## ADR-008: AssemblyAI for transcription over Whisper
**Date:** 2026-03-13
**Status:** Decided
**Decision:** Use AssemblyAI for voice transcription.

**Context:** Voice capture is a core MVP feature.

**Alternatives:**
- OpenAI Whisper API ($0.006/min — 10x more expensive)
- Deepgram (faster, similar pricing)
- Apple Speech (on-device, free but lower quality for long-form)

**Rationale:**
- 2.5x cheaper than Whisper ($0.00025/sec vs $0.006/min)
- Auto punctuation and speaker diarization included
- Real-time streaming option available
- Good quality for diverse accents

**Consequences:** External dependency. Can fall back to Apple Speech for short clips (< 1 min).

---

## Decisions Finalized (2026-03-13, approved by CS)

- **P1 Vector DB:** pgvector for MVP (free, integrated) — migrate to Pinecone if needed at 10K+ users
- **P2 Auth:** Supabase Auth (free tier 50K MAU, open-source, good iOS SDK)
- **P3 iOS Minimum:** iOS 17+ (enables @Observable macro, SwiftData)
- **P4 State Management:** N/A (Swift native, no React)
- **P5 File Storage:** AWS S3 from day one ($20-50/mo, scalable)
