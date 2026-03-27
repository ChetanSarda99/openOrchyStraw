# AI Services & iOS Feature Feasibility Report
**Date:** March 14, 2026

---

## PART 1: AI Cost Analysis

### Claude 3.5 Sonnet Pricing

| Metric | Cost |
|---|---|
| Input tokens | $3.00 / 1M tokens |
| Output tokens | $15.00 / 1M tokens |
| Batch API (24hr) | $1.50 input / $7.50 output per 1M |
| Prompt caching hits | 90% discount |

**Cost per 1,000 notes** (750 tokens in + 200 tokens out each):
- Standard: **$5.25**
- Batch API: **$2.63**
- With caching: **~$3.50-4.00**

### Voyage AI voyage-3 Pricing

| Metric | Cost |
|---|---|
| Price | $0.06 / 1M tokens |
| Free tier | First 200M tokens free |
| voyage-3-lite | $0.02 / 1M tokens |

**Cost per 1,000 embeddings:** $0.045 (essentially free at MVP scale).
200M free tier covers ~267K notes.

### pgvector Storage

Each 1024-dim float32 vector = ~4.1 KB. With HNSW index + metadata: ~6-8 KB/row.

| Scale | With HNSW index |
|---|---|
| 10K vectors | ~120-150 MB |
| 100K vectors | ~1.2-1.5 GB |
| 1M vectors | ~12-15 GB |

At 1M vectors, consider halfvec (float16) to halve storage, or migrate to Pinecone.

### AssemblyAI Pricing

| Feature | Cost |
|---|---|
| Base transcription | $0.15/hour ($0.0025/min) |
| + Speaker diarization | +$0.02/hour |
| + Summarization | +$0.03/hour |
| Free credits | $50 (~185 hours) |

Per voice memo (avg 2 min): **$0.005**

### Monthly Cost at 200 Users (5,000 notes each)

**Assumptions:** 50K new notes/month, 10% voice memos, 20K search queries/month.

| Service | Monthly Cost |
|---|---|
| Claude API (50K notes) | $262.50 |
| Voyage AI (50K embeddings) | $2.25 |
| AssemblyAI (5K memos x 2min) | $25.00 |
| Railway: Node.js API | ~$15-20 |
| Railway: PostgreSQL (20 GB) | ~$25-35 |
| Railway: Redis | ~$7-10 |
| AWS S3 | ~$5-10 |
| **Total** | **~$350-370/month** |

**Optimized** (batch API + caching): **~$200-250/month**

Break-even: **25-50 paying users** at $9.99/month.

---

## PART 2: iOS Feature Feasibility

### RevenueCat — LOW complexity
- Mature Swift SDK, SwiftUI PaywallView() component
- Remote paywall config without app updates
- Free up to $2,500/month revenue, then 1%

### SwiftUI Charts (Wheel of Life) — MEDIUM complexity
- Apple Charts does NOT include radar/spider charts natively
- Options: custom Path (~200-300 lines), ChartsOrg/Charts library, or creative donut/ring alternative
- Recommendation: custom SwiftUI Path view

### macOS Multiplatform — MEDIUM-HIGH complexity
- Realistic code reuse: 60-75%
- Models, ViewModels, services transfer well
- Navigation, keyboard shortcuts, menu bar need Mac-specific work
- Recommendation: defer, design iOS-first with clean separation

### iOS Share Extension — MEDIUM complexity (HIGH value)
- SwiftUI views via UIHostingController
- Receives URLs, text, images from any app's share sheet
- Needs App Groups for shared SwiftData access
- 120 MB memory limit — queue heavy work for main app
- Recommendation: implement early, primary "save from anywhere" mechanism

### App Intents / Siri — LOW-MEDIUM complexity
- "Hey Siri, save this to Memo" fully achievable
- Also enables Spotlight, Shortcuts app, Action Button
- Start with "Save note" and "Search Memo" intents

### Core ML On-Device — HIGH complexity
- Apple Foundation Models (iOS 26) gives ~3B on-device LLM
- Requires iPhone 15 Pro+ (excludes ~40-50% users in 2026)
- Recommendation: not viable as primary. Consider as offline fallback.

### Interactive Widgets — LOW-MEDIUM complexity
- iOS 17+ buttons/toggles in widgets
- iOS 18+ Control Center widgets
- Best for: Quick Capture button, Recent Notes, Search shortcut
- No text fields in widgets — can only open app to specific mode

### Feature Priority Matrix

| Feature | Complexity | User Value | When |
|---|---|---|---|
| Share Extension | Medium | Very High | M2-M3 |
| RevenueCat | Low | High | M3-M4 |
| App Intents/Siri | Low-Medium | Medium-High | M4-M5 |
| Interactive Widgets | Low-Medium | Medium | M4-M5 |
| Custom Chart | Medium | Medium | M3 |
| Core ML on-device | High | Low (MVP) | Post-launch |
| macOS multiplatform | Medium-High | Low (MVP) | Post-launch |
