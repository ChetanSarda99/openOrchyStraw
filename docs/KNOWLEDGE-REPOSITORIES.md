# Knowledge Repositories — Shared Intelligence Across Projects

_Last updated: March 17, 2026_

---

## The Problem

Every project starts from scratch:
- Backend googles "best auth library for Next.js" for the 4th time
- iOS agent picks RevenueCat, another project uses Stripe — inconsistent
- Same integration bug in Supabase webhooks hits 3 different projects
- No one knows what was actually tried and rejected last time

**Cost:** Research time + inconsistency + repeated mistakes + wasted tokens.

**Fix:** Build repositories of institutional knowledge that all agents read before doing work.

---

## The Research-First Protocol

Every worker agent MUST follow this before implementing any feature:

### Step 1: Check Internal Registry
```
Read docs/tech-registry/stack.md → Is this solved already?
Search shared-knowledge/ → Has CS used a solution for this before?
```

### Step 2: Research External Options
- Search GitHub for top repos solving this problem (stars, recency, maintenance)
- Check context7 for framework-specific recommendations
- Look at what top SaaS products in this space use
- Check Product Hunt, Hacker News, Reddit for current community sentiment

### Step 3: Submit Proposal to CTO
Append to `prompts/00-shared-context/proposals.md`:
```markdown
### [PROPOSAL] <date> | <agent-id> | <task>
**Problem:** <what needs to be solved>
**Options evaluated:**
- Option A: <name> — <pros/cons, cost, maintenance>
- Option B: <name> — <pros/cons, cost, maintenance>
- Option C: <name> — <pros/cons, cost, maintenance>
**Recommendation:** Option X because <reason>
**Notes:** <anything the CTO should know>
```

### Step 4: CTO Decides, Documents, Broadcasts
CTO reads proposals → evaluates → writes to `docs/tech-registry/` + broadcasts decision via shared context.

### Step 5: Worker Implements
Worker reads CTO decision, implements accordingly.

### Step 6: Worker Documents What Was Actually Used
After implementation, appends to `docs/tech-registry/registry.md`:
```markdown
| <date> | <project> | <domain> | <solution chosen> | <agent> |
```

---

## Repository 1: Tech Stack Registry

**Location:** `docs/tech-registry/`
**Purpose:** Single source of truth for approved solutions per domain.
**Updated by:** CTO (after evaluating worker proposals)
**Read by:** All agents (before starting any implementation)

### Structure
```
docs/tech-registry/
  README.md            — How to use the registry
  registry.md          — Master table: domain → approved solution
  stack.md             — Current approved stack (snapshot)
  decisions/
    AUTH-001.md         — Auth decision (Clerk vs Auth.js vs Supabase)
    PAYMENTS-001.md     — Payments decision (Stripe vs RevenueCat vs LemonSqueezy)
    STORAGE-001.md      — Storage decision (S3 vs Supabase vs Cloudflare R2)
    DATABASE-001.md     — DB decision (Supabase vs PlanetScale vs Turso)
    EMAIL-001.md        — Email (Resend vs SendGrid vs Postmark)
    ANALYTICS-001.md    — Analytics (PostHog vs Plausible vs Mixpanel)
    MONITORING-001.md   — Monitoring (Sentry vs Datadog vs LogRocket)
    [domain]-[N].md     — Add as needed
  proposals.md          — Incoming worker research proposals (CTO inbox)
```

### registry.md Format
```markdown
| Domain | Solution | Version | Decision | Projects Using | Notes |
|--------|----------|---------|----------|----------------|-------|
| Auth | Clerk | 6.x | AUTH-001 | my-mobile-app, my-other-app | Free up to 10k MAU |
| Payments | Stripe | latest | PAYMENTS-001 | my-other-app | 2.9%+30¢ |
| DB | Supabase | latest | DATABASE-001 | my-mobile-app, my-other-app | Free tier generous |
| Email | Resend | latest | EMAIL-001 | - | 3K free/mo |
```

### Decision Format (ADR-style)
```markdown
# AUTH-001 — Authentication Solution

**Date:** 2026-03-17
**Status:** APPROVED
**Decided by:** CTO (02-cto)

## Context
Need user auth for consumer-facing iOS/web app. CS builds solo, can't maintain auth infra.

## Options Evaluated
| Option | Pros | Cons | Cost |
|--------|------|------|------|
| Clerk | Best DX, prebuilt UI, iOS SDK | $25/mo after 10k MAU | Free to 10k |
| Supabase Auth | Built into Supabase stack | Less polished iOS SDK | Part of Supabase plan |
| Auth.js | Open source, full control | More setup, no hosted UI | Free |

## Decision
**Clerk** — Best developer experience, best iOS SDK, free to 10K MAU covers MVP.

## Rationale
CS is solo. DX matters more than cost at this stage. Supabase Auth is 2nd choice when
full-stack is already on Supabase (to avoid cross-vendor auth + DB).

## Trade-offs Accepted
- Vendor lock-in at 10K MAU → switching cost is auth migration (manageable)
- $25/mo after 10K → cross that bridge when there's revenue

## Projects Using This
- my-mobile-app (v1, iOS + web)

## Supersedes
Nothing — first auth decision.
```

---

## Repository 2: Service Catalog

**Location:** `docs/service-catalog.md`
**Purpose:** All 3rd-party APIs/services researched, with cost, limits, and integration notes.
**Updated by:** Any agent who integrates a service. Reviewed by CTO.
**Read by:** All agents considering third-party integrations.

```markdown
| Service | Category | Free Tier | Paid Tier | Auth | SDK | CS Used | Notes |
|---------|----------|-----------|-----------|------|-----|---------|-------|
| Supabase | DB/Auth/Storage | 500MB, 50K MAU | $25/mo | API key | ✅ | my-mobile-app | Postgres + storage + auth |
| Clerk | Auth | 10K MAU | $25+/mo | API key | ✅ | my-mobile-app | Best iOS SDK |
| Stripe | Payments | None | 2.9%+30¢ | API key | ✅ | my-other-app | Gold standard |
| RevenueCat | IAP | 10K MAU | $119+/mo | API key | ✅ | my-other-app | Best for iOS subscriptions |
| Resend | Email | 3K/mo | $20+/mo | API key | ✅ | - | Clean API, great DX |
| PostHog | Analytics | 1M events | $0+/mo | API key | ✅ | - | Open source option too |
| Sentry | Monitoring | 5K errors | $26+/mo | DSN | ✅ | - | Industry standard |
| Cloudflare R2 | Storage | 10GB | $0.015/GB | API key | ✅ | - | No egress fees |
| Upstash | Redis/Kafka | 10K cmds/day | $0.2+/mo | API key | ✅ | - | Serverless Redis |
| Inngest | Job queue | 50K steps | $20+/mo | API key | ✅ | - | Serverless background jobs |
```

---

## Repository 3: Code Pattern Library

**Location:** `docs/patterns/`
**Purpose:** Reusable code snippets for common problems. Tested and proven.
**Updated by:** Any agent who ships a working implementation. QA validates.
**Read by:** All worker agents before implementing common patterns.

```
docs/patterns/
  auth/
    clerk-next.md          — Next.js + Clerk auth setup (complete, tested)
    supabase-rls.md        — Row-level security patterns
  payments/
    stripe-webhooks.md     — Stripe webhook handler (with idempotency key)
    revenuecat-ios.md      — RevenueCat iOS subscription setup
  api/
    rest-error-handling.md — Standard REST error format + handler
    rate-limiting.md       — Per-user rate limiting with Upstash Redis
    pagination.md          — Cursor-based pagination pattern
  ios/
    nfc-reading.md         — CoreNFC tag reading (tested with NTAG215)
    audio-session.md       — AVFoundation audio session for background playback
  database/
    supabase-migrations.md — Migration workflow (local → staging → prod)
    soft-delete.md         — Soft delete pattern with Supabase RLS
```

### Pattern File Format
```markdown
# Pattern: Stripe Webhook Handler

**Status:** Tested ✅
**Last verified:** 2026-03-17
**Projects using:** my-other-app

## The Problem
Stripe webhooks can arrive out of order, duplicated, or fail. Need idempotent handler.

## Solution
[complete code snippet]

## Gotchas
- Always verify signature with STRIPE_WEBHOOK_SECRET
- Use idempotency key (event.id) to prevent double-processing
- Return 200 immediately, process async

## References
- Stripe docs: https://stripe.com/docs/webhooks
- Related decision: PAYMENTS-001
```

---

## Repository 4: Anti-Pattern Registry

**Location:** `docs/anti-patterns.md`
**Purpose:** Document what was tried and failed, and why. Prevent repeat mistakes.
**Updated by:** QA agent after finding recurring issues. Any agent after a debugging session.
**Format:** Problem → What was tried → Why it failed → What to do instead.

```markdown
## AP-001: Supabase RLS with service_role client
**Discovered:** 2026-03-15 by QA
**Problem:** Using service_role key in frontend bypasses ALL RLS policies
**What went wrong:** Backend agent used service_role for convenience in client SDK
**Fix:** Use anon key + proper RLS policies. service_role only in server-side trusted contexts.
**Affects:** All Supabase projects

## AP-002: iOS AudioSession not deactivated after body-doubling
**Discovered:** 2026-03-16 by Backend agent
**Problem:** App holds audio session after playback ends → blocks other audio apps
**Fix:** Deactivate session in deinit + playback completion handler
**Pattern:** See docs/patterns/ios/audio-session.md
```

---

## Repository 5: Prompt Template Library

**Location:** `docs/prompt-library/`
**Purpose:** Proven prompt templates for common agent tasks. Reuse instead of writing from scratch.
**Updated by:** PM agent after a prompt structure proves effective across cycles.
**Read by:** PM when creating new agent prompts.

```
docs/prompt-library/
  init/
    backend-api-agent.md    — Template for any REST API backend agent
    ios-agent.md            — Template for iOS feature agent
    landing-page-agent.md   — Template for landing page agent
  tasks/
    add-auth.md             — Proven prompt for adding Clerk auth
    add-stripe.md           — Proven prompt for Stripe integration
    add-tests.md            — Prompt for adding test coverage
    performance-audit.md    — Prompt for perf optimization
  review/
    security-review.md      — Prompt for security audit
    code-review.md          — Prompt for code review pass
```

---

## Repository 6: Architecture Blueprints

**Location:** `docs/blueprints/`
**Purpose:** Proven architecture patterns for common app types. Start here, don't design from scratch.
**Updated by:** CTO after a stack is proven in production.

```markdown
## Blueprint: Consumer iOS App (SaaS)
Stack: SwiftUI + Supabase + Clerk + RevenueCat + PostHog
Proven in: my-other-app (Phase 1)
Files to bootstrap from: [links]

## Blueprint: Full-Stack Web App
Stack: Next.js + Supabase + Clerk + Stripe + Vercel
Proven in: my-mobile-app (Web layer)
Files to bootstrap from: [links]

## Blueprint: CLI Tool
Stack: Bash/Node.js + GitHub CLI + no framework
Proven in: OrchyStraw itself
Files to bootstrap from: [links]
```

---

## Repository 7: Cost Model Registry

**Location:** `docs/costs.md`
**Purpose:** Actual costs at different scales. Pre-calculated. Agents check before recommending a service.

```markdown
| Service | 0 users | 100 MAU | 1K MAU | 10K MAU | 100K MAU | Notes |
|---------|---------|---------|---------|---------|----------|-------|
| Supabase | $0 | $0 | $0 | $25 | $25-599 | Pro plan at $25 |
| Clerk | $0 | $0 | $0 | $0 | $250+ | Free to 10K |
| RevenueCat | $0 | $0 | $0 | $0 | $119+ | Free to 10K |
| Vercel | $0 | $0 | $0 | $20+ | $20+ | Pro needed for teams |
| Cloudflare R2 | $0 | $0 | $0 | ~$0 | ~$1.50 | No egress cost |
```

---

## Cross-Project Knowledge Sharing

All repositories above live inside `orchystraw/docs/` but should be **shared across all CS's projects**.

### Proposed Structure

```
~/Projects/
  _shared-knowledge/          ← New shared repo (one-time setup)
    tech-registry/
    service-catalog.md
    patterns/
    anti-patterns.md
    blueprints/
    costs.md
    prompt-library/
  orchystraw/
    docs/ → symlinks to relevant parts of _shared-knowledge
  my-mobile-app/
    docs/ → symlinks to relevant parts of _shared-knowledge
  my-other-app/
    docs/ → symlinks to relevant parts of _shared-knowledge
```

**Or simpler:** Each project's agents are prompted to READ `~/Projects/_shared-knowledge/` before checking their local docs. No symlinks needed — just a known path all agents check.

### QMD Cross-Project Indexing
```bash
# Add shared knowledge to QMD index in every project
qmd collection add ~/Projects/_shared-knowledge --name shared-knowledge
qmd embed
```

Now every agent can search `qmd search "auth solution"` and get results from the shared registry.

---

## How This Gets Built (Process)

### Phase 1: Bootstrap (cycle 1-2 per new project)
- CTO reads project brief
- Identifies all major domains needing decisions (auth, payments, storage, etc.)
- Creates blank decision docs for each domain
- Workers start research and submit proposals

### Phase 2: First-Use Decisions (before first feature ships)
- Workers propose → CTO decides → registry updated
- All agents use registry from this point

### Phase 3: Maintenance (ongoing)
- Any agent who tries something new submits a proposal first
- QA validates patterns are working as documented
- CTO reviews proposals and updates registry every 3 cycles
- Anti-patterns added when bugs recur

### Phase 4: Cross-Project Propagation (when 2nd project starts)
- Bootstrap _shared-knowledge/ repo
- Move proven decisions from project 1 to shared
- Project 2 agents read shared + local (local overrides shared)
- Over time: shared knowledge grows, each new project starts smarter

---

## GitHub Issues to Create

1. CTO prompt: Add Tech Curator role + proposal inbox
2. Worker prompts: Add Research-First protocol before all implementation tasks
3. Create `docs/tech-registry/` structure + README
4. Create `docs/patterns/` directory with initial structure
5. Create `docs/anti-patterns.md` with known OrchyStraw pitfalls
6. Create `docs/prompt-library/` with PM templates
7. Create `~/Projects/_shared-knowledge/` repository
8. Add QMD cross-project indexing to auto-agent.sh init
9. Update bootstrap-prompt.txt to create registry structure for new projects
