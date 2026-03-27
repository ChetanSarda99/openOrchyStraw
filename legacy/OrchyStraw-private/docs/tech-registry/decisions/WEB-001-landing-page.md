# WEB-001: Landing Page Stack

_Decision Date: 2026-03-17_
_Status: APPROVED (LOCKED)_
_Decided By: CTO + Founder_

---

## Domain
Landing Page — Framework, styling, animations, deployment

## Decision
Next.js 15 + TypeScript + Tailwind v4 + shadcn/ui v4 + Framer Motion

## Base Template
memextech/nextjs-shadcn-landing-page-template

## Full Stack

| Concern | Choice | Version |
|---------|--------|---------|
| Framework | Next.js (App Router, static export) | 15+ |
| Language | TypeScript | strict |
| Components | shadcn/ui | v4 |
| CSS | Tailwind CSS | v4 |
| Icons | Lucide React | latest |
| Animations | Framer Motion | latest (subtle only) |
| Fonts | Inter/Geist (UI) + JetBrains Mono (code) | via next/font |
| Deploy | Vercel or GitHub Pages | — |

## Design Inspiration
- **Primary**: Conductor (dark, bold hero, 3-step how-it-works, FAQ accordion)
- **Secondary**: Whryte (specs grid, 3-step setup, pricing, monospace accents)

## Rationale
- Next.js 15 with static export = fast, SEO-friendly, free hosting
- shadcn/ui v4 shared with Tauri app for design consistency
- Framer Motion for tasteful micro-animations without heavy deps
- Template provides all sections: hero, social proof, features, FAQ, CTA

## Reversibility
Medium — landing page is a single surface, could swap framework without affecting other surfaces.
