# Tech Stack Registry — OrchyStraw

_Last updated: 2026-03-17_
_Maintained by: CTO (02-cto)_
_See docs/KNOWLEDGE-REPOSITORIES.md for full system documentation._

---

## Approved Stack

| Domain | Solution | Version | Decision | Projects | Notes |
|--------|----------|---------|----------|----------|-------|
| Core runtime | Bash | 5.x | Built-in | OrchyStraw | POSIX-compatible |
| Config format | Markdown + plain text | — | Built-in | OrchyStraw | No deps policy |
| AI CLI | claude CLI (primary) | latest | Built-in | OrchyStraw | bypassPermissions mode |
| Doc search | QMD | latest | — | OrchyStraw | BM25 + vector |
| Docs framework | context7 MCP | latest | — | OrchyStraw | Framework docs |

_CTO: fill in decisions as you evaluate proposals_

---

## Domain Decisions

| Domain | Status | ADR | Notes |
|--------|--------|-----|-------|
| Tauri UI framework | Pending | — | React vs Svelte vs Vue |
| Desktop DB | Pending | — | SQLite vs libsql (Turso) |
| Desktop styling | Pending | — | Tailwind vs UnoCSS |
| Benchmark runner | Pending | — | Custom vs existing SWE-bench harness |
| Landing page framework | Pending | — | Next.js vs Astro vs plain HTML |
| Docs site | Pending | — | Mintlify vs Nextra vs Docusaurus |

