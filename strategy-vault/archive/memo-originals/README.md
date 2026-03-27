# NoteNest
**"Your brain's external hard drive. One search bar for everything you've ever saved."**

---

## What Is NoteNest?

NoteNest is a **universal note aggregator** for ADHD brains. It connects to ALL your apps (Telegram, Instagram, Notion, LinkedIn, voice memos, etc.) and gives you **one search bar** to find anything you've ever saved.

**Problem:** You save brilliant ideas across 10+ apps. When you need them later? Can't find them.

**Solution:** NoteNest. One place. One search. Everything.

---

## Core Features

### Phase 1 (MVP - Months 1-2)
- ✅ **Telegram integration** (saved messages, voice memos, images)
- ✅ **Notion integration** (read + write with custom templates)
- ✅ **Voice capture** (record → auto-transcribe → searchable)
- ✅ **Universal search** (semantic AI search across all sources)
- ✅ **Quick capture** (iOS share sheet - save from any app)

### Phase 2 (Month 3)
- ✅ **Instagram saved posts**
- ✅ **LinkedIn saved posts**
- ✅ **Twitter/X bookmarks**
- ✅ **Facebook saved posts**
- ✅ **AI summarization** (long content → key points)

### Phase 3 (Months 4-5)
- ✅ **WhatsApp starred messages**
- ✅ **Discord saved messages**
- ✅ **Reddit saved posts**
- ✅ **Obsidian integration**
- ✅ **Email integration** (Gmail/Outlook starred)
- ✅ **Screenshot OCR** (auto-import from photo library)

---

## Why NoteNest?

### 1. **ADHD-First Design**
- No nested folders (overwhelming!)
- Search-first (find anything in 0.3 seconds)
- Haptic feedback (tactile confirmation)
- Dark mode default (less eye strain)

### 2. **Multimodal**
- Text, audio, video, images, PDFs
- Everything searchable

### 3. **Social Media Saved Posts**
- Instagram, LinkedIn, Twitter, Facebook
- No one else does this comprehensively

### 4. **Bidirectional Sync**
- Notion + Obsidian (with custom templates)
- Capture in NoteNest → organize in your favorite tool

### 5. **Mobile-First**
- iOS native (not web wrapper)
- Works offline
- Fast, smooth UX

---

## Target Users

- **ADHD creatives** with ideas everywhere
- **Students** drowning in saved articles/notes
- **Knowledge workers** with "second brain" aspirations
- **Notion/Obsidian power users** frustrated with capture workflow

---

## Competitive Advantage

| Feature | NoteNest | Readwise | Matter | Raindrop | Fabric |
|---------|----------|----------|--------|----------|--------|
| Social media saved posts | ✅ | ❌ | ❌ | ❌ | ? |
| Multimodal (voice/video) | ✅ | ❌ | ❌ | ❌ | ? |
| ADHD-focused | ✅ | ❌ | ❌ | ❌ | ❌ |
| Mobile-first | ✅ | ❌ | ✅ | ❌ | ❌ |
| Notion + Obsidian sync | ✅ | ✅ | ❌ | ❌ | ? |
| Price | $10/mo | $13/mo | $8/mo | $2/mo | ? |

---

## Business Model

### Pricing
- **Free Tier:** 3 connected sources, 100 notes/month, basic search
- **Pro Tier:** $10/mo or $96/year - Unlimited sources, AI features, full history
- **Team Tier:** $25/mo per user (coming later)

### Revenue Goal
- **Year 1:** $20K ARR (165 Pro users)
- **Year 2:** $144K ARR (1,200 Pro users)
- **Year 3:** $1M+ ARR (8,333 Pro users)

---

## Tech Stack

### Frontend
- **iOS:** Swift + SwiftUI (native performance)
- **Minimum iOS:** 16.0
- **Frameworks:** Speech (voice), Vision (OCR), ShareExtension (quick capture)

### Backend
- **Server:** Node.js + Express (or Python + FastAPI)
- **Database:** PostgreSQL (structured data)
- **Vector DB:** Pinecone (semantic search)
- **Cache/Queue:** Redis (sessions, rate limiting, background jobs)
- **Storage:** AWS S3 (media files)

### AI/ML
- **Embeddings:** OpenAI `text-embedding-3-small` ($0.02/1M tokens)
- **Summarization:** GPT-4o-mini ($0.15/1M input tokens)
- **Transcription:** Whisper API ($0.006/minute)
- **OCR:** Apple Vision (on-device) + Google Cloud Vision (fallback)

### Integrations
- Telegram Bot API, Notion API, Twitter API, Reddit API, Instagram (scraping/extension), LinkedIn (scraping/extension)

---

## Roadmap

### Pre-Launch (Months 1-5)
- [ ] Design mockups (Figma)
- [ ] Build MVP (3 sources + search)
- [ ] Beta testing (50-100 users)
- [ ] Landing page + waitlist
- [ ] Social media presence

### Launch (Month 6)
- [ ] Product Hunt launch
- [ ] Press outreach (TechCrunch, ADHD media)
- [ ] Influencer partnerships (ADHD creators)
- [ ] App Store submission
- [ ] Goal: 1,000 signups in first month

### Post-Launch (Months 7-12)
- [ ] Add Instagram, LinkedIn, Twitter integrations
- [ ] AI summarization
- [ ] Obsidian sync
- [ ] Referral program
- [ ] Goal: 500 signups/month sustained

### Year 2+
- [ ] Android app
- [ ] Team/enterprise features
- [ ] International expansion
- [ ] Hardware component (smart pen - NoteForge vision)

---

## Marketing Strategy

### Target Channels
1. **ADHD Communities**
   - r/ADHD (8M members), ADHD TikTok/Instagram, ADDitude Magazine
2. **Productivity Communities**
   - r/productivity, r/notion, r/ObsidianMD
3. **Influencer Partnerships**
   - ADHD creators (50-500K followers), offer free Pro + 30% affiliate commission
4. **Content Marketing**
   - Blog posts, YouTube demos, guest posts on ADHD/productivity sites
5. **Paid Ads**
   - Instagram/Facebook (target ADHD), Reddit ads, Google ads

### Messaging Hooks
1. **"The single best thing you can do for your brain"** (brain health)
2. **"Struggle with ADHD and lots of creative ideas?"** (identity)
3. **"'I thought about that before but don't know where it went'"** (pain point)
4. **"Type anything anywhere, access in one place"** (solution)

---

## Budget

### Year 1 (Bootstrap Mode)
- **If outsource dev:** $32K (iOS + backend devs) + $13K (infra/marketing/legal) = **$45K total**
- **If CS builds solo:** $0 (dev) + $13K (infra/marketing/legal) = **$13K total**

### Infrastructure (ongoing)
- Hosting: $15/mo (Railway)
- Pinecone: $70/mo (vector DB)
- OpenAI API: $200/mo (AI features)
- AWS S3: $20/mo (media storage)
- Tools/services: $36/mo (domain, email, monitoring)
- **Total: ~$341/mo = $4,092/year**

### Break-even: ~100 Pro users at $10/mo = $1,000 MRR

---

## Documentation

All detailed docs are in `/docs`:

1. **[PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md)** - Full product specification (31K words)
2. **[COMPETITIVE_ANALYSIS.md](docs/COMPETITIVE_ANALYSIS.md)** - Deep dive on competitors
3. **[TECH_STACK.md](docs/TECH_STACK.md)** - Technical architecture & implementation details
4. **MARKETING_PLAN.md** (coming next) - Go-to-market strategy

---

## Why This Will Work

### 1. Founder-Market Fit
- CS has ADHD → deeply understands the pain
- CS is the target customer → can validate daily
- Mechanical engineer background → systems thinking
- Data analyst → understands metrics

### 2. Market Timing
- ADHD awareness exploding (TikTok, destigmatization)
- "Second brain" concept mainstream
- AI tools expected in 2026
- Readwise/Matter prove market exists, but gaps remain

### 3. Clear Differentiation
- ONLY app that does: multimodal + social media + note apps + ADHD-first
- Competitors are single-use (read-later OR bookmarks OR one platform)

### 4. Product Moat
- API integrations take time (each = 2-4 weeks work)
- Data moat: once user has 1,000 notes in NoteNest, switching cost is HIGH
- Community moat: ADHD users loyal to "one of us" brands

### 5. Realistic Path to $1M ARR
- $10/mo × 8,333 Pro users = $1.2M ARR
- With 20% conversion: need ~42K free users
- Achievable in 18-24 months with ADHD community focus

---

## Next Steps

### Week 1
- [ ] Review product spec, make final edits
- [ ] Decide: build solo OR hire devs?
- [ ] Register domain (notenest.app or similar)
- [ ] Set up Twitter/Instagram accounts

### Week 2
- [ ] Design mockups (Figma)
- [ ] Create GitHub repo
- [ ] Set up project management (Linear/Notion)
- [ ] Research API docs (Telegram, Notion, etc.)

### Week 3
- [ ] Start development (backend or iOS first)
- [ ] Launch landing page (Webflow/Carrd)
- [ ] Write first blog post: "Why I'm building NoteNest"
- [ ] Announce on Twitter/LinkedIn (building in public)

---

## Contact

**Founder:** CS  
**Email:** [TBD]  
**Twitter:** [@notenestapp](https://twitter.com/notenestapp) (placeholder)  
**Website:** [notenest.app](https://notenest.app) (coming soon)

---

## License

Proprietary (not open source for now - protect competitive advantage)

---

**Let's build this. 🚀**
