MULTI-DIMENSIONAL CATEGORIZATION SYSTEM — Research & Recommendation
====================================================================
For Memo: ADHD-first universal note aggregator
Date: 2026-03-14


1. WHAT DIMENSIONS SHOULD NOTES BE CATEGORIZED BY?
====================================================================

Every note should carry metadata across 5 independent dimensions.
Three are fully automatic, one is AI-assigned, one is user-created.

DIMENSION 1: Source (automatic)
  Where the note came from. Already implemented.
  Values: telegram, notion, voice, instagram, reddit, twitter, pocket, email, etc.
  Used for: filtering, sync status, "show me everything from Telegram"

DIMENSION 2: Format (automatic — rename from "contentType")
  What the content physically is. Determined on capture.
  Current values (text, audio, video, image, link) are too generic.
  Recommended values:
    - article       (long-form web content, blog posts, newsletters)
    - bookmark      (saved URL with title, no full content yet)
    - snippet       (short text: tweet, message, quote, comment)
    - voice-memo    (audio recording with transcript)
    - screenshot    (image captured from screen, OCR'd)
    - photo         (non-screenshot image: Instagram post, camera photo)
    - video         (video content with optional transcript)
    - document      (Notion page, PDF, long-form notes)
    - thread        (Reddit thread, Twitter thread — multi-part)
    - highlight     (Readwise-style clipping from a longer source)

  Why expand: "text" tells you nothing. Knowing it's a "snippet" vs an "article"
  vs a "highlight" changes how you display it, how you summarize it, and what
  the user expects to see in search results.

DIMENSION 3: Life Area (AI-assigned — see Section 2 & 3 below)
  What part of your life this relates to. The primary organizational axis.
  AI assigns with confidence score. User can override.

DIMENSION 4: Tags (AI-suggested + user-created)
  Specific, granular labels. Already implemented.
  Examples: "knee-safe", "meal-prep", "side-project", "python", "date-idea"
  Tags are the user's personal vocabulary. AI suggests, user confirms/adds.

DIMENSION 5: Status (user-set, with smart defaults)
  What's the state of this note in the user's workflow?
  This is what Readwise, Notion, and Tiago Forte's PARA all agree on.
  Values:
    - inbox         (just captured, not reviewed — DEFAULT for everything)
    - active        (user is currently working with this)
    - reference     (keep for later, not actionable now)
    - archived      (done with it, out of sight but searchable)

  Why add this: Without status, the app becomes a dumping ground.
  The #1 complaint about save-everything apps is "I saved 500 things
  and did nothing with them." Status turns a pile into a workflow.
  This maps directly to PARA: inbox=capture, active=projects,
  reference=resources, archived=archive.

  NOT included: "Areas" from PARA — that's what Life Areas already cover.

WHAT OTHER APPS USE (competitive research):

  Readwise Reader:
    - Location (source)
    - Document type (article, book, tweet, PDF, email, podcast)
    - Tags (user-created)
    - Status: New / Shortlist / Archive / Feed
    - No life-area categorization

  Raindrop.io:
    - Collections (user-created folders, nestable)
    - Tags (user-created)
    - Type: link, article, image, video, document, audio
    - No AI categorization, no life areas

  Notion:
    - Databases with arbitrary properties (infinitely flexible)
    - Common pattern: Status, Type, Tags, Area/Project
    - No auto-categorization

  Obsidian:
    - Tags (inline #tags)
    - Folders (user-created)
    - Links (bi-directional graph)
    - Metadata via YAML frontmatter (arbitrary)
    - No auto-categorization

  Capacities:
    - "Object types" (person, book, idea, project, etc.) — like document type
    - Tags
    - Bi-directional links
    - No life-area concept

  Mem:
    - Collections (AI-auto-generated clusters)
    - Tags (called "labels")
    - Smart search (AI-powered)
    - No explicit life-area or status system

  Key insight: None of the competitors do automatic life-area categorization.
  This is Memo's differentiation. But every successful app has some form of
  status/workflow state + document type + tags.


2. WHAT SHOULD LIFE AREA CATEGORIES BE CALLED?
====================================================================

RECOMMENDATION: "Areas"

Why "Areas" wins:
  - Notion users already think in "Areas" (PARA is mainstream)
  - Tiago Forte's PARA framework made "Areas" the standard term for
    "ongoing responsibilities and interests in your life"
  - It's short, clear, unpretentious
  - No wellness/coaching connotation (unlike "Wheel of Life dimensions")
  - Obsidian users use "Areas" in their vault structures
  - Things 3 uses "Areas" for exactly this purpose

Rejected alternatives:
  - "Spaces" — Notion uses this for team workspaces. Confusing.
  - "Pillars" — Too formal, sounds like corporate strategy.
  - "Domains" — Too technical, sounds like web domains.
  - "Topics" — Too generic. Topics are more like tags. "My Health topic"
    sounds wrong vs "my Health area."
  - "Categories" — Already overloaded in the codebase. Too generic.
  - "Zones" — Sounds gamified.
  - "Dimensions" — Academic. Users don't say "my career dimension."
  - "Buckets" — Informal but unclear.

In the UI and codebase:
  - User-facing: "Areas" (e.g., "Browse by Area", "Health area")
  - Code: LifeArea type (replace WheelOfLifeDimension)
  - Database: keep the Category model but drop wheelOfLifeDimension field,
    replace with isLifeArea boolean or a categoryType enum


3. DEFAULT LIFE AREA CATEGORIES
====================================================================

Recommended defaults: 8 areas, practical and ADHD-resonant.

  1. Health & Body
     Slug: health-body
     Icon: heart.fill (SF Symbol)
     Color: #FF6B6B (coral red)
     Covers: exercise, nutrition, sleep, medical, body care, gym routines
     NOT called "Health & Fitness" — "Body" is more inclusive (sleep, medical, etc.)

  2. Mind & Focus
     Slug: mind-focus
     Icon: brain.head.profile
     Color: #9B59B6 (purple)
     Covers: ADHD strategies, therapy, mindfulness, productivity systems,
             focus techniques, journaling, emotional regulation
     NOT "Mental Health" — too clinical. ADHD users want tools, not therapy labels.
     "Focus" directly addresses the #1 ADHD struggle.

  3. Career & Work
     Slug: career-work
     Icon: briefcase.fill
     Color: #3498DB (blue)
     Covers: job stuff, professional growth, resume, skills for work,
             certifications, networking
     Simple. Everyone understands it.

  4. Money & Finance
     Slug: money-finance
     Icon: dollarsign.circle.fill
     Color: #2ECC71 (green)
     Covers: budgeting, investing, savings, crypto, financial goals
     Separated from Career because they're different contexts.
     People save finance content that has nothing to do with their job.

  5. Relationships & Social
     Slug: relationships-social
     Icon: person.2.fill
     Color: #E91E63 (pink)
     Covers: friends, family, dating, social plans, gift ideas,
             conversation topics, community

  6. Learning & Interests
     Slug: learning-interests
     Icon: book.fill
     Color: #FF9800 (orange)
     Covers: courses, books, hobbies, creative projects, personal skills,
             things you're curious about
     Merges the old "Skills & Hobbies" + "Career & Learning" overlap.
     This is the "I want to learn piano" and "interesting article about
     space" bucket. It's big, and that's fine — tags narrow it down.

  7. Projects & Ideas
     Slug: projects-ideas
     Icon: lightbulb.fill
     Color: #FFC107 (amber)
     Covers: side projects, business ideas, app ideas, things to build,
             startup concepts, creative ventures
     Replaces "Empire Building" which is cringe for most users.
     ADHD brains generate TONS of project ideas. This is their home.

  8. Home & Life
     Slug: home-life
     Icon: house.fill
     Color: #795548 (brown)
     Covers: home improvement, meal prep, chores, organization,
             travel plans, shopping, recipes, lifestyle
     The "everything practical about daily life" bucket.

DROPPED from current system:
  - "Spiritual & Purpose" — Too niche for defaults. Most ADHD productivity
    users won't use this. They can add it as a custom area if they want.
    Items that would go here get split between "Mind & Focus" (self-discovery,
    journaling) and "Learning & Interests" (philosophy, values).

WHY 8 and not fewer:
  - 6 is too few — users will have too many items per area, defeating the purpose.
  - 10+ is overwhelming for ADHD users. Cognitive load.
  - 8 is the sweet spot: specific enough to be useful, few enough to scan.
  - Users can delete areas they don't use and add custom ones.

ADHD-specific reasoning:
  - "Mind & Focus" explicitly validates ADHD as a life area (not a disorder)
  - "Projects & Ideas" gives the ADHD idea-generating brain a dedicated home
    (the #1 most-saved category for ADHD users will likely be this one)
  - No guilt-inducing names — no "Growth", no "Purpose", no "Spiritual"
  - Every area maps to concrete, tangible content people actually save


4. WHERE SHOULD CATEGORIES BE SHOWN IN THE UI?
====================================================================

Research on how the best apps handle this:

  Things 3:
    - Areas in sidebar as top-level grouping
    - Each area contains projects/tasks
    - Clean, minimal — area name + count
    - Never more than 1 level deep in the sidebar

  Linear:
    - Projects in sidebar
    - Status as horizontal tabs (Backlog / Todo / In Progress / Done)
    - Labels shown as colored dots on issue cards
    - Filters in a powerful filter bar above the list

  Notion:
    - Database views: Table, Board, Calendar, Gallery
    - Filter bar with property-based filtering
    - Group-by any property (including multi-select)
    - Sidebar for navigation between databases

  Obsidian:
    - Tags in a tag pane (shows all tags + counts)
    - Folders in file explorer sidebar
    - Search with tag: and path: operators
    - No built-in categorization UI — it's all manual

RECOMMENDATION FOR MEMO:

A. HOME SCREEN — Area Cards (primary navigation)
   The home screen IS the area browser. Not a dashboard, not a feed.

   Layout: Grid of 8 area cards (2 columns, scrollable)
   Each card shows:
     - Area icon + name
     - Item count
     - Colored left border or background tint
     - Last 2-3 items as preview thumbnails/text

   Tap a card -> full list of items in that area.

   Above the grid: "Inbox (12)" button for unprocessed items.

   Why this works for ADHD:
     - One glance shows everything
     - No decision paralysis (just tap what you need right now)
     - Counts give dopamine ("I have 47 gym ideas!")
     - No infinite scroll, no feed addiction

B. SEARCH — Filters as chips
   Search bar at top (always accessible).
   Below the search bar: horizontal scrolling filter chips.

   Filter chips:
     - Area: [Health & Body] [Career & Work] [Projects & Ideas] ...
     - Format: [Articles] [Voice Memos] [Screenshots] ...
     - Source: [Telegram] [Reddit] [Notion] ...
     - Status: [Inbox] [Active] [Reference]
     - Time: [This Week] [This Month] [Older]

   Multiple filters combinable: "Articles from Reddit about Health & Body"

   This is how Linear does it and it works beautifully.

C. NOTE CARDS — Compact metadata display
   Each note card in any list should show:
     - Title or first line (bold)
     - Summary (1 line, gray)
     - Source icon (small, top-right corner — Telegram logo, Reddit logo, etc.)
     - Format badge (small pill: "Article", "Voice Memo", etc.)
     - Area color indicator (thin colored left border, matching the area color)
     - 2-3 tags (small pills at bottom)
     - Timestamp ("3d ago")

   What NOT to show on cards:
     - Confidence scores (internal, not user-facing)
     - Full area name (the color border is enough; area name shows in filters)
     - Status (implied by which list you're viewing)

D. NOTE DETAIL — Full metadata
   When you open a note:
     - Full content
     - Summary (collapsible)
     - Area: [Health & Body] (tappable to change)
     - Tags: [tag1] [tag2] [+] (tappable to add/remove)
     - Format: Article
     - Source: Telegram, saved 3 days ago
     - Status: [Inbox] [Active] [Reference] [Archive] (segment control)
     - Link to original (if available)

E. NO DASHBOARD / NO OVERVIEW SCREEN (for MVP)
   Dashboards are a trap for ADHD apps. They look pretty but add
   cognitive load. The area grid IS the overview.

   Later (post-MVP), consider:
     - "This week" summary: "You saved 23 items across 5 areas"
     - Trending: "You've been saving a lot about cooking lately"
     - Resurface: "From 3 months ago: [random note]"

   But not for MVP. Ship the grid, search, and note detail.


5. HOW SHOULD AI AUTO-CATEGORIZATION WORK?
====================================================================

RECOMMENDATION: Single API call for all dimensions.

Current system does this right with processNote() in claude.ts — one call
returns summary + tags + dimension + confidence. Keep this pattern.

But expand the output to cover all 5 dimensions:

SINGLE CLAUDE CALL — input: raw note content + user's custom areas
OUTPUT JSON:
{
  "summary": "Short summary for scanning",
  "format": "article",
  "area": "health-body",
  "area_confidence": 0.92,
  "area_reasoning": "Discusses gym routines and protein intake",
  "secondary_areas": ["learning-interests"],
  "tags": ["upper-body", "protein", "gym-routine", "dumbbell"],
  "suggested_status": "reference"
}

What the AI assigns:
  - summary — always
  - format — detected from content structure (is it a link? a short message?
    a long article? an image description?)
  - area + confidence — primary life area
  - secondary_areas — other relevant areas (max 2)
  - tags — 3-8 specific, useful tags
  - suggested_status — usually "inbox", but if the content is clearly
    reference material (like a recipe), suggest "reference"

What the AI does NOT assign:
  - source — already known from the integration that captured it
  - final status — user decides, AI only suggests

WHY single call, not separate calls:
  1. Cost: 1 API call vs 4. At $3/1M input tokens, this matters at scale.
  2. Latency: 1 round-trip vs 4. Processing speed matters for batch import.
  3. Context: The AI needs to see the full picture to categorize well.
     Format detection helps area assignment ("this is a recipe article"
     -> format=article, area=home-life, tags=["recipe", "meal-prep"]).
  4. Consistency: One call means all outputs are coherent with each other.

KEEP the multi-signal approach for area assignment:
  The current 3-signal system (semantic 60% + Claude 30% + keywords 10%)
  is well-designed. Don't remove it. But use the single-call Claude result
  as the "AI signal" input to the multi-signal combiner.

BATCH OPTIMIZATION:
  For initial import (hundreds of notes), use Claude's batch API if available,
  or process in parallel with rate limiting. Group notes in batches of 5-10
  in a single prompt to reduce per-note overhead:

  "Categorize these 5 notes. Return a JSON array with one result per note."

  This cuts API calls by 5-10x during onboarding.


PRACTICAL EXAMPLES — How real notes would be categorized:
====================================================================

Example 1: User forwards a Telegram message with a gym workout image
  Source: telegram (automatic)
  Format: photo (automatic — it's an image)
  Area: Health & Body (AI, confidence 0.95)
  Tags: ["upper-body", "dumbbell", "chest", "gym"] (AI-suggested)
  Status: inbox (default)

Example 2: User saves a Reddit post about ADHD time management
  Source: reddit (automatic)
  Format: thread (automatic — it's a Reddit post with comments)
  Area: Mind & Focus (AI, confidence 0.88)
  Secondary area: Career & Work (some tips are work-specific)
  Tags: ["adhd", "time-management", "productivity", "pomodoro"] (AI-suggested)
  Status: inbox (default)

Example 3: User records a voice memo about a business idea
  Source: voice (automatic)
  Format: voice-memo (automatic)
  Area: Projects & Ideas (AI, confidence 0.91)
  Tags: ["saas", "developer-tools", "side-project"] (AI-suggested)
  Status: inbox (default)

Example 4: User saves an Instagram post with a recipe
  Source: instagram (automatic)
  Format: photo (automatic — Instagram image + caption)
  Area: Home & Life (AI, confidence 0.82)
  Secondary area: Health & Body (it's a healthy recipe)
  Tags: ["recipe", "meal-prep", "high-protein", "quick-dinner"] (AI-suggested)
  Status: reference (AI-suggested — recipes are reference material)

Example 5: User saves a Pocket article about salary negotiation
  Source: pocket (automatic)
  Format: article (automatic — it's a saved article)
  Area: Career & Work (AI, confidence 0.90)
  Secondary area: Money & Finance
  Tags: ["salary", "negotiation", "career-growth"] (AI-suggested)
  Status: inbox (default)

Example 6: Ambiguous content — "interesting things to do in Vancouver"
  Source: telegram (automatic)
  Format: snippet (automatic — short message)
  Area: Relationships & Social (AI, confidence 0.55 — LOW)
  Tags: ["vancouver", "activities", "travel"] (AI-suggested)
  Status: inbox (default)
  needsReview: true (confidence below threshold)
  Suggestions: [Relationships & Social, Home & Life, Learning & Interests]
  -> User picks the right one, AI learns for next time.


MIGRATION PATH FROM CURRENT SYSTEM:
====================================================================

The codebase currently uses WheelOfLifeDimension everywhere. Here's
the mapping for migration:

  health-fitness      -> health-body
  mental-health       -> mind-focus
  career-learning     -> career-work
  social-relationships -> relationships-social
  skills-hobbies      -> learning-interests
  empire-building     -> projects-ideas
  home-environment    -> home-life
  spiritual-purpose   -> (DROPPED — redistribute to mind-focus + learning-interests)

Files to change:
  - backend/src/models/types.ts (rename type + constants)
  - backend/src/services/ai/categorization.ts (keyword dictionaries, embeddings)
  - backend/src/services/ai/claude.ts (prompt text, dimension descriptions)
  - backend/prisma/schema.prisma (rename fields, add format enum)
  - iOS views (when built)

Add to schema.prisma:
  - Note.format field (enum of format types)
  - Note.status field (enum: inbox, active, reference, archived)
  - Category.isDefault boolean (to distinguish system defaults from user-created)
  - Drop Category.wheelOfLifeDimension, add Category.type enum (area, custom)


SUMMARY — The 5 Dimensions:
====================================================================

  1. Source     | Where it came from    | Automatic  | telegram, reddit, voice...
  2. Format     | What kind of content  | Automatic  | article, snippet, voice-memo...
  3. Area       | What part of life     | AI-assigned| Health & Body, Career & Work...
  4. Tags       | Specific labels       | AI + User  | "meal-prep", "python", "date-idea"
  5. Status     | Workflow state        | User + AI  | inbox, active, reference, archived

No Wheel of Life branding. No mental health scoring. No spiritual dimensions.
Just practical organization that helps ADHD brains find things and act on them.
