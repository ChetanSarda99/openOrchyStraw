# MVP Planning Guide — Solo Indie App

> A battle-tested phase-by-phase plan for building and launching a solo SaaS/app.
> Replace `[Your App]` with your project name throughout.

---

## Before You Start

**Answer these first:**
1. What's your weekly hour commitment? (10–15 hrs = 12 months, 20–30 hrs = 6–9 months)
2. What's your experience level with the required stack?
3. Do you have any learning gaps to close first?

---

## Phase 1: Landing Page (Week 1)

**Goal:** Validate demand before building anything.

- [ ] Write value prop copy (problem → solution → who it's for)
- [ ] Build simple HTML/Astro/Next.js landing page
- [ ] Register domain
- [ ] Set up email collection (Loops.so, Beehiiv, or ConvertKit — free tier)
- [ ] Deploy to Vercel/Netlify (free)
- [ ] Share on relevant communities (Twitter, Reddit, Slack groups)
- [ ] **Target: 50–100 signups in first month**

---

## Phase 2: Skill Gap Closing (Weeks 2–4)

*Skip if you're already proficient in the stack.*

**Resources by stack:**
- **iOS (Swift):** 100 Days of SwiftUI (paulhudson.com), Stanford CS193p (YouTube)
- **React Native:** Expo docs, React Native Express
- **Next.js:** Next.js official tutorial, Josh tried coding
- **Backend (Node.js):** freeCodeCamp Node course, official Express docs

**Practice projects:**
- Week 2: CRUD app with list + detail views
- Week 3: Add search/filter
- Week 4: Add the "hard feature" (auth, file upload, real-time, etc.)

**Checkpoint:** Can you build a simple version of your app's core flow? If yes → Phase 3.

---

## Phase 3: MVP Backend (Weeks 5–8)

### Week 5: Setup + Auth
- [ ] Initialize project with chosen stack
- [ ] Set up database (Railway, Supabase, or PlanetScale)
- [ ] Implement user auth (Supabase Auth, Clerk, or JWT)
- [ ] Deploy skeleton to production
- [ ] Test with Postman/Insomnia

### Week 6: Core Feature 1
- [ ] [Your first integration or core data flow]
- [ ] Store data in DB
- [ ] Write basic tests
- [ ] Test end-to-end

### Week 7: Core Feature 2
- [ ] [Second key feature]
- [ ] Handle edge cases
- [ ] Add error responses

### Week 8: Search / Query Layer
- [ ] Implement search endpoint (keyword or semantic)
- [ ] Add pagination
- [ ] Cache results if expensive

**Checkpoint:** Backend handles the core user flow start to finish.

---

## Phase 4: MVP Client (Weeks 9–14)

### Week 9: App Structure
- [ ] Create project (Xcode / CRA / Next.js / etc.)
- [ ] Set up navigation structure
- [ ] Create skeleton screens (no functionality)
- [ ] Set up local storage / cache

### Week 10: Authentication
- [ ] Login / signup UI
- [ ] Connect to backend auth
- [ ] Store tokens securely
- [ ] Handle refresh + logout

### Week 11: Core List / Feed View
- [ ] Fetch from backend (paginated)
- [ ] Display in scrollable list
- [ ] Pull-to-refresh
- [ ] Offline cache (last N items)

### Week 12: Search / Query View
- [ ] Search input component
- [ ] Call search endpoint
- [ ] Display ranked results
- [ ] Tap to view detail

### Week 13: Core Action (Create / Capture)
- [ ] [Your app's "new thing" action — voice, photo, form, etc.]
- [ ] Upload to backend
- [ ] Show result / confirmation

### Week 14: Settings + Onboarding
- [ ] Connect data sources / configure preferences
- [ ] Onboarding flow (3 screens max)
- [ ] Disconnect / manage settings

**Checkpoint:** Core loop works — can create, view, and find content.

---

## Phase 5: Beta Testing (Weeks 15–18)

### Week 15: Polish
- [ ] Fix bugs from internal testing
- [ ] Add loading states + error handling
- [ ] Performance pass (measure cold start, key screens)

### Week 16: TestFlight / Staging
- [ ] Upload build to TestFlight (iOS) or share staging URL
- [ ] Invite 10 trusted testers (friends / family)
- [ ] Collect structured feedback (Notion form or Typeform)

### Week 17–18: Beta Program
- [ ] Recruit 50 beta users from waitlist
- [ ] Weekly feedback calls (5–10 users)
- [ ] Fix critical bugs (P0/P1 only — don't scope creep)
- [ ] Add top 2–3 requested features

**Checkpoint:** 50 beta users, stable app, positive qualitative feedback.

---

## Phase 6: Launch Prep (Weeks 19–20)

### Week 19: Submission
- [ ] Final bug fixes
- [ ] App Store screenshots + preview video (if iOS)
- [ ] Description copy + keywords
- [ ] Privacy policy + terms (use a template)
- [ ] Submit for review

### Week 20: Marketing Assets
- [ ] 60-second demo video
- [ ] Product Hunt page draft
- [ ] Launch tweet/thread
- [ ] Identify 3–5 relevant influencers or communities
- [ ] Set aside $500–2,000 launch ad budget (optional)

**Checkpoint:** App approved, assets ready, beta testimonials in hand.

---

## Phase 7: Launch (Week 21)

**Launch Day Checklist:**
- [ ] Product Hunt (post at 12:01 AM PT)
- [ ] Twitter / X thread
- [ ] Email waitlist
- [ ] Post in relevant subreddits + communities (read rules first)
- [ ] Turn on paid ads (if budget exists)
- [ ] Monitor: crash rate, signups, conversion

**Launch Week Goals:**
- 500–1,000 downloads / signups
- 2–5% free → paid conversion
- Top 5 Product Hunt (if your category has traction)
- 1–3 press mentions

---

## Budget Template (Solo, Year 1)

| Item | Est. Cost |
|------|-----------|
| Domain | $12–20/year |
| Hosting (Railway/Fly/Vercel) | $15–50/mo |
| Database | $0–25/mo (Supabase free → $25) |
| AI API (OpenAI/Anthropic) | $50–400/mo |
| Email tool | $0–30/mo |
| App Store account | $99/year (iOS only) |
| Error tracking (Sentry) | $0–26/mo |
| Analytics (PostHog) | $0/mo (generous free tier) |
| **Total (low)** | **~$1,000/year** |
| **Total (high)** | **~$5,000/year** |

**Break-even:** ~100 Pro users at $10/mo = $1,000 MRR

---

## Common Risks

| Risk | Mitigation |
|------|-----------|
| Unknown stack | Close skill gap in Phase 2. Build simple. |
| Scope creep | Launch with 2 core features only. Add post-launch. |
| Stuck on a bug | Ask Claude/ChatGPT → Stack Overflow → paid consult. |
| No signups | Market early + in public. Talk to users. Pivot if needed. |
| Running out of steam | Ship small wins weekly. Community accountability. |

---

## Success Metrics by Phase

| Phase | Key Metric |
|-------|-----------|
| Landing page | 50+ email signups |
| Beta | 50 testers, 80% say "I'd use this daily" |
| Launch | 1,000 downloads, 3–5% conversion |
| Post-launch | $1,000 MRR within 3 months |

---

*Adapt the timeline to your hours/week. Progress > perfection. Ship.*
