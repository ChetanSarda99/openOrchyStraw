# Threat Model — OrchyStraw v0.1.0
**Date:** 2026-03-18
**Author:** 10-Security (Claude Opus 4.6)
**Status:** Living document — update each cycle

---

## 1. System Overview

OrchyStraw is a multi-agent AI coding orchestrator. Multiple AI agents (Claude instances) run concurrently on a shared codebase, each with assigned file ownership. An orchestrator bash script spawns, monitors, and commits for agents.

### Architecture
```
┌────────────────────────────────────┐
│  auto-agent.sh (orchestrator)      │
│  - Full shell access               │
│  - Spawns claude CLI per agent     │
│  - Manages git branches/commits    │
├────────────────────────────────────┤
│  Agent 1..N (claude CLI)           │
│  - --dangerously-skip-permissions  │
│  - Prompt-enforced boundaries      │
│  - Reads/writes files              │
│  - Executes shell commands         │
├────────────────────────────────────┤
│  Shared Context (markdown files)   │
│  - Cross-agent communication       │
│  - Writable by all agents          │
├────────────────────────────────────┤
│  Git Repository                    │
│  - Branch-per-agent isolation      │
│  - Orchestrator merges             │
└────────────────────────────────────┘
```

---

## 2. Trust Boundaries

| Boundary | Trust Level | Notes |
|----------|-------------|-------|
| Orchestrator script | FULL | Runs as user, full shell access |
| Agent processes | SEMI-TRUSTED | Follow prompts but can hallucinate; have full shell via --dangerously-skip-permissions |
| agents.conf | TRUSTED | Defines agent config; must be protected from agent modification |
| Shared context files | UNTRUSTED | Any agent can write; could contain prompt injection |
| Git repository | TRUSTED | Orchestrator-managed; agents cannot push/merge |
| External APIs | UNTRUSTED | Claude API responses are unpredictable |

---

## 3. Attack Surface

### 3.1 Command Injection (HIGH)
**Vector:** Crafted values in `agents.conf` ownership paths → `eval` in `commit_by_ownership()`
**Impact:** Arbitrary command execution as the user running the orchestrator
**Likelihood:** LOW (requires editing agents.conf, which is a protected file)
**Risk:** HIGH (RCE if exploited)
**Status:** OPEN — HIGH-01 in security-cycle-1.md
**Mitigation:** Replace eval with arrays (assigned to 06-Backend)

### 3.2 Agent Boundary Escape (HIGH — Accepted Risk)
**Vector:** Agents run with `--dangerously-skip-permissions`, can read/write any file
**Impact:** Agent reads credentials from `~/.claude/settings.json`, modifies other agents' prompts, exfiltrates data
**Likelihood:** MEDIUM (agents hallucinate; a confused agent could write outside boundaries)
**Risk:** HIGH
**Status:** ACCEPTED RISK — required for autonomous operation
**Mitigations:**
- Protected files list prevents modification of critical infrastructure
- `detect_rogue_writes()` catches out-of-boundary modifications post-hoc
- Branch isolation limits blast radius of rogue writes
- Future: `--allowedTools` when Claude Code supports per-agent tool restrictions

### 3.3 Prompt Injection via Shared Context (MEDIUM)
**Vector:** Agent A writes malicious instructions to `context.md`; Agent B reads and follows them
**Impact:** Agent B could be directed to write malicious code, exfiltrate secrets, or sabotage the build
**Likelihood:** LOW (requires agent A to be compromised or hallucinating maliciously)
**Risk:** MEDIUM
**Mitigations:**
- Each agent's prompt includes explicit instructions that override shared context
- Shared context is reset each cycle (limits persistence of injected content)
- QA agent reviews cross-agent outputs

### 3.4 PowerShell Injection via Notifications (MEDIUM)
**Vector:** Unescaped variables interpolated into PowerShell `-Command` string
**Impact:** Arbitrary PowerShell execution on Windows host (WSL environment)
**Likelihood:** LOW (requires crafted agent output in notification title)
**Risk:** MEDIUM (local-only, WSL-specific)
**Status:** OPEN — MEDIUM-02

### 3.5 Secret Leakage (LOW)
**Vector:** Accidental commit of `.env`, credentials, or API keys
**Impact:** Credential exposure if repo is public
**Likelihood:** LOW (`.gitignore` now covers sensitive patterns)
**Risk:** LOW
**Status:** MITIGATED — `.gitignore` hardened in Cycle 1

### 3.6 Race Conditions (LOW)
**Vector:** Two orchestrator instances running simultaneously; concurrent git operations
**Impact:** Git conflicts, corrupted commits, lost work
**Likelihood:** LOW (single-user tool)
**Risk:** LOW
**Status:** MITIGATED — `src/core/lock-file.sh` implements PID-tracked locking

### 3.7 Supply Chain (MINIMAL)
**Vector:** Compromised dependencies
**Impact:** Code execution via malicious package
**Likelihood:** VERY LOW (core orchestrator has zero external dependencies)
**Risk:** MINIMAL
**Mitigations:**
- Core is bash + markdown only
- Site/ has Node deps but is separate from orchestrator
- No curl|bash patterns

---

## 4. Data Flow Security

### Sensitive Data Inventory
| Data | Location | Protection |
|------|----------|------------|
| Claude API key | `~/.claude/settings.json` | OS file permissions; agents could read via shell |
| Git credentials | OS credential store | Not exposed to agents directly |
| Agent prompts | `prompts/` directory | Protected files list prevents modification by agents |
| Cycle logs | `logs/` directory | `.gitignore`d; may contain agent output |
| Lock/state files | `.orchystraw/` | `.gitignore`d |

### Data Flow Diagram
```
User → auto-agent.sh → claude CLI (per agent) → file system
                     → git operations
                     → shared context (read/write by all agents)
                     → notifications (WSL → Windows)
```

---

## 5. Security Controls Summary

| Control | Status | Effectiveness |
|---------|--------|---------------|
| Protected files list | Active | HIGH — prevents agent modification of infra |
| Rogue write detection | Active | MEDIUM — post-hoc only, cannot prevent |
| Branch isolation | Active | HIGH — limits blast radius |
| Lock file mechanism | Active | HIGH — prevents concurrent execution |
| .gitignore hardening | Active | HIGH — prevents secret commits |
| Backup/validate cycle | Active | HIGH — protects against prompt corruption |
| Usage throttling | Active | MEDIUM — prevents runaway API costs |
| eval removal | PENDING | N/A — HIGH-01 not yet fixed |

---

## 6. Recommendations for v0.1.0

### Must Fix (Release Blockers)
1. **Remove `eval`** from `commit_by_ownership()` — replace with array-based args

### Should Fix (Next Cycle)
2. **Sanitize PowerShell notifications** — escape PS metacharacters
3. **Add input validation** to `agents.conf` parser — reject paths with `$`, backticks, semicolons

### Track (Backlog)
4. **Per-agent tool restrictions** — when `--allowedTools` becomes available
5. **Shared context integrity checks** — detect prompt injection patterns
6. **Audit logging** — record which agent modified which files (beyond git blame)
