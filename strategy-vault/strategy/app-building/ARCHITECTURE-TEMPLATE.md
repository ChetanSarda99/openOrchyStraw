# ARCHITECTURE.md — [Your App] System Design

> **How to use:** Replace `[Your App]`, `[iOS App]`, and service names with your actual stack. Keep the structure — it covers all the layers you'll need to design.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      [Client Layer]                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Feature A  │  │  Feature B   │  │  Feature C   │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
└───────────────────────────┬─────────────────────────────────┘
                            │ REST API (HTTPS)
┌───────────────────────────┼─────────────────────────────────┐
│                    Backend (Node.js / Python)               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   API Layer │  │   ORM/DB     │  │   Services   │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┴────────────────────┐
        ▼                                        ▼
┌────────────────┐                    ┌──────────────────┐
│   Primary DB   │                    │  External APIs   │
│  (PostgreSQL)  │                    │  • AI provider   │
└────────────────┘                    │  • Auth service  │
        │                             │  • 3rd party     │
┌────────────────┐                    └──────────────────┘
│   Cache/Queue  │
│    (Redis)     │
└────────────────┘
```

---

## Data Flow

### 1. [Core User Flow — e.g. "Content Capture"]
```
User action → Client → Backend API
→ [Processing step — e.g. AI, transcription]
→ Database storage
→ Response to client → Display
```

### 2. [Background Flow — e.g. "Sync / Cron Job"]
```
Trigger (schedule/event) → Backend job
→ Fetch/process data
→ Store results
→ Client polls or receives push
```

### 3. [Search / Query Flow]
```
User query → Client → Backend
→ [Semantic or keyword search]
→ Database fetch (full records)
→ Cache results → Return to client
```

---

## Database Schema

### Primary DB (Prisma/SQL)

```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Add your relations here
}

model [YourMainEntity] {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])

  content   String   @db.Text
  // Add your fields here

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([userId])
}
```

### Vector DB (if applicable)

```typescript
interface EntityVector {
  id: string;          // Same ID as primary DB
  values: number[];    // Embedding dimensions
  metadata: {
    userId: string;
    // filter fields
  };
}
```

---

## API Endpoints

### Auth
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`

### [Main Resource]
- `GET /[resource]` — List (paginated, filterable)
- `POST /[resource]` — Create
- `GET /[resource]/:id` — Get single
- `PUT /[resource]/:id` — Update
- `DELETE /[resource]/:id` — Delete

### [Secondary Resource]
- `GET /[resource]` — List
- `POST /[resource]` — Create/connect
- `DELETE /[resource]/:id` — Remove/disconnect

### Search (if applicable)
- `POST /search` — Full-text or semantic search
  - Body: `{ query: string, filters?: { ... } }`

---

## Service Layer

### Core Services

```typescript
// AI service (if applicable)
- summarize(content: string): Promise<string>
- generateTags(content: string): Promise<string[]>

// Search service
- search(query: string, userId: string, filters?): Promise<Result[]>

// [Integration service]
- authenticate(userId: string): Promise<Credentials>
- fetchData(credentials: Credentials): Promise<Item[]>
```

---

## Client Architecture (MVVM)

```
Views/
├── RootView          # Top-level navigation
├── [FeatureA]/
│   ├── [FeatureA]View
│   └── [FeatureA]DetailView
├── [FeatureB]/
│   └── [FeatureB]View
└── Settings/
    └── SettingsView

ViewModels/
├── [FeatureA]ViewModel   # @Published state
└── [FeatureB]ViewModel

Services/
├── APIService            # Network layer
└── StorageService        # Local persistence

Models/
└── [YourMainEntity].swift/ts
```

---

## Security

### Authentication
- JWT tokens (access: short-lived, refresh: long-lived)
- Stored securely (Keychain / httpOnly cookies)
- HTTPS only

### Data Privacy
- OAuth credentials encrypted at rest (AES-256)
- User data isolated by userId in all queries
- GDPR-compliant: export + delete

### Rate Limiting
- Global: 100 req/min per IP
- Per-user: 120 req/min
- Expensive ops (search, AI): 10 req/min

---

## Scalability

### MVP (0–1K users)
- Single instance (512MB RAM)
- Shared DB + cache

### Growth (1K–10K users)
- Upgrade to 2GB instance
- Dedicated cache
- Start monitoring

### Scale (10K+ users)
- Load balancer + multiple instances
- DB read replicas
- CDN for static assets
- Consider external vector DB if using pgvector

---

## Monitoring

### MVP
- Platform logs (Railway/Fly)
- Manual testing

### Production
- Sentry (error tracking)
- PostHog or Mixpanel (analytics)
- Custom dashboard: latency, error rate, key feature metrics

---

## Development Workflow

```bash
# Backend
npm install && npm run dev   # localhost:3000

# Client
[run client]
```

### Testing
```bash
npm test           # Backend
[client test cmd]  # Client
```

### Deployment
```bash
# Backend: auto-deploys via git push to main (Railway/Fly)
# Client: release via TestFlight / App Store / Vercel
```

---

## Open Questions / TBD

1. **File storage:** Platform storage vs S3? (Start with platform, migrate if needed)
2. **Offline support:** Full offline or online-only? (Start online-only)
3. **Push notifications:** Trigger conditions TBD
4. **Real-time:** WebSockets or polling? (Start with polling)

---

*Template based on real production architecture. Fill in the blanks for your app.*
