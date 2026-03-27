# NoteNest MVP Development Plan
**Building Solo** | **Timeline: 6-9 months** | **Budget: $13K/year**

---

## Phase 1: Landing Page (Week 1) ✅
- [x] Write copy
- [x] Create HTML page
- [ ] Register domain (notenest.app)
- [ ] Set up email collection (Loops.so free tier)
- [ ] Deploy to Vercel/Netlify (free)
- [ ] Share on Twitter + Instagram
- [ ] **Goal: 100 signups in first month**

---

## Phase 2: Learning Swift (Weeks 2-4)
**If you've never done iOS dev, start here. If you have, skip to Phase 3.**

### Resources:
1. **100 Days of SwiftUI** (free, paulhudson.com)
   - Days 1-15: Swift basics
   - Days 16-30: SwiftUI fundamentals
   - Days 31-50: Intermediate projects
   - Pick relevant days only (search, lists, networking)

2. **Stanford CS193p** (free on YouTube)
   - Lectures 1-5: SwiftUI intro
   - Skip theory-heavy parts, focus on hands-on

3. **Apple Developer Docs**
   - Search API integration tutorial
   - Core Data tutorial (local storage)

### Practice Projects:
- **Week 2:** Simple note list app (create, read, delete)
- **Week 3:** Add search bar with filter
- **Week 4:** Add voice recording + playback

**Checkpoint:** Can you build a simple note app with search? If yes, move to Phase 3.

---

## Phase 3: MVP Backend (Weeks 5-8)

### Week 5: Setup + Auth
- [ ] Initialize Node.js + Express project
- [ ] Set up PostgreSQL (Railway $5/mo)
- [ ] Set up Redis (Railway $5/mo)
- [ ] Implement JWT authentication (email/password)
- [ ] Deploy to Railway
- [ ] Test endpoints with Postman

### Week 6: Telegram Integration
- [ ] Create Telegram bot (BotFather)
- [ ] Set webhook endpoint
- [ ] Handle text messages → save to DB
- [ ] Handle voice messages → download → save
- [ ] Test: Send message to bot → appears in DB

### Week 7: Notion Integration
- [ ] Set up Notion OAuth flow
- [ ] Fetch databases list (test with your own Notion)
- [ ] Fetch pages from database
- [ ] Save to NoteNest DB
- [ ] Test: Notion page → appears in NoteNest DB

### Week 8: Search + Embeddings
- [ ] Set up Pinecone account (free tier)
- [ ] Implement embedding generation (OpenAI API)
- [ ] Store vectors in Pinecone
- [ ] Implement search endpoint (hybrid: semantic + keyword)
- [ ] Test: Search query → returns relevant notes

**Checkpoint:** Backend can import from Telegram + Notion, and search works.

---

## Phase 4: MVP iOS App (Weeks 9-14)

### Week 9: App Structure
- [ ] Create Xcode project (SwiftUI)
- [ ] Set up navigation (TabView: Inbox, Search, Settings)
- [ ] Create basic UI screens (no functionality yet)
- [ ] Set up Core Data (local cache)

### Week 10: Authentication
- [ ] Build login/signup UI
- [ ] Connect to backend auth endpoints
- [ ] Store JWT token securely (Keychain)
- [ ] Handle token refresh

### Week 11: Inbox View
- [ ] Fetch notes from backend (paginated)
- [ ] Display in List with SwiftUI
- [ ] Pull-to-refresh
- [ ] Offline mode (cache in Core Data)

### Week 12: Search View
- [ ] Search bar component
- [ ] Call backend search endpoint
- [ ] Display results (grouped by source)
- [ ] Tap to view full note

### Week 13: Voice Capture
- [ ] Record audio with AVAudioRecorder
- [ ] Upload to backend
- [ ] Backend: transcribe with Whisper API
- [ ] Display transcription in app

### Week 14: Settings + Onboarding
- [ ] Connect sources (Telegram, Notion OAuth flows)
- [ ] Display connected sources
- [ ] Disconnect source
- [ ] Onboarding flow (3 screens)

**Checkpoint:** Can you record voice, search notes, and see Telegram/Notion content? If yes, you have MVP.

---

## Phase 5: Beta Testing (Weeks 15-18)

### Week 15: Polish
- [ ] Fix bugs from internal testing
- [ ] Add loading states
- [ ] Add error handling
- [ ] Improve UI based on feedback

### Week 16: TestFlight
- [ ] Create App Store Connect account ($99/year)
- [ ] Upload build to TestFlight
- [ ] Invite 10 friends/family for testing
- [ ] Collect feedback

### Week 17-18: Beta Program
- [ ] Recruit 50 beta testers from waitlist
- [ ] Weekly feedback calls (5-10 users)
- [ ] Fix critical bugs
- [ ] Add 2-3 most-requested features

**Checkpoint:** 50 beta users, app is stable, feedback is positive.

---

## Phase 6: Launch Prep (Weeks 19-20)

### Week 19: App Store Submission
- [ ] Final bug fixes
- [ ] App Store screenshots (5 per size)
- [ ] App Store description copy
- [ ] Privacy policy + terms (templates online)
- [ ] Submit for review (7-10 days)

### Week 20: Marketing Prep
- [ ] Record demo video (1 min)
- [ ] Prepare Product Hunt page
- [ ] Write launch tweet thread
- [ ] Reach out to 5 ADHD influencers
- [ ] Set up paid ads ($500 budget)

**Checkpoint:** App approved, marketing assets ready, beta testimonials collected.

---

## Phase 7: Launch (Week 21)

### Launch Day Checklist:
- [ ] Product Hunt launch (6 AM PT)
- [ ] Post on Twitter, Instagram, LinkedIn
- [ ] Email waitlist (1,000+ people)
- [ ] Post in r/SideProject (carefully)
- [ ] Turn on paid ads
- [ ] Monitor analytics (crashes, signups)

### Launch Week Goals:
- 1,000 app downloads
- 50 Pro conversions ($500 MRR)
- Top 5 on Product Hunt
- 3 press mentions

---

## Tech Stack Summary

### Frontend (iOS)
- **Language:** Swift
- **UI:** SwiftUI
- **Local DB:** Core Data
- **Networking:** URLSession + Combine
- **IDE:** Xcode

### Backend
- **Language:** Node.js + TypeScript
- **Framework:** Express.js
- **Database:** PostgreSQL (Railway $5/mo)
- **Cache:** Redis (Railway $5/mo)
- **Vector DB:** Pinecone (free tier)
- **Hosting:** Railway ($15/mo total)

### AI Services
- **Embeddings:** OpenAI text-embedding-3-small
- **Transcription:** OpenAI Whisper API
- **Summarization:** OpenAI GPT-4o-mini

### Tools
- **Code editor:** VS Code (backend), Xcode (iOS)
- **API testing:** Postman
- **Database GUI:** TablePlus
- **Version control:** GitHub

---

## Weekly Time Commitment

**Estimated: 20-30 hours/week**

- **Weekdays (Mon-Fri):** 2-3 hours/day after work = 10-15 hours/week
- **Weekends (Sat-Sun):** 5 hours/day = 10 hours/week
- **Total:** 20-25 hours/week

**If you can only do 10-15 hours/week:**
- Timeline extends to 12 months
- Focus on MVP first, add features post-launch

---

## Budget Breakdown (Solo)

### Year 1 Costs:
| Item | Cost |
|------|------|
| Domain (notenest.app) | $12/year |
| Email tool (Loops.so) | $0 (free tier) |
| Backend hosting (Railway) | $15/mo = $180/year |
| Pinecone (vector DB) | $0-70/mo = $0-840/year |
| OpenAI API (AI features) | $50-200/mo = $600-2,400/year |
| Apple Developer | $99/year |
| Tools (Figma, Canva, etc.) | $20/mo = $240/year |
| **Total (low estimate)** | **$1,131/year** |
| **Total (high estimate)** | **$3,771/year** |

**Launch marketing budget:** $2,000 one-time (Product Hunt, ads)

**Grand Total Year 1:** $3,131 - $5,771

**Break-even:** ~100 Pro users at $10/mo = $1,000 MRR

---

## Risks & Mitigation

### Risk 1: "I don't know Swift"
**Mitigation:** 100 Days of SwiftUI course. Start simple. Build incrementally. Join iOS dev communities (r/iOSProgramming, Twitter).

### Risk 2: "This is taking too long"
**Mitigation:** Launch with 2 sources only (Telegram + Notion). Add others post-launch. Ship fast, iterate.

### Risk 3: "I'm stuck on a technical problem"
**Mitigation:** Ask ChatGPT/Claude. Post on Stack Overflow. Join dev Discord servers. Pay for 1-hour consultant call ($100).

### Risk 4: "No one signs up"
**Mitigation:** Start marketing EARLY. Build in public on Twitter. Engage in ADHD communities. Collect feedback and pivot if needed.

---

## Success Metrics

### MVP Phase (Weeks 1-14):
- [ ] Landing page live with 100+ signups
- [ ] Backend can import from 2 sources
- [ ] iOS app runs on TestFlight
- [ ] Search works (semantic + keyword)

### Beta Phase (Weeks 15-18):
- [ ] 50 beta testers
- [ ] 80%+ say "I would use this daily"
- [ ] 3+ testimonials collected
- [ ] <5 critical bugs reported

### Launch Phase (Week 21+):
- [ ] 1,000 downloads in first month
- [ ] 5% free → Pro conversion (50 users)
- [ ] $500 MRR
- [ ] 4.5+ stars on App Store

---

## Next Steps (This Week)

1. **Register domain** (notenest.app) — $12
2. **Deploy landing page** to Vercel (free, 5 min setup)
3. **Set up email collection** with Loops.so (free)
4. **Post landing page link** on Twitter + Instagram
5. **Start Swift learning** (100 Days of SwiftUI, Day 1)

**By end of Week 1:**
- Landing page live
- 10 email signups
- Completed Swift basics (Days 1-5)

---

## Questions to Answer Before Starting

1. **Do you want to learn Swift from scratch?** (Yes = 4 weeks learning, No = hire iOS dev)
2. **How much time can you commit per week?** (10-15 hrs = 12 months, 20-30 hrs = 6 months)
3. **What's your iOS dev experience level?** (None, beginner, intermediate)
4. **Do you have a Mac?** (Required for Xcode)

Let me know and I'll adjust the plan accordingly.

---

**Let's ship this. 🚀**
