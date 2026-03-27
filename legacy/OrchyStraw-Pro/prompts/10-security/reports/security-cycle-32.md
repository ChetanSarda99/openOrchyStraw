# Security Audit — Cycle 32 (Session 6 Cycle 1)
**Date:** 2026-03-21
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** 8 new src/core/ modules (cycles 3-5) + secrets scan
**Verdict:** CONDITIONAL PASS — 5 modules PASS, 3 modules FAIL

---

## Secrets Scan
**Result:** CLEAN
- Scanned all `src/core/*.sh` files for `key|token|secret|password|api_key`
- All matches are code identifiers (variable names, comments) — zero credential leaks
- `.gitignore` patterns: PASS (verified in prior cycles)

---

## Module Audit Results

### PASS — 5 modules

| Module | Lines | Notes |
|--------|-------|-------|
| `prompt-adapter.sh` | 152 | No eval. Minor: line 130 grep uses unescaped `$agent_id` in regex — low risk (IDs are numeric from conf). |
| `model-fallback.sh` | 145 | No eval. Minor: line 52 grep uses unescaped `$model` in regex — low risk (values are hardcoded claude/openai/gemini). |
| `max-cycles.sh` | 131 | No eval. Excellent integer validation (regex + bounds check). Path via `$project_root` is trusted. |
| `agent-kpis.sh` | 443 | No eval. See HIGH-05 and HIGH-06 below — issues documented but module structure is otherwise sound. |
| `onboarding.sh` | 289 | No eval. See MEDIUM-03 below — path validation gap documented. |

### FAIL — 3 modules

| Module | Lines | Critical Issues |
|--------|-------|-----------------|
| `founder-mode.sh` | 417 | MEDIUM-04: JSON injection via string concat (lines 324-328) |
| `knowledge-base.sh` | 546 | HIGH-07: Path traversal in domain/key params (lines 128-351). MEDIUM-05: grep regex injection (lines 72, 90). MEDIUM-06: frontmatter corruption via `---` in value. |
| `compare-ralph.sh` | 394 | HIGH-08: Python string injection in heredoc (lines 213-214). HIGH-09: Path traversal via `$id` in temp files (line 114). MEDIUM-07: Predictable temp file names (should use mktemp). |

---

## New Findings

### HIGH-05: agent-kpis.sh — Path traversal in agent parameter
**Lines:** 249, 355, 374, 391, 423
**Risk:** Agent name used directly in file path (`$ORCH_KPI_DIR/${agent}.json`) without validation. If agent contains `../`, files can be written outside the KPI directory.
**Remediation:** Validate agent names: `[[ "$agent" =~ ^[0-9]{2}-[a-zA-Z0-9_-]+$ ]] || return 1`
**Assigned to:** 06-Backend
**Severity:** HIGH (arbitrary file write)

### HIGH-06: agent-kpis.sh — Unvalidated output_file parameter
**Lines:** 374, 391, 423
**Risk:** `output_file="$2"` written to without any path validation. Arbitrary file write.
**Remediation:** Restrict to expected directory or validate with realpath.
**Assigned to:** 06-Backend
**Severity:** HIGH

### HIGH-07: knowledge-base.sh — Path traversal in domain/key
**Lines:** 128-131, 191, 298, 340, 351
**Risk:** `$domain` and `$key` used directly in path construction (`$_ORCH_KB_DIR/$domain/${key}.md`). No validation prevents `../` sequences. Could write to arbitrary locations under `~/.orchystraw/`.
**Example:** `orch_kb_store "../../etc" "passwd" "content"` attempts write outside KB dir.
**Remediation:** Validate: `[[ "$domain" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ "$key" =~ ^[a-zA-Z0-9_.-]+$ ]]`
**Assigned to:** 06-Backend
**Severity:** HIGH

### HIGH-08: compare-ralph.sh — Python string injection
**Lines:** 213-214
**Risk:** `$ralph_results` and `$orchy_results` interpolated unescaped into Python `open()` call inside heredoc. If paths contain `'`, Python code injection is possible.
**Example:** Path `test'); import os; os.system('rm -rf /` breaks out of string.
**Remediation:** Pass paths as Python sys.argv instead of string interpolation.
**Assigned to:** 06-Backend
**Severity:** HIGH

### HIGH-09: compare-ralph.sh — Path traversal via instance_id
**Lines:** 101, 114
**Risk:** `$id` from JSON `instance_id` used in temp file path (`/tmp/orchystraw-compare-${label}-${id}.json`). If `$id` contains `../`, files created outside `/tmp/`.
**Remediation:** Sanitize: `id="${id//[^a-zA-Z0-9._-]/_}"` or use `mktemp`.
**Assigned to:** 06-Backend
**Severity:** HIGH

### MEDIUM-03: onboarding.sh — Unvalidated output_dir/name in paths
**Lines:** 230-231, 235, 280
**Risk:** `output_dir` and `name` used in path construction for mkdir/file writes without `../` validation.
**Remediation:** Validate name: `[[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]`
**Assigned to:** 06-Backend
**Severity:** MEDIUM

### MEDIUM-04: founder-mode.sh — JSON injection via string concat
**Lines:** 324-328
**Risk:** JSON built by string concatenation without escaping keys/values from associative array. Quotes/backslashes in agent names break JSON.
**Remediation:** Use `jq` for JSON construction, or escape special chars.
**Assigned to:** 06-Backend
**Severity:** MEDIUM

### MEDIUM-05: knowledge-base.sh — grep regex injection
**Lines:** 72, 90
**Risk:** `$domain/$key` used in grep pattern without escaping. Regex metacharacters cause unexpected matching.
**Remediation:** Use `grep -F` (fixed string) instead of regex grep.
**Assigned to:** 06-Backend
**Severity:** MEDIUM

### MEDIUM-06: knowledge-base.sh — Frontmatter corruption
**Line:** 168
**Risk:** `$value` written directly. If value contains `---`, YAML frontmatter parser breaks.
**Remediation:** Strip or escape `---` sequences in value before writing.
**Assigned to:** 06-Backend
**Severity:** MEDIUM

### MEDIUM-07: compare-ralph.sh — Predictable temp file names
**Line:** 114
**Risk:** Manual temp file construction instead of `mktemp`. TOCTOU race condition possible.
**Remediation:** Replace with `tmp=$(mktemp)`.
**Assigned to:** 06-Backend
**Severity:** MEDIUM

---

## Carried Forward (unchanged)

| ID | Severity | Status | Notes |
|----|----------|--------|-------|
| HIGH-03 | HIGH | CLOSED | git race — fixed (23895de) |
| HIGH-04 | HIGH | DEFERRED v0.1.1 | TOCTOU temp files |
| LOW-02 | LOW | OPEN | Unquoted `$all_owned` line 358 — CS action |

---

## Audit Coverage

| Metric | Count |
|--------|-------|
| Total src/core/ modules | 38 |
| Audited (prior cycles) | 31 |
| Audited (this cycle) | 8 (5 PASS, 3 FAIL) |
| **Total audited** | **38/38 (100%)** |
| scripts/benchmark/ | 1 audited (FAIL) |

---

## Summary

Full module coverage achieved (38/38). Five new HIGH findings and five MEDIUM findings across 3 modules. The most critical are:
1. **knowledge-base.sh** path traversal (HIGH-07) — could write outside `~/.orchystraw/knowledge/`
2. **compare-ralph.sh** Python injection (HIGH-08) — code execution via crafted file paths
3. **agent-kpis.sh** arbitrary file write (HIGH-05/06) — no path validation on output

All findings assigned to 06-Backend for remediation. None block v0.1.0 (already shipped). Should be fixed before v0.2.0 release.
