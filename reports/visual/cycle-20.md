# QA Visual Audit — Cycle 20 (fresh cycle 1 — 0410-0202)

**Date:** 2026-04-10
**Agent:** 09-qa-visual
**Scope:** Live visual QA of desktop app + landing site, plus build/test verification
**Verdict:** ⚠️ **CONDITIONAL PASS** — core flows work, 2 real bugs + 1 protocol violation

---

## Method

1. **Live visual QA** (primary) — Playwright 1.58.0 (chromium, headless) against running app server on `http://127.0.0.1:4321` and static landing export under `/openOrchyStraw/` basePath.
2. **Builds** — `npm run build` (site), `npx tsc --noEmit` (app).
3. **Tests** — `tests/core/run-tests.sh`.
4. **Code audit** (supplementary) — read `app/server.js`, `app/src/components/dashboard/*` to isolate root causes.

Screenshots: `reports/visual/cycle-20-screenshots/` (11 images, 1440×900 desktop + 390×844 mobile).

---

## What passed

### Builds & Tests (green)
| Surface | Result |
|---|---|
| `tests/core/run-tests.sh` | **44/44 PASS** (up from 23 cited in prompt — suite has grown) |
| `site && npm run build` | ✓ Next.js 16.2.0 / Turbopack, compiled in 2.6s, 4 static pages |
| `app && npx tsc --noEmit` | ✓ clean, exit 0 |

### App dashboard — live visual (Playwright headless)
All 6 sidebar views render without console errors or page errors:
- **Dashboard** — project cards, cycle stats (Status / Agents Active / Last Cycle), Live Activity panel
- **Agents** — full list, 12 agents with ownership + intervals visible
- **Chat** — agent picker dropdown populated from agents.conf
- **Logs** — level/agent filters + live tail
- **Config** — agents.conf editor rendering ID/LABEL/PROMPT PATH/OWNERSHIP/INTERVAL columns
- **Settings** — project path setter, scan directory, dark mode, model/API key fields

Dark theme consistent (#0a0a0a body bg). No broken images. Mobile viewport (390×844) reflows without horizontal overflow.

### Landing site — live visual
Built static export served under `http://127.0.0.1:3738/openOrchyStraw/` (GH Pages basePath):
- HTTP 200
- Title: `OrchyStraw — Multi-Agent AI Coding Orchestration`
- H1: `Multi-agent orchestration in pure bash`
- 8 `<section>` blocks rendered, 14 links, 0 broken images
- No pageerrors, no console errors when served at the correct basePath

---

## Bugs filed

### BUG-VQA-001 (MEDIUM): Dashboard shows 13 idle agents — phantom `09-qa` from test emitter
**Found in:** `src/pixel/test-emitter.sh:83-85` + `app/server.js:223` (readPixelEvents)
**Severity:** medium — cosmetic today, but masks real state when a cycle runs
**Steps to reproduce:**
1. `cd ~/Projects/openOrchyStraw && orchystraw app`
2. Open dashboard → observe "Agents Active 0 / 13" and "● 13 idle" in Live Activity
3. `curl -s 'http://127.0.0.1:4321/api/projects' | jq '.[0].agents_count'` → **12**
4. `curl -s 'http://127.0.0.1:4321/api/pixel-events?project=/Users/chetansarda/Projects/openOrchyStraw' | jq '.agents | length'` → **13**
5. `ls ~/.claude/projects/orchystraw-openOrchyStraw/` → contains a `09-qa/` directory alongside `09-qa-code/` and `09-qa-visual/`
**Expected:** dashboard reflects the 12 agents in agents.conf
**Actual:** dashboard reflects 13 — one for every subdirectory of `~/.claude/projects/orchystraw-<project>/`, regardless of whether the agent still exists in agents.conf
**Root cause chain:**
- `src/pixel/test-emitter.sh:83-85` hardcodes the agent ID `09-qa`, which was removed from agents.conf when it was split into `09-qa-code` + `09-qa-visual`.
- Running the emitter (during cycle 1 at 02:07 — confirmed by dir mtime) wrote `~/.claude/projects/orchystraw-openOrchyStraw/09-qa/session.jsonl` with synthetic content (`"Found bug: command needs \"double quotes\" + \\backslash\\"`).
- `app/server.js:readPixelEvents()` enumerates every subdir under the pixel project dir and adds each one as an agent, then merges agents.conf in on top — the stale `09-qa` never gets filtered out.
**Fix options (pick any 1 or combine):**
- (a) **08-pixel:** update `src/pixel/test-emitter.sh:83-85` to use `09-qa-code` (or a namespaced `-test` agent) instead of `09-qa`. Fastest fix.
- (b) **06-backend:** in `app/server.js:readPixelEvents()`, intersect pixel dirs with agents.conf IDs so unknown agents don't appear. Defensive fix.
- (c) **08-pixel:** delete the phantom dir at cycle start (`src/pixel/emit-jsonl.sh` or a hook) if its ID isn't in agents.conf.
**Assigned to:** 08-pixel (primary — option a), 06-backend (secondary — option b hardens server)

### BUG-VQA-002 (LOW): Landing site local preview breaks — basePath mismatch when served at root
**Found in:** `site/next.config.ts` + missing preview script in `site/package.json`
**Severity:** low — affects developer ergonomics, no production impact
**Steps to reproduce:**
1. `cd site && npm run build`
2. `python3 -m http.server 3737 --directory out`
3. Open `http://127.0.0.1:3737/` → HTML loads, but every JS chunk, CSS file, and font 404s (9 × 404 per page)
**Expected:** devs can preview the built site locally without manual workarounds
**Actual:** the build hardcodes `basePath: "/openOrchyStraw"` for GH Pages, and `next start` doesn't work with `output: "export"`, so the only way to preview is to copy `out/` into a `preview/openOrchyStraw/` subdir manually (verified: when served under the correct basePath, the page is clean — 0 × 404)
**Fix:** Add a `preview` script to `site/package.json`:
```json
"preview": "npm run build && rm -rf .preview && mkdir -p .preview && cp -r out .preview/openOrchyStraw && npx --yes serve -l 3737 .preview"
```
Or: make `basePath` conditional on `process.env.NEXT_PUBLIC_BASE_PATH` so `npm run dev` works naturally.
**Assigned to:** 11-web

---

## Protocol violation (escalated — not a bug)

**🚫 PROTECTED FILE MODIFICATION: `scripts/auto-agent.sh` has an uncommitted diff**
```
 --force) ORCH_FORCE_AGENTS=1; export ORCH_FORCE_AGENTS; shift ;;
+--smart-skip) ORCH_FORCE_AGENTS=0; export ORCH_FORCE_AGENTS; shift ;;
```
- `scripts/auto-agent.sh` is listed as PROTECTED per CLAUDE.md rule #5 and every agent prompt — agents MUST NOT touch it.
- I did not touch it. Whoever added `--smart-skip` was an agent violating its own lane.
- Auto-agent.sh is supposed to self-restore, so this may auto-revert on next cycle — but it means the restore logic either skipped this cycle or the edit happened after restore.
- **Escalated to:** CS (human owner). Options: (a) review & commit if desired, (b) `git checkout scripts/auto-agent.sh` to revert.
- Relates to BUG-012 and the PROTECTED FILES rule discussed in cycles 3–5.

---

## Secondary observations (not filed as bugs)

1. **Untracked branding assets** — `assets/branding/` contains 4 new SVG logo marks (dark/light/mono-black/mono-white, 512px). Looks like 12-designer output from a prior cycle. Not my lane to commit, but worth flagging to 12-designer / PM so they don't get lost.
2. **`alive` semantics are overloaded in `readPixelEvents`** (`app/server.js:270`). The JSON field `alive` is set to `isWorking` (`alive && lastTool && lastTool !== "idle"`). This works but conflates "process is running" with "agent is actively using a tool" — a future refactor could separate them, but it's not urgent.
3. **`CycleControl.tsx:49` vs `PixelAgents.tsx:121`** — Both compute an "active" count from the same pixel data but via slightly different predicates (`.alive` vs `.state === "working" && .alive`). Currently equivalent because of (2) above. If (2) gets refactored, these will diverge — file an ADR or unify both call sites into a `usePixelCounts()` hook at that time.

---

## Test data artifact to clean up

`~/.claude/projects/orchystraw-openOrchyStraw/09-qa/session.jsonl` — this is a stale pixel session dir. Suggested cleanup after BUG-VQA-001 fix lands:
```bash
rm -rf ~/.claude/projects/orchystraw-openOrchyStraw/09-qa
```
(09-qa-visual is NOT permitted to run destructive commands outside its ownership, so this is a recommendation, not an action.)

---

## Files in this report

```
reports/visual/
├── cycle-20.md                         ← this report
└── cycle-20-screenshots/
    ├── dashboard-desktop.png           ← app dashboard, 1440×900, dark
    ├── dashboard-mobile-390.png        ← app dashboard, 390×844
    ├── view-dashboard.png              ← /dashboard
    ├── view-agents.png                 ← /agents (12 rows visible)
    ├── view-chat.png                   ← /chat
    ├── view-logs.png                   ← /logs
    ├── view-config.png                 ← /config (agents.conf editor)
    ├── view-settings.png               ← /settings
    ├── view-00-Add_Project.png         ← Add Project modal
    ├── landing-desktop.png             ← site/, 1440×900
    └── landing-mobile.png              ← site/, 390×844
```

---

## Gate: CONDITIONAL PASS

- ✅ Builds, tests, and typecheck green across both surfaces.
- ✅ All 6 app dashboard views render without console/page errors on desktop + mobile.
- ✅ Landing site renders cleanly when served at the correct basePath.
- ⚠️ BUG-VQA-001 is visible to every user who opens the dashboard — should be fixed before the v0.5 demo / HN launch. Medium priority, 1-line fix in `test-emitter.sh`.
- ⚠️ BUG-VQA-002 is dev-ergonomics only — low priority, but easy win.
- 🚫 Protected-file breach requires CS triage before next release tag.
