# CLAUDE.md - Memo Project Instructions

**Read this first. Follow it exactly. This overrides defaults.**

---

## Project Overview

**Memo** — ADHD-first universal note aggregator iOS app.
Pulls saved content from Telegram, Notion, Instagram, Reddit, Twitter, voice memos into one searchable place.
AI categorizes everything across 5 dimensions: Source, Format, Area, Tags, Status. See `docs/core/CATEGORIZATION_SYSTEM.md`.

**Repo:** github.com/ChetanSarda99/memo-app (private)
**Owner:** CS — solo developer, learning Swift, experienced with JS/TS
**Timeline:** 6-9 months to MVP launch (started Mar 2026)

---

## Finalized Tech Stack (All Decided)

### iOS App
- **Swift + SwiftUI** (iOS 17+ minimum)
- **@Observable** macro for ViewModels (NOT ObservableObject)
- **SwiftData** for local persistence
- **Supabase Swift SDK** for auth
- **NavigationStack** (NOT NavigationView)
- **.task** modifier for async (NOT .onAppear)
- **SF Symbols** for all icons

### Backend
- **Node.js + Express + TypeScript** (strict mode)
- **Prisma ORM** + PostgreSQL (with **pgvector** for vector search)
- **Supabase Auth** (NOT custom JWT, NOT Auth0)
- **Redis** (cache + BullMQ job queue)
- **AWS S3** for file storage
- **Railway** for hosting

### AI Services
- **Anthropic Claude 3.5 Sonnet** — summarization, tagging, categorization
- **Voyage AI voyage-3** — text embeddings (1024-dim vectors)
- **AssemblyAI** — voice transcription ($0.00025/sec)
- **Apple Vision** — on-device OCR (free)

### Vector Search
- **pgvector** in PostgreSQL (NOT Pinecone for MVP)
- Migrate to Pinecone only if needed at 10K+ users

---

## Working Style — FOLLOW STRICTLY

### CS Prefers
- **Action over questions** — Just do it, don't ask for permission
- **Concise responses** — No fluff, no trailing summaries
- **Working code** — Not pseudocode, not TODO comments
- **Complete solutions** — Don't leave half-finished work
- **Production quality** — This ships to real paying users

### Anti-Slop Rules (CRITICAL)
- **NO** generic gradient backgrounds
- **NO** stock photo placeholders or Lorem ipsum
- **NO** default Material/Bootstrap components without customization
- **NO** rainbow loading spinners or generic animations
- **NO** emoji in code comments or commit messages
- **NO** over-explaining what you just did
- **NO** unnecessary abstractions or premature optimization
- **NO** adding features, comments, or refactoring beyond what was asked
- **YES** personality in design choices
- **YES** thoughtful micro-interactions
- **YES** custom components that match Memo's identity

---

## ADHD-First Design System

### Colors
- Primary: Calming teal/blue (NOT red/orange)
- Accent: Warm coral (CTAs and actions)
- Background: Off-white light / deep navy dark mode (#0D1B2A, NOT pure black)
- Area colors: Each of 8 life areas has distinct color (see docs/core/CATEGORIZATION_SYSTEM.md)
- Semantic: green=success, amber=warning, red=destructive ONLY

### Typography
- **SF Pro** exclusively (system font)
- Body: 17pt minimum (SF Pro default), line height 1.5-1.7
- Headers: 20-28pt semibold
- Left-aligned always (no justified text)
- 4.5:1 contrast ratio minimum

### Layout
- One clear action per screen
- 16pt minimum padding everywhere
- 12pt corner radius on cards
- Progressive disclosure (show only what's needed now)
- Dark mode is first-class (not afterthought)

### Animations
- Subtle spring animations for interactions
- Respect `UIAccessibility.isReduceMotionEnabled`
- No auto-playing animations
- Purpose: feedback, not decoration

### Design Inspirations
- **Linear** — clean, purposeful animations
- **Things 3** — calm, clear hierarchy
- **Obsidian** — content focus, minimal chrome

### UX Rules
- Search always accessible and instant-feeling
- No guilt-tripping ("You missed 5 days!")
- No streak pressure or gamification traps
- No notification spam (max 1-2/day, all opt-in)
- Batch notifications preferred over constant pings
- Empty states should be helpful and friendly

---

## Code Standards

### TypeScript (Backend)
```typescript
// ALWAYS: Strict mode, explicit types, async/await
interface Note {
  id: string;
  content: string;
  source: 'telegram' | 'notion' | 'voice' | 'instagram' | 'reddit' | 'twitter';
  createdAt: Date;
  tags: string[];
}

// ALWAYS: Custom error classes
class NotFoundError extends Error {
  constructor(entity: string, id: string) {
    super(`${entity} not found: ${id}`);
    this.name = 'NotFoundError';
  }
}

// ALWAYS: Validate env vars on startup
function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`Missing required env var: ${key}`);
  return value;
}

// NEVER: any types, .then() chains, unvalidated input
```

### Swift (iOS)
```swift
// ALWAYS: @Observable (not ObservableObject)
@Observable
final class SearchViewModel {
    var notes: [Note] = []
    var searchQuery = ""
    var isLoading = false

    func search() async {
        isLoading = true
        defer { isLoading = false }
        do {
            notes = try await APIService.shared.searchNotes(query: searchQuery)
        } catch {
            // Handle error
        }
    }
}

// ALWAYS: .task (not .onAppear), NavigationStack (not NavigationView)
struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.notes) { note in
                NoteRow(note: note)
            }
            .searchable(text: $viewModel.searchQuery)
            .task { await viewModel.search() }
        }
    }
}

// NEVER: force unwraps, UserDefaults for tokens, ObservableObject
```

### REST API Design
- Nouns not verbs: `/notes` not `/getNotes`
- Plural for collections: `/notes`, `/sources`
- Response: `{ data: T }` success, `{ error: { code, message } }` errors
- Paginate everything: `?page=1&limit=20`
- Filter with query params: `?source=telegram&from=2026-01-01`

### Git
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Branch from main: `feature/*`, `bugfix/*`, `hotfix/*`
- Never force push to main

---

## Project Structure

```
Memo/
├── ios/                        # Swift + SwiftUI app
│   └── Memo/
│       ├── App/                # MemoApp.swift, ContentView.swift
│       ├── Models/             # SwiftData @Model classes
│       ├── Views/
│       │   ├── Components/     # MemoButton, MemoCard, MemoSearchBar, MemoTag
│       │   ├── Screens/        # Search/, Capture/, Categories/, Settings/, Auth/
│       │   └── Modifiers/      # Custom ViewModifiers
│       ├── ViewModels/         # @Observable classes
│       ├── Services/           # APIService, AuthService, AudioService
│       └── Utilities/          # Extensions, Constants, ColorTheme
├── backend/                    # Node.js API
│   ├── src/
│   │   ├── index.ts            # Express entry point
│   │   ├── routes/             # auth, notes, sources, search, sync
│   │   ├── controllers/        # Request/response logic
│   │   ├── services/           # Business logic
│   │   │   ├── ai/             # Claude, Voyage, AssemblyAI
│   │   │   └── integrations/   # Telegram, Notion, etc.
│   │   ├── middleware/         # Auth (Supabase verify), errors, rate limiting
│   │   ├── models/             # TypeScript types/interfaces
│   │   └── utils/              # Helpers
│   └── prisma/                 # Database schema + migrations
├── docs/                       # 24 docs organized in subfolders
│   ├── core/                  # Product spec, categorization, tech stack, decisions
│   ├── research/              # Feasibility studies, competitive analysis
│   ├── brand/                 # Branding, marketing, growth, onboarding
│   ├── setup/                 # Environment & migration guides
│   └── archive/               # Superseded documents
├── prompts/                    # Session prompts (gitignored)
├── scripts/                    # setup.sh
├── docker-compose.yml          # PostgreSQL (pgvector) + Redis
├── .env.example                # All env vars documented
├── ARCHITECTURE.md             # System design
├── CONVENTIONS.md              # Full code style guide
└── CONTRIBUTING.md             # Git workflow, PR guidelines
```

---

## API Endpoints

### Auth (Supabase handles, backend verifies)
- Middleware: verify Supabase JWT → extract user ID → attach to req

### Notes
- `GET /notes` — List (paginated, filterable)
- `POST /notes` — Create
- `GET /notes/:id` — Detail
- `PATCH /notes/:id` — Update
- `DELETE /notes/:id` — Delete

### Search
- `POST /search` — Hybrid: pgvector semantic + PostgreSQL tsvector keyword

### Sources
- `GET /sources` — List connected
- `POST /sources/:type/connect` — OAuth flow
- `DELETE /sources/:id` — Disconnect
- `POST /sources/:id/sync` — Trigger sync

### Webhooks
- `POST /sync/telegram` — Telegram Bot webhook
- `POST /sync/notion` — Notion sync

---

## Common Tasks

### Adding a New Integration
1. Service in `backend/src/services/integrations/[source].ts`
2. Add credentials to `.env.example`
3. Route in `backend/src/routes/sync.ts`
4. iOS UI in `Views/Screens/Settings/IntegrationsView.swift`

### Adding a New Feature
1. Check GitHub issues: `gh issue list --repo ChetanSarda99/memo-app --milestone "MILESTONE"`
2. Backend first (API + tests)
3. iOS second (UI + ViewModel)
4. Test on simulator
5. Commit with conventional message

---

## Current Status (Last Updated: Mar 15, 2026 — 15:30)

### Codebase: 170 backend TS + 170 iOS Swift = 340 source files, 628 tests

### 97/111 issues closed (87%) — 14 open

### Phase 1 MVP — M1.1–M1.9 DONE, M1.10 has 3 open (TestFlight, beta, bugs — ALL Mac-blocked)
### Phase 2 — 100% COMPLETE (7/7 milestones, 0 open)
### Phase 3 — 100% COMPLETE (4/4 milestones, 0 open)
### Phase 4 — 100% COMPLETE (6/6 milestones, 0 open)
### Phase 5 — Launch ops only (9 open: marketing, App Store, ads, community — no code)

### Blocked on Mac (arriving ~Mar 22)
- Xcode project creation, Supabase SDK, first build, visual QA, TestFlight

---

## Auto-Agent Orchestrator

The project has an autonomous multi-agent build system. You don't need to be told how it works — just use it.

### Quick Commands
```bash
./scripts/auto-agent.sh orchestrate       # Run 10 cycles (no delay between cycles)
./scripts/auto-agent.sh orchestrate 5      # Run 5 cycles
./scripts/auto-agent.sh run 02-backend     # Run single agent once
./scripts/auto-agent.sh list               # Show all agents
./scripts/check-usage.sh                   # Check API rate limits
```

### Architecture
- **5 agents** in `scripts/agents.conf`: 01-pm (coordinator), 02-backend, 03-ios, 04-design, 05-qa
- **Each cycle**: workers run in parallel → commits by file ownership → PM reviews + updates tasks → merge to main → push
- **Shared context**: `prompts/00-shared-context/context.md` — agents read/write what they built/need
- **Session tracker**: `prompts/00-session-tracker/SESSION_TRACKER.txt` — long-term changelog
- **Progress**: `prompts/00-shared-context/progress.json` — file counts per cycle, regression detection
- **Backups**: `prompts/00-backup/cycle-*/` — prompt snapshots, 7-day rotation
- **QA reports**: `prompts/05-qa/reports/` — named by date-time

### What the Script Handles (don't duplicate)
- Timestamps + file counts in all prompts (auto-updated after every merge)
- Usage check via `check-usage.sh` (pauses at 70% rate limit)
- Shared context reset + archive per cycle
- `qmd update` every cycle, `qmd embed` on QA cycles
- Git branching, commits by ownership, merge, push
- Rogue write detection (files outside ownership)
- Backup rotation (7 days)

### What PM Agent Handles
- Task assignments (Edit "YOUR TASKS" sections — never rewrite full prompts)
- Milestone status updates
- SESSION_TRACKER what-shipped entries
- 99-cs-actions updates

### Monitoring
- Log: `prompts/01-pm/logs/orchestrator.log`
- Use `/monitor` in interactive sessions to watch cycles
- Don't edit `scripts/auto-agent.sh` while orchestrator is running (rogue detection reverts changes)

### Key Docs

- `docs/core/PRODUCT_SPEC.md` — Full product spec (31K words)
- `docs/core/CATEGORIZATION_SYSTEM.md` — 5-dimension categorization (Source, Format, Area, Tags, Status)
- `docs/core/TECH_STACK.md` — Technology decisions with rationale
- `docs/core/DECISIONS.md` — Architecture Decision Records
- `docs/core/LANDING-PAGE-STACK.md` — **LOCKED** landing page stack (Next.js 16 + Tailwind v4 + Framer Motion + GSAP, custom components, NO shadcn/ui)
- `docs/brand/APP_BUILDING_BEST_PRACTICES.md` — Onboarding, paywall, ads, analytics
- `docs/brand/APP_BRANDING.md` — Visual identity, brand voice, UI language
- `docs/brand/APP_MINDSET.md` — Execution principles, MVP definition, decision framework
- `docs/brand/MARKETING_STRATEGY.md` — Go-to-market plan
- `docs/README.md` — Full docs index

### Stack Reference (LOCKED — read before touching `landing/`)

| Surface | Reference Doc | Stack |
|---------|--------------|-------|
| Landing Page | `docs/core/LANDING-PAGE-STACK.md` | Next.js 16 + Tailwind v4 + Framer Motion + GSAP |
| iOS App | `docs/core/TECH_STACK.md` | Swift + SwiftUI + SwiftData + Supabase |
| Backend | `docs/core/TECH_STACK.md` | Node.js + Express + Prisma + PostgreSQL |

**Landing page uses CUSTOM components, NOT shadcn/ui.** All brand values from `landing/lib/constants.ts`. Dark mode only. ADHD design rules are non-negotiable (see LANDING-PAGE-STACK.md).

---

**Ship fast. Production quality. ADHD-first. Not AI slop.**
