# Security Audit — Cycle 9
**Date:** 2026-03-29
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** v0.2.0 module security review — dynamic-router.sh, review-phase.sh (preliminary), config-validator.sh v2+

---

## Verdict: CONDITIONAL PASS

v0.1.0 remains secure. v0.2.0 modules have **2 MEDIUM** findings for CS to address before integration. review-phase.sh deferred per CTO HOLD (BUG-017 + RP-01/02/03/04).

---

## v0.2.0 Module Review: dynamic-router.sh — APPROVED WITH FINDINGS

**File:** `src/core/dynamic-router.sh` (516 lines, 39 tests passing)
**CTO Status:** APPROVED (cycle 4)

### DR-SEC-01: State File Trust (LOW)

**Location:** `orch_router_load_state()` lines 420–433

The state file (`.orchystraw/router-state.json`) is loaded with `IFS='|' read -r` parsing. Values are used in:
- Arithmetic comparisons (`-eq`, `-ge`) — non-numeric values cause bash errors, not code execution
- String comparisons (`last_outcome`) — no injection vector
- Gate at line 427: only restores state for agents already in agents.conf

**Risk:** An attacker with filesystem write access could manipulate scheduling (e.g., set `eff_interval=0` to force-run agents). But filesystem access already implies full compromise.

**Verdict:** LOW — acceptable for v0.2.0. No action required.

### DR-SEC-02: Model Override Pass-Through (MEDIUM)

**Location:** `orch_router_model()` lines 443–474

Model resolution chain: env var `ORCH_MODEL_OVERRIDE_<ID>` > `ORCH_MODEL_CLI_OVERRIDE` > agents.conf col 9 > default.

Line 472: **Unknown model names are passed through as-is** with only a WARN log:
```bash
printf '%s\n' "$model"  # unknown model — passed through
```

This value would be used as a `--model` flag argument to Claude CLI. If the env var contains spaces or shell metacharacters, and the caller doesn't quote the output, it could inject CLI flags.

**Current risk:** LOW — auto-agent.sh doesn't use `orch_router_model` yet (CTO noted columns 6–9 integration pending). But when CS integrates this, the return value **must be quoted**.

**Recommendation for CS integration:**
```bash
# SAFE:
local model_flag
model_flag="$(orch_router_model "$id")"
claude --model "$model_flag" ...

# UNSAFE:
claude --model $(orch_router_model "$id") ...
```

**Also:** Consider validating model values at parse time (reject unknowns) rather than passing through. Forward-compat is lower priority than injection safety.

**Verdict:** MEDIUM — document for CS. No code change needed in dynamic-router.sh itself.

### DR-SEC-03: depends_on Parsing — SECURE

Lines 151–167: `IFS=',' read -ra dep_list` with array-based iteration. BUG-014 fix properly deduplicates. BUG-016 warns on unknown deps. Values are only used as associative array keys — no execution paths.

### DR-SEC-04: PM Force Override — SECURE

Simple flag (`=1` / `=0`), checked via exact string match. Can only make agents eligible, not bypass other checks.

### DR-SEC-05: Interval Manipulation via State — LOW

Same as DR-SEC-01. Tampered `eff_interval` values affect scheduling only. Requires filesystem access.

---

## v0.2.0 Module Review: review-phase.sh — DEFERRED (CTO HOLD)

**File:** `src/core/review-phase.sh` (279 lines)
**CTO Status:** HOLD — BUG-017 + RP-01/02/03/04 must be fixed first

### Preliminary Observations (not a full review)

1. **printf `--` usage (BUG-017 area):** `orch_review_summary()` lines 225–229 use `printf -- '...'` — correct bash 5.x syntax for option termination. However, CTO flagged this as still broken. Deferring to CTO's assessment.

2. **RP-SEC-01: Path Traversal in Review Directory (MEDIUM)**
   - Line 187: `review_dir="${_ORCH_REVIEW_OUTPUT_DIR}/${reviewer}/reviews"`
   - If `reviewer` ID contains `../`, writes escape the intended directory
   - Agent IDs from agents.conf are not validated for path traversal chars
   - This aligns with CTO's RP-04 finding
   - **Recommendation:** Validate agent IDs against `^[a-zA-Z0-9_-]+$` in `orch_review_init` or `orch_review_record`

3. **Review record injection:** SECURE — findings are passed as `%s` argument to printf, not interpolated into format string.

4. **Cost guard bypass:** LOW — `orch_review_should_run` uses integer comparison. Non-numeric input causes bash error, not silent bypass. Guard is advisory anyway.

**Full security review will be conducted after backend fixes BUG-017 + RP-01.**

---

## v0.2.0 Module Review: config-validator.sh v2+ — SECURE

**File:** `src/core/config-validator.sh` (290 lines)
**CTO Status:** APPROVED (cycle 4)

- Consistent use of `_orch_cv_trim()` for all parsed values
- Pipe count via `tr -cd '|' | wc -c` — standard, no injection
- Model validation is warn-only per MODEL-001 ADR — intentional
- No eval, no exec, no code execution from parsed config values
- Backward-compatible v1/v2/v2+ parsing branches all validate safely
- **Verdict:** SECURE — no findings.

---

## Recurring Checks

### Secrets Scan: CLEAN

All `.sh`, `.md`, `.txt`, `.conf` files scanned. No API keys, tokens, passwords, or credentials. Only documentation references in `strategy-vault/archive/` (examples, not real values).

### Ownership Enforcement: PASS

- agents.conf boundaries correct (9 agents)
- Protected files list intact in auto-agent.sh (lines 275–282)
- New agent 13-hr added at interval 3, owns `docs/team/ prompts/13-hr/` — no security concern

### .gitignore: PASS

All sensitive patterns present: `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `service-account*.json`, `*secret*.json`.

### Supply Chain: PASS

- Core: zero external dependencies (pure bash)
- No new curl|bash patterns
- Site dependencies unchanged
- check-domain.sh curl usage: utility only, not supply chain

---

## Finding Summary

| ID | Finding | Severity | Module | Status |
|----|---------|----------|--------|--------|
| DR-SEC-01 | State file trust | LOW | dynamic-router.sh | Accepted |
| DR-SEC-02 | Model override pass-through | MEDIUM | dynamic-router.sh | Open — document for CS integration |
| DR-SEC-03 | depends_on parsing | N/A | dynamic-router.sh | SECURE |
| DR-SEC-04 | PM force override | N/A | dynamic-router.sh | SECURE |
| DR-SEC-05 | Interval manipulation | LOW | dynamic-router.sh | Accepted |
| RP-SEC-01 | Path traversal in review dir | MEDIUM | review-phase.sh | Open — aligns with CTO RP-04 |
| — | config-validator.sh v2+ | N/A | config-validator.sh | SECURE |

### Open Findings from Previous Cycles (unchanged)

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| HIGH-02 | `--dangerously-skip-permissions` | HIGH | Accepted risk (Claude Code operational) |
| LOW-02 | Missing `set -e` | LOW | Deferred to v0.1.1 |
| BUG-009 | Dual agents.conf | LOW | Cleanup in v0.1.1 |

---

## Recommendations

1. **DR-SEC-02:** When CS integrates `orch_router_model` into auto-agent.sh, always quote the output. Consider rejecting unknown model names instead of pass-through.
2. **RP-SEC-01:** Add agent ID format validation (`^[a-zA-Z0-9_-]+$`) in review-phase.sh to prevent path traversal. Backend should include this in BUG-017 fix batch.
3. **review-phase.sh:** Full security review blocked on backend fixing BUG-017 + RP-01. Will audit in next eligible cycle.
