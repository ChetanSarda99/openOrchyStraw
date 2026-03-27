# Memo — MacBook Migration & Xcode Demo Guide

**For:** CS (or a new Claude session on macOS)
**Context:** Project was built on Windows 11 using Claude Code. This guide gets it running on macOS with Xcode for iOS development and demo.
**Last Updated:** March 13, 2026

---

## What Is This Project?

**Memo** is an ADHD-first universal note aggregator iOS app. It pulls saved content from Telegram, Notion, Instagram, Reddit, Twitter, and voice memos into one searchable place. AI categorizes everything into Wheel of Life dimensions.

- **Repo:** github.com/ChetanSarda99/memo-app (private)
- **Owner:** CS — solo developer, learning Swift, experienced JS/TS
- **Revenue Model:** Freemium — Free (3 sources) / Pro $9.99/mo
- **Full instructions:** Read `CLAUDE.md` in the project root first — it overrides defaults

---

## Pre-Migration Checklist (Do on Windows Before Moving)

- [ ] All changes committed and pushed to GitHub
- [ ] `.env` values documented somewhere safe (NOT in git)
- [ ] Supabase project credentials saved: project ID `mmdbizllhnmeiimvkrtf`, region `us-east-1`
- [ ] Figma file URL saved: `https://www.figma.com/design/ldM6tmXgUiSGZuaGX3dMiy/Untitled?node-id=0-1`
- [ ] This document is in the repo (`docs/MACBOOK_MIGRATION.md`)

---

## Phase 1: macOS Environment Setup (30-45 min)

### 1.1 Install Xcode
```bash
# From Mac App Store — download is ~12GB, install takes 20-30 min
# OR from developer.apple.com/download
# Minimum: Xcode 15.0+ (for iOS 17 support)

# After install, accept license and install CLI tools:
sudo xcodebuild -license accept
xcode-select --install
```

### 1.2 Install Homebrew + Dev Tools
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (Apple Silicon Macs)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Node.js, Docker, Git, PostgreSQL client
brew install node@20 git postgresql@17
brew install --cask docker

# Verify
node --version   # Should be 20.x
git --version
psql --version
```

### 1.3 Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### 1.4 Install iOS Simulators
```bash
# Open Xcode → Settings → Platforms → Download iOS 17 Simulator
# OR from command line:
xcodebuild -downloadPlatform iOS
```

---

## Phase 2: Clone & Set Up Project (15 min)

### 2.1 Clone the Repo
```bash
cd ~/Desktop/Projects  # or wherever you keep projects
git clone https://github.com/ChetanSarda99/memo-app.git Memo
cd Memo
```

**OR if copying the folder directly from Windows:**
```bash
# Just copy the entire Memo/ folder to ~/Desktop/Projects/Memo
# Then fix git if needed:
cd ~/Desktop/Projects/Memo
git status  # Should show clean working tree
```

### 2.2 Backend Setup
```bash
# Start Docker Desktop first (from Applications)
# Wait for Docker to be ready, then:

cd backend
npm install

# Create .env from template
cp .env.example .env
```

Edit `backend/.env` with real values:
```env
# Server
PORT=3000
NODE_ENV=development

# Supabase
SUPABASE_URL=https://mmdbizllhnmeiimvkrtf.supabase.co
SUPABASE_ANON_KEY=<get from Supabase dashboard → Settings → API>
SUPABASE_SERVICE_ROLE_KEY=<get from Supabase dashboard → Settings → API>

# Database (use Supabase's hosted PostgreSQL)
DATABASE_URL=postgresql://postgres.<project-ref>:<password>@aws-0-us-east-1.pooler.supabase.com:6543/postgres

# OR use local Docker PostgreSQL:
# DATABASE_URL=postgresql://postgres:postgres@localhost:5432/memo

# Redis
REDIS_URL=redis://localhost:6379

# AI (add when ready to test AI features)
# ANTHROPIC_API_KEY=
# VOYAGE_API_KEY=
# ASSEMBLYAI_API_KEY=
```

### 2.3 Database Setup

**Option A: Use Supabase hosted DB (recommended for demo)**
```bash
# Just run migrations against Supabase
cd backend
npx prisma migrate deploy
npx prisma generate

# Apply vector indexes
psql $DATABASE_URL -f prisma/post-migration.sql
```

**Option B: Use local Docker DB**
```bash
# From project root
docker compose up -d   # Starts PostgreSQL + Redis

cd backend
npx prisma migrate dev --name init
npx prisma generate

# Apply vector indexes
psql postgresql://postgres:postgres@localhost:5432/memo -f prisma/post-migration.sql
```

### 2.4 Verify Backend Starts
```bash
cd backend
npm run dev

# Should see: Memo API running on http://localhost:3000
# Test: curl http://localhost:3000
# Should return: {"name":"Memo API","version":"1.0.0","status":"running"}
```

---

## Phase 3: iOS Project in Xcode (10-15 min)

### 3.1 Open in Xcode
```bash
cd ~/Desktop/Projects/Memo/ios/Memo
open -a Xcode .

# OR if there's a .xcodeproj or .xcworkspace:
# open Memo.xcodeproj
# open Memo.xcworkspace
```

**If no Xcode project exists yet** (project was scaffolded but not created in Xcode):
1. Open Xcode
2. File → New → Project
3. iOS → App
4. Product Name: Memo
5. Team: Your Apple Developer account (free works for simulator)
6. Organization Identifier: com.chetansarda (or your bundle ID)
7. Interface: SwiftUI
8. Language: Swift
9. Storage: SwiftData
10. Save to: `~/Desktop/Projects/Memo/ios/`
11. After creation, drag existing Swift files into the Xcode project navigator

### 3.2 Add Swift Package Dependencies
In Xcode: File → Add Package Dependencies

| Package | URL | Version |
|---------|-----|---------|
| Supabase Swift SDK | `https://github.com/supabase/supabase-swift` | Latest (1.x) |

### 3.3 Configure Supabase in iOS
Edit `ios/Memo/Utilities/Constants.swift`:
```swift
enum Constants {
    static let supabaseURL = "https://mmdbizllhnmeiimvkrtf.supabase.co"
    static let supabaseAnonKey = "<your-anon-key>"
    static let apiBaseURL = "http://localhost:3000"  // For simulator
}
```

### 3.4 Build & Run on Simulator
1. Select target: iPhone 15 Pro (or any iOS 17+ simulator)
2. Cmd+B to build (fix any errors)
3. Cmd+R to run
4. App should launch in simulator showing the Search tab

### 3.5 Common Xcode Issues

**"No such module 'Supabase'"**
→ File → Packages → Reset Package Caches, then Cmd+B

**Build errors from files not in target**
→ Select file in navigator → check Target Membership in right panel

**Simulator can't reach localhost**
→ Backend must be running. Use `http://localhost:3000` (not 127.0.0.1)

**Missing provisioning profile**
→ For simulator only: no profile needed. For device: need Apple Developer account.

**SwiftData model errors**
→ Clean build folder (Cmd+Shift+K), then rebuild

---

## Phase 4: Demo Walkthrough

### What Should Work (depending on build state)
1. **App launches** → Shows login screen or main tab view
2. **Tab navigation** → Search, Capture, Settings tabs
3. **Search screen** → Search bar + note cards (if backend is running with seed data)
4. **Categories screen** → Wheel of Life grid with 8 dimensions
5. **Settings** → Account, Connected Sources, Appearance toggle
6. **Login/SignUp** → Supabase auth (if wired up)

### Seed Demo Data (Optional)
```bash
# If you want demo notes in the database for the demo:
cd backend
npx prisma db seed
# OR manually via Supabase SQL editor
```

---

## Project State When This Doc Was Written (Mar 13, 2026)

### What Exists
| Component | Status | Details |
|-----------|--------|---------|
| Backend scaffold | Built | Express + Prisma + TypeScript, search route + AI services |
| Prisma schema | Done | User, ConnectedSource, Note, Category, NoteCategory + pgvector |
| iOS project | Built | 22 Swift files, MVVM architecture, @Observable, NavigationStack |
| Auth middleware | Partial | Supabase JWT verification exists |
| Notes CRUD API | NOT built | No routes/controllers — #10 open |
| Sources CRUD API | NOT built | No routes/controllers — #12 open |
| Design system | Extracted | Tokens extracted from Figma, needs SwiftUI implementation |
| UI components | NOT built | #32 was blocked on Figma, now unblocked |
| Supabase project | Active | mmdbizllhnmeiimvkrtf, us-east-1, no public tables yet |
| Figma designs | Done | 5 screens: Search, Login, Capture, Settings, Categories |
| Docker Compose | Done | PostgreSQL (pgvector) + Redis |
| CI/CD | Done | GitHub Actions |

### What 02 (Backend) Session Should Have Built by Now
If CS ran the backend prompts, these should exist:
- `backend/src/routes/notes.ts` — Notes CRUD
- `backend/src/routes/sources.ts` — Sources CRUD
- `backend/src/routes/users.ts` — User profile
- Database tables created via Prisma migration

### What 03 (iOS) Session Should Have Built by Now
If CS ran the iOS prompts, these should exist:
- `ios/Memo/Utilities/MemoTheme.swift` — Design tokens
- `ios/Memo/Views/Components/MemoSearchBar.swift`
- `ios/Memo/Views/Components/MemoNoteCard.swift`
- `ios/Memo/Views/Components/MemoTag.swift`
- `ios/Memo/Views/Components/MemoCategoryCard.swift`
- Updated screen views with real design system

### GitHub Issue Status (as of Mar 13)
- M1.1 Project Setup: **DONE** (4/4 closed)
- M1.2 Backend Core: **IN PROGRESS** (2/6 closed — #6, #20 done, #8, #10, #12, #18 open)
- M1.3 iOS Foundation: **IN PROGRESS** (4/6 closed — #30, #31, #33, #34 done, #32 open)
- M1.4 AI Categorization: **SCAFFOLDED** (0/5 closed, code exists but not wired)

Check latest: `gh issue list --repo ChetanSarda99/memo-app --state open --limit 100`

---

## Key Files to Read First

A new Claude session should read these in order:
1. `CLAUDE.md` — Project rules, tech stack, design system, anti-slop rules
2. `docs/MACBOOK_MIGRATION.md` — This file
3. `prompts/01_project_manager.txt` — PM role and full project status
4. `prompts/99_me.txt` — CS manual action items
5. `ARCHITECTURE.md` — System design
6. `docs/DECISIONS.md` — 8 Architecture Decision Records

### Agent Session Prompts
The prompts/ folder contains role-specific prompts:
- `01_project_manager.txt` — PM (plans, tracks, generates prompts for others)
- `02_developer.txt` — Backend Node.js/TypeScript
- `03_ios_developer.txt` — iOS Swift/SwiftUI
- `04_figma_designer.txt` — Figma design system
- `99_me.txt` — CS manual action items (design tools, accounts, etc.)

Paste any of these into a new Claude Code session to resume that role.

---

## Design Reference

**Figma URL:** https://www.figma.com/design/ldM6tmXgUiSGZuaGX3dMiy/Untitled?node-id=0-1

Screen node IDs (for Figma MCP get_design_context):
- Search: `1:2`
- Login: `2:2`
- Capture: `3:65`
- Settings: `3:602`
- Categories: `3:730`

fileKey: `ldM6tmXgUiSGZuaGX3dMiy`

---

## Quick Start Summary (TL;DR)

```bash
# 1. Clone
git clone https://github.com/ChetanSarda99/memo-app.git Memo && cd Memo

# 2. Backend
cd backend && npm install && cp .env.example .env
# Edit .env with Supabase creds
docker compose up -d
npx prisma migrate deploy && npx prisma generate
npm run dev

# 3. iOS (in new terminal)
cd ios/Memo && open -a Xcode .
# Add Supabase Swift SDK via SPM
# Select iPhone 15 Pro simulator
# Cmd+R to run

# 4. Verify
# Backend: curl http://localhost:3000 → {"status":"running"}
# iOS: App launches in simulator with tab navigation
```

---

**This doc is self-contained. A new Claude session reading this + CLAUDE.md has full context to continue the project on macOS.**
