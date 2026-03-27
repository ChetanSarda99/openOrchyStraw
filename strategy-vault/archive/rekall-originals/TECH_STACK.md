# NoteNest - Technical Stack & Architecture
**Last Updated:** March 12, 2026

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    iOS App (Swift/SwiftUI)               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │   Inbox    │  │   Search   │  │  Settings  │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└─────────────────────────────────────────────────────────┘
                         │ REST API
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Backend (Node.js/FastAPI)                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  Auth API  │  │ Sync Queue │  │ Search API │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└─────────────────────────────────────────────────────────┘
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  PostgreSQL  │  │    Redis     │  │   Pinecone   │
│  (main data) │  │   (cache)    │  │ (vector DB)  │
└──────────────┘  └──────────────┘  └──────────────┘
                         │
                         ▼
        ┌─────────────────────────────────┐
        │  External Services (APIs)        │
        │  • Telegram Bot API              │
        │  • Notion API                    │
        │  • Twitter/X API                 │
        │  • Reddit API                    │
        │  • Anthropic API (Claude)        │
        │  • AssemblyAI (transcription)    │
        │  • Voyage AI (embeddings)        │
        │  • AWS S3 (media storage)        │
        └─────────────────────────────────┘
```

---

## Frontend (iOS)

### Core Framework
**Swift + SwiftUI**

**Why SwiftUI?**
- ✅ Modern, declarative UI
- ✅ Native performance
- ✅ Less code than UIKit
- ✅ Built-in dark mode, accessibility
- ✅ Works on iPhone, iPad, Mac (future expansion easy)

**Minimum iOS Version:** 16.0 (covers 95%+ of users as of 2026)

### Key iOS Frameworks

#### 1. **Speech Framework** (Voice Capture)
```swift
import Speech

// Real-time transcription
let recognizer = SFSpeechRecognizer()
let request = SFSpeechAudioBufferRecognitionRequest()
```

**Use Case:**
- Voice capture in app
- Send audio to backend → OpenAI Whisper API
- Display transcription in real-time

---

#### 2. **Vision Framework** (OCR)
```swift
import Vision

// OCR on screenshots
let request = VNRecognizeTextRequest { request, error in
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}
```

**Use Case:**
- Screenshot OCR
- Image text extraction
- On-device processing (privacy + speed)

---

#### 3. **ShareExtension** (Quick Capture)
```swift
// iOS Share Sheet integration
// User can share from ANY app → NoteNest

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Extract shared item
        // Send to NoteNest backend
    }
}
```

**Use Case:**
- Share URL from Safari → NoteNest
- Share image from Photos → NoteNest
- Share text from Notes → NoteNest

---

#### 4. **Combine** (Reactive Data Flow)
```swift
import Combine

// Real-time search updates
@Published var searchQuery: String = ""
var cancellables = Set<AnyCancellable>()

$searchQuery
    .debounce(for: 0.3, scheduler: RunLoop.main)
    .sink { query in
        // Trigger search API call
    }
    .store(in: &cancellables)
```

**Use Case:**
- Real-time search (debounced)
- Data sync (reactive updates)
- UI updates on data changes

---

### UI/UX Principles

#### 1. **ADHD-Friendly Design**
- **No nested folders** (search-first, tags only)
- **Haptic feedback** (tactile confirmation)
- **Dark mode default** (less eye strain)
- **Minimal chrome** (focus on content, not UI)
- **Instant feedback** (no loading spinners unless >2sec)

#### 2. **Search-First**
- Search bar = top of screen always
- No "organize" pressure
- Tags optional (AI suggests, user confirms)

#### 3. **Quick Capture**
- Voice capture = 1 tap (mic button always visible)
- Share sheet integration
- Camera scan (for physical notes)

---

### Data Persistence (Offline Mode)

**Core Data** (Apple's local database)
```swift
import CoreData

// Cache recent notes for offline access
@FetchRequest(entity: Note.entity(), sortDescriptors: [])
var notes: FetchedResults<Note>
```

**Use Case:**
- Offline search (last 100 notes cached)
- Queue for sync when back online
- Smooth UX (no "loading..." on every open)

---

## Backend

### Option 1: **Node.js + Express** (Recommended)
**Why Node.js?**
- ✅ JavaScript (same as frontend web later)
- ✅ Fast for I/O-heavy tasks (API calls)
- ✅ npm ecosystem (tons of API client libraries)
- ✅ Easy to hire developers

**Tech Stack:**
- **Framework:** Express.js
- **Language:** TypeScript (type safety)
- **ORM:** Prisma (clean database queries)
- **Testing:** Jest

**Example:**
```typescript
import express from 'express';
import { PrismaClient } from '@prisma/client';

const app = express();
const prisma = new PrismaClient();

app.post('/api/notes', async (req, res) => {
  const { userId, content, sourceType } = req.body;
  
  // Save note
  const note = await prisma.note.create({
    data: { userId, content, sourceType }
  });
  
  // Generate embedding (async job with Voyage AI)
  await generateEmbedding(note.id, content);
  
  res.json(note);
});

app.listen(3000);
```

---

### Option 2: **Python + FastAPI** (Alternative)
**Why Python?**
- ✅ Great for AI/ML (OpenAI library, embeddings)
- ✅ FastAPI = modern, fast, auto-docs
- ✅ Strong data processing libraries (pandas, numpy)

**Tech Stack:**
- **Framework:** FastAPI
- **Language:** Python 3.11+
- **ORM:** SQLAlchemy
- **Testing:** pytest

**Example:**
```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class Note(BaseModel):
    user_id: str
    content: str
    source_type: str

@app.post("/api/notes")
async def create_note(note: Note):
    # Save to database
    db_note = save_note(note)
    
    # Generate embedding (async)
    await generate_embedding(db_note.id, note.content)
    
    return db_note
```

---

### API Design

**RESTful Endpoints:**

#### Auth
- `POST /auth/signup` - Create account
- `POST /auth/login` - Login
- `POST /auth/refresh` - Refresh token
- `POST /auth/logout` - Logout

#### Notes
- `GET /api/notes` - List user's notes (paginated)
- `POST /api/notes` - Create note
- `GET /api/notes/:id` - Get single note
- `PATCH /api/notes/:id` - Update note (tags, title, etc.)
- `DELETE /api/notes/:id` - Delete note

#### Search
- `GET /api/search?q=query&source=instagram&date=2025-01` - Search notes

#### Sources
- `GET /api/sources` - List connected sources
- `POST /api/sources` - Connect new source (OAuth)
- `DELETE /api/sources/:id` - Disconnect source
- `POST /api/sources/:id/sync` - Trigger manual sync

#### Sync
- `POST /api/sync/telegram` - Webhook for Telegram updates
- `POST /api/sync/discord` - Webhook for Discord updates

---

## Database

### PostgreSQL (Main Database)

**Why PostgreSQL?**
- ✅ Reliable, mature
- ✅ Full-text search built-in
- ✅ JSON columns (flexible metadata)
- ✅ Great for structured data

**Hosting Options:**
- **Supabase** (Postgres + auth + storage) - $25/mo
- **Railway** (Postgres managed) - $5-20/mo
- **AWS RDS** (production scale) - $50-200/mo

**Schema:**
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    subscription_tier VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE connected_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    source_type VARCHAR(50) NOT NULL, -- 'telegram', 'notion', etc.
    auth_token TEXT, -- encrypted
    sync_enabled BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMP,
    metadata JSONB, -- source-specific config
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    source_id UUID REFERENCES connected_sources(id) ON DELETE SET NULL,
    source_item_id VARCHAR(255), -- original ID in source
    content_type VARCHAR(50), -- 'text', 'audio', 'video', 'image', 'link'
    title TEXT,
    body TEXT, -- full text content
    summary TEXT, -- AI-generated
    media_url TEXT, -- S3 path if applicable
    original_url TEXT, -- link back to source
    tags TEXT[], -- array of tags
    captured_at TIMESTAMP, -- when user originally saved it
    imported_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB, -- source-specific fields
    tsv TSVECTOR -- full-text search vector
);

CREATE INDEX notes_tsv_idx ON notes USING GIN(tsv);
CREATE INDEX notes_user_id_idx ON notes(user_id);
CREATE INDEX notes_captured_at_idx ON notes(captured_at DESC);

CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7), -- hex color
    auto_assigned BOOLEAN DEFAULT false,
    UNIQUE(user_id, name)
);
```

---

### Redis (Cache & Queue)

**Why Redis?**
- ✅ Fast (in-memory)
- ✅ Great for session management
- ✅ Rate limiting
- ✅ Job queues (with BullMQ)

**Use Cases:**
1. **Session cache** (JWT tokens)
2. **API rate limiting** (Notion = 3 req/sec)
3. **Job queue** (background sync tasks)
4. **Search result cache** (popular queries)

**Hosting:**
- **Upstash** (serverless Redis) - $0.20/100K requests
- **Redis Cloud** - $5-50/mo
- **Railway** - $5-20/mo

**Example (Rate Limiting):**
```javascript
import Redis from 'ioredis';
const redis = new Redis();

async function checkRateLimit(userId, limit = 10) {
  const key = `rate_limit:${userId}`;
  const current = await redis.incr(key);
  
  if (current === 1) {
    await redis.expire(key, 60); // 1 minute window
  }
  
  return current <= limit;
}
```

---

### Pinecone (Vector Database)

**Why Pinecone?**
- ✅ Purpose-built for vector search (semantic search)
- ✅ Fast (sub-100ms queries)
- ✅ Scales automatically
- ✅ Easy to integrate

**Pricing:**
- Starter: Free (100K vectors, 1 pod)
- Standard: $70/mo (5M vectors)

**Alternative:** Weaviate (self-hosted, cheaper at scale)

**How It Works:**
1. Note content → Voyage AI embedding (1024-dimension vector)
2. Store vector in Pinecone with metadata
3. User searches → query embedding
4. Pinecone finds similar vectors (cosine similarity)
5. Return note IDs → fetch full notes from Postgres

**Example:**
```javascript
import { PineconeClient } from '@pinecone-database/pinecone';

const pinecone = new PineconeClient();
await pinecone.init({ apiKey: process.env.PINECONE_API_KEY });

const index = pinecone.Index('notenest-notes');

// Insert note embedding
await index.upsert({
  upsertRequest: {
    vectors: [{
      id: noteId,
      values: embedding, // 1024-dim vector from Voyage AI
      metadata: { userId, sourceType, capturedAt }
    }]
  }
});

// Search
const queryEmbedding = await getEmbedding(userQuery);
const results = await index.query({
  queryRequest: {
    vector: queryEmbedding,
    topK: 20,
    filter: { userId: 'user123' }
  }
});
```

---

## AI/ML Services

### 1. Anthropic API

#### **Claude 3.5 Sonnet** (Summarization & Categorization)
**Use Cases:**
- Summarize long articles/videos
- Suggest tags/categories
- Extract key points
- Smart content analysis

**Cost:** $3/1M input tokens, $15/1M output tokens

**Why Sonnet?**
- ✅ Best quality-to-cost ratio (better than GPT-4 for most tasks)
- ✅ 200K context window (can summarize entire articles in one shot)
- ✅ Excellent at nuanced understanding (catches context GPT misses)
- ✅ Fast enough for real-time use
- ✅ Superior instruction-following

**Alternative:** Claude 3.5 Haiku ($1/$5 per 1M) for cost optimization on simple tasks

**Example:**
```javascript
import Anthropic from '@anthropic-ai/sdk';
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

async function summarize(text) {
  const response = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 150,
    messages: [{
      role: 'user',
      content: `Summarize this in 3 bullet points:\n\n${text}`
    }]
  });
  
  return response.content[0].text;
}
```

---

### 2. Voyage AI (Embeddings)

#### **voyage-3** (Semantic Search)
**Use Cases:**
- Convert notes to vectors for search
- Find similar notes

**Cost:** $0.06/1M tokens (2x OpenAI, but better retrieval quality)

**Why Voyage 3?**
- ✅ Recommended by Anthropic
- ✅ Best-in-class retrieval performance (beats OpenAI on MTEB benchmarks)
- ✅ 1024-dim vectors (richer representations)
- ✅ Better multilingual support (if needed later)

**Example:**
```javascript
import voyage from 'voyageai';
const vo = voyage.Client({ apiKey: process.env.VOYAGE_API_KEY });

async function getEmbedding(text) {
  const response = await vo.embed({
    model: 'voyage-3',
    input: [text]
  });
  
  return response.embeddings[0]; // 1024-dim vector
}
```

**Alternative:** `voyage-3-lite` (half the cost at $0.03/1M, slightly lower quality)

---

### 3. AssemblyAI (Transcription)

#### **Best Model** (Speech-to-Text)
**Use Cases:**
- Voice memos → text
- Video audio → transcript
- Speaker diarization (who said what)

**Cost:** $0.00025/second = $0.015/minute (2.5x cheaper than Whisper!)

**Why AssemblyAI?**
- ✅ Cheaper than OpenAI Whisper
- ✅ Real-time transcription option
- ✅ Auto punctuation, speaker labels
- ✅ Sentiment analysis (optional)

**Example:**
```javascript
import { AssemblyAI } from 'assemblyai';
const client = new AssemblyAI({ apiKey: process.env.ASSEMBLYAI_API_KEY });

async function transcribe(audioUrl) {
  const transcript = await client.transcripts.transcribe({
    audio_url: audioUrl,
    language_code: 'en'
  });
  
  return transcript.text;
}
```

**Alternative:** Deepgram ($0.0043/min, real-time streaming)

---

### 4. Google Cloud Vision (OCR Fallback)
**Use Cases:**
- Screenshot OCR (if Apple Vision fails)
- Handwritten text recognition

**Cost:** $1.50/1K images (first 1K free/month)

**Alternative:** Use Apple Vision on-device (free, faster, private)

---

## Third-Party Integrations

### 1. Telegram Bot API
**Docs:** core.telegram.org/bots/api  
**Difficulty:** Easy ⭐⭐⭐⭐⭐

**Setup:**
1. Create bot with BotFather
2. Get API token
3. Set webhook: `POST https://api.telegram.org/bot<token>/setWebhook`
4. Receive updates on your backend endpoint

**Example:**
```javascript
app.post('/api/sync/telegram', async (req, res) => {
  const { message } = req.body;
  
  if (message.text) {
    // Save text note
    await saveNote(message.from.id, message.text, 'telegram');
  }
  
  if (message.voice) {
    // Download voice file, transcribe
    const audioUrl = await getTelegramFileUrl(message.voice.file_id);
    const transcript = await transcribe(audioUrl);
    await saveNote(message.from.id, transcript, 'telegram');
  }
  
  res.sendStatus(200);
});
```

---

### 2. Notion API
**Docs:** developers.notion.com  
**Difficulty:** Medium ⭐⭐⭐

**Setup:**
1. Create Notion integration
2. OAuth flow to get user's token
3. Read databases, write pages

**Rate Limit:** 3 requests/second (manage with Redis queue)

**Example:**
```javascript
import { Client } from '@notionhq/client';

const notion = new Client({ auth: userToken });

// Fetch database items
const response = await notion.databases.query({
  database_id: userDatabaseId
});

// Create page
await notion.pages.create({
  parent: { database_id: userDatabaseId },
  properties: {
    Title: { title: [{ text: { content: noteTitle } }] }
  }
});
```

---

### 3. Twitter/X API
**Docs:** developer.twitter.com/en/docs/twitter-api  
**Difficulty:** Medium ⭐⭐⭐

**Setup:**
1. Apply for developer account
2. OAuth 2.0 flow
3. Access bookmarks endpoint

**API v2 Endpoint:**
- `GET /2/users/:id/bookmarks` (requires OAuth 2.0 with read permissions)

**Cost:** Free tier = 10K tweets/month read limit (should be enough)

**Example:**
```javascript
const response = await fetch(
  `https://api.twitter.com/2/users/${userId}/bookmarks`,
  {
    headers: { Authorization: `Bearer ${accessToken}` }
  }
);

const bookmarks = await response.json();
```

---

### 4. Instagram (API Limited - Scraping Needed)
**Docs:** developers.facebook.com/docs/instagram-basic-display-api  
**Difficulty:** Hard ⭐

**Problem:** Instagram Graph API does NOT expose saved posts

**Workaround:**
1. **Browser extension** (Chrome/Safari)
   - User installs extension
   - Extension scrapes saved posts on demand
   - Sends to NoteNest backend via secure API
2. **IFTTT/Zapier** (limited, user must manually trigger)

**Legal Note:** Check Instagram ToS - scraping may violate terms. Browser extension is user-initiated (safer).

---

### 5. Reddit API
**Docs:** reddit.com/dev/api  
**Difficulty:** Easy ⭐⭐⭐⭐

**Setup:**
1. Create Reddit app
2. OAuth flow
3. Access `/user/username/saved` endpoint

**Rate Limit:** 60 requests/minute

**Example:**
```javascript
const response = await fetch(
  `https://oauth.reddit.com/user/${username}/saved`,
  {
    headers: { Authorization: `Bearer ${accessToken}` }
  }
);

const saved = await response.json();
```

---

## Storage

### AWS S3 (Media Files)
**Use Cases:**
- Voice recordings (audio files)
- Video files
- Images/screenshots
- PDF attachments

**Cost:** $0.023/GB/month (first 50 TB)

**Example:**
```javascript
import AWS from 'aws-sdk';
const s3 = new AWS.S3();

// Upload file
await s3.putObject({
  Bucket: 'notenest-media',
  Key: `users/${userId}/${noteId}.mp3`,
  Body: audioBuffer,
  ContentType: 'audio/mpeg'
}).promise();

// Generate signed URL (expires in 1 hour)
const url = s3.getSignedUrl('getObject', {
  Bucket: 'notenest-media',
  Key: `users/${userId}/${noteId}.mp3`,
  Expires: 3600
});
```

**Alternative:** Cloudflare R2 (S3-compatible, cheaper egress)

---

## Background Jobs

### BullMQ (Job Queue)
**Use Cases:**
- Sync jobs (fetch new notes from sources)
- Embedding generation (CPU-intensive)
- AI summarization (rate-limited API calls)

**Why BullMQ?**
- ✅ Built on Redis
- ✅ Reliable (retries, failure handling)
- ✅ Dashboard (monitor jobs)

**Example:**
```javascript
import { Queue, Worker } from 'bullmq';

// Add job
const syncQueue = new Queue('sync', { connection: redis });
await syncQueue.add('syncTelegram', { userId, sourceId });

// Worker
const worker = new Worker('sync', async (job) => {
  if (job.name === 'syncTelegram') {
    await syncTelegramMessages(job.data.userId, job.data.sourceId);
  }
}, { connection: redis });
```

---

## Deployment

### Hosting Options

#### Option 1: **Railway** (Recommended for MVP)
**Why Railway?**
- ✅ Simple (one-click deploy)
- ✅ Affordable ($5-20/mo starting)
- ✅ Postgres + Redis included
- ✅ Auto-scaling
- ✅ GitHub integration (auto-deploy on push)

**Cost Estimate (MVP):**
- Backend app: $5/mo
- Postgres: $5/mo
- Redis: $5/mo
- **Total: $15/mo**

---

#### Option 2: **AWS (Production Scale)**
**Services:**
- **ECS/Fargate** (containerized backend)
- **RDS Postgres** (managed database)
- **ElastiCache Redis** (managed cache)
- **S3** (media storage)
- **CloudFront** (CDN for media)

**Cost Estimate (production):**
- ECS: $30-100/mo
- RDS: $50-200/mo
- ElastiCache: $30-100/mo
- S3: $10-50/mo
- **Total: $120-450/mo**

---

#### Option 3: **Fly.io** (Alternative to Railway)
**Why Fly?**
- ✅ Affordable
- ✅ Global edge network
- ✅ Postgres + Redis included

---

### CI/CD

**GitHub Actions** (free for public repos, $0.008/minute for private)

**Example Workflow:**
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
      - name: Build and push Docker image
        run: |
          docker build -t notenest-backend .
          docker push ghcr.io/notenest/backend
      - name: Deploy to Railway
        run: railway up
```

---

## Security

### 1. Authentication
**Firebase Auth** or **Clerk** (easiest)

**Why Firebase Auth?**
- ✅ Email/password + social login (Google, Apple)
- ✅ Free tier (50K MAU)
- ✅ SDKs for iOS + backend
- ✅ JWT tokens (stateless)

**Why Clerk?**
- ✅ Better UX (embeddable components)
- ✅ User management dashboard
- ✅ $25/mo (1,000 MAU) or free <10K MAU

---

### 2. API Security
- **JWT tokens** (stateless auth)
- **HTTPS only** (TLS 1.3)
- **Rate limiting** (Redis)
- **Input validation** (sanitize user input)

---

### 3. Data Encryption
- **Auth tokens encrypted at rest** (AES-256)
- **S3 media files encrypted** (SSE-S3)
- **Database encryption** (Postgres TDE)

---

### 4. OAuth Token Storage
**Problem:** Storing user's Notion/Telegram tokens securely

**Solution:**
1. Encrypt tokens with AES-256
2. Store encryption key in environment variable (not in code)
3. Use AWS KMS (Key Management Service) for production

---

## Monitoring & Logging

### Sentry (Error Tracking)
**Cost:** Free (5K errors/mo), $26/mo (50K errors)

**Use Case:**
- Backend crashes
- iOS app crashes
- API errors

---

### PostHog (Analytics)
**Cost:** Free (1M events/mo), $0/mo (open source self-hosted)

**Use Case:**
- User behavior tracking
- Feature usage metrics
- A/B testing

---

### Logtail (Logging)
**Cost:** Free (1 GB/mo), $5/mo (10 GB)

**Use Case:**
- Backend logs
- Debug production issues

---

## Cost Breakdown (Year 1)

### Infrastructure
| Service | Cost/Month | Annual |
|---------|-----------|--------|
| Railway (hosting) | $15 | $180 |
| Pinecone (vector DB) | $70 | $840 |
| AWS S3 (media) | $20 | $240 |
| Anthropic API (Sonnet) | $400 | $4,800 |
| Voyage AI (embeddings) | $30 | $360 |
| AssemblyAI (transcription) | $50 | $600 |
| Sentry (errors) | $26 | $312 |
| Domain + email | $10 | $120 |
| **Total** | **$621** | **$7,452** |

### With 1,000 users:
- AI costs scale: ~$600/mo = $7,200/year (Sonnet for quality)
- **Total: ~$14,400/year**

### Break-even with Sonnet: ~150 Pro users at $10/mo = $1,500/mo MRR

**Cost optimization strategy:**
- Use **Sonnet** for user-facing features (summaries, tags)
- Use **Haiku** for internal tasks (categorization, metadata extraction)
- Can reduce AI costs by 40-60% with smart model routing

### Break-even: ~100 Pro users at $10/mo = $1,000/mo MRR

---

## Performance Targets

### API Response Times
- **Search:** <300ms (p95)
- **Note create:** <200ms (p95)
- **Sync trigger:** <100ms (async job queued)

### App Metrics
- **Cold start:** <2 sec
- **Search results:** <500ms
- **Voice transcription:** <5 sec (depends on audio length)

---

## Scalability Plan

### Phase 1 (0-1K users)
- Railway hosting (sufficient)
- Pinecone Starter (100K vectors)
- Manual monitoring

### Phase 2 (1K-10K users)
- Migrate to AWS ECS
- Upgrade Pinecone ($70/mo → $140/mo)
- Add monitoring (Datadog or New Relic)

### Phase 3 (10K-100K users)
- Multi-region deployment (latency)
- Database read replicas
- CDN for media (CloudFront)
- Dedicated support team

---

## Development Tools

### Recommended Stack
- **Code editor:** VS Code
- **API testing:** Postman or Insomnia
- **Database GUI:** TablePlus (Postgres)
- **Git:** GitHub
- **Project management:** Linear or Notion
- **Design:** Figma (UI mockups)
- **iOS dev:** Xcode (required)

---

## Learning Resources (if CS builds solo)

### iOS Development
- **100 Days of SwiftUI** (free course by Paul Hudson)
- **Stanford CS193p** (SwiftUI course, free on YouTube)
- **Hacking with Swift** (tutorials + books)

### Backend Development
- **Node.js + Express tutorial** (freeCodeCamp)
- **Prisma docs** (excellent ORM docs)
- **BullMQ docs** (job queues)

### AI/ML
- **Anthropic docs** (Claude API examples)
- **Voyage AI docs** (embedding tutorials)
- **AssemblyAI docs** (transcription guides)
- **Pinecone docs** (vector search tutorials)

---

**END OF TECH STACK DOC**
