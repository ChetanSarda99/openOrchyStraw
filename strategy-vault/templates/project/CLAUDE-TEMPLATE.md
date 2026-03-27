# CLAUDE.md — [Your Project] Instructions

**Read this first. Follow it exactly. This overrides Claude's defaults.**

---

## Project Overview

**[Your App]** — [One sentence description: what it is and who it's for].

**Repo:** [github.com/owner/repo] (private/public)
**Owner:** [Name] — [role: solo developer / team lead]
**Timeline:** [X months to MVP, started Month Year]

---

## Tech Stack

### [Frontend Platform — e.g. iOS App]
- **[Framework]** (iOS 17+, SwiftUI / React Native / Next.js)
- **[State management]** (@Observable / Zustand / Redux)
- **[Local persistence]** (SwiftData / AsyncStorage / localStorage)
- **[Auth client]** (Supabase Swift SDK / Clerk / custom)
- **[Navigation]** (NavigationStack / React Navigation)

### Backend
- **[Runtime]** (Node.js + TypeScript / Python + FastAPI)
- **[Framework]** (Express / Hono / FastAPI)
- **[ORM]** (Prisma / SQLAlchemy / Drizzle)
- **[Database]** (PostgreSQL / Supabase)
- **[Cache/Queue]** (Redis + BullMQ)
- **[File storage]** (AWS S3 / Supabase Storage)
- **[Hosting]** (Railway / Fly.io / Vercel)

### AI / ML (if applicable)
- **LLM:** Anthropic Claude 3.5 Sonnet — summarization, tagging
- **Embeddings:** Voyage AI — semantic search
- **Transcription:** AssemblyAI / Apple Speech

---

## Working Style — FOLLOW STRICTLY

### [Owner] Prefers
- **Action over questions** — Just do it, don't ask for permission
- **Concise responses** — No fluff, no trailing summaries
- **Working code** — Not pseudocode, not TODO comments
- **Complete solutions** — Don't leave half-finished work
- **Production quality** — This ships to real users

### Anti-Slop Rules (CRITICAL)
- **NO** generic placeholder copy ("Lorem ipsum", "Your title here")
- **NO** half-built components with TODOs for the "real" logic
- **NO** asking to confirm before doing obvious things
- **NO** summarizing what you just did at the end
- **NO** excessive error handling for things that can't fail

---

## Code Style

### TypeScript
- Strict mode (`"strict": true` in tsconfig)
- Explicit types everywhere — no `any`
- Zod validation on all API inputs
- Consistent naming: `camelCase` variables, `PascalCase` types/classes

### [Your Frontend Language — e.g. Swift]
- [Framework-specific conventions]
- [Naming conventions]
- [Preferred patterns]

### General
- Commit messages: `type(scope): description`
  - Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`
- Never force push. Never rewrite history.
- Tests before committing (if test suite exists)

---

## Architecture Constraints

- **Authentication:** [Your auth provider] — do NOT implement custom auth
- **Database:** Use ORM (Prisma/etc.) — do NOT write raw SQL unless performance-critical
- **AI calls:** Async via job queue — do NOT make synchronous LLM calls in request handlers
- **Secrets:** Environment variables only — never hardcode API keys

---

## File Structure

```
[your-app]/
├── [frontend-dir]/      # Client-side code
├── backend/             # API server
│   ├── src/
│   │   ├── routes/      # Express/Hono route handlers
│   │   ├── services/    # Business logic
│   │   ├── workers/     # Background job processors
│   │   └── lib/         # Shared utilities
│   └── prisma/          # DB schema and migrations
├── [landing-dir]/       # Marketing site (if applicable)
└── docs/                # Documentation
```

---

## What Claude Handles (in multi-agent setups)

- **Backend:** API routes, services, workers, database, auth
- **[Frontend platform]:** [Main app code]
- **Infrastructure:** Deployment scripts, CI/CD, environment config

## What Claude Does NOT Handle

- Design system / component styling (→ [other agent])
- [Landing page / specific surface] (→ [other agent])
- Test coverage reviews (→ QA agent)

---

## Getting Started

```bash
# Backend
cd backend
npm install
cp .env.example .env  # Fill in variables
npm run dev           # localhost:3000

# [Frontend]
[setup commands]
```

---

*This file is the single source of truth for coding standards. Follow it or update it.*
