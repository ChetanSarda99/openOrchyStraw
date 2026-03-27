# Onboarding Guide

Welcome to Memo — the ADHD-focused universal note aggregator. This guide will get you from zero to running the full stack locally.

---

## Prerequisites

Install these before starting:

| Tool | Version | Purpose |
|------|---------|---------|
| **Node.js** | 20+ | Backend runtime |
| **npm** | Comes with Node | Package manager |
| **Xcode** | 15+ | iOS development (macOS only) |
| **Docker Desktop** | Latest | Local PostgreSQL + Redis |
| **Git** | Latest | Version control |

**Recommended editors:**

- **VS Code** for backend (TypeScript) — install the ESLint and Prettier extensions
- **Xcode** for iOS (Swift/SwiftUI)

---

## Architecture Overview

Memo has three main layers:

```
+------------------+       +------------------+       +------------------+
|                  |       |                  |       |                  |
|   iOS App        | <---> |   Backend API    | <---> |   Data Layer     |
|   Swift/SwiftUI  |  REST |   Node/Express   |       |   PostgreSQL     |
|   MVVM           |       |   TypeScript     |       |   Pinecone       |
|   iOS 17+        |       |                  |       |   Redis          |
|                  |       |                  |       |                  |
+------------------+       +------------------+       +------------------+
                                   |
                                   v
                           +------------------+
                           |                  |
                           |   AI Services    |
                           |   Claude 3.5     |
                           |   Voyage AI      |
                           |   AssemblyAI     |
                           |                  |
                           +------------------+
```

### iOS App (Swift + SwiftUI)

- **Pattern:** MVVM (Model-View-ViewModel)
- **Target:** iOS 17+
- **State:** `@Observable` macro, `@State`, `@Binding`, `@Environment`
- **Navigation:** `NavigationStack`
- **Networking:** `async/await` with `URLSession`

### Backend (Node.js + Express + TypeScript)

- **Framework:** Express.js with TypeScript in strict mode
- **ORM:** Prisma (type-safe database access)
- **Auth:** JWT tokens (access + refresh)
- **API style:** REST with JSON request/response bodies

### Data Layer

| Service | Role |
|---------|------|
| **PostgreSQL** | Primary database — users, notes, sources, metadata |
| **Pinecone** | Vector database — semantic search embeddings |
| **Redis** | Caching, rate limiting, background job queue |

### AI Services

| Service | Role |
|---------|------|
| **Claude 3.5 Sonnet** (Anthropic) | Note summarization, tagging, content understanding |
| **Voyage AI** | Text embeddings for semantic search |
| **AssemblyAI** | Voice memo transcription |

---

## Quick Start

### Step 1: Clone the repo

```bash
git clone https://github.com/ChetanSarda99/memo-app.git
cd memo-app
```

### Step 2: Start the database

```bash
docker compose up -d
```

This starts PostgreSQL and Redis in Docker containers. Verify they're running:

```bash
docker compose ps
```

You should see both containers with status `Up`.

### Step 3: Set up the backend

```bash
cd backend

# Copy environment template
cp .env.example .env
```

Open `backend/.env` and fill in your API keys:

```env
DATABASE_URL="postgresql://memo:memo@localhost:5432/memo?schema=public"
REDIS_URL="redis://localhost:6379"
ANTHROPIC_API_KEY="sk-ant-..."
VOYAGE_API_KEY="pa-..."
ASSEMBLYAI_API_KEY="..."
PINECONE_API_KEY="..."
JWT_SECRET="generate-with-openssl-rand-hex-32"
```

Then install dependencies and run migrations:

```bash
npm install
npm run migrate   # Apply database schema
npm run dev       # Start dev server at localhost:3000
```

You should see:

```
Server running on http://localhost:3000
```

### Step 4: Set up the iOS app

```bash
cd ios
open Memo.xcodeproj
```

In Xcode:

1. Select an iPhone simulator from the device dropdown (iPhone 15 or newer recommended)
2. Press **Cmd+R** or click the Run button
3. The app should build and launch in the simulator

> **Note:** The iOS app is in early development. If the `ios/` directory is empty or the project doesn't exist yet, skip this step for now and focus on backend work.

### Step 5: Verify everything works

- Backend: Open `http://localhost:3000/health` in your browser — you should get a JSON response
- Database: Run `cd backend && npm run studio` to open Prisma Studio and browse the database
- iOS: The app should display on the simulator

---

## Key Files to Know

These are the files you'll interact with most:

### Backend

| File | Purpose |
|------|---------|
| `backend/src/index.ts` | API entry point — Express server setup, middleware, route mounting |
| `backend/prisma/schema.prisma` | Database schema — all tables, relations, and indexes |
| `backend/.env.example` | Template for required environment variables |
| `backend/src/routes/` | Route definitions — URL paths mapped to controllers |
| `backend/src/controllers/` | Request handlers — parse input, call services, return responses |
| `backend/src/services/` | Business logic — core functionality, external API calls |
| `backend/src/middleware/` | Express middleware — auth, validation, error handling |

### iOS

| File | Purpose |
|------|---------|
| `ios/Memo/` | Main iOS app directory |
| `ios/Memo/Models/` | Data models |
| `ios/Memo/Views/` | SwiftUI views |
| `ios/Memo/ViewModels/` | View models (business logic for views) |
| `ios/Memo/Services/` | API client, persistence, integrations |

### Project-Wide

| File | Purpose |
|------|---------|
| `docs/` | All documentation — specs, research, guides |
| `CONVENTIONS.md` | Code style guide and conventions |
| `ARCHITECTURE.md` | System design and architecture decisions |
| `CONTRIBUTING.md` | How to contribute (branching, PRs, standards) |
| `CLAUDE.md` | AI assistant instructions |

---

## API Overview (Planned)

The backend exposes these REST endpoints (some may not be implemented yet):

### Authentication

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/auth/register` | Create a new account |
| `POST` | `/auth/login` | Login and receive JWT tokens |
| `POST` | `/auth/refresh` | Refresh an expired access token |

### Notes

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/notes` | List the current user's notes (paginated) |
| `POST` | `/notes` | Create a new note |
| `GET` | `/notes/:id` | Get a single note by ID |
| `PUT` | `/notes/:id` | Update a note |
| `DELETE` | `/notes/:id` | Delete a note |

### Search

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/search` | Semantic search across all notes |

Request body:

```json
{
  "query": "that restaurant idea from last week",
  "limit": 20,
  "sources": ["telegram", "notion"]
}
```

### Sources (Integrations)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/sources` | List connected sources |
| `POST` | `/sources/:type/connect` | Connect a new data source (Telegram, Notion, etc.) |
| `DELETE` | `/sources/:id/disconnect` | Disconnect a source |
| `POST` | `/sources/:id/sync` | Trigger a manual sync for a source |

All endpoints (except auth) require a valid JWT in the `Authorization` header:

```
Authorization: Bearer <access_token>
```

---

## Common Tasks

### Add a new API endpoint

1. **Route:** Create or update a file in `backend/src/routes/` to define the URL path
2. **Controller:** Add a handler in `backend/src/controllers/` to parse the request and call the service
3. **Service:** Add business logic in `backend/src/services/`
4. **Types:** Define request/response interfaces in `backend/src/types/`
5. **Test:** Write a test in `backend/src/__tests__/`

Example structure for a new `tags` feature:

```
backend/src/
  routes/tags.ts          # Router: GET /tags, POST /tags
  controllers/tags.ts     # parseRequest -> callService -> sendResponse
  services/tags.ts        # createTag(), listTags(), etc.
  types/tags.ts           # TagCreateRequest, TagResponse interfaces
  __tests__/tags.test.ts  # Jest tests
```

### Add a new integration (data source)

1. Create the integration service: `backend/src/services/integrations/<source>.ts`
2. Add required API credentials to `backend/.env.example`
3. Add source-specific fields to the Prisma schema if needed
4. Create or update the sync route in `backend/src/routes/sync.ts`
5. Build the iOS connect screen: `ios/Memo/Views/Integrations/<Source>ConnectView.swift`

### Modify the database schema

1. Edit `backend/prisma/schema.prisma`
2. Create a migration:

```bash
cd backend
npx prisma migrate dev --name describe_your_change
```

3. The migration SQL is saved in `backend/prisma/migrations/`
4. Prisma Client is regenerated automatically — your TypeScript types update instantly

### Run tests

```bash
# All backend tests
cd backend && npm test

# Specific test file
cd backend && npx jest --testPathPattern=search

# Watch mode (re-runs on file changes)
cd backend && npm run test:watch

# Coverage report
cd backend && npm run test:coverage
```

---

## Environment Details

### Ports

| Service | Port | URL |
|---------|------|-----|
| Backend API | 3000 | `http://localhost:3000` |
| PostgreSQL | 5432 | `postgresql://localhost:5432/memo` |
| Redis | 6379 | `redis://localhost:6379` |
| Prisma Studio | 5555 | `http://localhost:5555` |

### Docker Containers

| Container | Image | Purpose |
|-----------|-------|---------|
| `memo-postgres` | `postgres:16` | Primary database |
| `memo-redis` | `redis:7-alpine` | Cache and job queue |

---

## Getting Help

1. **Check the docs.** The `docs/` folder has detailed specs, research, and architecture docs.
2. **Read ARCHITECTURE.md.** Understand how the pieces fit together before diving into code.
3. **Review CONVENTIONS.md.** Follow established patterns so your code fits in.
4. **Read CONTRIBUTING.md.** Understand the git workflow and PR process.
5. **Ask in the team chat.** No question is too small — especially when you're ramping up.

---

## First Contribution Checklist

- [ ] Cloned the repo and can see the project structure
- [ ] Docker containers running (PostgreSQL + Redis)
- [ ] Backend starts without errors (`npm run dev`)
- [ ] Read `ARCHITECTURE.md` and `CONVENTIONS.md`
- [ ] Read `docs/PRODUCT_SPEC.md` to understand what Memo does
- [ ] Created a test branch and made a trivial change to verify your git setup
- [ ] Opened and merged your first PR
