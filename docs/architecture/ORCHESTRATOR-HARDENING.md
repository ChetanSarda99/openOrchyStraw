# Orchestrator Hardening — Priority Issues

_Date: March 18, 2026 (updated cycle 2)_
_Status: SPEC — for backend agent to implement_
_Reviewed by: CTO cycle 2 — deeper audit confirmed all findings, added new issues_

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

## Priority Summary (Cycle 2)

| Priority | Issue | Owner | Status |
|----------|-------|-------|--------|
| **P0** | Bash 5.0 version guard | 06-backend | SPEC (BASH-001) |
| **P0** | eval injection fix (3 calls) | 06-backend | SPEC |
| **P1** | Add `set -e` to auto-agent.sh | CS (protected) | SPEC |
| **P1** | Shebang standardization | 06-backend | SPEC |
| **P1** | .gitignore expansion | 06-backend | SPEC |
| **P1** | Signal handling | 06-backend | SPEC (cycle 1) |
| **P1** | Empty cycle detection | 06-backend | SPEC (cycle 1) |
| **P0** | Ownership overlap fix | CS (agents.conf) | SPEC (cycle 1) |
| **P2** | Progress checkpoint fix | 06-backend | SPEC (cycle 1) |
| **P2** | src/ overlap | PM | DOCUMENT |
| **P2** | auto-agent.sh ownership | PM | DOCUMENT |

## Blocking v0.1 Release

**P0 items are now blocking.** The eval injection and missing version guard must be fixed
before v0.1.0 tag. The .gitignore gaps (P1) should also be fixed — committing secrets
to a public repo is not recoverable.
