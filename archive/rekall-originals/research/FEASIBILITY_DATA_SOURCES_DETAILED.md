MEMO — DATA SOURCE INTEGRATION FEASIBILITY REPORT
===================================================
Date: 2026-03-14
Status: Research complete

Legend:
  GREEN  = Straightforward, well-documented, no major blockers
  YELLOW = Feasible but with caveats (cost, complexity, limitations)
  RED    = Significant blockers, unreliable, or not recommended for MVP


===============================================================================
1. TELEGRAM BOT API — GREEN
===============================================================================

API Availability:
  - Fully open, free, no approval process
  - Create bot via BotFather, get token, done in 5 minutes

Auth Method:
  - Bot token (single static token per bot)
  - No OAuth needed — user just messages the bot

What Data Can Be Pulled:
  - Text messages (including forwarded messages with origin info)
  - Voice messages (audio files up to 20MB download)
  - Photos, videos, documents, files
  - Locations, contacts, polls
  - Forwarded message metadata (original sender, date)
  - Stickers, animations, video notes

Rate Limits:
  - Private chats: ~1 msg/sec outbound (no inbound limit)
  - Groups: 20 msgs/min outbound
  - Bulk: ~30 msgs/sec (paid broadcast above free tier)
  - File download: 20MB max, upload: 50MB max

Cost: FREE (no API fees whatsoever)

Technical Complexity: LOW
  - Webhook setup (HTTPS required, ports 443/80/88/8443)
  - Long polling alternative for dev/testing
  - Updates expire after 24 hours if not consumed

Implementation Pattern for Memo:
  1. User starts conversation with @MemoSaveBot
  2. User forwards any message to the bot
  3. Webhook hits backend → parse message type → save note
  4. Voice messages → download → send to AssemblyAI → save transcript
  5. Images → Apple Vision OCR on device OR backend OCR

Key Limitation:
  - Bot CANNOT access user's existing saved messages folder
  - Bot only receives NEW messages sent/forwarded to it going forward
  - User must actively forward content to the bot (this is actually fine for
    the "save it" workflow — forward = intentional save action)

Gaps: None significant. This is the ideal Phase 1 integration.


===============================================================================
2. NOTION API — GREEN
===============================================================================

API Availability:
  - Official REST API, well-documented, stable
  - Official Node.js SDK: @notionhq/client

Auth Method:
  - Public integrations: OAuth 2.0 with PKCE
  - User selects specific pages/databases to share (granular)
  - Access token + refresh token issued
  - Internal integrations: static token (not for Memo's use case)

What Data Can Be Pulled:
  - Pages (full rich text content via block children)
  - Databases (query, filter, sort)
  - 30+ block types: paragraphs, headings, lists, to-dos, quotes,
    callouts, code, images, audio, video, files, PDFs
  - Bookmarks (URL + caption accessible)
  - Link previews, embeds
  - Comments on pages
  - User info

What Data Can Be Written (bidirectional sync):
  - Create pages with properties
  - Create/update database entries
  - Append block children to existing pages

Rate Limits:
  - 3 requests/second per integration (confirmed in project docs)
  - 429 responses with retry-after header
  - Manage with Redis queue + exponential backoff

Cost: FREE (no API fees, Notion charges users for their plan, not developers)

Technical Complexity: MEDIUM
  - OAuth flow requires backend redirect handling
  - Block children are paginated, require recursive fetching for nested content
  - Rich text parsing needed (bold, italic, links, mentions, equations)
  - Page picker UX — user must share specific pages with integration

Implementation Pattern for Memo:
  1. User connects Notion via OAuth in Memo settings
  2. User picks which databases/pages to sync
  3. Backend polls periodically OR user triggers manual sync
  4. Recursively fetch block children → flatten to note content
  5. Preserve metadata: page title, URL, last edited, tags/properties
  6. Bidirectional: push Memo notes back to Notion database

Gaps:
  - Some block types return as "unsupported" (forms, buttons)
  - No real-time webhook from Notion (must poll for changes)
  - Recursive block fetching can be slow for large pages (many API calls)
  - User must manually share pages with integration (Notion limitation)

Verdict: Solid Phase 1 integration. The 3 req/sec limit is manageable
with BullMQ job queue (already scaffolded in backend).


===============================================================================
3. INSTAGRAM — RED
===============================================================================

API Availability:
  - Instagram Basic Display API: DEPRECATED as of December 4, 2024
  - Instagram Graph API: Business/Creator accounts ONLY
  - NO API exists for consumer (personal) accounts anymore
  - NO endpoint for saved posts on ANY API tier (never existed)

Auth Method:
  - Graph API: Facebook Login OAuth (business accounts only)
  - Consumer accounts: no programmatic access at all

What Data Can Be Pulled (Business API only):
  - Own published posts (photos, videos, stories)
  - Basic profile info
  - Comments, mentions, hashtag discovery
  - NOT saved posts — this endpoint has NEVER existed

Rate Limits: N/A for saved posts (endpoint doesn't exist)

Cost: N/A

Technical Complexity: EXTREMELY HIGH (impossible via official means)

Alternatives Considered:
  1. Browser Extension (scraping)
     - User installs Chrome/Safari extension
     - Extension navigates to saved posts, scrapes content
     - Sends to Memo backend via API key
     - RISK: Violates Instagram ToS, fragile (UI changes break it),
       won't work on mobile (where most saving happens)
     - STATUS: YELLOW but legally risky

  2. IFTTT/Zapier
     - Can trigger on "new saved post" in some configs
     - Unreliable, adds dependency, limited data
     - STATUS: YELLOW

  3. Instagram Data Download
     - Users can request data export from Instagram
     - Includes saved posts in JSON
     - Manual process, not real-time
     - Could build "import your data download" feature
     - STATUS: YELLOW — decent onboarding feature, not ongoing sync

  4. Share Sheet (iOS)
     - User shares Instagram post to Memo via iOS share sheet
     - Gets URL + can scrape public post metadata
     - STATUS: GREEN — works great as manual save action

RECOMMENDATION:
  Phase 1: iOS Share Sheet integration (user shares from Instagram to Memo)
  Phase 2: "Import your data download" (one-time bulk import)
  Phase 3: Browser extension (if demand warrants the risk/maintenance)
  NEVER: Scraping Instagram directly from backend (will get IP banned)


===============================================================================
4. REDDIT — YELLOW
===============================================================================

API Availability:
  - Official API exists, saved posts endpoint works
  - Major pricing changes in June 2023 killed most third-party clients

Auth Method:
  - OAuth 2.0 (authorization code flow)
  - Register app at reddit.com/prefs/apps
  - Scopes needed: "history" + "save" + "read"
  - Access tokens expire after 1 hour, refresh tokens available

What Data Can Be Pulled:
  - Saved posts and comments: GET /user/{username}/saved
  - Post content (title, selftext, URL, subreddit, score, comments)
  - Comment content (body, parent, subreddit)
  - User identity

Rate Limits:
  - 100 requests/minute (with OAuth, using User-Agent header)
  - 10 requests/minute without OAuth
  - Must include descriptive User-Agent or get throttled

Cost:
  - Non-commercial use: FREE (confirmed — Reddit exempts non-commercial
    apps from paid API tiers)
  - Commercial use: $0.24 per 1000 API calls
  - Memo is commercial (freemium) → likely needs paid tier
  - HOWEVER: Memo's usage would be very low per user (sync saved posts
    periodically, maybe 5-10 API calls per sync). Monthly cost per active
    user would be negligible (<$0.01/user/month)

Technical Complexity: LOW-MEDIUM
  - Standard OAuth2 flow
  - Paginated responses (25 items default, "after" cursor)
  - JSON responses, well-structured
  - Need to handle mixed content (posts vs comments, different fields)

Implementation Pattern for Memo:
  1. User connects Reddit via OAuth in Memo settings
  2. Backend periodically polls /user/{username}/saved (every 15-30 min)
  3. Parse posts vs comments differently
  4. Store: title, body/selftext, subreddit, URL, score, saved timestamp
  5. Incremental sync: track last seen item, only fetch new saves

Gaps/Risks:
  - Reddit could change API terms again (they did it once, they'll do it again)
  - Commercial classification may require paid API access
  - No webhook/real-time — must poll
  - Reddit app registration requires manual approval for production

Verdict: Feasible for Phase 2-3. API works, saved endpoint exists,
cost is manageable. Main risk is Reddit's unpredictable API governance.


===============================================================================
5. TWITTER/X — YELLOW
===============================================================================

API Availability:
  - API v2 exists with Bookmarks endpoint
  - Major pricing overhaul: moved to pay-per-usage credits (no more tiers)
  - Bookmarks endpoint confirmed: GET /2/users/:id/bookmarks

Auth Method:
  - OAuth 2.0 PKCE (required for bookmarks — user context only)
  - Must have approved developer account
  - Developer Portal app registration required

What Data Can Be Pulled:
  - Bookmarked tweets (text, author, media, URLs, metrics)
  - Bookmark folders
  - Tweet metadata (created_at, public_metrics, entities)
  - Author information

Rate Limits:
  - Bookmarks lookup: 180 requests/15 min per user
  - Bookmark folders: 50 requests/15 min per user/app
  - Manage bookmarks (add/remove): 50 requests/15 min per user
  - Monthly cap: 2 million Post reads (pay-per-usage)

Cost:
  - Pay-per-usage credit system (no monthly subscription)
  - Credits purchased upfront, deducted per API call
  - Exact per-call cost: varies by endpoint, visible in Developer Console
  - Auto-recharge available with spending limits
  - Resources deduplicated within 24-hour UTC windows
  - xAI credits earned back at scale (20% back above $1000 cumulative)
  - UNKNOWN: exact cost per bookmark read — need to test in Developer Console

Technical Complexity: MEDIUM
  - OAuth 2.0 PKCE flow
  - Pay-per-usage billing adds operational complexity
  - Need to monitor spending, set caps
  - Developer account approval may take days

Gaps/Risks:
  - X API governance is unpredictable (changed pricing 3x since 2023)
  - Pay-per-usage makes cost forecasting hard for a startup
  - Could get expensive at scale if bookmark reads are priced high
  - Developer account approval process is opaque
  - No free tier — must pre-purchase credits
  - Elon factor: API could change/disappear with little notice

RECOMMENDATION:
  Phase 2-3 feature. Test the pay-per-usage pricing in Developer Console
  before committing. Keep the integration modular so it can be disabled
  if costs spike. Consider the iOS Share Sheet as a free alternative
  (user shares tweet to Memo manually).


===============================================================================
6. VOICE MEMOS (AssemblyAI) — GREEN
===============================================================================

API Availability:
  - Fully available, well-documented REST API
  - Official SDKs: Node.js (assemblyai package), Python

Auth Method:
  - API key in header (simple bearer token)
  - No OAuth needed

What Can Be Done:
  - Pre-recorded audio transcription (batch)
  - Real-time streaming transcription
  - Speaker diarization (identify who's speaking)
  - Language detection (multilingual support)
  - Sentiment analysis on transcribed text
  - Entity detection (names, places, etc.)
  - PII redaction
  - Content moderation
  - Auto-chapters and summarization
  - Subtitle generation (SRT/VTT)
  - Webhook notifications when transcription completes

Pricing (UPDATED from research — project docs slightly outdated):
  - Universal-2: $0.15/hour ($0.0025/min, $0.0000417/sec)
  - Universal-3 Pro: $0.21/hour
  - Universal Streaming: $0.15/hour
  - Speaker diarization: +$0.02/hour (pre-recorded)
  - Free tier: 185 hours of pre-recorded audio FREE
  - No monthly subscription, pure pay-as-you-go
  - No minimum commitment

  Note: Project CLAUDE.md says $0.00025/sec = $0.015/min. Current pricing
  is $0.15/hr = $0.0025/min for Universal-2. That's ~6x cheaper than the
  CLAUDE.md figure. Either pricing dropped or the original figure was for
  a different model. Either way, it's very cheap.

Rate Limits:
  - Free: 5 concurrent streams/minute
  - Paid: 100 concurrent streams/minute (auto-scales)
  - Unlimited concurrent pre-recorded transcriptions

Technical Complexity: LOW
  - Upload audio URL or file → get transcript back
  - Webhook for async notification
  - Node.js SDK handles everything

Implementation Pattern for Memo:
  1. User taps mic button in Memo iOS app
  2. Record audio using AVAudioEngine (iOS native)
  3. Upload audio file to S3 (already in stack)
  4. Send S3 URL to AssemblyAI via backend
  5. Receive transcript via webhook or polling
  6. Save transcript as note with audio attachment link
  7. AI categorizes transcript like any other note

Gaps: None. This is the simplest integration in the stack.


===============================================================================
7. APPLE VISION (On-Device OCR) — GREEN
===============================================================================

API Availability:
  - Built into iOS, no external API needed
  - VNRecognizeTextRequest (Vision framework)
  - Available since iOS 13, improved significantly in iOS 15+

Auth Method: None needed (on-device, local processing)

What Can Be Done:
  - Text recognition from images/screenshots
  - Two recognition levels:
    * .fast — lower accuracy, real-time capable
    * .accurate — higher accuracy, slower
  - Handwriting recognition
  - Document text recognition
  - Barcode/QR code reading (VNDetectBarcodesRequest)
  - Text in natural scenes (signs, menus, etc.)

Supported Languages:
  - English, Chinese, French, German, Italian, Portuguese, Spanish
  - Additional languages added with each iOS version
  - Automatic language detection

Cost: FREE (100% on-device, no API calls, no data leaves device)

Technical Complexity: LOW
  - Native Swift framework, well-documented
  - ~20 lines of code for basic OCR
  - Runs on Neural Engine (fast on modern iPhones)

Implementation Pattern for Memo:
  1. User takes screenshot or picks image from camera roll
  2. Or: user shares screenshot to Memo via Share Sheet
  3. VNRecognizeTextRequest processes image on-device
  4. Extracted text becomes note content
  5. Original image stored as attachment (S3)
  6. AI categorizes extracted text

Privacy Advantage:
  - All processing on-device
  - No images sent to cloud for OCR
  - Strong selling point for privacy-conscious ADHD users

Fallback:
  - Google Cloud Vision as backend fallback (if Apple Vision fails)
  - Already noted in TECH_STACK.md as contingency

Gaps:
  - Accuracy varies with image quality (blurry screenshots = poor results)
  - Handwriting recognition less reliable than printed text
  - Complex layouts (multi-column, overlapping text) can confuse it
  - No table structure recognition (just raw text extraction)


===============================================================================
PHASE 3 REALITY CHECK: Instagram, Reddit, Twitter
===============================================================================

The honest assessment post-2023:

Instagram: RED — No API for saved posts. Never had one, never will.
  The only viable paths are Share Sheet (manual) and data download (bulk).
  Browser extension works but is fragile and legally gray.

Reddit: YELLOW — API works, endpoint exists, but Reddit has shown
  willingness to change terms aggressively. Commercial apps may need
  paid API access. Cost is manageable but adds operational overhead.

Twitter/X: YELLOW — Bookmarks endpoint exists, but pay-per-usage pricing
  makes cost unpredictable. API governance under current ownership is
  volatile. Developer account approval is a gatekeeping risk.

Realistic Phase 3 alternatives:
  - For all three: iOS Share Sheet is the universal fallback (FREE, reliable,
    user-initiated, no API dependencies, no ToS risk)
  - Share Sheet actually aligns better with Memo's "intentional save" UX:
    user consciously decides "I want to keep this" and shares to Memo


===============================================================================
OTHER SOURCES USERS WILL WANT — FEASIBILITY SCAN
===============================================================================

WhatsApp — RED
  - WhatsApp Cloud API is BUSINESS ONLY (not consumer)
  - No API for personal message access whatsoever
  - Only option: user exports chat → import into Memo (manual)
  - Or: iOS Share Sheet from WhatsApp to Memo (works for individual messages)
  - RECOMMENDATION: Share Sheet integration (Phase 2)

YouTube Watch Later — RED
  - YouTube Data API v3 explicitly BLOCKS Watch Later playlist access
  - Returns 403 "watchLaterNotAccessible" error
  - Intentional privacy restriction by Google
  - Only option: Share Sheet (share video URL to Memo)
  - RECOMMENDATION: Share Sheet only

Kindle Highlights — YELLOW
  - Amazon has no public API for Kindle highlights
  - Readwise.io aggregates Kindle highlights (has API for paying users)
  - Could integrate with Readwise API as intermediary
  - Alternative: parse Kindle "My Clippings.txt" file (manual export)
  - Alternative: scrape read.amazon.com (fragile, ToS risk)
  - RECOMMENDATION: Readwise API integration (Phase 3), file import (Phase 2)

Apple Notes — YELLOW
  - No public API from Apple
  - Can access via AppleScript on macOS (not helpful for iOS-first app)
  - iOS Shortcuts can extract notes but limited programmatic access
  - CloudKit private database could theoretically be read but Apple
    doesn't expose Notes data to third-party apps
  - RECOMMENDATION: Share Sheet from Apple Notes (works, simple)

Email Forwards (Gmail) — YELLOW
  - Gmail API is fully featured and well-documented
  - OAuth 2.0 with granular scopes
  - Can read emails with specific labels/filters
  - Pattern: user creates a filter or forwards to memo-specific email
  - Rate limits: 250 quota units/sec (generous)
  - Cost: FREE
  - RECOMMENDATION: Good Phase 2-3 feature. User sets up a "Forward to Memo"
    email address or Gmail filter that labels/forwards specific emails.

Pocket — GREEN
  - API exists, free, well-documented
  - OAuth authentication (Pocket's own, not standard OAuth2)
  - Can retrieve all saved articles with full metadata
  - Tags, URL, title, excerpt, images, timestamps
  - Rate limits: reasonable (not well-documented but not restrictive)
  - RECOMMENDATION: Easy Phase 3 integration

Raindrop.io — GREEN
  - Full REST API, free to use
  - OAuth 2.0 authentication
  - Can retrieve all bookmarks, collections, tags
  - Rate limit: 120 requests/min per user
  - Well-documented, stable
  - RECOMMENDATION: Easy Phase 3 integration

Browser Bookmarks — YELLOW
  - No direct API (bookmarks are local to browser)
  - Chrome: can sync via Google Account API (complex)
  - Safari: no API, iCloud Bookmarks not accessible
  - Firefox: Sync API exists but complex
  - Best approach: browser extension that exports bookmarks
  - RECOMMENDATION: Browser extension (Phase 3), or manual import/export

Slack Saved Messages — YELLOW
  - Slack API (Web API) is well-documented
  - stars.list endpoint returns saved/starred items
  - OAuth 2.0 with granular scopes
  - Free for development, rate limits are generous
  - CATCH: requires Slack workspace admin approval for app install
  - RECOMMENDATION: Phase 3-4 feature

Discord Saved/Pinned — YELLOW
  - Bot API can access pinned messages in channels
  - But "saved messages" is not a Discord concept (no saved endpoint)
  - Can only capture messages in channels where bot is present
  - RECOMMENDATION: Low priority, niche audience overlap


===============================================================================
PRIORITY MATRIX — WHAT TO BUILD WHEN
===============================================================================

PHASE 1 (MVP — Months 1-2):
  [GREEN] Telegram Bot          — Primary capture channel
  [GREEN] Notion API             — Read + write, bidirectional
  [GREEN] Voice Memos            — AssemblyAI transcription
  [GREEN] Apple Vision OCR       — Screenshot text extraction
  [GREEN] iOS Share Sheet        — Universal fallback for ALL sources

PHASE 2 (Month 3):
  [YELLOW] Reddit API            — Saved posts sync
  [YELLOW] Email forwards        — Gmail API or forwarding address
  [GREEN]  Pocket API            — Saved articles (if demand exists)

PHASE 3 (Month 4-5):
  [YELLOW] Twitter/X Bookmarks   — Test pay-per-usage costs first
  [RED→YLW] Instagram            — Share Sheet + data download import
  [GREEN]  Raindrop.io           — Bookmark sync
  [YELLOW] Kindle/Readwise       — Via Readwise API

PHASE 4+ (Post-MVP):
  [YELLOW] Slack saved items
  [YELLOW] Browser extension     — Chrome/Safari for bookmarks + Instagram
  [RED]    WhatsApp              — Share Sheet only
  [RED]    YouTube Watch Later   — Share Sheet only
  [YELLOW] Apple Notes           — Share Sheet only


===============================================================================
KEY INSIGHT: THE SHARE SHEET IS YOUR SECRET WEAPON
===============================================================================

iOS Share Sheet works with EVERY app, requires:
  - Zero API integrations
  - Zero ongoing maintenance
  - Zero API costs
  - Zero ToS/legal risk
  - Works on day 1

For every RED source (Instagram, WhatsApp, YouTube), Share Sheet is the
realistic answer. Build a great Share Sheet extension in Phase 1 and you
automatically support 100+ apps without writing a single integration.

The Share Sheet should:
  1. Accept URLs → extract metadata (title, description, image)
  2. Accept text → save as note
  3. Accept images → OCR with Apple Vision
  4. Accept audio → transcribe with AssemblyAI
  5. Show quick category picker (Wheel of Life dimension)
  6. One-tap save (< 2 seconds from share to saved)

This is arguably MORE aligned with ADHD-first design than automatic
background sync: the user makes an INTENTIONAL choice to save something,
which means higher signal-to-noise ratio in their Memo library.


===============================================================================
COST PROJECTION (per 1000 monthly active users)
===============================================================================

Telegram Bot API:     $0/month
Notion API:           $0/month
AssemblyAI:           ~$15/month (assuming 100 hrs total voice memos)
Apple Vision OCR:     $0/month (on-device)
Reddit API:           ~$2.40/month (10K API calls)
Twitter/X API:        $???/month (pay-per-usage, need to test)
Gmail API:            $0/month
Pocket API:           $0/month
Raindrop.io API:      $0/month

Total estimated: ~$17.40/month per 1K MAU (excluding Twitter/X)
At $10/month Pro subscription, break-even is well under 10 paying users
per 1000 MAU, which is very achievable with typical 5-10% conversion.
