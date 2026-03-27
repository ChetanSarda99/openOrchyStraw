# Memo — Codex Instructions

## Your Role
You are assigned to **research and code review** tasks only. You run as part of a multi-agent orchestrator where different models handle different responsibilities.

## Project Overview
Memo — ADHD-first universal note aggregator iOS app. Pulls saved content from Telegram, Notion, Instagram, Reddit, Twitter, voice memos into one searchable place.

**Private repo** — iOS app + Node.js backend + landing page.

## What You Do
- **05-QA:** Test coverage, code review, quality gates, regression checks
- **Research tasks:** Competitive analysis, App Store research, ADHD product patterns

## What You Don't Do
- Don't build features (Claude handles iOS + backend)
- Don't design UI (Gemini handles design system)
- Don't modify prompts/ or scripts/ (PM-only territory)

## Tech Stack (Read-Only Reference)
- **iOS:** Swift + SwiftUI, iOS 17+, @Observable, SwiftData, Supabase Swift SDK
- **Backend:** Node.js + TypeScript, Hono, Supabase, Prisma, OpenAI
- **Landing:** Astro 5 + React + Tailwind + shadcn/ui
- **Infra:** Supabase (auth, DB, storage), Vercel (landing), Railway (backend)

## File Ownership
Respect `scripts/agents.conf` boundaries. Don't write outside your assigned paths.

## Code Style
- Read CLAUDE.md for full style rules — they apply to you too
- Swift: @Observable, NavigationStack, .task, SF Symbols
- TypeScript: explicit types, Zod validation, no `any`
- Always run tests before committing

## Git Rules
- Commit messages: `type(scope): description`
- Types: feat, fix, docs, test, refactor, chore
- Never force push. Never rewrite history.
