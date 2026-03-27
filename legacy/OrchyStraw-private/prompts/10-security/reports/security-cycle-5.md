# Security Audit — Cycle 5
**Date:** 2026-03-18
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** Remediation verification (HIGH-01, MEDIUM-02), full re-scan, .gitignore audit

---

## Verdict: CONDITIONAL PASS — 2 NEW HIGHs, 1 REGRESSION

HIGH-01 (eval injection) and MEDIUM-02 (notify injection) are **FIXED**.
Two new HIGH-severity issues found. .gitignore MEDIUM-01 has **regressed**.

---

## Remediation Status (from Cycle 1 + 2)

| ID | Finding | Status | Notes |
|----|---------|--------|-------|
| HIGH-01 | `eval` injection in `commit_by_ownership()` | **FIXED** | Replaced with array-based pathspec (lines 232-246). No `eval` calls remain. |
| HIGH-02 | `--dangerously-skip-permissions` | **ACCEPTED RISK** | No change. |
| MEDIUM-01 | `.gitignore` missing sensitive patterns | **REGRESSED** | Cycle 2 reported FIXED, but `.env`, `*.pem`, `*.key` etc. are NOT in current `.gitignore` |
| MEDIUM-02 | PowerShell notify injection | **FIXED** | Title passed via `$env:ORCH_TOAST_TITLE` (lines 64-78), HTML-escaped, single-quoted PS block |
| LOW-01 | No lock file mechanism | **FIXED** | `src/core/lock-file.sh` — no change |
| LOW-02 | Missing `set -e` | **ACCEPTED** | `set -uo pipefail` present (line 23) |

---

## NEW FINDINGS

### HIGH-03: Unquoted Variable Expansion in For Loops

**File:** `scripts/auto-agent.sh` — Lines 236, 310, 320
**Severity:** HIGH
**CVSS estimate:** 7.0 (local, requires agents.conf control)

```bash
# Line 236 — commit_by_ownership()
for path in $ownership; do  # VULNERABLE: unquoted

# Line 310 — detect_rogue_writes()
for path in $ownership; do  # VULNERABLE: unquoted

# Line 320 — detect_rogue_writes()
for path in $all_owned; do  # VULNERABLE: unquoted
```

**Risk:** `$ownership` comes from `agents.conf`. Without quoting, shell performs word-splitting AND pathname expansion (globbing). A path pattern like `src/*.sh` in agents.conf would expand to actual filenames at parse time, breaking ownership logic silently.

**Impact:** Incorrect file ownership resolution — agent commits could include or exclude wrong files. Not RCE, but a correctness/integrity issue that could lead to agents writing outside boundaries.

**Fix:** Use arrays parsed from IFS-split at read time:
```bash
IFS=' ' read -ra ownership_arr <<< "$ownership"
for path in "${ownership_arr[@]}"; do
```

**Assigned to:** 06-Backend

---

### HIGH-04: Sed Injection via Unescaped Variables

**File:** `scripts/auto-agent.sh` — Lines 785-791
**Severity:** HIGH
**CVSS estimate:** 6.5 (local, requires variable control)

```bash
# Line 785
sed -i "s/\*\*Date:\*\* .*/\*\*Date:\*\* $(date '+%B %d, %Y') — ${current_time}/" "$pf"

# Lines 788-791
sed -i "s/[0-9]* TypeScript source.../${backend_src} TypeScript source..." "$pf"
sed -i "s/Total:.*source files/Total: $total source files/" "$pf"
```

**Risk:** The `/` delimiter in sed means any variable containing `/` breaks the command. The `&` character in sed replacement means "insert matched text." If `current_time` or counts are manipulated (e.g., via corrupted state files), sed commands malfunction or corrupt prompt files.

**Impact:** Prompt file corruption. Not RCE, but could inject misleading content into agent prompts.

**Fix:** Use a safe delimiter and escape special sed characters:
```bash
safe_var=$(printf '%s\n' "$var" | sed 's/[\/&]/\\&/g')
sed -i "s|pattern|$safe_var|" "$file"
```

**Assigned to:** 06-Backend

---

### MEDIUM-01 REGRESSION: .gitignore Missing Sensitive Patterns

**File:** `.gitignore`

Cycle 2 report documented MEDIUM-01 as **FIXED** with `.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json` all present. However, the current `.gitignore` contains **none of these patterns**:

```
# Current .gitignore — INCOMPLETE
.DS_Store
Thumbs.db
logs/
*.log
prompts/00-backup/*.md
.orchystraw.lock
node_modules/
```

**Note:** `site/.gitignore` does cover `*.pem` and `.env*` for the Next.js project, but the root `.gitignore` does not.

**Risk:** Accidental commit of secrets if `.env` or credential files are created at repo root.

**Mitigating factor:** No `.env`, `.pem`, `.key`, or credential files currently exist in the repo.

**Fix required:** Add to root `.gitignore`:
```
# Secrets
.env
.env.*
*.pem
*.key
*.p12
*.pfx
credentials.json
service-account*.json
*secret*.json
.orchystraw/
```

**Assigned to:** CS (protected file)

---

## Verification: Core Module Sourcing

**Lines 30-34 of auto-agent.sh:**
```bash
if [ -d "$PROJECT_ROOT/src/core" ]; then
    for mod in bash-version logger error-handler cycle-state agent-timeout dry-run config-validator lock-file; do
        [ -f "$PROJECT_ROOT/src/core/${mod}.sh" ] && source "$PROJECT_ROOT/src/core/${mod}.sh"
    done
fi
```

**Status: SECURE.** Module list is hardcoded (not derived from directory listing), each file is existence-checked before sourcing, and the directory guard prevents errors on fresh clones.

---

## Verification: BUG-009 (Dual agents.conf)

Both `agents.conf` (root) and `scripts/agents.conf` are **identical** — 8 agents, same format. Reconciled in commit `d130de7`.

**Status: RESOLVED.**

---

## Secrets Scan

**Result: CLEAN** — No API keys, tokens, passwords, or credentials in any committed file.

- MODEL-REGISTRY.md uses `****` placeholders (correct)
- No `.env` files exist in repo
- No certificate files present
- TOKEN-EFFICIENCY.md references detection examples only (no real values)

---

## Integration Test Security Review

**File:** `tests/core/test-integration.sh` (190 lines)

- Uses `set -euo pipefail` — good
- Creates temp dir via `mktemp -d` with trap cleanup — good
- Sources all 8 modules, validates guard variables, 42 assertions — good
- No side effects on main codebase — good

**Status: SAFE.** No security implications.

---

## Summary for v0.1.0 Release

| Requirement | Status |
|-------------|--------|
| No eval on untrusted input | **PASS** — HIGH-01 fixed |
| No command injection in notify | **PASS** — MEDIUM-02 fixed |
| Unquoted variable loops | **FAIL** — HIGH-03 open |
| Sed injection in prompt updates | **FAIL** — HIGH-04 open |
| No secrets in repo | PASS |
| .gitignore covers sensitive patterns | **FAIL** — MEDIUM-01 regressed |
| Core modules secure | PASS |
| Core module sourcing safe | PASS |
| Lock file mechanism | PASS |
| BUG-009 dual agents.conf | PASS — resolved |
| Threat model documented | PASS |

---

## Release Gate

**v0.1.0 release: BLOCKED on HIGH-03 and HIGH-04.**

HIGH-03 (unquoted loops) and HIGH-04 (sed injection) are lower risk than the original HIGH-01 eval injection — neither enables direct RCE. However, they represent integrity risks in the ownership enforcement system, which is a core security boundary.

**Recommended path:**
1. Fix HIGH-03 + HIGH-04 in auto-agent.sh (CS or 06-Backend)
2. Fix MEDIUM-01 regression in .gitignore (CS)
3. QA regression pass
4. Security final sign-off → tag v0.1.0
