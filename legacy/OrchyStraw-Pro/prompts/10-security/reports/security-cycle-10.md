# Security Audit — Cycle 10
**Date:** 2026-03-20
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** Deep audit — 6 unaudited v0.2.0 modules, #78 QA-F003 review, integration review, secrets scan

---

## Verdict: **CONDITIONAL PASS — v0.2.0 modules SECURE, 2 items remain open**

Six previously unaudited modules now reviewed and cleared. No new vulnerabilities found. #78 QA-F003 (single-agent.sh `$cli`) confirmed NOT a shell injection — variable is properly quoted. Two v0.1.1 items (LOW-02, QA-F001) remain open.

---

## Issue Tracker

| # | Finding | Severity | Status | Notes |
|---|---------|----------|--------|-------|
| HIGH-01 | eval injection in commit_by_ownership() | HIGH | **CLOSED** | Array-based pathspec (23895de) |
| HIGH-03 | Unquoted $ownership in for loops | HIGH | **CLOSED** | while-read + arrays (23895de) |
| HIGH-04 | sed injection in prompt updater | HIGH | **DEFERRED v0.1.1** | awk -v replacements, safe |
| MEDIUM-01 | .gitignore missing secrets patterns | MEDIUM | **CLOSED** | 6 patterns present |
| MEDIUM-02 | notify() shell injection | MEDIUM | **CLOSED** | env var passing (d130de7) |
| LOW-01 | Lock file race condition | LOW | **CLOSED** | src/core/lock-file.sh |
| LOW-02 | Unquoted $all_owned in detect_rogue_writes | LOW | **OPEN — v0.1.1** | Line 358: word splitting risk |
| QA-F001 | Missing `set -e` in auto-agent.sh | LOW | **OPEN — v0.1.1** | Line 23: `set -uo pipefail` (no -e) |

No new findings this cycle.

---

## #78 QA-F003 Review: single-agent.sh

**Reported:** Unquoted `$cli` in single-agent.sh:349 — potential shell injection.

**Finding:** `$cli` IS properly double-quoted on line 349:
```bash
"$cli" "$prompt_content" 2>/dev/null || agent_exit=$?
```

Both `$cli` and `$prompt_content` are quoted. The `$cli` value comes from `orch_model_get_cli()` (line 339) or defaults to the string literal `"claude"` — both internal code paths, no user input surface.

**Verdict: NOT VULNERABLE.** Quotes prevent word splitting and glob expansion. If the model router returns a multi-word CLI (e.g., "codex exec"), the quotes would cause it to look for a single binary named "codex exec" rather than splitting — this is a **functional bug** (would fail to execute), not a security vulnerability. No injection possible.

---

## New Module Audits (6 modules)

### 1. init-project.sh (810 lines)

**Purpose:** Scans a project directory to detect languages, frameworks, and generate agents.conf + scaffold prompts.

| Check | Result |
|-------|--------|
| Double-source guard | PASS — `_ORCH_INIT_PROJECT_LOADED` |
| No eval | PASS |
| No curl/bash | PASS |
| find usage | PASS — `find "$project_dir" -maxdepth 3` with excluded dirs, properly quoted |
| grep usage | INFO — `grep -q "\"${dep_name}\""` in `_orch_init_pkg_json_has_dep` — dep_name could contain regex metacharacters. Low risk: values are hardcoded framework names ("react", "jest", etc.), not user input |
| File writes | PASS — `orch_init_generate_conf` and `orch_init_generate_prompts` write to user-specified output paths using printf/cat heredoc, no injection vectors |
| mkdir -p | PASS — on output paths only |
| Shebang | PASS — `#!/usr/bin/env bash` |

**Verdict: SECURE** — Filesystem read operations with hardcoded patterns. Write operations use safe heredoc/printf. No command injection surface.

---

### 2. self-healing.sh (585 lines)

**Purpose:** Auto-detect and remediate common agent failures (rate-limit, timeout, context overflow, permission, git conflict).

| Check | Result |
|-------|--------|
| Double-source guard | PASS — `_ORCH_SELF_HEALING_LOADED` |
| No eval | PASS |
| git operations | PASS — `git checkout --theirs -- "$conflict_file"` and `git add -- "$conflict_file"` both properly quoted with `--` separator |
| chmod | PASS — `chmod u+rw "$file"` within ownership-scoped `find` results |
| sleep | PASS — `sleep "$backoff"` where backoff is computed from integer arithmetic only |
| kill operations | N/A — no kill calls (signal-handler.sh handles that) |
| Ownership boundary enforcement | PASS — `_orch_heal_file_in_ownership()` validates before any file operation |
| cut/xargs usage | INFO — `cut -d'|' -f1 | xargs` in `_orch_heal_get_ownership()` line 99-101. `xargs` without `-0` could mangle filenames with special chars. Low risk: agents.conf values are controlled internal data. |
| Shebang | PASS — `#!/usr/bin/env bash` |

**Verdict: SECURE** — All file operations are ownership-scoped. Git operations use `--` separator and quoted variables. Backoff uses integer arithmetic only.

---

### 3. quality-gates.sh (627 lines)

**Purpose:** Scripted quality gates (syntax check, shellcheck, tests, ownership validation).

| Check | Result |
|-------|--------|
| Double-source guard | PASS — `_ORCH_QUALITY_GATES_LOADED` |
| No eval | PASS |
| bash -c usage | INFO — `bash -c "$cmd"` in `_orch_gate_exec()` line 114. By design: gates are shell commands registered by the orchestrator. Not user-facing input. |
| timeout wrapper | PASS — `$timeout_cmd` is unquoted but assembled from `"timeout ${_ORCH_GATE_TIMEOUT}"` where timeout is an integer. Word splitting is intentional here to pass "timeout" and the number as separate arguments. |
| Function dispatch | PASS — `"$cmd" "$agent_id"` for function-type gates, properly quoted |
| git diff | PASS — `git diff --name-only HEAD~1` in `orch_gate_check_ownership()`, results read via `while IFS= read -r` |
| Shebang | PASS — `#!/usr/bin/env bash` |

**Verdict: SECURE** — Gate commands are orchestrator-controlled, not user input. Safe patterns throughout.

---

### 4. file-access.sh (498 lines) — CTO PASS confirmed

**Purpose:** 4-zone file access enforcement (protected, owned, shared, unowned).

| Check | Result |
|-------|--------|
| Double-source guard | PASS |
| No eval | PASS |
| No file I/O beyond config parsing | PASS |
| Path matching | PASS — uses string prefix matching, no globbing or regex |
| Protected file list | PASS — hardcoded defaults: auto-agent.sh, agents.conf, CLAUDE.md, etc. |

**Verdict: SECURE** — Pure logic module with no command execution or file writes.

---

### 5. agent-as-tool.sh (378 lines) — CTO PASS confirmed

**Purpose:** Lightweight read-only agent invocations.

| Check | Result |
|-------|--------|
| Double-source guard | PASS |
| No eval | PASS |
| CLI invocation | INFO — `timeout "$_ORCH_TOOL_TIMEOUT" $effective_cmd "$wrapped_prompt"` — `$effective_cmd` deliberately unquoted to allow multi-word CLIs like "codex exec". Value comes from `orch_tool_register()` (programmatic, not user input). |
| Self-invoke guard | PASS — prevents agent from invoking itself |
| Read-only enforcement | INFO — read-only is enforced by the prompt instruction, not technically. The invoked CLI still has write access. Defense-in-depth gap, but acceptable for v0.2.0. |
| Shebang | PASS |

**Verdict: SECURE** — No user-facing injection surface. Read-only enforcement is prompt-based (defense in depth improvement possible in future).

---

### 6. model-budget.sh (405 lines) — CTO PASS confirmed

**Purpose:** Fallback chains and per-agent invocation budget controls.

| Check | Result |
|-------|--------|
| Double-source guard | PASS |
| No eval | PASS |
| No file I/O | PASS — pure in-memory state |
| No command execution | PASS — only `command -v` checks |
| Integer validation | PASS — `[[ "$max_invocations" =~ ^[0-9]+$ ]]` |
| Shebang | PASS |

**Verdict: SECURE** — Pure arithmetic/state module. Zero attack surface.

---

## Integration Review: auto-agent.sh

**Observation:** auto-agent.sh (lines 30-34) currently sources only 8 v0.1.0 modules:
```
bash-version logger error-handler cycle-state agent-timeout dry-run config-validator lock-file
```

The remaining 23 v0.2.0 modules (token-budget, context-filter, model-router, etc.) are NOT yet sourced in auto-agent.sh. The #77 "integration complete" status may refer to module completeness rather than auto-agent.sh wiring. **No new attack surface from integration yet** — these modules are only active when explicitly sourced by tests or single-agent.sh.

---

## Web Security: site/

**dangerouslySetInnerHTML:** One usage in `site/src/app/layout.tsx:97`:
```tsx
dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
```
This is JSON-LD structured data for SEO in a `<script type="application/ld+json">` tag. `JSON.stringify()` on a static object is safe. Standard Next.js pattern. **NOT an XSS vector.**

No other unsafe HTML injection patterns found in site/.

---

## Audit Checklist

### Secrets & Credentials
- [x] No API keys in any file
- [x] No tokens or passwords
- [x] No private paths leaked
- [x] `.gitignore` covers `.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`
- [x] Secrets grep clean (full scan: .txt, .md, .sh, .conf)

### Agent Isolation
- [x] Ownership boundaries defined (9 agents in agents.conf)
- [x] BUG-013 still open — CS must fix ownership paths for 09-qa and 10-security
- [x] New agent 13-hr boundary compliance confirmed (cycle 9)

### Script Safety
- [x] No `eval` on untrusted input (all 31 src/core/*.sh modules)
- [x] No `curl|bash` patterns
- [x] auto-agent.sh unchanged since last audit
- [x] 6 newly audited modules all SECURE
- [x] #78 QA-F003 confirmed NOT vulnerable — $cli is quoted
- [ ] `set -e` still missing — QA-F001, deferred to v0.1.1
- [ ] LOW-02 still open — $all_owned unquoted in detect_rogue_writes

### Supply Chain
- [x] No new dependencies in core
- [x] No curl|bash patterns
- [x] site/ node_modules separate concern

---

## Summary

**Deep audit cycle.** Six previously unaudited v0.2.0 modules now reviewed and cleared:
- `init-project.sh` — SECURE (filesystem scanner, hardcoded patterns)
- `self-healing.sh` — SECURE (ownership-scoped remediation)
- `quality-gates.sh` — SECURE (orchestrator-controlled gate commands)
- `file-access.sh` — SECURE (pure logic, CTO PASS)
- `agent-as-tool.sh` — SECURE (no user input surface, CTO PASS)
- `model-budget.sh` — SECURE (pure arithmetic, CTO PASS)

**#78 QA-F003** resolved as NOT VULNERABLE — `$cli` is properly quoted on single-agent.sh:349.

All 31 modules in src/core/ are now security-audited. **Total module audit coverage: 31/31 (100%).** Two v0.1.1 items remain open (LOW-02, QA-F001). No new findings.
