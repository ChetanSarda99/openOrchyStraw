# Life Categorization & Intelligent Repository System
## From Chaos to Action: Mental Health Framework Integration

**Created:** March 13, 2026  
**Status:** Core feature spec - ready for implementation  
**Related Docs:** PRODUCT_SPEC.md, APP_BUILDING_BEST_PRACTICES.md, TECH_STACK.md

---

## Table of Contents
1. [Vision](#vision)
2. [Mental Health Framework: Wheel of Life](#mental-health-framework-wheel-of-life)
3. [Chaos → Action: Organization Systems](#chaos--action-organization-systems)
4. [AI Categorization Engine](#ai-categorization-engine)
5. [Repository & Category View](#repository--category-view)
6. [Batch Processing Architecture](#batch-processing-architecture)
7. [Obsidian & Notion Integration](#obsidian--notion-integration)
8. [Customizable Note Types](#customizable-note-types)
9. [Technical Implementation](#technical-implementation)
10. [User Experience Flow](#user-experience-flow)
11. [Privacy & Control](#privacy--control)

---

## Vision

**Current Problem:** ADHD brains save ideas everywhere (Instagram, Telegram, Notion, voice memos, Reddit, Twitter) but can never find them. Even worse: saved content sits unused, creating guilt and overwhelm.

**Memo's Solution (v1):** Universal search bar to find anything you've saved.

**Memo's Evolution (v2):** Transform saved chaos into actionable life categories. Not just "find your notes" — **turn your notes into a personalized life operating system.**

### The Shift
- **From:** "I saved 500 things this month and did nothing with them"
- **To:** "I have 12 cooking ideas, 8 gym routines to try, 5 friend date concepts — organized, actionable, alive"

---

## Mental Health Framework: Wheel of Life

### What Is It?
The **Wheel of Life** is a coaching/therapy tool that divides life into key dimensions. Users rate satisfaction (1-10) in each area, creating a visual "wheel" showing life balance.

**Why It Matters for Memo:**
- ADHD brains struggle with life balance → framework provides structure
- Saved content naturally aligns to life areas (gym posts = Health, recipes = Self-Care)
- Seeing gaps motivates action ("I have 0 items in Relationships — I should save some friend ideas")

### Standard Dimensions (Customizable)

#### 6-Area Model (Simpler, Therapy-Focused)
1. **Physical** - Fitness, sleep, health tracking, nutrition
2. **Emotional** - Mental health, therapy, journaling, self-awareness
3. **Psychological** - Learning, reading, cognitive growth
4. **Social** - Friendships, family, dating, community
5. **Professional** - Career, skills, side projects, business
6. **Spiritual** - Purpose, meditation, values, meaning

#### 8-Area Model (Comprehensive, Coaching Standard)
1. **Health & Fitness** - Exercise, nutrition, medical, body care
2. **Mental & Emotional** - Therapy, mindfulness, stress management
3. **Social & Relationships** - Friends, family, dating, networking
4. **Career & Professional** - Job, skills, income, growth
5. **Financial** - Budget, savings, investments, money goals
6. **Personal Growth** - Learning, hobbies, creativity, skills
7. **Environment** - Home, workspace, organization, aesthetics
8. **Spiritual & Purpose** - Meaning, values, beliefs, contribution

#### Memo's Default (CS's Life - Customizable for All Users)
Based on CS's Wheel of Life in Notion + Transformation System:

1. **Health & Fitness** (Weight loss, gym, knee recovery, meals)
2. **Mental Health** (ADHD, therapy, self-love, confidence)
3. **Career & Learning** (BC Cancer, data skills, Empire ideas)
4. **Social & Relationships** (New people, dating, friends)
5. **Skills & Hobbies** (Singing, piano, reading, sketching, skiing)
6. **Empire Building** (Business ideas, side projects, innovation)
7. **Home & Environment** (Chores, organizing, meal prep)
8. **Spiritual & Purpose** ("New Man" journey, self-discovery)

**Key Insight:** Users can customize dimensions. App suggests defaults based on common patterns, but ADHD/neurodivergent users may have unique life structures.

### How It Works in Memo

#### Auto-Categorization
When Memo processes a saved post (Instagram reel, Telegram message, Notion page):
1. **AI analyzes content** (image OCR + text + context)
2. **Maps to Wheel of Life dimension** (e.g., gym workout video → Health & Fitness)
3. **Assigns subcategory** (e.g., Health & Fitness > Gym > Upper Body)
4. **Suggests tags** (e.g., #dumbbells, #chest-day, #knee-safe)

#### User Review & Learning
- User can approve/edit AI suggestions
- Corrections improve future categorization
- Over time, AI learns user's personal taxonomy

#### Wheel Visualization
- Dashboard shows Wheel of Life with saved item counts per dimension
- Example: Health (47 items) | Social (12 items) | Empire (89 items)
- Visual gaps highlight neglected life areas → prompts balanced saving

---

## Chaos → Action: Organization Systems

### The Problem
Saving ≠ Organizing ≠ Doing

**Reality Check:**
- CS has 314 Samsung Notes, 198 Telegram images, 75+ Notion pages
- Most sit unread, unactionable, guilt-inducing
- ADHD: out of sight = out of mind

**Goal:** Turn chaotic saved content into structured action system

### PARA Method (Tiago Forte)
**P**rojects | **A**reas | **R**esources | **A**rchive

#### How It Maps to Memo

**1. Projects** - Active, time-bound goals
- Example: "Launch Memo by June 2026"
- Saved items tagged as "Project: Memo" appear here
- Deadline tracking, progress view

**2. Areas** - Ongoing responsibilities (maps to Wheel of Life)
- Example: "Health & Fitness" area contains all gym/meal/recovery content
- No deadline, continuous improvement

**3. Resources** - Reference material for future use
- Example: "Cooking Recipes" - not active, but want to keep
- Searchable library, not action-focused

**4. Archive** - Completed or inactive
- Example: Old business ideas CS tried but abandoned
- Keeps database clean without deleting memories

#### PARA in Memo UI
Users can toggle between views:
- **Wheel of Life View** (life balance focus)
- **PARA View** (GTD actionability focus)
- **All Categories View** (custom user taxonomy)

### GTD (Getting Things Done - David Allen)
5-step process: Capture → Clarify → Organize → Reflect → Engage

#### How Memo Implements GTD

**1. Capture**
- Memo already does this (save from Instagram, Telegram, Notion, etc.)
- ADHD-friendly: one tap to save, no friction

**2. Clarify**
- AI pre-processes: "This is a gym workout (Health > Gym > Upper Body)"
- User confirms/edits in batch review flow

**3. Organize**
- Auto-files into PARA + Wheel of Life categories
- User can drag-drop between categories

**4. Reflect**
- Weekly review prompt: "You saved 23 items this week. Review unprocessed?"
- Dashboard shows category growth over time

**5. Engage**
- Browse categories (e.g., "Cooking > Quick Meals") to find ideas when needed
- Random inspiration mode: "Show me 3 random Gym ideas"
- Action mode: "Turn this into a task" (send to Notion To-Do or Obsidian Daily Note)

### Actionable Intelligence Features

#### Smart Prompts
- "You have 12 gym routines saved. Try one today?"
- "3 new friend date ideas this week. Schedule one?"
- "15 business ideas in Empire — time to research one?"

#### Next Action Extraction (AI-Powered)
For each saved item, AI suggests next action:
- **Recipe saved** → "Buy ingredients" + auto-generate grocery list
- **Gym workout saved** → "Schedule workout on calendar"
- **Business idea saved** → "Research competitors for 30 min"

#### Integration with Task Systems
- One-tap send to Notion To-Do, Obsidian task, Apple Reminders, Todoist
- AI converts saved content into actionable task with context link

---

## AI Categorization Engine

### How It Works

#### Phase 1: Content Analysis
**Input Types:**
- Text (Telegram messages, Reddit posts, Twitter threads)
- Images (Instagram posts with OCR, infographics, screenshots)
- Voice memos (transcribed + analyzed)
- Web pages (Notion pages, bookmarks, articles)

**AI Processing:**
1. **Text extraction** (OCR for images, transcription for audio)
2. **Semantic analysis** (NLP embeddings - what is this about?)
3. **Intent detection** ("Is this actionable or reference?")
4. **Entity extraction** ("Does it mention gym, recipes, ADHD, etc.?")

#### Phase 2: Category Matching
**Multi-Signal Approach:**
1. **Document-level similarity** (60% weight)
   - Compare entire content to category definitions
   - Uses sentence transformers (e.g., all-MiniLM-L6-v2)

2. **Sentence-level similarity** (30% weight)
   - Each sentence scored against categories
   - Catches nuanced multi-topic content

3. **Keyword extraction** (10% weight)
   - TF-IDF + manual keyword lists
   - Handles edge cases (slang, abbreviations)

4. **User history weighting** (adaptive)
   - If user always saves leg day content to "Gym > Lower Body", boost that pattern
   - Personalized taxonomy learning

#### Phase 3: Multi-Category Assignment
**Problem:** Content often fits multiple categories
- Example: "ADHD-friendly meal prep for weight loss"
  - Could be: Health > Nutrition OR Mental Health > ADHD Tools OR Cooking > Meal Prep

**Solution:** Hierarchical tagging + primary/secondary categories
- **Primary:** Health > Nutrition (main focus)
- **Secondary:** Mental Health > ADHD Tools, Cooking > Meal Prep
- User sees it in all 3 categories but knows primary intent

#### Phase 4: Confidence Scoring
- **High confidence (>0.85):** Auto-categorize, show to user in batch review
- **Medium confidence (0.60-0.85):** Suggest category, ask user to confirm
- **Low confidence (<0.60):** Flag for manual categorization

### Taxonomy Evolution
**Not static** - AI learns and suggests new categories

**Examples:**
- User saves 20 items about "knee-safe exercises" → AI suggests new subcategory "Health > Gym > Knee-Safe"
- User frequently saves "ADHD time management" content → AI suggests "Mental Health > ADHD > Time Management"

**User Control:**
- Accept AI category suggestions
- Edit/rename categories
- Merge/split categories
- Delete unused categories

### Implementation Tech Stack
- **Embeddings:** Sentence Transformers (all-MiniLM-L6-v2) via Hugging Face or OpenAI text-embedding-3-small
- **Classification:** Fine-tuned BERT or GPT-4 few-shot prompting
- **OCR:** Google Cloud Vision API or Tesseract (cost vs. accuracy trade-off)
- **Speech-to-Text:** Whisper API or Deepgram
- **Storage:** Vector database (Pinecone, Weaviate, or Supabase pgvector)

---

## Repository & Category View

### The Experience
**Shift from "search bar" to "living library"**

#### Home View Options
Users can toggle between:

**1. Wheel of Life Dashboard**
- 8 circular segments (Health, Social, Career, etc.)
- Each shows item count + visual fill (like a pie chart)
- Tap segment → browse that category

**2. PARA View**
- 4 tabs: Projects | Areas | Resources | Archive
- Each tab shows category cards with item counts
- Active projects highlighted at top

**3. Custom Categories View**
- User-created folders (like Cooking > Quick Meals, Gym > Upper Body)
- Drag-drop to reorder
- Nested hierarchy (up to 3 levels deep)

#### Category Browsing
**Example: User taps "Health & Fitness > Gym"**

Shows:
- **Item count:** 47 saved workouts
- **Recent items:** 5 most recent saves (thumbnails + titles)
- **Subcategories:** Upper Body (12), Lower Body (18), Cardio (9), Mobility (8)
- **Tags:** #dumbbells (15), #bodyweight (10), #knee-safe (7)
- **Smart filters:**
  - "Unread" (items not viewed since saving)
  - "Favorites" (user-starred items)
  - "This week" (saved in last 7 days)

**Item Detail View:**
- Full content (image, text, link back to source)
- AI summary (for long articles/videos)
- Tags (editable)
- Notes field (user can add context)
- Action buttons:
  - "Add to Task List" (send to Notion/Obsidian)
  - "Share" (send to friend via Telegram/WhatsApp)
  - "Archive" (move to Archive category)
  - "Delete" (permanent removal)

#### Random Inspiration Mode
**For ADHD brains that forget what they saved**

- "Show me 3 random Cooking ideas"
- "Surprise me with a Gym workout"
- "Pick a friend date idea for me"

Like shuffling a deck of your own saved content.

#### Smart Collections (AI-Generated)
App auto-creates temporary collections based on patterns:
- "5 meal prep recipes you saved last month" (around Sunday meal prep time)
- "Upper body workouts you haven't tried" (on Tue/Thu gym days per CS's schedule)
- "Business ideas with high scores" (from Business Ideas Tracker)

---

## Batch Processing Architecture

### The Challenge
**Initial load:** Process ALL existing saved content (100s-1000s of items across platforms)  
**Ongoing sync:** Process new saves in real-time or near-real-time

### Phase 1: Initial Batch Processing (One-Time)

#### Data Sources
1. **Telegram:** All saved messages/images from specific groups
2. **Instagram:** Saved posts collection (via unofficial API or export)
3. **Notion:** All pages in designated databases
4. **Reddit:** Saved posts (via Reddit API)
5. **Twitter/X:** Bookmarks (via API or export)
6. **Voice memos:** Files in designated folder (iOS/Android)

#### Processing Flow
```
User initiates first-time setup
  ↓
Select data sources to import (checkboxes)
  ↓
For each source:
  - Authenticate (OAuth or API key)
  - Fetch item list (paginated)
  - Add to processing queue
  ↓
Queue Worker (background process):
  - Fetch item content
  - AI categorization (parallel batch processing)
  - Store in database with categories
  - Update progress bar
  ↓
User sees dashboard populate in real-time
  ↓
Final review: Batch approve/edit AI categories
  ↓
Done! Repository is live
```

**Estimated Time (CS's data as example):**
- 314 Samsung Notes + 198 Telegram images + 75 Notion pages = ~587 items
- @ 10 items/min (AI processing) = ~60 minutes
- User not blocked: can browse processed items while queue continues

#### Progress UI
- Overall progress: "Processing 587 items... 342 complete (58%)"
- Per-source breakdown: "Telegram: 198/198 ✓ | Notion: 44/75 (59%) | Samsung Notes: pending..."
- Estimated time remaining: "~18 minutes left"

### Phase 2: Ongoing Sync (Real-Time)

#### Architecture: Web-Queue-Worker Pattern
```
New content saved (e.g., Instagram post)
  ↓
App captures save event
  ↓
Add to message queue (e.g., Redis, AWS SQS, Cloudflare Queues)
  ↓
Background worker picks up task
  ↓
AI processes & categorizes
  ↓
Store in database
  ↓
Push notification to user (optional): "New Gym idea added!"
  ↓
User sees it in repository immediately
```

#### Sync Frequency Options
**User chooses trade-off between battery/data vs. speed:**

1. **Real-time** (via webhooks where supported)
   - Telegram: Bot API webhooks
   - Notion: Database subscriptions
   - Fastest but uses more battery

2. **Polling (15 min intervals)**
   - Check APIs every 15 min for new saves
   - Balanced approach

3. **Manual sync**
   - User taps "Sync now" when they want updates
   - Best for battery, but requires user action

#### Queue Management
**Challenge:** Don't overwhelm AI API (rate limits) or user's phone (battery)

**Solution: Batching + throttling**
- Collect items for 15 min
- Process in batches of 10 items
- Throttle to 60 requests/min (respect OpenAI/Anthropic limits)
- Exponential backoff on errors

**Priority Queue:**
- High priority: User manually saved something (process immediately)
- Medium priority: Automated sync (process within 15 min)
- Low priority: Backfill old content (process overnight when charging)

### Technical Stack Options

#### Lightweight (MVP - Mobile-Friendly)
- **Queue:** In-app SQLite queue table with status column
- **Worker:** Background service (iOS BackgroundTasks, Android WorkManager)
- **Sync:** Polling every 15 min while app active, hourly when backgrounded

#### Scalable (Post-MVP - Cloud Backend)
- **Queue:** Redis or AWS SQS
- **Worker:** Serverless functions (Cloudflare Workers, AWS Lambda)
- **Sync:** Webhooks (real-time) + polling fallback
- **Database:** PostgreSQL with pgvector for embeddings

---

## Obsidian & Notion Integration

### The Vision
**Memo as central hub** - categorize content, then send to Notion/Obsidian for deeper work

**NOT replacing Notion/Obsidian** - enhancing them with auto-organization

### Obsidian Integration

#### Export to Obsidian Vault
**Use Case:** CS wants gym workout ideas as markdown files in Obsidian vault

**Flow:**
1. User selects "Health > Gym" category in Memo
2. Taps "Export to Obsidian"
3. Chooses Obsidian vault location (via file picker or Obsidian URI)
4. Memo creates markdown files:

```markdown
---
tags: [gym, upper-body, dumbbells, memo-imported]
source: instagram
saved_date: 2026-03-10
memo_category: Health > Gym > Upper Body
---

# Dumbbell Chest Workout

![workout-image](attachments/workout-123.jpg)

**Source:** [@fitnessguru on Instagram](https://instagram.com/p/abc123)

## Notes
Knee-safe, no jumping. CS tried 2026-03-12, felt great.

## Next Actions
- [ ] Buy 20lb dumbbells
- [ ] Schedule for Tuesday AM gym session
```

**Sync Options:**
- **One-time export:** Manual export whenever user wants
- **Auto-sync:** New items in selected categories auto-create Obsidian notes
- **Bidirectional:** Changes in Obsidian sync back to Memo (advanced, post-MVP)

#### Obsidian Plugin Integration (Future)
- Build Obsidian community plugin "Memo Sync"
- Inline Memo search within Obsidian
- Right-click note → "Send to Memo category"

### Notion Integration

#### Export to Notion Database
**Use Case:** CS wants business ideas in Notion's Business Ideas Tracker DB

**Flow:**
1. User selects "Empire > Business Ideas" category in Memo
2. Taps "Export to Notion"
3. Authenticates with Notion (OAuth)
4. Chooses target database (dropdown of user's Notion databases)
5. Memo maps fields:

```
Memo fields → Notion properties
- Title → Name (title property)
- Category → Area (select)
- AI Summary → Description (text)
- Source URL → Source (url)
- Saved Date → Date Generated (date)
- Tags → Tags (multi-select)
- Notes → Research Notes (text)
```

**Sync Options:**
- **One-time export:** Bulk export selected items
- **Auto-sync:** New items auto-create Notion pages
- **Bidirectional:** Edits in Notion sync back to Memo (requires webhooks, complex but valuable)

#### Notion API Challenges (Based on Research)
- **Nesting limits:** Notion API restricts block nesting depth (2 levels max)
  - Solution: Flatten deep nested lists in export
- **Rate limits:** 3 requests/sec
  - Solution: Queue-based export with throttling
- **Formatting conversion:** Markdown → Notion blocks
  - Solution: Use Notion SDK block builders (annoyingly verbose but necessary)

#### Bidirectional Sync (Advanced Feature)
**CS asked for user control over "how and what is done"**

**Conflict Resolution Strategy:**
1. **Last-write-wins** (simple but risky)
   - Latest edit (Memo or Notion) overwrites other
   - Show warning if conflict detected

2. **Merge-with-user-review** (safer)
   - Detect conflicts (both edited same item since last sync)
   - Show diff UI: "Memo version | Notion version - Choose one or merge"

3. **Field-level sync** (most flexible)
   - User chooses which fields sync bidirectionally
   - Example: Title + tags sync both ways, but notes only Notion → Memo

**Sync State Tracking:**
- Store last sync timestamp per item
- Hash content to detect changes
- Notion page ID <-> Memo item ID mapping table

### User Control Panel
**Settings screen: "Integrations"**

**Obsidian Section:**
- [ ] Enable Obsidian sync
- Vault path: `/Users/CS/ObsidianVault/Memo Imports/`
- Sync frequency: Manual / Hourly / Real-time
- Categories to sync: [Select categories]
- File naming: `{category}-{title}-{date}.md` (customizable template)

**Notion Section:**
- [ ] Enable Notion sync
- Connected databases:
  - Business Ideas Tracker → Empire > Business Ideas
  - Notes Master → Learning > Research
  - (Add more...)
- Sync direction:
  - ○ Memo → Notion only
  - ○ Notion → Memo only
  - ● Bidirectional (experimental)
- Conflict resolution: Last-write-wins / Ask me / Field-level

---

## Customizable Note Types

### The Problem
**One-size-fits-all doesn't work for ADHD brains**

Examples:
- Gym workout needs: exercises, sets/reps, difficulty, knee-safe flag
- Recipe needs: ingredients, cook time, servings, difficulty
- Business idea needs: problem, solution, market size, effort, score
- Friend date idea needs: activity, location, cost, energy level

**Memo's solution:** User-defined schemas (like Notion databases)

### Schema System Design

#### Built-In Templates (Suggested Defaults)
**Memo ships with common schemas users can enable:**

**1. Gym Workout**
- Exercise list (text array)
- Duration (number, minutes)
- Difficulty (select: Beginner/Intermediate/Advanced)
- Equipment (multi-select: Dumbbells, Barbell, Bodyweight, etc.)
- Muscle groups (multi-select: Chest, Back, Legs, etc.)
- Joint safety (multi-select: Knee-safe, Shoulder-safe, etc.)
- Sets x Reps (text)

**2. Recipe**
- Ingredients (text array)
- Cook time (number, minutes)
- Servings (number)
- Difficulty (select: Easy/Medium/Hard)
- Cuisine (select: Italian, Mexican, Asian, etc.)
- Dietary (multi-select: Vegan, Gluten-free, High-protein, etc.)
- Meal type (select: Breakfast, Lunch, Dinner, Snack)

**3. Business Idea**
- Problem statement (text)
- Solution (text)
- Target customer (text)
- Market size (select: Small/Medium/Large)
- Solo executable (checkbox)
- Startup cost (number, $)
- Effort required (select: Low/Medium/High)
- Moat potential (number, 1-10)
- Total score (number, auto-calculated)

**4. Learning Resource**
- Topic (text)
- Type (select: Article, Video, Book, Course, Podcast)
- Length (number, minutes or pages)
- Difficulty (select: Beginner/Intermediate/Advanced)
- Priority (select: Must-read/Someday/Nice-to-have)
- Completed (checkbox)

**5. Social/Friend Idea**
- Activity (text)
- Location (text)
- Cost (select: Free/$/$$/$$$/$$$$)
- Energy level (select: Low/Medium/High)
- Group size (select: 1-on-1, Small group, Large group)
- Weather dependent (checkbox)

#### Custom Schema Builder
**For power users (like CS) who want total control**

**UI Flow:**
1. User taps "Create custom note type"
2. Name it (e.g., "ADHD Strategies")
3. Add fields:
   - Field name: "Strategy name"
   - Field type: Text / Number / Select / Multi-select / Checkbox / Date / URL
   - Required: Yes/No
   - Default value: (optional)
4. Save schema
5. Assign schema to category (e.g., "Mental Health > ADHD > Strategies")

**Field Types (Notion-Inspired):**
- **Text** - Single line (title, names)
- **Long text** - Multi-line (descriptions, notes)
- **Number** - Integer or decimal (scores, prices, duration)
- **Select** - Single choice dropdown (difficulty, priority)
- **Multi-select** - Multiple choices (tags, categories)
- **Checkbox** - Boolean (completed, favorite, safe)
- **Date** - Calendar picker (deadline, saved date)
- **URL** - Link validation (source, reference)
- **File** - Attachment (images, PDFs)
- **Person** - Reference to contacts (for social ideas)
- **Formula** - Auto-calculate (like Notion formulas)

#### AI Auto-Fill
**Game-changer: AI fills schema fields from saved content**

**Example:** User saves Instagram reel of a workout

1. Memo detects it's a "Gym Workout" based on content
2. Applies "Gym Workout" schema
3. AI analyzes video + caption:
   - Exercise list: "Dumbbell bench press, Incline flyes, Push-ups"
   - Duration: 25 minutes
   - Difficulty: Intermediate
   - Equipment: Dumbbells
   - Muscle groups: Chest, Triceps
   - Joint safety: Knee-safe ✓
   - Sets x Reps: "3x12, 3x10, 3xAMRAP"
4. User reviews & edits if needed
5. Saves to database with rich metadata

**Searchability improvement:**
- Instead of text search "knee safe workout", user can filter:
  - Category: Gym
  - Joint safety: Knee-safe
  - Equipment: Dumbbells
  - Difficulty: Beginner or Intermediate
- Results are precise, not keyword-dependent

### Schema Templates Marketplace (Future)
**Community-driven schema library**

- Users can publish their custom schemas
- Others can install ("Install 'Knee Rehab Exercises' schema by @physio_dave")
- Upvote/review schemas
- Memo team curates high-quality templates

---

## Technical Implementation

### Database Schema Design

#### Core Tables

**users**
```sql
id, email, created_at, settings (jsonb)
```

**categories**
```sql
id, user_id, name, parent_id (self-reference for hierarchy),
icon, color, wheel_of_life_dimension, para_type (project/area/resource/archive),
order_index, created_at
```

**note_schemas**
```sql
id, user_id, name, description,
fields (jsonb array of {name, type, required, options}),
is_template (built-in vs custom), created_at
```

**saved_items**
```sql
id, user_id, title, content (text), content_type (text/image/video/audio),
source_platform (telegram/instagram/notion/reddit/twitter/voice),
source_url, source_id (platform-specific ID),
raw_data (jsonb - full API response), saved_at,
processed (boolean), processed_at,
embedding (vector) -- for semantic search
```

**item_categories** (many-to-many)
```sql
id, item_id, category_id, is_primary (boolean),
confidence_score (0-1), auto_categorized (boolean),
user_confirmed (boolean)
```

**item_metadata** (schema field values)
```sql
id, item_id, schema_id, field_values (jsonb - {field_name: value}),
created_at, updated_at
```

**sync_state** (for Obsidian/Notion integration)
```sql
id, item_id, platform (obsidian/notion),
external_id (Notion page ID or Obsidian file path),
last_synced_at, hash (content hash for conflict detection),
sync_direction (to_platform/from_platform/bidirectional)
```

**processing_queue**
```sql
id, user_id, item_id, source_platform,
status (pending/processing/completed/failed),
priority (high/medium/low), attempts, error_message,
created_at, processed_at
```

### AI Pipeline Architecture

#### Step 1: Content Extraction
**Service: `ContentExtractor`**

```typescript
interface ExtractedContent {
  text: string;
  images: string[]; // URLs or base64
  metadata: {
    platform: string;
    author: string;
    timestamp: Date;
    url: string;
  };
}

async function extractContent(source: SavedItem): Promise<ExtractedContent> {
  switch (source.platform) {
    case 'telegram':
      return extractTelegram(source);
    case 'instagram':
      return extractInstagram(source);
    case 'notion':
      return extractNotion(source);
    // ...
  }
}
```

#### Step 2: AI Categorization
**Service: `CategorizationEngine`**

```typescript
interface CategoryPrediction {
  categoryId: string;
  isPrimary: boolean;
  confidence: number;
  reasoning: string; // for user review
}

async function categorize(content: ExtractedContent): Promise<CategoryPrediction[]> {
  // Generate embedding
  const embedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: content.text
  });

  // Find similar categories via vector search
  const similarCategories = await vectorDB.search(embedding, topK: 5);

  // Use GPT-4 for final classification with user's taxonomy
  const prompt = `
    Analyze this saved content and assign it to relevant categories.
    User's categories: ${JSON.stringify(userCategories)}
    
    Content: ${content.text}
    
    Return JSON: [{categoryId, isPrimary, confidence, reasoning}]
  `;
  
  const result = await openai.chat.completions.create({
    model: 'gpt-4-turbo',
    response_format: { type: 'json_object' },
    messages: [{role: 'user', content: prompt}]
  });

  return JSON.parse(result.choices[0].message.content);
}
```

#### Step 3: Schema Field Extraction
**Service: `SchemaFiller`**

```typescript
async function fillSchema(
  content: ExtractedContent,
  schema: NoteSchema
): Promise<Record<string, any>> {
  const prompt = `
    Extract structured data from this content based on the schema.
    
    Schema fields: ${JSON.stringify(schema.fields)}
    Content: ${content.text}
    
    Return JSON matching the schema.
  `;

  const result = await openai.chat.completions.create({
    model: 'gpt-4-turbo',
    response_format: { type: 'json_object' },
    messages: [{role: 'user', content: prompt}]
  });

  return JSON.parse(result.choices[0].message.content);
}
```

### Background Processing (Mobile)

#### iOS: BackgroundTasks Framework
```swift
import BackgroundTasks

func registerBackgroundTasks() {
  BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.memo.processSavedItems",
    using: nil
  ) { task in
    handleProcessing(task: task as! BGProcessingTask)
  }
}

func handleProcessing(task: BGProcessingTask) {
  task.expirationHandler = {
    // Save state, cancel gracefully
    task.setTaskCompleted(success: false)
  }
  
  // Process queue items
  processQueue { success in
    task.setTaskCompleted(success: success)
  }
  
  // Schedule next background task
  scheduleBackgroundProcessing()
}
```

#### Android: WorkManager
```kotlin
class ProcessQueueWorker(context: Context, params: WorkerParameters) :
  CoroutineWorker(context, params) {
  
  override suspend fun doWork(): Result {
    return try {
      processQueue()
      Result.success()
    } catch (e: Exception) {
      if (runAttemptCount < 3) {
        Result.retry()
      } else {
        Result.failure()
      }
    }
  }
}

// Schedule periodic work
val processRequest = PeriodicWorkRequestBuilder<ProcessQueueWorker>(
  15, TimeUnit.MINUTES
).build()

WorkManager.getInstance(context).enqueue(processRequest)
```

### Sync Architecture (Obsidian/Notion)

#### Obsidian Export
```typescript
async function exportToObsidian(
  items: SavedItem[],
  vaultPath: string,
  template: string
) {
  for (const item of items) {
    const markdown = await renderTemplate(item, template);
    const fileName = sanitizeFileName(`${item.category}-${item.title}.md`);
    const filePath = path.join(vaultPath, fileName);
    
    await fs.writeFile(filePath, markdown);
    
    // Track sync state
    await db.syncState.create({
      itemId: item.id,
      platform: 'obsidian',
      externalId: filePath,
      lastSyncedAt: new Date(),
      hash: hashContent(markdown)
    });
  }
}
```

#### Notion Bidirectional Sync
```typescript
async function syncToNotion(item: SavedItem, databaseId: string) {
  const notion = new Client({ auth: user.notionApiKey });
  
  // Check if item already exists in Notion
  const syncState = await db.syncState.findOne({
    where: { itemId: item.id, platform: 'notion' }
  });
  
  if (syncState) {
    // Update existing page
    const localHash = hashContent(item);
    const remoteHash = await getNotionPageHash(notion, syncState.externalId);
    
    if (localHash !== remoteHash && syncState.hash !== remoteHash) {
      // Conflict! Both changed since last sync
      return handleConflict(item, syncState, notion);
    }
    
    await notion.pages.update({
      page_id: syncState.externalId,
      properties: mapToNotionProperties(item)
    });
  } else {
    // Create new page
    const page = await notion.pages.create({
      parent: { database_id: databaseId },
      properties: mapToNotionProperties(item)
    });
    
    await db.syncState.create({
      itemId: item.id,
      platform: 'notion',
      externalId: page.id,
      lastSyncedAt: new Date(),
      hash: hashContent(item)
    });
  }
}
```

---

## User Experience Flow

### First-Time Setup

**Step 1: Welcome & Vision**
- "Memo turns your saved chaos into organized action"
- Explain Wheel of Life concept with visual
- "Let's set up your life categories"

**Step 2: Choose Your Framework**
- Option A: Use Wheel of Life (8 default categories, customizable)
- Option B: Use PARA method (Projects, Areas, Resources, Archive)
- Option C: Start from scratch (build custom categories)
- CS likely chooses A (he already has Wheel of Life in Notion)

**Step 3: Customize Categories**
- Show default 8 categories (Health, Social, Career, etc.)
- User can rename, add, remove, reorder
- For each category, add subcategories (e.g., Health > Gym, Nutrition, Recovery)

**Step 4: Connect Data Sources**
- Checklist of platforms:
  - [ ] Telegram (authenticate, select groups to sync)
  - [ ] Instagram (login, import saved posts)
  - [ ] Notion (OAuth, select databases)
  - [ ] Reddit (API key, import saved posts)
  - [ ] Twitter/X (authenticate, import bookmarks)
  - [ ] Voice Memos (grant folder access)
- User can skip sources and add later

**Step 5: Initial Processing**
- "Processing 587 saved items... 12% complete"
- Background process runs, user can explore app meanwhile
- Push notification when complete: "Your repository is ready! 587 items organized into 8 categories."

**Step 6: Review & Approve**
- Batch review UI: Swipe through AI-categorized items
- Each item shows:
  - Thumbnail/preview
  - AI-suggested category (primary + secondary)
  - Confidence score
  - Quick actions: ✓ Approve | ✏ Edit | 🗑 Delete
- Can approve all high-confidence items in bulk

### Daily Usage Flow

#### Scenario 1: Saving New Content
**CS sees a gym workout on Instagram**

1. Tap "Save" on Instagram post (native Instagram save)
2. Memo detects save via Instagram API poll (every 15 min)
3. Background: AI categorizes → "Health > Gym > Upper Body" (confidence: 0.92)
4. Push notification: "New Gym idea saved!" (optional, user can disable)
5. CS opens Memo → sees it in "Health > Gym" category, ready to browse

#### Scenario 2: Browsing for Ideas
**CS wants to cook dinner, needs recipe ideas**

1. Opens Memo, taps "Cooking" category
2. Sees 23 recipes, filters by:
   - Cook time: < 30 min
   - Difficulty: Easy
   - Dietary: High-protein
3. Results: 5 recipes
4. Taps one, sees full recipe with ingredients
5. Taps "Add to Task List" → creates Notion To-Do: "Cook [recipe name] - buy ingredients"
6. Taps "Share" → sends recipe to friend via Telegram

#### Scenario 3: Weekly Review (GTD Reflect Step)
**Sunday evening, CS reviews saved content**

1. Memo prompts: "You saved 18 items this week. Review?"
2. Opens "This Week" smart collection
3. Sees breakdown:
   - Health: 6 gym workouts, 2 meal prep ideas
   - Social: 3 friend date ideas
   - Empire: 4 business concepts
   - Learning: 3 articles
4. Batch approves categories (swipe through quickly)
5. Marks 2 gym workouts as "Try next week" (adds to Favorites)
6. Archives 1 business idea (not relevant anymore)

#### Scenario 4: Action Mode
**CS is at gym, wants a workout**

1. Opens Memo → "Health > Gym"
2. Filters by:
   - Equipment: Dumbbells (only has dumbbells today)
   - Joint safety: Knee-safe
   - Difficulty: Intermediate
3. Sees 8 workouts
4. Taps "Random" → app picks one
5. Opens workout detail, follows exercises
6. After workout, taps "Completed" checkbox → auto-logs in Notion (if synced)

### Power User Flow (CS's Advanced Use Case)

#### Scenario: Empire Building Workflow
**CS researches business ideas, uses Memo + Notion integration**

**Setup:**
1. CS creates custom schema "Business Idea" in Memo
2. Fields: Name, Problem, Solution, Market Size, Solo Executable, Moat Score (1-10), Total Score
3. Assigns schema to "Empire > Business Ideas" category
4. Connects to Notion "Business Ideas Tracker" database
5. Enables bidirectional sync

**Daily Use:**
1. CS saves Twitter thread about SaaS opportunities
2. Memo AI:
   - Categorizes as "Empire > Business Ideas"
   - Extracts: Problem ("Freelancers struggle with invoicing"), Solution ("Automated invoice + payment tracking"), Market Size (Medium), etc.
   - Fills schema fields automatically
3. CS reviews in Memo, edits Moat Score from 6 → 8
4. Taps "Sync to Notion" → creates page in Business Ideas Tracker
5. Later, CS adds research notes in Notion
6. Memo syncs back → shows updated notes in app
7. Weekly, CS reviews top-scored ideas in Memo, decides which to pursue

---

## Privacy & Control

### CS's Requirement: "Gives users control over how and what is done"

#### Data Ownership
- **User owns all data** - no vendor lock-in
- Export all data anytime (JSON, CSV, or native formats)
- Delete account → permanent deletion within 30 days (GDPR compliance)

#### Processing Transparency
**Every AI action is auditable:**
- "Why was this categorized as Health?" → show AI reasoning
- "What fields were auto-filled?" → highlight AI vs. user edits
- "What data was sent to Notion?" → show sync log with timestamps

#### Granular Permissions

**Data Source Permissions:**
- User chooses which platforms to connect
- Can disconnect anytime (stops sync, doesn't delete existing data)
- Selective sync: "Only sync Instagram saves from last 6 months, ignore older"

**AI Processing Permissions:**
- [ ] Auto-categorize all items (default: on)
- [ ] Auto-fill schema fields (default: on, preview before save)
- [ ] Send data to OpenAI API for processing (default: on, can use local models)
- [ ] Use my data to improve categorization (default: off, explicit opt-in)

**Sync Permissions:**
- [ ] Enable Obsidian sync (user controls vault path)
- [ ] Enable Notion sync (user controls databases, sync direction)
- [ ] Allow Memo to read Notion pages (required for bidirectional)
- [ ] Allow Memo to edit Notion pages (required for two-way sync)

#### Privacy Modes

**1. Cloud Processing (Default)**
- AI runs on Memo servers (OpenAI API)
- Fastest, most accurate
- Data encrypted in transit & at rest
- Memo's privacy policy applies

**2. Local Processing (Privacy-Focused)**
- AI runs on-device (TensorFlow Lite, CoreML)
- No data leaves phone
- Slower, less accurate (smaller models)
- Battery intensive

**3. Self-Hosted (Advanced Users)**
- User runs Memo backend on own server
- Full control, host own AI models
- Requires technical setup
- Open-source backend (future roadmap)

#### Content Filtering
**Sensitive content protection:**
- User can mark categories as "Private" (require Face ID / passcode to open)
- Example: CS might mark "Mental Health" category as private
- Private categories excluded from:
  - App screenshots (system screenshot API blocks them)
  - Notifications (generic "New item saved" vs. "New Gym idea")
  - Search suggestions (won't appear in iOS/Android search)

---

## Implementation Roadmap

### Phase 1: MVP (Months 1-3)
**Goal: Core categorization + basic repository**

- [x] Research complete (this doc)
- [ ] Design Wheel of Life UI
- [ ] Build category management (CRUD)
- [ ] Implement AI categorization (OpenAI API)
- [ ] Connect 2 data sources (Telegram + Notion - CS's main sources)
- [ ] Batch processing queue
- [ ] Repository view (browse categories, search, filter)
- [ ] Basic export (Obsidian markdown files)
- [ ] TestFlight beta (CS + 10 ADHD testers)

**Success Metric:** CS can find any saved Telegram image or Notion page in < 10 seconds

### Phase 2: Action & Schemas (Months 4-5)
**Goal: Chaos → action transformation**

- [ ] Built-in schemas (Gym Workout, Recipe, Business Idea, Learning Resource)
- [ ] Custom schema builder
- [ ] AI auto-fill schema fields
- [ ] PARA view toggle (Projects/Areas/Resources/Archive)
- [ ] Smart collections (This Week, Unread, Favorites)
- [ ] Task integration (send to Notion To-Do, Apple Reminders)
- [ ] Random inspiration mode

**Success Metric:** CS acts on 3+ saved items per week (vs. current ~0)

### Phase 3: Sync & Integrations (Month 6)
**Goal: Seamless workflow with Obsidian + Notion**

- [ ] Notion bidirectional sync
- [ ] Obsidian auto-sync (new items → markdown files)
- [ ] Conflict resolution UI
- [ ] Sync state dashboard (show what's synced where)
- [ ] 5+ data sources (Instagram, Reddit, Twitter, Voice, Browser bookmarks)

**Success Metric:** CS's Notion databases auto-populate from Memo, zero manual entry

### Phase 4: Intelligence & Polish (Months 7-9)
**Goal: Proactive AI assistant**

- [ ] Weekly review prompts (GTD Reflect)
- [ ] Smart notifications ("You have 12 gym routines. Try one today?")
- [ ] Next action extraction (recipe → grocery list)
- [ ] Taxonomy evolution (AI suggests new categories)
- [ ] On-device processing option (privacy mode)
- [ ] Schema templates marketplace

**Success Metric:** CS's Wheel of Life shows balanced growth (no category < 10 items)

### Phase 5: Launch & Scale (Month 9+)
**Goal: Public beta → App Store**

- [ ] Onboarding flow (see APP_BUILDING_BEST_PRACTICES.md)
- [ ] Paywall (3-day trial → $9.99/mo Pro)
- [ ] TikTok ad campaign (ADHD angle)
- [ ] Community features (share categories, schemas)
- [ ] Analytics dashboard (user's own data insights)

**Success Metric:** 100 paying users by Month 12, 3x ROAS on ads

---

## Open Questions & Decisions Needed

### 1. AI Model Choice
**Options:**
- **OpenAI GPT-4 Turbo** (expensive but best categorization)
- **Anthropic Claude 3.5 Sonnet** (cheaper, good reasoning)
- **On-device (CoreML/TFLite)** (privacy but less accurate)
- **Hybrid:** Use GPT-4 for schema extraction, cheaper model for simple categorization

**Decision:** Start with GPT-4 Turbo, measure cost per 1000 items, optimize later

### 2. Freemium vs. Paid-Only
**Option A: Freemium (like current plan)**
- Free: 3 data sources, manual categorization
- Pro $9.99/mo: Unlimited sources, AI categorization, Obsidian/Notion sync

**Option B: Paid-only with trial**
- 7-day free trial (full features)
- $9.99/mo after trial
- Simpler onboarding, higher perceived value

**Decision:** TBD based on competitor analysis

### 3. Default Wheel of Life Dimensions
**Should Memo enforce 8 categories or let users fully customize from Day 1?**

**Option A: Guided (recommended)**
- Suggest 8 default categories
- User can edit/add/remove
- Most users appreciate starting point

**Option B: Blank slate**
- User builds categories from scratch
- More flexible but overwhelming for ADHD users

**Decision:** Option A (guided) - aligns with "reduce decision fatigue" ADHD principle

### 4. Sync Frequency Default
**What's the battery vs. freshness trade-off?**

**Options:**
- Real-time (webhooks where available, battery intensive)
- 15-min polling (balanced)
- Hourly (battery-friendly)
- Manual only (user controls)

**Decision:** 15-min polling default, let user adjust in settings

### 5. Notion Integration Scope
**How deep to go with Notion sync?**

**Phase 1 (MVP):**
- One-way export (Memo → Notion)
- User picks target database
- Simple property mapping

**Phase 2 (Advanced):**
- Bidirectional sync
- Conflict resolution
- Multi-database support

**Decision:** Phase 1 for launch, Phase 2 based on user demand

---

## Success Metrics

### User Engagement
- **Daily Active Users (DAU):** Target 40% of installs (high for utility app)
- **Session frequency:** 3+ sessions/week
- **Session length:** 5-8 min average (browse + act on 2-3 items)

### Chaos → Action Conversion
- **Items processed:** 80%+ of saved items categorized within 24 hours
- **Action taken:** 10%+ of saved items lead to task creation or completion
- **Repository growth:** 50+ new items saved per user per month

### Retention & Monetization
- **Day 7 retention:** 60%+ (critical for trial conversion)
- **Trial → Paid:** 15%+ conversion
- **Monthly churn:** < 10%
- **LTV:** $50+ (5+ months average subscription)

### ADHD-Specific Metrics
- **Time to find saved item:** < 10 seconds (vs. current "never find it" baseline)
- **Wheel of Life balance:** Standard deviation of category item counts decreases over time (life becomes more balanced)
- **User sentiment:** "I finally feel in control of my saved content" (qualitative surveys)

---

## Competitive Differentiation

### What Exists Today
**Search/Aggregation:**
- Notion, Obsidian (manual organization)
- Raindrop.io, Pocket (bookmarks only, no Instagram/Telegram)
- Evernote (clunky, no ADHD focus)

**Mental Health:**
- Fabulous, Finch (habit tracking, no content organization)
- Jour, Day One (journaling, not saved content)

**ADHD Tools:**
- Goblin Tools (task breakdown, no saving)
- Tiimo (visual schedules, not content management)

### Memo's Unique Position
**Only app that:**
1. Aggregates Instagram + Telegram + Notion + Reddit + Twitter + Voice
2. Auto-categorizes using mental health frameworks (Wheel of Life)
3. Transforms saved content into actionable insights
4. ADHD-first design (low friction, visual, gamified)
5. Syncs bidirectionally with Notion + Obsidian

**Closest competitor:** Saner.AI (ADHD notes app with AI) — but no social media aggregation, no Wheel of Life, no Notion sync

**Moat:** Multi-source aggregation is hard (APIs, rate limits, auth). Memo becomes the **central hub** for ADHD brains' digital life.

---

## Final Thoughts

This isn't just a "better search app."

**Memo is the operating system for ADHD brains' saved content.**

It takes scattered chaos and builds:
- **Structure** (Wheel of Life categories)
- **Action** (PARA projects + GTD next actions)
- **Intelligence** (AI categorization + schema extraction)
- **Control** (Obsidian/Notion sync + customizable schemas)
- **Empowerment** ("I saved it, I organized it, I acted on it")

For CS specifically:
- 314 Samsung Notes → organized
- 198 Telegram images → searchable
- 75+ Notion pages → categorized
- Empire ideas → ranked and actionable
- Gym content → knee-safe filtered and ready
- Social ideas → "2 new people per month" goal supported

**The ultimate test:** 
Does CS feel like his saved content is **working for him** instead of **guilt-tripping him**?

If yes, Memo succeeded.

---

**Next Steps:**
1. CS reviews this doc
2. Prioritize features (what must be in MVP vs. later?)
3. Design mockups (Wheel of Life UI, category browsing, batch review flow)
4. Build backend (queue system, AI pipeline, database schema)
5. Ship MVP to TestFlight

**Timeline:** 6 months to MVP if full-time, 9 months if part-time (around CS's work schedule)

**Let's build this.**

---

**Document Version:** 1.0  
**Last Updated:** March 13, 2026  
**Author:** Chai + CS  
**Status:** Ready for review and implementation planning
