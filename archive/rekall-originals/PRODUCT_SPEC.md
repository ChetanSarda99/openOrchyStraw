# NoteNest - Product Specification
**Version 1.0** | **Last Updated:** March 12, 2026

---

## Executive Summary

**Tagline:** "Your brain's external hard drive. One search bar for everything you've ever saved."

**Problem:** ADHD brains generate tons of creative ideas saved across 10+ apps. Finding them later = impossible.

**Solution:** NoteNest connects to ALL your note/save sources via APIs. One universal search bar. AI summarization. Auto-sync to Notion/Obsidian with your templates. iPhone-first, multimodal (text/audio/video/images).

**Target:** ADHD creatives, students, knowledge workers drowning in saved content

**Business Model:** Freemium (3 sources free) → Pro ($10/mo unlimited)

**Differentiation:** Only app that does ALL: social media saved posts + messaging apps + note apps + multimodal + AI + bidirectional Notion/Obsidian sync

---

## Core Value Propositions

### 1. "The single best thing you can do for your brain"
- Offload memory burden to external system
- Never lose an idea again
- Cognitive load reduction for ADHD brains

### 2. "Struggle with ADHD and lots of creative ideas?"
- Built FOR ADHD users BY ADHD user (founder story)
- No complex folder hierarchies
- Just search, it finds it

### 3. "'I thought about that before but don't know where it went'"
- The pain point everyone feels
- Happens less often with age/ADHD
- NoteNest eliminates it entirely

### 4. "Type anything anywhere, access in one place"
- The solution promise
- Universal inbox approach
- Platform-agnostic

---

## Feature Set

### Phase 1 MVP (Months 1-2)
**Goal:** Prove core value with 3 most common sources

1. **Telegram Integration**
   - Saved messages
   - Voice memos (auto-transcribed)
   - Images (OCR'd)
   - Videos (transcript if speech)
   - Links/articles

2. **Notion Integration** (read + write)
   - Connect to any database
   - Custom template mapping
   - Bidirectional sync
   - Full-text search across all pages

3. **Voice Capture**
   - iOS voice recording
   - Auto-transcribe (Whisper API)
   - Timestamp + searchable

4. **Universal Search**
   - Semantic search (vector embeddings)
   - Search across all connected sources
   - Instant results
   - Preview snippets

5. **Quick Capture**
   - iOS share sheet integration
   - From any app → NoteNest inbox
   - Auto-categorize with AI

### Phase 2 (Month 3)
**Goal:** Add social media sources

6. **Instagram Saved Posts**
   - Scrape saved posts (Graph API limited, may need web scraping)
   - Image + caption + comments
   - Original link preserved

7. **Facebook Saved Posts**
   - Article links
   - Videos
   - Posts
   - (API limited - may need browser extension fallback)

8. **LinkedIn Saved Posts**
   - Articles
   - Posts
   - Job listings
   - (API unclear - LinkedMash competitor exists, research needed)

9. **Twitter/X Bookmarks**
   - Tweets
   - Threads
   - Images/videos

10. **AI Summarization**
    - Long articles → key points
    - Videos → transcript summaries
    - Thread summaries
    - Custom summary templates

### Phase 3 (Month 4-5)
**Goal:** Expand ecosystem + polish

11. **WhatsApp Integration**
    - Starred messages
    - Media files
    - Voice notes

12. **Discord Saved Messages**
    - DMs
    - Server channels
    - Threads

13. **Reddit Saved Posts**
    - Posts + comments
    - Image/video downloads

14. **Obsidian Integration**
    - Bidirectional sync
    - Custom template mapping
    - Graph view compatibility

15. **Email Integration**
    - Gmail saved/starred
    - Outlook flagged
    - Newsletter clippings

16. **Browser Bookmarks**
    - Chrome/Safari sync
    - Bookmark folders → tags

17. **Screenshot OCR**
    - Auto-import from photo library
    - Full OCR + searchable
    - Date/time metadata

18. **Smart Reminders**
    - "You saved something about [topic] 3 months ago"
    - Resurface old ideas when relevant
    - Spaced repetition for learning content

19. **Sharing & Collaboration**
    - Share collections with others
    - Team workspaces
    - Collaborative tagging

20. **Analytics Dashboard**
    - What you save most
    - Topics trending in your content
    - Reading/watching habits
    - "Your year in notes" recap

### Future Ideas (Phase 4+)
- Apple Notes integration
- Google Keep
- Evernote import
- Bear notes
- Roam Research
- Slack saved messages
- iMessage saved photos
- YouTube watch later
- Spotify saved songs (for music notes)
- Goodreads highlights
- Kindle highlights (Readwise competitor feature)
- PDF annotations
- Hardware component (smart pen - NoteForge concept)

---

## User Flows

### Onboarding Flow
1. Download NoteNest app (iOS App Store)
2. Sign up (email/Apple/Google)
3. "Connect your first source" prompt
4. Choose: Telegram, Notion, or Voice Capture
5. Authenticate (OAuth)
6. Initial sync (background, show progress)
7. "Your first search" tutorial
8. Done - inbox ready

### Daily Use Flow
**Scenario 1: Capture new idea**
1. Voice record idea on iPhone
2. NoteNest auto-transcribes
3. AI suggests category/tags
4. User confirms or edits
5. Saved to universal inbox
6. Option: push to Notion with template

**Scenario 2: Find old idea**
1. Open NoteNest
2. Type search query in top bar
3. Results from ALL sources instantly
4. Preview snippets shown
5. Tap to open full content
6. Option: re-share, add note, archive

**Scenario 3: Instagram saved post rescue**
1. NoteNest auto-syncs Instagram saved posts (background)
2. User gets notification: "47 new saved posts imported"
3. User searches "marketing tips"
4. Instagram post from 6 months ago appears
5. Original link + full caption + saved date shown

### Power User Flow
**Scenario: Weekly review ritual**
1. Open NoteNest inbox (unsorted items)
2. Swipe through new captures
3. For each item:
   - Add tags
   - Send to Notion database (select template)
   - Or delete/archive
4. View "This week's insights" AI summary
5. Export curated list to Obsidian vault

---

## Technical Architecture

### Frontend (iOS)
- **Language:** Swift + SwiftUI
- **Minimum iOS:** 16.0
- **Frameworks:**
  - Speech (for transcription)
  - Vision (for OCR)
  - ShareExtension (for quick capture)
  - Combine (reactive data flow)
- **UI/UX:**
  - Clean, minimal, ADHD-friendly
  - No nested folders (search-first)
  - Haptic feedback everywhere
  - Dark mode default

### Backend
- **Server:** Node.js (Express) or Python (FastAPI)
- **Database:** PostgreSQL (structured data)
- **Vector DB:** Pinecone or Weaviate (semantic search embeddings)
- **Cache:** Redis (session + API rate limit management)
- **Storage:** AWS S3 (media files - images, audio, video)
- **Queue:** BullMQ or Celery (background jobs for syncing)

### AI/ML Services
- **Embeddings:** OpenAI `text-embedding-3-small` (cheap, fast)
- **Summarization:** OpenAI GPT-4o-mini (cost-effective)
- **Transcription:** OpenAI Whisper API
- **OCR:** Apple Vision framework (on-device) + Google Cloud Vision (fallback)
- **Categorization:** Fine-tuned classification model or GPT-4o-mini with structured output

### Third-Party Integrations
| Service | Method | API Available? | Notes |
|---------|--------|----------------|-------|
| Telegram | Bot API | ✅ Yes | Easy, well-documented |
| Notion | Official API | ✅ Yes | OAuth2, good docs, rate limits 3 req/sec |
| Obsidian | File system | ⚠️ Indirect | Access local vault files, Git sync for cloud |
| Instagram | Graph API | ⚠️ Limited | Saved posts NOT in API - need scraping |
| Facebook | Graph API | ❌ No | Saved items not exposed - need extension |
| LinkedIn | Official API | ⚠️ Unclear | User saved posts not documented - research needed |
| Twitter/X | Official API | ✅ Yes | Bookmarks endpoint exists (v2 API) |
| WhatsApp | Business API | ⚠️ Limited | Personal chats = need web scraping |
| Discord | Bot API | ✅ Yes | Can monitor user's saved messages |
| Reddit | Official API | ✅ Yes | `/user/username/saved` endpoint |
| Gmail | Gmail API | ✅ Yes | Search `is:starred` or `label:important` |

**Workarounds for limited APIs:**
- **Browser extension** (Chrome/Safari) for Instagram/Facebook/LinkedIn
  - User installs extension
  - Scrapes saved posts on demand
  - Sends to NoteNest backend via secure API
- **IFTTT/Zapier backup** for some integrations (fallback option)

### Data Model

**Core Entities:**

```
User
- id
- email
- subscription_tier (free/pro)
- created_at

ConnectedSource
- id
- user_id
- source_type (telegram, notion, instagram, etc.)
- auth_token (encrypted)
- sync_enabled
- last_sync_at
- metadata (JSON - source-specific config)

Note
- id
- user_id
- source_id
- source_item_id (original ID in source system)
- content_type (text, audio, video, image, link)
- title
- body (full text)
- summary (AI-generated)
- embedding (vector - for semantic search)
- media_url (S3 path if applicable)
- original_url (link back to source)
- tags (array)
- captured_at (original save date)
- imported_at
- metadata (JSON - source-specific fields)

Tag
- id
- user_id
- name
- color
- auto_assigned (boolean - was it AI-suggested?)

UserTemplate
- id
- user_id
- name
- target_system (notion, obsidian)
- template_config (JSON - mapping rules)
```

### Sync Architecture
**Challenge:** Some sources have 1000s of saved items. Initial sync = slow.

**Solution: Progressive sync**
1. First sync: Most recent 50 items (fast onboarding)
2. Background job: Fetch older items in batches
3. User can see & search recent content immediately
4. Notification when full history is imported

**Sync Frequency:**
- Real-time: Telegram (webhook), Discord (webhook)
- Polling (every 15 min): Instagram, LinkedIn, Twitter, Reddit
- Manual trigger: Notion/Obsidian (user-controlled)
- On-demand: Voice capture, screenshots, share sheet

### Search Implementation
**Hybrid search approach:**

1. **Semantic search** (vector similarity)
   - User query → embedding
   - Find similar note embeddings (cosine similarity)
   - Great for "find something about X" fuzzy queries

2. **Keyword search** (PostgreSQL full-text)
   - Exact phrase matching
   - Boolean operators (AND, OR, NOT)
   - Great for specific terms/dates

3. **Filters** (metadata)
   - Source type
   - Date range
   - Content type (audio, video, text, etc.)
   - Tags

**Search ranking:**
- Combine semantic + keyword scores
- Boost recent items slightly
- Boost items user has interacted with (opened/tagged)

### Security & Privacy
- **Encryption:**
  - Auth tokens encrypted at rest (AES-256)
  - S3 media files encrypted
  - TLS 1.3 for all API calls
- **Data retention:**
  - User can delete sources (removes all associated notes)
  - Account deletion = hard delete within 30 days
- **OAuth scopes:**
  - Request minimum permissions (read-only where possible)
  - Clear permission explanations during onboarding
- **GDPR/CCPA compliance:**
  - Export all data (JSON)
  - Delete all data on request
  - Privacy policy + terms

---

## Competitive Analysis

### Direct Competitors

#### 1. **Readwise Reader** ($12.99/mo)
**Strengths:**
- Deep Notion/Obsidian/Roam integration
- Excellent highlighting/annotation
- Newsletter + RSS support
- Strong brand (built on Readwise reputation)

**Weaknesses:**
- Focused on READ content (articles, books, newsletters)
- NOT social media saved posts
- NOT voice/video/multimodal
- Expensive ($155/year)

**Gap NoteNest fills:** Social media, multimodal, ADHD-first, cheaper

---

#### 2. **Matter** (Freemium, $8/mo Pro)
**Strengths:**
- Clean mobile UX
- Newsletter support
- Audio articles (TTS)
- Free tier exists

**Weaknesses:**
- Read-later ONLY (no social saved posts)
- Limited export options
- No Obsidian sync
- Not ADHD-focused

**Gap NoteNest fills:** Social media, Obsidian, ADHD branding, multimodal

---

#### 3. **Fabric** (Beta, unclear pricing)
**Strengths:**
- "Internet-wide search" vision (similar to NoteNest!)
- AI-powered
- Multi-source ambition

**Weaknesses:**
- Still in beta (as of March 2026)
- Unclear which sources supported
- No clear ADHD positioning
- Pricing unknown (risk: too expensive)

**Gap NoteNest fills:** ADHD-first, clearer pricing, mobile-first, faster to market

---

#### 4. **LinkedMash** ($10-20/mo estimated)
**Strengths:**
- LinkedIn saved posts organizer
- Export to Notion/Sheets/Airtable
- AI insights

**Weaknesses:**
- ONLY LinkedIn (single source)
- Not universal
- No multimodal
- Desktop-focused

**Gap NoteNest fills:** Multi-source, mobile-first, voice/video, all social platforms

---

#### 5. **Raindrop.io** (Free/$28/year Pro)
**Strengths:**
- Bookmark manager
- Good tagging/collections
- Affordable

**Weaknesses:**
- Bookmarks ONLY (no social saved posts)
- Manual save required (browser extension)
- Not AI-powered
- Not ADHD-focused

**Gap NoteNest fills:** Auto-sync social, AI categorization, multimodal, ADHD UX

---

### Indirect Competitors

- **Notion** - People use it as catch-all, but no auto-import from social
- **Obsidian** - Local-first, no cloud sync by default, no social media
- **Evernote** - Legacy, clunky, expensive, no social media
- **Apple Notes** - Simple but no integrations, no AI, no multimodal search
- **Google Keep** - Same as Apple Notes
- **Pocket** - Read-later only, no social media, dying product
- **Instapaper** - Same as Pocket

### Competitive Positioning

**NoteNest is the ONLY app that:**
1. ✅ Connects to social media saved posts (Instagram, LinkedIn, Twitter, Facebook)
2. ✅ Is multimodal (text, audio, video, images)
3. ✅ Has bidirectional Notion + Obsidian sync with custom templates
4. ✅ Is built ADHD-first (search-first, no folders, instant capture)
5. ✅ Is affordable ($10/mo vs $13-20/mo competitors)
6. ✅ Is mobile-first (iOS native, not web wrapper)

**Messaging:**
- Readwise = for readers
- Matter = for articles
- Raindrop = for bookmarks
- **NoteNest = for ADHD brains with ideas everywhere**

---

## Business Model

### Pricing Tiers

#### Free Tier
- Connect up to **3 sources**
- 100 notes/month capture limit
- Basic search (keyword only)
- 7-day history
- **Goal:** Let users try core value, convert to Pro when they hit limits

#### Pro Tier: **$10/month** or **$96/year** (20% discount)
- **Unlimited sources**
- Unlimited notes
- Full semantic search (AI-powered)
- Unlimited history
- AI summarization
- Custom Notion/Obsidian templates
- Priority sync (real-time webhooks)
- Export to CSV/JSON
- Email support

#### Team Tier: **$25/month per user** (coming Phase 3+)
- All Pro features
- Shared workspaces
- Collaborative tagging
- Team analytics
- Admin dashboard
- SSO (for enterprises)

### Revenue Projections (Conservative)

**Assumptions:**
- **Launch:** Month 6 (Sep 2026)
- **Growth:** 100 signups/month initially → 500/month by Month 12
- **Free → Pro conversion:** 15% (industry average for freemium)
- **Churn:** 5% monthly (typical for productivity apps)

**Year 1 Revenue:**
| Month | Free Users | Pro Users | MRR | ARR (run-rate) |
|-------|-----------|-----------|-----|----------------|
| M6 (Launch) | 100 | 15 | $150 | $1,800 |
| M9 | 400 | 72 | $720 | $8,640 |
| M12 | 900 | 165 | $1,650 | $19,800 |

**Year 2 Revenue:**
- Assuming 500 new signups/month sustained
- 20% conversion (improved product, social proof)
- ~1,200 Pro users by end of Year 2
- **ARR: ~$144,000**

**Break-even analysis:**
- Fixed costs: $500-1,000/mo (hosting, APIs, domain, tools)
- Need ~50-100 Pro users to break even
- Target: Month 9-10

### Monetization Extras (Future)
- **AI credits:** Users on free tier can buy AI credits ($5 for 100 summaries)
- **White-label:** Sell to companies/universities as internal knowledge base ($$$)
- **Affiliate:** Notion/Obsidian referral fees (if they have programs)
- **Premium templates:** Marketplace for Notion/Obsidian templates ($1-10 each)

---

## Go-to-Market Strategy

### Phase 1: Pre-Launch (Months 1-5)
**Goal:** Build waitlist + community

1. **Landing page** (Month 1)
   - Problem statement (ADHD pain)
   - Solution demo (mockups/video)
   - Email waitlist signup
   - Social proof (testimonials from beta testers)

2. **Social media presence**
   - **Twitter/X:** Daily tips on note-taking, ADHD productivity
   - **Instagram:** Reels showing "before/after" cluttered notes → NoteNest
   - **Reddit:** r/ADHD, r/productivity, r/notion, r/ObsidianMD (helpful comments, not spam)
   - **LinkedIn:** Thought leadership on knowledge management

3. **Content marketing**
   - Blog posts: "10 apps ADHD people use for notes (and why they all fail)"
   - Guest posts on ADHD/productivity sites
   - YouTube videos: "I saved 1,000 ideas but couldn't find any of them"

4. **Beta program** (Month 3-4)
   - 50-100 hand-picked users (ADHD community members)
   - Heavy feedback loop
   - Testimonials for launch

### Phase 2: Launch (Month 6)
**Goal:** 1,000 signups in first month

1. **Product Hunt launch**
   - Prepare assets (demo video, screenshots)
   - Rally beta users for upvotes/comments
   - Offer lifetime deal for top supporters

2. **Press outreach**
   - TechCrunch, The Verge, Wired (pitch: ADHD founder solving own problem)
   - ADHD-focused media (ADDitude Magazine, etc.)
   - Productivity newsletters (Matt D'Avella, Ali Abdaal, etc.)

3. **Influencer partnerships**
   - ADHD creators on TikTok/Instagram (50-500K followers)
   - Offer free Pro accounts + affiliate commission (30% first year)
   - Goal: 5-10 partnerships

4. **Paid ads** (small budget: $1-2K)
   - Instagram/Facebook ads targeting ADHD communities
   - Reddit ads in r/ADHD (self-serve)
   - Google ads for "ADHD note app", "Notion alternative"

### Phase 3: Growth (Months 7-12)
**Goal:** Reach 500 signups/month sustained

1. **Referral program**
   - Give 1 month Pro free for each referral who converts
   - Track in app

2. **App Store Optimization (ASO)**
   - Keywords: ADHD, notes, productivity, Notion, Obsidian
   - Get featured by Apple (submit for consideration)

3. **Partnerships**
   - Notion ambassadors/templates creators (cross-promote)
   - Obsidian plugin developers
   - ADHD coaches/therapists (recommend to clients)

4. **Case studies**
   - "How [ADHD influencer] uses NoteNest to manage 1,000 ideas"
   - Video testimonials
   - Before/after demos

5. **Community building**
   - Discord server for users
   - Weekly office hours
   - Feature requests voting
   - Showcase "power users"

### Phase 4: Scale (Year 2+)
- Expand to Android
- Team/enterprise sales
- International markets (translations)
- Hardware component (smart pen - NoteForge vision)

---

## Marketing Angles (Detailed)

### 1. "The single best thing you can do for your brain"
**Hook:** Brain health, cognitive optimization, longevity

**Copy examples:**
- "Your brain wasn't built to remember 10,000 thoughts. Offload them."
- "Neuroscience says: external memory = smarter decisions + less anxiety"
- "The second brain every high performer uses"

**Channels:**
- Health/wellness influencers
- Biohacking communities
- Fitness/nutrition crossover (brain health = body health)

---

### 2. "Struggle with ADHD and lots of creative ideas?"
**Hook:** ADHD community (identity-based)

**Copy examples:**
- "Built by an ADHD brain, for ADHD brains"
- "Your ideas are brilliant. Your organization system... isn't."
- "Stop losing your best ideas to digital clutter"

**Channels:**
- r/ADHD (8M members)
- ADHD TikTok/Instagram creators
- ADDitude Magazine
- How to ADHD (YouTube channel)

---

### 3. "'I thought about that before but don't know where it went'"
**Hook:** Universal pain point (relatability)

**Copy examples:**
- "You: 'I saved that article somewhere...' (Opens 5 apps, can't find it)"
- "The graveyard of your brilliant ideas = 10 different apps"
- "How many genius ideas have you lost to bad organization?"

**Channels:**
- Twitter threads (very relatable format)
- Instagram carousel posts
- LinkedIn storytelling posts

---

### 4. "Type anything anywhere, access in one place"
**Hook:** Solution-focused (clear benefit)

**Copy examples:**
- "One search bar. Everything you've ever saved. Any app. Any time."
- "Telegram. Instagram. Notion. LinkedIn. Voice memos. ALL searchable in 0.3 seconds."
- "Stop app-hopping. Just search."

**Channels:**
- Product demos (YouTube, Product Hunt)
- Landing page hero section
- Paid ads (very clear value prop)

---

## Development Roadmap

### Pre-Development (Weeks 1-2)
- [ ] Finalize product spec (this doc)
- [ ] Design mockups (Figma) - all screens
- [ ] Set up project management (Linear, GitHub Projects, or Notion)
- [ ] Choose tech stack finalized
- [ ] Register domain, set up hosting
- [ ] Create dev environment (local + staging + prod)

### MVP Development (Weeks 3-10)
**Goal:** Working app with 3 sources + search

- [ ] **Week 3-4: Backend foundation**
  - User auth (Firebase Auth or Clerk)
  - PostgreSQL schema
  - REST API endpoints
  - Telegram Bot API integration
  - Notion API integration (OAuth flow)

- [ ] **Week 5-6: iOS app basics**
  - SwiftUI screens (onboarding, inbox, search, settings)
  - Connect backend API
  - OAuth flow for Notion/Telegram
  - Voice recording + upload

- [ ] **Week 7: AI pipeline**
  - Whisper transcription
  - Embeddings generation (OpenAI)
  - Pinecone setup (vector DB)
  - Semantic search endpoint

- [ ] **Week 8: Sync logic**
  - Telegram sync (fetch saved messages)
  - Notion sync (fetch database items)
  - Background jobs (cron or webhooks)
  - Incremental sync (only new items)

- [ ] **Week 9: Search UI**
  - Search bar component
  - Results list
  - Filtering (by source, date, type)
  - Detail view for each note type

- [ ] **Week 10: Polish + beta prep**
  - Onboarding flow
  - Loading states
  - Error handling
  - Offline mode (cache recent searches)
  - TestFlight build

### Beta Testing (Weeks 11-14)
- [ ] Recruit 50 beta users
- [ ] Weekly feedback sessions
- [ ] Bug fixes
- [ ] Performance optimization
- [ ] Add 2-3 most-requested features

### Launch Prep (Weeks 15-16)
- [ ] App Store submission
- [ ] Landing page live
- [ ] Demo video
- [ ] Press kit
- [ ] Social media accounts active
- [ ] Product Hunt page drafted

### Launch (Week 17)
- [ ] Product Hunt launch
- [ ] Press outreach
- [ ] Social media blitz
- [ ] Monitor analytics
- [ ] Rapid bug fixing

### Post-Launch (Weeks 18-24)
- [ ] Add Instagram integration
- [ ] Add LinkedIn integration
- [ ] Add Twitter/X integration
- [ ] AI summarization feature
- [ ] Notion custom templates
- [ ] Obsidian sync
- [ ] User-requested features from backlog

---

## Success Metrics (KPIs)

### Product Metrics
- **Daily Active Users (DAU)**
- **Monthly Active Users (MAU)**
- **DAU/MAU ratio** (stickiness - target: 30%+)
- **Retention:** Day 1, Day 7, Day 30
- **Churn rate** (target: <5% monthly)
- **Notes captured per user per week** (target: 10+)
- **Searches per user per week** (target: 5+)
- **Sources connected per user** (target: 3+ for Pro users)

### Business Metrics
- **Monthly Recurring Revenue (MRR)**
- **Annual Recurring Revenue (ARR)**
- **Free → Pro conversion rate** (target: 15-20%)
- **Customer Acquisition Cost (CAC)** (target: <$30)
- **Lifetime Value (LTV)** (target: >$180 = 18 months retention)
- **LTV/CAC ratio** (target: >3)
- **Payback period** (target: <6 months)

### Growth Metrics
- **Signups per month** (target: 100 → 500 progression)
- **Referral rate** (% of users who refer others - target: 10%+)
- **Viral coefficient** (target: >1 eventually)
- **App Store rating** (target: 4.5+ stars)
- **NPS (Net Promoter Score)** (target: 50+)

---

## Risks & Mitigation

### Technical Risks

**Risk 1: API rate limits (Notion = 3 req/sec)**
- **Mitigation:** Queue system, batch requests, cache aggressively

**Risk 2: Instagram/Facebook saved posts = no API**
- **Mitigation:** Browser extension fallback, web scraping (legal gray area - research ToS)

**Risk 3: AI costs scale with users**
- **Mitigation:** Use smallest models (GPT-4o-mini, Whisper), cache embeddings, limit free tier usage

**Risk 4: Search latency at scale**
- **Mitigation:** Pinecone (fast vector DB), pagination, pre-compute popular queries

### Business Risks

**Risk 1: Low conversion (free → Pro)**
- **Mitigation:** Optimize free tier limits to create urgency, add "upgrade" CTAs at friction points

**Risk 2: High churn**
- **Mitigation:** Onboarding excellence, email re-engagement, feature announcements

**Risk 3: Readwise/Matter clones our idea**
- **Mitigation:** Move fast, own ADHD niche, build community moat, emphasize multimodal/social

**Risk 4: Hard to explain value prop**
- **Mitigation:** Demo video, free tier (let them try), case studies, influencer testimonials

### Legal Risks

**Risk 1: Scraping Instagram/Facebook violates ToS**
- **Mitigation:** Consult lawyer, use official APIs where possible, require user-initiated scraping (not automated), consider workarounds

**Risk 2: GDPR/CCPA compliance**
- **Mitigation:** Privacy policy, terms of service, data export/deletion tools, lawyer review

**Risk 3: User data breach**
- **Mitigation:** Encrypt auth tokens, SOC 2 compliance (eventually), security audit, bug bounty

---

## Team & Roles (if hiring)

**Needed to build MVP:**

1. **CS (Founder/Product)** - 100%
   - Product vision
   - User research
   - Marketing/growth
   - Community building
   - Fundraising (if needed)

2. **iOS Developer** (1 person, contract or co-founder)
   - Swift/SwiftUI expert
   - 3-6 month contract for MVP
   - $10-20K budget (outsource) OR equity co-founder

3. **Backend Developer** (1 person, contract or co-founder)
   - Node.js or Python
   - API integrations experience
   - $10-20K budget (outsource) OR equity co-founder

**OR: CS learns Swift + builds MVP solo** (6-9 months instead of 3-4, $0 cost)

**Phase 2+ hires:**
- Android developer (when ready to expand)
- Designer (part-time initially)
- Customer support (part-time)
- Marketing/growth specialist

---

## Budget Breakdown

### MVP Budget (Bootstrap Mode)

**Development:**
- iOS developer (contract): $15,000
- Backend developer (contract): $15,000
- Designer (Figma mockups): $2,000
- **Total dev:** $32,000

**OR CS builds solo:** $0 (just time - 6-9 months)

**Infrastructure (Year 1):**
- Hosting (AWS/Railway): $100/mo = $1,200/year
- Database (managed Postgres): $50/mo = $600/year
- Vector DB (Pinecone): $70/mo = $840/year
- AI APIs (OpenAI): $200/mo avg = $2,400/year
- Domain + email: $100/year
- **Total infra:** $5,140/year

**Marketing (Launch):**
- Landing page builder (Webflow): $20/mo = $240/year
- Email tool (ConvertKit): $29/mo = $348/year
- Social media tools (Buffer): $15/mo = $180/year
- Paid ads (launch month): $2,000 one-time
- Product Hunt promotion: $500 one-time
- **Total marketing:** $3,268 first year

**Legal/Admin:**
- LLC formation: $500
- Privacy policy/ToS lawyer: $1,500
- App Store developer account: $99/year
- Business insurance: $500/year
- Accounting (Bench): $200/mo = $2,400/year
- **Total legal/admin:** $4,999/year

**TOTAL YEAR 1 (outsource dev):** $32,000 + $5,140 + $3,268 + $4,999 = **$45,407**

**TOTAL YEAR 1 (CS builds solo):** $0 + $5,140 + $3,268 + $4,999 = **$13,407**

**Funding options:**
1. **Bootstrap** (CS's savings): $13-45K
2. **Pre-seed raise** (angel/friends/family): $50-100K for 10% equity
3. **Crowdfunding** (Kickstarter): $30-50K goal (risky, need audience first)
4. **Revenue-based financing** (once MRR >$5K, take loan)

---

## Why This Will Work

### 1. **Founder-Market Fit**
- CS has ADHD → deeply understands the pain
- CS is the target customer → can validate daily
- Mechanical engineer background → can think through systems
- Data analyst → understands user analytics
- Already building tools for himself (Notion workflows, Telegram automation)

### 2. **Market Timing**
- ADHD awareness exploding (TikTok, destigmatization)
- "Second brain" concept mainstream (Tiago Forte, Building a Second Brain)
- AI tools expected in 2026 (users want summarization, categorization)
- Readwise/Matter prove market exists, but gaps remain

### 3. **Clear Differentiation**
- ONLY app that does multimodal + social media + note apps + ADHD-first
- Competitors are single-use (read-later OR bookmarks OR one social platform)
- NoteNest = universal inbox vision (Fabric tried, but still in beta)

### 4. **Product Moat**
- API integrations take time (each one is 2-4 weeks work)
- Data moat: once user has 1,000 notes in NoteNest, switching cost is HIGH
- Community moat: ADHD users are tribal, loyal to "one of us" brands
- Feature velocity: small team = faster iteration than Readwise/Matter

### 5. **Realistic Path to $1M ARR**
- $10/mo × 8,333 Pro users = $100K MRR = $1.2M ARR
- With 20% free→Pro conversion: need ~41,665 free users
- Achievable in 18-24 months with ADHD community focus + influencer growth
- Comparable to Readwise (45K users in Year 1) and Matter (100K+ users)

---

## Next Steps (Action Items)

### Week 1
- [ ] CS: Review this spec, make edits
- [ ] Decide: build solo OR hire devs?
- [ ] If hiring: post job listings (Upwork, Twitter, YC co-founder matching)
- [ ] If solo: enroll in Swift course (Hacking with Swift, 100 Days of SwiftUI)
- [ ] Register domain (notenest.app, notenest.io, or similar)
- [ ] Set up Twitter/Instagram accounts (@notenestapp)

### Week 2
- [ ] Design mockups in Figma (all screens)
- [ ] Create GitHub repo
- [ ] Set up project management (Linear)
- [ ] Research API docs (Telegram, Notion, Instagram, LinkedIn)
- [ ] Write privacy policy + terms (template + lawyer review later)

### Week 3
- [ ] Start development (backend first if hiring, iOS first if solo)
- [ ] Set up landing page (Webflow or Carrd)
- [ ] Write first blog post: "Why I'm building NoteNest"
- [ ] Post on Twitter/LinkedIn: announce building in public
- [ ] Create waitlist (ConvertKit or Loops)

### Ongoing
- [ ] Weekly progress updates on Twitter/LinkedIn
- [ ] Reach out to beta testers (ADHD community members)
- [ ] Document learnings (for content marketing later)
- [ ] Join ADHD/productivity Slack/Discord groups (lurk, be helpful)

---

## Appendix

### Inspiration & Resources
- **Articles:**
  - "Building a Second Brain" - Tiago Forte
  - "How ADHD Brains Work Differently" - ADDitude Magazine
  - "The Case for a Universal Inbox" - Wait But Why
  
- **Competitors to Study:**
  - Readwise Reader (pricing, features, onboarding)
  - Matter (mobile UX, free tier strategy)
  - Raindrop.io (tagging system)
  - Notion (templates, integration ecosystem)
  
- **Communities to Engage:**
  - r/ADHD (8M members)
  - r/productivity (2M members)
  - r/notion (500K members)
  - r/ObsidianMD (200K members)
  - ADHD Twitter/TikTok
  
- **Courses (if building solo):**
  - Hacking with Swift (100 Days of SwiftUI)
  - Stanford CS193p (SwiftUI course - free on YouTube)
  - Ray Wenderlich iOS tutorials

### Questions to Answer Before Launch
1. What's the #1 killer feature? (Probably: multimodal search + social saved posts)
2. Which integration is most requested in beta? (Prioritize that)
3. Can we legally scrape Instagram/Facebook? (Lawyer consult)
4. What free tier limits convert best? (A/B test)
5. Should we do lifetime deal at launch? (Risky, but good for cash flow)

---

**END OF SPEC**

---

*This is a living document. Update as we learn.*