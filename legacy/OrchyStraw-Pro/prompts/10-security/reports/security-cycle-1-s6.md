# Security Audit — Cycle 1, Session 6
**Date:** 2026-03-20 14:45
**Auditor:** 10-Security (Claude Opus 4.6)
**Verdict:** CONDITIONAL PASS — #77 integration SECURE, 1 NEW HIGH finding, benchmark harness still OPEN

---

## Summary

This audit covers the #77 integration that finally shipped (b1c7a78 + fixes 00ca24f, c208a37). Three commits expanded auto-agent.sh from 8 to 31 sourced modules and added 8 lifecycle hook points. Also re-evaluated all prior findings.

1. **#77 integration** — SECURE. Module sourcing is guarded, lifecycle hooks use safe patterns.
2. **CRITICAL-01 DOWNGRADED → INFO** — deeper analysis shows env var passing to PowerShell is NOT vulnerable to subexpression injection. XML entity encoding is complete.
3. **CRITICAL-02 (benchmark)** — STILL OPEN. No changes to run-swebench.sh.
4. **NEW HIGH-05:** auto-agent.sh removed from PROTECTED_FILES array — should be RE-PROTECTED now that #77 is shipped.
5. Secrets scan — CLEAN
6. Agent ownership — PASS
7. Supply chain — PASS

---

## #77 Integration Security Review

### Module Sourcing (lines 30-40) — PASS
```bash
for mod in bash-version logger error-handler cycle-state agent-timeout dry-run \
           config-validator lock-file signal-handler usage-checker init-project \
           conditional-activation dynamic-router model-router model-budget \
           context-filter prompt-compression prompt-template session-windower \
           task-decomposer token-budget file-access quality-gates review-phase \
           self-healing cycle-tracker qmd-refresher vcs-adapter worktree-isolator \
           single-agent agent-as-tool; do
    [ -f "$PROJECT_ROOT/src/core/${mod}.sh" ] && source "$PROJECT_ROOT/src/core/${mod}.sh"
done
```
- Module names are hardcoded strings (not from user input) ✅
- Existence check before source ✅
- Modules are in-repo, under version control ✅
- No path traversal possible (mod names are fixed alphanumeric-plus-hyphen) ✅

### Lifecycle Hooks (8 hooks) — PASS
All hooks follow the same safe pattern:
```bash
type -t orch_function_name &>/dev/null && orch_function_name [args] 2>/dev/null || true
```
- `type -t` checks function existence before calling ✅
- `2>/dev/null` suppresses errors ✅
- `|| true` prevents pipeline failure ✅
- Functions are defined by sourced modules (in-repo, version-controlled) ✅

Hooks added:
| Hook | Location | Risk |
|------|----------|------|
| `orch_signal_init` | Pre-cycle (line 727) | LOW — runs once per cycle |
| `orch_init_project` | Pre-cycle (line 728) | LOW — receives `$PROJECT_ROOT` (trusted) |
| `orch_should_run_agent` | Agent eligibility (line 741) | LOW — boolean return |
| `orch_self_heal` | On failure (line 765) | MEDIUM — receives agent ID |
| `orch_quality_gate` | Post-agents (line 771) | LOW — receives cycle number |
| `orch_track_cycle` | Post-commit (line 807) | LOW — receives counts |
| `orch_refresh_qmd` | Post-commit (line 808) | LOW — no args |

### `--permission-mode bypassPermissions` (line 171) — INFO
Added alongside existing `--dangerously-skip-permissions`. Redundant but not a new risk — agents already had full permissions.

---

## Finding Updates

### CRITICAL-01: DOWNGRADED → INFO (False Positive)
**Previous:** PowerShell XML injection via toast notifications
**Re-analysis:** The `notify()` function uses env var passing (`ORCH_TOAST_TITLE="$safe_title"` → `$env:ORCH_TOAST_TITLE`). In PowerShell:
1. `$title = $env:ORCH_TOAST_TITLE` — direct assignment, no string interpolation
2. `$template = "...$title..."` — variable substitution only; PowerShell does NOT recursively evaluate `$(...)` patterns inside variable values during string interpolation
3. `$xml.LoadXml($template)` — XML entity encoding covers all 5 predefined entities (`&`, `<`, `>`, `"`, `'`)

**Verdict:** Not exploitable. The env var isolation pattern is the correct defense. Downgraded to INFO.

### CRITICAL-02: STILL OPEN — Benchmark git apply injection
**File:** `scripts/benchmark/run-swebench.sh` line 191
No changes since cycle 31. `echo "$test_patch" | git apply --allow-empty` with no patch format validation.
**Assign to:** 06-backend

### HIGH-01: STILL OPEN — Unvalidated TASK_REPO
**File:** `scripts/benchmark/run-swebench.sh` line 104
No changes. `git clone "https://github.com/$TASK_REPO.git"` without regex validation.
**Assign to:** 06-backend

---

## NEW Finding

### HIGH-05: auto-agent.sh Removed from PROTECTED_FILES
- **File:** `scripts/auto-agent.sh` line 311
- **Change:** `"scripts/auto-agent.sh"` commented out with `# NOTE: auto-agent.sh removed from protection to allow module integration (#77)`
- **Issue:** Now that #77 is shipped, auto-agent.sh should be RE-PROTECTED. The orchestrator script is the highest-privilege file in the system. Any agent with overlapping ownership could modify it.
- **Risk:** Agent escape — a hallucinating agent could inject arbitrary code into the orchestrator, which runs with `--dangerously-skip-permissions`. This is the most powerful write target in the repo.
- **Remediation:** Uncomment line 311 to restore protection. #77 is done, there's no reason to leave it unlocked.
- **Severity:** HIGH — leaving the orchestrator unprotected post-fix is an unnecessary risk
- **Assign to:** CS (one-line change, protected file)

---

## Carried Forward

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| CRITICAL-02 | CRITICAL | OPEN | git apply injection in benchmark harness (line 191) |
| HIGH-01 | HIGH | OPEN | Unvalidated TASK_REPO in git clone (line 104) |
| HIGH-02 | HIGH | OPEN | echo -e with untrusted filenames in detect_rogue_writes |
| HIGH-03 | HIGH | OPEN | Race condition in parallel git operations |
| HIGH-04 | HIGH | OPEN | TOCTOU temp file via predictable `${pf}.tmp` names |
| **HIGH-05** | **HIGH** | **NEW** | auto-agent.sh unprotected — re-protect now |
| LOW-02 | LOW | OPEN (v0.1.1) | Unquoted `$all_owned` line 358 |
| QA-F001 | LOW | OPEN (v0.1.1) | Add `set -e` to auto-agent.sh |

---

## Checklist Results

### Secrets & Credentials — PASS ✅
- [x] No API keys in any file (full repo scan, 268 commits)
- [x] No tokens or passwords in source
- [x] `.gitignore` covers `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`
- [x] No `.env` files present
- [x] Git history clean

### Agent Isolation — CONDITIONAL PASS ⚠️
- [x] Ownership boundaries defined in agents.conf
- [x] Shared context is the only cross-agent channel
- [ ] auto-agent.sh is NOT protected (HIGH-05) — agents could modify it

### Script Safety — CONDITIONAL PASS ⚠️
- [x] No `eval` on untrusted input
- [x] Lifecycle hooks use safe `type -t` guard pattern
- [x] Module names are hardcoded (no injection vector)
- [ ] echo -e with untrusted data (HIGH-02 carried)
- [ ] Predictable temp files (HIGH-04 carried)
- [ ] Benchmark harness unvalidated (CRITICAL-02 carried)

### Supply Chain — PASS ✅
- [x] No new dependencies in core
- [x] No curl|bash patterns
- [x] GitHub workflow minimal permissions

---

## Severity Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 1 | CARRIED — benchmark git apply |
| HIGH | 5 | 1 NEW (unprotected orchestrator), 4 carried |
| LOW | 2 | CARRIED — v0.1.1 backlog |
| INFO | 1 | CRITICAL-01 downgraded (not exploitable) |

---

## Recommendations

1. **P0:** Re-protect auto-agent.sh immediately (HIGH-05) — one line uncomment, CS must do it
2. **P1:** Fix CRITICAL-02 + HIGH-01 in benchmark harness before any benchmark runs
3. **P2:** Migrate echo -e → printf in detect_rogue_writes (HIGH-02)
4. **P2:** Use mktemp for prompt update temp files (HIGH-04)

---

## Next Audit Focus
- Verify HIGH-05 fix (auto-agent.sh re-protected)
- Verify benchmark harness fixes when shipped
- Monitor lifecycle hook implementations in new modules
