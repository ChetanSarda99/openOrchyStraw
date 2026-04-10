# Security Audit — Cycle 11 (fresh cycle)
**Date:** 2026-04-10 02:05
**Auditor:** 10-security
**Verdict:** PASS (no new HIGH/MEDIUM findings)

---

## Scope
Fresh cycle after extended quiet period. Reviewed:
1. Uncommitted changes to `scripts/auto-agent.sh` (PROTECTED FILE — read-only review)
2. Backlog item: `src/core/single-agent.sh` (P0 carryover from prior cycles)
3. Secrets scan across repo
4. `.gitignore` coverage
5. Recent commit history for supply-chain drift

---

## Findings

### 1. `scripts/auto-agent.sh` — uncommitted change
**Diff:** 1 line added at L1345.
```
+                --smart-skip) ORCH_FORCE_AGENTS=0; export ORCH_FORCE_AGENTS; shift ;;
```
- CLI flag parser addition. Sets an integer literal `0`, exports, shifts positional args.
- No user input reaches a shell command. No injection surface.
- **Verdict:** SAFE.

### 2. `src/core/single-agent.sh` — full review (627 lines)
Module provides Ralph-compatible single-agent runner + v0.4 focus/checkpoint/progress features.

| Check | Result |
|-------|--------|
| `eval` on untrusted input | None present |
| Unquoted variable expansion in commands | None — all variables quoted |
| Command injection via agent ID / module name | None — inputs pass through `_orch_single_trim` then compared as strings or echoed to stdout only |
| Path traversal in checkpoint I/O (L463, L506) | PROJECT_ROOT is a trusted init arg; checkpoint path is constructed, not user-controlled at runtime |
| Checkpoint file restore (L513–530) | **SAFE** — parses line-by-line with explicit `case` whitelist of `ORCH_CKPT_*` keys. Does NOT `source` the file. Unknown keys silently ignored. Correct pattern. |
| `IFS='|' read -ra` parsing of agents.conf | Standard safe pattern, same as other modules |
| `mkdir -p` with quoted var (L464) | Safe |
| Module skip/keep lists (L58–59) | Hardcoded `readonly` strings. Cannot be mutated at runtime. |
| Ownership boundary enforcement | Module only READS config; orchestrator enforces ownership. Correct separation. |

**Findings:** 0 HIGH, 0 MEDIUM, 0 LOW, 1 INFO.

- **SA-INFO-01 (INFO):** Checkpoint restore (L512–530) correctly avoids `source`, but comments could note this explicitly for future maintainers — the pattern is intentional, not accidental. No action required.

**Verdict:** APPROVED. Remove from backlog.

### 3. Secrets scan
- Pattern scan for `sk-…`, `ghp_…`, `AKIA…`, `api_key="…"`, `password="…"`, `token="…"` across `*.{sh,ts,tsx,js,jsx,md,conf,py}`: **CLEAN**.
- `.env.example` present (2704 bytes). Real `.env` absent from repo. Good.

### 4. `.gitignore` coverage
Covers: `.env`, `.env.*` (with `!.env.example` exception), `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `token.json`, `secrets.json`, `service-account*.json`, `*secret*.json`, `.claude/channels/`. **PASS.**

### 5. Supply chain drift
Reviewed last 20 commits. All internal changes (app features, pixel events, cofounder templates, grep-oP macOS fixes, cycle fixes). No new third-party deps added to the core bash orchestrator. `site/` and `app/` are node projects (separate trust boundary, out of scope for this sweep).

---

## Backlog Status

| Item | Status |
|------|--------|
| single-agent.sh | **DONE — APPROVED** (this report) |
| SWE-bench scaffold (`scripts/benchmark/`) | Carry forward |
| qmd-refresher.sh | Carry forward |
| prompt-template.sh | Carry forward |
| task-decomposer.sh | Carry forward |
| init-project.sh | Carry forward |
| 5 efficiency scripts independent verification | Carry forward |
| WT-SEC-01 independent verification | Carry forward |
| Post-integration auto-agent.sh review | Carry forward |

Backlog went from 9 → 8 items.

---

## Release Gates
- Secrets: PASS
- .gitignore: PASS
- Supply chain: PASS
- Ownership: PASS (single-agent.sh confirmed non-privileged reader)
- New module review: PASS (single-agent.sh)
- HIGH/MEDIUM findings: 0

**Overall cycle verdict: PASS.**
