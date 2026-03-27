# Landing Page — Stack Reference
## For agent: 11-web

**DO NOT deviate from this stack. These are locked decisions.**

---

## Base Template

**memextech/nextjs-shadcn-landing-page-template** — https://github.com/memextech/nextjs-shadcn-landing-page-template

Clone this as the starting point. Do NOT build from scratch.

```bash
npx create-next-app@latest site --typescript --tailwind --eslint --app --src-dir
# Then add shadcn components from the template
```

### Why This Template
- Next.js + shadcn/ui + Tailwind — same stack as Conductor's landing page
- Pre-built components: Accordion, Button, Card, Dialog, etc.
- Light/dark mode theming via CSS variables
- Modern layout with Google Fonts (Inter)
- MIT licensed, flexible

---

## Locked Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Framework | Next.js | 15+ | App Router, static export |
| Language | TypeScript | strict | No `any` |
| UI Components | shadcn/ui | v4 | Same as Tauri app |
| CSS | Tailwind CSS | v4 | Utility-first |
| Icons | Lucide React | latest | Same as Tauri app |
| Animations | Framer Motion | latest | Subtle, tasteful only |
| Font (UI) | Inter or Geist | — | Via next/font |
| Font (code) | JetBrains Mono | — | For code blocks |
| Deploy | Vercel or GitHub Pages | — | Static export |

---

## Design Inspiration

### Primary: [Conductor](https://conductor.build)
- Dark background, bold hero text
- 3-step "How it works" (numbered)
- FAQ accordion
- "Trusted by builders at..." social proof
- Single CTA: "Get Started" / "Star on GitHub"
- Clean, minimal, no clutter

### Secondary: [Whryte](https://whryte.com)
- Product specs grid (input speed, privacy, languages)
- 3-step setup section (Download → Permissions → Use)
- Pricing section (one-time, clean)
- Dark theme, monospace accents

---

## Page Sections (in order)

1. **Hero** — Headline + subhead + CTA + optional terminal animation
2. **Social Proof** — "Trusted by builders at..." (add when available)
3. **How It Works** — 3 numbered steps (Configure → Run → Review)
4. **Features Grid** — 4-6 cards with icons
5. **Supported Tools** — Logo row (Claude Code, Codex, Gemini, Aider, etc.)
6. **FAQ** — Accordion (5-8 questions)
7. **CTA** — Final call to action
8. **Footer** — GitHub, MIT license, links

---

## Design System (shared with Tauri app)

- **Background:** #0a0a0a (near-black)
- **Font (code):** JetBrains Mono
- **Font (UI):** Inter or Geist
- **Accent color:** TBD (OrchyStraw brand — suggest warm orange or teal)
- **No gradients** — flat, clean
- **Generous whitespace**
- **Mobile responsive** (desktop-first)

---

## MCP Integration

shadcn MCP server configured in `.mcp.json`:
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

---

## File Structure

```
site/
  src/
    app/
      page.tsx           — Landing page (all sections)
      layout.tsx         — Root layout (fonts, meta, theme)
      globals.css        — Tailwind + CSS variables (light/dark)
    components/
      ui/                — shadcn/ui components
      hero.tsx           — Hero section
      how-it-works.tsx   — 3-step section
      features.tsx       — Features grid
      supported-tools.tsx — Tool logos
      faq.tsx            — FAQ accordion
      footer.tsx         — Footer
      terminal-demo.tsx  — Terminal animation (optional)
  public/
    logos/               — Tool logos (Claude, Codex, etc.)
    og-image.png         — OpenGraph image
    favicon.ico
  next.config.js
  tailwind.config.ts
  package.json
```

---

## DO NOT

- ❌ Use a different framework (no Astro, no Gatsby, no vanilla HTML)
- ❌ Use CSS modules or styled-components (Tailwind only)
- ❌ Add heavy JS frameworks or animation libraries (Framer Motion max)
- ❌ Build a SPA — this is a static site
- ❌ Add auth, database, or API routes (it's a landing page)
- ❌ Use light mode as default (dark first)
- ❌ Use different components than shadcn/ui (consistency with Tauri app)
