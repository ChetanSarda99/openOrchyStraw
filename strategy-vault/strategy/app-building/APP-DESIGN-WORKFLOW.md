# App Building Best Practices — From Video Research
## Design-to-Code Workflow for Mobile Apps with AI

**Source:** "Design and Build a Mobile App from Start to Finish" — Starter Story Build, featuring Matia (Sleek Design)
**Created:** March 15, 2026
**Status:** Living document

---

## Table of Contents
1. [Research Phase](#1-research-phase)
2. [Design Principles](#2-design-principles)
3. [Illustration & Branding](#3-illustration--branding)
4. [AI-Powered Design Workflow](#4-ai-powered-design-workflow)
5. [Design to Code](#5-design-to-code)
6. [MVP Philosophy](#6-mvp-philosophy)
7. [Post-MVP Priorities](#7-post-mvp-priorities)
8. [Memo-Specific Applications](#memo-specific-applications)

---

## 1. Research Phase

**Core principle: Don't reinvent the wheel.**

### Competitor Revenue Research
- Use **Sensor Tower** to research competitor apps and their actual revenue numbers
- Look for apps making $50K+/month in your category — validates real demand
- Check revenue *before* building to confirm the market pays for this kind of app
- Revenue data tells you what users actually pay for, not what they say they want

### Design Research with Mobbin
- Use **Mobbin** as a design library of popular, shipping apps
- Study flows of top apps in your category (not just screenshots — full user journeys)
- Focus on onboarding flows, empty states, search patterns, settings screens

### Mood Board Construction
- Pick 2-3 competitor or reference apps
- For each reference, document explicitly:
  - **What you LIKE** — specific screens, interactions, color choices, layouts
  - **What you DON'T LIKE** — pain points, confusing flows, visual clutter
- Combine the best elements from multiple references with your own twist
- This becomes the design brief for AI-assisted design later

> **Memo application:** Research Readwise, Notion mobile, Apple Notes, Saner.AI, and Obsidian mobile on Mobbin. Document what works (Readwise's clean card layout, Notion's search) and what doesn't (Notion's overwhelming sidebar, Apple Notes' generic feel). Cross-reference with the competitive differentiation already documented in `APP_BRANDING.md`.

---

## 2. Design Principles

### Functional Before Beautiful
- Good design means **functional + beautiful**, not just beautiful
- Every design choice should serve a user goal
- If something looks great but confuses users, it fails

### Thumb-Reachable Actions
- Keep all primary actions in the **lower third** of the screen
- The top of the screen is for display (titles, status), not interaction
- Tab bars, primary CTAs, and frequent actions belong at the bottom
- This is especially critical on larger phones (iPhone 15 Pro Max, etc.)

### Gamification for Engagement
- Gamification elements measurably increase daily opens and session time
- Approaches that work: mascots, plant/garden growth metaphors, progress visualizations
- Not streak counters or guilt trips — engagement through delight, not anxiety

### Clean, Playful, Simple
- For habit/tracking/daily-use apps, simplicity wins
- Reduce visual noise — one primary action per screen
- Playful details (subtle animations, friendly copy) make apps feel alive without being cluttered

> **Memo application:** Memo's ADHD-first philosophy already aligns here. Key action items: ensure Search, Capture, and Quick Actions are all in the bottom nav / lower screen area. Consider whether a subtle progress metaphor (not a streak) could work — e.g., a growing "memory garden" that fills as you save more content. This must NOT feel like guilt or pressure.

---

## 3. Illustration & Branding

### Custom Illustration Strategy
- Custom illustrations and mascots make apps feel unique and personal
- Users develop attachment to mascots — they open the app to "see" the character
- Even simple illustrations (a friendly blob, an animal, a plant) work
- They differentiate from competitors who all look the same

### AI-Assisted Illustration Workflow
1. **Gather references** — Find 3-5 existing mascots/illustrations whose style you like
2. **Analyze style with AI** — Feed reference images into Gemini and ask it to describe the illustration style (line weight, color palette, shading technique, proportions)
3. **Generate with AI** — Use ChatGPT image generation with the style description as a prompt, request transparent backgrounds (PNG)
4. **Clean up in Figma** — Crop, adjust colors to match your palette, resize for different contexts
5. **Iterate** — Generate 5-10 variations, pick the best 2-3, refine further

### Consistency Rules
- Once you establish a style, stick to it across all illustrations
- Same line weight, same color palette, same level of detail
- Create a small illustration library (empty states, onboarding, error screens, success states)

> **Memo application:** The current branding doc (`APP_BRANDING.md`) explicitly says "no mascots, no excessive emoji." This is a conscious choice for Memo's calm, intelligent brand. However, the principle of custom illustration still applies — consider custom branded empty state illustrations and onboarding graphics that use the teal/coral palette. Not a mascot, but a consistent visual language (geometric shapes, abstract convergence visuals matching the icon concept).

---

## 4. AI-Powered Design Workflow

### Requirements Generation
- Take your mood board (liked/disliked elements from research) and feed it to AI
- Generate a structured requirements document that describes the design you want
- Include: color preferences, layout rules, component styles, screen list, user flows

### Parallel Generation for Variety
- Run the same design prompt **2-3 times in parallel** to get multiple options
- AI has inherent randomness — each run produces meaningfully different results
- Compare outputs side by side, pick the strongest one as your starting point
- Cherry-pick individual elements from different runs (header from run 1, cards from run 3)

### Iterative Refinement
- Start from the best generated option
- Refine specific sections with targeted follow-up prompts
- Don't try to get it perfect in one shot — iterate in focused rounds
- Each round should address one concern (spacing, colors, typography, etc.)

> **Memo application:** When designing new screens (PARA view, Schema Builder, Smart Collections), generate 2-3 AI layout variations in parallel. Pick the best and refine against Memo's design system. This is especially useful for screens where the right layout isn't obvious — let AI explore the possibility space, then apply Memo's constraints.

---

## 5. Design to Code

### The Pipeline
1. **Export design as code** — Get HTML/CSS or structured code from your design tool
2. **Feed into Claude Code** — Use the exported design code as a reference for generating the actual app code
3. **Use "ultra think"** — This keyword improves Claude Code's output quality on complex UI tasks
4. **Use a starter template** — Pre-configured project setup (navigation, auth, base components) so AI generates feature code, not boilerplate

### Double-Run Strategy
- Run the design-to-code conversion **twice** with the same input
- Compare both outputs — pick the one with better structure, fewer bugs, cleaner code
- Sometimes combine: navigation from run 1, component style from run 2
- This is cheap (just time) and significantly improves output quality

### Quality Control
- AI-generated code always needs a human review pass
- Check: accessibility (tap targets, contrast), animation performance, edge cases (empty states, long text, offline)
- Test on real devices, not just simulator — especially for haptics and scrolling

> **Memo application:** Memo uses Swift + SwiftUI (not React Native), so the HTML export step is less directly applicable. The principle still holds: when building new views, provide Claude Code with the existing design system (`MemoButton`, `MemoCard`, `MemoSearchBar`, `MemoTag` components) and the screen's requirements, then generate 2 versions and pick the better one. The "ultra think" tip applies directly to Claude Code sessions for Memo.

---

## 6. MVP Philosophy

### Speed Over Perfection
- The goal is **idea to working prototype in under a day** (for simple apps)
- Ship to validate demand, get real users, make first revenue
- Don't need Figma expertise, design agency, or expensive team
- AI tools have collapsed the design-to-code timeline dramatically

### Validate Revenue Before Building
- Check competitor revenue on Sensor Tower before writing a single line of code
- If no one in your category makes money, reconsider or find a different angle
- If competitors make $50K+/month, the market exists — now differentiate

### What "MVP" Actually Means
- Core value proposition works end-to-end
- One happy path is polished
- Edge cases can be rough
- Design doesn't need to be final — but it needs to be coherent
- Performance can be unoptimized — but it can't be broken

> **Memo application:** Memo's MVP is already 93% complete (53/58 issues). The takeaway here is for the remaining 7%: don't gold-plate. Ship TestFlight, get beta users, fix what they actually complain about. The design workflow above is more relevant for Phase 2 features (PARA view, Task Integration, Action System) where speed matters.

---

## 7. Post-MVP Priorities

### Onboarding is the First Priority After MVP
- Great onboarding is the single biggest lever for retention and conversion
- Study what works in top apps (see `APP_BUILDING_BEST_PRACTICES.md` for detailed onboarding framework)
- Test extensively — small changes yield large results (10% completion improvement = massive revenue impact)
- Onboarding should demonstrate value, not explain features

### App Store Submission
- Submit early, even if you'll iterate — the review process takes time to learn
- First submission often gets rejected for minor issues (metadata, screenshots, privacy policy)
- Use Transporter app for fast .ipa uploads (5 min vs 1-2 hours with alternatives)

### Continuous Iteration Loop
1. Ship MVP
2. Get users (ads, organic, TestFlight beta)
3. Watch the data (onboarding completion, retention, conversion)
4. Fix the biggest drop-off point
5. Ship update
6. Repeat every 2-3 days during growth phase

> **Memo application:** Memo's onboarding flow is already built (6-screen onboarding). Priority after Mac arrives: TestFlight submission, then instrument analytics on every onboarding screen to find drop-off points. The iteration loop above maps directly to the post-launch action items in `APP_BUILDING_BEST_PRACTICES.md`.

---

## Memo-Specific Applications

### Immediate Action Items

| Practice | Memo Action | Priority |
|----------|-------------|----------|
| Sensor Tower research | Check revenue of Readwise, Notion, Saner.AI | Before ads launch |
| Mobbin study | Document 5 competitor flows (search, capture, onboarding) | Pre-Mac |
| Mood board | Create Figma board with liked/disliked elements from competitors | Pre-Mac |
| Thumb-reachable design | Audit all screens — move primary actions to bottom third | During visual QA |
| Parallel AI generation | Use for Phase 2 screen designs (PARA, Schema, Collections) | Phase 2 |
| Double-run code gen | Run twice for complex SwiftUI views, pick better output | Ongoing |
| "Ultra think" keyword | Use in Claude Code sessions for complex UI | Ongoing |
| Custom illustrations | Design branded empty state graphics (not mascots) | Post-MVP polish |

### Research Template

For each competitor app studied, document:

```
## [App Name]
**Revenue (Sensor Tower):** $XX,XXX/mo
**Category rank:** #X

### Screens Studied
- Onboarding: [link to Mobbin or screenshots]
- Search: ...
- Empty states: ...

### What I LIKE
- [Specific element] — why it works
- [Specific element] — why it works

### What I DON'T LIKE
- [Specific element] — why it fails
- [Specific element] — why it fails

### Steal for Memo
- [Element to adapt] — how to make it ours
```

### Design-to-Code Workflow for Memo

Since Memo uses Swift + SwiftUI (not React Native), the adapted workflow is:

1. **Research** — Study competitor screen on Mobbin
2. **Mood board** — Document liked/disliked elements
3. **Requirements** — Write a clear screen spec (data shown, user actions, states)
4. **Generate** — Feed spec + existing Memo components into Claude Code, run twice
5. **Pick** — Compare outputs, select the better structure
6. **Refine** — Iterate on spacing, animations, edge cases
7. **Review** — Check against Memo design system (colors, typography, tap targets, accessibility)

---

## Key Takeaways

1. **Research before design** — Study competitors on Sensor Tower (revenue) and Mobbin (flows) before touching Figma or code
2. **Document likes AND dislikes** — A mood board without opinions is useless
3. **Thumb zone matters** — Primary actions in the bottom third of the screen, always
4. **AI gives variety, not perfection** — Run prompts 2-3 times in parallel, pick the best, iterate
5. **Double-run code generation** — Cheap insurance against AI inconsistency
6. **"Ultra think" for complex UI** — Better Claude Code results on layout-heavy tasks
7. **Starter templates save hours** — Pre-configured projects let AI focus on features, not boilerplate
8. **Validate revenue first** — Check Sensor Tower before building anything
9. **Onboarding is the #1 post-MVP lever** — Test relentlessly, small gains compound
10. **Ship fast, iterate faster** — Perfection is the enemy of learning from real users

---

## Related Docs
- `APP_BUILDING_BEST_PRACTICES.md` — Onboarding, paywall, ads, analytics (from Glow case study)
- `APP_BRANDING.md` — Visual identity, brand voice, UI language
- `APP_MINDSET.md` — Execution principles, MVP definition, decision framework
- `MARKETING_STRATEGY.md` — Go-to-market plan
- `ONBOARDING.md` — Onboarding flow details

---

**Last Updated:** March 15, 2026
**Owner:** CS
