# Security Audit — Cycle 2
**Date:** 2026-03-18
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** Remediation verification + new module scan

---

## Verdict: CONDITIONAL PASS — 1 HIGH remains open

v0.1.0 release is BLOCKED until HIGH-01 is remediated.

---

## Remediation Status (from Cycle 1)

| ID | Finding | Status | Notes |
|----|---------|--------|-------|
| HIGH-01 | `eval` injection in `commit_by_ownership()` | **OPEN** | Lines 236-237, 241 still use `eval` on unquoted config-derived paths |
| HIGH-02 | `--dangerously-skip-permissions` | **ACCEPTED RISK** | Documented, no change expected |
| MEDIUM-01 | `.gitignore` missing sensitive patterns | **FIXED** | `.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json` all present |
| MEDIUM-02 | PowerShell notify injection | **OPEN** | Line 62: `$escaped_title` is XML-escaped but not PowerShell-escaped; `$(...)` in title would execute |
| LOW-01 | No lock file mechanism | **FIXED** | `src/core/lock-file.sh` implements PID-tracked lock with stale detection |
| LOW-02 | Missing `set -e` | **ACCEPTED** | Intentional design for orchestrator resilience |

---

## HIGH-01 Detail (Still Open)

**File:** `scripts/auto-agent.sh:236-241`

Three `eval` calls remain in `commit_by_ownership()`:
```bash
local changes=$(eval "git diff --name-only -- $include_paths $exclude_paths" ...)
local untracked=$(eval "git ls-files --others --exclude-standard -- $include_paths $exclude_paths" ...)
eval "git add -- $include_paths $exclude_paths" ...
```

**Risk:** Command injection via crafted ownership paths in `agents.conf`. A path like `$(rm -rf /)` would execute inside eval.

**Required fix:** Replace eval with array-based argument passing:
```bash
declare -a inc_arr exc_arr
for path in $ownership; do
    if [[ "$path" == !* ]]; then
        exc_arr+=(":!${path#!}")
    else
        inc_arr+=("$path")
    fi
done
git diff --name-only -- "${inc_arr[@]}" "${exc_arr[@]}" 2>/dev/null
```

**Assigned to:** 06-Backend

---

## MEDIUM-02 Detail (Still Open)

**File:** `scripts/auto-agent.sh:58-62`

```bash
local escaped_title=$(echo "$title" | sed 's/&/&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
"$ps_exe" -Command "...<text id=\"2\">$escaped_title</text>..."
```

XML escaping does not prevent PowerShell injection. A title containing `` `$(calc.exe)` `` or `"; Remove-Item -Recurse C:\; "` would execute.

**Required fix:** Use single-quoted PowerShell string or sanitize for PS metacharacters:
```bash
local safe_title=$(echo "$title" | sed "s/'/''''/g")
# Then use '$safe_title' (single-quoted) inside PowerShell -Command
```

**Assigned to:** 06-Backend

---

## New Module Scan: src/core/*.sh

Audited 7 modules (~700 LOC total):

| Module | Lines | Verdict | Notes |
|--------|-------|---------|-------|
| logger.sh | 227 | SECURE | All paths quoted, safe printf, no eval |
| error-handler.sh | 171 | SECURE | Safe stderr/stdout separation, no injection vectors |
| cycle-state.sh | 191 | SECURE | Regex-based parsing, no eval, quoted file I/O |
| agent-timeout.sh | 184 | SECURE | Safe command arrays, proper signal handling |
| dry-run.sh | 280 | SECURE | IFS+read parsing, no dynamic code execution |
| config-validator.sh | 251 | SECURE | Regex validation, associative array dedup, no eval |
| lock-file.sh | 92 | SECURE | PID validation, stale lock detection, grep-anchored parsing |

**Overall: EXCELLENT.** Zero vulnerabilities found. All modules follow consistent security patterns: quoted variables, no eval, safe file operations, no external dependencies.

### Minor Recommendations (Informational)

1. **lock-file.sh:** Add explicit numeric PID validation: `[[ "$existing_pid" =~ ^[0-9]+$ ]]`
2. **logger.sh:** Consider `umask 0077` before creating cycle logs if logs may contain sensitive data
3. All modules properly use double-source guards — good practice

---

## Secrets Scan

**Result: CLEAN** — No API keys, tokens, passwords, or credentials found in any committed file.

- MODEL-REGISTRY.md uses `****` placeholders (correct)
- No `.env` files exist in repo
- No certificate files (`.pem`, `.key`) present
- `.gitignore` now covers all sensitive patterns

---

## Summary for v0.1.0 Release

| Requirement | Status |
|-------------|--------|
| No eval on untrusted input | **FAIL** — HIGH-01 open |
| No secrets in repo | PASS |
| .gitignore covers sensitive patterns | PASS |
| Core modules secure | PASS |
| Lock file mechanism | PASS |
| Threat model documented | PASS (see threat-model-v0.1.md) |

**Release gate: FIX HIGH-01 before tagging v0.1.0.**
MEDIUM-02 (PowerShell notify) is lower risk (WSL-only, local-only) but should be fixed in next cycle.
