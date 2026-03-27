# ARCHITECTURE.md - Memo System Design

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         iOS App                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Search    │  │   Capture    │  │ Integrations │      │
│  │   (Voice)   │  │  (Voice/Text)│  │   (OAuth)    │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
│         │                 │                   │             │
│         └─────────────────┴───────────────────┘             │
│                           │                                 │
└───────────────────────────┼─────────────────────────────────┘
                            │ REST API (HTTPS)
┌───────────────────────────┼─────────────────────────────────┐
│                    Backend (Node.js)                        │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Express   │  │   Prisma     │  │   Services   │      │
│  │    API      │  │     ORM      │  │   (AI, Sync) │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
│         │                 │                   │             │
│         └─────────────────┴───────────────────┘             │
│                           │                                 │
└───────────────────────────┼─────────────────────────────────┘
                            │
        ┌───────────────────┴────────────────────┐
        │                                        │
        ▼                                        ▼
┌────────────────┐                    ┌──────────────────┐
│   PostgreSQL   │                    │   External APIs  │
│   (Primary DB) │                    │                  │
└────────────────┘                    │  • Anthropic     │
        │                             │  • Voyage AI     │
        │                             │  • AssemblyAI    │
┌────────────────┐                    │  • Telegram      │
│    Pinecone    │                    │  • Notion        │
│  (Vector DB)   │                    │  • Instagram     │
└────────────────┘                    └──────────────────┘
        │
┌────────────────┐
│     Redis      │
│    (Cache)     │
└────────────────┘
```

---

## Data Flow

### 1. Note Capture (Voice)
```
User speaks → iOS (AVAudioRecorder) → .m4a file → Upload to Backend
→ AssemblyAI (transcription) → Claude (summarization, tags)
→ Voyage AI (embedding) → PostgreSQL + Pinecone
→ Return note ID to iOS → Display in app
```

### 2. Note Capture (Integration Sync - Telegram)
```
Cron job triggers → Backend fetches new Telegram saved messages
→ Download media/text → Claude (summarization, tags)
→ Voyage AI (embedding) → PostgreSQL + Pinecone
→ iOS polls for updates → Display new notes
```

### 3. Search
```
User types query → iOS sends to Backend → Voyage AI (query embedding)
→ Pinecone (semantic search, top 20 results)
→ PostgreSQL (fetch full note metadata)
→ Redis (cache results for 5 min) → Return to iOS → Display
```

---

## Database Schema

### PostgreSQL (Prisma)

```prisma
model User {
  id            String   @id @default(uuid())
  email         String   @unique
  name          String?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  
  sources       ConnectedSource[]
  notes         Note[]
}

model ConnectedSource {
  id            String   @id @default(uuid())
  userId        String
  user          User     @relation(fields: [userId], references: [id])
  
  type          SourceType // telegram, notion, voice, etc.
  status        String   @default("active") // active, syncing, error
  credentials   Json     // OAuth tokens, encrypted
  lastSyncAt    DateTime?
  
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  
  notes         Note[]
}

model Note {
  id            String   @id @default(uuid())
  userId        String
  user          User     @relation(fields: [userId], references: [id])
  
  sourceId      String
  source        ConnectedSource @relation(fields: [sourceId], references: [id])
  
  content       String   @db.Text
  summary       String?  @db.Text
  tags          String[]
  
  sourceType    SourceType
  sourceUrl     String?  // Link back to original (Telegram msg, Notion page, etc.)
  sourceMetadata Json?   // Source-specific data
  
  attachments   Attachment[]
  
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  capturedAt    DateTime // When the note was originally saved (might differ from createdAt)
  
  @@index([userId, capturedAt])
  @@index([userId, sourceType])
}

model Attachment {
  id            String   @id @default(uuid())
  noteId        String
  note          Note     @relation(fields: [noteId], references: [id])
  
  type          AttachmentType // image, audio, video, pdf
  url           String   // S3 or Railway static storage
  thumbnailUrl  String?
  
  metadata      Json?    // width, height, duration, etc.
  
  createdAt     DateTime @default(now())
}

enum SourceType {
  TELEGRAM
  NOTION
  VOICE
  INSTAGRAM
  REDDIT
  TWITTER
  WHATSAPP
  DISCORD
}

enum AttachmentType {
  IMAGE
  AUDIO
  VIDEO
  PDF
  OTHER
}
```

### Pinecone (Vector DB)

```typescript
// Vector structure
interface NoteVector {
  id: string;              // Same as PostgreSQL Note.id
  values: number[];        // 1024-dim embedding from Voyage AI
  metadata: {
    userId: string;
    sourceType: string;
    capturedAt: number;    // Unix timestamp for filtering
    tags: string[];
  };
}
```

---

## API Endpoints

### Auth
- `POST /auth/register` - Create account
- `POST /auth/login` - Login
- `POST /auth/refresh` - Refresh JWT token

### Sources (Integrations)
- `GET /sources` - List connected sources
- `POST /sources/telegram/connect` - OAuth flow
- `POST /sources/notion/connect` - OAuth flow
- `DELETE /sources/:id` - Disconnect source
- `POST /sources/:id/sync` - Manual sync trigger

### Notes
- `GET /notes` - List notes (paginated, filterable)
- `POST /notes` - Create note (voice upload or manual entry)
- `GET /notes/:id` - Get single note
- `DELETE /notes/:id` - Delete note
- `PUT /notes/:id/tags` - Update tags

### Search
- `POST /search` - Semantic search
  - Body: `{ query: string, filters?: { sourceType?, dateRange? } }`
  - Returns: Array of notes ranked by relevance

### Sync (Internal, cron-triggered)
- `POST /sync/telegram` - Sync all Telegram sources
- `POST /sync/notion` - Sync all Notion sources

---

## Service Layer

### AI Services

#### Claude Service (`services/ai/claude.ts`)
```typescript
- summarizeNote(content: string): Promise<string>
- generateTags(content: string): Promise<string[]>
- answerQuestion(query: string, context: Note[]): Promise<string>
```

#### Voyage Service (`services/ai/voyage.ts`)
```typescript
- embedText(text: string): Promise<number[]>
- embedBatch(texts: string[]): Promise<number[][]>
```

#### AssemblyAI Service (`services/ai/assembly.ts`)
```typescript
- transcribeAudio(fileUrl: string): Promise<string>
```

### Integration Services

#### Telegram Service (`services/integrations/telegram.ts`)
```typescript
- authenticate(userId: string): Promise<OAuth tokens>
- fetchSavedMessages(credentials: Credentials): Promise<Message[]>
- downloadMedia(messageId: string): Promise<Buffer>
```

#### Notion Service (`services/integrations/notion.ts`)
```typescript
- authenticate(userId: string): Promise<OAuth tokens>
- fetchPages(credentials: Credentials): Promise<Page[]>
- fetchDatabases(credentials: Credentials): Promise<Database[]>
```

### Search Service (`services/search.ts`)
```typescript
- semanticSearch(query: string, userId: string, filters?: Filters): Promise<Note[]>
  1. Embed query with Voyage AI
  2. Query Pinecone for top 20 vector matches
  3. Fetch full notes from PostgreSQL
  4. Cache results in Redis (5 min TTL)
  5. Return ranked results
```

---

## iOS App Architecture (MVVM)

```
Views/
├── RootView.swift              # TabView (Search, Capture, Settings)
├── Search/
│   ├── SearchView.swift        # Main search interface
│   ├── SearchResultsView.swift
│   └── NoteDetailView.swift
├── Capture/
│   ├── VoiceCaptureView.swift  # Voice memo recording
│   └── ManualNoteView.swift    # Text entry
├── Integrations/
│   ├── IntegrationsListView.swift
│   ├── TelegramConnectView.swift
│   └── NotionConnectView.swift
└── Settings/
    ├── SettingsView.swift
    └── AccountView.swift

ViewModels/
├── SearchViewModel.swift       # @Published notes, searchQuery
├── VoiceCaptureViewModel.swift # Audio recording logic
└── IntegrationsViewModel.swift # OAuth flows, sync status

Services/
├── APIService.swift            # URLSession wrapper
├── AudioService.swift          # AVAudioRecorder wrapper
└── KeychainService.swift       # JWT storage

Models/
├── Note.swift
├── ConnectedSource.swift
└── User.swift
```

---

## Security

### Authentication
- JWT tokens (access: 1 hour, refresh: 7 days)
- Stored in iOS Keychain
- HTTPS only (no HTTP allowed)

### Data Privacy
- OAuth credentials encrypted in PostgreSQL (AES-256)
- User data isolated by userId in all queries
- No sharing between users
- GDPR-compliant: user can export/delete all data

### API Rate Limiting
- 100 requests/minute per user (Redis-based)
- Search: 10 requests/minute (expensive)

---

## Scalability

### MVP (100 users)
- Single Railway instance (512MB RAM)
- PostgreSQL: 1GB storage
- Pinecone: Free tier (1M vectors)
- Redis: Railway add-on (shared)

### Growth (1,000 users)
- Railway: 2GB RAM instance
- PostgreSQL: 10GB storage
- Pinecone: Starter ($70/mo, 5M vectors)
- Redis: Dedicated instance

### Scale (10,000 users)
- Load balancer + multiple Railway instances
- PostgreSQL: Read replicas
- Pinecone: Standard ($250/mo, 50M vectors)
- CDN for attachments (CloudFlare)

---

## Monitoring

### MVP
- Railway logs (basic)
- Manual testing

### Production
- Sentry (error tracking)
- PostHog or Mixpanel (analytics)
- Custom dashboard: active users, search latency, sync success rate

---

## Development Workflow

### Local Development
```bash
# Backend
cd backend
npm install
npm run dev  # Runs on localhost:3000

# iOS
cd ios
open Memo.xcodeproj
# Xcode → Run on simulator
```

### Testing
```bash
# Backend
npm test

# iOS
Xcode → Cmd+U (runs XCTests)
```

### Deployment
```bash
# Backend (Railway)
git push origin main  # Auto-deploys to Railway

# iOS (TestFlight)
Xcode → Product → Archive → Upload to App Store Connect
```

---

## Open Questions / TBD

1. **File storage:** Railway static files vs S3? (Start with Railway, migrate to S3 if needed)
2. **Offline support:** Full offline mode or online-only? (Start online-only, add offline later)
3. **Push notifications:** Do we notify on new synced notes? (TBD based on user feedback)
4. **Real-time sync:** WebSockets or polling? (Start with polling, add WebSockets if needed)

---

**Last Updated:** March 12, 2026
