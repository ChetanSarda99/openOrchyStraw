# UI-001: Tauri Desktop App Frontend Stack

_Decision Date: 2026-03-17_
_Status: APPROVED (LOCKED)_
_Decided By: CTO + Founder_

---

## Domain
Tauri Desktop App — Frontend framework, styling, state management

## Decision
React 19 + TypeScript + Tailwind v4 + shadcn/ui v4 + Zustand + TanStack Query

## Base Template
dannysmith/tauri-template

## Full Stack

| Concern | Choice | Version |
|---------|--------|---------|
| UI Framework | React | 19 |
| Language | TypeScript | strict mode |
| Build | Vite | 7 |
| Components | shadcn/ui | v4 |
| CSS | Tailwind CSS | v4 |
| Icons | Lucide React | latest |
| UI State | Zustand | v5 |
| Data State | TanStack Query | v5 |
| Type Bridge | tauri-specta | latest |
| Testing | Vitest | v4 |
| Linting | ESLint + Prettier + ast-grep | — |

## Rationale
- React 19 is the most widely supported and agent-friendly framework
- shadcn/ui v4 provides composable, un-opinionated components (shared with landing page)
- Zustand + TanStack Query separates UI state from server/backend state cleanly
- tauri-specta provides type-safe IPC between Rust and TypeScript
- Template includes all boilerplate: command palette, dark mode, notifications, auto-updates

## Alternatives Considered
- **Svelte**: Smaller ecosystem, fewer agents can write it, no equivalent template
- **Vue**: Viable but React has better shadcn/ui support and agent familiarity

## Reversibility
Low — framework choice is foundational. Would require full rewrite.
