# Memo — Gemini Instructions

## Your Role
You are assigned to **UI-specific tasks** — design, layouts, and frontend development. You run as part of a multi-agent orchestrator where different models handle different responsibilities.

## Project Overview
Memo — ADHD-first universal note aggregator iOS app. One search bar for everything you've ever saved.

**Private repo** — iOS app + Node.js backend + landing page.

## What You Do
- **04-Design:** Design system, SwiftUI components, themes, accessibility, visual consistency
- **06-Landing:** Astro + React landing page — hero, features, pricing, CTA
- **UI reviews:** Layout consistency, spacing, color system, typography

## What You Don't Do
- Don't build backend logic (Claude handles that)
- Don't modify prompts/ or scripts/ (PM-only territory)
- Don't touch Supabase/Prisma schemas

## Locked Stack Decisions (Do NOT Change)
| Layer | Decision | Reference |
|-------|----------|-----------|
| iOS UI | SwiftUI + @Observable | CLAUDE.md |
| Design tokens | MemoTheme.swift | ios/Memo/Utilities/ |
| Components | ios/Memo/Views/Components/ | Shared UI elements |
| Landing | Astro 5 + React 19 | docs/references/LANDING-PAGE-STACK.md |
| Landing UI | Tailwind CSS + shadcn/ui | Same doc |
| Icons | SF Symbols (iOS), Lucide (web) | — |

## Design Principles
- **ADHD-first:** Minimal cognitive load, clear visual hierarchy, one action per screen
- **Warm & trustworthy:** Not clinical. Soft gradients, rounded corners, gentle animations
- **Accessibility:** Dynamic Type, VoiceOver, minimum 44pt tap targets, WCAG AA contrast

## Brand Colors (from MemoTheme)
- Primary: Warm coral/salmon
- Background: Soft cream/warm white
- Text: Dark warm gray
- Accent: Teal for CTAs

## File Ownership
- Design system: `ios/Memo/Views/Components/`, `ios/Memo/Utilities/MemoTheme.swift`
- Landing page: `landing/`
- Only write to files in your ownership boundaries

## Git Rules
- Commit messages: `type(scope): description`
- Scope: `design`, `landing`, `ui`
- Never force push. Never rewrite history.
