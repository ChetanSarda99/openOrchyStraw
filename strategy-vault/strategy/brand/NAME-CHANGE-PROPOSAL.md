# Name Change Proposal: Memo → Rekall

**Date:** March 15, 2026  
**Status:** PROPOSED (awaiting CS decision)

---

## Why Change the Name?

### The "Memo" Problem

1. **Domain unavailable:** `memo.app` is taken (owned by existing funded company, PitchBook profile exists). Aftermarket price: $5K-$50K+.
2. **SEO nightmare:** "Memo" is generic English word. You'll fight Apple's Memo app, Memo (the existing SaaS at $49.5/mo), getmemo.app (tasks/notes app in beta), heymemo.app (German vocab app), and every blog post that uses the word "memo."
3. **App Store collision:** Search "memo" on App Store → dozens of results. Your app drowns.
4. **Trademark risk:** Generic words are hard to trademark. An existing "Memo App" company with funding could challenge you.
5. **All alternative "memo" domains are taken:**
   - `memo.app` ❌ Owned, redirects to /lander
   - `getmemo.app` ❌ Active product (waitlist phase)
   - `heymemo.app` ❌ Active German app
   - `memoapp.co` ❌ Dead startup, parked domain
   - `trymemo.app` ❌ Returns 200
   - `mymemo.app` ❌ Returns 405
   - `memoapp.dev` ❌ Returns 403
   - `memo.so` 💰 For sale on Dynadot (price unknown)
   - `usememo.app` ⚠️ 404 on Vercel (abandoned but registered)

### Why "Rekall"

| Factor | Memo | Rekall |
|--------|------|--------|
| Domain | ❌ All taken | ✅ `rekall.app` UNREGISTERED |
| Uniqueness | 4+ competitors | Zero competitors |
| App Store SEO | Buried | Own it |
| Trademark | Weak (generic word) | Strong (invented spelling) |
| Memorability | Forgettable | "Total Rekall" — instant hook |
| Tagline potential | Weak | "Total Rekall for your digital brain" |
| Character count | 4 | 6 |
| Pronunciation | Clear | Clear (re-CALL) |

---

## Proposed New Identity

### Name: **Rekall**

### Tagline Options:
1. "Total Rekall for your digital brain"
2. "Save everything. Rekall anything."
3. "One search for everything you've saved"
4. "Your second brain, actually searchable"

### Domain: `rekall.app`
- Confirmed UNREGISTERED via DNS + WHOIS (March 15, 2026)
- `.app` TLD = Google-operated, HTTPS enforced, perfect for iOS apps
- Cost: ~$14-20/year

### Social Handles to Reserve:
- [ ] X/Twitter: @rekallapp
- [ ] Instagram: @rekallapp
- [ ] Reddit: r/rekallapp
- [ ] GitHub: rekall-app (or similar)
- [ ] TikTok: @rekallapp

---

## Publisher / Studio Brand

**Name:** Sarda Labs  
**Domain:** `sardalabs.com` (UNREGISTERED, confirmed March 15, 2026)

All apps published under "Sarda Labs" on Apple Developer + Google Play.

App Store listing: **"Rekall — Save Everything" by Sarda Labs**

---

## Other Available App Names (Backup Options)

All confirmed unregistered `.app` domains:

| Name | Domain | Vibe |
|------|--------|------|
| **Savd** | savd.app | Minimal, self-explanatory, 4 chars |
| **MindSift** | mindsift.app | Descriptive ("sift through your mind") |
| **Hoardr** | hoardr.app | Self-deprecating, relatable to ADHD |
| **BrainBin** | brainbin.app | Playful, "searchable junk drawer" |
| **CatchAll** | catchall.app | Descriptive but generic |
| **Ingest** | ingest.app | Technical/power-user vibe |

---

## What Changes in the Codebase

### Must Change
- App display name (Info.plist → `CFBundleDisplayName`)
- App Store metadata (name, subtitle, keywords, description)
- Landing page copy + domain
- All user-facing strings referencing "Memo" or "NoteNest"
- App icon (redesign for new brand)
- Onboarding screens

### Does NOT Change
- Internal code (module names, API routes, database schema)
- Architecture
- Features
- Backend infrastructure
- Tech stack

### Estimated Effort
- **Code changes:** 2-4 hours (mostly string replacements + plist)
- **Design changes:** 4-8 hours (new icon, updated screenshots, landing page)
- **Total:** 1 day of focused work

---

## Migration Checklist

If CS approves the rename:

### Immediate (Day 1)
- [ ] Register `rekall.app` domain (~$14-20)
- [ ] Register `sardalabs.com` domain (~$12)
- [ ] Reserve @rekallapp on X, Instagram, TikTok
- [ ] Reserve r/rekallapp on Reddit
- [ ] Update `CFBundleDisplayName` in Xcode project
- [ ] Update user-facing strings

### Week 1
- [ ] Design new app icon (The Search Lens or Convergence concept from APP_BRANDING.md, adapted for "Rekall")
- [ ] Update landing page copy + deploy to `rekall.app`
- [ ] Update App Store Connect listing (name, subtitle, keywords, description, screenshots)
- [ ] Update all docs that reference "Memo" in user-facing context
- [ ] Set up email: cs@sardalabs.com

### Week 2
- [ ] Create GitHub repo: `ChetanSarda99/rekall-app` (or rename existing `memo-app`)
- [ ] Update README, CLAUDE.md project name references
- [ ] Deploy studio website to `sardalabs.com`
- [ ] Set up Product Hunt maker profile

---

## Decision Required

CS needs to decide:

1. **Approve "Rekall"?** Or prefer one of the alternatives (Savd, MindSift, Hoardr, BrainBin)?
2. **Approve "Sarda Labs"?** Or prefer Empire Apps, Neuroship, etc.?
3. **When to rename?** Before launch (recommended) or after initial beta?

**Recommendation:** Rename BEFORE any public presence. Changing names after people know you is 10x harder.

---

## References

- Domain availability research: `~/Projects/archives/OpenClaw_Archive_Backup/workspace/empire-os/research/brand-setup-guide.md`
- Full marketing strategy: `~/Projects/archives/OpenClaw_Archive_Backup/workspace/empire-os/research/app-marketing-strategy.md`
- WHOIS/DNS checks performed: March 15, 2026
