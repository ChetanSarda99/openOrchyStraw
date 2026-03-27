# QA Report — Cycle 36

**Date:** 2026-03-20
**Agent:** 09-QA
**Verdict:** CONDITIONAL PASS

---

## Test Results

| Suite | Result |
|-------|--------|
| Unit tests | 38/39 pass (agent-kpis jq pre-existing) |
| Integration test | 42/42 pass (but only covers 8/38 modules — QA-F004 still open) |
| Site build | PASS (25 pages, 0 errors) |
| Tauri build | N/A (src-tauri/ not yet scaffolded) |

---

## Code Review: Cycle 5 Modules

### founder-mode.sh — PASS

- Correct `orch_` prefix on all 6 public functions
- `_orch_` prefix on 1 internal function (`_orch_founder_parse_agents`)
- Double-source guard present and functional
- Proper error handling (returns 1 on missing args for all public functions)
- No eval on user input — safe
- No external dependencies (JSON built in pure bash, no jq)
- agents.conf parsing handles comments, blank lines correctly
- Test coverage: 70 assertions in test-founder-mode.sh — comprehensive, all pass

**Minor note:** `_orch_founder_parse_agents` uses `echo "$line" | cut -d'|'` spawning subprocesses per line. Could use bash `IFS='|' read` for performance. Not a bug — style/perf only. No action needed.

### knowledge-base.sh — PASS

- Correct `orch_` prefix on all 8 public functions
- `_orch_` prefix on 3 internal functions
- Double-source guard present and functional
- Proper error handling with descriptive error messages
- Index management via grep -v is safe (patterns constructed from controlled domain/key values)
- Frontmatter parsing is correct (handles opening/closing `---` delimiters)
- Merge logic correctly uses timestamp comparison (newer wins)
- Test coverage: 43 assertions in test-knowledge-base.sh — comprehensive, all pass

### compare-ralph.sh (scripts/benchmark/custom/) — PASS with notes

- Input validation present: `_validate_positive_int`, `_validate_model`
- Dependency check (`_check_deps`) gates execution properly
- Clean separation: load tasks → run both approaches → aggregate → compare
- Well-structured CLI arg parsing with `--help`
- Sources instance-runner.sh and results-collector.sh correctly
- Python heredoc for per-task comparison is clean

**Note:** Inherits BENCH-SEC-03 pattern from results-collector.sh (see below).

---

## BENCH-SEC Security Findings — Status Check

### BENCH-SEC-01: Command injection via prompt escaping — FIXED

**File:** `scripts/benchmark/lib/instance-runner.sh:99-102`
**Fix:** Agent prompt and workspace path passed via environment variables (`BENCH_WORKSPACE`, `BENCH_PROMPT`) instead of being interpolated into a `bash -c` string. Correct fix.

### BENCH-SEC-02: Unsafe eval of test_command from JSON — PARTIALLY FIXED

**File:** `scripts/benchmark/lib/instance-runner.sh:121`
**Change:** `eval "$test_command"` replaced with `bash -c "$test_command"`.
**Assessment:** `bash -c "$test_command"` is functionally similar to `eval` for injection purposes — both execute the string as shell code. However, `bash -c` avoids double-expansion that `eval` performs, which reduces one class of injection. Since `test_command` is inherently meant to be executed as a shell command (it's the benchmark test runner), the fix is acceptable IF the JSON input source is trusted. The `_validate_repo_url` function validates repo URLs but there is no validation on `test_command` content.
**Risk:** LOW — benchmark JSON files are developer-created, not user-supplied at runtime.
**Status:** ACCEPTED with caveat — document that benchmark JSON must be trusted input.

### BENCH-SEC-03: Python shell escape in file paths — NOT FIXED

**File:** `scripts/benchmark/lib/results-collector.sh:16`
**Issue:** `with open('$results_file') as f:` — bash variable `$results_file` is interpolated directly into a Python string literal inside `python3 -c`. If the file path contains a single quote (e.g., `results/it's-done.jsonl`), it breaks out of the Python string and enables arbitrary Python code execution.
**Same pattern in:** `compare-ralph.sh:213-218` (`$ralph_results`, `$orchy_results`)
**Fix needed:** Use `sys.argv` to pass file paths to Python instead of string interpolation:
```python
python3 -c "
import json, sys
results_file = sys.argv[1]
with open(results_file) as f:
    ...
" "$results_file"
```
**Assigned to:** 06-Backend
**Severity:** HIGH (code execution via crafted file path)

---

## Open Issues Status

| ID | Title | Status | Notes |
|----|-------|--------|-------|
| QA-F004 | Integration test expansion (8/38 modules) | OPEN | Still covers only original 8 modules |
| BENCH-SEC-03 | Python shell escape in file paths | OPEN | Not fixed — see above |
| BUG-012 | PROTECTED FILES missing from 4 prompts | OPEN | 5/9 fixed, 4 remaining (01-ceo, 03-pm, 10-security, 13-hr) |
| agent-kpis jq | test-agent-kpis requires jq | PRE-EXISTING | Not a regression |

---

## Verdict Rationale

**CONDITIONAL PASS** because:
- All shipping code passes tests (38/39, sole failure is pre-existing jq dependency)
- Cycle 5 modules (founder-mode, knowledge-base) are well-written, well-tested, and secure
- compare-ralph.sh is clean with proper input validation
- BENCH-SEC-01 correctly fixed
- BENCH-SEC-02 acceptably mitigated
- BENCH-SEC-03 remains open — HIGH severity but low likelihood (file paths are script-constructed)
- No regressions detected

**Blockers for full PASS:**
1. BENCH-SEC-03 must be fixed (results-collector.sh + compare-ralph.sh)
2. QA-F004 integration test should cover all 38 modules

---

*Generated by 09-QA — cycle 36*
