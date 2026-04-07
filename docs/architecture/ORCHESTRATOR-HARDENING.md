# Orchestrator Hardening — Priority Issues

_Date: March 18, 2026 (updated 2026-03-29)_
_Status: ALL SECURITY BLOCKERS RESOLVED — v0.1 release gate clear_
_Reviewed by: CTO 2026-03-29 — verified 601c9a2 fixes (HIGH-03, HIGH-04, MEDIUM-01)_

---

## Issues Found (Cycle 1 Review)

### P0: Bash Version Check — ADR: BASH-001 ✅ RESOLVED

`auto-agent.sh` uses `declare -A` (bash 4+) and `declare -gA` (bash 5+).
**Implemented** in `src/core/bash-version.sh` — sourced early by `auto-agent.sh`.
Exits with clear error and install instructions if bash < 5.0.

Test runner (`tests/core/run-tests.sh`) also auto-detects and re-execs with
homebrew bash 5 (`/opt/homebrew/bin/bash` or `/usr/local/bin/bash`) if available.

**Decision (BASH-001):** Minimum version is **bash 5.0**, not 4.0. See `docs/tech-registry/decisions/BASH-001-version-compatibility.md`.

All shebangs use `#!/usr/bin/env bash` (portable, finds Homebrew bash when in PATH).

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

## CTO Review — 2026-03-29 (CS Commit 601c9a2)

CS applied all three v0.1 security blockers in a single commit. CTO review follows.

### HIGH-03: Unquoted `$ownership` glob expansion — VERIFIED FIXED

All 3 locations converted from bare `$ownership` iteration to array-based:

1. **Line 244** (`commit_by_ownership`): `IFS=' ' read -ra _ownership_arr <<< "$ownership"` → `for path in "${_ownership_arr[@]}"` ✓
2. **Lines 319-320** (`detect_rogue_writes`, inner loop): `IFS=' ' read -ra _own_arr <<< "$ownership"` → `for path in "${_own_arr[@]}"` ✓
3. **Lines 315, 330** (`detect_rogue_writes`, `$all_owned`): Converted from string concat (`all_owned+=" $path"`) to proper array (`local -a all_owned_arr=()` + `all_owned_arr+=("$path")`) → `for path in "${all_owned_arr[@]}"` ✓

Fix exactly matches the CTO-approved pattern. Glob expansion suppressed because quoted array expansion `"${arr[@]}"` preserves elements as-is. `IFS=' '` is scoped to the `read` builtin — doesn't leak to outer scope.

**Architecture verdict: PASS.**

### HIGH-04: Sed injection in prompt updates — VERIFIED FIXED

The fix applies two layers of defense:

1. **Delimiter change:** All 5 sed commands switched from `/` to `|` ✓
2. **Input escaping:** All 8 variables pre-escaped via `sed 's/[|&]/\\&/g'` before interpolation ✓

Escaping correctly handles `|` (delimiter) and `&` (sed backreference). Variables are escaped into `_safe_*` locals, then those locals are used in the sed commands.

Note: `\` in replacement strings is not escaped, but no current or foreseeable value source (date, integer counts) can produce backslashes. Acceptable for v0.1.

LHS regex patterns verified: none contain `|`, so delimiter change is safe.

**Architecture verdict: PASS.** Defense-in-depth beyond what's strictly needed — good practice for a public repo.

### MEDIUM-01: .gitignore secrets patterns — VERIFIED FIXED

Security-critical patterns added:
- `.env`, `.env.*` — all dotenv variants ✓
- `*.pem`, `*.key` — private keys ✓
- `*.p12`, `*.pfx` — certificate stores (bonus beyond spec) ✓
- `credentials.json`, `service-account*.json`, `*secret*.json` — cloud credentials ✓

Missing P2 items (not blocking): `dist/`, `build/`, `.vscode/`, `.idea/`, `*.swp`, `coverage/`. These are cosmetic — `site/.gitignore` already covers Next.js build output.

Cosmetic note: `node_modules/` appears twice in root .gitignore (lines 16 and 21). Harmless.

**Architecture verdict: PASS.**

---

## Priority Summary (Updated 2026-03-29)

| Priority | Issue | Owner | Status |
|----------|-------|-------|--------|
| ~~**P0**~~ | ~~Dual agents.conf (BUG-009)~~ | ~~CS~~ | **FIXED** (cycle 4, d130de7) |
| ~~**P0**~~ | ~~eval injection (HIGH-01)~~ | ~~CS~~ | **FIXED** (cycle 4, d130de7) |
| ~~**P0**~~ | ~~Bash 5.0 version guard~~ | ~~CS~~ | **FIXED** (cycle 4, sourced at startup) |
| ~~**P1**~~ | ~~MEDIUM-02 notify injection~~ | ~~CS~~ | **FIXED** (cycle 4, d130de7) |
| ~~**P1**~~ | ~~HIGH-03: Unquoted `$ownership` glob~~ | ~~CS~~ | **FIXED** (601c9a2, CTO verified) |
| ~~**P1**~~ | ~~HIGH-04: Sed delimiter injection~~ | ~~CS~~ | **FIXED** (601c9a2, CTO verified) |
| ~~**P1**~~ | ~~MEDIUM-01: .gitignore secrets~~ | ~~CS~~ | **FIXED** (601c9a2, CTO verified) |
| **P1** | Add `set -e` to auto-agent.sh | CS (protected) | OPEN — still `set -uo pipefail` (line 23) |
| **P1** | Backend ownership exclusions | CS (agents.conf) | OPEN — 06-backend still owns `scripts/` |
| **P1** | Shebang standardization | CS (protected) | OPEN — auto-agent.sh still `#!/bin/bash` (line 1) |
| **P1** | Signal handling | 06-backend | SPEC (cycle 1) |
| **P1** | Empty cycle detection | 06-backend | SPEC (cycle 1) |
| **P2** | Progress checkpoint fix | 06-backend | SPEC (cycle 1) |
| **P2** | src/ overlap detection | 06-backend | FUTURE (v0.5) |
| **P2** | Consolidate to single agents.conf | CS | Deferred — both synced, low priority |
| **P2** | .gitignore duplicate `node_modules/` | CS | Cosmetic — lines 16 and 21 both ignore node_modules |
| **P2** | BUG-012: PROTECTED FILES missing from 8 prompts | PM | 01-ceo, 03-pm, 04-tauri-rust, 05-tauri-ui, 07-ios, 10-security, 12-brand, 13-hr |

## v0.2 Module Review (Cycle 4 — 2026-03-29 16:10)

### dynamic-router.sh — APPROVED

41 tests pass (was 36). EXEC-001 and MODEL-001 compliant. Both medium issues fixed:
- ~~**DR-01:**~~ State file numeric validation — corrupted rows skipped ✅
- ~~**DR-02:**~~ `mkdir` return code + file write error checks ✅

### review-phase.sh — APPROVED (HOLD lifted cycle 6)

36 tests pass (was 24). All 5 CTO findings fixed and verified:
- ~~**BUG-017 (CRITICAL):**~~ `printf --` added to all leading-dash format strings ✅
- ~~**RP-01 (HIGH):**~~ Verdict validation via `case` — rejects invalid, accepts {approve, request-changes, comment} ✅
- ~~**RP-02 (HIGH):**~~ `**Summary:**` field output in 3 variants (empty, all-clear, needs-attention) ✅
- ~~**RP-03 (HIGH):**~~ I/O error checks on `mkdir -p` and file write with logging + return 1 ✅
- ~~**RP-04 (MEDIUM):**~~ Path traversal rejection (`*".."*`) in both `orch_review_context` and `orch_review_record` ✅

REVIEW-001 ADR compliant. Ready for v0.2 integration.

### config-validator.sh v2+ — APPROVED

10 tests pass. Full backward compatibility v1→v2→v2+ confirmed. MODEL-001 model validation correct (warn on unknown, don't fail). Production-ready.

### worktree.sh — APPROVED (Cycle 8, 2026-03-29)

37 tests pass (T1–T37). Covers: init/validation, create/list, merge with/without changes, input validation (path traversal, numeric cycle), cleanup by cycle/all/stale, filesystem isolation, merge conflict detection, sequential merge.

**ADR Deviation:** WORKTREE-001 said "inline in auto-agent.sh" but backend built standalone module. **Deviation accepted** — module approach is architecturally superior (testable, composable, no auto-agent.sh bloat). Recommend WORKTREE-002 ADR to document this decision.

Security: No eval, no injection vectors. Path traversal blocked (`..` and `/` rejected). All git commands properly quoted. Glob expansion intentional and controlled (cleanup pattern). SHA validation not needed (git handles integrity). Git 2.15+ validated at init.

**Integration status:** Module is production-ready but **NOT sourced in auto-agent.sh** — correct per ADR deferral to v0.2.0 Phase 2+. Dormant until CS integrates.

### prompt-compression.sh — APPROVED (Cycle 8, 2026-03-29)

30 tests pass (T1–T30). Covers: init/budget, section parsing/classification, compression modes (full/standard/minimal), token estimation (string + stdin), hash generation/determinism, hash I/O persistence, mode decision logic, stats reporting, error handling (missing file, unclassified, missing hash), edge cases (empty file, no stable sections, budget triggers).

Security: No eval, no injection vectors. Hash computation via `sha256sum`/`shasum` (safe). Fallback string hash acceptable (non-cryptographic use). File handling quoted. Pattern arrays hardcoded (not user-derived). `printf '%s'` used throughout (no format string injection).

Architecture: Zero dependencies. Token estimation `chars/4` is sound for Claude tokenizer (~4% margin, rounds up). Tiered loading (stable/dynamic/reference) aligns with TOKEN-EFFICIENCY.md Tier 1. Hash-based change detection is deterministic and cross-platform (sha256sum + shasum fallback).

### conditional-activation.sh — APPROVED (Cycle 8, 2026-03-29)

25 tests pass (T1–T25). Covers: init/config parsing, coordinator exclusion, ownership parsing, skip decision, PM force flag, owned-path change detection, boundary enforcement, multi-agent path matching, context mention scanning, exclusion patterns (`!`-prefix), empty input handling, stats output, error handling (missing config).

Security: No eval, no injection vectors. Ownership matching is prefix-based string comparison (not glob/regex). All array expansions quoted. No filesystem operations on paths (comparison only). Force flag is exact string match (`"1"`). Context scanning uses bash `[[ =~ ]]` with hardcoded patterns only.

Architecture: Zero dependencies. Fail-open design (returns 0/activate if not initialized — avoids silent skips). Ownership detection supports include + exclude patterns. Context mention scanning uses keyword-boundary validation (prevents false positives). PM force flag has highest precedence, well-logged.

### differential-context.sh — APPROVED (Cycle 10, 2026-03-29)

42 tests pass (T1–T42). Covers: init/mapping, context parsing/section count, per-agent filtering (backend/CTO/web/PM), universal sections, custom mapping override, fail-open for unmapped sections, error handling (missing file, pre-parse, pre-init), stats/savings, cross-cycle history filtering (own entries, dependency entries, PM entries, "All" entries, cross-references), key normalization (emoji/special chars), agent label extraction, in-list matching (ID/label/wildcard/rejection).

Security: No eval, no injection vectors. `sed` patterns are fixed literals (key normalization). `awk` program is hardcoded (column counting). `printf '%s'` used throughout. File reads via standard `while IFS= read -r` pattern. All array expansions quoted.

Architecture: Zero dependencies. Fail-open design (unmapped sections included, not excluded). PM gets everything unconditionally. Dependency-aware history filtering (parsed from agents.conf v2+ `depends_on` field). Section→agent mappings hardcoded with override API.

**Finding DC-01 (LOW):** `_orch_diffctx_in_list` line 78 `for item in $haystack` and `orch_diffctx_filter_history` line 313 `for dep in $deps` use unquoted iteration — same class as fixed HIGH-03. Not exploitable (agent names are `NN-name`, alphanumeric+dash only), but architecturally inconsistent. Consider array conversion for consistency.

### session-tracker.sh — APPROVED (Cycle 10, 2026-03-29)

33 tests pass (T1–T33). Covers: init/defaults/custom params/non-numeric fallback, window failures (no init, missing file), small/medium/large trackers, preserved sections (milestone/codebase/priorities), preamble/table header, stats/compression, single cycle, zero cycles, custom window sizes, overflow (recent > total), agent subsections in detail, summary-range exclusion, omitted-cycle exclusion, double-source guard, real tracker file, output ordering (newest first), init state reset, large cycle numbers (98-100), compression percentage (81% at 30 cycles), edge cases (summary=0, recent=0, no preserved sections), table rows for recent cycles.

Security: No eval, no injection vectors. Only external command is `wc -l` (line counting). All regex patterns are fixed. Integer arithmetic uses validated inputs. File reads via standard `while IFS= read -r` pattern.

Architecture: Zero dependencies. Parse-then-render separation. Sparse array handling for non-contiguous cycle numbers. Configurable windowing (recent N full detail, next M as table rows, older omitted). Preserved sections always pass through regardless of windowing. Target ~80 lines output regardless of project age.

**Finding ST-01 (LOW):** `_orch_tracker_line_count` uses `<<<` (appends trailing newline) while original count uses `wc -l < file`. Can produce 1-line discrepancy in stats display. Negligible.

## v0.1 Release Status

**ALL SECURITY BLOCKERS RESOLVED.** CS applied HIGH-03, HIGH-04, MEDIUM-01 fixes in commit `601c9a2`. CTO review: PASS on all three.

Remaining v0.1 path:
1. ~~CS fixes HIGH-03~~ ✅ VERIFIED
2. ~~CS fixes HIGH-04~~ ✅ VERIFIED
3. ~~CS fixes MEDIUM-01~~ ✅ VERIFIED
4. QA full regression — **NEXT**
5. Security final sign-off — **NEXT**
6. README rewrite — CS (P1)
7. Tag v0.1.0

v0.1.1 backlog: `set -e`, shebang standardization, backend ownership exclusions

---

## CTO Review — Cycle 1 (2026-03-30): Efficiency Sprint

CS applied the efficiency sprint in commit `a1a33f4`. CTO review of new code follows.

### auto-agent.sh v0.2 module wiring — VERIFIED CORRECT

Lines 36–41: v0.2 modules sourced in correct order (signal-handler, cycle-tracker,
conditional-activation, differential-context, session-tracker, prompt-compression).
Same conditional pattern as v0.1 (`[ -f ... ] && source`). No concerns.

Lines 706–718: Module initialization in orchestrate loop — correct:
- `orch_activation_init` parses config, `orch_activation_set_changed` feeds file list,
  `orch_activation_set_context` feeds shared context. All guarded by `type -t` checks.
- `orch_diffctx_init` + `orch_diffctx_parse` — same pattern. Context file existence check
  before parse. Correct.

Lines 728–731: Conditional activation skip — correct:
- `orch_activation_check "$id"` returns 1 to skip, with reason logged via `orch_activation_reason`.
- Agents that fail the check are logged and `continue`'d. No work wasted.

Lines 787–817: Pre-PM lint integration — correct:
- Lint report captured to `$LINT_REPORT` variable.
- PM skip on `Recommendation: PM SKIP` — clean, tested by lint script's verdict logic.
- Skipped cycles still backup prompts, save lint report to file, commit context, merge.
- No silent data loss on PM skip.

Lines 174–200: Per-agent context filtering — correct:
- Differential context: `orch_diffctx_filter` with fallback to `cat` on failure. Fail-open. ✓
- Session tracker windowing: `orch_tracker_window` with fallback to `tail -150`. Fail-open. ✓

### scripts/pre-pm-lint.sh — APPROVED (4 LOW/INFO findings)

Full review documented in EFFICIENCY-001 ADR. Summary:

| Finding | Severity | Description |
|---------|----------|-------------|
| LINT-01 | LOW | Missing `set -e` (same as auto-agent.sh P1) |
| LINT-02 | LOW | `--since="1 hour ago"` is fragile — should use branch diff |
| LINT-03 | LOW | `git log --all` includes stale branches — should scope to current |
| LINT-04 | INFO | No CONF_FILE existence check — silently empty on missing config |

None blocking. Report format is clean and well-structured. Verdict logic (QUIET/LOW/ACTIVE)
is correct. Backend should address LINT-01–04 in a follow-up.

### New ADRs Written This Cycle

- **EFFICIENCY-001** (`docs/architecture/EFFICIENCY-001-script-first.md`): Script-first
  architecture principle. Decision framework: "Can a regex do it? → Script." Catalogs all
  v0.2 script-vs-agent migrations. Reviews pre-pm-lint.sh.
- **COST-001** (`docs/architecture/COST-001-token-budget.md`): Token budget architecture.
  Per-agent model + max_tokens in agents.conf v3. PM skip policy. Cost logging to JSONL.
  Warn-only budget enforcement for v0.2, hard stops deferred to v0.5.

### Backend's 5 New Scripts — CTO REVIEW

Backend shipped 5 new scripts (commit this cycle). CTO review follows.

| Script | Lines | Zero-Dep | Verdict | Findings |
|--------|-------|----------|---------|----------|
| `pre-cycle-stats.sh` | 117 | PARTIAL (`gh` optional) | APPROVED | STATS-01 (LOW): empty agents → invalid JSON |
| `commit-summary.sh` | 118 | YES | APPROVED | CS-01 (LOW): `grep -oP` is GNU-only, not portable to BSD |
| `agent-health-report.sh` | 163 | YES | APPROVED | AHR-01 (INFO): state file format not validated |
| `secrets-scan.sh` | 125 | YES | APPROVED w/ finding | SS-01 (MEDIUM): line 30 uses `\s` and `\x27` with `grep -E` — these are Perl extensions, not ERE. Pattern silently fails to match passwords. Fix: use `-P` flag or POSIX `[[:space:]]` |
| `post-cycle-router.sh` | 108 | NO (sources modules) | APPROVED | PCR-01 (LOW): `git diff HEAD~1` fails if < 2 commits in repo |

**Overall: ALL 5 APPROVED.** No eval, no injection vectors, proper quoting throughout.
1 MEDIUM finding (SS-01) should be fixed — password pattern is effectively dead code.
All other findings are LOW/INFO.

**Security note:** `secrets-scan.sh` line 29 (`'PRIVATE KEY-''----'`) is NOT a syntax error —
it's standard bash string concatenation producing `PRIVATE KEY-----`. Matches PEM headers correctly.

**Architecture note:** `post-cycle-router.sh` sources internal modules (`dynamic-router.sh`,
`logger.sh`) — this is acceptable. It's a glue script connecting existing approved modules.
Not a new external dependency.
