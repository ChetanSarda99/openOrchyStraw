# Security Audit — Cycle 6
**Date:** 2026-03-18
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** Re-verification of HIGH-03, HIGH-04, MEDIUM-01 regression; full secrets scan; new code review

---

## Verdict: NO CHANGE — v0.1.0 STILL BLOCKED

All three blockers from cycle 5 remain **unfixed**. No source code changes to `auto-agent.sh` since commit `0025b1d` (cosmetic `local` keyword fix on line 781 — security neutral).

---

## Finding Status

| ID | Finding | Severity | Status | Line(s) |
|----|---------|----------|--------|---------|
| HIGH-01 | `eval` injection in `commit_by_ownership()` | HIGH | **FIXED** (d130de7) | — |
| HIGH-02 | `--dangerously-skip-permissions` | HIGH | **ACCEPTED RISK** | 198, 488 |
| HIGH-03 | Unquoted `$ownership` in for loops | HIGH | **OPEN** | 236, 310, 320 |
| HIGH-04 | Sed injection via unescaped variables | HIGH | **OPEN** | 785–791 |
| MEDIUM-01 | `.gitignore` missing sensitive patterns | MEDIUM | **OPEN (regression)** | — |
| MEDIUM-02 | PowerShell notify injection | MEDIUM | **FIXED** (d130de7) | — |
| LOW-01 | No lock file mechanism | LOW | **FIXED** | — |
| LOW-02 | Missing `set -e` | LOW | **ACCEPTED** | — |

---

## HIGH-03: Unquoted Variable Expansion — STILL OPEN

**File:** `scripts/auto-agent.sh` — Lines 236, 310, 320

Verified by reading the current file. All three instances remain:

```bash
# Line 236 — commit_by_ownership()
for path in $ownership; do    # UNQUOTED

# Line 310 — detect_rogue_writes()
for path in $ownership; do    # UNQUOTED

# Line 320 — detect_rogue_writes()
for path in $all_owned; do    # UNQUOTED
```

**Risk unchanged:** Shell word-splitting + globbing on ownership values from `agents.conf`. A path like `src/*.sh` would glob-expand at parse time, breaking ownership boundary enforcement.

**Required fix:**
```bash
IFS=' ' read -ra ownership_arr <<< "$ownership"
for path in "${ownership_arr[@]}"; do
```

**Assigned to:** CS (protected file)

---

## HIGH-04: Sed Injection — STILL OPEN

**File:** `scripts/auto-agent.sh` — Lines 785–791

Verified. All sed commands still use `/` delimiter with unescaped variables:

```bash
sed -i "s/\*\*Date:\*\* .*/\*\*Date:\*\* $(date '+%B %d, %Y') — ${current_time}/" "$pf"
sed -i "s/[0-9]* TypeScript source + [0-9]* test files = [0-9]* total/${backend_src} TypeScript source + ${test_count} test files = ${ts_count} total/" "$pf"
sed -i "s/[0-9]* Swift files/${swift_count} Swift files/" "$pf"
sed -i "s/[0-9]* components/${component_count} components/" "$pf"
sed -i "s/Total:.*source files/Total: $total source files/" "$pf"
```

**Risk unchanged:** Any variable containing `/` or `&` corrupts sed commands. Current values (`date`, numeric counts) are low-risk, but the pattern is unsafe by construction.

**Required fix:** Use `|` delimiter + escape special chars:
```bash
safe_var=$(printf '%s\n' "$var" | sed 's/[|&]/\\&/g')
sed -i "s|pattern|$safe_var|" "$file"
```

**Assigned to:** CS (protected file)

---

## MEDIUM-01: .gitignore Regression — STILL OPEN

Current root `.gitignore` contents:
```
.DS_Store
Thumbs.db
logs/
*.log
prompts/00-backup/*.md
.orchystraw.lock
node_modules/
```

**Missing patterns (required before v0.1.0 tag):**
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

**Mitigating factor:** No secret files currently exist in the repo. Risk is preventive.

**Assigned to:** CS (protected file)

---

## New Observations — Cycle 6

### 1. BUG-009 (Dual agents.conf) — CONFIRMED RESOLVED
Root `agents.conf` and `scripts/agents.conf` are byte-identical. No divergence.

### 2. New Agent: 13-HR
Agent `13-hr` was added (commit `d130de7`). Ownership: `docs/team/ prompts/13-hr/`. Files created:
- `docs/team/TEAM_ROSTER.md`
- `docs/team/ONBOARDING.md`
- `docs/team/NORMS.md`

**Security review:** No sensitive content. Ownership is properly scoped. No issues.

### 3. Commit 0025b1d — Stray `local` Fix
Removed a stray `local` keyword in the prompt update loop (line 781). Security-neutral change — no impact on any finding.

### 4. Core Module Sourcing — STILL SECURE
Lines 30–34: hardcoded module list, existence-checked, directory-guarded. No change.

---

## Secrets Scan

**Result: CLEAN**

- Scanned all `.txt`, `.md`, `.sh`, `.conf` files for: key, token, secret, password, api_key
- All matches are documentation references, design token mentions, or placeholder text
- No `.env`, `.pem`, `.key`, `.p12`, `.pfx` files exist anywhere in the repo
- No credentials, API keys, or real secrets found

---

## Summary for v0.1.0 Release

| Requirement | Status |
|-------------|--------|
| No eval on untrusted input | **PASS** |
| No command injection in notify | **PASS** |
| Unquoted variable loops | **FAIL** — HIGH-03 open |
| Sed injection in prompt updates | **FAIL** — HIGH-04 open |
| No secrets in repo | **PASS** |
| .gitignore covers sensitive patterns | **FAIL** — MEDIUM-01 open |
| Core modules secure | **PASS** |
| Core module sourcing safe | **PASS** |
| Lock file mechanism | **PASS** |
| Dual agents.conf resolved | **PASS** |
| Threat model documented | **PASS** |
| New agents properly scoped | **PASS** |

---

## Release Gate

**v0.1.0: BLOCKED.** Same 3 issues as cycle 5. No progress on fixes.

All three blockers are in `scripts/auto-agent.sh` (protected file) or root `.gitignore` — only CS can apply these fixes. Agents cannot unblock themselves.

**Action required from CS:**
1. Fix HIGH-03: Use array-based iteration for `$ownership` loops (lines 236, 310, 320)
2. Fix HIGH-04: Use `|` delimiter + escaping in sed commands (lines 785–791)
3. Fix MEDIUM-01: Add sensitive patterns to root `.gitignore`
4. After fixes: Security will do final sign-off → tag v0.1.0
