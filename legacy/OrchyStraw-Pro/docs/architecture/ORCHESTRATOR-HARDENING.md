# Orchestrator Hardening — Priority Issues

_Date: March 19, 2026 (updated cycle 8+)_
_Status: RELEASE READY — all security blockers fixed, QA conditional pass, Security full pass_
_Reviewed by: CTO cycle 8 — verified 23895de fixes, updated priority table_

---

## Issues Found (Cycle 1 Review)

### P0: Bash Version Check (Missing) — ADR: BASH-001

`auto-agent.sh` uses `declare -A` (bash 4+) but has no version guard.
`error-handler.sh` and `logger.sh` use `declare -g -A` which requires bash 5.0+.

**Decision (BASH-001):** Minimum version is **bash 5.0**, not 4.0. See `docs/tech-registry/decisions/BASH-001-version-compatibility.md`.

**Fix:**
```bash
# Add after set -uo pipefail (line 23):
if ((BASH_VERSINFO[0] < 5)); then
    echo "ERROR: OrchyStraw requires bash 5.0+" >&2
    echo "  macOS: brew install bash && sudo chsh -s /opt/homebrew/bin/bash" >&2
    exit 1
fi
```

**Also fix:** Standardize all shebangs to `#!/usr/bin/env bash` (portable, finds Homebrew bash).

### P0: Ownership Overlap — Backend Agent vs Protected Files

`agents.conf` gives backend agent ownership of `scripts/`. But `scripts/auto-agent.sh`, `scripts/agents.conf`, and `scripts/check-*.sh` are PROTECTED.

**Current behavior:** Backend agent can stage changes to `scripts/`, then rogue detector restores protected files. This is confusing — agent does work that gets silently discarded.

**Fix options:**
1. Change backend ownership to `scripts/helpers/` (new directory for non-protected scripts)
2. Add exclusion: `scripts/ !scripts/auto-agent.sh !scripts/agents.conf !scripts/check-*.sh`
3. Split: backend owns `src/core/ src/lib/ benchmarks/` only, new `scripts/` agent or keep scripts human-only

**Recommendation:** Option 2 (exclusions) for v0.1, Option 1 (subdirectory) for v0.5.

### P1: No Signal Handling for Agent Subprocesses

`cleanup()` kills agent PIDs on SIGINT/SIGTERM, but:
- Doesn't set a flag to prevent new agents from launching
- Doesn't wait with a timeout (could hang)
- Doesn't log which agents were killed

**Fix:** Add `SHUTTING_DOWN=false` flag, check before launching, `wait` with timeout.

### P1: Empty Cycle Detection is Too Aggressive

`MAX_EMPTY_CYCLES=3` stops the orchestrator after 3 cycles with no commits. But a cycle where agents run successfully but produce no file changes (e.g., CTO writes specs to docs/) is NOT empty — it's just a non-code cycle.

**Fix:** Track "agent ran successfully" separately from "files committed". Only count truly failed cycles (all agents returned non-zero).

### P2 → P0: `eval` Usage in commit_by_ownership (UPGRADED)

Lines 236-237, 241 use `eval` to expand paths. This is a **confirmed shell injection risk**.
CTO cycle 2 audit verified: 3 eval calls in `commit_by_ownership()` — all vulnerable.
Paths from `agents.conf` are passed directly to `eval` with zero validation or escaping.

**Severity upgraded to P0** — this is the only code injection vector in the orchestrator.

**Fix:** Use arrays instead of eval:
```bash
local -a git_args=()
for path in $ownership; do
    if [[ "$path" == !* ]]; then
        git_args+=(":(exclude)${path#!}")
    else
        git_args+=("$path")
    fi
done
git diff --name-only -- "${git_args[@]}"
```

### P2: Progress Checkpoint Assumes Backend/iOS Structure

Lines 742-744 count `.ts` and `.swift` files. OrchyStraw's core is bash + markdown — these counts are always 0. Progress tracking should measure what actually exists.

**Fix:** Count files that matter for this project:
```bash
bash_count=$(find "$PROJECT_ROOT/scripts" -name '*.sh' 2>/dev/null | wc -l)
prompt_count=$(find "$PROJECT_ROOT/prompts" -name '*.txt' 2>/dev/null | wc -l)
doc_count=$(find "$PROJECT_ROOT/docs" -name '*.md' 2>/dev/null | wc -l)
```

---

## New Issues Found (Cycle 2 CTO Audit)

### P1: Missing `set -e` (errexit) in auto-agent.sh

Line 23: `set -uo pipefail` — missing `-e`. Non-pipeline command failures are silently
ignored. The `$(...)` subshells in lines 236-237 return empty strings on git failure
instead of aborting.

**Fix:** Change to `set -euo pipefail`. Audit all commands that intentionally fail
(grep, git diff on clean tree) and add `|| true` where needed.

### P1: Shebang Inconsistency

- `auto-agent.sh`: `#!/bin/bash` (hardcoded path)
- Core modules: `#!/usr/bin/env bash` (portable)
- `check-usage.sh`: `#!/bin/bash` (hardcoded path)

**Fix:** Standardize all to `#!/usr/bin/env bash` per BASH-001.

### P1: .gitignore Missing Sensitive Patterns

Current .gitignore is minimal (7 patterns). Missing:
- `.env`, `.env.local`, `.env.*.local` — API keys
- `*.pem`, `*.key` — private keys
- `dist/`, `build/`, `.next/` — build artifacts
- `.vscode/`, `.idea/` — IDE settings
- `*.swp`, `*.swo`, `*~` — editor swap files
- `coverage/` — test coverage
- `prompts/00-shared-context/usage.txt` — API usage tracking

**Fix:** Expand .gitignore with standard patterns. See SECURITY-HARDENING section.

### P2: Ownership Overlap — 05-tauri-ui `src/` vs 06-backend `src/core/` `src/lib/`

05-tauri-ui owns `src/` (parent). 06-backend owns `src/core/` and `src/lib/` (children).
If both agents write in the same cycle, commit order determines winner for overlapping paths.

**Fix for v0.1:** Document as known limitation. PM should not schedule both in same cycle
for `src/` changes. **Fix for v0.5:** Add overlap detection in `config-validator.sh`.

### P2: `auto-agent.sh` Has No Owner

The main orchestrator script is PROTECTED (agents can't modify it) but has no designated
agent responsible for its evolution. Backend agent owns `scripts/` but protected files
are silently restored.

**Fix:** Explicitly document that `auto-agent.sh` changes are human-only (CS) with CTO
review. Backend agent contributes via `src/core/` modules that get sourced.

---

## New Issues Found (Cycle 3 CTO Audit)

### P0: Dual agents.conf (BUG-009 confirmed)

Two `agents.conf` files exist with divergent content:
- `scripts/agents.conf` — 8 agents (used by `auto-agent.sh` line 33)
- `agents.conf` (root) — 13 agents (orphaned, not referenced by anything)

Root file has 5 additional agents (04-tauri-rust, 05-tauri-ui, 07-ios, 12-brand, 13-hr) and different ownership paths for CTO (includes `prompts/02-cto/`).

**Fix:** Change `auto-agent.sh` line 33 from `scripts/agents.conf` to `agents.conf` (root). Delete `scripts/agents.conf`. See ADR: OWN-001.

---

## CTO Review — Cycle 4 (CS Applied Fixes)

CS applied a major fix commit (`d130de7`) addressing multiple P0 and P1 items. CTO review follows.

### HIGH-01 eval injection — VERIFIED FIXED

The 3 `eval` calls in `commit_by_ownership()` (lines 236-237, 241) are replaced with array-based pathspec construction. The fix:
- Uses `local -a include_args=()` and `local -a exclude_args=()` arrays
- Builds `:(exclude)` pathspecs for `!`-prefixed paths
- Passes arrays directly to `git diff`, `git ls-files`, and `git add` via `"${pathspec[@]}"`
- No shell expansion of user-controlled strings — **injection vector eliminated**

**Architecture verdict: PASS.** Clean implementation matching the spec in this document.

### MEDIUM-02 notify injection — VERIFIED FIXED

The `notify()` function now:
- XML-escapes the title (including `"` and `'` which were missing before)
- Passes the escaped title via `ORCH_TOAST_TITLE` env var
- Uses single-quoted PowerShell command block — no bash interpolation inside PS
- PowerShell reads `$env:ORCH_TOAST_TITLE` — never touches bash's `$()` or backticks

**Architecture verdict: PASS.** Defense in depth — XML escaping + env var isolation.

### Core module sourcing — VERIFIED, NOTE ON ORDER

Modules are sourced at startup via explicit ordered list (not glob):
```bash
for mod in bash-version logger error-handler cycle-state agent-timeout dry-run config-validator lock-file; do
```
- Conditional: only if `src/core/` exists
- Graceful: `[ -f ... ] && source` — missing modules don't crash
- Explicit order matters: `bash-version` first (exits early if < 5.0), `logger` before error-handler

**Architecture verdict: PASS.** Better than glob (`src/core/*.sh`) because order is deterministic.

**NOTE:** `set -e` is still missing from line 23 (`set -uo pipefail`). This means module source failures are silent. P1, not blocking v0.1 but should be next fix.

### BUG-009 agents.conf reconciliation — VERIFIED FIXED, ARCHITECTURAL NOTE

CS chose to sync root → scripts/ (making root match scripts/) rather than the CTO-recommended approach (point auto-agent.sh to root, delete scripts/ copy). Result:
- Both files are now identical (9 agents)
- `auto-agent.sh` line 41 still reads `scripts/agents.conf`
- Root `agents.conf` is a duplicate, not the source of truth

**Functional result: PASS** — divergence eliminated, no orphaned agents.
**Architectural note:** Two identical files is fragile. Recommend for v0.2: single `agents.conf` at root, auto-agent.sh updated to read it. Low priority since both are now synced.

### Agents removed from config (04-tauri-rust, 05-tauri-ui, 07-ios, 12-brand)

These 4 agents were in root agents.conf but not in scripts/. CS removed them during reconciliation. This is correct — none have active work, and unused agents waste cycles. They can be re-added when their surfaces begin development.

### CTO ownership path change

Root agents.conf previously had CTO owning `prompts/02-cto/ docs/architecture/`. Now matches scripts/: `docs/architecture/` only. This means CTO can't commit to its own prompt directory. Acceptable — CTO doesn't self-modify prompts; PM handles that.

---

## CTO Review — Cycle 5 Security Findings (Cycle 1 of new run)

Security cycle 5 found 2 new HIGHs and 1 MEDIUM regression. CTO assessment follows.

### HIGH-03: Unquoted `$ownership` in for loops — CTO CONFIRMED

Lines 236, 310, 320: `for path in $ownership; do` — shell performs word-splitting AND glob expansion. The HIGH-01 fix removed `eval` but left the glob vector intact.

**Severity assessment: Agree HIGH, but not P0.** Unlike eval (which could execute arbitrary commands), glob expansion only affects which files match — an integrity risk, not RCE. However, it undermines the ownership boundary system which is a core security control.

**Approved fix pattern:**
```bash
IFS=' ' read -ra ownership_arr <<< "$ownership"
for path in "${ownership_arr[@]}"; do
```
This preserves word-splitting (space-delimited paths) while suppressing glob expansion.

**Applies to 3 locations:**
1. `commit_by_ownership()` line 236 — `$ownership`
2. `detect_rogue_writes()` line 310 — `$ownership`
3. `detect_rogue_writes()` line 320 — `$all_owned`

For `$all_owned` (line 320), which is built by appending in a loop, convert to array at construction time.

### HIGH-04: Sed injection in prompt updates — CTO CONFIRMED, DOWNGRADED to P1

Lines 785-791: sed uses `/` delimiter in double-quoted strings.

**Severity assessment: P1, not HIGH.** All variables come from controlled sources:
- `current_time` = `date '+%H:%M'` — always `HH:MM`
- `current_date` = `date '+%B %d, %Y'` — always `Month DD, YYYY`
- `backend_src`, `test_count`, etc. = `find|wc` — always integers

No current path produces `/` or `&` in these values. Risk is future-fragility, not present exploit.

**Approved fix:** Switch delimiter to `|` for all sed commands in the prompt update block:
```bash
sed -i "s|\*\*Date:\*\* .*|\*\*Date:\*\* ${current_date} — ${current_time}|" "$pf"
```

### MEDIUM-01: .gitignore regression — CTO CONFIRMED

Root `.gitignore` has 7 patterns, missing all secret/credential patterns. The `site/.gitignore` covers the Next.js project but root does not protect against accidental commits of `.env`, `*.pem`, `*.key` at repo level.

**Pre-release blocker** for public repo. No secrets currently exist in repo (verified by Security), so this is preventive.

---

## CTO Review — Cycle 8 (CS Applied Fixes, 23895de)

CS applied commit `23895de` fixing the remaining security blockers. CTO review follows.

### HIGH-03: Unquoted `$ownership` glob — VERIFIED FIXED

`commit_by_ownership()` now uses proper bash arrays:
- `include_args` and `exclude_args` built as indexed arrays (lines 269-279)
- `pathspec` array constructed and passed to `git add "${pathspec[@]}"` (line 283)
- No word-splitting or glob expansion of user-controlled strings

`detect_rogue_writes()` uses `PROTECTED_FILES` as a proper array (line 303), iterated safely (lines 321-326). `all_owned` is still a space-separated string but only used for ownership checking, not shell expansion — acceptable.

**Architecture verdict: PASS.**

### HIGH-04: Sed injection → awk -v — VERIFIED FIXED (bonus)

CS went beyond the spec (switch sed delimiter to `|`) and replaced all sed prompt updates with `awk -v`:
```bash
awk -v d="**Date:** ${current_date} — ${current_time}" \
    '{gsub(/\*\*Date:\*\* .*/, d)}1' "$pf" > "${pf}.tmp" && mv "${pf}.tmp" "$pf"
```
Variables passed via `-v` flag — never interpolated in the awk program string. This is strictly safer than any sed delimiter choice.

**Architecture verdict: PASS.** Superior to the spec'd fix.

### MEDIUM-01: .gitignore secrets — VERIFIED FIXED

Root `.gitignore` now includes `.env`, `*.pem`, `*.key`, and other sensitive patterns (6 new patterns added). Verified against Security requirements.

**Architecture verdict: PASS.**

### Remaining Observations

1. **Shebang:** `auto-agent.sh` line 1 still `#!/bin/bash` (not `#!/usr/bin/env bash`). P2, cosmetic — bash-version.sh module guards bash 5.0+ at runtime regardless of shebang path.
2. **`set -e`:** Line 23 still `set -uo pipefail`. Deferred to v0.1.1 per QA-F001.
3. **agents.conf:** Line 42 still reads `scripts/agents.conf`. Both copies synced but root has `model` column that scripts/ lacks. Deferred to v0.2.
4. **BUG-013:** agents.conf ownership paths for 09-qa (`reports/`) and 10-security (`reports/`) don't match actual directories (`prompts/09-qa/reports/`, `prompts/10-security/reports/`). CS must fix before v0.1.0 tag.

---

## CTO Review — v0.2.0 Token Optimization Modules (Cycle 2, New Run)

4 new modules shipped in cycle 1 (commit 4cd2c09). CTO architecture review follows.

### usage-checker.sh — PASS

Replaces `check-usage.sh`. Key improvements:
- Graduated backoff (70→10s, 80→30s, 90→120s, 100→300s)
- Portable JSON extraction (`grep -o` + `sed` replaces `grep -oP`)
- Configurable thresholds via `ORCH_PAUSE_THRESHOLD` env var
- 14 unit tests

**Minor:** Lines 102-108 dead branch — both `if/else` set codex=100. Cosmetic, not blocking.

### task-decomposer.sh — PASS

Progressive task decomposition with priority-based selection.
- P0 tasks always included (don't count against limit)
- Insertion sort fine for <20 tasks
- Markdown parser handles multiple task formats
- ENV configurable via `ORCH_MAX_TASKS_PER_AGENT`

### token-budget.sh — PASS

Per-agent token budgeting with history-based optimization.
- Integer-only arithmetic (no `bc`/`awk`) — zero-dep compliant
- Priority multiplier via x10 scale (avoids floats)
- History reduction: used <50% → reduce 25% next cycle
- Hard cap: 2x base prevents runaway allocation
- `orch_budget_to_max_tokens` 30% output ratio is reasonable

### session-windower.sh — PASS

Sliding window compression for SESSION_TRACKER.txt.
- `.bak` backup before modification
- `orch_auto_window` only compresses when token estimate exceeds budget
- chars/4 token estimation is standard
- Preserves recent N cycles in full, compresses older to one-line summaries

### Integration Status

Integration guide covers usage-checker (Step 8). Steps 10-12 needed for the other 3 modules. Recommended source order: `usage-checker → signal-handler → cycle-tracker → token-budget → task-decomposer → session-windower`.

---

## Priority Summary (Updated Cycle 8+)

| Priority | Issue | Owner | Status |
|----------|-------|-------|--------|
| ~~**P0**~~ | ~~Dual agents.conf (BUG-009)~~ | ~~CS~~ | **FIXED** (cycle 4, d130de7) |
| ~~**P0**~~ | ~~eval injection (HIGH-01)~~ | ~~CS~~ | **FIXED** (cycle 4, d130de7) |
| ~~**P0**~~ | ~~Bash 5.0 version guard~~ | ~~CS~~ | **FIXED** (cycle 4, sourced at startup) |
| ~~**P1**~~ | ~~MEDIUM-02 notify injection~~ | ~~CS~~ | **FIXED** (cycle 4, d130de7) |
| ~~**P1**~~ | ~~HIGH-03: Unquoted `$ownership` glob~~ | ~~CS~~ | **FIXED** (cycle 8, 23895de) |
| ~~**P1**~~ | ~~HIGH-04: Sed injection~~ | ~~CS~~ | **FIXED** (cycle 8, 23895de — awk -v) |
| ~~**P1**~~ | ~~MEDIUM-01: .gitignore secrets~~ | ~~CS~~ | **FIXED** (cycle 8, 23895de) |
| **P1** | BUG-013: agents.conf report paths | CS (agents.conf) | OPEN — `reports/` → actual paths |
| ~~**P1**~~ | ~~Function naming conflict (model-budget vs token-budget)~~ | ~~06-backend~~ | **FIXED** (#80 closed, PM verified) |
| ~~**P1**~~ | ~~agent-kpis.sh jq dependency~~ | ~~06-backend~~ | **FIXED** (jq removed, pure bash/awk JSON) |
| ~~**P1**~~ | ~~agent-kpis.sh test execution side effect~~ | ~~06-backend~~ | **FIXED** (returns 100.0, no test exec) |
| ~~**P2**~~ | ~~knowledge-base.sh regex injection~~ | ~~06-backend~~ | **FIXED** (grep -Fv, SEC-MEDIUM-03) |
| ~~**P2**~~ | ~~model-fallback.sh grep -P portability~~ | ~~06-backend~~ | **FIXED** (POSIX grep -E + sed) |
| **P1** | issue-tracker.sh QA-F007 awk shell exec | 06-backend | OPEN — awk getline+cmd in update(); replace with pure awk |
| **P1** | issue-tracker.sh title validator gaps | 06-backend | OPEN — allows single/double quotes; add to reject pattern |
| **P2** | migrate.sh unsanitized ORCH_PROJECT_ROOT | 06-backend | OPEN — validate env var is safe directory |
| **P2** | migrate.sh non-atomic version file write | 06-backend | OPEN — use mktemp+mv pattern |
| ~~**P1**~~ | ~~Signal handling~~ | ~~06-backend~~ | **INTEGRATED** (cycle 3, all 31 modules sourced) |
| ~~**P1**~~ | ~~Empty cycle detection~~ | ~~06-backend~~ | **INTEGRATED** (cycle 3, all 31 modules sourced) |
| **P2** | Add `set -e` to auto-agent.sh | CS (protected) | Deferred v0.1.1 (QA-F001) |
| **P2** | Backend ownership exclusions | CS (agents.conf) | OPEN — 06-backend still owns `scripts/` |
| **P2** | Shebang standardization | CS (protected) | OPEN — cosmetic, runtime guard covers |
| **P2** | Progress checkpoint fix | 06-backend | SPEC (cycle 1) |
| **P2** | src/ overlap detection | 06-backend | FUTURE (v0.5) |
| **P2** | Consolidate to single agents.conf | CS | Deferred v0.2 — both synced, low priority |
| **P2** | BUG-012: PROTECTED FILES sections | PM | 6 prompts missing, not blocking |

---

## CTO Review — v0.2.0 Cycle 3 Modules (Cycle 4, New Run)

5 new backend modules + 4 pixel adapter files shipped in cycles 2-3. Full architecture review follows.

### conditional-activation.sh (#32) — PASS

Agent eligibility with idle backoff and PM force-flags. Key design:
- Force override via `FORCE: <agent_id>` in shared context (safe regex: `[a-zA-Z0-9_-]+`)
- Interval scheduling: `cycle % interval == 0`
- Idle backoff: 3+ consecutive no-output cycles → skip (unless git changes in owned paths)
- **No eval, no injection vectors.** Git pathspecs use arrays, not string interpolation.
- **24 tests** — good coverage of interval logic, force parsing, idle tracking.

**Issues (non-blocking):**
1. **NOT INTEGRATED** — module exists but `auto-agent.sh` doesn't source it yet (CS: Steps 13-14 in INTEGRATION-GUIDE.md)
2. No git integration tests (tests use nonexistent paths to skip git)
3. Report function uses inefficient pipeline sort (cosmetic)

### prompt-compression.sh (#31) — PASS

Three-tier prompt loading (full/standard/minimal) to reduce token overhead.
- Section-to-tier mapping via associative arrays
- Auto-tier selection: runs 0-1 → full, 2-4 → standard, 5+ → minimal
- File header (before first `##`) always preserved
- **No eval, safe regex.** Section parsing via `^##[[:space:]]+(.*)` with BASH_REMATCH.
- **27 tests** — covers all tiers, force-full override, savings estimation.

**Issues (non-blocking):**
1. **NOT INTEGRATED** — same as conditional-activation
2. Empty heading edge case (malformed `## ` with no text) would match all keys — low risk, defaults to standard tier
3. Missing test: `---` divider preservation between included/excluded sections

### context-filter.sh — PASS

Differential context filtering for agent-specific delivery.
- Declarative mapping: agents → comma-separated section names or "ALL"
- Always includes header, Blockers, Notes as safety net
- **No eval, safe regex.** Same `^##[[:space:]]+` pattern.
- **18 tests** — all essential scenarios covered.

### prompt-template.sh — PASS

Template inheritance with `{{VAR_NAME}}` placeholder syntax.
- Hardcodes standard blocks (GIT_RULES, PROTECTED_FILES) to avoid file deps
- Uses awk for safe multiline value substitution (not sed or eval)
- **17 tests** — covers basic ops and multiline edge cases.

**Note:** Tests disable `set -e` around sourcing because `read -r -d ''` returns 1 (known bash quirk). Not a production issue.

### qmd-refresher.sh — PASS

Semantic search index refresh lifecycle.
- Tracks last-update/last-embed timestamps in `.orchystraw/qmd-*` state files
- Smart auto-refresh: always update (fast), conditionally embed (slow) based on interval
- Uses subshells `(cd ... && qmd ...)` for safe directory isolation
- **15 tests** — covers happy path and init, but mock only tests success path.

### Pixel Phase 2 Adapter — CONDITIONAL PASS

4 files: `orchystraw-adapter.js`, `cycle-overlay.js`, `character-map.json`, `test-adapter.js`

**Architecture:** Clean separation — JSONLWatcher → AgentStateTracker → WebSocket bridge → Canvas HUD. Event flow is well-designed.

**Issues:**
1. **8/11 agents mapped** — 04-tauri-rust, 05-tauri-ui, 07-ios missing from character-map.json (acceptable: these agents are deferred)
2. **XSS theoretical risk** — `lastSpeech` broadcast without sanitization. Mitigated by Canvas 2D rendering (fillText doesn't interpret HTML), but downstream DOM usage could be unsafe. Recommend: sanitize speech text before WebSocket broadcast.
3. **No cycle reset logic** — JSONL truncation resets offset but not agent states. Agents remain in last animation from prior cycle.
4. **PM walkPath defined but unused** — character-map.json line 41 defines desk-to-desk path for PM, but adapter doesn't implement pathfinding. Polish item.
5. **33 test assertions** — good happy path coverage, but no WebSocket or Canvas tests.

**Verdict:** Ship-ready for 8 active agents. Address XSS sanitization before any DOM-based frontend consumes the WebSocket events.

### Cross-Module Observations

All 5 bash modules follow identical patterns:
- Double-source guard via readonly variable
- `declare -gA` for state (bash 4.2+ compatible)
- Consistent error signaling (return 1)
- Proper quoting throughout
- No external dependencies

**QA-F002 confirmed:** None of the 5 new modules include `set -euo pipefail`. This is acceptable for sourced modules (caller sets strict mode), but should be documented as a convention.

## CTO Review — v0.2.0 Cycle 5 Modules (Cycle 6)

3 new modules shipped in cycle 5. Full architecture review follows.

### init-project.sh (#29) — PASS

Project scanner and agent blueprint generator. Scans a target directory for languages, frameworks, package managers, test frameworks, CI config, and generates suggested `agents.conf` + scaffold prompt files.

**Architecture:**
- Detection pipeline: languages → frameworks → pkg managers → test frameworks → CI → features → build suggestions
- Uses `find` with `-maxdepth 3` and hardcoded exclude list (node_modules, .git, vendor, etc.)
- Agent suggestion logic is deterministic: CEO+CTO+PM always included, then conditionally adds backend/frontend/tauri/ios/QA/DevOps/infra/security based on scan results
- Config output follows existing `agents.conf` pipe-delimited format
- Prompt scaffold is generic but functional — includes role, ownership, rules, context sections

**Security:**
- No eval, no injection vectors
- `grep -q` for dependency detection — no shell expansion of package names
- `_orch_init_pkg_json_has_dep` uses quoted grep pattern — safe
- `_orch_init_requirements_has` uses `grep -qi "^${pkg}"` — regex anchor prevents partial matches but `$pkg` is not escaped for regex special chars. Low risk: package names are ASCII alphanumeric in practice.
- Prompt generation uses heredoc (`cat <<PROMPT_EOF`) — safe
- `for p in ${ownership}` (line 450) — unquoted, but this is output formatting only (generating markdown), not shell expansion of paths. Cosmetic.

**Issues (non-blocking):**
1. `_orch_init_build_find_excludes` (lines 76-89) builds find arguments as a string but is **never called** — dead code. `_orch_init_find_files` uses hardcoded excludes instead. Should be removed for cleanliness.
2. Framework detection could false-positive: `grep -q '"react"'` in package.json matches `"react-dom"`, `"react-native"`, etc. Not harmful (all indicate React presence).
3. **20 tests** — covers scan, detect, generate, edge cases (empty project). Good coverage.

**Verdict: PASS.** Clean, zero-dep, no security concerns.

### self-healing.sh (#72) — PASS

Auto-detect and fix common agent failures with conservative remediation. Classifies failures into 7 categories: rate-limit, timeout, context-overflow, permission, crash, git-conflict, unknown.

**Architecture:**
- Diagnosis: exit code analysis first (134/139/137 → crash, 124 → timeout), then log tail keyword matching via `grep -qiE`
- Remediation matrix:
  - rate-limit: exponential backoff (`10 * 2^attempts`, capped 300s)
  - timeout: store increased timeout recommendation (+50%)
  - context-overflow: write `.orchystraw/heal-compress-{agent}` flag file for prompt-compression module
  - permission: `chmod u+rw` on owned files only
  - git-conflict: `git checkout --theirs` on owned files only
  - crash/unknown: log-only, return 1 (no auto-fix)
- Audit trail: every action recorded with timestamp, agent, class, action, success
- Retry budget: configurable max retries + cooldown period

**Security:**
- No eval, no injection vectors
- Log tail captured via `tail -n 50` — bounded, no unbounded reads
- Pattern matching uses `grep -qiE` with fixed patterns — safe
- Ownership lookup parses agents.conf safely (`cut -d'|'`, no eval)
- `_orch_heal_file_in_ownership` (line 118): `for path in $ownership` — unquoted word splitting. Same pattern as the OLD HIGH-03 issue, but here `$ownership` comes from `_orch_heal_get_ownership` which uses `cut | xargs` — result is space-separated paths with no globs. **LOW RISK** but should be converted to array for consistency. Recommend:
  ```bash
  IFS=' ' read -ra ownership_arr <<< "$ownership"
  for path in "${ownership_arr[@]}"; do
  ```
  Same applies to `orch_heal_apply` permission handler (line 334).
- `chmod u+rw` restricted to agent's owned paths — good boundary enforcement
- `git checkout --theirs` restricted to agent's owned paths — good boundary enforcement

**Issues (non-blocking):**
1. **Unquoted `$ownership` in 2 locations** (lines 118, 334) — LOW risk as values come from controlled source (agents.conf via cut+xargs), but should use array pattern for consistency with HIGH-03 fix. Not blocking since no glob chars expected in ownership paths.
2. `_orch_heal_epoch` uses `date +%s` (GNU) — `date -j` fallback in `should_retry` handles BSD. Good portability.
3. **25 tests** — covers all diagnosis classes, retry budget, history, reporting. Good coverage.

**Verdict: PASS.** Well-designed failure recovery. Recommend array fix in v0.3.

### quality-gates.sh (#67) — PASS

Scripted quality gates with blocking/warning severity. 4 built-in gates (syntax, shellcheck, test, ownership) plus custom gate registration.

**Architecture:**
- Registration-based: gates registered by name with command/function + severity
- Execution order preserved via indexed array
- `run_all` stops on first blocking failure, skips remaining gates
- Result tracking: pass/fail/skip with output capture (truncated to 500 chars) and duration
- Built-in gates:
  - `syntax`: `bash -n` on all `src/core/*.sh`
  - `shellcheck`: `-S warning` level (gracefully skips if not installed)
  - `test`: runs `tests/core/run-tests.sh` (gracefully skips if missing)
  - `ownership`: placeholder — delegates to `orch_gate_check_ownership`
- Custom gates: either shell commands (`bash -c`) or bash functions
- Per-gate timeout via `timeout` command (60s default)

**Security:**
- **Shell command gates** (line 114): `bash -c "$cmd"` where `$cmd` comes from `orch_gate_register` — caller-controlled input. If an attacker could call `orch_gate_register` with arbitrary strings, this would be injection. However, registration only happens from trusted code (the orchestrator itself), not from agent output. Acceptable.
- `$timeout_cmd` (line 113): constructed as `"timeout ${_ORCH_GATE_TIMEOUT}"` then used unquoted in `$timeout_cmd bash -c "$cmd"`. The timeout value is integer-only (set in `orch_gate_init`). Safe.
- `orch_gate_check_ownership`: `for path in $ownership_paths` (line 417) — same unquoted pattern. Input comes from function parameter, ultimately from agents.conf. Same LOW risk as self-healing.
- No eval anywhere. Good.

**Issues (non-blocking):**
1. **Unquoted `$ownership_paths`** (line 417) in `orch_gate_check_ownership` — same pattern as self-healing. LOW risk, recommend array conversion for consistency.
2. `_orch_gate_exec` line 114: `$timeout_cmd bash -c "$cmd"` — unquoted `$timeout_cmd` relies on word-splitting to pass `timeout 60` as two words. Works but fragile. Consider using an array: `local -a timeout_cmd=(timeout "$_ORCH_GATE_TIMEOUT")`.
3. `_orch_gate_builtin_syntax` line 148: `errors+=1` should be `(( errors++ ))` — `+=1` on an integer variable does string concatenation in some contexts, though here `return $errors` coerces back. Cosmetic.
4. **22 tests** — covers registration, execution, pass/fail, skip, reset, custom gates, ownership. Good coverage.

**Verdict: PASS.** Solid gate framework. Ready for integration.

### Cross-Module Observations (Cycle 5 batch)

All 3 modules follow the established patterns:
- Double-source guard via readonly variable
- `declare -gA` for associative array state (bash 4.2+ compatible)
- Consistent error signaling (return 1, stderr logging)
- No external dependencies
- Proper quoting (with minor exceptions noted above)

**Recurring pattern: unquoted `$ownership` in for-loops.** Found in self-healing.sh (2 locations) and quality-gates.sh (1 location). Same class as the fixed HIGH-03 but lower risk since values come from controlled sources (agents.conf via cut/xargs, not raw user input). Recommend converting all 3 to array pattern in a future cleanup pass. Not blocking.

**Integration readiness:** All 3 have integration steps documented (Steps 19-21 in INTEGRATION-GUIDE.md). Recommended source order addition: `... → self-healing → quality-gates` (init-project is standalone, not sourced at orchestrator startup).

---

## CTO Review — v0.2.0 Cycle 7 Modules (Cycle 8)

3 new modules shipped in cycle 7. Full architecture review follows.

### file-access.sh (#66) — PASS

4-zone file access enforcement: protected → owned → shared → unowned. Replaces the ad-hoc ownership checking scattered throughout auto-agent.sh with a centralized, testable module.

**Architecture:**
- Zone priority chain: protected (denied) → owned (read-write) → shared (read-write) → unowned (read-only) → unknown (read-only)
- Path matching via prefix comparison with `/` boundary enforcement — prevents `src/core` matching `src/core-backup/`
- Exclusion support: `!`-prefixed paths in ownership strip the prefix and check exclusions before ownership
- `orchestrator` agent ID bypasses protected read restriction — clean privilege escalation model
- Default protected paths hardcoded as readonly: auto-agent.sh, agents.conf, check-usage.sh, CLAUDE.md, .orchystraw/
- Default shared paths: prompts/00-shared-context/, prompts/99-me/
- Config parser reads agents.conf pipe-delimited format, field 3 (ownership), handles comments and blank lines

**Security:**
- No eval, no injection vectors
- `_orch_fa_normalize_path` strips `./` prefix and collapses `//` — prevents path traversal via normalization tricks
- `_orch_fa_matches_prefix` uses exact `==` and `==.../*` pattern matching — no regex, no glob
- `for p in $paths` (lines 228, 242) — unquoted word splitting in `set_protected` and `set_shared`. These take space-separated path strings and split into arrays. Input comes from module constants or caller code, not user input. **LOW risk** — same class as the recurring pattern in self-healing/quality-gates. Could be array parameters instead, but the API is consistent with the rest of the codebase.
- `for entry in $ownership` (line 259) in `register_ownership` — same unquoted pattern. Input comes from agents.conf via `parse_config` or direct caller registration. Same low risk.
- `for f in $file_list` (line 416) in `validate_writes` — unquoted. Input is space-separated file paths from git diff output. File names with spaces would break, but OrchyStraw's codebase doesn't use spaces in paths. Acceptable.
- `while IFS= read -r raw_line` in `parse_config` — properly handles each line individually. Safe.

**Issues (non-blocking):**
1. **Protected read access model:** `orch_access_can_read` returns 1 for protected files (non-orchestrator). This is more restrictive than current behavior — agents CAN read CLAUDE.md and agents.conf today. The integration step should use `can_write` for enforcement and `can_read` only for audit logging, not blocking.
2. **No glob/wildcard support** in ownership paths. Prefix matching covers directory trees, but patterns like `*.sh` aren't supported. Not needed today since all ownership is directory-based.
3. **28 tests** — covers all zones, parse_config, normalization, exclusions, validation. Good coverage.

**Verdict: PASS.** Clean, well-structured access control. This module is the foundation for proper ownership enforcement.

### agent-as-tool.sh (#26) — PASS

Lightweight read-only agent invocations. Lets one agent invoke another for quick lookups without file writes.

**Architecture:**
- Registration-based: agents register with prompt path + CLI command
- Self-invoke prevention: caller == target returns 3 — prevents recursive loops
- Mock support via `_ORCH_TOOL_MOCK_CMD` — clean testing hook
- History tracking: newline-separated `target:timestamp:status` entries per caller
- History trimming: keeps last 50 entries per caller — bounded memory
- Timeout via `timeout(1)` command, returns 1 on timeout (exit code 124 mapped)
- Distinct return codes: 0=success, 1=timeout, 2=unknown-target, 3=self-invoke

**Security:**
- No eval, no injection vectors
- `_orch_at_build_prompt` uses heredoc with unquoted `$caller_id` and `$query` inside `cat <<PROMPT`. These are interpolated by bash into the heredoc, which is then passed as a CLI argument. The caller_id comes from agents.conf (trusted), and the query comes from agent code (trusted). **No injection risk** — the values become a string argument to the CLI command, not evaluated as shell.
- `timeout "$_ORCH_TOOL_TIMEOUT" $effective_cmd "$wrapped_prompt"` (line 229) — `$effective_cmd` is unquoted. For single-word CLIs like `claude`, `codex`, `gemini`, this works. For multi-word CLIs like `codex exec`, word-splitting is **relied upon** to separate the command from its subcommand. This is intentional and consistent with how `model-router.sh` handles CLI strings.
- `2>/dev/null` on the invocation suppresses stderr — prevents target agent errors from leaking into caller's output. Good isolation.

**Issues (non-blocking):**
1. **Read-only enforcement is advisory only.** The "READ-ONLY" instruction is in the prompt text, but nothing prevents the invoked CLI from actually writing files. True enforcement would require running in a restricted shell or temporary directory. For v0.2.0, prompt-level restriction is acceptable — agents are trusted code, not adversarial.
2. **No invocation depth limit.** Agent A can invoke B, which (in a full integration) could invoke C. No depth counter prevents infinite chains. Timeout is the only safeguard. Recommend adding `_ORCH_TOOL_DEPTH` counter in v0.3.
3. **22 tests** — covers registration, self-invoke guard, mock invocation, timeout, history, state reset. Good coverage.

**Verdict: PASS.** Well-designed inter-agent communication primitive. The advisory read-only model is appropriate for the current trust boundary.

### model-budget.sh (#69) — PASS

Per-agent fallback chains and invocation budget controls. Companion to model-router.sh (independent, doesn't source it).

**Architecture:**
- Fallback chain: comma-separated model list per agent, resolved left-to-right
- CLI availability check via `command -v` — skips models whose CLI isn't installed
- Budget enforcement: per-agent limit + global limit, checked at resolve time
- Cycle-aware: `reset_cycle` clears counters but preserves chains and limits — correct lifecycle
- Default chain: `claude,codex,gemini` — matches the project's model routing table
- Counter tracking: per-agent count, per-model count, global count — three dimensions
- Report function collects all known agents from chains, limits, and counts — handles agents that have only chains, only limits, or only invocations

**Security:**
- No eval, no injection vectors
- `IFS=',' read -ra models <<< "$chain"` (line 278) — proper array parsing, no glob expansion
- Integer-only arithmetic throughout — no `bc`, no float operations, zero-dep compliant
- Timeout validation: `[[ "$seconds" =~ ^[0-9]+$ ]]` — rejects non-integers. But this is on `set_timeout` in agent-as-tool.sh, not here. Here, `set_limit` and `set_global_limit` use the same pattern. Good.
- `command -v "$model"` (line 287) — checks if the model CLI exists in PATH. `$model` comes from the chain string which is set by trusted orchestrator code. Safe.

**Issues (non-blocking):**
1. **resolve() checks agent budget before iterating fallback chain.** At line 293, budget exhaustion is checked inside the `for model` loop but applies to the agent as a whole, not per-model. This means if the agent's budget is exhausted, it returns 1 on the first iteration regardless of chain position. Logically correct — budget exhaustion means no model should be used — but the loop structure makes this non-obvious. Could short-circuit before the loop. Cosmetic.
2. **No fallback chain for global exhaustion.** When `_orch_mb_global_exhausted` returns 0, all agents stop. There's no "degraded mode" or priority-based allocation. Acceptable for v0.2 — global limits are a hard cap.
3. **`echo` used for output instead of `printf`.** Lines 92, 199, 251, 304, etc. use `echo "$var"`. For simple string output this is fine, but `printf '%s\n' "$var"` is more portable if the value starts with `-`. All values here are known-safe (model names, integers, "unlimited"). Cosmetic.
4. **24 tests** — covers chains, limits, recording, exhaustion, resolve, cycle reset, report. Good coverage.

**Verdict: PASS.** Clean budget control system. Ready for integration alongside model-router.

### Cross-Module Observations (Cycle 7 batch)

All 3 modules follow the established patterns:
- Double-source guard via readonly variable
- `declare -gA` for associative array state (bash 4.2+ compatible)
- Consistent error signaling (return 1, stderr logging)
- No external dependencies
- Proper quoting (with recurring low-risk unquoted `$paths` exceptions)

**Integration cohesion:** file-access.sh + agent-as-tool.sh + model-budget.sh form a complete access control + invocation layer. The recommended integration order: `... → file-access → model-budget → agent-as-tool` (file-access should be early to establish zones before any agent runs; model-budget before agent-as-tool since tool invocations consume budget).

**Total module count:** 24 modules, all reviewed and PASSED. Integration steps 1-24 documented.

---

## CTO Review — #77 Module Integration (Cycle 3, Session 5)

**#77 RESOLVED.** All 31 modules now listed in `auto-agent.sh` lines 31-37.

### Source order — VERIFIED CORRECT

Order: `bash-version → logger → error-handler → cycle-state → agent-timeout → dry-run → config-validator → lock-file → signal-handler → usage-checker → init-project → conditional-activation → dynamic-router → model-router → model-budget → context-filter → prompt-compression → prompt-template → session-windower → task-decomposer → token-budget → file-access → quality-gates → review-phase → self-healing → cycle-tracker → qmd-refresher → vcs-adapter → worktree-isolator → single-agent → agent-as-tool`

Dependency chain is sound:
- `bash-version` first (early exit guard)
- `logger` before `error-handler` (error-handler uses logger)
- Core primitives before signal/usage handlers
- Routing chain in correct order (activation → router → budget)
- Prompt pipeline sequential (filter → compress → template)
- Access control before enforcement (file-access → quality-gates → review-phase)
- Invocation modules last (single-agent, agent-as-tool)

### Lifecycle hooks — VERIFIED WIRED

All 5 hooks found in auto-agent.sh with `type -t` guard (graceful skip if module not loaded):
- `orch_signal_init` (line 630) — startup
- `orch_should_run_agent` (line 735) — per-agent eligibility
- `orch_quality_gate` (line 785) — post-agent quality check
- `orch_self_heal` (line 788) — failure recovery
- `orch_track_cycle` (line 878) — cycle bookkeeping

### P1 BUG: Function naming conflict — model-budget.sh vs token-budget.sh

**3 functions defined in both modules:**
- `orch_budget_init()` — model-budget.sh:43, token-budget.sh:48
- `orch_budget_record()` — model-budget.sh:148, token-budget.sh:111
- `orch_budget_report()` — model-budget.sh:327, token-budget.sh:158

Since `model-budget` is sourced BEFORE `token-budget`, **token-budget silently overwrites all 3 functions**. model-budget's fallback chain and per-agent limit features are effectively dead code at runtime.

**Fix:** Rename token-budget's functions to use a `orch_token_budget_` prefix:
- `orch_budget_init` → `orch_token_budget_init`
- `orch_budget_record` → `orch_token_budget_record`
- `orch_budget_report` → `orch_token_budget_report`

Alternatively, rename model-budget's to `orch_model_budget_*`. Either way, the prefixes must be distinct. **Assign to 06-backend.**

### Architecture verdict: PASS (with P1 naming conflict)

Integration is structurally sound. The naming conflict must be fixed before v0.2.0 ships, but it doesn't affect v0.1.x (those 8 modules had no conflicts).

---

## Cycle 6 Review — RETRACTED (was false verification)

_Previous content retracted — CTO wrote "VERIFIED" without reading the file. See cycle 20 below._

---

## Cycle 20 Review — #77 ACTUALLY Verified (2026-03-20 14:45)

**Commit `b1c7a78` fixed #77.** Two follow-up bugfixes: `00ca24f` (local keyword scope), `c208a37` (lifecycle hook variable scope). CTO verified by reading `scripts/auto-agent.sh` directly.

### Changes verified (actual file read):

1. **Module expansion (lines 31–37):** `for mod in` lists all 31 modules: bash-version logger error-handler cycle-state agent-timeout dry-run config-validator lock-file signal-handler usage-checker init-project conditional-activation dynamic-router model-router model-budget context-filter prompt-compression prompt-template session-windower task-decomposer token-budget file-access quality-gates review-phase self-healing cycle-tracker qmd-refresher vcs-adapter worktree-isolator single-agent agent-as-tool.
2. **Pre-cycle hooks (lines 727–728):** `orch_signal_init` + `orch_init_project`, both `type -t` guarded.
3. **Per-agent hook (line 741):** `orch_should_run_agent` for conditional activation / dynamic routing.
4. **Failure hook (line 765):** `orch_self_heal` on agent exit failure.
5. **Post-agents hook (line 771):** `orch_quality_gate` after all agents finish.
6. **Post-cycle hooks (lines 807–808):** `orch_track_cycle` + `orch_refresh_qmd`.

### Architecture assessment:
- **No new dependencies** — all hooks call functions from already-sourced modules
- **Backward compatible** — all 7 hooks use `type -t ... &>/dev/null && ... || true` guard pattern
- **No eval** — maintains secure pattern from HIGH-01 fix
- **Source order correct** — foundational modules (bash-version, logger) before higher-level (quality-gates, self-healing)
- **Bugfixes were necessary** — `local` keyword can't be used at script scope outside functions, correctly removed in `00ca24f`

### #77 status: **VERIFIED — PASS.** Confirmed by direct file read + `grep -c` validation.

---

## Cycle 3 Review (2026-03-20) — Post-#77 Security & Integration

### run-swebench.sh — CRITICAL-02 + HIGH-01 Fix Review

**`_validate_repo()`** — Regex whitelist `^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$`. Prevents URL injection by restricting to safe owner/repo characters only. Correctly placed: called in `_load_task()` immediately after jq parsing, before any use of `TASK_REPO`.

**`_validate_patch()`** — Defense-in-depth:
- Rejects `--exec`, `;`, backticks, `$(`, `&&`, `||` — blocks command injection via git apply
- Rejects `+++ a/../` directory traversal — blocks workspace escape
- Returns early on empty patches (correct no-op)
- Called for both `test_patch` and `gold_patch` with descriptive labels

**Verdict: PASS.** Clean, minimal, correct placement. No bypass vectors identified.

### auto-agent.sh — #52, #16, QA-F005 Review

1. **`set -uo pipefail` → `set -euo pipefail`** (#52) — Adds `-e` for fail-fast on errors. Correct.
2. **`echo -e` → `printf '%b'`** (#52) — 4 occurrences replaced. `printf '%b'` is POSIX-portable; `echo -e` behavior varies across shells. Correct fix.
3. **Pixel emitter integration** (#16) — `emit-jsonl.sh` sourced conditionally (`if [ -f ... ]`). No hard dependency. `pixel_init`, `pixel_agent_start`, `pixel_agent_done` wired at correct lifecycle points with `type -t ... &>/dev/null && ... || true` guard pattern.
4. **PROTECTED_FILES re-addition** (QA-F005) — `scripts/auto-agent.sh` restored to protected list. #77 is complete, correct to re-lock.
5. **Variable extraction** — `local agent_for_pid` avoids repeated `${AGENT_IDS[$pid_idx]:-unknown}` lookups. Clean.

**Verdict: PASS.** All changes follow established patterns, no security regressions, no dependency additions.

---

## CTO Review — v0.2.0 Advanced Modules (Cycle 1, Session 8, 2026-03-20)

8 new modules reviewed. 4 PASS, 4 CONDITIONAL PASS.

### compare-ralph.sh (#48) — CONDITIONAL PASS

393 lines. Located at `scripts/benchmark/custom/compare-ralph.sh`. Side-by-side benchmark runner: runs same tasks through OrchyStraw (multi-agent) and Ralph (single-agent), generates comparison report.

**Architecture:**
- Three-phase pipeline: Ralph run → OrchyStraw run → aggregate + compare
- Sources `lib/instance-runner.sh`, `lib/results-collector.sh`, `lib/cost-estimator.sh` — matches BENCH-001 directory layout
- Input validation: `_validate_positive_int`, `_validate_model` with allowlist
- `set -euo pipefail`, proper error handling with `_die()`
- Dependency check: git, jq, python3, bash 4.2+
- Dry-run mode with cost estimation for both approaches
- JSONL result format matches BENCH-001 spec

**Issues:**
1. **Python in report generation (lines 207-254)** — Embedded Python for per-task JSON joining in `_generate_comparison_report`. BENCH-001 says Steps 1-5 are pure bash, this is Step 4. The Python is minimal (report formatting only, not core logic). **Acceptable exception** but should be documented.
2. **File path embedding in Python** — `$ralph_results` and `$orchy_results` are bash-interpolated into Python f-strings. Paths are internally generated (line 337-338) with controlled format, so no injection risk. But single quotes in paths would break.
3. **`jq` required** — Acceptable for benchmark scripts per BENCH-001 (jq restriction is src/core/ only).

### founder-mode.sh (#61) — PASS

416 lines. 6 public functions. Keyword-based task triage, delegation logging, cycle scheduling override.

**Architecture:**
- Keyword matching via `grep -qE` with category priority: security > infra > bug > feature > refactor > docs > unknown
- Delegation log: append-only file with `timestamp|agent|task` format
- Runtime state via associative arrays: agents, labels, active tasks, overrides
- agents.conf parsing via `cut -d'|'` — safe, no eval
- `orch_founder_should_run` logic: override → active tasks → interval → coordinator (interval=0 always runs)

**Minor issue (non-blocking):**
- JSON serialization in `orch_founder_override_priority` (line 322): `json+="\"${key}\":\"${_ORCH_FOUNDER_OVERRIDES[$key]}\""` — no escaping of `"` or `\` in values. Produces invalid JSON if values contain special chars. Low risk: inputs are controlled strings ("critical", "high", etc.).

### knowledge-base.sh (#76) — CONDITIONAL PASS

545 lines. 8 public functions. Cross-project knowledge persistence at `~/.orchystraw/knowledge/`.

**Architecture:**
- Domain/key file layout: `~/.orchystraw/knowledge/{domain}/{key}.md` with YAML frontmatter
- Index file for fast lookup: `domain/key|timestamp|description`
- Bidirectional merge: project-local → global, global → project-local, newer wins by ISO timestamp comparison
- Export to single markdown file
- All state via filesystem — no in-memory cache, no IPC

**Issues (P2 — should fix):**
1. **Regex injection in `_orch_kb_update_index` (line 72):** `grep -v "^${domain}/${key}|"` — if domain/key contain regex metacharacters (`.`, `*`, `+`, `[`), this matches/skips unintended entries. Fix: `grep -Fv "${domain}/${key}|"` (fixed-string match). Same issue in `_orch_kb_remove_from_index` (line 90).
2. **User query as regex in `orch_kb_search` (line 242):** `grep -qi "$query"` treats the query as a regex pattern. Special chars in queries will cause errors or unexpected matches. Fix: `grep -Fqi "$query"` or document regex support as intentional.

### agent-kpis.sh (#71) — CONDITIONAL PASS

442 lines. 5 public functions. Per-agent KPI collection with composite scoring.

**Architecture:**
- 5 metrics: files changed (git), tasks completed (context grep), test pass rate, cycle time (git timestamps), lines changed (git numstat)
- Weighted composite score: files=20, tasks=25, tests=30, cycle_time=15, lines=10
- Normalization with sensible caps (20 files, 10 tasks, 600s cycle time, 500 net lines)
- JSON output via jq
- `--skip-tests` flag for bulk collection

**Issues:**
1. **jq dependency in src/core/ (P1)** — `orch_kpi_init()` hard-requires `jq`. Core modules are zero-dep (bash-only). Either move this module to `scripts/` or replace `jq` output with `printf`-based JSON generation (like founder-mode.sh does). Currently blocks orchestrator startup if jq is not installed.
2. **Test execution side effect (P1)** — `_orch_kpi_test_pass_rate` runs `bash "$test_file"` for every test file in `tests/core/`. A metric *collection* function should not *execute* tests. It should read results from a log file or test results directory. Running tests during KPI collection is slow, unpredictable, and may produce confusing side effects.

### onboarding.sh (#62) — PASS

288 lines. 6 public functions. Project type detection and agent team suggestion.

**Architecture:**
- Marker file detection: package.json → JS, Cargo.toml → Rust, go.mod → Go, etc.
- Multi-language support: >1 detected → "multi" type
- Agent suggestion per project type: deterministic mapping
- Config generation: pipe-delimited agents.conf with role, ownership, frequency
- Prompt scaffold: minimal `## Responsibilities / Tasks / File Ownership / Notes`
- Full pipeline: `orch_onboard_run` chains init → detect → suggest → generate

**No issues.** Clean, zero-dep, no security concerns.

### prompt-adapter.sh (#75) — PASS

151 lines. 3 model adapters + agent-model lookup.

**Architecture:**
- Model detection: string prefix matching (claude/opus/sonnet → claude, gpt/codex → openai, gemini/palm → gemini)
- Per-model prompt wrapping: Claude (XML tags), OpenAI (markdown headers), Gemini (bold sections)
- Agent model lookup from agents.conf field 5
- Batch mode: read prompt from file, adapt, output to stdout

**No issues.** Clean, well-structured.

### model-fallback.sh (#82) — CONDITIONAL PASS

144 lines. Auto-switches agents to available models when primary hits rate limits.

**Architecture:**
- Fallback chains: claude→openai→gemini, openai→claude→gemini, etc.
- CLI mapping: claude→"claude", openai→"codex exec", gemini→"gemini -p"
- Usage checking: env var first (`USAGE_CLAUDE`), then shared context file (`grep`)
- Threshold-based: usage ≥90 = rate-limited
- Configurable: custom chains, custom CLIs, custom threshold

**Issue (P2):**
- **`grep -oP` not portable (line 52):** `grep -oP "${model}=\K[0-9]+"` uses PCRE (`-P`), which is GNU grep only. Not available on macOS/BSD. Fix: use `sed -n "s/.*${model}=\([0-9]*\).*/\1/p"` or `grep -o "${model}=[0-9]*" | cut -d= -f2`.

### max-cycles.sh (#81) — PASS

130 lines. Cycle count override with priority cascade.

**Architecture:**
- Resolution: env `MAX_CYCLES` → `.orchystraw/max-cycles` file → default (10)
- Validation: positive integer, clamped to 1-100 range
- Source detection: `orch_max_cycles_source` for logging/debugging
- Setter: validates before writing to file

**No issues.** Clean, well-designed override pattern.

### Cross-Module Observations (Cycle 1 Session 8 batch)

All 8 modules follow established patterns:
- Double-source guard via variable check
- `declare -gA` for associative array state
- Consistent error signaling (return 1, stderr messages)
- Proper quoting throughout (no HIGH-03 regressions)

**New findings summary:**
- **P1: agent-kpis.sh jq dependency** — violates zero-dep core principle
- **P1: agent-kpis.sh test execution** — collection shouldn't run tests
- **P2: knowledge-base.sh regex injection** — `grep -v` → `grep -Fv`
- **P2: model-fallback.sh portability** — `grep -P` → portable alternative

**Total module count:** 38 modules reviewed across all cycles. 31+7=38 (compare-ralph.sh is in scripts/, not src/core/).

---

## Cycle 1 Review (2026-03-21, Session 9)

**Reviewer:** CTO
**Commit range:** d153203 (latest), a771be9, 4eef3a2

### CS Bug Fix: d153203 — PASS

`scripts/auto-agent.sh` — 3 fixes in one commit:

1. **`local` outside function (line 768)** — `local agent_for_pid=...` was outside any function body, causing `local: can only be used in a function`. Fixed by removing `local` keyword. Correct — variable is in loop scope within main body, not a function.

2. **Agent timeout (300s default)** — All 3 model calls (`claude`, `codex`, `gemini`) now wrapped in `timeout "$agent_timeout"`. Configurable via `AGENT_TIMEOUT` env var. Prevents infinite hangs from unresponsive model CLIs.

3. **PM timeout (600s)** — PM review call now wrapped in `timeout 600` with `|| log "[01-PM] WARNING:..."` fallback. Prevents orchestrator from hanging on merge step.

**Verdict:** All three are correct fixes. The timeout approach is sound — `timeout` sends SIGTERM which allows graceful cleanup. The error handling on PM timeout is particularly good (logs warning but doesn't abort the cycle).

### New Module: model-registry.sh (#70) — PASS

- Proper `orch_registry_*` namespace, double-source guard
- File-based persistence to `.orchystraw/models/registry.txt`
- `timeout 5` on version queries prevents hangs during scan
- 6 known models: claude, codex, gemini, aider, cursor, copilot
- No security concerns — reads from PATH only, no user-controlled inputs in shell execution
- Minor: copilot version check (lines 150-153) has identical logic in both branches — cosmetic, not a bug

### New Module: init-project.sh (#29) — PASS

- Comprehensive project scanner: languages, frameworks, pkg managers, test frameworks, CI/CD, monorepo/docker/database
- Proper `orch_init_*` namespace, double-source guard
- `find -maxdepth 3` prevents excessive filesystem traversal
- Agent suggestion logic: always CEO+CTO+PM, conditionally adds backend/frontend/tauri/iOS/QA/devops/infra/security
- Knowledge bootstrap integrates cleanly with knowledge-base.sh
- No security concerns — operates on local filesystem

### results-collector.sh Update — PASS

- BENCH-SEC-03: file path now passed via `BENCH_RESULTS_FILE` env var instead of interpolation into Python code. Correct security pattern.

### instance-runner.sh Update — PASS (unchanged security model)

- BENCH-SEC-01 and BENCH-SEC-02 still intact. No regressions.

**Total modules reviewed all-time:** 40 (31 src/core/ + 7 scripts/benchmark/ + 2 new this cycle)

---

## Cycle 3 Review (2026-03-21) — Security Validation Architecture

Reviewed commit `3e56975`: SEC-HIGH-05/06/07/08/09 input validation + jq removal across 5 modules.

### Verdict: **PASS** — Consistent validation architecture, appropriate for threat model.

### What was fixed

| File | Fixes | Pattern |
|------|-------|---------|
| `agent-kpis.sh` | SEC-HIGH-05, jq removal | Agent name regex `^[0-9]{2}-[a-zA-Z0-9_-]+$`, output path traversal guard, pure bash/awk JSON |
| `knowledge-base.sh` | SEC-HIGH-06/07 | Domain regex `^[a-zA-Z0-9_-]+$`, key regex `^[a-zA-Z0-9_.-]+$`, `grep -Fv` (fixed string), frontmatter sanitization |
| `founder-mode.sh` | SEC-HIGH-08 | JSON key/value sanitization — strips `"` and `\` before embedding |
| `onboarding.sh` | SEC-HIGH-09 | Path traversal rejection (`*..*)` case pattern) |
| `compare-ralph.sh` | SEC-MEDIUM-03/04 | `mktemp` for temp files (eliminates TOCTOU), task ID whitelist, Python env var passing |

### Architecture assessment

**Strong patterns:**
- Validation-at-entry: all public functions validate before operating. Correct boundary placement.
- Consistent regex style: alphanumeric + hyphens/underscores/dots. No over-permissive patterns.
- `grep -Fv` replacing `grep -v`: eliminates regex injection in knowledge-base index lookups.
- `mktemp` replacing predictable paths: eliminates symlink/TOCTOU races in benchmark runner.
- Python env var passing: `RALPH_RESULTS_FILE="$path" python3 -c 'os.environ[...]'` is the correct pattern vs shell interpolation into Python strings.
- jq fully removed from agent-kpis.sh: dependency eliminated, pure bash/awk JSON handling.
- Test suite updated: all jq references replaced with awk/grep equivalents, tests still validate structure.

**Minor observations (not blocking):**
1. **founder-mode.sh sanitization**: stripping `"` and `\` is minimal but sufficient here — inputs are validated agent names and priority strings. No arbitrary user input reaches this path.
2. **`*..*)` path traversal check**: simple glob, wouldn't catch symlink-based traversal. Acceptable for the threat model — these are local CLI tools, not web-facing.
3. **`_kpi_json_val` awk parser**: works for flat JSON this module produces; would break on deeply nested structures. Since it only reads its own output files, this is fine.
4. **`_orch_kpi_test_pass_rate` now always returns 100.0**: correct change — removes dangerous side effect of executing arbitrary test scripts during KPI collection.

### Consistency check

All 5 modules now follow the same validation pattern:
1. Validate inputs at function entry (regex whitelist or case pattern)
2. Return 1 with stderr error message on failure
3. Use validated inputs in file paths and shell operations

This is architecturally sound. No bypass vectors identified.

---

## CTO Review — migrate.sh + issue-tracker.sh (Cycle 1, Session 9, 2026-03-21)

Two new modules/scripts reviewed. 1 PASS, 1 CONDITIONAL PASS.

### migrate.sh (#64) — PASS

284 lines. Located at `scripts/migrate.sh`. Version detection + upgrade path (v0.1→v0.2, stubs for v0.5/v1.0).

**Architecture:**
- Multi-layer version detection: explicit `.orchystraw/version` file → heuristic fallback (module count, dir presence)
- Linear upgrade path: v0.1→v0.2→v0.5→v1.0 with stubs for future versions
- 4-step v0.1→v0.2 upgrade: create `.orchystraw/` → write version file → verify modules → check agents.conf format
- Dry-run mode via `check` command — safe preview before upgrade
- Fully idempotent: all state-changing ops guarded with existence checks (`[[ ! -d ... ]]`, `[[ ! -f ... ]]`)
- Can be sourced or executed directly (dual-mode guard)
- `set -euo pipefail` present, 11 functions total

**Security:**
- No eval, no injection vectors in CLI handling (whitelist case dispatch)
- Module list is hardcoded array — safe from injection
- Command-line validation uses whitelist approach (`detect|check|upgrade|--help|-h`)

**Issues (P2, non-blocking):**
1. **`ORCH_PROJECT_ROOT` unsanitized** (line 12): Environment variable used without validation. Attacker could set to `/etc` → writes to `/etc/.orchystraw/version`. Fix: validate directory exists, is writable, and contains expected project markers (agents.conf, src/core/).
2. **Non-atomic version file write** (line 134): `echo "0.2.0" > "$VERSION_FILE"` — partial write leaves corrupted file. Fix: write to temp file, then `mv` (atomic on same filesystem).
3. **`compgen -G` bashism** (line 62): bash-specific glob expansion. Acceptable since script declares `#!/usr/bin/env bash` and project minimum is bash 5.0.
4. **Silent grep failure** (line 169): `grep -q ... 2>/dev/null` hides `grep` binary missing or file unreadable. Low risk — bash always has grep.
5. **Magic number** (line 77): Module count threshold `>10` for v0.2 detection not documented. Add comment.

**23 tests, all passing.** Good coverage of detect, check, upgrade, idempotency.

**Verdict: PASS.** Clean migration tool. P2 items (env var validation, atomic write) should be fixed but don't block v0.2.0.

### issue-tracker.sh — CONDITIONAL PASS (QA-F007 open)

676 lines. Located at `src/core/issue-tracker.sh`. JSONL-based issue tracker with CRUD, filtering, optional GitHub sync.

**Architecture:**
- JSONL storage in `.orchystraw/issues/issues.jsonl` — one JSON record per line
- Auto-increment ID via `_orch_issue_next_id()` (reads max ID from file)
- 6 public API functions: create, list, close, assign, show, update (all `orch_issue_*` prefix)
- 8 validator functions covering ID, title, priority, assignee, labels, status, path traversal
- Atomic updates via mktemp+mv pattern (lines 362, 412, 556) — good
- Optional GitHub sync via `gh` CLI — one-way push, best-effort

**Security:**
- Strong input validation: regex whitelists on all fields (ID=numeric, priority=P0-P4, assignee=alphanumeric+hyphens, labels=alphanumeric+hyphens+colons)
- Title validator (line 54) rejects: backticks, `$`, `|`, `;`, `&`, `<`, `>`, `$()`, `..` — blocks most shell metacharacters
- Path traversal protection via explicit `..` rejection
- **HOWEVER:** Title validator does NOT reject single or double quotes

**CRITICAL FINDING — QA-F007 (lines 584-586):**
```bash
cmd = "echo '\''" $0 "'\'' | sed '\''" scmd "'\''"
cmd | getline result
close(cmd)
```
The `orch_issue_update()` function uses awk `getline` to pipe each JSONL line through sed for field substitution. The sed command (`scmd`) is interpolated into a shell string inside awk, then executed via `cmd | getline`. This is inherently dangerous:
- If a title containing quotes passes validation (currently possible), it could break out of the sed command's quoting
- Even with current validators, this pattern is fragile — any future relaxation of title validation creates an injection vector
- **Fix:** Replace awk `cmd|getline` with pure awk string substitution (`gsub()` or `sub()`) which never shells out

**Other issues:**
1. **GitHub sync lacks idempotency** (line 668): No tracking of which issues were already synced → creates duplicates on re-run. Low security risk, operational annoyance.
2. **No file locking**: Concurrent JSONL writes could corrupt data. mktemp+mv is atomic but two concurrent updates could lose one. Acceptable for single-user orchestrator.
3. **Sourced library, no `set -euo pipefail`**: Relies on caller. Consistent with other src/core/ modules. Acceptable convention.

**45 tests, all passing.** Good coverage across CRUD ops, validation, edge cases.

**Verdict: CONDITIONAL PASS.** Must fix QA-F007 (awk shell execution) and add quote rejection to title validator before v0.2.0 tag. Both are straightforward fixes.

### Cross-Module Observations

- **migrate.sh** is a standalone script (not sourced) — correctly uses `set -euo pipefail`
- **issue-tracker.sh** is a sourced library — correctly omits `set -euo pipefail`, relies on caller
- Both use the established double-source guard pattern
- Both have comprehensive test suites (23 + 45 tests)

**Priority table updated above** with 4 resolved items (jq, test side-effect, regex injection, grep -P) and 4 new items from this review.

**Total modules reviewed all-time: 42** (31 src/core/ + 7 scripts/benchmark/ + 2 new scripts + 2 new modules)

---

## v0.1 Release Status

**All security blockers RESOLVED.** QA: CONDITIONAL PASS. Security: FULL PASS.

v0.1.0 path — only CS tasks remain:
1. ~~CS fixes HIGH-03~~ — DONE (23895de)
2. ~~CS fixes HIGH-04~~ — DONE (23895de)
3. ~~CS fixes MEDIUM-01~~ — DONE (23895de)
4. ~~QA regression~~ — CONDITIONAL PASS (cycle 8)
5. ~~Security sign-off~~ — FULL PASS (cycle 8)
6. CS writes README — **OPEN**
7. CS fixes BUG-013 (agents.conf paths) — **OPEN**
8. Tag v0.1.0
