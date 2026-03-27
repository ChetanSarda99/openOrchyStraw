# STYLE-001: Shared Design System

_Decision Date: 2026-03-17_
_Status: APPROVED (LOCKED)_
_Decided By: CTO + Founder_

---

## Domain
Design System — Colors, typography, component library (shared across all surfaces)

## Decision
shadcn/ui v4 + Tailwind v4 + Lucide React + JetBrains Mono + Inter/Geist + dark mode (#0a0a0a)

## Shared Across
- Tauri Desktop App
- Landing Page
- Documentation Site

## Design Tokens

| Token | Value | Usage |
|-------|-------|-------|
| Background | #0a0a0a | All surfaces, dark mode default |
| Font (code) | JetBrains Mono | Terminal output, code blocks, agent logs |
| Font (UI) | Inter or Geist | Headings, body text, labels |
| Running | #22c55e (green) | Active agent indicator |
| Idle | #eab308 (yellow) | Waiting/paused agent |
| Error | #ef4444 (red) | Failed agent, errors |
| Inactive | #6b7280 (gray) | Agent not scheduled this cycle |
| Accent | TBD | Warm orange or teal (to be finalized) |

## Principles
- No gradients
- Generous whitespace
- Mobile responsive
- Dark mode first, light mode optional
- Data-dense developer UI (Conductor-inspired)

## Rationale
- shadcn/ui v4 is composable and un-opinionated — adapts to any surface
- Tailwind v4 provides utility-first CSS with design token support
- Lucide React for consistent iconography
- JetBrains Mono is the de facto developer font
- #0a0a0a background is the standard dark UI background (used by Vercel, Linear, etc.)

## Reversibility
Medium — design tokens can evolve, but component library choice is structural.
