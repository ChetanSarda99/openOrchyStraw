# Security Audit — Cycle 14 (context cycle 1, 2026-04-10)

**Auditor:** 10-security
**Scope:** Read-only review of all `src/core/*.sh` and `scripts/*.sh` changes since cycle 13.
**Verdict:** **CONDITIONAL PASS** — no HIGH/CRITICAL. 1 MEDIUM (data-loss risk), several LOW/INFO defense-in-depth items.

---

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 0     | — |
| HIGH     | 0     | — |
| MEDIUM   | 1     | AI-SEC-01 (new) |
| LOW      | 4     | CF-SEC-01, CA-SEC-01, BM-SEC-01, AI-SEC-02 (new/uncovered) |
| INFO     | 4     | CF-SEC-02, CA-SEC-02, PR-SEC-01, SS-SEC-01 |

No secrets leaked. `.gitignore` is complete. `scripts/auto-agent.sh` (protected file) is untouched by me. Release posture unchanged: safe to ship current state with the caveats below.

---

## Files reviewed this cycle

Modified since cycle 13 (by mtime / git log):

- `src/core/cofounder.sh` (Apr 10) — **new review**
- `src/core/conditional-activation.sh` (Apr 10) — **new review**
- `src/core/auto-improve.sh` (Apr 9) — **new review**
- `src/core/auto-researcher.sh` (Apr 9) — **new review**
- `src/core/model-selector.sh` (Apr 9) — spot check
- `src/core/stall-detector.sh` (Apr 9) — **new review** (small, full read)
- `src/core/dynamic-router.sh` (Apr 9) — spot check (delta from cycle 9 review)
- `src/core/context-injector.sh` (Apr 8) — spot check
- `src/core/decision-store.sh`, `project-registry.sh`, `quality-scorer.sh`, `dry-run.sh` (Apr 7) — unchanged from prior audits, not re-reviewed
- `scripts/pr-review.sh` — **new review** (post-commit review helper)
- `scripts/commit-summary.sh`, `secrets-scan.sh` — delta review
- `scripts/benchmark/run-benchmark.sh` — delta review

Secrets regex sweep across all `*.sh / *.md / *.ts / *.json / *.env` in repo: **CLEAN** (previous false positives in reports and `.gitleaks.toml` regex patterns only).

`.gitignore` re-verified: `.env*`, `*.pem`, `*.key`, `*secret*.json`, `credentials.json`, `token.json`, etc. — all present.

---

## New findings

### AI-SEC-01 — MEDIUM — auto-improve.sh runs `git reset --hard` without dirty-tree check

**File:** `src/core/auto-improve.sh:164-172` (`_improve_revert`), called from `orch_improve_step:218, 238`.

```bash
_improve_revert() {
    local snapshot="$1"
    local project_root="${PROJECT_ROOT:-.}"
    if [[ -n "$snapshot" ]]; then
        git -C "$project_root" reset --hard "$snapshot" 2>/dev/null
    fi
}
```

**Risk:** `_improve_snapshot()` only captures `HEAD` (line 155). When `orch_improve_run` is invoked with uncommitted changes in the working tree, any subsequent reject path calls `reset --hard HEAD`, which silently destroys the user's local edits. This is a data-loss hazard in the Karpathy auto-improvement loop. Severity MEDIUM because:

- It's destructive by design but no pre-flight refuses to run on a dirty tree.
- The loop is invoked automatically via `--auto-improve` (see `db5d16a` and `693d4ae` commits), so a user running the CLI over their own work could be bitten without warning.
- It contradicts the user's "production ready" bar (per Chetan's memory — must not trash user state).

**Remediation (not mine to implement — 06-backend owns):**
1. At `orch_improve_init`, `git status --porcelain` → if non-empty, **refuse** and log an error.
2. Or: `git stash push -u -m orch-improve-prerun` before loop, `git stash pop` in trap on exit.
3. Document the destructive semantic in the CLI `--auto-improve` help text.

### AI-SEC-02 — LOW — auto-improve.sh hardcoded bash paths

**File:** `src/core/auto-improve.sh:115, 203-204`

```bash
output=$(/opt/homebrew/bin/bash "$test_runner" 2>&1 || /usr/bin/bash "$test_runner" 2>&1)
...
/opt/homebrew/bin/bash "${ORCH_ROOT:-$project_root}/scripts/auto-agent.sh" orchestrate 1 2>/dev/null || \
/usr/bin/bash "${ORCH_ROOT:-$project_root}/scripts/auto-agent.sh" orchestrate 1 2>/dev/null
```

**Risk:** Portability regression — commit `1bf53c8` (CRITICAL: Fix portability) addressed hardcoded paths elsewhere but missed this module. On Linux / Intel Mac / any non-brew path, both branches silently fail. Not a security finding, but defense in depth and ties back to "production ready" bar.

**Remediation:** replace with `"${BASH:-bash}" "$test_runner"` or `command -v bash`.

### CF-SEC-01 — LOW — cofounder.sh mutates `agents.conf` without locking

**File:** `src/core/cofounder.sh:263-273` (`orch_cofounder_adjust_intervals`)

```bash
tmp_file=$(mktemp)
while IFS= read -r line; do
    if [[ "$line" =~ ^${id}[[:space:]]*\| ]]; then
        echo "$new_line"
    else
        echo "$line"
    fi
done < "$conf_file" > "$tmp_file"
mv "$tmp_file" "$conf_file"
```

**Risk:** No advisory lock is taken on `agents.conf` before the read-modify-write. If a user is editing `agents.conf` in another process, or if two orchestrator cycles run concurrently (which is now possible via `run --all --parallel`, commit `deda72c`), the last writer wins and edits are silently lost. Also the line-match regex on line 267 uses unescaped `$id` — agent IDs are trusted (config-sourced) so this is defense in depth, not exploitable.

**Remediation:** call `orch_lock_acquire_named "agents.conf"` / `orch_lock_release_named` (from `lock-file.sh`) around the write. Already available in the codebase — no new code needed.

**Architectural note:** I understand cofounder.sh is intentionally allowed to write `agents.conf` (that's the whole point of the Co-Founder agent — autonomous interval tuning). This finding is about the **mechanism**, not the authority.

### CA-SEC-01 — LOW — conditional-activation.sh context mention uses substring + unescaped regex

**File:** `src/core/conditional-activation.sh:134, 143-148`

```bash
if [[ "$_ORCH_ACTIVATION_CONTEXT" == *"$agent_id"* ]]; then
    return 0
fi
...
if [[ "$context_lower" =~ (need|block|wait|assign|must|should).*$label_lower ]] || \
   [[ "$context_lower" =~ $label_lower.*(need|block|wait|assign|must|should) ]]; then
```

**Risk:**
1. Substring match on line 134 — `06-backend` matches anywhere in context including URLs, prior-cycle history dumps, comments. Any mention of `backend` triggers an activation, inflating token spend. Defense-in-depth / cost control concern, not injection.
2. `$label_lower` is interpolated into a regex without escaping. Labels are config-sourced and currently plain ASCII, so not exploitable, but a label like `qa.*` would break the matcher.

**Remediation:** word-boundary match (bash `=~` with `\<${agent_id}\>` is fragile — consider `grep -wqF`), and escape regex metachars in label interpolation.

### BM-SEC-01 — LOW — `eval "$test_command"` in benchmark runner

**File:** `scripts/benchmark/run-benchmark.sh:126`

```bash
_run_task_tests() {
    local workspace="$1" test_command="$2"
    ...
    (
        cd "$workspace"
        if eval "$test_command" >/dev/null 2>&1; then
```

`test_command` is loaded via `jq -r '.test_command // ""' "$task_json"` from a benchmark task file.

**Risk:** LOW because benchmark task JSON lives inside the repo (`scripts/benchmark/cases/`) and is trusted by the author. But the **pattern is dangerous** — SWE-bench will eventually ingest external task sets (real SWE-bench cases), and at that point `eval` of arbitrary strings from a JSON field becomes a sandbox-escape vector.

**Remediation:** before `v0.2.0` tag, either:
- Whitelist permitted test commands (e.g. `pytest …`, `bash tests/…`, `npm test`), or
- Require test command to be an **array** (`.test_argv`) and `exec` via `"${argv[@]}"`, never `eval`.

I'm flagging this now so it doesn't become HIGH the day SWE-bench ingestion goes live.

---

## Informational findings

### CF-SEC-02 — INFO — cofounder.sh JSON parsed by tr+scan instead of jq

**File:** `cofounder.sh:98-121, 326-345`

```bash
for field in $(echo "$line" | tr '{},:"' ' '); do
    case "$prev" in
        agent) agent="$field" ;;
        cost_estimate) cost="$field" ;;
        ...
    esac
    prev="$field"
done
```

**Risk:** Fragile. Word splitting on `$(...)` means string values with spaces would be tokenized. Could under-report or over-report `_COFOUNDER_DAILY_COST`, which silently disables the $50 budget escalation gate. Not a security issue — a correctness issue for the agent's own budget enforcement.

**Remediation:** the module already checks `command -v jq` is available (via dependent modules). Replace the hand-rolled parser with `jq -r 'select(.timestamp | startswith("'"$today"'")) | .cost_estimate'`.

### CA-SEC-02 — INFO — BUG-019 multiline pattern in conditional-activation

**File:** `conditional-activation.sh:337`

```bash
issue_count=$(gh issue list --state open --limit 1 --json number 2>/dev/null | grep -c '"number"' 2>/dev/null || echo "0")
```

**Risk:** Same BUG-019 shape — `grep -c` prints `0` and returns 1 on no-match, the `|| echo "0"` then appends another `0`, so `$issue_count` = `"0\n0"`. Subsequent `[[ "$issue_count" -gt 0 ]]` behavior is brittle. This is the pattern QA filed as BUG-019 and backend fixed in 7 locations — this occurrence slipped in after the fix.

**Remediation:** `issue_count=$(...) || issue_count=0` (the canonical fix backend applied elsewhere).

### PR-SEC-01 — INFO — BUG-019 multiline pattern in pr-review.sh

**File:** `scripts/pr-review.sh:170, 184`

```bash
local_count=$(grep -c "\b${name}\b" "$filepath" 2>/dev/null || echo 0)
```

Same shape as CA-SEC-02. Not security — functional bug. Flagged for 06-backend cleanup when they next sweep BUG-019 residue.

### SS-SEC-01 — INFO — secrets-scan.sh private-key regex is awkward but functional

**File:** `scripts/secrets-scan.sh:29`

```bash
'PRIVATE KEY-''----'                          # Private key block
```

The adjacent single-quoted strings concatenate to `PRIVATE KEY-----` (five dashes), which still matches the trailing `-----` of both `BEGIN PRIVATE KEY-----` and `END PRIVATE KEY-----` lines in a PEM. So it's functional, but the intent is unclear and one careless edit could break it.

**Remediation:** replace with the explicit PEM header pattern `-----BEGIN[A-Z ]+PRIVATE KEY-----` for readability.

---

## Verified secure this cycle

- **Secrets scan** (`sk-[a-zA-Z0-9]{20,}|xoxb-|ghp_|AKIA|-----BEGIN`) across all source: **zero real hits** (existing matches are regex patterns inside `secrets-scan.sh` itself, `.gitleaks.toml`, and a prior security report citing them — all legitimate).
- **`.gitignore`** — all sensitive patterns present (`.env*`, `*.pem`, `*.key`, `*.p12`, `*secret*.json`, `credentials.json`, `token.json`, `strategy-vault/`, `docs/infrastructure/`).
- **`scripts/auto-agent.sh`** (PROTECTED) — 102 kB, I did not modify. Protected-file rule honored.
- **`src/core/stall-detector.sh`** — full read; clean. Only note: `since_ref` read from state file is passed to `git log "${since_ref}..HEAD"` — git treats it as a revspec, not shell, so safe even if state file is locally tampered.
- **`src/core/model-selector.sh`** — grep for `API_KEY|curl|wget|http`: no hits. Selector invokes CLI tools (`claude`, `gpt`, etc.), does not ship secrets over the wire directly.
- **`src/core/dynamic-router.sh`** — grep for `reset --hard|rm -rf|eval \$`: clean. DR-SEC-02 integration note from cycle 9 still applies (quote `orch_router_model` output on consumption).
- **`src/core/auto-researcher.sh`** — uses `gh api "$endpoint"` where `$endpoint` is URL-path assembled from trusted config. `gh api` does not shell-eval; account names from `research-sources.conf` only contribute to URL path and output filenames (`${_ORCH_RES_CACHE_DIR}/${account}-${today}.json`). LOW path-traversal risk if config ingests an account like `foo/../bar` — trust-boundary, not exploit.

---

## Carry-forward backlog (not reviewed this cycle)

Cycle 5's "HARD PAUSE" was broken by all the Apr 7–10 activity. I cleared the newly-touched modules this cycle. The following pre-existing backlog items remain unreviewed and are lower priority than the new findings above:

1. `src/core/single-agent.sh` — command injection, config parsing, ownership enforcement
2. `scripts/benchmark/` — full review (BM-SEC-01 partial; rest pending)
3. `src/core/qmd-refresher.sh` — state tracking, file I/O
4. `src/core/prompt-template.sh` — #54 template inheritance
5. `src/core/task-decomposer.sh` — markdown parsing sanitization
6. `src/core/init-project.sh` — path traversal, generated conf safety

I'll chip away at these across the next 2–3 cycles unless PM re-prioritizes.

---

## Release gates

- v0.1.0 — previously cleared, still cleared. Nothing in this cycle regresses it.
- v0.2.0 — previously CONDITIONAL PASS. **AI-SEC-01 (MEDIUM) must be fixed before tag** — data-loss risk in user-invoked `--auto-improve` is a ship-blocker for the "production ready" bar. BM-SEC-01 should be documented as a trust-boundary constraint on benchmark task sources.
- Budget-gate integrity — CF-SEC-02 (JSON parse fragility) weakens the $50 escalation gate. Would be nice-to-fix alongside AI-SEC-01.

---

## For 06-backend (action items, priority-ordered)

1. **[MEDIUM] AI-SEC-01** — `src/core/auto-improve.sh`: refuse to run with dirty tree, or stash/pop. File new bug.
2. **[LOW] CF-SEC-01** — `src/core/cofounder.sh`: wrap `agents.conf` write in `orch_lock_acquire_named/release_named`.
3. **[LOW] CA-SEC-01** — `src/core/conditional-activation.sh`: word-boundary match for context mentions; escape `$label_lower` regex interp.
4. **[LOW] BM-SEC-01** — `scripts/benchmark/run-benchmark.sh`: plan migration from `eval "$test_command"` to array-based `exec` before external SWE-bench ingestion.
5. **[LOW] AI-SEC-02** — `src/core/auto-improve.sh`: replace hardcoded `/opt/homebrew/bin/bash` and `/usr/bin/bash` with portable resolution.
6. **[INFO] CA-SEC-02, PR-SEC-01** — BUG-019 pattern residue; fold into the existing grep-count sweep.
7. **[INFO] CF-SEC-02** — replace tr-and-scan JSON parser with `jq`.
8. **[INFO] SS-SEC-01** — rewrite the private-key pattern in `secrets-scan.sh` for clarity.

## For 03-pm

Please file GitHub issues for AI-SEC-01 (MEDIUM, ship-blocker for next tag) and the four LOW items. The four INFOs can be tracked in the backlog without individual issues.

---

*Report written by 10-security. Read-only audit. No source files were modified.*
