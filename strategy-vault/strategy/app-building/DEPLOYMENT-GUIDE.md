# Deployment Guide — Node.js Backend on Railway

> A complete production deployment runbook for a Node.js/TypeScript backend.
> Replace `[Your App]` and service names with your specifics.

---

## Prerequisites

- Railway account with a project created
- Railway CLI: `npm i -g @railway/cli && railway login`
- Database provisioned (Supabase PostgreSQL + Auth, or Railway Postgres plugin)
- Redis instance (Railway plugin or Upstash)
- File storage ready (AWS S3 or Supabase Storage)
- AI API keys if using LLMs

---

## First-Time Setup

### 1. Link the Railway Project

```bash
cd backend
railway link
```

Select your Railway project and environment (e.g. `production`).

### 2. Add Redis Plugin

In the Railway dashboard → Add Plugin → Redis. The `REDIS_URL` will be injected automatically as a shared variable.

### 3. Configure Build Settings

| Setting | Value |
|---------|-------|
| Build Command | `npm run build` |
| Start Command | `npm run start` |
| Root Directory | `backend` (or `.` if mono-root) |
| Node Version | 20.x (or latest LTS) |

Railway runs `npm install` automatically before build. Prisma Client generates during `postinstall` if configured.

### 4. Set Environment Variables

Via Railway dashboard (Settings → Variables) or CLI:

```bash
railway variables set KEY=value
```

See [Environment Variables](#environment-variables) below.

### 5. Run Initial Database Migration

```bash
railway run npm run migrate:deploy
```

This runs `prisma migrate deploy` via the direct DB connection (required — not pgbouncer).

### 6. Apply Performance Indexes (if applicable)

```bash
railway run npx prisma db execute --file prisma/performance-indexes.sql --schema prisma/schema.prisma
```

Use `CREATE INDEX CONCURRENTLY` in the SQL file — avoids table locks.

### 7. First Deploy

```bash
railway up
```

---

## Environment Variables

### Required (app won't start without these)

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL via pgbouncer (app queries) | `postgresql://...?pgbouncer=true` |
| `DIRECT_URL` | PostgreSQL direct (migrations only) | `postgresql://...:5432/...` |
| `NODE_ENV` | `production` | — |
| `REDIS_URL` | From Railway plugin | `redis://...` |
| `[AUTH_PROVIDER]_JWT_SECRET` | JWT verification secret | from auth provider |
| `[AI_PROVIDER]_API_KEY` | LLM API key | `sk-...` |

### Database Connection Strings (Supabase)

| Variable | Port | Purpose |
|----------|------|---------|
| `DATABASE_URL` | 6543 | App queries — goes through pgbouncer (connection pooling) |
| `DIRECT_URL` | 5432 | Prisma migrations — must bypass pgbouncer |

**Why two strings?** pgbouncer multiplexes connections (essential at load) but can't run migrations (uses advisory locks). Always use `DIRECT_URL` for migrations.

### Optional (have defaults or only enable specific features)

| Variable | Default | Enables |
|----------|---------|---------|
| `PORT` | `3000` | Railway sets automatically |
| `LOG_LEVEL` | `info` | `debug` for verbose logs |
| `SENTRY_DSN` | blank | Error tracking |
| `ALLOWED_ORIGINS` | blank | CORS domains |
| `[INTEGRATION]_CLIENT_ID` | blank | OAuth integrations |
| `[INTEGRATION]_CLIENT_SECRET` | blank | OAuth integrations |

---

## Database Setup

### With Supabase

```prisma
datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
  directUrl  = env("DIRECT_URL")
  extensions = [vector]  // if using pgvector
}
```

### Running Migrations

```bash
# Apply all pending migrations (production — safe)
railway run npm run migrate:deploy

# Check migration status
railway run npx prisma migrate status
```

**Never** run `prisma migrate dev` against production. It can reset data.

---

## Deploy

### Standard Deploy

```bash
railway up
```

Railway: install deps → generate Prisma Client → compile TypeScript → start server.

### Deploy with Schema Changes

```bash
# 1. Migrate first (additive changes are safe to do before code deploy)
railway run npm run migrate:deploy

# 2. Then deploy code
railway up
```

**Rule:** Always make migrations backward-compatible. Add nullable columns. Remove columns only after code stops using them.

### CI/CD (GitHub Auto-Deploy)

In Railway: connect GitHub repo → set branch to `main` → enable auto-deploy. Railway rebuilds on every push.

---

## Post-Deploy Verification

### 1. Health Check

```bash
curl https://your-app.railway.app/health
```

Expected (200):
```json
{ "status": "ok", "timestamp": "...", "uptime": 5.1, "checks": { "database": true } }
```

`database: false` → check `DATABASE_URL`.

### 2. Check Logs

In Railway dashboard → Logs. Look for:

```
{"level":"info","msg":"API running","port":3000}
{"level":"info","msg":"All workers started"}
```

### 3. Verify Background Workers

Create a test item via the API, confirm worker completion in logs:
```
{"level":"info","queue":"ai-processing","msg":"Job completed"}
```

---

## Background Workers

Workers run in the same process as the API server (for MVP). Started via `startWorkers()` in `src/index.ts`.

| Worker | Queue | Concurrency | Purpose |
|--------|-------|-------------|---------|
| AI Processor | `ai-processing` | 2 | Summarize/categorize via LLM |
| Embedding Worker | `embedding-generation` | 5 | Generate vector embeddings |
| Sync Worker | `source-sync` | 2 | Sync from external sources |

**Failed jobs:** Retry with exponential backoff → move to failed set after max attempts. Inspect via BullMQ `getJobs('failed')` or Bull Board UI.

**Graceful shutdown:** On `SIGTERM` (Railway sends on redeploy), workers finish current jobs then close cleanly.

---

## Monitoring

### Sentry (Error Tracking)

Set `SENTRY_DSN` to enable. Captures:
- Unhandled rejections and exceptions
- Express errors (auto-routed)
- Tags events with `userId` when auth context available

```
tracesSampleRate: 0.1  // production — sample 10%
```

### Structured Logging (pino)

All logs are JSON. Key fields: `level`, `msg`, `method`, `path`, `statusCode`, `durationMs`, `userId`.

In production: `LOG_LEVEL=info`. Set `debug` temporarily for deep investigation.

### Rate Limiting

| Layer | Limit | Response |
|-------|-------|---------|
| Global (IP) | 100 req/min | 429 + `RATE_LIMIT` |
| Per-user | 120 req/min | 429 + `RATE_LIMIT_EXCEEDED` |
| Expensive ops (AI/search) | 10 req/min | 429 + `RATE_LIMIT_EXCEEDED` |

---

## Scaling

### Vertical (MVP)
- 512 MB RAM → comfortable for low traffic
- 1 GB RAM → needed when source syncs and AI processing run concurrently

### Horizontal (when needed)
1. Separate API server and workers into two Railway services
2. Both connect to same Redis + PostgreSQL
3. Scale API replicas independently from workers
4. Add health check for Railway's load balancer

### Database Connection Limits
- Supabase free: ~20 direct connections
- pgbouncer multiplexes — always use port 6543 for `DATABASE_URL`
- Reduce Prisma pool if needed: add `&connection_limit=5` to `DATABASE_URL`

---

## Rollback

### Via Railway Dashboard
Services → Deployments → three-dot menu → Rollback on last good deploy.

### Via CLI
```bash
railway deployments          # list recent
railway redeploy <deploy-id> # redeploy specific version
```

### Database Rollback
- Additive migration (new column/table) → old code ignores it, no rollback needed
- Destructive migration (dropped column) → write a new migration to restore it
- Failed migration: `railway run npx prisma migrate resolve --rolled-back <migration-name>`

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Server won't start: "Missing required env var" | Check which var; set in Railway → Variables |
| Health check 503 (database: false) | `DATABASE_URL` wrong, Supabase down, or connection pool exhausted |
| Workers not processing jobs | `REDIS_URL` set? Redis has memory? Logs show workers started? |
| Migration fails "prepared statement exists" | Using pgbouncer for migration — use `DIRECT_URL` (port 5432) |
| High memory usage | BullMQ failed jobs accumulating? Fix root cause, then `queue.clean(0, 'failed')` |
| Rate limiting legitimate traffic | Raise limits in middleware config |
| Sentry not receiving events | `SENTRY_DSN` set? `NODE_ENV=production`? |

---

*This guide covers Railway deployments. For Fly.io: same patterns, `fly deploy` instead of `railway up`.*
