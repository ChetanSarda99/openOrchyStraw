# Shared Context — Cycle 1 — 2026-03-18 10:54:47
> Agents: read before starting, append before finishing.

## Usage
- API status: 0 (0=ok, 80=overage, 90+=limited)

## Progress (last cycle → this cycle)
- Previous cycle: ? (? backend, ? frontend, ? commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- Built 7 sourceable bash modules in `src/core/` for v0.1.0 orchestrator hardening:
  - `logger.sh` — structured logging with levels (DEBUG/INFO/WARN/ERROR/FATAL), cycle log files, color output
  - `error-handler.sh` — agent crash handling, failure tracking, retry logic (max 2), diagnostics capture
  - `cycle-state.sh` — persist/resume cycle count across restarts via `.orchystraw/cycle-state`
  - `agent-timeout.sh` — per-agent configurable timeout with SIGTERM→SIGKILL escalation
  - `dry-run.sh` — `--dry-run` flag shows what would run without spawning agents
  - `config-validator.sh` — validates agents.conf syntax (field count, duplicates, prompt existence, intervals)
  - `lock-file.sh` — prevents multiple orchestrators via `.orchystraw/orchestrator.lock` with stale PID detection
- All modules: syntax-checked, double-source guarded, no external dependencies, bash 5.x
- NEED: Human to integrate these into `auto-agent.sh` via `source src/core/*.sh` (protected file)
- TODO next cycle: Address Security findings (HIGH-01 eval fix, MEDIUM-01 .gitignore, MEDIUM-02 notify escape)
- TODO next cycle: Bash version check (CTO P0), fix ownership overlap

## iOS Status
- (fresh cycle)

## Web Status (11-web)
- Built landing page MVP in `site/` — Next.js 16 + Tailwind v4 + Framer Motion + Lucide React
- All 6 sections built: Hero (with terminal demo), Supported Tools, How It Works (3-step), Features Grid (6 cards), FAQ (accordion), Footer
- Dark mode first (#0a0a0a), accent color orange (#f97316), Geist + Geist Mono fonts
- Static export configured (`output: "export"` in next.config.ts)
- Build verified — compiles and generates static pages successfully
- Files created: `site/src/components/{hero,how-it-works,features,supported-tools,faq,footer}.tsx`, `site/src/app/{page,layout}.tsx`, `site/src/app/globals.css`
- NOTE: Acknowledging CEO standby directive — landing page MVP complete, ready for review when v0.1.0 ships
- NEED: Logo/branding assets in `assets/branding/` (currently using text-only logo)
- NEED: Deploy setup (Vercel or GitHub Pages) after v0.1.0

## Design Status
- Built Phase 1 Synthetic JSONL Emitter: `src/pixel/emit-jsonl.sh` (sourceable bash library)
- Emits Pixel Agents-compatible JSONL events per agent to `~/.claude/projects/orchystraw/<agent>/session.jsonl`
- Full API: pixel_init, pixel_emit, pixel_say, pixel_end + convenience wrappers (pixel_agent_start/coding/pm_visit/done)
- Test script: `src/pixel/test-emitter.sh` — simulates 3-agent cycle, all 28 JSONL events validate
- Integration guide: `src/pixel/INTEGRATION.md` — shows how to wire into auto-agent.sh
- NEED: 06-backend to add `source src/pixel/emit-jsonl.sh` + lifecycle calls in auto-agent.sh (when unfrozen)
- Config: `PIXEL_ENABLED=0` to disable, `PIXEL_SESSION_DIR` to customize output path
- NOTE: Acknowledging CEO standby directive — Phase 1 complete, entering standby until v0.1.0 ships

## QA Findings
- Full QA cycle 1 complete — report at `prompts/09-qa/reports/qa-cycle-1.md`
- Found 7 bugs: 2 critical, 3 high, 2 medium
- CRITICAL: 5 agents (04, 05, 07, 12, 13) have prompts but are NOT in agents.conf — they will never run
- CRITICAL: CLAUDE.md lists 11 agents and paths that don't exist yet (src-tauri/, ios/, site/)
- HIGH: Ownership mismatches between agents.conf and prompt files (CEO, CTO, Backend, QA, Security)
- HIGH: QA prompt says `prompts/07-qa/` (should be 09), Security says `prompts/08-security/` (should be 10)
- MEDIUM: No tests/ directory exists — zero test files in project
- MEDIUM: README says "10 AI agents" but only 8 are active in agents.conf
- Script quality: auto-agent.sh is solid — config parsing, SIGINT cleanup, protected files, backups all working
- All 11 prompts have git safety rules and correct repo URLs
- NEED: Human to fix agents.conf ownership (protected file) and update CLAUDE.md
- NEED: PM to fix wrong agent numbers in QA and Security prompt paths

## Security Findings (Cycle 1)
- [HIGH-01] `eval` in `commit_by_ownership()` (auto-agent.sh:236-241) — replace with array-based args. Assign: 06-Backend
- [HIGH-02] `--dangerously-skip-permissions` = prompt-only isolation. Accepted risk, needs documentation. Assign: 02-CTO
- [MEDIUM-01] `.gitignore` missing `.env`, `*.pem`, `*.key`, `credentials.json` patterns. Assign: 06-Backend
- [MEDIUM-02] PowerShell notify function has unescaped variable. Assign: 06-Backend
- Full report: `prompts/10-security/reports/security-cycle-1.md`
- **Verdict: CONDITIONAL PASS** — fix HIGH-01 + MEDIUM-01 before v0.1.0

## Blockers
- (none)

## CEO Strategic Direction (Cycle 1)
- STRATEGIC MEMO: `docs/strategy/CYCLE-1-STRATEGIC-MEMO.md` — all agents should read
- DIRECTIVE: v0.1.0 is the ONLY priority. All other work (Pixel, Tauri, landing page) is frozen until release.
- DECISION: Open-source v0.1.0 to openOrchyStraw immediately after tagging
- DECISION: Benchmarks elevated to P1 (immediately after v0.1.0) — proof before polish
- DECISION: README rewrite happens BEFORE v0.1.0 tag
- DECISION: v0.1.1 will add --single-agent mode (Ralph compatibility on-ramp)
- TARGET: v0.1.0 tagged by end of Cycle 3
- 06-Backend is the critical path. 09-QA and 10-Security should prep audit checklists now.
- All non-critical-path agents (01, 02, 04, 05, 07, 08, 11): standby mode.

## CTO Architecture Review (Cycle 1)
- [CTO DECISION] Tauri Frontend: React 19 + shadcn/ui v4 + Zustand + TanStack Query (see UI-001)
- [CTO DECISION] Landing Page: Next.js 15 + shadcn/ui v4 + Framer Motion (see WEB-001)
- [CTO DECISION] Documentation: Mintlify (see DOCS-001)
- [CTO DECISION] Design System: shadcn/ui v4 + Tailwind v4 + dark #0a0a0a (see STYLE-001)
- [CTO DECISION] Desktop DB: SQLite (see DB-001)
- Tech registry updated: 6 "Pending" domains → 5 LOCKED/APPROVED, 3 remain pending
- 5 ADRs written to `docs/tech-registry/decisions/`
- Orchestrator hardening spec: `docs/architecture/ORCHESTRATOR-HARDENING.md`
  - P0: Missing bash version check (crashes on macOS stock bash)
  - P0: Backend owns `scripts/` but protected files overlap — silent discard of work
  - P1: Signal handling incomplete, empty cycle detection too aggressive
  - P2: `eval` injection risk (confirms Security HIGH-01), progress metrics measure wrong files
- Acknowledges Security HIGH-02 (--dangerously-skip-permissions): this is an accepted risk for v0.1. Will document threat model in architecture docs for v0.5.
- AGREE with CEO: v0.1.0 is the only priority. All locked stack decisions are for AFTER v0.1.0.
- NEED: Backend to implement bash version check + fix ownership overlap in agents.conf
- NEED: Human to update agents.conf ownership for backend (protected file)

## Notes
- (none)
