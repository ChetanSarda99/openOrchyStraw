# Memo API Reference

**Base URL:** `https://<host>:<port>` (default `http://localhost:3000`)
**Auth:** Supabase JWT in `Authorization: Bearer <token>` header (all protected routes)
**Response format:** `{ data: T }` or `{ data: T[], meta: { page, limit, total, totalPages } }`
**Error format:** `{ error: { code: string, message: string } }`

---

## Global Headers

| Header | Direction | Description |
|--------|-----------|-------------|
| `Authorization` | Request | `Bearer <supabase-jwt>` — required on all protected routes |
| `X-API-Version` | Response | API version (currently `1.0`) |
| `X-RateLimit-Limit` | Response | Per-user rate limit (120 req/min) |
| `X-RateLimit-Remaining` | Response | Requests remaining in window |
| `X-RateLimit-Reset` | Response | Window reset timestamp |
| `X-Quota-*` | Response | Usage quota headers (notesCreated, aiCalls, etc.) |
| `X-Source-Limit` | Response | Max sources for plan |
| `X-Source-Count` | Response | Current connected source count |
| `X-Privacy-Session` | Request | Privacy session token (for private categories) |

## Rate Limits

- **Global:** 100 req/min per IP
- **Per-user:** 120 req/min (authenticated)
- **Search:** 10 req/min

---

## Health

### `GET /health`
Health check with database connectivity.

**Auth:** None

**Response (200):**
```json
{ "status": "ok", "timestamp": "2026-03-15T17:00:00Z", "uptime": 3600, "checks": { "database": true } }
```

---

## Notes

### `GET /notes`
List notes with pagination and filters.

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `source` | enum | Filter by source: `telegram\|notion\|voice\|instagram\|reddit\|twitter\|pocket\|email\|youtube` |
| `category` | string | Filter by category name |
| `format` | enum | `article\|bookmark\|snippet\|voice-memo\|screenshot\|photo\|video\|document\|thread\|highlight` |
| `status` | enum | `inbox\|active\|reference\|archived` |
| `from` | string | ISO date — notes captured after |
| `to` | string | ISO date — notes captured before |
| `page` | int | Page number (default 1) |
| `limit` | int | Items per page (1-100, default 20) |

**Response (200):**
```json
{
  "data": [{
    "id": "uuid",
    "userId": "uuid",
    "sourceId": "uuid",
    "contentType": "text",
    "format": "article",
    "status": "inbox",
    "title": "Note title",
    "body": "Note content...",
    "summary": "AI summary...",
    "mediaUrl": null,
    "originalUrl": "https://...",
    "tags": ["tag1"],
    "capturedAt": "2026-03-15T00:00:00Z",
    "importedAt": "2026-03-15T00:00:00Z",
    "category": "health-body",
    "categoryConfidence": 0.85,
    "metadata": {},
    "source": { "id": "uuid", "sourceType": "telegram" }
  }],
  "meta": { "page": 1, "limit": 20, "total": 42, "totalPages": 3 }
}
```

> **Important:** The note content field is `body`, NOT `content`. The `source` field is a nested object with `id` and `sourceType`, NOT a flat `sourceType` string.

### `POST /notes`
Create a note. Quota-checked (`notesCreated`).

**Body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `body` | string | Yes | Note content (max 50K chars) |
| `title` | string | No | Title (max 500) |
| `contentType` | enum | No | `text\|audio\|video\|image\|link` |
| `format` | enum | No | Note format (see above) |
| `status` | enum | No | Default `inbox` |
| `source` | enum | No | Source type |
| `category` | string | No | Category name |
| `tags` | string[] | No | Up to 20 tags |
| `capturedAt` | datetime | No | Original capture time |
| `originalUrl` | url | No | Source URL |
| `mediaUrl` | url | No | Media attachment URL |

**Response (201):** `{ "data": Note }`

### `GET /notes/:id`
Get a single note by UUID.

**Response (200):** `{ "data": Note }`

### `PATCH /notes/:id`
Update a note. All fields optional.

**Body:** Same fields as POST (all optional).

**Response (200):** `{ "data": Note }`

### `DELETE /notes/:id`
Delete a note (owner only).

**Response (200):** `{ "data": {} }`

### `GET /notes/:id/related`
Get semantically related notes via pgvector cosine similarity. Returns up to 10 notes ranked by similarity score.

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "...",
      "body": "...",
      "summary": "...",
      "tags": [],
      "format": "article",
      "status": "inbox",
      "capturedAt": "2026-03-15T00:00:00Z",
      "contentType": "text",
      "similarity": 0.92
    }
  ]
}
```

> **Note:** Response items include a `similarity` float (0-1) but no nested `source` object — this is a raw pgvector query result, not the standard Note serialization.

### `POST /notes/:id/actions`
Extract action items from a note (Claude-powered). Quota: `aiCalls`.

**Response (200):** `{ "data": Action[] }`

### `POST /notes/:id/checklists`
Extract checklist items from a note (Claude-powered). Quota: `aiCalls`.

**Response (200):** `{ "data": ChecklistItem[] }`

### `POST /notes/:id/autofill?schema=<name>`
Auto-fill a schema from note content (Claude-powered). Quota: `aiCalls`.

**Response (200):** `{ "data": { fields: Record<string, unknown> } }`

### `GET /notes/random?area=<slug>`
Get a random note, optionally filtered by life area.

### `GET /notes/para`
Get notes organized by PARA method (Projects, Areas, Resources, Archives).

---

## Search

### `POST /search`
Hybrid semantic + keyword search. Rate-limited: 10/min.

**Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `query` | string | Yes | Search query (max 500) |
| `source` | enum | No | Filter by source |
| `category` | string | No | Filter by category |
| `format` | enum | No | Filter by format |
| `status` | enum | No | Filter by status |
| `tags` | string[] | No | Filter by tags |
| `dateFrom` | datetime | No | Start date |
| `dateTo` | datetime | No | End date |
| `page` | int | No | Page (default 1) |
| `limit` | int | No | Results per page (1-100) |
| `semanticWeight` | float | No | 0-1, weight for vector search |
| `keywordWeight` | float | No | 0-1, weight for keyword search |

> **Important:** All filter fields are flat (top-level in the body). Do NOT nest them in a `filters` object.

**Response (200):**
```json
{
  "data": [{ "noteId": "uuid", "score": 0.85, "semanticScore": 0.9, "keywordScore": 0.7, "note": Note }],
  "meta": { "page": 1, "limit": 20, "total": 5, "totalPages": 1, "searchDurationMs": 42 }
}
```

---

## Users

### `GET /users/me`
Get current user profile. Cache: none.

**Response (200):** `{ "data": User }`

### `PATCH /users/me`
Update user profile.

**Body:** `{ "name": string?, "email": string? }`

### `GET /users/me/usage`
Get current usage quotas.

**Response (200):** `{ "data": { notesCreated, aiCalls, voiceMinutes, embeddings, periodStart, limits } }`

### `PATCH /users/me/plan`
Sync plan from iOS StoreKit purchase.

**Body:**
```json
{ "plan": "free" | "pro", "originalTransactionId": "string", "productId": "string?" }
```

---

## Sources

### `GET /sources`
List connected sources.

**Response (200):** `{ "data": ConnectedSource[] }`

### `POST /sources/:type/connect`
Connect a new source. Type: `telegram|notion|voice|instagram|reddit|twitter|pocket|email|youtube`.

**Body:** `{ "authToken": string?, "metadata": object? }`

**Response (201):** `{ "data": ConnectedSource }`

**Error (403):** `SOURCE_LIMIT_EXCEEDED` — free plan limit reached (3 sources).

### `DELETE /sources/:id`
Disconnect a source.

### `POST /sources/:id/sync`
Trigger manual sync for a source.

---

## Categories

### `GET /categories`
List all categories. Cache: 5min.

### `POST /categories`
Create a category.

**Body:** `{ "name": string, "slug"?: string, "parentId"?: uuid, "icon"?: string, "color"?: string (max 50 chars), "isDefault"?: boolean, "orderIndex"?: int }`

> **Note:** The field is `color` (free-form string, e.g. `"#FF6B6B"`), NOT `colorHex`.

### `GET /categories/:id`
Get category by ID.

### `PATCH /categories/:id`
Update category.

### `DELETE /categories/:id?reassignTo=<uuid>`
Delete category, optionally reassigning notes.

### `POST /categories/reorder`
Reorder categories.

**Body:** `{ "orderedIds": uuid[] }` (1-500 IDs)

### `GET /categories/suggestions`
Get AI-suggested categories for user's notes.

---

## Collections

### `GET /collections`
List smart collections.

### `GET /collections/:slug/notes?page=&limit=`
Get notes in a smart collection.

### `GET /collections/custom`
List custom collections.

### `POST /collections/custom`
Create a custom collection.

### `DELETE /collections/custom/:id`
Delete a custom collection.

### `GET /collections/custom/:id/notes`
Get notes in a custom collection.

### `POST /collections/generate`
Generate AI-suggested collections.

---

## Sync & Integrations

### Webhooks (no auth)

| Endpoint | Source | Verification |
|----------|--------|-------------|
| `POST /sync/telegram` | Telegram Bot | SHA-256 hash of bot token in `?secret=` |
| `POST /sync/email` | SendGrid Inbound Parse | ECDSA signature (`x-twilio-email-event-webhook-signature`) |
| `POST /sync/app-store` | Apple Server Notifications v2 | JWS x5c chain verification (Apple Root CA G3) |

### OAuth Flows

| Start | Callback | Integration |
|-------|----------|-------------|
| `GET /sync/pocket/auth` (auth) | `POST /sync/pocket/callback` | Pocket |
| — (via Notion web) | `GET /sync/notion/callback` | Notion |
| `POST /sync/google-calendar/connect` (auth) | `GET /sync/google-calendar/callback` | Google Calendar |

### Notion Sync

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/sync/notion/status` | Bidirectional sync status |
| `GET` | `/sync/notion/errors` | Retry queue + dead letter items |
| `GET` | `/sync/notion/mappings` | Get field mappings (custom or defaults) |
| `PUT` | `/sync/notion/mappings` | Update field mappings |
| `POST` | `/sync/notion/mappings/reset` | Reset to default mappings |

### Obsidian Export

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/sync/obsidian/export` | Export single note as Markdown |
| `POST` | `/sync/obsidian/bulk-export` | Export up to 50 notes |
| `GET` | `/sync/obsidian/config` | Get Obsidian vault config |
| `PUT` | `/sync/obsidian/config` | Update Obsidian vault config |

### General Sync

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/sync/status` | Multi-source sync health status |
| `POST` | `/sync/:sourceId/trigger` | Trigger sync for a source |

---

## Review

### `GET /notes/review?status=inbox&limit=10`
Get review queue (notes needing categorization).

### `GET /notes/review/stats`
Review queue statistics.

### `PATCH /notes/batch`
Batch update multiple notes (status, area, tags, approval).

**Body:**
```json
{
  "notes": [
    { "id": "uuid", "area": "health-body", "tags": ["fitness"], "status": "active", "approved": true }
  ]
}
```

> **Note:** There is no `PATCH /notes/:id/review` endpoint. To mark a single note as reviewed, use `PATCH /notes/batch` with a single-element array and `"approved": true`.

---

## Digests

### `GET /digests/latest`
Get the latest AI-generated daily digest.

### `GET /digests?page=&limit=`
List past digests.

### `PATCH /digests/:digestId/actions/:actionId`
Update a digest action item (complete, edit text). `actionId` is a zero-based integer index.

**Body:** `{ "text"?: string, "completed"?: boolean }`

**Response (200):** `{ "data": Digest }` (full serialized digest with updated actions)

> **Note:** There is no `PATCH /notes/:id/actions/:actionId` endpoint. Action items belong to digests, not notes. To update an action, use the digest path.

---

## Weekly Review

### `GET /review/weekly`
Get weekly review data (AI-generated summary of the past week).

### `GET /review/weekly/history?page=&limit=`
Get past weekly reviews (paginated, max 50 per page).

---

## Action Recommendations

### `GET /actions/recommendations`
Get AI-recommended actions based on notes.

### `DELETE /actions/recommendations/:id`
Dismiss a recommendation.

---

## Areas

### `GET /areas/:slug/summary`
Get summary for a life area.

**Slugs:** `health-body`, `mind-focus`, `career-work`, `money-finance`, `relationships-social`, `learning-interests`, `projects-ideas`, `home-life`

---

## Analytics

### `POST /analytics/events`
Record analytics events.

### `GET /analytics/events/count?name=&from=&to=`
Count events by name and date range.

### `GET /analytics/funnel?steps=step1,step2`
Get funnel conversion data.

### `GET /analytics/summary?period=7d|30d`
Get analytics summary.

### `GET /analytics/categories?period=7d|30d|90d`
Category usage analytics.

### `GET /analytics/dashboard?period=7d|30d|90d`
Full analytics dashboard.

### `GET /analytics/wheel-of-life`
Life area balance scores.

---

## Schemas

### `GET /schemas`
List note schemas.

### `POST /schemas`
Create a note schema.

### `PATCH /schemas/:id`
Update a schema.

### `DELETE /schemas/:id`
Delete a schema.

---

## Schema Marketplace

### `POST /schemas/marketplace/publish`
Publish a schema to the marketplace.

### `GET /schemas/marketplace`
Browse marketplace schemas.

### `GET /schemas/marketplace/:id`
Get marketplace schema details.

### `DELETE /schemas/marketplace/:id`
Unpublish a schema.

### `POST /schemas/marketplace/:id/install`
Install a marketplace schema.

### `POST /schemas/marketplace/:id/rate`
Rate a marketplace schema.

### `GET /schemas/marketplace/:id/ratings`
Get ratings for a schema.

---

## Checklists

### `GET /checklists?page=&limit=&noteId=&completed=`
List checklist items.

### `POST /checklists`
Create a checklist item.

### `PATCH /checklists/:id`
Update a checklist item.

### `DELETE /checklists/:id`
Delete a checklist item.

### `POST /checklists/reorder`
Reorder checklist items.

### `GET /checklists/stats`
Checklist completion statistics.

### Export & Sync

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/checklists/:id/export/reminders` | Export to Apple Reminders format |
| `POST` | `/checklists/:id/export/calendar` | Export to calendar format |
| `POST` | `/checklists/:id/sync/google-calendar` | Sync to Google Calendar |
| `POST` | `/checklists/:id/sync/notion` | Sync to Notion |
| `POST` | `/checklists/export/reminders` | Batch export to Reminders |
| `POST` | `/checklists/sync/notion` | Batch sync to Notion |

---

## Notifications

### `GET /notifications/preferences`
Get notification preferences.

### `PUT /notifications/preferences`
Update notification preferences.

### `GET /notifications/scheduled`
Get scheduled notifications.

---

## Privacy

### `GET /settings/privacy`
Get privacy settings.

### `PUT /settings/privacy`
Update privacy settings.

### `PUT /privacy/categories/:id/privacy`
Set category privacy. Body: `{ "isPrivate": boolean }`

### `GET /privacy/categories/private`
List private categories.

### `POST /privacy/session`
Start a privacy session (returns session token for `X-Privacy-Session` header).

---

## Export

### `POST /notes/export`
Export notes in various formats (JSON, CSV, Markdown).

---

## Import

### `POST /import/:id`
Start import from a source.

### `GET /import`
List imports.

### `GET /import/:id/status`
Get import progress.

---

## Jobs

### `GET /jobs/:id`
Get background job status.

### `GET /jobs/imports/:id/progress`
Get import job progress.

### `GET /jobs/imports/:id/stream`
Stream import progress (SSE).

---

## Admin

All admin routes require the `requireAdmin` middleware (checks `ADMIN_EMAILS` env var).

### `GET /admin/dlq?queue=&page=&limit=`
Get dead letter queue items.

### `POST /admin/dlq/:queue/:jobId/retry`
Retry a failed job.

### `DELETE /admin/dlq/:queue/:jobId`
Remove a failed job.

### `POST /admin/dlq/retry-all?queue=`
Retry all failed jobs in a queue.

### `GET /admin/stats`
Get system statistics.

---

## Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| `VALIDATION_ERROR` | 400 | Invalid input (Zod validation failed) |
| `UNAUTHORIZED` | 401 | Missing/invalid/expired JWT |
| `FORBIDDEN` | 403 | Access denied |
| `SOURCE_LIMIT_EXCEEDED` | 403 | Free plan source limit (3) reached |
| `NOT_FOUND` | 404 | Resource not found |
| `UNIQUE_CONSTRAINT` | 409 | Duplicate record |
| `ALREADY_QUEUED` | 409 | Sync job already in progress |
| `RATE_LIMIT` | 429 | IP rate limit exceeded |
| `RATE_LIMIT_EXCEEDED` | 429 | Per-user rate limit exceeded |
| `QUOTA_EXCEEDED` | 429 | Monthly usage quota exceeded |
| `EXTERNAL_SERVICE_ERROR` | 502 | AI/external service failure |
| `INTERNAL_ERROR` | 500 | Unexpected server error |
| `NOT_CONFIGURED` | 503 | Integration not configured |

---

## Enums Reference

**Source types:** `telegram`, `notion`, `voice`, `instagram`, `reddit`, `twitter`, `pocket`, `email`, `youtube`

**Content types:** `text`, `audio`, `video`, `image`, `link`

**Note formats:** `article`, `bookmark`, `snippet`, `voice-memo`, `screenshot`, `photo`, `video`, `document`, `thread`, `highlight`

**Note statuses:** `inbox`, `active`, `reference`, `archived`

**Life areas:** `health-body`, `mind-focus`, `career-work`, `money-finance`, `relationships-social`, `learning-interests`, `projects-ideas`, `home-life`
