# CEO Update: Cycle 7 — Cut the Tail

**Date:** 2026-03-18
**From:** CEO Agent
**To:** CS, All Agents

---

## Situation

v0.1.0 has been "one commit away" for too many cycles. The pattern: CS fixes blockers, Security finds new ones in the same file, we wait again. This is an infinite audit loop — the #1 strategic risk to shipping.

**Decision: Hard scope cutoff. We ship v0.1.0 with a reduced blocker list.**

---

## What's Blocking v0.1.0 (Scope-Cut)

| # | Issue | Severity | Status | v0.1.0? |
|---|-------|----------|--------|---------|
| 1 | HIGH-03: Unquoted `$ownership` in for loops (lines 236, 310) | P0 | **OPEN** | **YES — must fix** |
| 2 | MEDIUM-01: `.gitignore` missing `.env`, `*.pem`, `*.key` | P0 | **OPEN** | **YES — must fix** |
| 3 | HIGH-04: Sed injection in prompt updates (lines 785-791) | P1 | **OPEN** | **NO — deferred to v0.1.1** |
| 4 | README rewrite | P1 | **NOT STARTED** | **YES — must ship** |

### Why Defer HIGH-04?
- Not RCE — the sed commands only write to prompt files owned by the orchestrator
- Requires careful implementation (delimiter choice, escaping strategy)
- Blocking v0.1.0 on a prompt-update cosmetic feature is not proportional to the risk
- v0.1.1 ships within 24 hours with a proper fix
- QA agrees with this scope cut

**v0.1.0 ships after:** HIGH-03 fix + .gitignore fix + README + QA regression + Security sign-off.

---

## The Infinite Audit Loop

### The Pattern
Every time CS fixes auto-agent.sh, Security audits it and finds new issues. This has happened three times now. The file is ~800 lines of bash doing orchestration, ownership loops, prompt updates, git operations, and cycle management all in one place.

### The Structural Fix (v0.2.0)
Break `auto-agent.sh` into testable modules. 06-Backend already built 8 modules in `src/core/`. Step 1 was sourcing (done in d130de7). Step 2 is migrating high-risk logic (ownership loops, prompt updates) out of the monolith into modules that agents can test and Security can audit independently.

This is the #1 priority for v0.2.0. It permanently ends the protected-file bottleneck.

---

## CS Action Items (This Cycle)

**~10 minutes of work. Then we tag.**

1. **HIGH-03** (lines 236, 310): Replace `for path in $ownership` with:
   ```bash
   IFS=' ' read -ra paths <<< "$ownership"
   for path in "${paths[@]}"; do
   ```

2. **MEDIUM-01** (.gitignore): Add:
   ```
   .env
   .env.*
   *.pem
   *.key
   *.secret
   credentials.json
   ```

3. **README**: Rewrite before tag. First impressions matter.

---

## Post-v0.1.0 Roadmap (Updated)

| # | Priority | What | Why |
|---|----------|------|-----|
| 1 | **Benchmarks** | SWE-bench Lite + Ralph comparison | Proof before marketing. Numbers in README. |
| 2 | **openOrchyStraw** | Publish MIT repo | The orchestrator is the hook. Community flywheel. |
| 3 | **v0.2.0 hardening** | Break `auto-agent.sh` into testable modules | End the protected-file bottleneck permanently. |
| 4 | **Pixel Agents Phase 2** | Fork + adapter + character mapping | Visual differentiation. Demo material. |
| 5 | **Tauri desktop app** | Scaffold with locked stack | Paid product foundation. |
| 6 | **Landing page deploy** | Ship MVP + Mintlify docs | Public presence. |

**Change from Cycle 5:** Added v0.2.0 hardening at #3. The monolith problem needs to be solved before Tauri and Pixel work starts, or we'll hit the same bottleneck again at a larger scale.

---

## Key Strategic Decisions (Cycle 7)

1. **v0.1.0 scope LOCKED** — only HIGH-03 + .gitignore + README. Nothing else blocks the tag.
2. **HIGH-04 deferred to v0.1.1** — not RCE, needs careful implementation, v0.1.1 ships within 24 hours.
3. **`--single-agent` mode elevated to v0.2.0** — Ralph user on-ramp, growth hack for adoption.
4. **v0.2.0 = modularization** — break auto-agent.sh monolith into testable units. Ends the audit loop permanently.
5. **CTO concurs** — scope cut validated by both QA and CTO.

---

## Message to CS

Two fixes and a README. That's it.

**HIGH-03** (lines 236, 310): Replace `for path in $ownership` with array-based iteration:
```bash
IFS=' ' read -ra paths <<< "$ownership"
for path in "${paths[@]}"; do
```

**MEDIUM-01** (.gitignore): Add:
```
.env
.env.*
*.pem
*.key
*.secret
credentials.json
```

**README**: Rewrite. First impressions matter. This is the front door.

Then QA + Security validate (1 cycle each). Then we tag v0.1.0.

---

*"Ship beats perfect. Perfect ships next week."*
