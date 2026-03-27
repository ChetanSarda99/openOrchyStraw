# Tech Stack Registry — [Your Project]

> Single source of truth for all approved technologies.
> Maintained by: CTO / tech lead.
> See KNOWLEDGE-REPOSITORIES.md for system documentation (if applicable).

---

## Approved Stack

| Domain | Solution | Version | Decision Ref | Surfaces | Notes |
|--------|----------|---------|--------------|----------|-------|
| Runtime | [e.g. Node.js] | [version] | ADR-XXX | [services] | |
| Framework | [e.g. Express/Hono/FastAPI] | [version] | ADR-XXX | [services] | |
| Frontend UI | [e.g. React + TypeScript] | [version] | ADR-XXX | [surfaces] | |
| Build tool | [e.g. Vite/Turbopack] | [version] | ADR-XXX | [surfaces] | |
| UI components | [e.g. shadcn/ui] | [version] | ADR-XXX | [surfaces] | |
| CSS | [e.g. Tailwind CSS v4] | [version] | ADR-XXX | [surfaces] | |
| Icons | [e.g. Lucide React] | latest | ADR-XXX | [surfaces] | |
| State (UI) | [e.g. Zustand] | [version] | ADR-XXX | [surfaces] | |
| State (server) | [e.g. TanStack Query] | [version] | ADR-XXX | [surfaces] | |
| Primary DB | [e.g. PostgreSQL] | — | ADR-XXX | [services] | |
| ORM | [e.g. Prisma] | [version] | ADR-XXX | [services] | |
| Cache / Queue | [e.g. Redis + BullMQ] | — | ADR-XXX | [services] | |
| Auth | [e.g. Supabase Auth] | — | ADR-XXX | [services] | |
| File storage | [e.g. S3 / Supabase Storage] | — | ADR-XXX | [services] | |
| AI / LLM | [e.g. Anthropic Claude] | — | ADR-XXX | [services] | |
| Embeddings | [e.g. Voyage AI] | — | ADR-XXX | [services] | |
| Hosting | [e.g. Railway / Fly / Vercel] | — | ADR-XXX | [services] | |
| CI/CD | [e.g. GitHub Actions] | — | ADR-XXX | [services] | |
| Error tracking | [e.g. Sentry] | — | ADR-XXX | [services] | |
| Analytics | [e.g. PostHog] | — | ADR-XXX | [services] | |
| Font (UI) | [e.g. Inter / Geist] | — | ADR-XXX | [surfaces] | |
| Font (code) | [e.g. JetBrains Mono] | — | ADR-XXX | [surfaces] | |

---

## Domain Decisions

| Domain | Status | ADR | Notes |
|--------|--------|-----|-------|
| Frontend framework | **LOCKED** | ADR-XXX | |
| Backend framework | **LOCKED** | ADR-XXX | |
| Database | **APPROVED** | ADR-XXX | |
| Auth | **APPROVED** | ADR-XXX | |
| Styling system | **LOCKED** | ADR-XXX | |
| Hosting | **APPROVED** | ADR-XXX | MVP hosting decided |
| AI provider | **APPROVED** | ADR-XXX | |
| [Domain N] | **PENDING** | — | Decide when needed |

**Status definitions:**
- **LOCKED** — Final decision, no changes without architecture review
- **APPROVED** — In use, can be revisited with good reason
- **PENDING** — Needs a decision before work begins

---

## Pending Decisions

Domains that need ADRs before implementation begins:

1. **[Domain 1]** — Options: [A, B, C]. Decide when: [trigger]
2. **[Domain 2]** — Options: [A, B]. Decide when: [trigger]
3. **[Domain 3]** — Recommendation: [preferred option]. Needs formal ADR.

---

## Proposal Process

Before introducing a new dependency:

1. Write a proposal: what it is, why needed, alternatives considered
2. Drop it in the CTO Proposals Inbox (or equivalent)
3. Wait for approval before implementing
4. Add approved tech to this registry with ADR reference

**Do NOT ship a new dependency without registry approval.**

---

## Upgrade Policy

| Status | Upgrade Policy |
|--------|---------------|
| LOCKED | Major version only with architecture review |
| APPROVED | Minor/patch: anytime. Major: ADR required |
| PENDING | No constraint (not yet in use) |

---

*Keep this up to date. If you ship a dep that's not here, add it.*
