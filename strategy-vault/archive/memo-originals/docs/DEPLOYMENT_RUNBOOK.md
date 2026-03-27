# Deployment Runbook -- Memo Backend on Railway

Last updated: 2026-03-15

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [First-Time Setup](#first-time-setup)
3. [Environment Variables](#environment-variables)
4. [Database Setup](#database-setup)
5. [Redis Setup](#redis-setup)
6. [Deploy](#deploy)
7. [Post-Deploy Verification](#post-deploy-verification)
8. [Background Workers](#background-workers)
9. [Monitoring and Observability](#monitoring-and-observability)
10. [Scaling](#scaling)
11. [Rollback](#rollback)
12. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Railway account with a project created
- Railway CLI installed: `npm i -g @railway/cli && railway login`
- Supabase project provisioned (PostgreSQL + Auth)
- Redis instance (Railway plugin or external)
- AWS S3 bucket created for file storage
- Anthropic and Voyage AI API keys

---

## First-Time Setup

### 1. Link the Railway project

```bash
cd backend
railway link
```

Select or create your Railway project and environment (e.g., `production`).

### 2. Add a Redis plugin

In the Railway dashboard, add a **Redis** plugin to your project. Copy the `REDIS_URL` from the plugin's connect panel -- it will look like `redis://default:password@host:port`.

### 3. Configure build settings

Railway auto-detects Node.js via `package.json`. Verify in your service settings:

| Setting        | Value                 |
|----------------|-----------------------|
| Build Command  | `npm run build`       |
| Start Command  | `npm run start`       |
| Root Directory | `backend`             |
| Node Version   | 20.x (or latest LTS)  |

Railway runs `npm install` automatically before the build command. Prisma Client is generated during `postinstall` via `prisma generate`.

### 4. Set environment variables

See the full list in the [Environment Variables](#environment-variables) section. Set them via the Railway dashboard (Settings > Variables) or CLI:

```bash
railway variables set KEY=value
```

### 5. Run initial database migration

```bash
railway run npm run migrate:deploy
```

This executes `prisma migrate deploy` against the production database using `DIRECT_URL` (direct connection, not pgbouncer -- required for migrations).

### 6. Apply performance indexes

After the initial migration completes:

```bash
railway run npx prisma db execute --file prisma/performance-indexes.sql --schema prisma/schema.prisma
```

Or run the SQL manually via the Supabase SQL Editor by pasting the contents of `prisma/performance-indexes.sql`. This creates composite indexes for:

- `note_user_captured_at_idx` -- primary note list queries
- `note_user_source_idx` -- source-filtered queries
- `note_user_imported_at_idx` -- PARA view queries
- `note_user_format_idx` -- format-filtered queries
- `analytics_user_timestamp_idx` -- analytics summaries
- `note_user_category_active_idx` -- active notes by category (partial index)

All use `CREATE INDEX CONCURRENTLY` so they won't lock tables.

### 7. Deploy

```bash
railway up
```

---

## Environment Variables

### Required (server will not start without these)

| Variable                   | Description                                          | Example                                                                                        |
|----------------------------|------------------------------------------------------|------------------------------------------------------------------------------------------------|
| `DATABASE_URL`             | Supabase PostgreSQL via pgbouncer                     | `postgresql://postgres.xxx:pw@pooler.supabase.com:6543/postgres?pgbouncer=true`                |
| `DIRECT_URL`               | Supabase PostgreSQL direct (used by Prisma migrations)| `postgresql://postgres.xxx:pw@db.supabase.com:5432/postgres`                                   |
| `SUPABASE_URL`             | Supabase project URL                                 | `https://abcdefgh.supabase.co`                                                                 |
| `SUPABASE_ANON_KEY`        | Supabase anon/public key                             | `eyJ...`                                                                                       |
| `SUPABASE_SERVICE_ROLE_KEY`| Supabase service role key (server-side only)          | `eyJ...`                                                                                       |
| `SUPABASE_JWT_SECRET`      | JWT secret for token verification                    | from Supabase dashboard > Settings > API                                                        |
| `ANTHROPIC_API_KEY`        | Claude API key for AI categorization                 | `sk-ant-...`                                                                                   |
| `VOYAGE_API_KEY`           | Voyage AI key for embeddings                         | `pa-...`                                                                                       |

### Required for production

| Variable          | Value        | Notes                                    |
|-------------------|--------------|------------------------------------------|
| `NODE_ENV`        | `production` | Enables production logging, Sentry rates |
| `REDIS_URL`       | from plugin  | Railway Redis plugin provides this       |
| `ALLOWED_ORIGINS` | your domains | Comma-separated, e.g. `https://memo.app` |

### Optional (have defaults or can be left blank)

| Variable                            | Default                                        | Notes                                     |
|-------------------------------------|------------------------------------------------|-------------------------------------------|
| `PORT`                              | `3000`                                         | Railway sets this automatically            |
| `LOG_LEVEL`                         | `info` (production), `debug` (development)     | pino log level                             |
| `SENTRY_DSN`                        | blank (disabled)                               | Set to enable error tracking               |
| `ASSEMBLYAI_API_KEY`                | blank                                          | Required for voice transcription           |
| `TELEGRAM_BOT_TOKEN`               | blank                                          | Required for Telegram integration          |
| `NOTION_CLIENT_ID`                  | blank                                          | Required for Notion OAuth                  |
| `NOTION_CLIENT_SECRET`              | blank                                          | Required for Notion OAuth                  |
| `NOTION_REDIRECT_URI`              | `http://localhost:3000/sources/notion/callback` | Set to production callback URL             |
| `POCKET_CONSUMER_KEY`              | blank                                          | Required for Pocket integration            |
| `SENDGRID_API_KEY`                  | blank                                          | Required for email forwarding              |
| `EMAIL_INGEST_DOMAIN`              | `memo-ingest.example.com`                      | Domain for inbound email parsing           |
| `SENDGRID_WEBHOOK_VERIFICATION_KEY`| blank                                          | ECDSA key for webhook verification         |
| `GOOGLE_CLIENT_ID`                  | blank                                          | Required for Google Calendar               |
| `GOOGLE_CLIENT_SECRET`              | blank                                          | Required for Google Calendar               |
| `GOOGLE_REDIRECT_URI`              | `http://localhost:3000/sync/google-calendar/callback` | Set to production callback URL      |
| `APP_STORE_SHARED_SECRET`          | blank                                          | For App Store server notifications         |
| `AWS_ACCESS_KEY_ID`                | blank                                          | Required for S3 file storage               |
| `AWS_SECRET_ACCESS_KEY`            | blank                                          | Required for S3 file storage               |
| `AWS_S3_BUCKET`                    | `memo-uploads`                                 | S3 bucket name                             |
| `AWS_REGION`                        | `us-east-1`                                    | AWS region                                 |

---

## Database Setup

### Supabase PostgreSQL with pgvector

The database is hosted on Supabase. The Prisma schema enables the `vector` extension:

```prisma
datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
  directUrl  = env("DIRECT_URL")
  extensions = [vector]
}
```

**Two connection strings are required:**

| Variable       | Port | Purpose                              | Pooling    |
|----------------|------|--------------------------------------|------------|
| `DATABASE_URL` | 6543 | Application queries (Prisma Client)  | pgbouncer  |
| `DIRECT_URL`   | 5432 | Migrations and introspection (Prisma CLI) | Direct |

pgbouncer is required for production because it pools connections, preventing exhaustion under load. However, Prisma migrations require a direct connection (they use advisory locks and temp tables that pgbouncer doesn't support).

### Running migrations

```bash
# Production: apply all pending migrations
railway run npm run migrate:deploy

# Check migration status
railway run npx prisma migrate status
```

Never run `prisma migrate dev` against production. That command is for local development only (it can reset data). Always use `migrate deploy`.

### Enabling pgvector

pgvector is pre-installed on Supabase. If for some reason the extension is missing:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

---

## Redis Setup

### Railway Redis plugin

Add the Redis plugin from the Railway dashboard. It provisions a Redis instance and injects `REDIS_URL` into your service automatically if you reference it as a shared variable.

### BullMQ queues

The backend creates these queues on startup:

| Queue                        | Retry Delay | Max Attempts | Completed Retention | Failed Retention      |
|------------------------------|-------------|--------------|---------------------|-----------------------|
| `ai-processing`             | 5s exponential  | 3        | 1000 jobs           | 1000 jobs / 7 days    |
| `source-sync`               | 10s exponential | 3        | 500 jobs            | 1000 jobs / 7 days    |
| `embedding-generation`      | 3s exponential  | 3        | 1000 jobs           | 1000 jobs / 7 days    |
| `notion-bidirectional-sync` | 30s exponential | 2        | 200 jobs            | 1000 jobs / 7 days    |
| `digest`                    | (per digestWorker) | --    | --                  | --                    |
| `notifications`             | (per notificationScheduler) | -- | --           | --                    |

Queues are created lazily on first use. No manual queue creation is needed.

### Redis memory

For MVP scale, 25-50 MB of Redis memory is sufficient. Monitor with `INFO memory` if you suspect issues. BullMQ's job retention settings (above) keep memory bounded.

---

## Deploy

### Standard deployment

```bash
cd backend
railway up
```

Railway will:
1. Install dependencies (`npm install`)
2. Generate Prisma Client (`prisma generate` via postinstall)
3. Compile TypeScript (`npm run build` -> `tsc`)
4. Start the server (`npm run start` -> `node dist/index.js`)

### Deploying with migrations

If the deploy includes schema changes, run migrations before deploying new code:

```bash
# 1. Apply migrations first
railway run npm run migrate:deploy

# 2. Deploy the new code
railway up
```

For additive changes (new columns with defaults, new tables, new indexes) the order is less critical -- migrate first is always safest. For destructive changes (dropping columns, renaming), you must coordinate: deploy code that stops using the column, then migrate to drop it.

### CI/CD (GitHub integration)

In Railway dashboard, connect the GitHub repo and set:
- **Branch:** `main`
- **Root Directory:** `backend`
- **Auto-deploy:** On push to main

Railway will build and deploy automatically on every push.

---

## Post-Deploy Verification

### 1. Health check

```bash
curl https://your-app.railway.app/health
```

Expected response (200):
```json
{
  "status": "ok",
  "timestamp": "2026-03-15T12:00:00.000Z",
  "uptime": 5.123,
  "checks": {
    "database": true
  }
}
```

If `status` is `"degraded"` and `database` is `false`, the database connection is failing. Check `DATABASE_URL`.

### 2. API info

```bash
curl https://your-app.railway.app/
```

Expected response (200):
```json
{
  "name": "Memo API",
  "version": "1.0.0",
  "status": "running"
}
```

### 3. Check logs

In Railway dashboard, open the service logs. Look for:

```
{"level":"info","msg":"Memo API running","port":3000}
{"level":"info","msg":"All workers started"}
{"level":"info","msg":"Sentry initialized"}
```

If Sentry is not configured, the "Sentry initialized" line will be absent (this is fine).

### 4. Verify workers are processing

Create a test note via the API and confirm the logs show:
```
{"level":"info","queue":"ai-processing","msg":"Job completed"}
{"level":"info","queue":"embedding-generation","msg":"Job completed"}
```

---

## Background Workers

All workers run in the same process as the Express server. They start automatically via `startWorkers()` in `src/index.ts`.

| Worker               | Queue                        | Concurrency | Purpose                                        |
|----------------------|------------------------------|-------------|-------------------------------------------------|
| aiProcessor          | `ai-processing`              | 2           | Summarize, tag, categorize notes via Claude      |
| embeddingWorker      | `embedding-generation`       | 5           | Generate Voyage AI vector embeddings             |
| syncWorker           | `source-sync`                | 2           | Sync content from connected sources              |
| digestWorker         | `digest`                     | 1           | Generate daily/weekly digest summaries           |
| notionSyncWorker     | `notion-bidirectional-sync`  | 1           | Bidirectional Notion sync (rate-limit sensitive) |
| notificationWorker   | `notifications`              | 2           | Send push notifications                          |

### Worker failure behavior

- Failed jobs are retried with exponential backoff (see queue table above)
- After all retries are exhausted, the job moves to the failed set with a log entry: `"Job permanently failed (all retries exhausted)"`
- Failed jobs are retained (up to 1000 per queue, 7 days max) for debugging
- Use BullMQ's `getJobs('failed')` or a Bull Board UI to inspect and retry failed jobs

### Graceful shutdown

On `SIGTERM` or `SIGINT` (Railway sends `SIGTERM` on redeploy):

1. HTTP server stops accepting new connections
2. Sentry flushes pending events
3. All BullMQ workers close (finish current job, then stop)
4. All queue connections close
5. Process exits with code 0

Railway allows 10 seconds for graceful shutdown by default. The app's shutdown sequence is fast enough for this window.

---

## Monitoring and Observability

### Sentry

Set `SENTRY_DSN` to enable error tracking. Configuration:

| Setting              | Production Value |
|----------------------|------------------|
| `tracesSampleRate`   | 0.1 (10%)       |
| `environment`        | `production`     |

Sentry captures:
- All unhandled promise rejections (`unhandledRejection`)
- All uncaught exceptions (`uncaughtException`)
- Auth middleware tags events with `userId` and `email`
- Express error handler forwards errors to Sentry

### Structured logging (pino)

All logs are JSON-structured via pino. Key fields:

| Field        | Description                      |
|--------------|----------------------------------|
| `level`      | `info`, `warn`, `error`, `debug` |
| `msg`        | Human-readable message           |
| `method`     | HTTP method                      |
| `path`       | Request path                     |
| `statusCode` | Response status code             |
| `durationMs` | Request duration                 |
| `userId`     | Authenticated user ID            |
| `queue`      | BullMQ queue name (worker logs)  |
| `jobId`      | BullMQ job ID (worker logs)      |

In production, `LOG_LEVEL` defaults to `info`. Set to `debug` temporarily for deeper investigation.

### Railway metrics

Railway provides built-in metrics for:
- CPU and memory usage
- Network I/O
- Deployment history and logs

Monitor these in the Railway dashboard under your service.

### Rate limiting

Two layers of rate limiting are active:

| Layer            | Limit            | Scope      |
|------------------|------------------|------------|
| Global (IP)      | 100 req/min      | Per IP     |
| Per-user         | 120 req/min      | Per user   |

Rate-limited requests receive a `429` with:
```json
{ "error": { "code": "RATE_LIMIT", "message": "Too many requests, try again later" } }
```

---

## Scaling

### Vertical scaling

Railway allows you to adjust CPU and memory for your service. For MVP:
- **1 vCPU / 512 MB RAM** is sufficient for low traffic
- **2 vCPU / 1 GB RAM** when you have active users with source syncs

### Horizontal scaling (future)

The current architecture runs workers in-process with the API server. To scale horizontally:

1. Separate the API server and workers into two Railway services
2. Both connect to the same Redis and PostgreSQL
3. Scale API replicas independently from worker replicas
4. Add a health check endpoint for Railway's load balancer

This separation is not needed for MVP but is the path forward if worker load impacts API latency.

### Database connection limits

Supabase free tier allows ~20 direct connections. pgbouncer (port 6543) multiplexes these. If you hit connection limits:
- Verify `DATABASE_URL` uses `?pgbouncer=true`
- Reduce Prisma connection pool size via `DATABASE_URL` query param: `&connection_limit=5`
- Upgrade Supabase plan for higher limits

---

## Rollback

### Rolling back a deployment

Railway supports instant rollback via the dashboard:

1. Go to your service in Railway
2. Click **Deployments**
3. Find the last known good deployment
4. Click the three-dot menu and select **Rollback**

This redeploys the previous build image immediately.

### Rolling back via CLI

```bash
# List recent deployments
railway deployments

# Redeploy a specific deployment ID
railway redeploy <deployment-id>
```

### Rolling back a database migration

If a migration fails partway:

```bash
# Mark the failed migration as rolled back
railway run npx prisma migrate resolve --rolled-back <migration-name>
```

If a migration succeeded but the code change is being rolled back:
- If the migration was additive (new table, new column), the old code will simply ignore the new schema -- no database rollback needed
- If the migration was destructive (dropped column the old code needs), you must write a new migration to restore it

**Rule of thumb:** Always make migrations backward-compatible. Add new columns as nullable or with defaults. Remove columns only after the code no longer references them.

---

## Troubleshooting

### Server won't start: "Missing required env var"

The `requireEnv()` function in `src/config.ts` throws on startup if any required variable is missing. Check which variable the error names and set it in Railway.

Required variables that use `requireEnv`:
- `DATABASE_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`
- `ANTHROPIC_API_KEY`
- `VOYAGE_API_KEY`

### Health check returns 503 (degraded)

The `/health` endpoint runs `SELECT 1` against the database. A 503 means:
- `DATABASE_URL` is wrong or unreachable
- Supabase is down (check status.supabase.com)
- Connection pool is exhausted (check pgbouncer settings)

### Workers not processing jobs

Check that:
1. `REDIS_URL` is set and reachable
2. Logs show `"All workers started"` on boot
3. Redis has available memory (`INFO memory` via Redis CLI)
4. Jobs are being enqueued (check queue counts)

### Migration fails with "prepared statement already exists"

This happens when running migrations through pgbouncer. Ensure `DIRECT_URL` (port 5432, no pgbouncer) is set and that Prisma uses it for migrations. The `directUrl` field in `schema.prisma` handles this automatically.

### CORS errors from the iOS app

Verify `ALLOWED_ORIGINS` includes the origin your app sends. For iOS apps making requests, this is typically not needed (CORS is browser-only), but if you have a web client, set the exact origin.

### Rate limiting in production

If legitimate traffic is hitting rate limits:
- Global: 100 req/min/IP -- increase in `src/index.ts` if needed
- Per-user: 120 req/min -- increase in auth middleware if needed
- Both use sliding window counters via `express-rate-limit`

### High memory usage

Check if BullMQ failed jobs are accumulating. The retention policy (1000 jobs, 7 days) should prevent this, but if many jobs are failing:
1. Check worker error logs
2. Fix the root cause (API key expired, service down)
3. Clear failed jobs if needed: `queue.clean(0, 'failed')`

### Sentry not receiving events

- Verify `SENTRY_DSN` is set correctly
- Check that `NODE_ENV=production` (traces sample rate is 0.1 in production, 1.0 in development)
- Sentry flushes on shutdown; if the process crashes hard, some events may be lost
