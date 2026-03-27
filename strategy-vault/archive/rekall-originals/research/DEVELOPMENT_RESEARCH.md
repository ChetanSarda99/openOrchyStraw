# Development Research: Memo iOS App + Landing Page

> Last updated: 2026-03-12
> Compiled for solo development with Claude Code assistance

## Executive Summary

- **iOS Stack:** Swift + SwiftUI + SwiftData (offline-first) + MVVM with `@Observable`. Target iOS 17+ minimum. SwiftUI is mature enough in 2025-2026 for production apps — no need for UIKit unless hitting edge cases.
- **Landing Page Stack:** Astro + Tailwind CSS + shadcn/ui (or React components via Astro islands). Deploy on Vercel or Netlify. Astro ships zero JS by default = blazing fast landing pages.
- **ADHD Design:** Chunk everything. Predictable layouts. Low visual noise. Front-load value. Left-aligned text. Generous whitespace. Color-coded categories. User control over display preferences.
- **Claude Code Workflow:** CLAUDE.md is king. Plan Mode before complex features. Give Claude verification criteria (tests, screenshots). Use sub-agents for parallel work. Keep context windows fresh.
- **Anti-Slop Design:** Build a design system BEFORE coding. Collect 3-5 reference apps. Custom color palette + typography. Add micro-interactions. Personality in empty states, errors, loading. Treat AI as junior designer, not creative director.

---

## 1. Modern iOS Development (Swift + SwiftUI)

### Best Practices 2025-2026

- **Use `@Observable` macro** (iOS 17+) instead of `ObservableObject` — cleaner, better performance, automatic view tracking
- **SwiftData for persistence** — Apple's modern replacement for Core Data, production-ready as of 2025. Uses `@Model` macro, integrates natively with SwiftUI
- **Structured Concurrency** — Use `async/await` and `TaskGroup` for all async work. Swift 6.2 adds default actor isolation improvements
- **Minimum deployment target: iOS 17** — Gives access to `@Observable`, SwiftData, and modern SwiftUI APIs without losing too many users
- **iOS 18 additions:** Improved ScrollView APIs, fine-grained subview control, mesh gradients, new `@Entry` macro for custom environment values
- **WWDC 2025 (iOS 19/26):** SwiftUI performance instruments, Foundation Models API for on-device AI, 3D Charts, improved localization with `#Bundle` macro

### YouTube Tutorials & Courses

- **[100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui)** - Hacking with Swift (Paul Hudson) - Free, comprehensive curriculum. Best starting resource per Reddit consensus. Covers SwiftUI fundamentals through real projects.
- **[SwiftUI Fundamentals](https://www.youtube.com/watch?v=b1oC7sLIgpI)** - Sean Allen (YouTube) - Full beginner course, project-based. Covers `@State`, `@Binding`, `@StateObject`, data flow between views.
- **[Swiftful Thinking](https://www.youtube.com/c/SwiftfulThinking)** - YouTube Channel - Excellent for intermediate SwiftUI. Clean explanations, modern patterns.
- **[Hacking with iOS: SwiftUI Edition](https://www.youtube.com/playlist?list=PLuoeXyslFTuZRi4q4VT6lZKxYbr7so1Mr)** - Paul Hudson playlist - Video companion to the written tutorials.

### Blog Posts & Articles

- **[Offline-First SwiftUI with SwiftData](https://medium.com/@ashitranpura27/offline-first-swiftui-with-swiftdata-clean-fast-and-sync-ready-9a4faefdeedb)** - Ashit Ranpura, June 2025
  - SwiftData is production-ready in 2025
  - Shows clean offline-first architecture with sync readiness
  - Perfect pattern for Memo's note aggregation use case

- **[SwiftData vs Core Data: Which Should You Choose in 2025?](https://www.hashstudioz.com/blog/swiftdata-vs-core-data-which-should-you-choose-in-2025/)** - Hashstudioz, Sep 2025
  - New projects should use SwiftData
  - Core Data still valid for complex migration scenarios
  - SwiftData uses `@Model`, `@Query` macros — much less boilerplate

- **[SwiftUI Data Persistence in 2025](https://dev.to/swift_pal/swiftui-data-persistence-in-2025-swiftdata-core-data-appstorage-scenestorage-explained-with-5g2c)** - DEV Community, June 2025
  - Comprehensive comparison of all persistence options
  - Updated with WWDC 2025 changes
  - `@AppStorage` for settings, SwiftData for structured data

- **[What's New in SwiftUI for iOS 18](https://www.hackingwithswift.com/articles/270/whats-new-in-swiftui-for-ios-18)** - Paul Hudson
  - Scroll view improvements, text rendering control
  - Custom container APIs now public
  - Mesh gradients for rich visual effects

### Recommended Architecture

**MVVM with `@Observable`** — recommended for Memo.

| Pattern | Pros | Cons | Verdict |
|---------|------|------|---------|
| **MVVM + @Observable** | Simple, SwiftUI-native, low boilerplate, great with AI coding | Less structure for very complex apps | ✅ **Best for Memo** |
| **TCA (The Composable Architecture)** | Excellent testability, unidirectional data flow, time-travel debugging | Steep learning curve, verbose, Point-Free dependency | ❌ Overkill for solo dev |
| **MV (Model-View)** | Minimal code, Apple's own examples use this | Can get messy at scale | ⚠️ Too simple for Memo's aggregation logic |

**Why MVVM for Memo:**
- Claude Code understands MVVM patterns extremely well
- Clear separation: Model (SwiftData `@Model`), ViewModel (`@Observable` class), View (SwiftUI)
- Easy to test ViewModels independently
- Scales well for a note aggregation app with multiple data sources

### Key Architecture Decisions for Memo

```
Memo/
├── Models/          # SwiftData @Model classes
├── ViewModels/      # @Observable ViewModels
├── Views/           # SwiftUI views
│   ├── Components/  # Reusable UI components
│   ├── Screens/     # Full-screen views
│   └── Modifiers/   # Custom ViewModifiers
├── Services/        # API clients, importers, sync
├── Utilities/       # Extensions, helpers
└── Resources/       # Assets, colors, fonts
```

---

## 2. Modern Landing Page Development

### Best Practices 2025-2026

- **Ship fast, iterate** — a landing page is a marketing tool, not a product. Get it live in hours, not weeks
- **Mobile-first design** — 60%+ traffic is mobile. Design for thumb zones
- **Core Web Vitals matter** — LCP < 2.5s, CLS < 0.1, INP < 200ms. Static sites win here
- **Single CTA focus** — one primary action per viewport (waitlist signup)
- **Social proof early** — even "Join X others on the waitlist" with a counter
- **Email capture > full forms** — just email for waitlist. Reduce friction to zero

### Recommended Stack: Astro + Tailwind + React Islands

| Framework | Best For | JS Shipped | Deploy |
|-----------|----------|-----------|--------|
| **Astro** ✅ | Landing pages, marketing sites | Zero by default | Any CDN, Vercel, Netlify |
| Next.js | Full web apps with dynamic content | Full React runtime | Vercel (optimized) |
| SvelteKit | Interactive sites with minimal JS | Very small | Vercel, Netlify |

**Why Astro for Memo's landing page:**
- Ships **zero JavaScript by default** — 40% faster load times than Next.js for static content
- **Island architecture** — add interactive React/Svelte components only where needed (e.g., waitlist form)
- Perfect for a landing page that's 90% static content + 1 interactive email form
- Deploys to any CDN or Vercel/Netlify for free
- Claude Code generates excellent Astro code

### Component Libraries & Templates

- **[shadcn/ui](https://ui.shadcn.com/)** — Copy-paste React components. Use with Astro's React islands for the waitlist form
- **[Shadcn Landing Page Template](https://github.com/leoMirandaa/shadcn-landing-page)** — Free starter with hero, features, testimonials, CTA sections
- **[Waitly Template](https://shadcnuikit.com/template/waitly-free-waitlist-template)** — Free Next.js waitlist template with shadcn/ui
- **[Launch UI](https://www.launchuicomponents.com/)** — Professional landing page blocks built with shadcn/ui
- **[Page UI by Shipixen](https://pageui.shipixen.com/)** — Copy-paste landing page components for React/Next.js
- **[ShadcnBlocks](https://www.shadcnblocks.com/templates)** — Landing page templates available in both Next.js and Astro editions

### Waitlist Capture Best Practices

- **Email-only form** — single field, big button, zero friction
- **Resend or Loops for email** — modern transactional email services with free tiers
- **Confirmation page with share incentive** — "Move up the waitlist by sharing"
- **Store in database** — Supabase free tier or simple JSON API
- **Auto-respond** — immediate confirmation email builds trust
- **Show count** — "Join 847 others" creates social proof (even if small)

### Deployment

- **Vercel** — Best DX, automatic deploys from GitHub, free tier generous
- **Netlify** — Similar to Vercel, good for static sites
- **Cloudflare Pages** — Fastest CDN, unlimited bandwidth on free tier

---

## 3. ADHD-Focused Design

### Core UI/UX Principles (Evidence-Based)

Source: UXPA research, neurodiversity design literature, cognitive load theory

1. **Predictability** — Keep layout patterns consistent so attention isn't spent re-learning the page
2. **Chunking** — Break content into short, meaningful units that can be completed quickly
3. **Visible hierarchy** — Make structure obvious with headings, spacing, and lists
4. **Low distraction** — Reduce competing elements: no autoplay, minimal animation, clean sidebars
5. **User control** — Offer text size, spacing, and theme preferences
6. **Front-load value** — Put the most actionable content first. ADHD users abandon if payoff is slow
7. **Design for "resume reading"** — Users WILL be interrupted. Make it easy to pick up where they left off
8. **Progressive disclosure** — Show only what's needed now. Expandable sections > walls of content

### Color & Typography

**Typography:**
- Sans-serif fonts optimized for screen reading (SF Pro is excellent — it's Apple's system font)
- Body text: 16-18px minimum, generous line height (1.5-1.7)
- Left-aligned text (no justified — "rivers" of whitespace distract ADHD readers)
- Bold sparingly for key phrases. Avoid extensive italics
- Clear distinction between similar characters (I/l/1, O/0)
- Constrain text column width — long lines cause place-losing

**Color:**
- **Color-code categories** — Research shows strategic color use produces retention effect size of g+=0.53 (significant improvement)
- **Red/warm tones for action items** — Red improves detail-oriented task performance by 31% vs blue (UBC study)
- **Cool tones (teal, blue) for calm/reference content** — Reduces anxiety
- **Avoid red for health/clinical contexts** — Triggers anxiety
- **Ensure 4.5:1 contrast ratios minimum** — Accessibility AND readability
- **Semantic color tokens** — Don't just "primary/secondary" — name colors by meaning: `action`, `reference`, `warning`, `calm`

**Suggested Memo Palette Approach:**
- Warm accent for capture/action (amber/coral)
- Cool accent for reading/reference (teal/slate blue)  
- Neutral backgrounds with high contrast text
- Dark mode as first-class citizen (many ADHD users prefer it — less visual stimulation)

### Notification Strategies for ADHD

- **Opt-in, not opt-out** — Let users choose what to be notified about
- **Batch notifications** — Daily digest > constant pings
- **Gentle reminders, not alarms** — Soft language: "You saved 3 notes yesterday" not "You haven't opened the app!"
- **No guilt-tripping** — Zero streak mechanics that punish missing a day
- **Smart timing** — Respect Do Not Disturb, suggest review times based on usage patterns

### Gamification That Helps (Not Distracts)

- ✅ **Progress visualization** — Show notes processed, inbox zero progress
- ✅ **Gentle streaks** — "You've been consistent this week" (no punishment for breaks)
- ✅ **Completion satisfaction** — Satisfying animations when clearing inbox
- ❌ **No points/leaderboards** — Creates anxiety and comparison
- ❌ **No daily login rewards** — Builds unhealthy obligation
- ❌ **No notification spam** — Respect attention as a finite resource

### Resources

- **[Designing for ADHD in UX](https://uxpa.org/designing-for-adhd-in-ux/)** — UXPA research article
- **[ADHD Friendly Design: High-Legibility Tips for 2025](https://www.influencers-time.com/adhd-friendly-design-high-legibility-tips-for-2025/)** — Comprehensive typography and layout guide
- **[How Colour Coding Helps People With ADHD](https://recallify.ai/adhd-apps-colour-coding-recallify/)** — Evidence-based color coding with neuroscience citations
- **[Meta-analysis of colour effects on learning](https://www.sciencedirect.com/science/article/abs/pii/S1747938X17300581)** — Academic paper, effect size g+=0.53 for color-coded materials
- **[Mobbin](https://mobbin.com/)** — Real app screenshots. Search "ADHD", "notes", "productivity" for design patterns

---

## 4. Claude Code / AI-Assisted Development

### Best Practices (from Anthropic's Official Docs + Community)

**The CLAUDE.md File (Most Important Thing):**
- Create a `CLAUDE.md` in your project root — Claude reads it automatically
- Include: build commands, code style rules, architecture patterns, testing requirements
- Use sub-CLAUDE.md files in directories for module-specific context
- Keep it concise — Claude's context window fills fast

**Recommended CLAUDE.md structure for Memo:**
```markdown
# Memo iOS App

## Build & Run
- Xcode 16+, iOS 17+ target
- `cmd+B` to build, `cmd+R` to run in simulator

## Architecture
- MVVM with @Observable
- SwiftData for persistence
- Services layer for API/import logic

## Code Style
- SwiftUI views: keep under 100 lines, extract components
- ViewModels: @Observable classes, no Combine
- Use Swift concurrency (async/await), no completion handlers

## Testing
- Unit tests for ViewModels and Services
- UI tests for critical flows (capture, review, search)

## Key Patterns
- [describe your patterns as you build them]
```

**The Explore → Plan → Implement → Commit Workflow:**
1. **Explore** (Plan Mode): "Read /src/Models and understand the data model"
2. **Plan** (Plan Mode): "I want to add Telegram import. What files need to change? Create a plan."
3. **Implement** (Normal Mode): "Implement the Telegram import from your plan. Write tests. Run them."
4. **Commit**: "Commit with a descriptive message"

**Context Window Management (Critical):**
- Context fills fast — monitor usage
- Start new sessions for new features (don't let context degrade)
- Use `/clear` between unrelated tasks
- For large features, break into sub-tasks and use sub-agents

**Verification is Everything:**
- Always give Claude a way to verify its work: tests, screenshots, expected outputs
- "Write a function AND write tests AND run them" > "Write a function"
- UI changes: use screenshots for visual verification

**Prompt Engineering:**
- Reference specific files: "Look at `Models/Note.swift` and add a `source` property"
- Include constraints: "Don't use any third-party dependencies"
- Provide examples of desired patterns: "Follow the same pattern as `NoteViewModel`"

### Resources

- **[Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)** — Official Anthropic documentation (must read)
- **[7 Claude Code Best Practices for 2026](https://www.eesel.ai/blog/claude-code-best-practices)** — Field-tested patterns: CLAUDE.md, plan-then-execute, git workflows, sub-agents
- **[Writing a Good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)** — HumanLayer guide on structuring project context files
- **[How I Structure Claude Code Projects](https://www.reddit.com/r/ClaudeAI/comments/1r66oo0/how_i_structure_claude_code_projects_claudemd/)** — Reddit community post: profiles, preferences, decisions, sessions approach
- **[Beginner's Guide to Building Apps with Claude Code](https://www.sidetool.co/post/beginner-s-guide-to-building-apps-with-claude-code)** — Step-by-step for first-time users
- **[Claude Code Best Practices Compilation](https://rosmur.github.io/claudecode-best-practices/)** — Community-curated from multiple sources, includes Master-Clone architecture pattern

### Pro Tips for Memo Development

1. **Start with data models** — Define your SwiftData `@Model` classes first. Everything flows from there.
2. **One feature per session** — Fresh context = better code. Don't try to build the whole app in one conversation.
3. **Let Claude write tests early** — "Before implementing, write the test cases we'll use to verify this works"
4. **Use Plan Mode for architecture decisions** — "Compare these two approaches for import handling. Which is better and why?"
5. **Commit often** — Small, descriptive commits. Makes it easy to revert if Claude goes sideways.

---

## 5. Styling & Component Libraries

### iOS (SwiftUI)

**SF Symbols (6,000+ icons, free from Apple):**
- Use `Image(systemName: "note.text")` — massive built-in icon library
- Supports multicolor, hierarchical, and palette rendering modes
- Automatically adapts to dark mode, accessibility settings, and Dynamic Type
- Download [SF Symbols app](https://developer.apple.com/sf-symbols/) to browse
- [Complete Guide to SF Symbols](https://www.hackingwithswift.com/articles/237/complete-guide-to-sf-symbols) — Hacking with Swift

**SwiftUI Native Components:**
- SwiftUI IS the component library — `List`, `NavigationStack`, `TabView`, `Sheet`, `Form`
- Straying from Apple's components = fighting accessibility and screen size support
- Customize Apple components rather than building from scratch
- Use `.tint()`, `.foregroundStyle()`, `.font()` for theming

**Dark Mode:**
- Use semantic colors: `Color.primary`, `Color.secondary`, `Color(.systemBackground)`
- Define custom colors in Asset Catalog with dark mode variants
- Test in both modes constantly — SwiftUI previews support this natively
- [Dark Mode and Accessibility Guide](https://designcode.io/swiftui2-dark-mode-and-accessibility/) — Design+Code

**Third-Party Libraries (Use Sparingly):**
- **Nuke** — Image loading/caching (if fetching remote images)
- **SwiftUIX** — Extended SwiftUI components for edge cases
- Prefer Apple-native solutions. Fewer dependencies = fewer problems with AI coding.

### Web / Landing Page

**Tailwind CSS:**
- Utility-first CSS framework. Claude Code writes excellent Tailwind
- v4 (2025) is faster with Rust-based engine
- Perfect for rapid prototyping while maintaining consistency

**shadcn/ui:**
- Not a traditional component library — copy-paste components into your project
- Full control over styling. No dependency lock-in
- Built on Radix UI primitives (accessible by default)
- Works with Astro via React islands

**Animation:**
- **Framer Motion** — Declarative React animations (use in Astro islands)
- **CSS animations** — Prefer for simple transitions (zero JS overhead)
- **View Transitions API** — Native browser page transitions (Astro supports this)

### Recommended Approach for Memo

**iOS App:**
1. Use SF Symbols for all icons
2. Build a custom color system in Asset Catalog (light + dark variants)
3. Create a small set of reusable SwiftUI components: `MemoCard`, `SourceBadge`, `NotePreview`
4. Use Apple's native components as base, customize with modifiers
5. Define typography scale: title, headline, body, caption — using SF Pro (system font)

**Landing Page:**
1. Astro + Tailwind CSS for the static site
2. One React island for the waitlist signup form (shadcn/ui `Input` + `Button`)
3. Custom color tokens matching the iOS app palette
4. Framer Motion for subtle entrance animations
5. System font stack (fast loading) or one custom variable font max

---

## 6. Quick Start Checklist

### iOS App

- [ ] Install Xcode 16+ from Mac App Store
- [ ] Create new SwiftUI project targeting iOS 17+
- [ ] Set up Git repo + `CLAUDE.md`
- [ ] Define SwiftData `@Model` classes for Note, Source, Tag
- [ ] Build basic MVVM structure (Models/, ViewModels/, Views/)
- [ ] Read: [100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui) (at least Days 1-25 for foundations)
- [ ] Read: [Offline-First SwiftUI with SwiftData](https://medium.com/@ashitranpura27/offline-first-swiftui-with-swiftdata-clean-fast-and-sync-ready-9a4faefdeedb)
- [ ] Download SF Symbols app
- [ ] Set up custom Asset Catalog colors (light + dark)
- [ ] Create first screen: Note list with basic CRUD

### Landing Page

- [ ] `npm create astro@latest memo-landing`
- [ ] Add Tailwind CSS: `npx astro add tailwind`
- [ ] Add React integration: `npx astro add react`
- [ ] Install shadcn/ui components for the form
- [ ] Build single-page landing: Hero, Problem, Solution, Waitlist CTA, Footer
- [ ] Set up Vercel deployment from GitHub
- [ ] Add email capture (Resend / Loops / Supabase)
- [ ] Add basic analytics (Plausible or Vercel Analytics — privacy-friendly)
- [ ] Test on mobile devices
- [ ] Add og:image and meta tags for social sharing

---

## 7. Must-Read Resources (Top 5, Ranked)

1. **[Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)** — Read this FIRST. It's your workflow bible for building with AI assistance. Understanding context management alone will save you hours.

2. **[100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui)** — Free, comprehensive SwiftUI education. Even doing Days 1-30 gives you enough foundation to build Memo's core with Claude Code filling the gaps.

3. **[ADHD Friendly Design: High-Legibility Tips for 2025](https://www.influencers-time.com/adhd-friendly-design-high-legibility-tips-for-2025/)** — Your design north star. Every UI decision in Memo should pass through these principles.

4. **[How to Break the AI-Generated UI Curse](https://dev.to/a_shokn/how-to-break-the-ai-generated-ui-curse-your-guide-to-authentic-professional-design-2en)** — Critical reading before you start designing. The 5-Layer Authenticity Stack is your anti-slop playbook.

5. **[Offline-First SwiftUI with SwiftData](https://medium.com/@ashitranpura27/offline-first-swiftui-with-swiftdata-clean-fast-and-sync-ready-9a4faefdeedb)** — Directly applicable architecture pattern for Memo's core data layer.

**Bonus:** Bookmark [Mobbin](https://mobbin.com/) for real-world design inspiration and [SF Symbols](https://developer.apple.com/sf-symbols/) for icons.

---

## 8. Avoiding "AI Slop" Design

### What Makes Design Look Generic

**Visual Red Flags (the "AI Look"):**
- Overly perfect gradients with no character or meaning
- Color palettes from the same 5 trending combinations (purple-to-blue gradient, anyone?)
- Card-based layouts that feel identical to every other app
- Spacing that's mathematically perfect but emotionally cold
- Stock-photo-esque illustrations or generic 3D blob art
- Generic Material/Feather icons instead of thoughtful icon choices
- Default system fonts with no typographic hierarchy
- Centered-everything layouts with no visual tension

**Interaction Red Flags:**
- Zero micro-interactions — buttons that don't respond, lists that don't animate
- Template-driven user flows with no contextual intelligence
- Copy-paste navigation patterns regardless of use case
- Generic loading spinners instead of contextual skeleton screens
- No personality in empty states, errors, or onboarding

**Copy Red Flags:**
- "Streamline your workflow" / "Boost your productivity" / "All-in-one solution"
- Generic value propositions that could describe any app
- Error messages like "An error occurred. Please try again."
- No voice, no humor, no humanity

> Source: [How to Break the AI-Generated UI Curse](https://dev.to/a_shokn/how-to-break-the-ai-generated-ui-curse-your-guide-to-authentic-professional-design-2en)

### How to Add Personality

**The 5-Layer Authenticity Stack:**

1. **Visual Identity Beyond Templates**
   - Create a custom color palette BEFORE coding. Use [Realtime Colors](https://www.realtimecolors.com/) to preview
   - Pick ONE typeface pairing and commit to it. SF Pro for the iOS app is fine — customize weights and sizes intentionally
   - Create semantic color tokens named by meaning: `memo.capture`, `memo.review`, `memo.source.telegram`
   - Define a consistent border radius system (e.g., 8px for cards, 12px for modals, full for pills)

2. **Micro-Interactions That Matter**
   - Button press feedback (scale + haptic)
   - Satisfying swipe-to-archive animation
   - Subtle bounce when a new note arrives
   - Shimmer loading placeholders instead of spinners
   - Spring animations on navigation transitions
   - [Micro-Interactions in SwiftUI](https://dev.to/sebastienlato/micro-interactions-in-swiftui-subtle-animations-that-make-apps-feel-premium-2ldn) — 7 polished examples with code

3. **Personality Injection Points**
   - **Empty states:** "No notes yet. Your future self will thank you for what you capture here." (not "No data found")
   - **Error messages:** "Hmm, that didn't work. Mind trying again?" (not "Error: Invalid input")
   - **Loading states:** "Brewing your notes..." or contextual skeleton screens
   - **Onboarding:** Guide with enthusiasm, show the magic moment fast
   - **Success moments:** Satisfying completion animations when inbox hits zero

4. **Contextual Layout Intelligence**
   - Design layouts that respond to CONTENT, not just screen size
   - A note from Telegram should feel different from a note from voice memo
   - Use source-specific visual cues (color accents, icons) to add information density without clutter

5. **Copy With a Voice**
   - Define Memo's voice: helpful, calm, slightly warm. Not corporate, not quirky-for-the-sake-of-it
   - Write your own microcopy — this is where personality lives
   - AI can draft copy, but the final voice should be yours

### Examples of Well-Designed Indie Apps

Study these for inspiration — what makes them NOT feel generic:

- **[Things 3](https://culturedcode.com/things/)** — Task manager. Masterclass in restraint. Custom typography, intentional whitespace, delightful animations. Feels handcrafted.
- **[Bear](https://bear.app/)** — Notes app. Warm color palette, beautiful Markdown rendering, custom icons. Personality without being loud.
- **[Structured](https://structured.app/)** — Day planner. Visual timeline approach, bold colors, satisfying interactions. Won Apple Design Award.
- **[Flighty](https://flighty.com/)** — Flight tracker. Stunning custom UI, aviation-inspired design language. Every element is intentional.
- **[Ivory](https://tapbots.com/ivory/)** — Mastodon client. Custom design system built over years. Proves you can have personality within iOS conventions.
- **[Carrot Weather](https://www.meetcarrot.com/weather/)** — Weather app. Strong voice/personality in copy. Proves an app can be functional AND have character.
- **[Halide](https://halide.cam/)** — Camera app. Custom controls that feel premium. Shows what thoughtful interaction design looks like.

**What they all share:** Intentional constraints. They don't try to do everything — they do their thing with obvious care.

> Browse real app screenshots at [Mobbin](https://mobbin.com/) and [Muzli iOS Gallery](https://muz.li/inspiration/ios-app-examples/)

### Practical Tips for Solo Developers

**Before You Write Any Code:**
1. Collect 3-5 reference apps that nail the vibe you want for Memo
2. Screenshot specific screens you love. Annotate WHY (color? spacing? typography? animation?)
3. Create a mini style guide: colors, fonts, spacing scale, border radii, shadow styles
4. Write Memo's voice in 2-3 sentences. Reference it when writing any user-facing copy

**When Working with Claude Code:**
1. **Never accept the first UI output** — Always iterate. "Make this feel more X" or "This looks too generic, try Y"
2. **Provide visual references** — "Make this card look more like Bear's note cards — warm, generous padding, subtle shadow"
3. **Build your design system as SwiftUI components first** — Then Claude uses YOUR components, not generic ones
4. **Create a `/Design` folder with your style guide** — Reference it in CLAUDE.md so Claude always knows your visual language
5. **Review generated UI with fresh eyes** — After Claude builds a screen, step back and ask: "Would I screenshot this and share it? Does this look like 50 other apps?"

**When to Break the Rules:**
- When the "standard" pattern feels wrong for ADHD users — trust your instinct over convention
- When Apple's default component looks exactly like every other app — customize it
- When "best practice" produces boring output — personality > perfection

**Design Resources for Non-Designers:**
- **[Refactoring UI](https://www.refactoringui.com/)** — Book by Tailwind creators. Practical design tips for developers. Worth every penny.
- **[Mobbin](https://mobbin.com/)** — Real app screenshots with search. Your daily design inspiration.
- **[Dribbble](https://dribbble.com/)** — Search "iOS app" or "note app" for polished concepts
- **[Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)** — Know the rules so you can break them intentionally
- **[Typescale](https://typescale.com/)** — Generate harmonious font size scales
- **[Realtime Colors](https://www.realtimecolors.com/)** — Preview color palettes on a real website layout
- **[Coolors](https://coolors.co/)** — Generate and lock custom color palettes

### The Anti-Slop Checklist

Before shipping any screen, ask:

- [ ] Could this screen belong to ANY app, or is it clearly Memo?
- [ ] Is there at least one micro-interaction that feels delightful?
- [ ] Does the empty state have personality (not "No items")?
- [ ] Are the colors intentional and named semantically?
- [ ] Does the copy sound like a human, not a corporate chatbot?
- [ ] Would I screenshot this and show someone?
- [ ] Is there ONE thing on this screen that surprises or delights?

---

## Appendix: Tech Stack Summary

| Layer | Choice | Reasoning |
|-------|--------|-----------|
| **iOS Language** | Swift 6 | Only option for native iOS, excellent with AI coding |
| **iOS UI** | SwiftUI | Modern, declarative, great for rapid development |
| **iOS Persistence** | SwiftData | Apple-native, offline-first, replaces Core Data |
| **iOS Architecture** | MVVM + @Observable | Clean, testable, AI-friendly |
| **iOS Min Target** | iOS 17 | Access to @Observable, SwiftData |
| **Landing Framework** | Astro | Zero JS default, fastest static sites |
| **Landing Styling** | Tailwind CSS v4 | Utility-first, excellent AI generation |
| **Landing Components** | shadcn/ui (React islands) | Copy-paste, full control, accessible |
| **Landing Deploy** | Vercel | Free tier, GitHub integration, fast CDN |
| **Email Capture** | Resend | Modern API, generous free tier |
| **Analytics** | Plausible | Privacy-friendly, lightweight |
| **Version Control** | Git + GitHub | Standard, integrates with Claude Code |
| **AI Coding** | Claude Code | Best for Swift/SwiftUI, understands MVVM |
