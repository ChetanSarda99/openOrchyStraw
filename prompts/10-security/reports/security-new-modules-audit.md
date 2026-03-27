# Security Audit — 8 New Modules (Cycles 3-5)

**Date:** 2026-03-20
**Auditor:** 10-Security (Claude Opus 4.6)
**Scope:** 8 modules added in cycles 3-5, previously unaudited
**Verdict:** CONDITIONAL PASS — 2 MEDIUM, 2 LOW findings

---

## Modules Audited

| # | Module | Lines | Verdict |
|---|--------|-------|---------|
| 1 | `src/core/prompt-adapter.sh` | 152 | PASS |
| 2 | `src/core/model-fallback.sh` | 145 | PASS |
| 3 | `src/core/max-cycles.sh` | 131 | PASS |
| 4 | `src/core/agent-kpis.sh` | 443 | PASS (1 LOW) |
| 5 | `src/core/onboarding.sh` | 289 | PASS |
| 6 | `src/core/founder-mode.sh` | 417 | PASS (1 MEDIUM) |
| 7 | `src/core/knowledge-base.sh` | 546 | CONDITIONAL PASS (1 MEDIUM, 1 LOW) |
| 8 | `scripts/benchmark/custom/compare-ralph.sh` | 394 | PASS |

---

## Findings

### MEDIUM-03: knowledge-base.sh — grep -v with unvalidated domain/key in index operations

**File:** `src/core/knowledge-base.sh:72,90`
**Functions:** `_orch_kb_update_index`, `_orch_kb_remove_from_index`
**Risk:** Regex injection via crafted domain or key values

```bash
grep -v "^${domain}/${key}|" "$_ORCH_KB_DIR/index.txt" > "$tmpfile"
```

If `domain` or `key` contain regex metacharacters (`.`, `*`, `+`, `[`, etc.), the grep pattern becomes unpredictable. A domain like `patterns.*` would match unintended index lines, potentially deleting entries belonging to other domains.

**Impact:** Data corruption in knowledge base index — unintended entries could be removed during store/delete operations. Not directly exploitable for RCE but could cause knowledge loss.

**Recommendation:** Use `grep -Fv` (fixed-string match) instead of `grep -v` to prevent regex interpretation. Alternatively, validate domain/key against `[a-zA-Z0-9_-]` pattern before use.

**Assigned to:** 06-backend
**Severity:** MEDIUM

---

### MEDIUM-04: founder-mode.sh — JSON injection in override_priority output

**File:** `src/core/founder-mode.sh:324`
**Function:** `orch_founder_override_priority`

```bash
json+="\"${key}\":\"${_ORCH_FOUNDER_OVERRIDES[$key]}\""
```

Agent name (`$key`) and priority value are interpolated directly into JSON without escaping. If an agent name or priority value contains `"`, `\`, or newlines, the JSON output is malformed or injectable.

**Impact:** Malformed `founder-overrides.json` file. In a prompt injection scenario where an agent manipulates its own name in context, this could corrupt the founder state. Low exploitability in practice since agent names come from agents.conf (trusted source), but priority values come from function arguments.

**Recommendation:** Validate priority against a whitelist (`critical|high|normal|low|skip`) and validate agent names against `[a-zA-Z0-9_-]`. The priority whitelist is already documented in the function comment but not enforced.

**Assigned to:** 06-backend
**Severity:** MEDIUM

---

### LOW-03: agent-kpis.sh — Test execution of arbitrary .sh files

**File:** `src/core/agent-kpis.sh:130`
**Function:** `_orch_kpi_test_pass_rate`

```bash
if bash "$test_file" &>/dev/null; then
```

This executes every `test-*.sh` file in `tests/core/` via `bash`. While the directory is trusted (project-owned), a malicious file placed there (e.g., by a compromised agent writing outside boundaries) would be executed silently.

**Impact:** Code execution if an unauthorized file is placed in `tests/core/`. Mitigated by file ownership boundaries in agents.conf (only 09-QA owns `tests/`).

**Recommendation:** No immediate action required — ownership boundary is the primary control. Document this as an assumption: KPI collection trusts `tests/core/` contents.

**Assigned to:** Track only
**Severity:** LOW

---

### LOW-04: knowledge-base.sh — Path traversal partially possible in domain/key

**File:** `src/core/knowledge-base.sh:128-131`
**Function:** `orch_kb_store`

```bash
local domain_dir="$_ORCH_KB_DIR/$domain"
mkdir -p "$domain_dir"
local entry_file="$domain_dir/${key}.md"
```

If `domain` is `../../etc` or `key` is `../../../etc/passwd`, the path could escape `~/.orchystraw/knowledge/`. The `mkdir -p` would create directories outside the knowledge base.

**Impact:** File write outside intended directory. In practice, agents pass hardcoded domain strings like "patterns" or "decisions", not user-controlled input. But if `orch_kb_store` is ever exposed to external input, this becomes HIGH.

**Recommendation:** Add validation: reject domain/key containing `/`, `..`, or any path separator. Example: `[[ "$domain" =~ [./] ]] && return 1`

**Assigned to:** 06-backend
**Severity:** LOW (escalate to HIGH if ever exposed to untrusted input)

---

## Clean Modules — No Findings

### prompt-adapter.sh — PASS
- No eval, no exec, no command injection vectors
- Model detection uses safe `case` statement with hardcoded patterns
- `grep "^${agent_id}|"` on agents.conf: agent_id comes from orchestrator (trusted), and `|` delimiter prevents partial matching
- heredoc templates are safe — variable expansion in heredocs doesn't execute commands
- `cat "$prompt_file"` is safe — reads file content, doesn't execute

### model-fallback.sh — PASS
- No eval, no exec
- `${!env_var}` indirect expansion on line 45: the variable name is constructed from `"USAGE_${model^^}"` where `model` comes from the hardcoded set (claude/openai/gemini). Safe.
- `grep -oP` on context file: regex `${model}=\K[0-9]+` — model is from trusted source. Pattern only matches digits after `=`, preventing injection.
- Usage comparison `[[ "$usage" -ge "$_USAGE_THRESHOLD" ]]` is integer comparison — non-integer would cause bash error, not exploit.

### max-cycles.sh — PASS
- Regex validation on line 30: `[[ ! "$val" =~ ^[0-9]+$ ]]` — rejects anything that isn't a pure integer
- Bounds checking: clamps 1-100, prevents absurd values
- `$((val))` arithmetic on validated integer — safe
- `head -1 "$config_file" | tr -d '[:space:]'` — reads config safely, strips whitespace
- `printf '%s\n' "$validated" > "$config_file"` — safe write of validated integer

### onboarding.sh — PASS
- No eval, no exec, no command injection
- `orch_onboard_detect_project` only checks `[[ -f "$project_dir/package.json" ]]` etc. — file existence tests, not file execution
- Project type detection uses safe `case` statements
- `cat > "$prompt_file" <<PROMPT` — heredoc write with variable expansion, no command execution
- `mkdir -p "$agent_dir"` — creates directories from agent names that come from hardcoded `case` results

### compare-ralph.sh — PASS
- `set -euo pipefail` — good practice
- `_validate_positive_int` regex: `^[1-9][0-9]*$` — strict integer validation on all CLI args
- `_validate_model` whitelist: only sonnet/opus/haiku — no arbitrary model strings
- Python3 inline script (lines 207-254): reads from file paths constructed by the script itself (`$ralph_results`, `$orchy_results`), not from user input. The filenames use `$run_ts` from `date +%Y%m%d-%H%M%S` which is safe.
- `jq -r` calls use `$ralph_summary` etc. — paths constructed internally
- `awk "BEGIN {printf ...}"` calls use values from jq output (numbers) — no injection vector
- Temp files use PID in path (`$$`) — not mktemp, but acceptable for benchmarks (not security-critical)

---

## Secrets Scan

```
grep -rn "key|token|secret|password|api_key" across all 8 files
```

**Result:** CLEAN. All matches are variable names (`$key`, `key_name`, `keyword`), not actual credentials.

---

## Checklist

- [x] No API keys in any file
- [x] No tokens or passwords
- [x] No eval on untrusted input
- [x] No unquoted variables causing word-splitting (within these modules)
- [x] mktemp used for temp files in knowledge-base.sh (GOOD)
- [x] All shebangs are `#!/usr/bin/env bash` (GOOD)
- [x] Double-source guards on all modules (GOOD)
- [x] No curl|bash patterns
- [x] No external dependencies beyond git, jq, python3 (benchmark only)

---

## Updated Audit Coverage

**Before:** 31/38 modules audited
**After:** 39/38* modules audited (*count increased to 42 total — 35 .sh files in src/core/ + 7 elsewhere)

Remaining unaudited src/core/ modules (added since last count):
- `agent-as-tool.sh`
- `context-filter.sh`
- `file-access.sh`
- `init-project.sh`
- `qmd-refresher.sh`
- `session-windower.sh`
- `single-agent.sh`

**Recommendation:** Audit these 7 remaining modules next cycle to reach 100% coverage.

---

## Summary

| Severity | Count | IDs |
|----------|-------|-----|
| CRITICAL | 0 | — |
| HIGH | 0 | — |
| MEDIUM | 2 | MEDIUM-03 (grep regex injection), MEDIUM-04 (JSON injection) |
| LOW | 2 | LOW-03 (test execution trust), LOW-04 (path traversal) |

**Overall:** CONDITIONAL PASS. No blocking issues for v0.2.0. MEDIUM-03 and MEDIUM-04 should be fixed before v0.2.0 release. LOW items tracked for v0.2.1+.
