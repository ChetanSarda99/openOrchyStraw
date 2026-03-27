# Tech Stack Registry — OrchyStraw

_Last updated: 2026-03-20_
_Maintained by: CTO (02-cto)_
_See docs/KNOWLEDGE-REPOSITORIES.md for full system documentation._

---

## Approved Stack

| Domain | Solution | Version | Decision | Surfaces | Notes |
|--------|----------|---------|----------|----------|-------|
| Core runtime | Bash | 5.0+ | BASH-001 | Orchestrator | macOS: brew install bash |
| Config format | Markdown + plain text | — | Built-in | Orchestrator | No deps policy |
| AI CLI | claude CLI (primary) | latest | Built-in | Orchestrator | bypassPermissions mode |
| Doc search | QMD | latest | — | Orchestrator | BM25 + vector |
| Docs framework | context7 MCP | latest | — | Orchestrator | Framework docs |
| Tauri frontend | React 19 + TypeScript | 19 / strict | UI-001 | Desktop App | dannysmith/tauri-template |
| Tauri build | Vite | 7 | UI-001 | Desktop App | — |
| UI components | shadcn/ui | v4 | STYLE-001 | All surfaces | Shared across app, site, docs |
| CSS framework | Tailwind CSS | v4 | STYLE-001 | All surfaces | Utility-first |
| Icons | Lucide React | latest | STYLE-001 | All surfaces | — |
| UI state | Zustand | v5 | UI-001 | Desktop App | Global UI state |
| Data state | TanStack Query | v5 | UI-001 | Desktop App | Server/backend state |
| Type bridge | tauri-specta | latest | UI-001 | Desktop App | Rust ↔ TS type safety |
| Testing (frontend) | Vitest | v4 | UI-001 | Desktop App | — |
| Landing page | Next.js (App Router) | 15+ | WEB-001 | Landing Page | Static export, memextech template |
| Animations | Framer Motion | latest | WEB-001 | Landing Page | Subtle only |
| Documentation | Mintlify | latest | DOCS-001 | Docs Site | Same as Claude Code docs |
| Desktop DB | SQLite | — | DB-001 | Desktop App | rusqlite / Tauri plugin |
| Font (code) | JetBrains Mono | — | STYLE-001 | All surfaces | — |
| Font (UI) | Inter / Geist | — | STYLE-001 | All surfaces | — |

---

## Domain Decisions

| Domain | Status | ADR | Notes |
|--------|--------|-----|-------|
| Bash version | **APPROVED** | BASH-001 | Minimum bash 5.0, portable shebang |
| Tauri UI framework | **LOCKED** | UI-001 | React 19 + TypeScript |
| Desktop DB | **APPROVED** | DB-001 | SQLite |
| Desktop styling | **LOCKED** | STYLE-001 | Tailwind v4 + shadcn/ui v4 |
| Landing page framework | **LOCKED** | WEB-001 | Next.js 15 |
| Docs site | **LOCKED** | DOCS-001 | Mintlify |
| Design system | **LOCKED** | STYLE-001 | Shared dark theme, tokens |
| File ownership | **APPROVED** | OWN-001 | Boundaries, overlap rules, protected file policy |
| Benchmark runner | **APPROVED** | BENCH-001 | Bash runner + Python SWE-bench glue. See BENCHMARK-ARCHITECTURE.md |
| v0.5 CLI language | Pending | — | Python (recommended in PLATFORM-COMPATIBILITY.md) |
| Notifications | Pending | — | Desktop toast (WSL), Telegram, Slack |

---

## Pending Decisions (CTO will evaluate when relevant)

These domains need ADRs when implementation begins:

1. ~~**Benchmark runner**~~ — DECIDED: BENCH-001 (bash runner, Python only for SWE-bench glue)
2. **v0.5 CLI language** — Python strongly recommended, needs formal ADR
3. **Notification channels** — Currently WSL toast only, need cross-platform strategy
4. **Auth for public API** — If OrchyStraw exposes a CLI/API (v1.0+)
5. **Accent color** — Warm orange (#F97316 from Mintlify) vs teal (TBD)
