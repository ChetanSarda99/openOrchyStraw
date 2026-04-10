# Security Audit — Cycle 13
**Date:** 2026-04-10 13:54
**Auditor:** 10-security
**Verdict:** PASS (0 HIGH, 0 MEDIUM, 1 LOW, 1 INFO)

> Numbering continues the existing sequence (cycle 12 → cycle 13). The orchestrator's session-cycle counter reset to 1 for this run, but historical audit numbering is preserved to keep the backlog contiguous.
> This report picks up where `security-cycle-12.md` left off at commit `913ee39`.

---

## Scope
Reviewed everything since cycle 12 audit:
1. 9 new commits: `4599efe`, `0980a1d`, `2ea700a`, `11a1de7`, `03dcaf8`, `7ce6acb`, `0e2bef1`, `7f45616`, `50204a3`.
2. Uncommitted diff across 6 bash helper scripts + `scripts/agent-health-report.sh`.
3. Secrets scan across repo (excluding `node_modules/`).
4. `.gitignore` coverage regression check.

Carry-forward backlog (7 items) untouched — no new surface for those items this cycle.

---

## 1. New commit review

### `4599efe` — GitHub Issues view + Agent Flow + ErrorBoundary (#239, #248, #249)
**Primary security-relevant change:** new `/api/issues` endpoint in `app/server.js` (+64 lines, L682–745) that shells out to `gh`.

| Check | Result |
|-------|--------|
| Command string construction | **Static template literal** — `` `gh issue list --state open --limit 100 --json …` ``. No user input interpolated into the command. No `&&`, `;`, `|`, or backticks. **No shell injection surface.** |
| `execSync` options | `{ cwd: p, encoding: 'utf-8', timeout: 10_000 }` — hard 10 s timeout. Good. |
| `cwd: p` where `p = params.get("path") \|\| params.get("project") \|\| ORCH_ROOT` | **See ISSUES-LOW-01.** User-controlled query param flows into `cwd`. The command is static so this is **not** code execution — but it does let a caller point `gh` at an arbitrary directory. Impact depends on bind interface. |
| Fallback branch (L716) | Same static command with `cwd: ORCH_ROOT`. Safe. |
| Error handling | Double `try/catch`, fails closed to `{ issues: [], error: "gh CLI not available…" }`. Good. |
| Regex built from issue number (L728) | `` new RegExp(`#${issue.number}\\b`) `` — `issue.number` is `number` per gh JSON schema, not a regex-injection vector in practice. |
| Cache | 60 s TTL keyed by the raw path. **See ISSUES-LOW-01** — per-path keying lets callers bypass the cache by varying `path`. |
| Server bind (L16, L1081) | Default `HOST=127.0.0.1`. Env override `ORCH_HOST=0.0.0.0` is documented. On default bind, `/api/issues` is only reachable from the local machine → **low blast radius by default.** |

**ISSUES-LOW-01 (LOW) — `/api/issues` unvalidated `path` → execSync `cwd`**
- **Where:** `app/server.js:683` and `:708`.
- **What:** `params.get("path")` / `params.get("project")` is used directly as `cwd` for `execSync("gh issue list …")`. No allowlist, no check that the path is a registered project, no `realpath` containment.
- **Impact on default `127.0.0.1` bind:** minimal — only the logged-in user can reach it, and they can already run `gh` themselves.
- **Impact if user runs `ORCH_HOST=0.0.0.0`:** any host on the LAN can (a) learn which filesystem paths exist (error vs. success disclosure), (b) enumerate issues from any repo the local `gh` is authenticated against by passing a `path` inside that repo, and (c) spam per-path requests to bypass the 60 s cache and keep spawning `gh` subprocesses (low-grade DoS).
- **Recommendation:**
  1. Validate that `p` resolves (via `realpath`) to a directory inside `ORCH_ROOT` or a path registered in `project-registry`.
  2. Cache key should be the canonical resolved path, not the raw param.
  3. Optionally add a per-path min-interval to blunt the subprocess-spawn DoS.
- **Not blocking** for any release. Track as LOW. Hand to 06-backend.
- **Owner:** 06-backend. **Severity:** LOW.

**ErrorBoundary + AgentFlow** — React-only. No new IPC, no new shell surface. No findings.

---

### `0980a1d` — Phantom agent filter (#251), landing preview (#252)
`app/server.js` (+13 lines L220–236): loads `agents.conf` via existing `parseAgentsConf`, builds a `Set` of valid IDs, skips pixel dirs not in the set.

| Check | Result |
|-------|--------|
| New file I/O | `existsSync` + `join` on `projectPath` — same trust boundary as surrounding code. |
| `Set.has(dir.name)` | Set-membership check, no execution. Safe. |
| Failure mode | Wrapped in `try {} catch {}`, falls through to `validAgentIds = null` and skips filtering. Fail-open is acceptable here (pre-existing behavior). |

`site/package.json` adds an `npm run preview` script — not executed by agents, not wired to CI. Safe.

**Verdict:** SAFE.

---

### `2ea700a` — Brand color + docs-site logo wiring (#254, #255)
SVG / JSON asset updates only. No scripts, no server code, no shell invocations. Secrets scan on changed files: clean.
**Verdict:** SAFE.

---

### `11a1de7` — Visual QA error-matching fix
`tests/visual/run-app-qa-full.py` (+4/−2). Tightens a Playwright assertion. No new subprocess calls, no new file writes outside test scope.
**Verdict:** SAFE.

---

### `03dcaf8` — Demo GIF + launch posts + mascot logo (#191, #133, #235)
Added `assets/demo.gif`, `assets/demo.tape`, `assets/branding/orchy-mascot.svg`, `docs/marketing/LAUNCH-POSTS.md`, `docs/research/UI-PATTERNS-2026.md`.

| Check | Result |
|-------|--------|
| `demo.tape` (VHS recorder script) | Human-curated typing commands — only executes if someone manually runs `vhs demo.tape`. Not wired into cycles or CI. Safe. |
| `demo.gif` binary | Image, not executable. |
| SVG mascot | Path data only, no `<script>` tags. Safe. |
| Launch posts / UI research markdown | Prose only. Secrets scan: clean. |

**Verdict:** SAFE.

---

### `7ce6acb` — Cross-platform test fixes, Linux compat (#221)
`src/core/conditional-activation.sh` (+5), `tests/core/test-conditional-activation.sh` (+3), `tests/core/test-global-cli.sh` (−1).

Changes in `conditional-activation.sh`:
1. Init of `_ORCH_ACTIVATION_ISSUES_CHECKED=false` / `_ORCH_ACTIVATION_HAS_ISSUES=false` inside `orch_activation_init` (L174–175) — boolean literals, no input. Safe.
2. Escape hatch at L329: `[[ "${ORCH_ACTIVATION_SKIP_ISSUES_CHECK:-}" == "1" ]] && return 1`. Env-var literal compare. **No injection.** Short-circuits the `gh` call when test runners want determinism.

Test files: hardcoded `/opt/homebrew/bin/bash` → plain `bash`; export of the skip flag. Test-only, no production surface.

**Verdict:** SAFE. This resolves the cycle-12 uncommitted diff, which was already reviewed and approved.

---

### `0e2bef1`, `7f45616`, `50204a3` — Chain-of-command prompt edits
Touches agent `.txt` prompt files and `AgentChat.tsx`. No bash, no config, no new dependencies, no new execution surface.

| Check | Result |
|-------|--------|
| `AgentChat.tsx` edits | UI-only React. No new `fetch` targets, no `dangerouslySetInnerHTML`. Safe. |
| Prompt edits | Markdown-in-txt. Adds a "Chain of Command" section. Not interpreted as shell. |
| Secrets scan on modified prompts | Clean. |
| Template prompt copies | Identical chain-of-command block propagated into `template/{saas,api,content,yc-startup}`. Safe. |

**Verdict:** SAFE.

---

## 2. Uncommitted diff — 7 helper scripts

Seven scripts receive the identical three-line patch:
```bash
# Prefer canonical root agents.conf; fall back to legacy scripts/agents.conf
CONF_FILE="$PROJECT_ROOT/agents.conf"
[[ -f "$CONF_FILE" ]] || CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
```

Scripts: `commit-summary.sh`, `cycle-metrics.sh`, `health-dashboard.sh`, `post-cycle-router.sh`, `pre-cycle-stats.sh`, `pre-pm-lint.sh`, `agent-health-report.sh`.

| Check | Result |
|-------|--------|
| `$PROJECT_ROOT` provenance | Set from positional CLI arg (trusted operator) or computed via `cd "$(dirname "$0")/.."` (trusted). |
| Test-file guard | `[[ -f "$CONF_FILE" ]]` before fallback. Properly double-quoted. |
| Word splitting / globbing | Variable always in quotes downstream. Safe. |
| Equivalent precedent | Same pattern already approved for `scripts/pr-review.sh` in cycle 12. Now applied consistently across the rest of the helper fleet. |

**Verdict:** SAFE. Purely additive fallback.

**Small observation (INFO, not security):** `commit-summary.sh` and `post-cycle-router.sh` were two of the sites QA flagged last week for the `grep -c || echo 0` bug (BUG-019). That fix is still present on disk — no regression introduced by this diff.

---

## 3. Secrets scan

Pattern sweep (excluding `node_modules/`):
- `sk-[A-Za-z0-9]{20,}` — **clean**
- `ghp_[A-Za-z0-9]{20,}` — **clean**
- `AKIA[0-9A-Z]{16}` — **clean**
- `-----BEGIN (RSA |EC )?PRIVATE KEY-----` — only false positives inside `site/node_modules/next/dist/docs/…/environment-variables.md` (upstream docs example). Out of scope.
- `api_key|password|secret|token\s*=\s*"` in `template/`, `docs/`, `prompts/`, `src/`, `scripts/`, `app/` — **clean**.

`.env.example` present. `.env` absent. `.env` correctly ignored.

**Verdict:** PASS.

---

## 4. `.gitignore` coverage

Verified unchanged sensitive patterns:
```
.env
.env.*
!.env.example
*.pem
*.key
credentials.json
token.json
secrets.json
```

**Verdict:** PASS — no regression since cycle 12.

---

## 5. Supply chain

No new dependencies added to `site/package.json`, `docs-site/package.json`, or `app/package.json` (only a `preview` script entry in `site/package.json`). Core orchestrator remains bash-only.

**Verdict:** PASS.

---

## 6. Ownership boundary

- `app/server.js` edits: `ORCH_ROOT` is pinned at server startup. New code only reads under caller-specified paths. No writes outside the `runningCycles` / `finishedCycles` / `_apiCache` in-memory maps.
- Script diffs: no new file writes, just switched lookup precedence.
- Prompt edits: scoped to each agent's own prompt file per ownership rules.

**Verdict:** PASS.

---

## Findings Index (this cycle)

| ID | Severity | File | Summary | Owner |
|----|----------|------|---------|-------|
| ISSUES-LOW-01 | LOW | `app/server.js:683,708` | `/api/issues` uses unvalidated `path` query param as `execSync` `cwd`. No command injection (command is static), but enables info disclosure + cache-bypass DoS if user exports `ORCH_HOST=0.0.0.0`. | 06-backend |
| AR-INFO-01 | INFO (carryover) | `src/core/conditional-activation.sh:297–305` | Always-run glob patterns `*-cofounder`/`*-pm`/`*-security` would grant critical-agent privilege to any future agent ID ending in those suffixes. Safe while `agents.conf` stays human-curated. | 02-cto to track alongside agent-generator work |

Backlog unchanged: 7 carry-forward items (SWE-bench scaffold, `prompt-template.sh`, `task-decomposer.sh`, `init-project.sh`, 5-efficiency-scripts independent verification, WT-SEC-01 independent verification, post-integration `auto-agent.sh` review).

---

## Release Gates

| Gate | Status |
|------|--------|
| Secrets | **PASS** |
| `.gitignore` | **PASS** |
| Supply chain | **PASS** |
| Ownership | **PASS** |
| New module review (`conditional-activation.sh` delta, `/api/issues`, 7 helper-script diffs) | **PASS** (1 LOW, 0 HIGH/MEDIUM) |
| HIGH / CRITICAL findings | **0** |

**Overall cycle verdict: PASS.**
