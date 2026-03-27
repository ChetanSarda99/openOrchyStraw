# Data Source Integration Feasibility Report
**Date:** March 14, 2026

## Summary Table

| Source | Rating | Cost | MVP Priority |
|---|---|---|---|
| **Telegram Bot** | GREEN | Free | P0 - Launch |
| **Notion API** | GREEN | Free | P0 - Launch |
| **AssemblyAI (Voice)** | GREEN | $0.15/hr, 185hr free | P0 - Launch |
| **Pocket** | GREEN | Free | P1 - Soon after |
| **Raindrop.io** | GREEN | Free | P1 - Soon after |
| **Email Forwards** | GREEN | Free tier available | P1 - Soon after |
| **Reddit** | YELLOW | Free (non-commercial) | P2 - Post-MVP |
| **Twitter/X** | YELLOW/RED | $200+/month minimum | P3 - If pricing improves |
| **Kindle Highlights** | YELLOW | Free (unofficial) | P3 - Best effort |
| **WhatsApp** | YELLOW | Complex setup | P3 - Defer |
| **Browser Bookmarks** | YELLOW | Free (extension needed) | P3 - Defer |
| **Instagram Saved** | RED | N/A | Drop |
| **YouTube Watch Later** | RED | N/A | Drop |
| **Apple Notes** | RED | N/A | Drop |

---

## 1. Telegram Bot API — GREEN

**How it works:** User adds your bot, forwards messages to it. Bot receives full Message object via webhook.

**Data available:** Full text, photos, videos, documents, audio, voice notes, links, captions, original sender info (if privacy allows), forward date, media file IDs.

**Auth:** Bot token from @BotFather. No OAuth needed.
**Rate limits:** 30 messages/second outbound. Inbound effectively unlimited for single-user app.
**Pricing:** Free.
**Implementation:** Webhook at POST /sync/telegram.

---

## 2. Notion API — GREEN

**OAuth flow:** Standard OAuth 2.0. User selects which pages/databases to share.

**What you can read:** Pages, databases, blocks (paragraphs, headings, lists, to-dos, toggles, callouts, quotes, code, images, bookmarks, embeds, tables). Max 1000 blocks/request.

**Rate limits:** 3 requests/second average. 429 with Retry-After header.
**Pricing:** Free.
**Limitations:** Some block types partial support. Two levels nested children max per request.

---

## 3. Instagram Graph API — RED

**Blocked.** No saved posts endpoint exists. Basic Display API shut down Dec 4, 2024. Only Business/Creator accounts can connect. Even Business accounts can't access saved collection. Scraping violates ToS.

**Recommendation:** Drop from all phases.

---

## 4. Reddit API — YELLOW

**Saved posts:** `/user/{username}/saved` endpoint exists. Requires OAuth with `history` and `read` scopes.
**Free tier:** 100 requests/minute with OAuth. Enough for periodic syncing.
**Complications:** Pre-approval required (2025+). Commercial use is expensive (~$12K/year). Terms are vague on what counts as commercial.

**Recommendation:** Include on free tier for MVP. Monitor commercial-use policies.

---

## 5. Twitter/X API — YELLOW/RED

**Bookmarks endpoint exists** in API v2 but requires paid tier.
- Free tier: No bookmarks. 1 post read/15 min.
- Basic tier ($200/month): Likely includes bookmarks.
- Pay-as-you-go (2026): Per-request pricing in beta.

**Recommendation:** Defer. $200/month floor not viable for MVP.

---

## 6. AssemblyAI — GREEN

**Pricing:** $0.15/hour base. Speaker diarization +$0.02/hr. Summarization +$0.03/hr.
**Free tier:** $50 credits (~185 hours).
**Accuracy:** Up to 95% (Universal-3 Pro model).
**Formats:** WAV, MP3, FLAC, M4A, most audio/video formats.
**Flow:** Upload audio → POST /v2/transcript → Poll until completed (or use webhooks).
**Languages:** 99 languages with auto-detection.

---

## 7. Additional Sources

### Pocket — GREEN
REST API with OAuth. `GET /v3/get` returns all saved articles with metadata. Free API access.

### Raindrop.io — GREEN
REST API with OAuth 2.0. Full CRUD on bookmarks/collections/tags. Free access.

### Email Forwards — GREEN
SendGrid Inbound Parse or Mailgun Inbound Routing. User gets unique address (save@memo.app). Parses emails to structured JSON. Free tiers available.

### WhatsApp — YELLOW
Cloud API is business-only. No personal chat history access. Can only receive messages TO your business number. Not suitable for "forward to Memo" flow. Skip.

### YouTube Watch Later — RED
Google deprecated third-party access specifically. Not feasible.

### Kindle Highlights — YELLOW
No official API. Community solutions (scraping read.amazon.com, My Clippings.txt parsing). Fragile. Best effort post-MVP.

### Apple Notes — RED
No read API. SiriKit only creates notes. iOS sandboxing blocks database access.

### Browser Bookmarks — YELLOW
No remote API. Would need browser extension (new platform to maintain). Consider simple import instead.
