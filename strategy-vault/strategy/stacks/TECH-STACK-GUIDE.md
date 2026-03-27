# Tech Stack Decision Guide — Indie App (2026)

> A reference for choosing and justifying your stack. Read before making tech decisions.
> Each section covers options, tradeoffs, and a recommendation with reasoning.

---

## Frontend

### Option A: iOS Native (Swift + SwiftUI)
**Best for:** iOS-only apps, apps using platform APIs (camera, voice, share sheet, health)

**Why SwiftUI:**
- Declarative UI — less code than UIKit
- Native performance
- Built-in dark mode, Dynamic Type, accessibility
- Future-proof (Apple's direction)
- iOS 16+ covers 95%+ of active devices (as of 2026)

**Key frameworks:**
- `Speech` — real-time voice recognition
- `Vision` — on-device OCR
- `AVFoundation` — audio/video capture
- `ShareExtension` — capture from any app
- `Combine` — reactive data flow

**Tradeoff:** Android requires separate effort (SwiftUI is iOS only).

---

### Option B: React Native (Expo)
**Best for:** Cross-platform (iOS + Android), JS-experienced teams

**Why:**
- One codebase for iOS + Android
- Large ecosystem
- Expo managed workflow reduces native config

**Tradeoff:** Bridge overhead, slightly less native feel, harder access to new iOS APIs.

---

### Option C: Next.js (Web App / PWA)
**Best for:** Web-first products, marketplaces, B2B SaaS

**Stack:** Next.js 15 (App Router) + React 19 + Tailwind CSS + shadcn/ui

**Tradeoff:** No App Store distribution, limited device APIs.

---

## Backend

### Option A: Node.js + TypeScript + Express/Hono (Recommended for most)
**Why:**
- Single language across stack (TypeScript everywhere)
- Rich ecosystem for third-party API integrations
- Fast for I/O-heavy work (webhooks, API aggregation)
- Express: mature, massive community
- Hono: modern, lighter, edge-compatible

**ORM:** Prisma (best DX, type-safe, schema-first)

---

### Option B: Python + FastAPI
**Why:**
- Best for AI/ML-heavy backends
- FastAPI: auto-docs, async, fast
- Pydantic for validation

**Tradeoff:** Slower for pure I/O ops; teams need Python fluency.

---

## Database

### PostgreSQL (Primary — always)
**Why:** Reliable, mature, full-text search built-in, JSON columns, great tooling.

| Hosting | Cost | Best For |
|---------|------|----------|
| Supabase | $0–25/mo | Auth + DB combo, easy setup |
| Railway | $5–20/mo | Simple deploys |
| AWS RDS | $50–200/mo | Production scale |

**ORM:** Prisma for Node.js, SQLAlchemy for Python.

---

### pgvector (Semantic Search — MVP)
**Use when:** You need vector/semantic search but want to keep the stack simple.
- Runs inside PostgreSQL (no extra service)
- Free, sufficient for 0–10K users (~1M vectors)
- Migrate to Pinecone/Qdrant at scale if needed

**Index type:** HNSW for best query performance.

---

### Redis (Cache + Queue)
**Use when:** You need rate limiting, search result caching, or background job queues.

| Hosting | Cost |
|---------|------|
| Upstash | $0.20/100K requests |
| Railway plugin | $5–20/mo |
| Redis Cloud | $5–50/mo |

**Job queues:** BullMQ (Node.js, built on Redis).

---

## AI / ML Services

### LLM: Anthropic Claude
| Model | Cost (input/output per 1M) | Best For |
|-------|---------------------------|----------|
| Claude 3.5 Sonnet | $3 / $15 | Summarization, complex reasoning, JSON output |
| Claude 3.5 Haiku | $1 / $5 | Internal tasks, high-volume simple ops |

**Why Claude over GPT:**
- Best instruction-following for structured JSON output
- 200K context window
- Superior at nuanced understanding

---

### Embeddings: Voyage AI
| Model | Cost per 1M tokens | Notes |
|-------|-------------------|-------|
| voyage-3 | $0.06 | Best quality, 1024-dim |
| voyage-3-lite | $0.02 | Cost-optimized, slightly lower quality |

**Why Voyage over OpenAI embeddings:**
- Best retrieval quality on MTEB benchmarks
- Recommended by Anthropic
- Free tier: first 200M tokens

---

### Transcription: AssemblyAI
**Cost:** $0.00025/sec ($0.015/min)
**Why over Whisper API ($0.006/min):** 2.5x cheaper, auto-punctuation, speaker diarization.
**Fallback:** Apple Speech on-device (free, good for <1 min clips).

---

### OCR: Apple Vision (On-Device)
**Cost:** Free
**Why:** Private, fast, no API call needed. Use Google Cloud Vision ($1.50/1K) as fallback only.

---

## Storage

### AWS S3 (Media Files)
**Cost:** $0.023/GB/month
**Use for:** Audio, video, images, PDFs

**Alternative:** Cloudflare R2 — same S3 API, cheaper egress (free).
**Alternative (simple):** Supabase Storage — integrated, generous free tier.

---

## Auth

| Option | Cost | Best For |
|--------|------|----------|
| Supabase Auth | Free (<50K MAU) | Email + social login, open-source |
| Clerk | Free (<10K MAU) | Best UX, embeddable components |
| Auth0 | $35+/mo | Enterprise features |
| Custom JWT | Free | Full control, more maintenance |

**Recommendation:** Supabase Auth for most apps (free tier generous, open-source).

---

## Hosting

| Platform | Cost (MVP) | Best For |
|----------|-----------|----------|
| Railway | $15/mo (backend + DB + Redis) | Simplest DX, fast deploys |
| Fly.io | Similar to Railway | Global edge, Postgres built-in |
| Vercel | Free–$20/mo | Next.js / serverless functions |
| AWS ECS + RDS | $120–450/mo | Production scale, fine-grained control |

**Recommendation:** Railway for MVP. Migrate to AWS at scale.

---

## CI/CD

**GitHub Actions** — free for public repos, $0.008/min for private.

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: railway up  # or fly deploy, etc.
```

---

## Monitoring

| Category | Tool | Cost |
|----------|------|------|
| Error tracking | Sentry | Free (5K errors/mo) |
| Analytics | PostHog | Free (1M events/mo) |
| Logging | Logtail / Axiom | Free tier |

---

## Development Tools

| Tool | Use |
|------|-----|
| VS Code | Backend + web |
| Xcode | iOS |
| Postman / Insomnia | API testing |
| TablePlus | Database GUI |
| GitHub | Version control |
| Linear | Issue tracking |
| Figma | UI design |

---

## Cost Model — Typical Indie App

### Year 1 (0–200 users)
| Service | Monthly |
|---------|---------|
| Railway (hosting) | $15 |
| AI APIs (Claude + Voyage) | $50–200 |
| Transcription (if applicable) | $20–50 |
| Storage (S3) | $5–20 |
| Error tracking | $0–26 |
| **Total** | **$90–311/mo** |

### Break-even: 30–100 Pro users at $10/mo

---

## Performance Targets

| Metric | Target |
|--------|--------|
| API response (search) | <300ms p95 |
| API response (create) | <200ms p95 |
| Client cold start | <2s |
| AI processing (background) | <5s |

---

*Updated March 2026. Revisit when planning v2 or scaling past 10K users.*
