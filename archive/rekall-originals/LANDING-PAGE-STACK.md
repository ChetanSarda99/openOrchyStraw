# Memo Landing Page — Stack Reference

**DO NOT deviate from this stack. These are locked decisions.**

---

## Existing Codebase

The landing page is ALREADY BUILT at `landing/`. Do NOT scaffold from scratch.
Do NOT replace the existing component architecture.

---

## Locked Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Framework | Next.js | 16+ | App Router |
| Language | TypeScript | 5+ | Strict mode |
| CSS | Tailwind CSS | v4 | `@theme inline` in globals.css |
| Animations | Framer Motion | 12+ | Primary animation library |
| Animations (scroll) | GSAP + @gsap/react | 3.14+ | Scroll-triggered only |
| Utilities | clsx + tailwind-merge | latest | Class merging |
| Deploy | Vercel | — | Static + API routes |

### NOT using (and don't add)
- ❌ shadcn/ui (custom components, NOT component library)
- ❌ Radix UI (no headless primitives needed)
- ❌ Any CSS-in-JS (no styled-components, no Emotion)
- ❌ Any other animation library (Framer Motion + GSAP only)

---

## Brand Identity

### App Name
**Rekall** (display name, used in constants). Internal project name: Memo.
All brand strings come from `lib/constants.ts` — `APP` object.

### Colors (from globals.css @theme)

| Role | Token | Hex | Usage |
|------|-------|-----|-------|
| Primary | `--color-primary` | `#1A7A6D` | Deep teal — buttons, links, active |
| Primary Light | `--color-primary-light` | `#2BA89A` | Hover states, highlights |
| Accent | `--color-accent` | `#E8734A` | Coral — CTAs, badges, notifications |
| Accent Hover | `--color-accent-hover` | `#d4633c` | Accent pressed state |
| Warm Sand | `--color-warm-sand` | `#F5E6D3` | Light mode backgrounds |
| Dark BG | `--color-dark-bg` | `#0D1B2A` | Deep navy — page background |
| Dark Surface | `--color-dark-surface` | `#1B2838` | Cards, sections |
| Dark Surface 2 | `--color-dark-surface-2` | `#243347` | Elevated surfaces |
| Dark Border | `--color-dark-border` | `#2E4057` | Borders, dividers |
| Dark Text | `--color-dark-text` | `#E8E8E8` | Body text |
| Dark Muted | `--color-dark-text-muted` | `#94A3B8` | Secondary text |
| AI | `--color-ai` | `#7E57C2` | AI features accent |

### Dark Mode is Default
- `html { color-scheme: dark; }` — DO NOT add a light mode toggle
- Background: deep navy `#0D1B2A` (NOT pure black)
- Text: `#E8E8E8` (NOT pure white)
- Muted text: `#94A3B8`

### Typography
- **Font:** Inter (via `next/font/google`)
- **Variable:** `--font-inter` → `--font-sans`
- **Body:** 16-18px, `leading-relaxed` (1.625)
- **Hero:** `text-5xl md:text-7xl`, `font-bold`, `tracking-tight`
- **Sections:** `text-3xl md:text-5xl`, `font-bold`

### Radii
- Small: 8px (`--radius-small`)
- Medium: 12px (`--radius-medium`)
- Large: 16px (`--radius-large`)
- Search/pills: 24px (`--radius-search`)

### Ease
- Spring: `cubic-bezier(0.34, 1.56, 0.64, 1)` (`--ease-spring`)

---

## Source Brand Colors (from constants.ts)

| Source | Hex | Token |
|--------|-----|-------|
| Telegram | `#0088CC` | `SOURCE_COLORS.telegram` |
| Notion | `#3A3A3A` | `SOURCE_COLORS.notion` |
| Instagram | `#E1306C` | `SOURCE_COLORS.instagram` |
| Reddit | `#FF4500` | `SOURCE_COLORS.reddit` |
| Twitter | `#1DA1F2` | `SOURCE_COLORS.twitter` |
| Voice | `#7E57C2` | `SOURCE_COLORS.voice` |
| Screenshot | `#607D8B` | `SOURCE_COLORS.screenshot` |
| Pocket | `#EF4056` | `SOURCE_COLORS.pocket` |

---

## Page Structure (locked section order)

```
page.tsx:
  <Navbar />           — Sticky, links: Features, How it works, Pricing
  <Hero />             — Headline + source pills + waitlist form + phone mockup
  <Problem />          — "You saved it somewhere" pain point
  <PocketMigration />  — Pocket shutdown hook (timely)
  <Solution />         — "One search bar" value prop
  <HowItWorks />       — 3-step: Connect → AI categorizes → Search
  <Features />         — Feature grid with icons
  <Comparison />       — vs. competitors table
  <BuiltForADHD />     — ADHD-specific messaging
  <Pricing />          — Free vs Pro ($9.99/mo)
  <WaitlistCTA />      — Final email capture
  <Footer />           — Links, social, legal
```

---

## Component Architecture

### All components are custom — NO component library
Components live in `landing/components/`. Each is a self-contained section.

### Shared Patterns
- **FadeUp animation:** Framer Motion `motion.div` with `opacity: 0, y: 24` → `opacity: 1, y: 0`
- **Reduced motion:** ALWAYS check `useReducedMotion()` and disable animations
- **Scroll parallax:** `useScroll` + `useTransform` for subtle depth (Hero phone)
- **Container:** `mx-auto max-w-7xl px-6 sm:px-8 lg:px-12`
- **Section spacing:** `py-24 md:py-32`

### Constants
All brand strings, colors, pricing, sources, and nav items are in `lib/constants.ts`.
**NEVER hardcode brand values in components** — always import from constants.

---

## Waitlist Backend

- **API route:** `landing/app/api/waitlist/route.ts`
- **Database:** Supabase (env vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- **Rate limiting:** In-memory, 5 submissions per IP per hour
- **Validation:** Email regex + trim + lowercase
- **SQL schema:** `landing/landing-waitlist.sql`

---

## File Structure

```
landing/
  app/
    page.tsx              — Main page (imports all sections)
    layout.tsx            — Root layout (Inter font, metadata)
    globals.css           — Tailwind v4 @theme + dark mode + custom properties
    opengraph-image.tsx   — Dynamic OG image
    twitter-image.tsx     — Dynamic Twitter card
    api/waitlist/route.ts — Waitlist API endpoint
  components/
    Navbar.tsx            — Sticky nav
    Hero.tsx              — Hero + phone mockup + waitlist form
    Problem.tsx           — Pain point section
    PocketMigration.tsx   — Pocket shutdown hook
    Solution.tsx          — Value proposition
    HowItWorks.tsx        — 3-step process
    Features.tsx          — Feature grid
    Comparison.tsx        — vs. competitors
    BuiltForADHD.tsx      — ADHD-specific messaging
    Pricing.tsx           — Free vs Pro
    WaitlistCTA.tsx       — Bottom CTA
    WaitlistForm.tsx      — Email input + submit
    WaitlistCounter.tsx   — Live count display
    PhoneMockup.tsx       — App preview
    Footer.tsx            — Footer
  lib/
    constants.ts          — ALL brand values (name, colors, pricing, sources)
    utils.ts              — Utility functions
  public/
    screenshots/          — App screenshots for mockup
```

---

## ADHD Design Rules (NON-NEGOTIABLE)

1. **Respect `useReducedMotion()`** — every animation must check
2. **No guilt-tripping** — no "You missed X days!" or streak pressure
3. **No notification spam messaging** — max "1-2 per day, all opt-in"
4. **Calming colors** — teal/navy, NOT red/orange for primary
5. **One clear action per viewport** — don't overwhelm
6. **16pt minimum padding** everywhere
7. **4.5:1 contrast ratio** minimum (WCAG 2.1 AA)
8. **Dark mode only** (for now) — deep navy, not pure black

---

## Pricing (from constants.ts)

### Free
- 3 connected sources
- 50 notes per month
- Basic keyword search
- Manual categorization

### Pro — $9.99/mo
- Unlimited sources
- 1,000 notes per month
- AI semantic search
- Voice transcription
- Smart notifications
- Pattern insights
- Weekly digest
- Priority support

---

## DO NOT

- ❌ Add shadcn/ui or any component library (custom components only)
- ❌ Add a light mode toggle (dark mode only)
- ❌ Use pure black (#000) or pure white (#FFF)
- ❌ Hardcode brand strings (use `lib/constants.ts`)
- ❌ Skip reduced motion checks on ANY animation
- ❌ Add more than Framer Motion + GSAP for animations
- ❌ Change the section order without explicit approval
- ❌ Use gradients (except the subtle Hero radial gradient)
- ❌ Add generic placeholder images or Lorem ipsum
- ❌ Use emoji in the UI (source pills use colored dots)
