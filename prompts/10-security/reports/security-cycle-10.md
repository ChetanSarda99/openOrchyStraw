# Security Audit — Cycle 10

**Date:** 2026-03-29
**Auditor:** 10-Security (Opus 4.6)
**Scope:** 6 v0.2.0–v0.3.0 modules pending security review
**Verdict:** APPROVED — all 6 modules cleared. 1 LOW, 2 INFO findings.

---

## Modules Reviewed

| Module | Lines | Tests | CTO | QA | Security |
|--------|-------|-------|-----|----|----------|
| review-phase.sh | 311 | 36 | APPROVED | PASS | **APPROVED** |
| worktree.sh | 256 | 48 | APPROVED | PASS | **APPROVED** (1 LOW) |
| prompt-compression.sh | 411 | 30 | APPROVED | PASS | **APPROVED** |
| conditional-activation.sh | 271 | 25 | APPROVED | PASS | **APPROVED** |
| differential-context.sh | 465 | 42 | APPROVED | PASS | **APPROVED** (1 INFO) |
| session-tracker.sh | 382 | 33 | APPROVED | PASS | **APPROVED** |

---

## Findings

### WT-SEC-01 — Missing path traversal validation in orch_worktree_merge (LOW)

**Module:** worktree.sh
**Location:** `orch_worktree_merge()` (line 156)

`orch_worktree_create` validates agent_id (rejects `..` and `/` on line 113), but `orch_worktree_merge` does not independently validate. If called directly with a crafted agent_id containing `..`, the constructed worktree path could reference directories outside the intended tmpdir.

**Risk:** LOW — caller is the orchestrator (trusted), agent_id comes from agents.conf, and `create` must be called before `merge` in normal flow. Defense-in-depth gap only.

**Remediation:** Add the same validation block from `orch_worktree_create` lines 113-119 to `orch_worktree_merge`. Assign to 06-backend.

### PC-SEC-01 — Weak hash fallback (INFO)

**Module:** prompt-compression.sh
**Location:** `orch_prompt_stable_hash()` line 285

When neither `sha256sum` nor `shasum` is available, the fallback hash uses `len + first/last 8 chars`. This is trivially collisionable.

**Risk:** INFO — SHA-256 is the primary path and is available on all target platforms (Linux/macOS). The fallback only affects compression mode selection (full vs standard), not security controls.

**No action required.**

### DC-SEC-01 — Fail-open on unmapped sections (INFO)

**Module:** differential-context.sh
**Location:** `orch_diffctx_filter()` line 270-273

Unmapped section headers are included for all agents (fail-open). A crafted section header that normalizes to an unmapped key bypasses filtering.

**Risk:** INFO — intentional design choice documented on line 239. Shared context is inter-agent communication, not access-controlled data. Impact is token waste, not information leakage.

**No action required.**

---

## Security Checklist

### Secrets & Credentials
- [x] No API keys in any file
- [x] No tokens or passwords
- [x] No private paths (except .gitignore)
- [x] `.gitignore` covers all sensitive patterns (.env, *.pem, *.key, *.p12, *.pfx, credentials.json, service-account*.json, *secret*.json)

### Code Safety (all 6 modules)
- [x] No `eval` on any input
- [x] No unquoted variables in dangerous positions
- [x] No external calls (curl, wget, pip, npm, cargo)
- [x] No supply chain dependencies
- [x] printf with `%s` format specifiers throughout (no format string injection)
- [x] Input validation on numeric parameters (worktree cycle_num, tracker recent/summary)
- [x] Path traversal checks on agent IDs (review-phase RP-04, worktree create)
- [x] Verdict validation in review-phase (RP-01)
- [x] I/O error handling with mkdir/write checks (review-phase RP-03)

### Agent Isolation
- [x] Ownership boundaries defined in agents.conf
- [x] No agent prompt references files outside its ownership
- [x] Shared context is the only cross-agent channel
- [x] No module can modify the orchestrator script

### Module-Specific Checks

**review-phase.sh:**
- [x] Review record injection — findings use `printf '%s'`, no format injection
- [x] Cost guard bypass — `-ge` treats non-numeric as 0 (runs reviews). Acceptable: cost optimization, not security control. Caller provides trusted value.
- [x] RP-04 path traversal — both `orch_review_context` and `orch_review_record` reject `..`
- [x] RP-03 I/O error handling — mkdir and write have error checks

**worktree.sh:**
- [x] Path traversal in create — rejects `..` and `/` in agent_id
- [~] Path traversal in merge — NOT validated (WT-SEC-01 LOW)
- [x] Stale worktree recovery — `--force` removal is crash recovery, acceptable
- [x] Merge conflict handling — returns 1 without cleanup, caller resolves
- [x] Numeric validation on cycle_num

**prompt-compression.sh:**
- [x] SHA-256 primary hash — computationally infeasible to collide
- [~] Fallback hash is weak (PC-SEC-01 INFO)
- [x] Token estimation is approximation only, not a security control
- [x] File existence check before reading
- [x] State file parsing uses `|` split, no eval

**conditional-activation.sh:**
- [x] PM force flag — parameter from orchestrator, not self-settable by agents
- [x] Ownership matching — glob patterns from agents.conf (trusted)
- [x] Context mention scan — by design, agents communicating is intended
- [x] Fail-open on initialization failure — documented, reasonable for optimization module

**differential-context.sh:**
- [x] Header normalization — sed with fixed pattern, no injection possible
- [x] PM bypass — label derived from agent_id via string op, not forgeable by agents
- [~] Fail-open on unmapped sections (DC-SEC-01 INFO)
- [x] Cross-cycle history filtering — relevance-based, cross-references included by design
- [x] No eval, no external calls

**session-tracker.sh:**
- [x] Numeric validation on recent/summary parameters (regex `^[0-9]+$`, default on failure)
- [x] Cycle number extraction uses `[0-9]+` capture only
- [x] Preserved sections are aggregate data, no per-cycle sensitive leakage
- [x] Line-by-line parsing with `while IFS= read -r`, no injection vectors

---

## DR-SEC-02 Integration Reminder

CS must quote `orch_router_model` output when integrating dynamic-router.sh into auto-agent.sh. This was flagged in cycle 9 and remains pending.

---

## v0.2.0 Release Gate Status

| Gate | Status |
|------|--------|
| CTO review (all modules) | PASS |
| QA tests (278 tests) | PASS |
| Security review (all modules) | **PASS** (this audit) |
| CS integration | PENDING |

**All quality gates for v0.2.0 are now PASS.** Only CS integration remains before tagging.

---

## Open Findings Summary

| ID | Severity | Module | Status |
|----|----------|--------|--------|
| WT-SEC-01 | LOW | worktree.sh | OPEN — add path validation to merge |
| PC-SEC-01 | INFO | prompt-compression.sh | ACCEPTED — SHA-256 is primary path |
| DC-SEC-01 | INFO | differential-context.sh | ACCEPTED — intentional design |
| DR-SEC-01 | LOW | dynamic-router.sh | OPEN (cycle 9) |
| DR-SEC-02 | MEDIUM | dynamic-router.sh (integration) | PENDING CS — quote model output |

No HIGH or CRITICAL findings. **v0.2.0 CLEARED for release** pending CS integration.
