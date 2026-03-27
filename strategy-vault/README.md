# OrchyStraw Strategy Vault

> Definitive strategy and guide reference for all upcoming app projects. Start here before starting anything.

---

## What This Is

This repo is the master strategy reference for CS — a single source of truth for brand, marketing, product strategy, and technical decisions that apply **across all projects**.

It's also home to project-specific docs for active builds (Rekall, OrchyStraw).

---

## How to Use This Repo

### Starting a new project?
1. Read `strategy/` — brand, marketing, app-building mindset, and stack references
2. Copy `templates/` files into your new project repo as a starting point
3. Create a `projects/<your-project>/` folder here for project-specific docs

### Working on an existing project?
- Rekall (Memo) docs → `projects/rekall/`
- OrchyStraw docs → `projects/orchystraw/`
- Agent prompts (reusable) → `prompts/`

---

## Structure

```
strategy/               Universal docs — read before any project
  brand/                Brand setup, naming, branding strategy
  marketing/            Marketing strategy, plans, Reddit/LinkedIn playbooks
  creative/             Creative framework, ad concepts
  app-building/         Best practices, mindset, design workflow, onboarding
  stacks/               Locked tech stacks (landing page, Tauri, docs site)
  app-store/            App Store review checklist, Apple Intelligence strategy
  AGENT-DESIGN-REFERENCE.md
  ARCHITECTURE-REFERENCE.md
  CONTRIBUTING.md
  CONVENTIONS.md
  KNOWLEDGE-REPOSITORIES.md
  RESEARCH-LEARNINGS.md
  anti-patterns.md

templates/              Bootstrap a new project fast
  AGENTS.md             Template AGENTS.md for new project repos
  CLAUDE.md             Template CLAUDE.md for new project repos
  PRODUCT_SPEC.md       Template product spec
  COMPETITIVE_ANALYSIS.md Template competitive analysis

projects/               Project-specific docs (not universal)
  rekall/               Memo/Rekall — architecture, MVP, product spec, research
  orchystraw/           OrchyStraw — cycle updates, architecture, team, tech registry

prompts/                Agent prompts — reusable across projects
  01-ceo/ → 13-hr/      Specialist agent prompts (CEO, CTO, PM, iOS, etc.)

archive/                Old/superseded docs

scripts/                Utility scripts
```

---

## Projects

| Project | Folder | Status |
|---------|--------|--------|
| Rekall (Memo) | `projects/rekall/` | Active |
| OrchyStraw | `projects/orchystraw/` | Active |

---

## Key Reads (Start Here)

| What | Where |
|------|-------|
| Brand strategy | `strategy/brand/BRAND_SETUP_GUIDE.md` |
| App building mindset | `strategy/app-building/APP_MINDSET.md` |
| Marketing strategy | `strategy/marketing/MARKETING_STRATEGY_2026.md` |
| Tech stack decisions | `strategy/stacks/` |
| App Store prep | `strategy/app-store/APP_STORE_REVIEW_CHECKLIST.md` |

---

*OrchyStraw Strategy Vault — building tools people actually want to use.*
