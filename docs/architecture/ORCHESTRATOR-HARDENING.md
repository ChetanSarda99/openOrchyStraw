# Orchestrator Hardening — Priority Issues

_Date: March 18, 2026_
_Status: SPEC — for backend agent to implement_

---

## Issues Found (Cycle 1 Review)

### P0: Bash Version Check (Missing)

`auto-agent.sh` uses `declare -A` (bash 4+) but has no version guard.
Documented in PLATFORM-COMPATIBILITY.md but never implemented.

**Fix:**
```bash
# Add after set -uo pipefail (line 23):
if ((BASH_VERSINFO[0] < 4)); then
    echo "ERROR: bash 4+ required. macOS: brew install bash"
    exit 1
fi
```

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

### P2: `eval` Usage in commit_by_ownership

Lines 236-237 use `eval` to expand paths. This is a shell injection risk if `agents.conf` contains malicious paths.

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

## Not Blocking v0.1 Release

These are spec'd here for the backend agent. The orchestrator works — these are hardening improvements, not blockers.
