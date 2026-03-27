# API Design Guide — REST API Best Practices

> Patterns and conventions for building clean, consistent REST APIs.
> Extracted from real production backend design. Adapt for your app.

---

## Conventions

### Base URL
```
https://<host>:<port>
# Default dev: http://localhost:3000
```

### Auth
- All protected routes: `Authorization: Bearer <jwt-token>`
- JWT issued by your auth provider (Supabase, Clerk, custom)
- Non-auth routes: `/health`, public listing endpoints

### Response Format
```typescript
// Single item
{ "data": T }

// Collection
{ "data": T[], "meta": { page, limit, total, totalPages } }

// Error
{ "error": { "code": string, "message": string } }
```

**Consistency rule:** Always return `data` key — never a bare object or array.

---

## Standard Headers

| Header | Direction | Description |
|--------|-----------|-------------|
| `Authorization` | Request | `Bearer <token>` — required on protected routes |
| `X-API-Version` | Response | API version (e.g. `1.0`) |
| `X-RateLimit-Limit` | Response | Max requests allowed in window |
| `X-RateLimit-Remaining` | Response | Requests remaining |
| `X-RateLimit-Reset` | Response | Window reset timestamp |

---

## Rate Limiting

- **Global (IP-based):** 100 req/min
- **Per-user (authenticated):** 120 req/min
- **Expensive ops (AI, search):** 10 req/min
- Exceed → `429 RATE_LIMIT_EXCEEDED`

Implementation: Redis sliding window via BullMQ or `rate-limiter-flexible`.

---

## CRUD Endpoints Pattern

```
GET    /resource         List (paginated, filterable)
POST   /resource         Create
GET    /resource/:id     Get single
PATCH  /resource/:id     Partial update (prefer PATCH over PUT)
DELETE /resource/:id     Delete
```

### Pagination (always use)
```
GET /resource?page=1&limit=20
```
Response meta:
```json
{ "page": 1, "limit": 20, "total": 100, "totalPages": 5 }
```

### Filtering (flat query params)
```
GET /resource?status=active&category=finance&from=2026-01-01
```
Keep filter params flat — don't nest in a `filters` object. Frontend devs will thank you.

---

## Search Endpoint

```
POST /search
```

Use POST (not GET) when search has complex filters or body >255 chars.

```typescript
// Request body
{
  query: string,        // required
  filters?: {           // or flat params — pick one
    status?: string,
    category?: string,
    // ...
  },
  page?: number,
  limit?: number
}

// Response
{
  data: [{ id, score, ...item }],
  meta: { page, limit, total, totalPages, searchDurationMs }
}
```

---

## Health Check

```
GET /health
```

No auth required. Used by load balancers and uptime monitors.

```json
{ "status": "ok", "timestamp": "...", "uptime": 3600, "checks": { "database": true } }
```

---

## Nested Resources

Keep max 2 levels deep:

```
GET  /users/:id/items          ✅ Good
GET  /users/:id/items/:itemId  ✅ Good
GET  /users/:id/items/:itemId/sub-items/:subId  ❌ Too deep — flatten
```

---

## Batch Operations

For bulk updates, prefer a dedicated batch endpoint:

```
PATCH /resource/batch
```

```json
{
  "items": [
    { "id": "uuid", "status": "active" },
    { "id": "uuid", "status": "archived" }
  ]
}
```

Don't require N separate API calls for N items. Batch limits: 50–500 items.

---

## Background Jobs

For long-running ops (AI processing, imports, sync):

```
POST /resource/:id/[action]   → Returns immediately with job ID
GET  /jobs/:id                → Poll job status
GET  /jobs/:id/stream         → SSE stream for real-time progress
```

Response from trigger:
```json
{ "data": { "jobId": "uuid", "status": "queued" } }
```

---

## Webhooks (Incoming)

For third-party webhooks:

```
POST /sync/[service]
```

- No user auth — webhook secret verification instead
- Verify signature in header (HMAC SHA-256 or ECDSA)
- Return `200` quickly, process async via job queue
- Log all incoming payloads for debugging

---

## Error Codes

Define a consistent error code vocabulary:

| Code | HTTP | When |
|------|------|------|
| `VALIDATION_ERROR` | 400 | Invalid input (Zod/Joi failed) |
| `UNAUTHORIZED` | 401 | Missing/expired token |
| `FORBIDDEN` | 403 | Valid token, wrong permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `UNIQUE_CONSTRAINT` | 409 | Duplicate record |
| `ALREADY_QUEUED` | 409 | Job already running |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `QUOTA_EXCEEDED` | 429 | Monthly usage quota hit |
| `EXTERNAL_SERVICE_ERROR` | 502 | AI/3rd party failure |
| `INTERNAL_ERROR` | 500 | Unexpected server error |

**Rule:** Use specific codes, not just HTTP status. Frontend needs to differentiate.

---

## Validation

Use Zod (TypeScript) or Joi/yup for all request validation:

```typescript
const createItemSchema = z.object({
  body: z.string().min(1).max(50000),
  title: z.string().max(500).optional(),
  tags: z.array(z.string()).max(20).optional(),
});
```

Validate at the route/middleware layer, before any business logic.

---

## Versioning

For MVP: no versioning needed. Just `/api/...`.

When you need versioning:
- URL-based: `/v2/resource` (simple, discoverable)
- Header-based: `X-API-Version: 2` (cleaner URLs but harder to test)

Add `X-API-Version` response header from day one.

---

## Security Checklist

- [ ] All routes require auth except explicitly public ones
- [ ] User data filtered by `userId` in every query (row-level isolation)
- [ ] Rate limiting on all endpoints
- [ ] Webhook signatures verified
- [ ] No secrets in responses (no passwords, tokens, full keys)
- [ ] SQL injection impossible (parameterized queries via ORM)
- [ ] HTTPS only in production

---

## Testing

Use Postman or Insomnia for manual testing. For automated:

```typescript
// Jest + supertest example
it('GET /notes returns paginated notes', async () => {
  const res = await request(app)
    .get('/notes')
    .set('Authorization', `Bearer ${testToken}`);
  
  expect(res.status).toBe(200);
  expect(res.body.data).toBeInstanceOf(Array);
  expect(res.body.meta).toHaveProperty('total');
});
```

Test: happy path, auth failure, validation failure, not found, rate limit.

---

## Documentation

Auto-generate API docs from code where possible:
- **OpenAPI/Swagger:** `@fastify/swagger`, `swagger-jsdoc`
- **Hono:** Built-in OpenAPI support
- **Postman:** Export collection for team sharing

Write a minimal API reference doc (like this one) for agent/LLM context.

---

*Good APIs are boring. Consistent naming, predictable responses, clear errors.*
