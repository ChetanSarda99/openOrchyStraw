# App Branding Strategy for Memo

## Executive Summary

Branding isn't a logo. It's the feeling someone gets the first time they see your app icon, read your tagline, or tap through your onboarding. For indie apps, branding is the difference between "another note app" and "this was made for me." Memo needs to feel calm, intelligent, and trustworthy from the first pixel — because ADHD users have been burned by overcomplicated tools before. First impressions determine whether someone downloads, and brand consistency determines whether they stay.

**Core brand promise:** Memo is the one calm place where everything you've ever saved lives — and you can actually find it.

---

## 1. Visual Identity

### App Icon Design (2026 Best Practices)

**Design Principles:**
- **Simple:** Recognizable at 29x29pt (smallest iOS size). If it doesn't read at thumbnail, it fails.
- **Memorable:** One visual concept, not a collage. Think: what shape do users picture when they hear "Memo"?
- **Scalable:** Works on App Store (1024x1024), home screen (60x60), Spotlight (40x40), and Settings (29x29).
- **No text:** Apple's HIG explicitly discourages text in app icons. It doesn't scale.
- **No photos:** Use abstract or stylized imagery only.

**2026 Trends:**
- **Subtle depth:** Move past flat design. Use soft gradients, gentle shadows, or layered elements that suggest dimension without going full skeuomorphic.
- **Adaptive identities:** Icons that feel native on both light and dark home screens. Consider how the icon renders on iOS 19's tinted icon mode.
- **Minimal but warm:** The trend is away from cold, corporate minimalism toward approachable, human-feeling design.
- **Avoid AI slop:** No generic gradient blobs, no Midjourney-generated icons. Custom design or nothing — users can smell template work.

**Memo-Specific Recommendations:**
- **Concept 1: The Search Lens** — A minimal magnifying glass with a subtle memo/note element inside. Represents the core action: finding things.
- **Concept 2: The Convergence** — Multiple subtle lines or streams converging into a single point. Represents bringing scattered ideas together.
- **Concept 3: The Brain Bookmark** — A stylized bookmark with organic, brain-like curves. Represents saving + cognition.
- Use a single hero color from the palette (see below) as the icon background.
- Rounded square with subtle inner shadow for depth.

**Tools:**
- **Figma** — Primary design tool (free tier works fine)
- **SF Symbols** — Reference for iOS-native iconography style
- **Bakery** (by Jordi Bruin) — iOS app icon generator
- **IconKitchen** — Quick icon mockups
- **RealFaviconGenerator** — For web assets

---

### Color Palette

**ADHD-Friendly Color Research:**
- Studies suggest calming blues and greens reduce cognitive overwhelm
- Warm neutrals feel approachable without being stimulating
- High contrast aids focus; low contrast causes eye strain
- Avoid: pure red (anxiety), bright yellow (overstimulation), neon anything

**Recommended Palette:**

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| **Primary** | Deep Teal | `#1A7A6D` | Buttons, links, active states |
| **Primary Light** | Soft Teal | `#2BA89A` | Hover states, highlights |
| **Secondary** | Warm Sand | `#F5E6D3` | Backgrounds, cards (light mode) |
| **Accent** | Coral Orange | `#E8734A` | CTAs, notifications, badges |
| **Neutral Dark** | Charcoal | `#2D2D2D` | Text (light mode) |
| **Neutral Light** | Off-White | `#FAFAF8` | Page background (light mode) |
| **Dark Mode BG** | Deep Navy | `#0D1B2A` | Background (dark mode) |
| **Dark Mode Surface** | Slate | `#1B2838` | Cards (dark mode) |

**Why not generic blue?** Every productivity app is blue (Notion, Todoist, Things, Trello). Teal is close enough to feel trustworthy but distinct enough to stand out in a folder of blue icons.

**Dark Mode Considerations:**
- Don't just invert colors — redesign surfaces
- Use `#0D1B2A` (deep navy) instead of pure black (less harsh on eyes)
- Reduce contrast slightly (white text on dark = `#E8E8E8`, not `#FFFFFF`)
- Accent color (coral) should pop equally in both modes

**Accessibility (WCAG 2.1 AA):**
- Primary text on background: minimum 4.5:1 contrast ratio
- Large text (18pt+): minimum 3:1
- Interactive elements: minimum 3:1 against adjacent colors
- Test with: WebAIM Contrast Checker, Stark (Figma plugin)

---

### Typography

**System Font: SF Pro (iOS)**
- Use San Francisco as the primary typeface — it's optimized for Apple devices, supports Dynamic Type, and costs nothing.
- Don't fight the platform. Custom fonts add load time and accessibility headaches.

**Type Scale:**

| Element | Weight | Size | Line Height | Usage |
|---------|--------|------|-------------|-------|
| **Title 1** | Bold | 28pt | 34pt | Screen titles |
| **Title 2** | Bold | 22pt | 28pt | Section headers |
| **Title 3** | Semibold | 20pt | 25pt | Card headers |
| **Body** | Regular | 17pt | 22pt | Primary text |
| **Callout** | Regular | 16pt | 21pt | Secondary text |
| **Caption** | Regular | 12pt | 16pt | Timestamps, metadata |

**ADHD Readability Principles:**
- Generous line height (1.3-1.5x font size)
- Short paragraphs (3-4 lines max)
- Left-aligned text (never justified — uneven spacing hurts ADHD readers)
- Clear visual hierarchy (users should scan, not read)
- Adequate whitespace between sections

---

### Logo & Wordmark

**Approach: Icon-First**
- The app icon IS the logo for most contexts (App Store, home screen, social)
- Create a simple wordmark for the landing page and marketing materials
- Font: SF Pro Display Bold or a clean geometric sans (Satoshi, General Sans)

**Wordmark Options:**
1. **"memo"** — All lowercase, friendly, approachable. Lowercase = casual, not corporate.
2. **"Memo"** — Title case, slightly more professional. Works for App Store listing.
3. **"memo."** — With period. Suggests completeness, finality ("it's done, it's saved").

**Scalability:**
- App Store: Icon only (no wordmark needed)
- Landing page: Wordmark + icon side by side
- Social media: Icon as profile pic, wordmark in cover/banner
- Future merch: Wordmark works on hats, stickers, shirts

---

## 2. Brand Voice & Personality

### Who is Memo?

**If Memo were a person, they'd be:**
- The friend who always remembers where you put your keys
- Calm when you're frantic
- Smart but never condescending
- Organized but not rigid
- Quietly confident

**Personality Traits:**
- ✅ Calm — Never makes you feel rushed or overwhelmed
- ✅ Intelligent — Finds things fast, understands context
- ✅ Friendly — Warm, conversational, human
- ✅ Reliable — Always there, always works
- ✅ Simple — Says more with less

**NOT:**
- ❌ Robotic — No "Your query returned 0 results"
- ❌ Corporate — No "We're excited to announce..."
- ❌ Overwhelming — No feature dumps, no 12-step onboarding
- ❌ Patronizing — No "Great job saving your first note! 🎉🎉🎉"
- ❌ Cute for cute's sake — No mascots, no excessive emoji

**Voice Guidelines:**
| Situation | ❌ Don't | ✅ Do |
|-----------|---------|------|
| Empty state | "No results found" | "Nothing here yet. Save something and it'll show up." |
| Error | "Error 404: Resource not found" | "Hmm, couldn't find that. Try a different search?" |
| Onboarding | "Welcome to Memo! Let's set up your account in 5 easy steps!" | "Let's get you set up. Takes about 30 seconds." |
| Success | "Item successfully saved to your collection!" | "Saved." |
| Upgrade | "Unlock premium features for just $9.99/month!" | "Want to search across all your apps? That's in Pro." |

---

### Messaging Hierarchy

**Tagline (Primary):**
> "One search bar for everything you've ever saved."

**Tagline Alternatives:**
- "Find anything. From anywhere. Instantly."
- "Your ideas, finally in one place."
- "Stop losing ideas."

**Value Props by Audience:**

| Audience | Pain Point | Memo's Answer |
|----------|-----------|---------------|
| **ADHD users** | "I saved it somewhere but can't find it" | "Search once, find everything — Telegram, Notion, voice memos, all in one place" |
| **Productivity nerds** | "I use 7 apps and nothing talks to each other" | "Memo connects your apps so you don't have to" |
| **Multi-app haters** | "I'm tired of switching between apps to find stuff" | "One app. One search bar. Done." |

**Feature Description Guidelines:**
- Lead with the benefit, not the feature
- ❌ "Telegram integration with bi-directional sync"
- ✅ "Save a Telegram message. Find it later with one search."
- Keep it to one sentence
- Use active voice ("Find your notes" not "Notes can be found")

---

## 3. UI Design Language

### Component Style

**Buttons:**
- Primary: Filled, rounded corners (12px), primary teal color
- Secondary: Outlined, same corner radius, subtle border
- Destructive: Coral/red, used sparingly
- Minimum tap target: 44x44pt (Apple HIG)
- Clear labels: "Save" not "Submit", "Search" not "Go"

**Cards:**
- Subtle shadow: `0 2px 8px rgba(0,0,0,0.08)` (light mode)
- Rounded corners: 12px (consistent with iOS 19)
- Padding: 16px internal
- Clear content hierarchy: title → preview → metadata
- Tap entire card to open (not just a tiny button)

**Input Fields:**
- Large tap targets (48pt height minimum)
- Clear placeholder text (not cryptic)
- Floating labels that move on focus
- Search bar: prominent, always accessible, top of screen

**Navigation:**
- Tab bar (bottom): 3-4 tabs max (Search, Capture, Library, Settings)
- No hamburger menus (hidden = forgotten for ADHD users)
- Predictable: same position, same behavior, every screen
- Back button always works as expected

---

### Micro-interactions

**Haptic Feedback:**
- Light tap: selecting items, toggling switches
- Medium impact: saving a note, successful search
- Success notification: completing onboarding, first capture
- Never: scrolling, navigating between tabs (too frequent = annoying)

**Animation Timing:**
- Enter/exit: 250-300ms (quick but perceptible)
- Spring animations: slight bounce for playfulness (dampingRatio: 0.7)
- Loading: skeleton screens, not spinners (less anxiety-inducing)
- Rule: if the animation makes you wait, it's too long

**Loading States:**
- Skeleton screens for content (gray blocks that match layout)
- Subtle shimmer animation (not distracting)
- Never block the entire screen — let users interact where possible

**Success/Error Feedback:**
- Success: brief checkmark animation + haptic (then dismiss)
- Error: inline red text below the field (not an alert popup)
- Warning: yellow banner at top (dismissable)
- Never: modal alerts for non-critical errors

---

## 4. Brand Consistency Checklist

- [ ] App icon uses primary color palette
- [ ] App icon works on light AND dark home screens
- [ ] Typography uses SF Pro consistently (no random custom fonts)
- [ ] All interactive elements meet 44pt minimum tap target
- [ ] Color contrast passes WCAG 2.1 AA on all surfaces
- [ ] Voice tone is consistent across onboarding, errors, empty states
- [ ] Animations use consistent timing (250-300ms)
- [ ] Dark mode is designed (not just inverted)
- [ ] Landing page matches app design language
- [ ] App Store screenshots match actual app UI
- [ ] Social media assets use same color palette
- [ ] Email communications match brand voice

---

## 5. Competitive Differentiation

### How Memo is Visually Different

| Competitor | Their Look | Memo's Difference |
|-----------|-----------|-------------------|
| **Notion** | Complex, white, overwhelming sidebar | Calm, one search bar, no sidebar |
| **Readwise** | Reader-focused, bookish, text-heavy | Universal (not just reading), visual |
| **Apple Notes** | Generic, system-default, forgettable | Distinctive teal palette, personality |
| **Saner.AI** | Corporate, blue, clinical | Warm, approachable, ADHD-designed |
| **Obsidian** | Dark, techy, graph-obsessed | Simple, non-technical, human |

### Visual Differentiation Tactics:
- **Unique color:** Teal + coral (no one in the space uses this combo)
- **Custom iconography:** Modified SF Symbols with consistent stroke weight and rounded caps
- **Branded empty states:** Illustrations or copy that feel uniquely Memo ("Nothing saved yet. Your future self will thank you.")
- **Branded error screens:** Not generic. "We lost your search but not your notes. Try again?"
- **Onboarding personality:** 3 screens max, conversational copy, skip button always visible

---

## 6. Resources & Tools

### Design
- **Figma** (free) — UI design, prototyping, icon design
- **SF Symbols 6** (free) — iOS icon library (600+ symbols)
- **Stark** (Figma plugin, free tier) — Accessibility checker

### Color
- **Coolors.co** — Palette generator
- **Realtime Colors** — Test palettes on a live website mockup
- **WebAIM Contrast Checker** — WCAG compliance
- **Happy Hues** — Curated color palette inspiration

### Typography
- **Apple HIG Typography** — SF Pro guidelines
- **Typescale.com** — Generate type scales

### Mockups & Assets
- **Rotato** — 3D device mockups for App Store screenshots
- **shots.so** — Quick mockup backgrounds
- **ScreenshotFramer** — App Store screenshot generator

### Inspiration
- **Mobbin** — Real app UI screenshots (search "note" or "search")
- **Dribbble** — Design concepts (filter by "mobile")
- **Refero** — Curated app design references

---

## Appendix: Brand Quick Reference

| Element | Value |
|---------|-------|
| **Primary Color** | Deep Teal `#1A7A6D` |
| **Accent Color** | Coral `#E8734A` |
| **Font** | SF Pro (system) |
| **Corner Radius** | 12px |
| **Tagline** | "One search bar for everything you've ever saved" |
| **Voice** | Calm, smart, friendly, brief |
| **Icon Style** | Search/convergence concept, subtle depth |
| **Tap Target** | 44pt minimum |
| **Animation** | 250-300ms, spring-damped |

---

*Last updated: March 2026*
*Document owner: CS*
