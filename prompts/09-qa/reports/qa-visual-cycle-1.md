# QA Visual Audit — Cycle 1

**Date:** 2026-04-10
**Cycle:** auto/cycle-1-0410-0232
**Agent:** 09-qa-visual
**Mode:** Code audit (no browser MCP available in this harness — labeled as code audit, not live visual QA per prompt rules)
**Verdict:** 🔴 **FAIL — 4 HIGH, 2 MEDIUM, 1 LOW** — docs site + GitHub social preview ship with broken/off-brand visuals

---

## Scope

Audited the visual surfaces that changed this cycle:

- `docs-site/` — `mint.json`, `introduction.mdx`, `quickstart.mdx`, `api/cli.mdx`, `concepts/modules.mdx`, new `troubleshooting.mdx`
- `assets/branding/` — 6 new logo SVGs (mark + wordmark, dark/light/mono)
- `assets/icons/` — 4 new favicon/icon SVGs (16/32/48/180)
- `assets/brand-guide.md`, `assets/README.md`
- `assets/social/github/social-github-preview-1280x640.svg` (modified this cycle)
- `site/public/` and `docs-site/public/` — existing logo & favicon

---

## Findings

### VIS-001 — HIGH — Docs site: mint.json points to logo files that don't exist
**Found in:** `docs-site/mint.json:4-8`, `docs-site/public/`
**Severity:** HIGH

`mint.json` declares:
```json
"logo": { "dark": "/logo/dark.svg", "light": "/logo/light.svg" },
"favicon": "/favicon.svg"
```

Actual contents of `docs-site/public/`:
```
docs-site/public/logo.svg
```
No `logo/dark.svg`, `logo/light.svg`, or `favicon.svg` anywhere under `docs-site/`.

**Impact:** When Mintlify builds and serves the site, the top-left logo and the browser tab favicon will both render as missing images. First-impression damage on the docs site.

**Fix path:** Either
1. Update `mint.json` to `"dark": "/logo.svg", "light": "/logo.svg", "favicon": "/logo.svg"`, or
2. Copy the new branding assets into `docs-site/public/logo/dark.svg`, `docs-site/public/logo/light.svg`, and `docs-site/public/favicon.svg`, sourced from `assets/branding/logo-mark-dark-512.svg`, `assets/branding/logo-mark-light-512.svg`, and `assets/icons/favicon-32.svg`.

**Assigned to:** 11-web (owns `site/`, `docs-site/` per agents.conf convention)

---

### VIS-002 — HIGH — Docs site: troubleshooting page is orphaned from navigation
**Found in:** `docs-site/mint.json:27-52`, `docs-site/troubleshooting.mdx`
**Severity:** HIGH

`docs-site/troubleshooting.mdx` is a well-written, 186-line user-facing troubleshooting guide (install issues, lock files, budget errors, AI CLI failures, dashboard problems). It is **not listed in any `navigation.pages` group in `mint.json`**.

**Impact:** Mintlify will not render the page in the sidebar. Users browsing the docs site will never discover it. From the user's perspective it doesn't exist. This directly hits the "production ready" bar: users hit install/runtime errors → docs site has the answer but can't be found.

**Fix:** Add a new navigation group (or extend Getting Started) in `mint.json`:
```json
{
  "group": "Getting Started",
  "pages": ["introduction", "quickstart", "troubleshooting"]
}
```

**Assigned to:** 11-web

---

### VIS-003 — HIGH — GitHub social preview ships with regression color `#58a6ff`
**Found in:** `assets/social/github/social-github-preview-1280x640.svg` (modified this cycle)
**Severity:** HIGH

`assets/README.md:35-37` is explicit:
> Older assets used `#58a6ff` (GitHub-style blue). All current sources in this directory use `#3b82f6` per the brand guide. **If you find `#58a6ff` in a new file, it's a regression — fix it.**

Every brand-colored element in this file uses `#58a6ff`:
- Background hexagon pattern (line 11)
- Logo mark hexagons + center node (lines 21-23)
- Three feature pills — "Markdown-first", "Zero dependencies", "Bash + AI" (lines 31-36)
- Agent count badge stroke + circle (lines 40-41)
- Bottom accent line (line 48)

This is the image GitHub renders when the repo is shared to Slack, Discord, Twitter, iMessage, Linear, anywhere link-unfurling happens. It is the single most-seen brand asset outside of the repo itself, and it's the wrong color.

**Fix:** Replace all occurrences of `#58a6ff` with `#3b82f6` in this file. Confirm the `#1e3a5f` agent-badge background still has sufficient contrast with `#3b82f6` after the swap.

**Assigned to:** 12-designer (owns `assets/`)

---

### VIS-004 — HIGH — Landing page + docs site logos both use regression color
**Found in:** `site/public/logo.svg:5-20`, `docs-site/public/logo.svg:5-20`
**Severity:** HIGH

Both public-facing logo files use `#58a6ff` on every stroke, fill, and accent line. Same regression as VIS-003 — the README calls it out explicitly as a bug.

**Impact:** The landing page hero logo and (if VIS-001 is fixed by wiring `/logo.svg`) the docs site logo will both ship in GitHub-blue instead of brand blue. Tauri app logos may also be affected — worth a sweep.

**Fix:** Replace `#58a6ff` with `#3b82f6` in both files. Prefer redirecting both `site/public/logo.svg` and `docs-site/public/logo.svg` to copies of `assets/branding/logo-mark-dark-512.svg` (which is already correct).

**Assigned to:** 11-web (owns `site/public/`, `docs-site/public/`)

---

### VIS-005 — MEDIUM — Brand guide "Files" table is stale
**Found in:** `assets/brand-guide.md:52-57`
**Severity:** MEDIUM

The brand guide lists these canonical files:
| Claimed path | Actual location |
|---|---|
| `site/public/logo.svg` | exists but off-brand (VIS-004) |
| `site/public/favicon.svg` | exists but has broken transform (VIS-006) |
| `assets/og-image.svg` | **does not exist** — real path is `assets/social/og/social-og-default-1200x630.svg` |
| `assets/social-preview.svg` | **does not exist** — real path is `assets/social/github/social-github-preview-1280x640.svg` |

The table also doesn't mention any of the 6 new `assets/branding/` files or 4 new `assets/icons/` files, which are now the sources of truth per `assets/README.md`.

**Fix:** Refresh the table to match the actual layout in `assets/README.md:7-22`. List the new branding + icon + social directories as authoritative.

**Assigned to:** 12-designer

---

### VIS-006 — MEDIUM — site/public/favicon.svg has geometry outside viewBox
**Found in:** `site/public/favicon.svg:7-9`
**Severity:** MEDIUM

```svg
<polygon points="16,10 28,17 28,30 16,37 4,30 4,17"
         ... transform="translate(0,-5)"/>
```
The front hexagon polygon has a point at `y=37` and then a `translate(0,-5)` — nets to `y=32`, right at the edge of the 32×32 viewBox. With `stroke-width="1.5"`, the bottom stroke is clipped. `assets/README.md:50` already flags this: *"the existing one has a broken transform outside the viewBox"*.

The new `assets/icons/favicon-32.svg` is geometrically clean (all points inside 0..32 with room for stroke) and should replace the site copy.

**Fix:** `cp assets/icons/favicon-32.svg site/public/favicon.svg`. Consider doing the same for `docs-site/public/favicon.svg` once VIS-001 wiring lands.

**Assigned to:** 11-web

---

### VIS-007 — LOW — Repo slug casing inconsistency
**Found in:** multiple
**Severity:** LOW

- `docs-site/mint.json` → `github.com/ChetanSarda99/openOrchyStraw`
- `assets/social/github/social-github-preview-1280x640.svg:46` → `github.com/ChetanSarda99/openOrchyStraw`
- `prompts/09-qa/09-qa-visual.txt` → `https://github.com/ChetanSarda99/OrchyStraw`
- `CLAUDE.md` → codebase is at `openOrchyStraw`

GitHub URLs are case-insensitive for routing so nothing breaks, but inconsistent casing leaks into search results, OG titles, and copy-paste command lines. Pick one and normalize.

**Assigned to:** 03-pm (prompt owner) — quick sweep to align.

---

## Checks that passed

- ✅ All 6 new `assets/branding/*.svg` files have correct viewBox (512×512 for marks, 1200×300 for wordmarks). Dark/light variants use `#0a0a0a` / `#fafafa` backgrounds per brand guide.
- ✅ All 4 new `assets/icons/*.svg` files have correct viewBox matching their dimensions (16, 32, 48, 180).
- ✅ New favicon-32 geometry is clean — all polygon points inside the viewBox, no transform hacks.
- ✅ `assets/README.md` directory layout matches filesystem (branding/, icons/, social/og|github|twitter|linkedin/, source/).
- ✅ `docs-site/concepts/modules.mdx` MDX syntax is valid — AccordionGroup/Accordion tags are balanced, code fences closed, new v0.4/v0.5 module docs well-formed.
- ✅ `docs-site/troubleshooting.mdx` content itself is high quality — covers install, bash version, locks, budget, agents standby, AI CLI, dashboard, logs. Only issue is that it's unlinked (VIS-002).
- ✅ Brand-guide color tokens in `assets/brand-guide.md:4-15` are internally consistent with `assets/README.md:26-34`. No color-token drift.
- ✅ No `#58a6ff` occurrences in the new `assets/branding/` or `assets/icons/` files. The designer-authored new assets are all on-brand — the regression is only in files the designer did not yet touch.

---

## Summary

| Surface | Result |
|---|---|
| New branding SVGs (mark, wordmark) | ✅ on-brand, correct geometry |
| New icon SVGs (16/32/48/180) | ✅ on-brand, correct geometry |
| `docs-site/troubleshooting.mdx` content | ✅ good |
| `docs-site/concepts/modules.mdx` content | ✅ good |
| `docs-site/mint.json` wiring | 🔴 broken logo/favicon (VIS-001) + orphaned page (VIS-002) |
| GitHub social preview SVG | 🔴 regression color throughout (VIS-003) |
| `site/public/logo.svg` + `docs-site/public/logo.svg` | 🔴 regression color (VIS-004) |
| `site/public/favicon.svg` | 🟡 broken transform (VIS-006) |
| `assets/brand-guide.md` file table | 🟡 stale (VIS-005) |
| Repo casing | 🟢 minor (VIS-007) |

**Root cause pattern:** the designer (12-designer) shipped beautiful new source assets in `assets/branding/` + `assets/icons/`, but the handoff to `site/public/` and `docs-site/public/` has not happened yet — per `assets/README.md:39-43` that handoff is 11-web's job. The orphaned troubleshooting page is a separate 11-web miss on the Mintlify nav.

**Recommendation to 03-PM:** create two coordinated tasks for next cycle — (1) 12-designer fixes the in-asset regressions (VIS-003, VIS-005), (2) 11-web does the public/ handoff + mint.json wiring (VIS-001, VIS-002, VIS-004, VIS-006). Both can run in parallel.

---

## Methodology note

This audit was code-only — the harness running this cycle has no Chrome DevTools MCP and no live browser. A follow-up live visual QA session should:
1. `cd docs-site && npx mintlify dev` → screenshot sidebar, logo, favicon, troubleshooting page route
2. Open `assets/social/github/social-github-preview-1280x640.svg` in a browser to confirm the color regression is visible at the rendered size
3. Load the landing page in `site/` and verify hero logo color
4. Screenshot at 1280×640 (GitHub social preview dimensions) and 1200×630 (OG default) to confirm platform rendering

Per QA Visual prompt rules (two types of visual QA, section at top), findings above are labeled **code audit**, not live visual QA.
