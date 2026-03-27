# App Store Review Checklist
## Pre-TestFlight & Pre-Submission Guide

**Last updated:** March 22, 2026
**Sources:** Apple App Store Review Guidelines, Apple Developer Program License Agreement 3.3.1(B), RevenueCat rejection docs, 9to5Mac/The Information vibe coding crackdown (Mar 18, 2026)

---

## ⚠️ VIBE CODING & AI-GENERATED APPS (NEW — Mar 2026)

### What Happened
On March 18, 2026, Apple blocked updates for Replit and Vibecode — two "vibe coding" apps that let users create apps via AI prompts. This is NOT a ban on AI-assisted development. Apple's stance:

**What Apple is blocking:**
- Apps that dynamically generate and execute code at runtime (Guideline 2.5.2)
- Apps that change their functionality after passing App Store review
- Apps that let users create and run sub-apps inside a host app without review

**What Apple is NOT blocking:**
- Apps built WITH AI coding tools (Cursor, Claude Code, GitHub Copilot, Xcode AI)
- Native Swift/SwiftUI apps that happen to be AI-assisted in development
- Apps that USE AI APIs for features (Claude, GPT, etc.)
- Apple literally added Anthropic/OpenAI agentic coding support to Xcode 26.3

### The Key Guidelines
**Guideline 2.5.2:** "Apps should be self-contained in their bundles, and may not download, install, or execute code which introduces or changes features or functionality of the app."

**Developer Program License 3.3.1(B):** "Interpreted code may be downloaded to an Application but only so long as such code does not change the primary purpose of the Application by providing features or functionality that are inconsistent with the intended and advertised purpose."

### What This Means For Us
✅ **We're fine.** Building a native Swift/SwiftUI app with AI-assisted coding (Claude Code, Cursor, Xcode AI) is exactly how Apple wants you to build apps. The crackdown is on apps that ARE code generators, not apps MADE with code generators.

**To stay safe:**
- [ ] All app functionality is compiled into the binary — no runtime code generation
- [ ] AI features call external APIs (Claude, OpenAI) for data processing only — not for generating executable code
- [ ] App behavior doesn't change after review (no feature flags that unlock new screens)
- [ ] No WebView-based functionality that could be swapped server-side

---

## Top Rejection Reasons (ranked by frequency)

### 1. Performance: App Completeness (Guideline 2.1) — 40%+ of rejections
- App crashes during review
- Broken flows or dead-end screens
- Placeholder content ("Lorem ipsum", "Coming soon")
- Features that don't work without backend

**Checklist:**
- [ ] Every screen loads without crash
- [ ] Every button/tap target does something (no dead ends)
- [ ] No placeholder text anywhere
- [ ] Backend running and accessible during review
- [ ] Search returns real results (seed demo data if needed)
- [ ] All empty states show helpful messages (not blank screens)
- [ ] Onboarding flow completes without getting stuck

### 2. Metadata Accuracy (Guideline 2.3)
- App description matches actual functionality
- Screenshots show real app UI (not mockups)
- No "beta", "alpha", "v0.1" in app name or description

**Checklist:**
- [ ] App Store description matches what app actually does
- [ ] Screenshots from real device (not simulator with fake content)
- [ ] No "beta" suffix in app name
- [ ] Category selection matches app purpose
- [ ] Keywords accurate and relevant
- [ ] Preview video (if any) shows actual app experience

### 3. In-App Purchase (Guideline 3.1.1)
**Checklist:**
- [ ] All digital purchases use Apple's StoreKit (not custom payment)
- [ ] Subscription terms clearly stated before purchase
- [ ] Free tier is functional (not just a login wall)
- [ ] "Restore Purchases" button exists in Settings
- [ ] Trial terms visible on paywall screen
- [ ] Cancel instructions accessible
- [ ] Auto-renew disclosure present
- [ ] Full price, currency, and billing period shown

### 4. Privacy (Guideline 5.1.1) — STRICTER IN 2026
**Checklist:**
- [ ] Privacy policy URL hosted and linked in App Store Connect
- [ ] Every permission has clear purpose string explaining WHY
- [ ] App Privacy nutrition labels filled accurately
- [ ] All data collection disclosed: what, why, third parties
- [ ] If using AI APIs: disclose that content is processed by AI services
- [ ] User consent for AI processing (ideally during onboarding)
- [ ] If children could use the app: comply with COPPA/data limits
- [ ] Third-party SDKs that collect data must be disclosed

### 5. Design (Guideline 4.0) — HIGHER STANDARDS IN 2026
**Checklist:**
- [ ] Native SwiftUI components (NavigationStack, TabView, etc.)
- [ ] SF Symbols for icons
- [ ] Standard iOS gestures (swipe back, pull to refresh)
- [ ] Dark Mode supported
- [ ] Dynamic Type supported (no hardcoded font sizes)
- [ ] VoiceOver/accessibility works
- [ ] Good color contrast
- [ ] Works on smallest (iPhone SE) and largest (Pro Max) screens
- [ ] Must look like a native app — NOT a web wrapper

### 6. AI-Specific (Guideline 4.7 + 2026 Updates)
**Checklist:**
- [ ] AI features clearly labeled in UI (users know when AI is involved)
- [ ] AI-generated content NOT presented as human-written
- [ ] AI processing disclosed in App Privacy labels
- [ ] User consent for AI data processing
- [ ] Explain what AI does, what data it uses, how users can control it
- [ ] No misleading claims about AI capabilities

---

## TestFlight

### Internal Testing (no Apple review)
- Up to 100 internal testers
- Builds available immediately after upload
- Use for: compile verification, basic flow testing

### External Testing (Apple reviews the build)
- Up to 10,000 testers
- Apple reviews within 24-48 hours
- Must pass basic quality bar (no crashes, no placeholder content)
- Enable public TestFlight link for easy distribution

### Common TestFlight Mistakes
- [ ] Enable public TestFlight link
- [ ] Test on physical devices, not just simulator
- [ ] Test on oldest supported iOS version
- [ ] Test on smallest screen (iPhone SE) and largest (Pro Max)

---

## Pre-Submission Final Checks

### Technical
- [ ] No force unwraps that could crash
- [ ] No hardcoded API keys in client code
- [ ] Network error handling on every API call
- [ ] Offline state doesn't crash
- [ ] App handles backgrounding and foregrounding
- [ ] Memory usage under 200MB during normal use
- [ ] No private API usage
- [ ] Built with Xcode 26+ and latest iOS SDK

### Content
- [ ] All strings English-complete (localization optional for v1)
- [ ] No debug logging in production build
- [ ] No test/dev URLs in production
- [ ] Backend pointing to production URL
- [ ] Analytics pointing to production

### Legal
- [ ] Privacy policy URL in App Store Connect
- [ ] Terms of service URL
- [ ] EULA (can use Apple's standard)
- [ ] Age rating set correctly
- [ ] Export compliance answered (HTTPS only = "No")

---

## Review Notes Template

```
Demo Account:
Email: review@[yourapp].app
Password: [password]

To test key features:
1. Complete onboarding
2. [Core feature 1 — describe steps]
3. [Core feature 2 — describe steps]
4. [Core feature 3 — describe steps]

Backend: hosted on [provider] (running during review)
AI services: [list providers] for [describe usage]
```

---

## Best Practices for AI-Assisted Development (2026)

### Recommended Stack
- **Language:** Swift 6+ / SwiftUI
- **IDE:** Xcode 26+ (with Apple Intelligence coding features)
- **AI coding assistants:** Claude Code, Cursor, GitHub Copilot, Xcode AI — all fine to use
- **Architecture:** MVVM or MV (Apple's recommendation)
- **Minimum iOS:** 17.0+ (broad device coverage) or 18.0+ (if using newer APIs)

### What Makes Apple Happy
1. **Native everything** — SwiftUI over UIKit where possible, SF Symbols, system colors
2. **Apple frameworks first** — Use Foundation Models, CoreML, StoreKit 2, HealthKit natively before reaching for third-party
3. **On-device when possible** — Apple Intelligence for simple tasks, server AI for complex
4. **Privacy by design** — Minimal data collection, on-device processing, clear consent flows
5. **Accessibility built-in** — Dynamic Type, VoiceOver, high contrast from day 1
6. **No runtime code execution** — All functionality compiled into the binary

### What Gets You Rejected
1. ❌ WebView wrapper pretending to be native
2. ❌ Dynamic code execution or feature flags that change app behavior post-review
3. ❌ Missing or vague privacy labels
4. ❌ AI content presented as human-generated
5. ❌ Subscription dark patterns (hard to cancel, confusing pricing)
6. ❌ Crashes, placeholder content, broken flows
7. ❌ Not supporting Dark Mode / Dynamic Type in 2026
8. ❌ Misleading screenshots or descriptions

---

**Review this checklist before every submission.**
