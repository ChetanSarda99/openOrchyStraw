# App Building Best Practices
## From $2k/Month App Case Study + Industry Insights

**Source:** "How I built an app that makes $2,000 in one month (from scratch)" + Memo Research  
**Created:** March 13, 2026  
**Status:** Living document - update as we learn

---

## Table of Contents
1. [Core Philosophy](#core-philosophy)
2. [Validation & Ideation](#validation--ideation)
3. [Onboarding Optimization](#onboarding-optimization)
4. [Paywall Strategy](#paywall-strategy)
5. [User Acquisition & Ads](#user-acquisition--ads)
6. [Analytics & Tracking](#analytics--tracking)
7. [Iteration Speed](#iteration-speed)
8. [Monetization](#monetization)
9. [Technical Tips](#technical-tips)

---

## Core Philosophy

### Build Fast, Iterate Faster
- **MVP in days, not months** - The creator built Glow in under a week
- Ship first version → get real users → iterate based on data
- Don't perfect features before launch - users will tell you what matters

### Data-Driven Everything
- Track every step of the user journey
- Make decisions based on metrics, not assumptions
- Test one variable at a time to understand impact

### User Journey is Everything
- Focus obsessively on the funnel: Install → Onboarding → Trial → Paid
- A 10% improvement in onboarding completion = massive revenue impact
- Users decide value in the first 60 seconds

---

## Validation & Ideation

### Problem-First Approach
1. Identify a real pain point (for Glow: daily affirmations/self-confidence)
2. Check if competitors exist (they should - validates demand)
3. Find the gap (what are competitors missing?)

### Competitive Research
- Don't reinvent the wheel - study top apps in your category
- Look at App Store reviews: what do users love? What frustrates them?
- Identify features that are "table stakes" vs. differentiators

### Target Market
- **Nordic countries strategy** - Glow targeted Norway, Sweden, Denmark, Finland
- High purchasing power + smaller markets = less competition
- English works, but native language ads/app increases conversion significantly

---

## Onboarding Optimization

### The Impact of Onboarding
- **Case study:** 74% → 83% completion = massive revenue increase
- Onboarding is where you lose or win customers
- Test relentlessly - small changes = big results

### Best Practices

#### 1. **Progress Bar**
- Simple visual showing "step X of Y"
- Reduces abandonment - users know how long it takes
- The creator forgot this initially and adding it boosted completion ~10%

#### 2. **One Concept Per Screen**
- Don't overwhelm with information
- Each screen should have ONE clear message/action
- Examples from Glow:
  - Screen 1: "What's your name?"
  - Screen 2: "How old are you?"
  - Screen 3: "What's your goal?" (self-confidence, success, health, etc.)

#### 3. **Personalization Questions**
- Ask 3-5 questions to tailor the experience
- Use answers to create "For You" recommendations
- Makes users feel the app understands them

#### 4. **Tutorial AFTER Commitment**
- Don't teach before they care
- Show value first → then explain features
- Glow's tutorial: "Tap category badge → see For You section → install widget"

#### 5. **Commitment Psychology**
- **Game-changer tactic** - Add before paywall
- Example: "I [Name] will use [App] to feel more [Goal]"
- Hold fingerprint to "sign" commitment
- Based on psychology: people follow through on commitments
- Used by Flow, Duolingo, Headway - works

#### 6. **Reduce Friction**
- Remove optional steps
- Auto-advance when possible
- Test removing screens that have high drop-off

### Metrics to Track
- **Onboarding completion rate** - Target: 80%+
- **Screen-by-screen drop-off** - Identify problem areas
- **Time to complete** - Too long = abandonment

---

## Paywall Strategy

### Multi-Step Paywall (Critical)
**Don't show everything at once** - Users won't read it

#### 3-Step Structure (Glow Example):
1. **Screen 1:** "Start your 3-day free trial"
   - Focus: No payment now
   - Build: Zero-risk message
2. **Screen 2:** "We'll remind you 1 day before trial ends"
   - Focus: Transparency builds trust
   - Removes: "I'll forget and get charged" fear
3. **Screen 3:** "Here's what you unlock with Premium"
   - Focus: Value proposition
   - Show: Specific features (themes, unlimited affirmations, widgets, etc.)

### Free Trial Best Practices
- **3-day trial** is optimal for habit-forming apps
- Shorter than 7 days = less time to forget
- Send reminder notification Day 2 (before trial ends)
- During trial: encourage daily usage (notifications, streak tracking)

### Trial-to-Paid Optimization
- Glow's struggle: 10 trials → 0 paid conversions initially
- Fix 1: Improved onboarding so users saw value
- Fix 2: Added "For You" personalized content
- Fix 3: Tutorial so users understood features
- **Result:** 10-15% trial-to-paid conversion after changes

### Pricing Strategy
- Study competitors' pricing
- Test different tiers (monthly vs. yearly)
- Yearly upfront = better LTV, but lower conversion
- Monthly = easier commitment, more trials convert

---

## User Acquisition & Ads

### Ad Platform Strategy

#### TikTok Ads (Primary Channel for Glow)
**Why TikTok:**
- Smart targeting (algorithm learns fast)
- Creative-first platform (authentic content wins)
- Lower CPI than Facebook/Google for new apps

**Setup:**
- Campaign type: "App Install"
- Optimization: "Install" (not clicks)
- iOS 14 dedicated campaign (if iOS-only)
- Minimum budget: $50/day for learning phase
- Run 3 days minimum before judging results

**Creative Strategy:**
- Test 6+ different videos in first campaign
- Each video highlights different feature:
  - Video 1: Widget showcase
  - Video 2: Notifications feature
  - Video 3: Customization/themes
  - Video 4: Before/after emotional hook
  - Video 5: Social proof (testimonials)
  - Video 6: App walkthrough
- Use TikTok-native content (NOT polished ads)
- Hook in first 3 seconds or users scroll past

**Targeting:**
- Start: Broad targeting (let algorithm learn)
- Countries: Nordic/high-income markets
- Age: 18+ (25+ converts better but smaller audience)
- Language: Match app language

**Budget Allocation:**
- Phase 1 (Days 1-3): €25-30/day testing
- Phase 2 (Days 4-7): Kill bad creatives, double budget on winners
- Phase 3 (Ongoing): Scale winning creative(s)

#### Apple Search Ads
**Why use:**
- High intent (users searching for your category)
- Often overlooked = cheaper than competition
- $100 free credit for new accounts (check Reddit for promos)

**Strategy:**
- Target competitor keywords
- Target category keywords (e.g., "affirmations app")
- CPI typically $2-5 depending on category
- Set max CPI bid to stay profitable

#### Free Ad Credit Hacks
1. **TikTok:** New accounts get "Spend $200, get $200" promos
2. **Apple Search Ads:** $100 credit for new accounts
3. **Google UAC:** Often has similar promos
4. **Result:** Glow got $300 free credits by using both

### Native Language Optimization
- **Creator's insight:** Ads in Norwegian/Swedish/Finnish would likely convert better
- Same for app localization
- Even if target market speaks English, native language = trust

---

## Analytics & Tracking

### Essential Metrics Dashboard

#### Revenue Metrics
- **Daily revenue** (absolute)
- **Revenue per install (RPI)** - Target varies by category
- **Customer acquisition cost (CAC)** - Must be < LTV
- **Lifetime value (LTV)** - Predict based on retention cohorts

#### Funnel Metrics
1. **Install → App Open** (should be ~95%+)
2. **App Open → Onboarding Start** (98%+)
3. **Onboarding Start → Onboarding Complete** (target: 80%+)
4. **Onboarding Complete → Paywall Shown** (should be 100%)
5. **Paywall Shown → Trial Start** (target: 20-40%)
6. **Trial Start → Paid Conversion** (target: 10-25%)

#### User Behavior
- **Session length** - Are users engaging?
- **Day 1, 3, 7 retention** - Critical for trial conversion
- **Feature usage** - What do paying users use most?

### Tools Used (Glow Case Study)
- **RevenueCat** - Paywall management, analytics, A/B testing
- **Cloud Code** - Custom analytics dashboard
- **TikTok Events API** - Track install attribution
- **Firebase Analytics** - User behavior tracking

### Screen-by-Screen Tracking
- Track drop-off at EACH onboarding screen
- Example from Glow:
  - 100 installs
  - 95 start onboarding
  - 90 complete name input
  - 85 complete age input
  - 83 complete goal selection
  - 78 reach paywall
  - 12 start trial
- **Action:** Remove/simplify screens with big drop-offs

---

## Iteration Speed

### Rapid Testing Cycle
**Glow's iteration speed:**
- Day 1-7: Build MVP
- Day 8-10: Launch ads, get first users
- Day 11-20: See poor conversion, iterate onboarding v2
- Day 21-24: Test new ads, pause campaign, fix tracking
- Day 25-28: Onboarding v3 (progress bar + commitment)
- Day 29-31: See 10% boost, iterate paywall
- Day 32-36: Localization tests, theme feature, conversion improves

**Key insight:** Ship updates every 2-3 days during growth phase

### A/B Testing Priorities
1. **Onboarding flow** (biggest impact)
2. **Paywall copy/design** (second biggest)
3. **Ad creatives** (drives volume)
4. **Pricing tiers** (test last - needs more data)

### Apple Review Speed Hack
**Instead of Expo EAS (slow queue):**
- Use **Transporter app** (official Apple tool)
- Drag & drop .ipa file
- 5 minutes to App Store Connect vs. 1-2 hours with EAS
- Only for iOS (Android use EAS)

---

## Monetization

### Subscription Model (Best for Apps)
- **Why subscriptions >> one-time:**
  - Predictable recurring revenue
  - Higher LTV
  - Aligns incentives (you keep improving → users stay)
- **Typical tiers:**
  - Monthly: $4.99-9.99
  - Yearly: $29.99-49.99 (include 2-month discount)
  - Lifetime: Controversial (cannibalizes subscriptions)

### Free vs. Freemium vs. Paid
**Glow's model: Freemium + Trial**
- Free: Basic features (limited affirmations, no themes, no widgets)
- Trial: 3 days full premium
- Premium: Unlimited content, customization, widgets

**Why this works:**
- Free tier removes download friction
- Users experience value before paying
- Trial converts curious users
- Premium retains engaged users

### What to Put Behind Paywall
**Free (Table Stakes):**
- Core functionality works
- Enough to understand value
- Example: 5-10 affirmation categories, basic UI

**Premium (Differentiated):**
- Customization (themes, fonts, backgrounds)
- Advanced features (widgets, Apple Watch, Siri shortcuts)
- Unlimited content/storage
- Ad-free experience

### Revenue Expectations
**Glow case study (30 days):**
- Spent: $200 (ads)
- Revenue: $2,000
- Net profit: $1,800
- 10x ROAS (return on ad spend)

**Reality check:**
- Most apps: 2-3x ROAS is good
- Takes 3-6 months to optimize to 5x+
- First month usually breakeven or loss

---

## Technical Tips

### Build Stack (Glow Used)
- **Framework:** React Native (one codebase, iOS + Android)
- **Expo:** Faster development, easier deployment
- **RevenueCat:** Paywall/subscription management
- **Firebase:** Analytics + push notifications
- **TikTok SDK:** Ad attribution tracking

### iOS-Specific
- **Transporter app** for fast builds (see Iteration Speed)
- **TestFlight** for beta testing (get feedback before launch)
- **App Store Connect API** for automated builds
- **StoreKit** for native paywall UI (or use RevenueCat)

### Push Notifications Strategy
- **Day 1:** Welcome message (remind them to set up)
- **Day 2:** Usage reminder (if they haven't opened)
- **Day 3:** Trial ending reminder (for trial users)
- **Daily:** Habit reminder (e.g., "Time for your affirmations")
- **Avoid spam:** Max 1 notification per day unless urgent

### Attribution Tracking
- **Critical for ads:** Know which campaign/creative drove install
- **TikTok Events API:** Send install event with campaign ID
- **Glow mistake:** Initially sent wrong payload → couldn't attribute
- **Fix:** Test attribution before spending big on ads

---

## Lessons Specific to Memo

### Apply to Memo (Note Aggregator App)

#### Onboarding Flow
1. **Screen 1:** "What do you save?" (Instagram, Twitter, Telegram, Notion, Voice memos)
2. **Screen 2:** "Connect your first source" (pick one to start)
3. **Screen 3:** Test search with sample data
4. **Screen 4:** Commitment - "I'll never lose an idea again"
5. **Paywall:** 3-step structure
6. **Tutorial:** Show search, tagging, cross-source results

#### Key Differences from Glow
- **Memo value = save time finding stuff** (demonstrate search speed)
- **Network effects = more sources = more value** (encourage adding 2-3 in trial)
- **ADHD angle = relatable pain point** (lean into this for ads)

#### Ad Creative Ideas (TikTok)
1. "POV: You finally remember that Instagram reel... but can't find it" → Show Memo finding it
2. "ADHD brain saves 47 ideas across 10 apps" → Memo shows all in one search
3. Before/after: Scrolling Telegram for 10 min vs. Memo instant search
4. "Why isn't this built into phones?" emotional hook
5. Social proof: "Everyone with ADHD needs this" user testimonial
6. Feature showcase: Cross-source search (type "productivity" → see Notion + Telegram + Twitter)

#### Pricing Strategy
- **Free:** 3 sources (e.g., Telegram + Notion + Voice)
- **Pro ($9.99/mo):** Unlimited sources + AI summarization
- **Trial:** 7 days (need time to save enough to see value)

---

## Resources & Further Learning

### Communities
- **Discord:** Creator built community for accountability + knowledge sharing
- **Reddit:** r/SideProject, r/EntrepreneurRideAlong, r/iOSProgramming
- **Twitter:** Follow app developers sharing their journey (#BuildInPublic)

### Tools Mentioned
- **RevenueCat** (revenuecat.com) - Paywall management + analytics
- **Transporter** (Apple app) - Fast iOS build uploads
- **TikTok Ads Manager** - Creative testing at scale
- **Apple Search Ads** - High-intent user acquisition

### Articles Referenced
- RevenueCat: "How to Fix Your Onboarding Funnel"
- Commitment psychology in apps (Duolingo, Flow, Headway)

---

## Action Items for Memo

### Pre-Launch (Weeks 1-2)
- [ ] Build onboarding flow with progress bar
- [ ] Implement 3-step paywall
- [ ] Set up RevenueCat for subscription management
- [ ] Create analytics dashboard (track funnel metrics)
- [ ] Design 6 TikTok ad creatives (ADHD angle)

### Launch Week (Week 3)
- [ ] Deploy to TestFlight for beta feedback
- [ ] Submit to App Store
- [ ] Set up TikTok Ads account (claim $200 credit)
- [ ] Set up Apple Search Ads (claim $100 credit)
- [ ] Launch with $30/day ad budget

### Post-Launch (Weeks 4-8)
- [ ] Track onboarding completion daily
- [ ] Test commitment psychology screen
- [ ] Test personalized "For You" sources recommendations
- [ ] Optimize trial-to-paid conversion
- [ ] Scale winning ad creative

### Month 2-3
- [ ] Add native language support (if targeting non-English markets)
- [ ] Build community (Discord/Reddit)
- [ ] Implement retention features (streaks, notifications)
- [ ] Test pricing tiers
- [ ] Aim for 3x ROAS minimum

---

## Key Takeaways

1. **Onboarding is the #1 priority** - 10% improvement = massive revenue impact
2. **Iterate fast** - Ship every 2-3 days during growth phase
3. **Data over intuition** - Track everything, test one change at a time
4. **Commitment psychology works** - Add before paywall
5. **Multi-step paywall > single screen** - Don't overwhelm users
6. **TikTok ads = creative-first** - Authentic content beats polished ads
7. **Free ad credits exist** - TikTok + Apple = $300 to start
8. **Trial length matters** - 3 days for simple apps, 7 days for complex
9. **Transporter app** - 10x faster iOS builds
10. **Build community** - Discord/Twitter for accountability + learning

---

**Last Updated:** March 13, 2026  
**Next Review:** After Memo MVP launch  
**Owner:** CS / Chai
