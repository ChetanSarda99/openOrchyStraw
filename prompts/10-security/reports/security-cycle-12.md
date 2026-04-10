# Security Audit — Cycle 12
**Date:** 2026-04-10 02:35
**Auditor:** 10-security
**Verdict:** PASS (no new HIGH/MEDIUM findings)

---

## Scope
Fresh cycle. Reviewed:
1. 4 new commits since cycle 11 (359db58, 310f734, db5d16a, 913ee39)
2. Uncommitted diff on `src/core/conditional-activation.sh`
3. Backlog item: `src/core/qmd-refresher.sh` (P0 carryover)
4. Secrets scan across repo + new template files
5. `.gitignore` coverage (unchanged)

---

## 1. New commit review

### 359db58 — Fix stale agent states (#240, #244)
Touches `app/server.js`, `app/src/components/dashboard/CycleControl.tsx`, `app/src/components/dashboard/PixelAgents.tsx`.
- Node/React app, out of core-orchestrator trust boundary. No bash/shell changes. No new external calls.
- **Verdict:** SAFE — no orchestrator surface touched.

### 310f734 — Cofounder in templates + agent-generator (#246, #247)
Adds `template/_agent-generator/` (README + agent-template.txt) and 00-cofounder prompt files to `template/{saas,api,content}`. Also adds 3 lines to each of the 3 `agents.conf` template files.
- Secrets scan on `template/` tree: **CLEAN** (no api_key/password/secret/token assignments).
- Placeholder tokens in `agent-template.txt` (`{{AGENT_LABEL}}`, `{{OWNED_PATHS}}`, etc.) — template substitution target, not shell expansion. Safe.
- `agents.conf` additions use hardcoded agent IDs and paths, no user data.
- **Verdict:** SAFE — purely additive template content.

### db5d16a — `--force` default (later reverted)
Made `ORCH_FORCE_AGENTS=1` the default, added `--smart-skip` opt-out.
- **Reverted** by 913ee39 — no longer in tree. Historical only.
- If still live: no injection surface — integer literal assignment, env export. Safe.

### 913ee39 — Fix conditional activation properly (#245)
Touches `scripts/auto-agent.sh` (-5 lines), `scripts/pr-review.sh` (+2), `src/core/conditional-activation.sh` (+42).

**`scripts/auto-agent.sh`** — PROTECTED FILE, read-only review:
- Removes the default `ORCH_FORCE_AGENTS=1` and the `--smart-skip` flag branch.
- Removal only, no new surface.
- **Verdict:** SAFE.

**`scripts/pr-review.sh`** (+2 lines L132–135):
```bash
CONF_FILE="$PROJECT_ROOT/agents.conf"
[[ -f "$CONF_FILE" ]] || CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
```
- Fallback path lookup with proper `[[ -f ]]` guard. `PROJECT_ROOT` is trusted (set at script init).
- **Verdict:** SAFE.

**`src/core/conditional-activation.sh`** (+42 lines):

| Check | Result |
|-------|--------|
| New function `_orch_activation_has_open_issues` (L328–344) | Calls `gh issue list --state open --limit 1 --json number`. **No user input in the command.** Output piped to `grep -c '"number"'`, compared via `-gt`. No injection. |
| Per-cycle caching via module-global flags | `_ORCH_ACTIVATION_ISSUES_CHECKED`, `_ORCH_ACTIVATION_HAS_ISSUES` — declared `declare -g`, no external input. Safe. |
| Always-run case (L297–305) | Glob patterns: `00-cofounder\|*-cofounder\|03-pm\|*-pm\|10-security\|*-security`. Broad trailing-match patterns, but `agent_id` comes from `agents.conf` which is human-curated and protected. See AR-INFO-01 below. |
| Subshell/eval usage | None introduced. |
| `gh` failure handling | `2>/dev/null \|\| echo "0"` + integer test. Fails closed to "no issues" — safe. |

- **AR-INFO-01 (INFO):** Always-run glob patterns `*-cofounder`, `*-pm`, `*-security` will grant critical-agent privilege to *any* agent ID ending in those suffixes. Today this is fine because `agents.conf` is a protected human-curated file. If future tooling ever generates agent IDs from untrusted input (e.g. an onboarding wizard that takes a user-supplied label), this becomes a privilege-escalation footgun. No action required today — track alongside BUG-012 protected-files work.
- **Findings:** 0 HIGH, 0 MEDIUM, 0 LOW, 1 INFO.
- **Verdict:** APPROVED.

---

## 2. Uncommitted diff — `src/core/conditional-activation.sh`

Two changes:
1. L171–174: Added `_ORCH_ACTIVATION_ISSUES_CHECKED=false` + `_ORCH_ACTIVATION_HAS_ISSUES=false` to `orch_activation_init`. Integer/boolean literals, no input. Safe.
2. L329–330: Added escape hatch `[[ "${ORCH_ACTIVATION_SKIP_ISSUES_CHECK:-}" == "1" ]] && return 1`. Env var check against literal `"1"`. No injection.

- **Verdict:** SAFE. Cleanly layered test/isolation hook.

---

## 3. Backlog — `src/core/qmd-refresher.sh` (220 lines)

Auto-refresh QMD index module with state tracking via `.orchystraw/`.

| Check | Result |
|-------|--------|
| `eval` on untrusted input | None |
| Unquoted variable expansion in commands | None — all `${var}` calls quoted |
| State filename sanitization | `_orch_qmd_write_timestamp` enforces `^[a-zA-Z0-9._-]+$` regex — blocks `../` path traversal. PASS |
| State dir handling | `ORCH_STATE_DIR` env var or default `.orchystraw`. Trusted operator env. |
| `cd "${project_root}" && qmd ...` | Runs in `(...)` subshell — directory change is contained. `project_root` is quoted; no word-splitting or injection. PASS |
| Command execution | Only invokes `qmd update`, `qmd embed`, `command -v qmd` — no dynamic command construction. |
| Readonly constants | `_ORCH_QMD_UPDATE_STATE_FILE`, `_ORCH_QMD_EMBED_STATE_FILE` hardcoded — pass the regex validator. Real callers never trigger the validation error path. |
| Output handling | `printf`, `echo` to state files or stderr — no shell interpretation of output. |

- **QR-INFO-01 (INFO, NOT SECURITY):** Line 58 calls `_orch_qmd_log WARN ...` but `_orch_qmd_log` is **never defined** in this file and no other module provides it. If the regex validation ever fires, this becomes a `command not found` error rather than a clean `return 1`. Dead code in practice because every caller uses hardcoded readonly names that pass the regex — but the defect should be fixed by 06-backend for correctness. Filing as `QR-INFO-01` in this report; not a backlog blocker.
- **Findings:** 0 HIGH, 0 MEDIUM, 0 LOW, 1 INFO (correctness, not security).

- **Verdict:** APPROVED. Remove from backlog. QR-INFO-01 handed to 06-backend.

---

## 4. Secrets scan

- Pattern scan for `sk-`, `ghp_`, `AKIA…`, PEM private key headers across repo: **CLEAN**.
- Assignment scan (`api_key|password|secret|token = "…"`) in `template/` tree: **CLEAN**.
- `.env.example` present, `.env` absent from repo.

## 5. `.gitignore` coverage
Unchanged since cycle 11. Covers `.env`, `.env.*` (with `!.env.example`), `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `token.json`, `secrets.json`, `service-account*.json`, `*secret*.json`, `.claude/channels/`. **PASS.**

## 6. Supply-chain drift
Reviewed 4 new commits. Zero new third-party deps in the core bash orchestrator. `app/` and `site/` are separate trust boundaries (node projects, out of scope for this sweep).

---

## Backlog Status

| Item | Status |
|------|--------|
| single-agent.sh | DONE — APPROVED (cycle 11) |
| qmd-refresher.sh | **DONE — APPROVED** (this report) |
| SWE-bench scaffold (`scripts/benchmark/`) | Carry forward |
| prompt-template.sh | Carry forward |
| task-decomposer.sh | Carry forward |
| init-project.sh | Carry forward |
| 5 efficiency scripts independent verification | Carry forward |
| WT-SEC-01 independent verification | Carry forward |
| Post-integration auto-agent.sh review | Carry forward |

Backlog: 8 → 7 items.

---

## Release Gates
- Secrets: PASS
- .gitignore: PASS
- Supply chain: PASS
- Ownership: PASS
- New module review: PASS (conditional-activation.sh delta + qmd-refresher.sh)
- HIGH/MEDIUM findings: 0

**Overall cycle verdict: PASS.**

---

## Findings Index (this cycle)
- **AR-INFO-01** (INFO) — `*-cofounder`/`*-pm`/`*-security` glob patterns in always-run whitelist. No action today; note for future agent-generator hardening.
- **QR-INFO-01** (INFO, correctness) — `_orch_qmd_log` undefined in `qmd-refresher.sh:58`. Handed to 06-backend.
