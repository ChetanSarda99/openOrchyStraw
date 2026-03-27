# Security Audit — Cycle 31
**Date:** 2026-03-20 08:15
**Auditor:** 10-Security (Claude Opus 4.6)
**Verdict:** CONDITIONAL PASS — 2 NEW CRITICAL findings in benchmark harness, 1 NEW CRITICAL in notify()

---

## Summary

Full audit performed across all surfaces. v0.1.0 core remains secure. Two new attack surfaces found:

1. **Benchmark harness** (`scripts/benchmark/run-swebench.sh`) — new since last audit, contains command injection vectors via untrusted JSON task files
2. **PowerShell toast notifications** — XML injection in `notify()` function via attacker-controlled branch/cycle names
3. All 31 src/core/ modules — still SECURE, no changes since cycle 30
4. Secrets scan — CLEAN
5. Agent ownership — PASS, no boundary violations
6. Supply chain — PASS, no new dependencies

---

## NEW Findings

### CRITICAL-01: PowerShell XML Injection via Toast Notifications
- **File:** `scripts/auto-agent.sh` lines 74-86
- **Issue:** `notify()` escapes XML entities for title but the escaping is incomplete. PowerShell backtick or `${...}` patterns in title could execute arbitrary PowerShell code. Attacker-controlled branch names (e.g., cycle names) flow into this path.
- **Risk:** Remote code execution on Windows/WSL systems
- **Remediation:** Use proper PowerShell string escaping or write to temp XML file with validation. Assign to **06-backend**.

### CRITICAL-02: Git Apply Command Injection via Untrusted Patch Content
- **File:** `scripts/benchmark/run-swebench.sh` line 191
- **Issue:** `_evaluate_task()` pipes untrusted JSON content directly to `git apply`: `echo "$test_patch" | git apply --allow-empty 2>/dev/null`. No validation of patch format.
- **Risk:** Arbitrary file modification during benchmark runs; patches could reference files outside workspace or trigger git hooks.
- **Remediation:** Validate patch format, reject patches referencing files outside workspace, use `git apply --check` first. Assign to **06-backend**.

### HIGH-01: Unvalidated TASK_REPO in git clone
- **File:** `scripts/benchmark/run-swebench.sh` line 104
- **Issue:** `git clone "https://github.com/$TASK_REPO.git"` does not validate `$TASK_REPO` from untrusted JSON. Malicious values could inject URL characters.
- **Risk:** URL injection, potential clone of malicious repos
- **Remediation:** Validate with strict regex: `^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$`. Assign to **06-backend**.

### HIGH-02: Echo -e Interpretation with Untrusted Filenames
- **File:** `scripts/auto-agent.sh` lines 323, 332, 365, 371, 375, 444
- **Issue:** Strings built with `\n` and piped through `echo -e`. If filenames contain backslashes (Windows paths or malicious names), interpretation could disclose information.
- **Risk:** Information disclosure, log parsing issues
- **Remediation:** Replace `echo -e` with `printf '%s\n'`. Assign to **06-backend**.

### HIGH-03: Race Condition in Parallel Git Operations
- **File:** `scripts/auto-agent.sh` lines 650-651, 718-731, 787-790
- **Issue:** Multiple agents run in parallel, then git operations follow. No lock protection on `git checkout main && git pull` sequence. Multiple orchestrator instances could interfere.
- **Risk:** Git repo corruption, lost commits
- **Remediation:** Use lock file mechanism for git operations. Assign to **06-backend**.

### HIGH-04: Temp File TOCTOU via Predictable Names
- **File:** `scripts/auto-agent.sh` lines 837-847
- **Issue:** Temp files use predictable `${pf}.tmp` pattern. If agent prompt paths in agents.conf are attacker-controlled, symlink attacks could overwrite sensitive files.
- **Risk:** Arbitrary file overwrite via symlink
- **Remediation:** Use `mktemp` with proper permissions, reject symlinks. Assign to **06-backend**.

### MEDIUM-01: Unvalidated JSON Input in Benchmark
- **File:** `scripts/benchmark/run-swebench.sh` lines 74-79
- **Issue:** Task data extracted from JSON without schema validation. No size limits or path traversal checks on TASK_REPO.
- **Risk:** Memory exhaustion, path traversal
- **Remediation:** Validate JSON schema, limit string lengths. Assign to **06-backend**.

---

## Carried Forward (Unchanged)

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| LOW-02 | LOW | OPEN (v0.1.1) | Unquoted `$all_owned` in detect_rogue_writes line 358 |
| QA-F001 | LOW | OPEN (v0.1.1) | Add `set -e` to auto-agent.sh line 23 |

---

## Checklist Results

### Secrets & Credentials — PASS
- [x] No API keys in any file
- [x] No tokens or passwords in source
- [x] `.gitignore` covers `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`
- [x] No `.env` files present in repo
- [x] No hardcoded URLs with credentials

### Agent Isolation — PASS
- [x] Ownership boundaries defined in `agents.conf` for all 12 agents
- [x] All agent prompts enforce file restrictions
- [x] Shared context is the only cross-agent communication channel
- [x] No agent can modify orchestrator script without explicit permission
- [x] Recent commits respect ownership boundaries
- [x] Owner directive rules enforced in PM prompt

### Script Safety — CONDITIONAL PASS
- [x] No `eval` on untrusted input (HIGH-01 from cycle 1 FIXED)
- [ ] Unquoted variables in shell scripts (echo -e pattern — HIGH-02 NEW)
- [x] Lock file module exists (`src/core/lock-file.sh`)
- [ ] Temp files use secure creation — FAIL (HIGH-04 NEW)
- [ ] Benchmark harness validated — FAIL (CRITICAL-02, HIGH-01 NEW)

### Supply Chain — PASS
- [x] No npm/pip/cargo dependencies in core orchestrator
- [x] pixel-agents: express + ws only (appropriate)
- [x] site: Next.js stack per approved LANDING-PAGE-STACK.md
- [x] No curl|bash patterns
- [x] GitHub workflow uses minimal permissions (contents:read, pages:write)

---

## Severity Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 2 | NEW — PowerShell injection, git patch injection |
| HIGH | 4 | NEW — URL injection, echo -e, race condition, TOCTOU |
| MEDIUM | 1 | NEW — unvalidated JSON in benchmark |
| LOW | 2 | CARRIED — v0.1.1 backlog |

---

## Recommendations

1. **Block benchmark from production use** until CRITICAL-02 and HIGH-01 are fixed
2. **Sanitize notify() inputs** — CRITICAL-01 affects every orchestrator run on WSL/Windows
3. **Prioritize echo -e → printf migration** — affects core orchestrator safety
4. **Add input validation module** for benchmark harness (regex on repo names, patch validation)

---

## Next Audit Focus
- Verify CRITICAL-01/02 fixes when shipped
- Pixel emitter integration audit when #16 ships
- Continue monitoring 31-module integration surface area
