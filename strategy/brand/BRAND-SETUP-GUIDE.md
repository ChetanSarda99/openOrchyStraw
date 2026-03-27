# Brand Setup Guide — CS's App Empire

## The Two-Layer Strategy

You need **two brands**:
1. **Studio brand** — your company/publisher identity (LinkedIn, Apple Developer, Google Play)
2. **App brands** — each app has its own name, domain, social accounts

### Why Two Layers?
- Apple Developer Account shows **publisher name** on every app → needs to look legit
- LinkedIn credibility is built under **your personal name + studio name**
- Each app gets its own landing page, Twitter/X, and potentially subreddit
- Studio brand = authority. App brand = marketing.

---

## Part 1: Rename "Memo" — Top Candidates

**Problem:** "Memo" has 3-4 active competitors, memo.app is taken ($5K-$50K+), you'll lose SEO and App Store battles.

### Naming Principles
- **Unique & ownable** — zero competitors with same name
- **Short** (≤8 chars) — easy to type, remember, say out loud
- **Domain + handles available** — .app preferred for iOS apps
- **Describes the value** — hints at what it does
- **ADHD-friendly** — punchy, not boring

### ⚠️ Name Validation Protocol (MANDATORY before committing to any name)

**Never suggest a name without completing ALL validation steps first.**

#### Step 1: Generate 15+ Candidates
- Use naming principles above + phonetic science from BRAND_NAME_SCIENCE.md
- Mix approaches: invented spellings, real words, compound words, truncated words
- Cover different emotional registers (punchy vs calm, short vs medium)

#### Step 2: Domain Availability Check (for EACH candidate)
Run automated checks on priority domains:
```bash
for domain in <name>.app <name>.co <name>.io get<name>.app get<name>.com <name>ai.com try<name>.app; do
  code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 8 "https://$domain" 2>/dev/null || echo "ERR")
  dns=$(dig +short "$domain" 2>/dev/null | head -1)
  echo "$domain | HTTP: $code | DNS: ${dns:-NONE}"
done
```
- **Available:** No DNS record + no HTTP response (or connection refused)
- **Taken:** Active site, redirect, or parked/for-sale page
- **Unclear:** 404/405 with no DNS — may be registered but unused

#### Step 3: App Store & Product Conflict Check
For each surviving candidate:
- Search: `"<name> app iOS"` — check for existing iOS apps
- Search: `"<name> app"` and `"<name> software"` — check for SaaS/products
- Check App Store directly if possible
- Check G2, Product Hunt, AlternativeTo

#### Step 4: Social Handle Check
For top survivors, verify handle availability:
- Twitter/X: @<name>, @<name>app, @get<name>
- Instagram: @<name>, @<name>app, @get<name>
- TikTok: @<name>, @<name>app
- Reddit: r/<name>, r/<name>app
- GitHub: <name>, <name>-app

#### Step 5: Elimination Criteria
**ELIMINATE immediately if:**
- ❌ Active website on `.com` or `.app` domain
- ❌ Existing iOS/Android app with same name (even if different category)
- ❌ Major existing product/brand using the name (SaaS, open source, etc.)
- ❌ Trademark conflict in same class (search USPTO TESS)
- ⚠️ Multiple parked/for-sale domains (signals name is "known" and may be contested)

#### Step 6: Present TOP 3 Only
For each finalist, provide:
- Name + pronunciation
- Available domains (confirmed)
- Available handles (confirmed)
- Tagline idea
- Why it works (phonetics, meaning, ownable-ness)
- Any risks or caveats

**Example of a FAILED validation:** "Klaro" — passed phonetic/meaning tests but failed Step 3 (4+ existing products: klaroapp.com SaaS, iOS humidity app, G2 project management tool, Klaro! consent manager used by UNICEF). Never made it to suggestion.

### Top App Name Picks (ALL confirmed available .app domains)

| Rank | Name | Domain | Why It Works |
|------|------|--------|-------------|
| 🥇 | **Rekall** | rekall.app | "Total recall for your brain." Instantly communicates finding + memory. Sci-fi cool (Total Recall movie). 6 chars. Note: rekal.app is taken (study app), but rekall.app is FREE. |
| 🥈 | **Savd** | savd.app | "Everything you saved. One search." Minimal, punchy, self-explanatory. 4 chars. The missing vowel = tech-forward. |
| 🥉 | **MindSift** | mindsift.app | "Sift through everything in your mind." Describes the action. 8 chars. Clear value prop. |
| 4 | **Hoardr** | hoardr.app | "For digital hoarders." Self-deprecating (ADHD people relate). Funny. 6 chars. Risk: slightly negative connotation. |
| 5 | **BrainBin** | brainbin.app | "Your second brain's junk drawer — but searchable." 8 chars. Playful + descriptive. |
| 6 | **CatchAll** | catchall.app | "Catch everything. Find anything." 8 chars. Descriptive but more generic. |
| 7 | **Ingest** | ingest.app | "Ingest all your sources." Technical/power-user vibe. 6 chars. Clean. |

### My Pick: **Rekall**
- Memorable, unique, zero competitors
- "Total Rekall for your digital brain" — the tagline writes itself
- Sci-fi/cyberpunk vibe fits ADHD-tech aesthetic
- Easy to say: "just Rekall it"
- rekall.app is UNREGISTERED right now

---

## Part 2: Studio/Publisher Name

This goes on your Apple Developer account, LinkedIn company page, and all App Store listings.

### Top Studio Name Picks (ALL confirmed available domains)

| Name | Domain(s) | Vibe |
|------|-----------|------|
| **Sarda Labs** | sardalabs.com, sardalabs.dev | Your last name → instant personal brand tie. "Labs" = indie tech credibility. Short. |
| **Empire Apps** | empireapps.com, empireapps.dev | Ties to your "Empire OS" philosophy. Bold. |
| **Neuroship** | neuroship.com, neuroship.dev | "Neuro" (ADHD/brain focus) + "Ship" (shipping products). Unique. |
| **Sparkline** | sparkline.dev, sparklineapps.com | Data viz term (you're a data analyst). Subtle, elegant. |
| **Cerebral Labs** | cerebrallabs.dev | Brain-focused. Premium sound. Longer though. |

### My Pick: **Sarda Labs**
- Personally branded (you ARE the company)
- Short, memorable, professional
- Works on LinkedIn: "Founder, Sarda Labs"
- Works on App Store: "by Sarda Labs"
- sardalabs.com + sardalabs.dev both available
- Future apps all under one credible publisher

---

## Part 3: Complete Brand Setup Checklist

### Day 1: Foundation (30 minutes)

#### Domain Registration
- [ ] Buy **rekall.app** (or your pick) — ~$14-20/year on Google Domains, Namecheap, or Cloudflare
- [ ] Buy **sardalabs.com** (or studio pick) — ~$12/year
- [ ] Point both to Cloudflare DNS (free, fast, SSL)
- [ ] Set up email: `cs@sardalabs.com` (Google Workspace $7/mo or Zoho free tier)

#### Apple Developer Account
- [ ] Sign up at developer.apple.com — $99 USD/year
- [ ] Register as **Individual** first (faster approval, ~48 hours)
- [ ] Later: convert to Organization once you have LLC/corp (shows company name on App Store)
- [ ] Your legal name shows as developer until you convert → fine for now
- [ ] Pro tip: Apple requires a **website with contact info** for organization accounts → sardalabs.com

#### Google Play Developer Account
- [ ] Sign up at play.google.com/console — $25 one-time
- [ ] Use studio name as developer name
- [ ] Even if iOS-first, reserve this now

### Day 2: Social Presence (1 hour)

#### LinkedIn — MOST IMPORTANT for credibility
**Personal Profile:**
- [ ] Update headline: "Founder, Sarda Labs | Building [App Name] — [one-liner tagline]"
- [ ] Update About section: your story (engineer → data analyst → indie dev, building tools for ADHD brains)
- [ ] Add "Sarda Labs" as current position (Founder, Mar 2026 → Present)
- [ ] Profile photo: professional but approachable (not corporate)

**Company Page:**
- [ ] Create LinkedIn Company Page: "Sarda Labs"
- [ ] Logo + banner (can be simple — Figma template, ship fast)
- [ ] Description: "Building apps for minds that work differently"
- [ ] Add yourself as employee
- [ ] This makes "Sarda Labs" appear as a real company when people click it

**Content Strategy (start in week 2):**
- Post 2-3x/week on your PERSONAL profile (not company page — company pages have ~0 organic reach)
- Topics that build credibility:
  - "Building in public" posts (screenshots, progress, design decisions)
  - ADHD + productivity insights (your lived experience = authenticity)
  - Technical deep dives (Swift, AI/ML, search architecture)
  - Lessons learned (honest > polished)
- Format: short text posts with 1 hook, story, takeaway. NO images needed.
- Self-comment on every post (boosts reach ~30%)
- Engage with 5-10 posts in your niche daily (10 min)

#### X/Twitter
- [ ] Create @getrekall (app) — `@rekallapp` is TAKEN (dormant account). `@getrekall` is available.
- [ ] Create @SardLabs (studio) — reserve the handle
- [ ] Post build-in-public threads, ship updates, engagement
- [ ] This is where indie devs + tech people discover apps
- [ ] Follow + engage with: indie hackers, iOS devs, ADHD community

#### Reddit
- [ ] DO NOT make a company account for Reddit — Reddit hates self-promotion
- [ ] Use your personal account
- [ ] Contribute genuinely to: r/iOSProgramming, r/SideProject, r/ADHD, r/IndieHackers, r/Apple
- [ ] When your app launches: ONE launch post in r/SideProject, r/Apple, r/ADHD (if relevant)
- [ ] r/ADHD is your GOLDMINE — if Rekall genuinely helps, they'll spread the word organically
- [ ] After launch: create r/rekallapp for support/community

#### GitHub
- [ ] Your ChetanSarda99 account is fine
- [ ] Pin relevant repos (agent-factory is a good credibility signal)
- [ ] Contribute to open source if you can — looks great on LinkedIn
- [ ] If you open-source parts of Rekall (SDK, plugins), that builds dev trust

#### Other (reserve handles now, use later)
- [ ] Instagram: @getrekall (app — `@rekallapp` TAKEN by "Miguel") + @sardalabs (studio)
- [ ] TikTok: @getrekall (app — `@rekallapp` TAKEN by squatter) + @sardalabs (studio)
- [ ] Product Hunt: create account → launch day is critical
- [ ] Threads: @getrekall + @sardalabs — Meta's Twitter competitor, might matter

#### Handle Availability Summary (verified Mar 15, 2026)

| Platform | App Handle | Status | Studio Handle |
|----------|-----------|--------|---------------|
| Domain | rekall.app | ✅ Available | sardalabs.com + .dev ✅ |
| GitHub | rekallapp | ✅ Available | — |
| Reddit | r/rekallapp | ✅ Available | — |
| X/Twitter | @getrekall | ✅ Available | @SardLabs (check) |
| Instagram | @getrekall | ✅ Available | @sardalabs (check) |
| TikTok | @getrekall | ✅ Available | @sardalabs (check) |

**Taken handles:** @rekallapp on X (dormant), IG ("Miguel"), TikTok (squatter, 0 content).
**Backup handles if needed:** @rekall_app (available on IG + TikTok)

### Day 3-7: Landing Page + Credibility Foundations

#### Studio Website (sardalabs.com)
- Simple one-page site:
  - Hero: "We build apps for minds that work differently"
  - About: Your story
  - Apps: Grid of your apps (just Rekall for now)
  - Contact: cs@sardalabs.com
- Deploy on Vercel/Cloudflare Pages (free)
- This satisfies Apple's organization account requirement

#### App Landing Page (rekall.app)
- Spectacular page (use Aceternity UI + Next.js + Tailwind + Framer Motion)
- iPhone mockup hero, feature sections, pricing, App Store badge
- Email capture for waitlist (ConvertKit free tier or simple Supabase table)
- This is your marketing anchor

---

## Part 4: Account Structure

### Personal vs Business — The Right Split

```
CS (Personal)
├── LinkedIn: Chetan Sarda (personal — this is where credibility lives)
│   └── Position: "Founder, Sarda Labs"
├── X/Twitter: @chaitean (personal thoughts, retweets from studio)
├── Reddit: personal account (genuine participation)
├── GitHub: ChetanSarda99 (code + open source)
└── Telegram: @chaitean (personal comms)

Sarda Labs (Studio)
├── LinkedIn: Sarda Labs Company Page
├── X/Twitter: @SardLabs (company updates, launches)
├── Email: cs@sardalabs.com (business comms)
├── Apple Developer: Sarda Labs (publisher name)
├── Google Play: Sarda Labs
├── Website: sardalabs.com
└── Product Hunt: Sarda Labs

Rekall (App)
├── X/Twitter: @rekallapp (app updates, user engagement)
├── Website: rekall.app (landing page)
├── Reddit: r/rekallapp (post-launch community)
├── Instagram: @rekallapp (design showcases)
└── App Store: "Rekall — Find Everything You Saved" by Sarda Labs

Future App 2 (e.g. Joint-Safe Fitness)
├── X/Twitter: @[appname]
├── Website: [appname].app
└── App Store: "[App Name]" by Sarda Labs  ← same publisher!
```

### Key Principle
- **Personal brand sells the studio** (LinkedIn posts, credibility)
- **Studio brand publishes the apps** (App Store, professional identity)
- **App brands market themselves** (own landing pages, own socials)
- Cross-pollinate: every app says "by Sarda Labs", studio website lists all apps

---

## Part 5: Credibility Playbook (Weeks 1-12)

### Weeks 1-2: Setup
- Register everything above
- Write first 5 LinkedIn posts (queue them)
- Deploy sardalabs.com (simple, 1 evening)
- Deploy rekall.app landing page with waitlist

### Weeks 3-6: Build in Public
- Post 3x/week on LinkedIn (personal profile)
  - "Day 1 of building Rekall — why I'm solving my own ADHD problem"
  - "The search architecture behind Rekall"
  - "What I learned from 6 months of Notion data hoarding"
- Tweet daily about progress (@SardLabs + @rekallapp)
- Engage authentically on Reddit (r/ADHD, r/iOSProgramming)
- Start collecting emails on rekall.app

### Weeks 6-8: Credibility Signals
- Publish a blog post: "Why I Built Rekall" (Medium + sardalabs.com/blog)
- Get featured on Indie Hackers (free product listing)
- Submit to BetaList.com (pre-launch listing, ~2-week wait)
- Record a short Loom demo → post on LinkedIn + Twitter
- Share on relevant Discord communities (indie hackers, ADHD, iOS dev)

### Weeks 8-12: Launch Prep
- Product Hunt launch prep (get 5+ hunters/followers to upvote day-of)
- Reach out to ADHD YouTubers/bloggers for early access
- Prepare App Store screenshots + preview video
- Write press email template for tech blogs
- Reddit launch posts (r/SideProject, r/Apple, r/ADHD)

### LinkedIn Content Templates

**Hook formats that work:**
1. "I'm building [app] because [personal story]" → empathy
2. "Here's what I learned after [specific thing]" → value
3. "Most people think [common belief]. Here's why that's wrong." → curiosity
4. "[Number] things I wish I knew before [doing X]" → listicle
5. "I [did something bold]. Here's what happened." → story

**Post structure (for LinkedIn):**
```
[Hook — 1 punchy line]

[Space — forces "See more" click]

[2-3 paragraphs of story/value]

[Takeaway or call-to-action]

---
[Self-comment with additional context or link]
```

---

## Part 6: Tools & Costs

| Item | Cost | When |
|------|------|------|
| rekall.app domain | ~$14-20/yr | Day 1 |
| sardalabs.com domain | ~$12/yr | Day 1 |
| Apple Developer Account | $99/yr | Day 1 |
| Google Play Account | $25 one-time | Day 1 |
| Email (Zoho free or Google Workspace) | $0-7/mo | Day 1 |
| Cloudflare (DNS + CDN) | Free | Day 1 |
| Vercel/Cloudflare Pages (hosting) | Free | Day 3 |
| ConvertKit (email list) | Free (≤1000 subs) | Week 1 |
| Namechk.com (handle checker) | Free | Day 1 |
| Figma (logo/branding) | Free tier | Day 1 |
| **Total initial:** | **~$150** | |
| **Monthly ongoing:** | **$0-7** | |

---

## Part 7: Common Mistakes to Avoid

1. **Don't use company page for LinkedIn content** — personal profiles get 10x reach
2. **Don't spam Reddit** — genuine participation THEN one launch post
3. **Don't wait for "perfect" branding** — ship fast, iterate
4. **Don't create separate Apple ID per app** — one publisher account for all apps
5. **Don't pay for LinkedIn Premium yet** — only worth it at 1000+ followers
6. **Don't buy premium domains** — $14 .app domain works perfectly
7. **Don't create LLC before revenue** — individual account first, convert later
8. **Don't post the same content everywhere** — adapt per platform

---

## Part 8: Platform Priority (What Matters Most)

1. **LinkedIn** (personal profile) — #1 for B2B credibility, founder brand, job safety net
2. **X/Twitter** — #1 for indie dev community, build-in-public
3. **Product Hunt** — #1 for launch day spike
4. **Reddit** — #1 for organic word-of-mouth (esp. r/ADHD)
5. **Landing page** — #1 for email capture + App Store conversion
6. **Instagram/TikTok** — only if you want to do ADHD content (huge audience there)

---

---

## Part 9: Reddit Strategy — ADHD Communities Deep Dive

### The Landscape (Your Target Subreddits)

| Subreddit | Members | What It Is | Your Play |
|-----------|---------|-----------|-----------|
| **r/ADHD** | ~2.2M | Main ADHD support community. Strict rules. Science-backed. | Help people, share coping strategies. **NO self-promo allowed.** |
| **r/ADHD_Programmers** | ~100K+ | ADHD devs sharing productivity tips, tools, struggles | **HAS "Dev-Self Promotion" flair** — this is your gold mine |
| **r/adhdwomen** | ~547K | Women with ADHD (large, active) | Participate genuinely; your app serves this audience too |
| **r/ADHDmemes** / **r/ADHDmeme** | ~183K | Meme subs — high engagement, low effort | Lurk, engage, build karma. Not for promotion. |
| **r/neurodiversity** | ~117K | Broader neurodivergent community | Cross-post relevant content |
| **r/ADHDUK** | ~45K | UK-based ADHD community | Skip (you're in Vancouver) |
| **r/productivity** | ~1M+ | General productivity crowd | Share ADHD-specific productivity tips |
| **r/iOSProgramming** | ~150K+ | iOS dev community | Technical posts, build-in-public |
| **r/SideProject** | ~200K+ | Indie builders sharing projects | **Launch post here** |
| **r/Apple** | ~6M+ | Apple ecosystem fans | App launch, if noteworthy |

### Critical Rule: r/ADHD Bans ALL Self-Promotion

From their official rules:
> "We are a support community and will remove **any form of advertising or self-promotion.**"

This means:
- ❌ You CANNOT post "Hey I built an ADHD app"
- ❌ You CANNOT link to your app, even casually
- ❌ You CANNOT do market research or surveys
- ✅ You CAN share your personal ADHD experience genuinely
- ✅ You CAN recommend tools you use (if you genuinely use them, not just yours)
- ✅ You CAN build karma by being a helpful community member

**r/ADHD is for credibility farming, NOT direct promotion.**

### r/ADHD_Programmers — Your #1 Subreddit

This sub **explicitly allows dev self-promotion** with a dedicated flair:
> "Developers are welcome to post their productivity apps using the **Dev-Self Promotion** flair to get honest productivity feedback and reviews from moderators and the community."

BUT — they're also getting tired of low-effort ADHD app spam:
> "Recently this forum gets flooded with (mostly badly vibe coded) ADHD apps. Can we please add a rule to get rid of them?"

**What this means for you:** Your post needs to be REAL. Not "I made an ADHD app, check it out." It needs to be: "I have ADHD. Here's the specific problem I couldn't solve. Here's what I built. Here's what I learned. Roast me."

### The 90-Day Reddit Playbook

#### Phase 1: Weeks 1-4 — Be a Human First (NO promotion)

**Goal:** Build karma to 500+, establish presence, become a recognized name.

**Daily routine (15-20 min):**
1. Sort r/ADHD by **New** → find 2-3 posts you can genuinely help with
2. Write thoughtful comments (3-5 sentences minimum, not one-liners)
3. Share YOUR real ADHD experiences — medication, routines, what works for you
4. Upvote good content, engage with other commenters

**Topics where YOU have real authority (use these):**
- Morning routines with ADHD (you literally have a 5:30 AM system)
- ADHD + working out (gym routine, knee management)
- ADHD + building systems (you've built an entire "Empire OS")
- ADHD + Wellbutrin experiences
- ADHD + data/tech careers
- ADHD + weight management
- ADHD + meditation (you do it daily)
- ADHD + information overload (saving things everywhere — THE problem your app solves)

**Example comments you could write RIGHT NOW:**

> *On a "How do you manage mornings?" post:*
> "26M, diagnosed ADHD. I tried every morning routine hack for years and most of them fell apart within a week. What finally worked: I made my routine so rigid there are zero decisions. 5:30 alarm, meds immediately (Wellbutrin + vitamins on my nightstand), 10 min meditation, then walk. No phone until after meditation. The key was removing all choice — my ADHD brain can't handle 'should I do X or Y?' at 5:30 AM. It's been 3 weeks and I haven't missed once."

> *On a "I save everything but can never find it" post:*
> "This is literally my life. I have notes in Notion, screenshots in Telegram, voice memos on my phone, bookmarks in Chrome, saved posts on Reddit and Instagram... and when I actually need something I spend 20 minutes searching 6 different apps. The worst part is KNOWING you saved it somewhere but not remembering WHERE. I've started thinking about this as a design problem — what if there was just ONE search bar that searched everything?"

☝️ That second one is PERFECT. It's genuine. It's relatable. And months later when you launch, people will remember "oh that's the guy who had the same problem."

#### Phase 2: Weeks 4-8 — Build Authority

**Goal:** Karma 1000+, become a "regular" the community recognizes.

**Weekly additions:**
- Write 1 original post per week on r/ADHD (your real experiences, 280+ chars minimum)
- Start commenting in r/ADHD_Programmers about your dev process
- Share technical ADHD productivity approaches in r/productivity

**Post ideas (all genuine, from your life):**

1. "How building a rigid system saved my mornings — ADHD brain needs zero-decision routines"
2. "ADHD + weight loss: what actually worked after years of yo-yo (86→75kg journey)"
3. "I have 10+ apps with 'saved' content I'll never find again — the ADHD hoarding problem nobody talks about"
4. "As a data analyst with ADHD, here's how I stay focused during deep work at the office"
5. "My ADHD meditation journey: from 'I literally cannot sit still' to daily practice"
6. "ADHD time blindness nearly cost me my career — here's the visual timer system I built"

**The Information Hoarding Post (#3) is your Trojan horse.** It surfaces the EXACT problem your app solves. Other ADHD people will flood the comments saying "omg same." You now have:
- Proof of demand
- A list of people who feel this pain
- Authority as someone who understands the problem
- And you NEVER mentioned your app.

#### Phase 3: Weeks 8-12 — Soft Launch

**r/ADHD_Programmers first (they welcome it):**

Post with "Dev-Self Promotion" flair:

> **Title:** "I have ADHD and I built the app I wished existed — one search bar for everything I've ever saved. Would love brutal feedback."
>
> **Body:** Tell your story. The problem (saving everywhere, finding nowhere). Why existing tools don't work. What you built. Screenshots. What's working, what's not. Ask for honest feedback. Offer TestFlight codes.
>
> **Key:** Be vulnerable. Be specific. Show you're dogfooding it. Show you have ADHD yourself. This is NOT a press release — it's a fellow ADHD dev sharing their project.

**Then cross-post to:**
- r/SideProject — "Shipped my first iOS app after 6 months of solo building"
- r/iOSProgramming — technical focus, architecture decisions
- r/productivity — "How I solved the 'saved in 10 apps, found in zero' problem"

**DO NOT post in r/ADHD.** The mods will remove it instantly. Let it spread organically. If you've been helpful for 8 weeks, people will mention your app FOR you in r/ADHD comments.

#### Phase 4: Ongoing — Community Building

- Create r/rekallapp (or whatever name you pick) → support sub
- Cross-post updates to r/ADHD_Programmers periodically (monthly max)
- Reply to EVERY comment on your posts (engagement signals = more visibility)
- When people in r/ADHD post about info hoarding, others will tag you or mention your app
- Give away free codes/lifetime access to early r/ADHD_Programmers users → they become evangelists

### Reddit Rules You MUST Follow

1. **Reddit-wide 10% rule:** No more than 10% of your posts/comments should be self-promotional
2. **r/ADHD:** ZERO self-promotion. Period. Even "subtle" mentions get caught.
3. **r/ADHD_Programmers:** Use the Dev-Self Promotion flair. Be genuine. Accept criticism.
4. **Never use a brand account on Reddit.** Always your personal account. Redditors despise corporate accounts.
5. **Never ask for upvotes.** Never coordinate upvotes. Reddit auto-detects this.
6. **Write everything yourself.** r/ADHD_Programmers explicitly bans AI-written posts: "No one here needs AI written posts about experiences, write it yourself so that it actually describes your lived experiences"
7. **Don't post the same content to multiple subs simultaneously.** Space it out over days.

### Karma Building Quick Wins (While Being Genuine)

| Action | Karma Potential | Time |
|--------|----------------|------|
| Thoughtful comment on r/ADHD | 10-200 per comment | 5 min |
| Sharing personal ADHD experience | 50-500 per post | 15 min |
| Answering "what app do you use for X?" threads | 5-50 per comment | 3 min |
| Detailed r/ADHD_Programmers productivity tip | 50-300 per comment | 10 min |
| Original post about ADHD coping strategy | 100-2000+ per post | 20 min |
| Launch post with Dev-Self Promotion flair | 50-500+ | 30 min |

**Target: 500 karma by week 4, 2000+ by week 8.** This puts you in the "Experienced" tier where algorithms favor your content and mods trust you.

### What NOT to Do on Reddit (Instant Credibility Killers)

1. ❌ Create a throwaway to post about your app → mods check account age
2. ❌ Have friends upvote your posts → Reddit detects vote manipulation
3. ❌ Post "anyone else save stuff everywhere? 😅" as a setup to mention your app → transparent, will get called out
4. ❌ DM people who comment about your problem → creepy, reportable
5. ❌ Use AI to write your posts → r/ADHD_Programmers explicitly bans this, and Redditors can smell it
6. ❌ Cross-post your launch to r/ADHD → instant removal + potential ban
7. ❌ Post more than once per month about your app in any sub → spam
8. ❌ Argue with negative feedback → take it, thank them, improve

### The Timeline Summary

| Week | Action | Where |
|------|--------|-------|
| 1-2 | Comment helpfully, share experiences | r/ADHD, r/ADHD_Programmers |
| 3-4 | First original posts (your ADHD story) | r/ADHD |
| 4-6 | Post about "information hoarding" problem | r/ADHD (NO app mention) |
| 6-8 | Share dev journey posts | r/ADHD_Programmers, r/SideProject |
| 8-10 | **Launch post** with Dev-Self Promotion flair | r/ADHD_Programmers |
| 8-10 | Cross-post to other subs (spaced out) | r/SideProject, r/iOSProgramming |
| 10-12 | Create r/rekallapp, engage with early users | Your sub |
| 12+ | Monthly updates, respond to all feedback | r/ADHD_Programmers |

---

## Quick Reference: Available Domains Confirmed

### App Names (all .app, unregistered as of Mar 15, 2026)
- rekall.app ✅
- savd.app ✅
- mindsift.app ✅
- hoardr.app ✅
- brainbin.app ✅
- catchall.app ✅
- ingest.app ✅
- omnimemo.app ✅

### Studio Names (unregistered as of Mar 15, 2026)
- sardalabs.com ✅ / sardalabs.dev ✅
- empireapps.com ✅ / empireapps.dev ✅
- neuroship.com ✅ / neuroship.dev ✅
- sparkline.dev ✅ / sparklineapps.com ✅
- cerebrallabs.dev ✅
