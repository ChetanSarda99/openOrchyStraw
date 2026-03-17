# Tauri Desktop App — Stack Reference
## For agents: 04-tauri-rust, 05-tauri-ui

**DO NOT deviate from this stack. These are locked decisions.**

---

## Base Template

**dannysmith/tauri-template** — https://github.com/dannysmith/tauri-template

Clone this as the starting point. Do NOT scaffold from scratch.

```bash
git clone https://github.com/dannysmith/tauri-template.git
```

### Why This Template
- Production-ready, batteries-included
- Designed for AI coding agents (comprehensive docs in `docs/developer/`)
- Already has every pattern we need (sidebars, preferences, themes, menus)
- React 19 + TypeScript + Vite 7 + shadcn/ui v4 + Tailwind v4

---

## Locked Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Framework | Tauri | v2 | Desktop runtime |
| Frontend | React | 19 | With React Compiler (auto-memoization) |
| Language | TypeScript | strict | No `any` types |
| Build | Vite | 7 | Fast HMR |
| UI Components | shadcn/ui | v4 | Copy-paste, Tailwind-based |
| CSS | Tailwind CSS | v4 | Utility-first |
| Icons | Lucide React | latest | Consistent icon set |
| State (UI) | Zustand | v5 | Global UI state |
| State (Data) | TanStack Query | v5 | Persistent/async data |
| Type Bridge | tauri-specta | latest | Type-safe Rust↔TS commands |
| Testing | Vitest | v4 | With Testing Library |
| Linting | ESLint + Prettier + ast-grep | — | Architecture enforcement |

### State Management (Three-Layer Rule)
1. **useState** — component-local state only
2. **Zustand** — global UI state (sidebar open, theme, etc.)
3. **TanStack Query** — persistent data from Rust backend

### Built-in Features (from template)
- ✅ Command Palette (Cmd+K)
- ✅ Collapsible sidebars with state persistence
- ✅ Dark/light mode with system detection
- ✅ Preferences system (Rust-side persistence + React hooks)
- ✅ Toast + native notifications
- ✅ Auto-updates via GitHub Releases
- ✅ Keyboard shortcuts (platform-aware)
- ✅ Native menus (File, Edit, View)
- ✅ i18n + RTL support
- ✅ Crash recovery
- ✅ Structured logging (Rust + TypeScript)
- ✅ Multi-window architecture
- ✅ Platform-specific title bars (macOS traffic lights, Windows controls)
- ✅ Single-instance prevention

### Tauri Plugins (pre-configured)
- single-instance, window-state, fs, dialog, notification
- clipboard-manager, global-shortcut, updater, opener, tauri-nspanel

---

## Design System

- **Background:** #0a0a0a (near-black)
- **Font (code):** JetBrains Mono
- **Font (UI):** Inter or Geist
- **Status colors:** 🟢 `#22c55e` running, 🟡 `#eab308` idle, 🔴 `#ef4444` error, ⚪ `#6b7280` not this cycle
- **Inspiration:** [Conductor](https://conductor.build) — clean, dark, data-dense developer UI

---

## MCP Integration

shadcn MCP server is configured in `.mcp.json` at project root:
```json
{
  "mcpServers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    }
  }
}
```

Use the MCP to browse and install shadcn components. Example prompts:
- "Show me all available components in the shadcn registry"
- "Add the button, dialog and card components"
- "Add the sidebar component"

---

## File Structure (from template)

```
src-tauri/
  src/
    commands/          — Tauri IPC commands (auto-generates TS types via specta)
    models/            — Rust data models
    state/             — App state management
    db/                — SQLite via rusqlite
    lib.rs             — Plugin registration
    main.rs            — Entry point

src/
  components/
    ui/                — shadcn/ui components (copy-pasted, owned by us)
    layout/            — App layout (sidebar, titlebar, content area)
    agents/            — Agent status cards, detail views
    cycles/            — Cycle dashboard, controls
    logs/              — Log viewer, filters
    config/            — agents.conf visual editor
  hooks/               — Custom React hooks
  stores/              — Zustand stores
  services/            — Tauri command wrappers (type-safe via specta)
  lib/                 — Utilities
  styles/              — Global CSS, Tailwind config
```

---

## Quality Gates

Before any PR/commit:
```bash
npm run check:all    # TypeScript + ESLint + Prettier + ast-grep + clippy + tests
```

---

## DO NOT

- ❌ Use a different UI library (no MUI, Ant Design, Chakra)
- ❌ Use CSS modules or styled-components (Tailwind only)
- ❌ Add Redux or MobX (Zustand + TanStack Query only)
- ❌ Scaffold a new Tauri project (use dannysmith/tauri-template)
- ❌ Skip type safety (no `any`, use tauri-specta)
- ❌ Add unnecessary animations (data-dense, fast, minimal)
