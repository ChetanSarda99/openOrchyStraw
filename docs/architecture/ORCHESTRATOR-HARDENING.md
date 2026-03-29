# Orchestrator Hardening — Priority Issues

_Date: March 18, 2026 (updated 2026-03-29)_
_Status: ALL SECURITY BLOCKERS RESOLVED — v0.1 release gate clear_
_Reviewed by: CTO 2026-03-29 — verified 601c9a2 fixes (HIGH-03, HIGH-04, MEDIUM-01)_

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
