================================================================================
MEMO APP — MONETIZATION & LAUNCH FEASIBILITY RESEARCH
================================================================================
Date: 2026-03-14
Status: Research complete — actionable recommendations
Model: Freemium (3 sources free) / Pro $9.99/mo (unlimited + AI)
Target: 200 paying users ($2K MRR) by month 12

================================================================================
M5.1 ONBOARDING
================================================================================

------------------------------------------------------------------------
1. THREE-STEP ONBOARDING — ADHD BEST PRACTICES
------------------------------------------------------------------------

RECOMMENDATION: 3 steps is correct. Do NOT exceed 4 screens before paywall.

Research findings:
- Adding a progress bar alone boosted onboarding completion ~10% in the Glow
  case study (74% -> 83% completion)
- One concept per screen is mandatory for ADHD users
- Industry target: 80%+ onboarding completion rate
- Top-performing apps show paywall at end of onboarding, not after

Memo's 3-step flow:
  Step 1: "What do you save?" (pick sources — Instagram, Telegram, Notion, etc.)
  Step 2: "Connect your first source" (one OAuth tap, show progress)
  Step 3: Demo search with sample data ("See? Found in 0.3 seconds")
  -> Commitment screen
  -> Paywall (3-step structure)

ADHD-specific requirements:
- Skip button visible on every screen (ADHD users hate feeling trapped)
- Auto-advance where possible (reduce tap count)
- No long text blocks — use icons + short phrases
- Progress indicator always visible
- Total time: under 90 seconds
- Respect reduced motion preferences

RISK: LOW — Well-established pattern, already validated in similar apps.

------------------------------------------------------------------------
2. SOURCE CONNECTION DURING ONBOARDING — FRICTION VS ACTIVATION
------------------------------------------------------------------------

RECOMMENDATION: Ask them to connect ONE source during onboarding, but make
it skippable. Don't force multiple connections.

Tradeoff analysis:
- PRO: Users who connect a source during onboarding have 2-3x higher D7
  retention (they see real value immediately)
- CON: OAuth flows add friction — each additional step loses 5-15% of users
- SWEET SPOT: One source connection with "skip for now" option

Implementation:
- Show the 3 easiest sources first (Telegram Bot = 2 taps, Voice = no auth,
  Notion = OAuth)
- If they skip: show sample data so search demo still works
- After onboarding: gentle prompt to connect first source (not blocking)
- Track: % who connect during onboarding vs. later vs. never

Progressive sync strategy (from PRODUCT_SPEC.md):
- First sync: most recent 50 items (fast, shows value immediately)
- Background: fetch older items in batches
- User sees content instantly, not a loading spinner

RISK: MEDIUM — Getting OAuth right during onboarding is tricky. Test both
flows (connect vs. skip) in A/B test.

------------------------------------------------------------------------
3. COMMITMENT SCREEN BEFORE PAYWALL — DOES IT WORK?
------------------------------------------------------------------------

RECOMMENDATION: YES — implement it. Well-researched psychological principle.

Psychology backing:
- Based on Cialdini's "Commitment and Consistency" principle: people who
  make a small commitment are more likely to follow through with larger ones
- Used by: Duolingo, Headway, Flow, Noom — all report conversion lifts
- Glow case study called it a "game-changer tactic"

Memo's commitment screen:
  "I, [Name], will never lose a brilliant idea again."
  [Hold to confirm] (haptic feedback, subtle animation)

Implementation notes:
- Use the name they entered in onboarding (personalization increases effect)
- Hold-to-confirm feels more intentional than a tap (Touch ID metaphor)
- Keep it under 5 seconds total interaction
- Spring animation on confirm (satisfying micro-interaction)
- This screen should feel empowering, NOT guilt-tripping
  (ADHD users are sensitive to shame — frame as aspiration, not obligation)

Conversion impact:
- Top-performing apps see 20-40% uplift in paywall conversion when using
  multi-step paywalls with commitment screens
- Mentioning "free" 5-7 times across paywall screens = 20-40% uplift

RISK: LOW — Worst case it has no effect and you remove it. No downside.


================================================================================
M5.2 PAYWALL & MONETIZATION
================================================================================

------------------------------------------------------------------------
4. REVENUECAT IMPLEMENTATION
------------------------------------------------------------------------

RECOMMENDATION: Use RevenueCat. It's the industry standard for indie iOS apps.

Technical implementation (Swift + SwiftUI):
- SDK: RevenueCat/purchases-ios (Swift Package Manager)
- ~70 lines of SwiftUI code for a basic paywall
- Supports @Observable pattern (compatible with Memo's architecture)
- Built-in paywall templates (configurable remotely, no app update needed)

Key features for Memo:
- Remote paywall configuration (change copy/pricing without App Store review)
- A/B testing via Experiments (test 2-4 variants, full lifecycle analysis)
- Can test: trial length, price, plan groupings, paywall copy
- Webhook integration for server-side subscription validation
- Built-in analytics: MRR, churn, trial conversion, LTV

Setup steps:
  1. Create RevenueCat account (free up to $2.5K MRR)
  2. Add purchases-ios via SPM
  3. Configure Products in App Store Connect ($9.99/mo, $95.88/yr)
  4. Create Offerings in RevenueCat dashboard
  5. Display paywall using RevenueCat's PaywallView or custom UI
  6. Server-side webhook to backend for entitlement verification

Pricing tiers to configure:
  - Monthly: $9.99/mo
  - Annual: $95.88/yr ($7.99/mo — "Save 20%")
  - Consider: 7-day free trial on both

Cost: FREE up to $2.5K MRR, then 1% of revenue. At $2K MRR = $0.

RISK: LOW — Mature SDK, excellent docs, SwiftUI support confirmed.

------------------------------------------------------------------------
5. FREE TIER LIMITS — 3 SOURCES CAP ENFORCEMENT
------------------------------------------------------------------------

RECOMMENDATION: Server-side enforcement is NON-NEGOTIABLE. Client-side
checks are trivially bypassed.

Architecture:
  CLIENT SIDE (UX only):
  - Show source count: "2 of 3 sources connected"
  - Grey out "Add Source" button when at limit
  - Show upgrade prompt when tapping greyed button

  SERVER SIDE (enforcement):
  - POST /sources/:type/connect checks user.subscription_tier
  - If tier == 'free' AND connectedSources.count >= 3: return 403
  - Subscription status verified via RevenueCat webhook + DB flag
  - JWT contains tier info for fast checks, but DB is source of truth

Why server-side matters:
- Pentest research shows client-side freemium controls are "trivially
  bypassed" — users can disable paywall modals, modify local storage, etc.
- Without server-side checks, any user could bypass restrictions and
  access every restricted feature

Free tier limits (from PRODUCT_SPEC.md):
  - 3 sources (enough to see value, not enough for power use)
  - 100 notes/month capture limit
  - Basic search only (keyword, not semantic)
  - 7-day history (older notes require upgrade)

Each limit creates a natural "upgrade moment" — user hits the wall
organically while using the app.

RISK: LOW — Standard implementation pattern. Just don't skip server-side.

------------------------------------------------------------------------
6. UPGRADE PROMPTS — ADHD-FRIENDLY, NO GUILT
------------------------------------------------------------------------

RECOMMENDATION: Show value, not pressure. 3 trigger points maximum.

Anti-patterns to AVOID (ADHD users are sensitive to):
  x "You're missing out on 47 features!"
  x "Upgrade NOW — limited time offer!"
  x "You've hit your limit" (with a sad emoji)
  x Countdown timers or fake urgency
  x Blocking modals that require dismissal
  x Any language that implies failure or inadequacy

ADHD-friendly upgrade prompts:

  Trigger 1: Source limit hit
  "You've connected 3 sources — nice! Unlock unlimited sources with Pro."
  [See what's included] [Maybe later]

  Trigger 2: Semantic search attempt on free
  "This search would find 12 more results with AI-powered search."
  [Try Pro free for 7 days] [Use basic search]

  Trigger 3: History limit hit (searching for old content)
  "This note is from 2 weeks ago. Pro gives you unlimited history."
  [Unlock full history] [Dismiss]

  Trigger 4 (passive): Settings screen
  "Pro" badge next to locked features, no modal, just visible

Rules:
- Max 1 upgrade prompt per session
- Never interrupt a search or active workflow
- Always provide a dismiss option
- Never show the same prompt twice in 24 hours
- Track which prompts convert best, kill the rest

RISK: LOW — The ADHD community will punish guilt-tripping apps publicly
on TikTok/Reddit. Stay respectful.

------------------------------------------------------------------------
7. TRIAL PERIOD — 7-DAY VS 14-DAY
------------------------------------------------------------------------

RECOMMENDATION: 7-day trial. Not 14. Not 3.

Research data:
- Large-scale experiment (337,724 users): 7-day trials maximized
  acquisition, retention, AND profits vs. 14-day and 30-day
- After 4 days, there's no significant difference in conversion rates
  between trial lengths (Recurly data)
- 7-14 day trials outperform 30+ day trials by up to 20% (Gartner)
- Users who start with a trial have LTV up to 64% higher than direct buyers

Why 7 days for Memo specifically:
- Memo needs time for users to save content across sources and then SEARCH
  for it — this requires at least 3-5 days of organic use
- 3 days (Glow's recommendation) is too short — Memo's value compounds
  over time as more content syncs
- 14 days provides no additional conversion benefit but delays revenue
- 7 days creates enough urgency while allowing value discovery

Trial implementation:
- Day 0: Full Pro access, first source sync
- Day 1-2: Push notification: "You've saved 23 items — try searching!"
- Day 3-4: In-app: "Your AI summaries are ready" (show Pro feature)
- Day 5: Push: "2 days left on your trial — here's what you'd lose"
- Day 6: In-app: "Tomorrow your trial ends. Keep everything with Pro."
- Day 7: Conversion screen with clear before/after comparison

Key metrics to track:
- Trial start rate (% of onboarding completions)
- D1, D3, D5 engagement during trial
- Trial-to-paid conversion rate (target: 15-25%)
- Post-trial retention for non-converters

RISK: LOW — 7 days is the safest default. Can A/B test vs. 14 later.


================================================================================
M5.3 MARKETING & LAUNCH
================================================================================

------------------------------------------------------------------------
8. LANDING PAGE — STACK RECOMMENDATION
------------------------------------------------------------------------

RECOMMENDATION: Start with Carrd ($19/yr), migrate to Astro + Vercel
before launch.

Comparison:
  CARRD ($19/yr Pro)
  + Build in under 1 hour
  + Perfect for pre-launch waitlist
  + Fast load times
  + Zero maintenance
  - No CMS, limited customization
  - Can't scale for blog/content marketing
  VERDICT: Use NOW for waitlist phase

  FRAMER ($0-20/mo)
  + Premium design without engineering
  + Popular with startups for launch pages
  + Better than Carrd for customization
  - Vendor lock-in (no code export)
  - Limited SEO capabilities
  - CMS limitations
  VERDICT: Good for design-first founders, but CS should own the code

  NEXT.JS (free + Vercel hosting)
  + Full code ownership and scalability
  + Best SEO capabilities
  + Can add blog, docs, dynamic pages later
  + Vercel free tier is generous
  - More setup time (but templates exist)
  VERDICT: Overkill for pre-launch, good for post-launch

  ASTRO + TAILWIND (free + Vercel hosting)
  + Fast, cheap, SEO-friendly (already in MARKETING_STRATEGY.md)
  + Static site = blazing fast
  + Can add blog with markdown files
  + CS already knows JS/TS
  VERDICT: BEST for launch and beyond

Phased approach:
  Phase 1 (now): Carrd for waitlist ($19/yr)
  Phase 2 (month 4): Astro site for launch (free on Vercel)
  Phase 3 (post-launch): Add blog, press kit, docs to Astro site

RISK: LOW — Carrd is a 1-hour task. No reason to overthink this.

------------------------------------------------------------------------
9. TIKTOK STRATEGY FOR ADHD APP
------------------------------------------------------------------------

RECOMMENDATION: TikTok is the #1 organic channel for ADHD apps. Go hard.

Audience data:
- #ADHD on TikTok: 6.3+ BILLION views
- #ADHDtok, #ADHDawareness, #ADHDinwomen, #neurodivergent: billions more
- Top 90 ADHD videos average 5.4 MILLION views each
- 80% of top ADHD creators post consistently (algorithm rewards frequency)
- 41% of TikTok users are 16-24 (skews young but highly engaged)

Content formats that work:
  1. POV videos (highest engagement)
     "POV: You saved a life-changing idea but can't find it"
     -> frantically opening 7 apps -> opens Memo -> found in 2 seconds

  2. Relatable list format
     "Things people with ADHD do:" (text overlay with checkmarks)
     -> Memo as the solution at the end

  3. Before/After
     Left: 10 apps, chaos | Right: Memo, one search bar

  4. Pain hook + demo (15-30 sec)
     First 3 sec: STATE THE PAIN ("Can't find that idea you saved?")
     Next 10 sec: SHOW THE SOLUTION (screen recording of Memo)
     Last 5 sec: CTA ("link in bio")

  5. Founder story (authenticity wins)
     "I have ADHD and built an app because..." (face to camera)

Production:
- Record on iPhone (screen record + face cam overlay)
- Edit in CapCut (free)
- Add captions (80% watch without sound)
- 30-45 min production per video
- Cost: $0

Posting cadence: 3-5x/week minimum (algorithm rewards consistency)
Cross-post to: Instagram Reels, YouTube Shorts (same video)

RISK: LOW — $0 cost, huge potential. One viral video = 1,000+ downloads.

------------------------------------------------------------------------
10. APP STORE ASO — KEYWORD STRATEGY
------------------------------------------------------------------------

RECOMMENDATION: Target the intersection of ADHD + note-taking + search.

Title (30 char limit):
  "Memo - Find Your Lost Ideas"

Subtitle (30 char limit):
  "ADHD-Friendly Note Search"

Keywords (100 char limit — comma-separated, no spaces after commas):
  ADHD,notes,organizer,idea,capture,search,voice,memo,telegram,
  save,find,productivity,brain,second

Keyword strategy:
  HIGH INTENT (users ready to install):
  - "ADHD note taking app"
  - "best app for ADHD productivity"
  - "find saved notes app"

  MEDIUM INTENT:
  - "note organizer"
  - "voice memo search"
  - "universal search notes"

  BROAD DISCOVERY:
  - "productivity"
  - "second brain"
  - "idea capture"

ASO optimization tactics for 2026:
- Apple's NLP now interprets conversational, intent-based queries
  -> Write metadata that sounds natural ("Find your lost ideas")
- Custom Product Pages: Apple now allows up to 70 custom pages
  -> Create one for "ADHD focus app" and another for "note search app"
  -> Each CPP with different screenshots optimized for that audience
- CPPs improve conversion 15-40% vs generic listing
- Run keyword optimization monthly — 20-40% compounding download growth

Screenshots (in order of importance):
  1. Search results (the magic moment — multi-source results)
  2. Voice capture in action
  3. Source connections (Telegram, Notion, etc.)
  4. AI summary/categorization
  5. Clean dark mode UI

RISK: LOW — ASO is free and iterative. Start with best guess, optimize
monthly with App Store Connect data.

------------------------------------------------------------------------
11. DEMO VIDEO — TOOLS
------------------------------------------------------------------------

RECOMMENDATION: CapCut (free) for social demos, ScreenStory for polished
App Store preview video.

Tool comparison:
  CAPCUT (free)
  + Free, great for short-form
  + Captions, transitions, trending audio
  + Perfect for TikTok/Reels/Shorts
  BEST FOR: Social media demo content

  SCREENSTORY ($15/mo)
  + Designed specifically for product demo videos
  + Auto-zoom on clicks, device frames, smooth transitions
  + Professional output without video editing skills
  BEST FOR: App Store preview video, landing page hero

  FOCUSEE ($9.99 one-time)
  + Records iOS device screen via USB connection
  + Auto-zoom, cursor highlighting
  + Good for tutorials
  BEST FOR: Long-form tutorials, YouTube

  LOOM (free tier)
  + Fast recording with instant sharing
  + Good for beta tester communication
  BEST FOR: Internal demos, beta feedback

  OPUSCLIP ($9/mo)
  + AI-powered: turns long recordings into short clips
  + Auto-captions, vertical reformat, brand styling
  BEST FOR: Repurposing content across platforms

Workflow:
  1. Record on iPhone Simulator (Xcode) or real device
  2. Edit in CapCut for social content
  3. Use ScreenStory for App Store preview (30-sec limit)
  4. Use OpusClip to create variations for different platforms

RISK: LOW — All tools are cheap or free.


================================================================================
M5.4 APP STORE & COMPLIANCE
================================================================================

------------------------------------------------------------------------
12. APP STORE REVIEW RISKS
------------------------------------------------------------------------

RISK RATING: MEDIUM — Several areas need attention.

LIKELY ISSUES:

  1. AI Data Disclosure (HIGH RISK)
     Memo uses Claude API for summarization and Voyage AI for embeddings.
     Apple now REQUIRES a consent modal before sending any personal data
     to external AI services. Must specify:
     - Which AI provider (Anthropic)
     - What data types are sent (note content)
     - User must explicitly consent
     FIX: Add AI consent modal during onboarding, store consent flag.

  2. Subscription Transparency (MEDIUM RISK)
     Must show: full price, renewal terms, cancellation instructions
     BEFORE any purchase. Apple rejects apps that obscure pricing.
     FIX: RevenueCat's built-in paywall templates handle this correctly.

  3. Third-Party SDK Privacy Manifests (MEDIUM RISK)
     Apple now requires SDK privacy manifests and signatures.
     Every SDK (RevenueCat, Supabase, PostHog) must have a privacy
     manifest or Apple will reject.
     FIX: Verify all SDKs have updated privacy manifests before submission.

  4. Social Media Scraping (HIGH RISK if implemented)
     If Memo scrapes Instagram/Facebook saved posts without official APIs,
     Apple may reject for violating platform ToS.
     FIX: Use only official APIs for MVP. Browser extension as fallback.
     Telegram Bot API and Notion API are safe.

  5. Data Deletion Requirement (LOW RISK)
     Apple requires apps to offer account deletion. Already planned.
     FIX: Implement account deletion endpoint + in-app UI.

UNLIKELY ISSUES:
  - Performance: Native SwiftUI app, should be fast
  - Metadata mismatch: Just show real screenshots
  - Spam/UGC moderation: Memo is personal notes, no UGC

OVERALL: Passable with preparation. The AI consent modal is the #1
thing to get right before submission.

------------------------------------------------------------------------
13. PRIVACY NUTRITION LABELS
------------------------------------------------------------------------

RECOMMENDATION: Prepare this early. Apple requires it for submission.

Data Memo collects (must declare in App Store Connect):

  DATA LINKED TO USER:
  - Contact Info: email address (auth)
  - User Content: notes, voice recordings, saved content
  - Identifiers: user ID
  - Usage Data: app interactions, feature usage (PostHog)
  - Search History: search queries
  - Diagnostics: crash logs, performance data

  DATA NOT LINKED TO USER:
  - Diagnostics: anonymized crash reports

  DATA USED FOR TRACKING:
  - NONE (Memo does not sell data or use it for cross-app tracking)

  THIRD-PARTY DATA SHARING:
  - Anthropic Claude: note content sent for summarization (with consent)
  - Voyage AI: note content sent for embedding generation
  - AssemblyAI: voice recordings sent for transcription
  - Supabase: auth data
  - PostHog: usage analytics (anonymized)

Declaration process:
  1. Go to App Store Connect > App Privacy
  2. Answer questionnaire for each of 14 data categories
  3. Specify: collected, linked to identity, used for tracking
  4. Include third-party SDK data collection
  5. Labels auto-generated from your answers

RISK: LOW — Just be honest and thorough. Users appreciate transparency.

------------------------------------------------------------------------
14. GDPR / PRIVACY COMPLIANCE
------------------------------------------------------------------------

RECOMMENDATION: Build privacy features into MVP, not as afterthought.

Required features (GDPR Articles 15-20):

  RIGHT TO ACCESS (Article 15):
  - In-app: "Download my data" button in Settings
  - Endpoint: GET /users/me/export
  - Format: JSON (structured data) + original media files (S3)
  - Response time: within 30 days (but aim for instant)

  RIGHT TO ERASURE (Article 17):
  - In-app: "Delete my account" in Settings
  - Endpoint: DELETE /users/me
  - Must delete: user record, all notes, connected sources, auth tokens,
    S3 media files, vector embeddings, analytics data
  - Hard delete within 30 days (grace period for accidental deletion)
  - Must also delete from: PostHog, RevenueCat (cancel subscription)

  RIGHT TO PORTABILITY (Article 20):
  - Export in machine-readable format (JSON/CSV)
  - Already covered by data export feature

  CONSENT MANAGEMENT:
  - AI processing: explicit opt-in (consent modal)
  - Analytics: can be opt-out (PostHog respects this)
  - Push notifications: iOS handles this natively
  - Store consent timestamps in database

  PRIVACY POLICY:
  - Must be accessible before account creation
  - Must list: data collected, purposes, third parties, retention period,
    user rights, contact info for DPO
  - Host at: memo-app.co/privacy
  - Use a template + lawyer review ($500-1,500)

Implementation priority:
  1. Privacy policy (before App Store submission)
  2. Account deletion (Apple requires this)
  3. Data export (GDPR Article 15)
  4. AI consent modal (Apple requires this)
  5. Analytics opt-out

RISK: MEDIUM — Not hard to implement, but easy to forget. Build it into
the backend scaffold now.


================================================================================
M5.5 ADVERTISING
================================================================================

------------------------------------------------------------------------
15. APPLE SEARCH ADS — CPA FOR PRODUCTIVITY APPS
------------------------------------------------------------------------

DATA (2025-2026 benchmarks):
- Productivity CPA increased from $1.49 (2024) to $2.84 (2025) — 90% YoY
- Overall market CPA: $2.51 average in 2025
- Q4 is most expensive ($3.28 avg), Q1-Q2 cheapest ($2.11)
- Subscription apps: $1.00-$3.50 CPT (cost per tap) average
- Custom Product Pages improve conversion 15-40%

Memo's Apple Search Ads strategy:
  Budget: Start with $100 free credit (new account promo)
  Target keywords:
  - Brand defense: "memo app", "memo notes"
  - Competitor: "readwise", "notion", "obsidian"
  - Category: "ADHD app", "note organizer", "idea capture"
  - Long-tail: "find saved notes", "search all apps"

  Expected CPA: $2.50-$4.00 for ADHD/productivity keywords
  At $9.99/mo subscription: need user to stay >1 month to break even
  With 17% annual retention: LTV ~$20 (monthly plan)
  -> CPA of $3-4 is profitable

  Timing: Launch in Q1-Q2 when CPAs are lowest

RISK: LOW — Apple Search Ads are high-intent. $100 free credit = risk-free test.

------------------------------------------------------------------------
16. TIKTOK ADS — COST PER INSTALL
------------------------------------------------------------------------

DATA (2025-2026 benchmarks):
- TikTok CPI range: $0.50-$4.50 depending on vertical
- Average for utility/productivity: $1.75-$4.00
- Minimum campaign budget: $50/day for learning phase
- Need 3+ days minimum before judging results
- Creative quality is the #1 factor in CPI (not targeting)

Memo's TikTok Ads strategy:
  Phase 1: Organic first (3-5x/week posting, $0)
  Phase 2: Once organic content identifies winning hooks, boost those
  Budget: $30-50/day for 7 days = $210-$350 test
  Campaign type: "App Install" optimized for installs (not clicks)

  Creative strategy (test 6+ videos):
  - Video 1: POV "can't find saved idea" -> Memo finds it
  - Video 2: "ADHD brain saves ideas in 10 apps" -> one search bar
  - Video 3: Voice memo capture + instant search
  - Video 4: Before/after chaos -> organized
  - Video 5: Founder story (authentic, face to camera)
  - Video 6: User testimonial (from beta testers)

  Targeting: Start BROAD (let algorithm learn)
  - Age: 18-40
  - Interests: ADHD, productivity, note-taking, Notion
  - Location: US, UK, Canada, Australia

  Expected CPI: $2.00-$3.50 for ADHD niche
  Kill threshold: If CPI > $5 after 3 days, pause and test new creatives

Free credits: TikTok offers "Spend $200, get $200" for new accounts

RISK: MEDIUM — TikTok ads require creative iteration. Plan for 2-3 rounds
of testing before finding a winner.

------------------------------------------------------------------------
17. TARGET ROAS FOR $9.99/MO SUBSCRIPTION
------------------------------------------------------------------------

ANALYSIS:

  Revenue per user (pessimistic):
  - Monthly plan: $9.99/mo
  - Average retention: 4-6 months (17% retain at 12 months)
  - LTV (monthly): $9.99 * 5 months avg = ~$50
  - Apple takes 30% (year 1), 15% (year 2+)
  - Net LTV: $50 * 0.70 = $35

  Revenue per user (optimistic, annual plan):
  - Annual plan: $95.88/yr ($7.99/mo)
  - Annual retention: 50-60% for yearly plans
  - LTV: $95.88 * 1.5 renewals = ~$144
  - Net LTV: $144 * 0.70 = $101

  ROAS targets:
  - D30 ROAS: 1.5-2.0x is acceptable (subscription revenue is backloaded)
  - D90 ROAS: 2.5-3.0x target
  - D365 ROAS: 5.0x+ target
  - Lifetime ROAS: 8-10x target

  Break-even:
  - If CPA = $3.50 and net LTV = $35: ROAS = 10x (excellent)
  - If CPA = $5.00 and net LTV = $35: ROAS = 7x (good)
  - If CPA = $10.00 and net LTV = $35: ROAS = 3.5x (marginal)

  Rule of thumb: Keep CAC under $8 for $9.99/mo subscription app.
  Anything under $5 CAC is great.

RISK: LOW — The math works if retention is reasonable and CAC stays under $8.


================================================================================
M5.6 COMMUNITY & ANALYTICS
================================================================================

------------------------------------------------------------------------
18. DISCORD VS OTHER PLATFORMS FOR ADHD COMMUNITY
------------------------------------------------------------------------

RECOMMENDATION: Discord. No contest for this audience.

Why Discord wins:
- ADHD users are already on Discord (multiple active ADHD servers exist)
- ADHD Dopamine server: active community "made by ADHD for ADHD"
- Real-time chat suits ADHD communication style (quick, informal)
- Channels for: bug reports, feature requests, general chat, wins
- Voice channels for community calls
- Free to run (no hosting costs)
- Bots for automation (feature voting, role assignment)

Alternative: Circle ($89/mo) — too expensive and unnecessary for <1K users
Alternative: Slack — fine but less community-oriented
Alternative: Reddit — good for discovery, bad for ongoing community

Discord launch plan:
  Phase 1 (beta): 50-200 members (founders, beta testers)
  - Validate channel structure and rules
  - High-touch: respond to every message
  Phase 2 (launch): Open waitlist with batch invitations
  - Avoid overwhelm by controlling growth
  Phase 3 (growth): Public invite link
  - Add moderation bots, community roles

Channel structure:
  #announcements (read-only)
  #introductions
  #feature-requests (with voting)
  #bug-reports
  #tips-and-tricks
  #adhd-general (non-app chat — builds community)
  #show-your-setup (users share their source configurations)

Success metrics:
  - New member activation: % who post within 48 hours
  - Weekly returning members
  - Message-to-member ratio
  - Feature request volume

RISK: LOW — Discord is free and the audience is already there.

------------------------------------------------------------------------
19. POSTHOG VS MIXPANEL VS AMPLITUDE — ANALYTICS
------------------------------------------------------------------------

RECOMMENDATION: PostHog for MVP. Migrate to Mixpanel if needed.

Comparison for Memo's needs:

  POSTHOG (RECOMMENDED)
  + Free up to 1M events/month (plenty for 200 users)
  + Open-source (no vendor lock-in)
  + All-in-one: analytics + session replay + feature flags + A/B testing
  + Developer-first (matches CS's profile)
  + Self-hostable if needed
  + Built-in data warehouse (import Stripe data later)
  - Mobile SDK less polished than Mixpanel
  - UI less intuitive for non-technical users
  COST: $0 for MVP scale

  MIXPANEL
  + Best mobile SDK (iOS-optimized)
  + Session replay on mobile (added 2024)
  + Point-and-click report builders (easier for non-technical)
  + Free up to 1M events/month (was 100K users)
  + AI-powered session summaries
  - Less developer-focused
  - No built-in feature flags (added late 2025)
  COST: $0 for MVP scale

  AMPLITUDE
  + Deepest behavioral analytics
  + Warehouse-native queries
  + Session replay + heatmaps
  - Free tier limited to 10K MTU
  - Enterprise-oriented (overkill for indie app)
  - Session replay only on Growth/Enterprise plans
  COST: $0 up to 10K MTU, then jumps to ~$50K/yr

Decision: PostHog.
  - Free tier is most generous for Memo's needs
  - Feature flags + A/B testing included (Mixpanel just added these)
  - Developer-first fits CS's workflow
  - Can import RevenueCat data via webhooks
  - If mobile SDK becomes a pain point, consider switching to Mixpanel

RISK: LOW — Both PostHog and Mixpanel have generous free tiers.

------------------------------------------------------------------------
20. KEY METRICS FOR FIRST 12 MONTHS
------------------------------------------------------------------------

RECOMMENDATION: Focus on 10 metrics. Track weekly. Act monthly.

TIER 1 — SURVIVAL METRICS (track daily):
  1. MRR (Monthly Recurring Revenue)
     Target: $0 -> $500 (M3) -> $2,000 (M12)

  2. Trial-to-Paid Conversion Rate
     Target: 15-25%
     Benchmark: Top apps = 20%+, median = 2.18% (freemium)
     Note: Hard paywall median = 12.11%, freemium = 2.18%
     Memo's model (freemium + trial) should aim for 10-15%

  3. Monthly Churn Rate
     Target: <5% monthly
     Benchmark: 65% of weekly plans cancel in 30 days
     Monthly plans: 43% retain at day 90, 17% at 12 months
     Annual plans: 50-60% retain at 12 months
     KEY: Push annual plans to reduce churn

TIER 2 — GROWTH METRICS (track weekly):
  4. New Installs per Week
     Target: 20/week (M1) -> 50/week (M6) -> 100/week (M12)

  5. Activation Rate (onboarding complete + 1 source connected)
     Target: 60%+
     This is the strongest predictor of conversion

  6. Day 7 Retention
     Target: 30%+
     Benchmark: 20-30% is good for productivity apps

TIER 3 — ENGAGEMENT METRICS (track monthly):
  7. Sources Connected per User
     Target: 2+ for free, 4+ for Pro
     More sources = higher retention (more value = stickier)

  8. Searches per User per Week
     Target: 5+
     If users aren't searching, they're not getting value

  9. Notes Captured per User per Week
     Target: 10+
     Combines auto-sync + manual capture

  10. NPS (Net Promoter Score)
      Target: 50+
      Survey after 2 weeks of use (not earlier)

WEEKLY REVIEW TEMPLATE:
  Week of: ___
  MRR: $___  (change: +/-$___)
  New installs: ___
  Trial starts: ___
  Conversions: ___
  Churn: ___ users (___ %)
  D7 retention: ___%
  Activation: ___%
  Top feedback: ___
  One action for next week: ___


================================================================================
COMPETITIVE LANDSCAPE
================================================================================

------------------------------------------------------------------------
21. COMPETITIVE DIFFERENTIATION
------------------------------------------------------------------------

DIRECT COMPETITORS:

  READWISE READER ($9.99-12.99/mo)
  - Focus: Read-later (articles, newsletters, PDFs)
  - Strengths: Best Notion/Obsidian sync, highlight system, strong brand
  - Weakness: NO social media, NO voice, NOT multimodal, NOT ADHD-specific
  - Recent: Omnivore shutdown (Nov 2024) + Pocket closing (Jul 2025)
    drove massive user migration to Readwise
  - MEMO DIFFERENTIATOR: Multi-source + voice + ADHD-first + social media

  MEM AI ($8.33/mo)
  - Focus: AI-powered note organization
  - Strengths: AI auto-organization, quick capture, no folders needed
  - Weakness: Notes only (no external source aggregation), no social media
  - MEMO DIFFERENTIATOR: Aggregation from external sources (Mem = internal
    notes only). Memo captures FROM everywhere, Mem organizes WITHIN itself.

  CAPACITIES ($23/mo)
  - Focus: Object-based knowledge management ("studio for your mind")
  - Strengths: 100K+ users, unique object model, growing fast
  - Weakness: Expensive ($23/mo), no source aggregation, no ADHD focus
  - MEMO DIFFERENTIATOR: Price ($9.99 vs $23), source aggregation,
    ADHD-first design, simpler UX

  NOTION ($0-10/mo)
  - Focus: All-in-one workspace
  - Strengths: 30M+ users, extremely flexible, great API
  - Weakness: Overwhelming for ADHD, no auto-import, blank page problem
  - MEMO DIFFERENTIATOR: Position as Notion's INPUT LAYER
    "Capture everywhere -> Memo -> organize in Notion"

  READWISE + READER ($12.99/mo combined)
  - Strongest competitor overall
  - But they're focused on reading, not capture/aggregation
  - Omnivore/Pocket shutdowns = migration opportunity

  MATTER (shutdown risk?)
  - Was $8/mo Pro, clean mobile UX
  - Read-later only, no social media
  - Given Omnivore/Pocket shutdowns, Matter's sustainability is uncertain

  OMNIVORE (DEAD — Nov 2024)
  - Acquihired by ElevenLabs, all data deleted
  - Gap in market for free/affordable read-later with source aggregation

  POCKET (DYING — closing Jul 2025)
  - Mozilla shutting it down
  - Another gap opening in the market

  RAINDROP.IO ($28/yr)
  - Bookmark manager, not note aggregator
  - Very affordable, 500K+ users
  - Don't compete on price — compete on automation + AI

MARKET OPPORTUNITY: Two major competitors (Omnivore, Pocket) have died
in the past year. Users are looking for alternatives. Memo can capture
these displaced users with the right positioning.

------------------------------------------------------------------------
22. ADHD-SPECIFIC COMPETITORS
------------------------------------------------------------------------

FINDING: No app specifically targets ADHD NOTE AGGREGATION. This is a gap.

ADHD apps that exist (different categories):

  SANER.AI
  - "Built by ADHDers" — closest competitor to Memo's positioning
  - But: focuses on organizing YOUR notes, not aggregating FROM sources
  - No Telegram, no Instagram, no external source sync
  - MEMO DIFFERENTIATOR: External source aggregation

  ADHD TASK MANAGERS (not note apps):
  - Todoist, Things 3, TickTick — task management, not capture
  - Different problem space entirely

  ADHD FOCUS APPS:
  - Forest, Focus@Will, Brain.fm — focus/productivity tools
  - No overlap with Memo's capture/search use case

  GENERAL ADHD APPS:
  - Inflow ($60/yr) — ADHD management (habits, therapy, education)
  - Numo — ADHD daily planner
  - Routinery — routine builder

CONCLUSION: Memo has NO direct competitor in "ADHD-first universal note
aggregation." Saner.AI is the closest but doesn't do source aggregation.
This is a genuine market gap.

RISK: LOW for now. If Saner.AI adds source aggregation, they become the
primary threat. Speed to market matters.


================================================================================
FINANCIAL MODEL
================================================================================

------------------------------------------------------------------------
REVENUE PROJECTION: IS $2K MRR REALISTIC?
------------------------------------------------------------------------

Target: 200 users * $9.99/mo = $1,998 MRR by month 12

Working backwards:
  At 10% freemium-to-paid conversion: need 2,000 free users
  At 15% conversion: need 1,333 free users
  At 5% conversion: need 4,000 free users

  To get 2,000 free users in 12 months:
  - Need ~167 new signups per month average
  - Or ~42 per week
  - Achievable with: organic social + App Store ASO + small ad budget

  Trial conversion benchmarks:
  - Freemium median: 2.18% (too low — need better than average)
  - Hard paywall median: 12.11%
  - Top performers: 20%+
  - Memo target: 10-15% (ambitious but achievable with good onboarding)

  Churn modeling:
  - Monthly churn: 8-10% is realistic for early stage
  - Need to ACQUIRE more than you LOSE each month
  - At 8% churn with 200 paying users: lose 16/month
  - Need 16+ new paying users/month just to maintain
  - With 10% conversion: need 160+ new free users/month (achievable)

VERDICT: $2K MRR by month 12 is REALISTIC but requires:
  1. Consistent organic content (3-5x/week TikTok/Instagram)
  2. 60%+ activation rate
  3. 10%+ conversion rate
  4. <10% monthly churn
  5. Product-market fit (users search weekly)

Conservative scenario: $1,200 MRR (120 paying users)
Optimistic scenario: $3,500 MRR (350 paying users)

RISK: MEDIUM — Achievable but requires execution across marketing,
product, and retention simultaneously.

------------------------------------------------------------------------
CAC (CUSTOMER ACQUISITION COST) ANALYSIS
------------------------------------------------------------------------

Channel breakdown:

  ORGANIC (target: 60% of users, CAC = ~$0):
  - TikTok/Instagram Reels: $0 (time investment only)
  - Reddit community: $0
  - Product Hunt launch: $0
  - Word of mouth / referrals: $0
  - Effective CAC: $0 (but costs CS 10-15 hrs/week in content creation)

  APPLE SEARCH ADS (target: 20% of users):
  - CPA: $2.50-$4.00 for productivity keywords
  - Start with $100 free credit
  - Budget after credit: $100-200/month
  - Expected installs: 30-60/month

  TIKTOK ADS (target: 15% of users):
  - CPI: $2.00-$3.50
  - Budget: $150-300/month
  - Expected installs: 50-100/month

  INFLUENCER (target: 5% of users):
  - Cost: $0 (free Pro in exchange for post)
  - Expected: 50-200 installs per micro-influencer
  - Effective CAC: $0

  BLENDED CAC:
  - If 60% organic + 40% paid at $3.00 CPI:
  - Blended CAC = $3.00 * 0.40 = $1.20 per install
  - With 10% conversion to paid: $12.00 per PAYING user
  - With 15% conversion: $8.00 per paying user

  TARGET: Blended CAC < $10 per paying user
  LTV/CAC RATIO target: >3x (net LTV $35 / CAC $10 = 3.5x)

RISK: LOW if organic content works. MEDIUM if forced to rely on paid.

------------------------------------------------------------------------
INFRASTRUCTURE COSTS AT 200 USERS
------------------------------------------------------------------------

MONTHLY COSTS:

  HOSTING (Railway):
  - Node.js API server: ~$10-20/mo
  - PostgreSQL (with pgvector): ~$10-20/mo
  - Redis: ~$5-10/mo
  - Worker process (BullMQ): ~$5-10/mo
  Railway total: $30-60/mo

  AI SERVICES:
  - Claude API (Sonnet 4.5): $3/$15 per 1M tokens
    200 users * 50 notes/month * ~500 tokens avg = 5M tokens/month
    Cost: ~$15 input + ~$75 output = ~$90/mo
    With batch processing: ~$45/mo
  - Voyage AI embeddings: $0.06/1M tokens
    5M tokens/month = ~$0.30/mo (negligible)
  - AssemblyAI transcription: $0.00025/sec
    200 users * 5 voice memos/month * 60 sec avg = 60K seconds
    Cost: ~$15/mo
  AI total: $60-100/mo

  STORAGE:
  - AWS S3: $0.023/GB
    200 users * 100MB avg = 20GB
    Cost: ~$0.50/mo + data transfer ~$2/mo
  S3 total: ~$3/mo

  THIRD-PARTY SERVICES:
  - Supabase Auth: $0 (free up to 50K MAU)
  - RevenueCat: $0 (free up to $2.5K MRR)
  - PostHog: $0 (free up to 1M events)
  - Apple Developer Account: $99/yr (~$8.25/mo)
  Services total: ~$8/mo

  DOMAIN & EMAIL:
  - Domain: $12/yr = $1/mo
  - Email (Loops.so or similar): $0-29/mo

  TOTAL INFRASTRUCTURE: $100-200/mo at 200 users

REVENUE AT 200 PAYING USERS:
  $1,998/mo gross
  - Apple's cut (30% year 1): -$599
  - Infrastructure: -$150 (avg)
  = NET: ~$1,249/mo

  Year 2 (Apple's cut drops to 15% for Small Business Program):
  $1,998 - $300 (15%) - $150 = ~$1,548/mo net

RISK: LOW — Infrastructure costs are very manageable at this scale.

------------------------------------------------------------------------
BREAK-EVEN ANALYSIS
------------------------------------------------------------------------

Fixed monthly costs: ~$150/mo (infrastructure)
Variable costs per user: ~$0.75/mo (AI + storage)
Apple's cut: 30% of revenue (year 1), 15% (year 2+)

Break-even calculation (year 1):
  Revenue per paying user: $9.99 * 0.70 (after Apple) = $6.99 net
  Variable cost per user: $0.75
  Contribution margin: $6.99 - $0.75 = $6.24 per user
  Fixed costs: $150/mo
  Break-even users: $150 / $6.24 = ~24 paying users

  AT 24 PAYING USERS, MEMO COVERS ITS INFRASTRUCTURE COSTS.

With marketing spend ($200/mo):
  Fixed costs: $350/mo
  Break-even: $350 / $6.24 = ~56 paying users

Path to break-even:
  Month 1-2: Beta, no revenue, costs ~$100/mo
  Month 3-4: First paying users (10-20), still negative
  Month 5-6: 30-50 paying users, approaching break-even
  Month 7-8: 60-80 paying users, profitable
  Month 9-12: 100-200 paying users, reinvest in growth

VERDICT: Break-even at ~24-56 paying users depending on ad spend.
This is very achievable within 6 months of launch.

RISK: LOW — The economics are sound. AI costs are the main variable,
but batch processing cuts them significantly.


================================================================================
SUMMARY: TOP RECOMMENDATIONS & RISK MATRIX
================================================================================

PRIORITY ACTIONS (do these first):
  1. Implement RevenueCat SDK with 7-day trial on both monthly/annual
  2. Build 3-step onboarding with commitment screen
  3. Server-side source limit enforcement (3 sources for free)
  4. AI consent modal for App Store compliance
  5. Start TikTok/Instagram content NOW (pre-launch, $0)

RISK MATRIX:
  LOW RISK:
  - RevenueCat implementation (mature SDK)
  - Discord community (free, audience exists)
  - PostHog analytics (free tier is generous)
  - Landing page with Carrd ($19/yr)
  - Infrastructure costs (manageable at 200 users)
  - Break-even point (achievable at 24-56 users)

  MEDIUM RISK:
  - App Store review (AI consent modal is critical)
  - TikTok ads ROI (requires creative iteration)
  - $2K MRR target (achievable but needs consistent execution)
  - GDPR compliance (build into MVP, don't retrofit)
  - Source connection during onboarding (A/B test both flows)

  HIGH RISK:
  - Social media scraping for Instagram/Facebook (avoid at MVP)
  - Relying solely on paid acquisition (organic must work first)

THINGS THAT DON'T MATTER YET:
  - Lifetime deals (don't offer until you have retention data)
  - Android (iOS only for 12+ months)
  - Team tier ($25/mo per user — build when you have enterprise interest)
  - Localization (English only for MVP)
  - Amplitude (overkill — PostHog is fine)

FINANCIAL SUMMARY:
  Break-even: 24-56 paying users (month 5-6)
  Target: 200 paying users = $2K MRR (month 12) -- REALISTIC
  Net profit at 200 users: ~$1,250/mo (year 1), ~$1,550/mo (year 2)
  Blended CAC target: <$10 per paying user
  LTV target: $35-100 depending on plan type
  Infrastructure at 200 users: ~$150/mo

================================================================================
SOURCES
================================================================================

RevenueCat:
- https://www.revenuecat.com/docs/tools/paywalls
- https://www.revenuecat.com/feature/experiments
- https://www.revenuecat.com/state-of-subscription-apps-2025/
- https://www.revenuecat.com/blog/growth/paywall-conversion-boosters/

Apple Search Ads:
- https://www.mobileaction.co/report/apple-ads-2026-benchmark-report/
- https://www.businessofapps.com/marketplace/apple-search-ads/research/apple-search-ads-costs/
- https://splitmetrics.com/apple-ads-search-results-benchmarks-2025/

TikTok:
- https://www.admetrics.io/en/post/tiktok-ads-costs-complete-2026-pricing-guide
- https://www.businessofapps.com/ads/cpi/research/cost-per-install/
- https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0319335

App Store:
- https://theapplaunchpad.com/blog/app-store-review-guidelines
- https://developer.apple.com/app-store/app-privacy-details/
- https://adapty.io/blog/how-to-pass-app-store-review/
- https://www.apptweak.com/en/aso-blog/aso-strategy

Analytics:
- https://posthog.com/blog/posthog-vs-mixpanel
- https://posthog.com/blog/best-mobile-app-analytics-tools

Subscriptions & Trials:
- https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/
- https://www.businessofapps.com/data/app-subscription-trial-benchmarks/
- https://phiture.com/mobilegrowthstack/the-subscription-stack-how-to-optimize-trial-length/

Compliance:
- https://secureprivacy.ai/blog/gdpr-compliance-mobile-apps
- https://secureprivacy.ai/blog/gdpr-compliance-2026
- https://onsecurity.io/article/pentest-findings-bypassing-freemium-through-client-side-security-controls/

Pricing:
- https://railway.com/pricing
- https://platform.claude.com/docs/en/about-claude/pricing
- https://segwise.ai/blog/roas-benchmarks-industry-standards

Competitors:
- https://www.saner.ai/blogs/best-adhd-note-taking-apps
- https://www.fahimai.com/capacities-vs-mem-ai
- https://gleamr.io/blog/omnivore-shut-down-alternatives
- https://danielprindii.com/blog/read-it-later-alternatives-after-omnivore-shutting-down

Landing Pages:
- https://geeksforgrowth.com/blog/webflow-vs-framer-vs-carrd-whats-best-for-startup-sites/
- https://www.subframe.com/tips/carrd-vs-framer-a7616

Community:
- https://www.influencers-time.com/building-an-engaging-discord-community-in-2025/
- https://medium.com/unheard-voices/from-discord-to-tiktok-building-thriving-online-communities-for-autistic-and-adhd-creators-709cc67bec15
