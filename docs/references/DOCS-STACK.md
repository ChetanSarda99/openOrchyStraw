# Documentation Site — Stack Reference
## For agent: 11-web

**DO NOT deviate from this stack. These are locked decisions.**

---

## Platform

**Mintlify** — https://mintlify.com

Same platform used by:
- **Claude Code docs** (code.claude.com/docs)
- **Conductor docs** (docs.conductor.build)
- **Anthropic API docs** (docs.anthropic.com)
- Coinbase, HubSpot, Zapier, Perplexity

### Why Mintlify
- Zero custom code for docs infrastructure
- Built-in: sidebar nav, tabs, accordions, code blocks, search, API refs
- Markdown/MDX content — same as our prompts system
- Auto-deploy from GitHub
- Free tier available
- AI-native: has its own MCP server + skill for AI agents

---

## Setup

### Quick Start
```bash
# Install Mintlify CLI
npm install -g mintlify

# Initialize in docs directory
cd site/docs
mintlify init

# Preview locally
mintlify dev
```

### Connect to GitHub
1. Go to mintlify.com/start
2. Connect GitHub account
3. Point to `site/docs/` directory in repo
4. Auto-deploys on push

### AI Agent Setup
```bash
# Install Mintlify skill (for Claude Code agents)
npx skills add https://mintlify.com/docs
```

MCP server config (add to `.mcp.json`):
```json
{
  "mcpServers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    },
    "mintlify": {
      "command": "npx",
      "args": ["mintlify@latest", "mcp"]
    }
  }
}
```

---

## Content Structure

```
site/docs/
  mint.json              — Mintlify config (nav, theme, logo, colors)
  introduction.mdx       — Overview / landing
  quickstart.mdx         — Getting started guide
  configuration.mdx      — agents.conf reference
  writing-prompts.mdx    — How to write agent prompts
  shared-context.mdx     — Cross-agent communication
  auto-cycle.mdx         — Auto-cycle mode
  examples/
    basic.mdx            — Simple 3-agent setup
    tauri-desktop.mdx    — Desktop app example
    full-team.mdx        — 10-agent team example
  pixel-agents.mdx       — Pixel Agents integration
  faq.mdx                — FAQ
  contributing.mdx       — How to contribute
  changelog.mdx          — Version history
```

---

## Mintlify Components (use these, not custom)

### Navigation
```json
// mint.json
{
  "navigation": [
    { "group": "Getting Started", "pages": ["introduction", "quickstart"] },
    { "group": "Configuration", "pages": ["configuration", "writing-prompts"] },
    { "group": "Features", "pages": ["shared-context", "auto-cycle", "pixel-agents"] },
    { "group": "Examples", "pages": ["examples/basic", "examples/tauri-desktop"] }
  ]
}
```

### Built-in Components
- `<Card>` — linked cards (like Conductor's docs)
- `<CardGroup>` — grid of cards
- `<Tabs>` / `<Tab>` — tabbed content
- `<Accordion>` / `<AccordionGroup>` — collapsible sections
- `<CodeGroup>` — multi-language code blocks
- `<Tip>` / `<Warning>` / `<Note>` — callout boxes
- `<Steps>` — numbered step-by-step guides
- `<Frame>` — image/video frames
- `<Tooltip>` — inline tooltips

### Theme (mint.json)
```json
{
  "name": "OrchyStraw",
  "logo": {
    "dark": "/logo/dark.svg",
    "light": "/logo/light.svg"
  },
  "colors": {
    "primary": "#F97316",
    "light": "#FB923C",
    "dark": "#EA580C",
    "background": {
      "dark": "#0a0a0a"
    }
  },
  "favicon": "/favicon.svg",
  "topbarLinks": [
    { "name": "GitHub", "url": "https://github.com/ChetanSarda99/openOrchyStraw" }
  ],
  "topbarCtaButton": {
    "name": "Get Started",
    "url": "/quickstart"
  },
  "footer": {
    "socials": {
      "github": "https://github.com/ChetanSarda99/openOrchyStraw"
    }
  }
}
```

---

## Content Source

Port from existing openOrchyStraw docs:
- `README.md` → `introduction.mdx`
- `CONCEPTS.md` → `shared-context.mdx` + `configuration.mdx`
- `CREATING-CUSTOM-AGENTS.md` → `writing-prompts.mdx`
- `WORKFLOW.md` → `auto-cycle.mdx`
- `examples/` → `examples/`

---

## DO NOT

- ❌ Build a custom docs site (no Docusaurus, no Starlight, no VitePress)
- ❌ Write custom CSS for docs (Mintlify handles it)
- ❌ Add custom React components to docs (use Mintlify built-ins)
- ❌ Host docs on a separate domain initially (use `.mintlify.app` then custom domain)
- ❌ Duplicate content between landing page and docs (link between them)
