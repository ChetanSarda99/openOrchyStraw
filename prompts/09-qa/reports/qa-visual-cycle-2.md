# QA Visual Audit — Cycle 2

**Date:** 2026-04-10 13:54
**Cycle:** auto/cycle-1-0410-1351
**Agent:** 09-qa-visual
**Mode:** Code audit + test-suite verification (no Chrome DevTools MCP / live browser in this harness — labeled as code audit per prompt rules)
**Verdict:** 🟡 **CONDITIONAL PASS** — cycle-1 critical regressions fixed, 3 findings remain (1 new, 2 carry-over MEDIUM), all priority dry-run flows clean

---

## Priority task results (from prompt)

| Task | Result |
|------|--------|
| **P0** `tests/core/run-tests.sh` | **44 passed, 0 failed** — 44 test files, zero regressions |
| **P1** `auto-agent.sh orchestrate --dry-run` | PASS — 12 agents scheduled, parallel groups computed, no side effects |
| **P1** `auto-agent.sh list` / `status` | PASS — 12 agents loaded, branch `auto/cycle-1-0410-1351` |
| **P1** `src/core/single-agent.sh` | PASS — `bash -n` clean, library module (sourced, not standalone); test-single-agent.sh + test-single-agent-v04.sh both PASS in suite |
| **P2** `scripts/benchmark/run-benchmark.sh --suite basic --dry-run` | PASS — 3 test cases enumerated (Fix calculator bugs, Create tests for user_auth, Update README) |

No regressions in the test suite vs cycle 21's baseline (44 → 44). No side effects from any dry-run flow.

---

## Cycle-1 visual findings — status re-check

All 7 findings from `qa-visual-cycle-1.md` re-verified against HEAD:

| ID | Severity | Status | Evidence |
|----|----------|--------|----------|
| VIS-001 | HIGH | ✅ **FIXED** | `docs-site/mint.json:29-33` → `"dark": "/logo.svg"`, `"light": "/logo.svg"`, `"favicon": "/logo.svg"`; `docs-site/public/logo.svg` exists |
| VIS-002 | HIGH | ✅ **FIXED** | `docs-site/mint.json:33` → `"troubleshooting"` listed under Getting Started nav group |
| VIS-003 | HIGH | ✅ **FIXED** | `grep 58a6ff assets/social/github/social-github-preview-1280x640.svg` → no matches |
| VIS-004 | HIGH | ✅ **FIXED** | `grep 58a6ff site/public/logo.svg docs-site/public/logo.svg` → no matches |
| VIS-005 | MEDIUM | 🟡 **STILL OPEN** | `assets/brand-guide.md:54-57` still references `assets/og-image.svg` and `assets/social-preview.svg` — neither file exists on disk |
| VIS-006 | MEDIUM | 🟡 **STILL OPEN** | `site/public/favicon.svg:7-9` still carries the `transform="translate(0,-5)"` hack with points at `y=37` (nets to `y=32`, bottom stroke clipped at viewBox edge) |
| VIS-007 | LOW | ⚠️ **PARTIAL** | Casing now consistent as `openOrchyStraw` in `docs-site/mint.json` + `social-github-preview-1280x640.svg` + `CLAUDE.md`. `prompts/09-qa/09-qa-visual.txt` still says `OrchyStraw` — cosmetic only |

**4 of 7 fixed (all HIGHs), 2 MEDIUMs carry over, 1 LOW cosmetic.** Confirmed via commit `2ea700a` ("Fix brand color regression + docs-site logo/nav wiring (#254, #255)").

---

## New findings (Cycle 2)

### VIS-008 — MEDIUM — `docs-site/concepts/modules.mdx` claims "35 modules" but documents only 31

**Found in:** `docs-site/concepts/modules.mdx:3` (front-matter description)
**Severity:** MEDIUM

The cycle's edit to `modules.mdx` bumps the description from *"20+ bash modules"* to **"35 bash modules that power OrchyStraw orchestration"**. `ls src/core/*.sh | wc -l` → `35`, so the count is correct, but the document itself never actually mentions 4 of those 35:

| Missing module | Expected section |
|----------------|------------------|
| `bash-version.sh` | Foundation (v0.1.0) |
| `cycle-tracker.sh` | Smart Cycle (v0.2.0) |
| `auto-improve.sh` | Global CLI & Model Selection (v0.5.0) |
| `auto-researcher.sh` | Global CLI & Model Selection (v0.5.0) |

Verification:
```bash
ls src/core/*.sh | xargs -n1 basename | sort > all.txt
grep -oE "[a-z-]+\.sh" docs-site/concepts/modules.mdx | sort -u > docs.txt
comm -23 all.txt docs.txt
# → auto-improve.sh, auto-researcher.sh, bash-version.sh, cycle-tracker.sh
```

**User-facing impact:** A reader lands on the Core Modules page, reads "reference for the 35 bash modules", then tries to find `bash-version.sh` (the portability gate that docs repeatedly reference elsewhere) and can't — documentation says 35 but delivers 31. Small credibility leak on the most technical page of the site.

**Fix path:** Add four `<Accordion>` blocks under the appropriate version sections. `bash-version.sh` exits if bash < 5.0 (Foundation). `cycle-tracker.sh` is referenced in CLAUDE.md cycle history (Smart Cycle). `auto-improve.sh` powers `--auto-improve` Karpathy loop, `auto-researcher.sh` is the research-first workflow automator — both Global CLI.

Accordion tag balance verified clean at time of audit: 31 open / 31 close, 5 `<AccordionGroup>` open / 5 close. No MDX structural issues.

**Assigned to:** 11-web (owns `docs-site/` per ownership convention)

---

## Checks that passed

- ✅ `bash -n` clean on all 35 `src/core/*.sh` modules
- ✅ Test suite: 44/44 (up from 23 in prior cycle task list, up from 44 in cycle-21 baseline — held flat, no regressions)
- ✅ `orchestrate --dry-run` enumerates all 12 agents with correct intervals and ownership paths, produces three parallel groups of up to 4, no side effects
- ✅ `list` and `status` commands match agents.conf (12 agents, correct ownership, PM last)
- ✅ `benchmark --suite basic --dry-run` runs cleanly, enumerates 3 test cases
- ✅ `docs-site/concepts/modules.mdx` MDX structure valid (31/31 Accordion balance, 5/5 AccordionGroup balance, all 14 unique `src/core/*.sh` references point to files that exist)
- ✅ No `#58a6ff` anywhere in tracked `assets/`, `site/public/`, `docs-site/public/` — only in `site/out/logo.svg` which is in `.gitignore` (stale build artifact, ignore)
- ✅ New `assets/branding/orchy-mascot.svg` renders on `#0a0a0a` brand background, uses a distinct mascot palette (purple/pink/green/amber) — deliberately off the blue brand axis, which is correct for a character asset, not a regression
- ✅ New `assets/demo.gif` + `assets/demo.tape` committed — cannot visually audit a binary gif via code audit, needs live playback (see Methodology note)
- ✅ `docs-site/mint.json` navigation: all 10 page entries (`introduction`, `quickstart`, `troubleshooting`, `concepts/*` ×5, `api/*` ×2) resolve to existing `.mdx` files

---

## Summary table

| Surface | Result |
|---|---|
| Test suite (44 files) | 🟢 PASS |
| `auto-agent.sh` dry-run / list / status | 🟢 PASS |
| `benchmark` dry-run | 🟢 PASS |
| `single-agent.sh` library | 🟢 PASS |
| Docs site logo + favicon wiring (VIS-001) | 🟢 FIXED |
| Docs site troubleshooting nav (VIS-002) | 🟢 FIXED |
| Brand color regression — social preview (VIS-003) | 🟢 FIXED |
| Brand color regression — landing + docs logos (VIS-004) | 🟢 FIXED |
| `assets/brand-guide.md` files table (VIS-005) | 🟡 STALE — references non-existent files |
| `site/public/favicon.svg` geometry (VIS-006) | 🟡 STILL CLIPPED |
| `docs-site/concepts/modules.mdx` module count (VIS-008) | 🟡 NEW — says 35, docs 31 |
| Casing sweep (VIS-007) | 🟢 mostly aligned, 1 cosmetic miss in prompt file |
| `orchy-mascot.svg` colors | 🟢 deliberate mascot palette, on `#0a0a0a` bg |

---

## Recommendation to 03-PM

**Conditional pass — ship it.** v0.5.0 core orchestration is healthy, all P0 gates clean. Two carry-over MEDIUMs (VIS-005, VIS-006) are the same assignments already routed in cycle 1 and have simply not been picked up yet by 11-web / 12-designer — not a blocker, but PM should re-surface them in next cycle's backlog so they don't calcify.

One new item to route:
- **VIS-008 → 11-web:** add 4 missing module accordions to `docs-site/concepts/modules.mdx` (bash-version, cycle-tracker, auto-improve, auto-researcher). ~30 min of work. Either that, or walk the front-matter count back to "31" — but the repo genuinely has 35 src/core modules, so adding the 4 entries is the right fix.

No findings severe enough to block v0.5.0 release or the current cycle's commits.

---

## Methodology note

This audit was **code audit** (not live visual QA), because the current harness has no Chrome DevTools MCP and no live browser. Per the two-types-of-visual-QA rule in this agent's prompt, the following still need a live visual QA pass on a real machine before the next launch:

1. `cd docs-site && npx mintlify dev` → screenshot sidebar, logo render, favicon in browser tab, troubleshooting page route (verify VIS-001/VIS-002 fixes render correctly)
2. Open `site/public/favicon.svg` at 16×16 and 32×32 in a real browser to visually confirm the VIS-006 stroke-clipping bug is visible (code review says it is; eyeballs say for sure)
3. Open `assets/demo.gif` in a real player to validate animation timing, caption legibility, and frame quality — binary gifs are invisible to code audit
4. Landing page: hero logo, dark-mode contrast, mobile viewport at 375px, OG preview at 1200×630
5. GitHub social preview: render `social-github-preview-1280x640.svg` at 1280×640 and verify `#3b82f6` on `#1e3a5f` has enough contrast for the agent-count badge after the VIS-003 color swap
6. `docs-site/concepts/modules.mdx` in Mintlify dev server: verify all 31 current accordions expand/collapse cleanly, check for any rendering glitches on the new v0.4/v0.5 sections added this cycle
