# Module Review — Cycle 1 (2026-04-10)

_Reviewer: CTO (02-cto)_
_Scope: two long-pending P1 review items._

Target files:
- `src/core/freshness-detector.sh` (431 LOC) — issue #167
- `scripts/health-dashboard.sh` (441 LOC) — issue #184

Both modules have been sitting in the review queue for multiple cycles.
Cleared in this cycle.

---

## 1. `src/core/freshness-detector.sh` — APPROVED

### Compliance with project standards

| Standard | Status | Notes |
|---|---|---|
| `#!/usr/bin/env bash` shebang (BASH-001) | PASS | line 1 |
| Double-source guard | PASS | `_ORCH_FRESHNESS_LOADED` lines 21-22 |
| Zero core dependencies | PASS | `git` and `gh` are optional and gated |
| Fail-open behavior | PASS | every branch returns cleanly if optional tool missing |
| Portable date parsing | PASS | tries `date -d` (GNU) then `date -j -f` (BSD) — lines 39-48 |
| Namespaced public API | PASS | `orch_freshness_*` prefix |
| No touching of protected files | PASS | pure read-only |

### Design assessment

The split between v0.3 (static scan) and v0.4 (git-blame + gh refs + drift)
is clean — you can use the static scanner without `git` or `gh` installed,
and both advanced features degrade gracefully. This matches the
architecture principle of "optional capabilities, mandatory core."

The finding format `TYPE|file|line|detail` is simple and works because all
field sources are controlled (enum type, own file paths, integer line
numbers, short English detail strings). No escaping machinery needed at
current scope.

### Findings

| ID | Sev | Location | Finding |
|---|---|---|---|
| FD-01 | LOW | 93 | `find ... -name '*.md' -o -name '*.txt'` lacks parentheses around the OR. Works today because there are no other predicates, but becomes a silent bug the instant someone adds `-type f` in front. Recommend `find "$target" -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null`. |
| FD-02 | LOW | 111-139 | Per-line shells: every `echo "$line" \| grep -qiE ...` forks a subshell **and** a grep process. For a prompts/ tree with ~50 files × ~300 lines × ~5 checks, that's ~75k forks. Use bash-native regex: `[[ "$line" =~ (✅\|DONE\|FIXED\|SHIPPED\|completed\|CLOSED) ]]`. Performance only, not correctness. |
| FD-03 | LOW | 308-322 | `orch_freshness_check_refs` loops `gh issue view` once per `#NNN` reference per line with a 5s timeout each. No dedup, no cache. A file with 40 refs and a slow network can take 200s. Recommend: collect refs with a first pass, dedup into an associative array, call `gh` once per unique ref per invocation. |
| FD-04 | LOW | 377-428 | `orch_freshness_drift` uses `echo ... \| grep -c` idioms for every comparison. Also runs `comm -23 <(echo "$curr_headings") <(echo "$prev_headings")` which spawns two subshells; harmless but slow. Low priority polish. |
| FD-05 | INFO | 60-75 | `orch_freshness_init` silently resets `_ORCH_FRESHNESS_FINDINGS=()` and `_ORCH_FRESHNESS_SCANNED=0`. This is intentional but undocumented — callers who `scan` twice across two `init`s will lose the first batch. Document in the header comment. |

### Verdict

**APPROVED — no blocking changes required.** All findings are LOW/INFO
performance polish. Module matches BASH-001, EFFICIENCY-001, and the
zero-deps policy. Ship as-is; schedule FD-01..FD-03 as a follow-up if the
freshness scanner gets wired into the orchestrator loop.

---

## 2. `scripts/health-dashboard.sh` — APPROVED WITH CHANGES

### Compliance with project standards

| Standard | Status | Notes |
|---|---|---|
| `#!/usr/bin/env bash` shebang | PASS | line 1 |
| `set -euo pipefail` | PASS | line 10 — correct for a one-shot CLI script |
| Zero core dependencies | PASS | zero-dep inline HTML + hand-rolled canvas charts (no Chart.js CDN) |
| Canonical `agents.conf` path with legacy fallback | PASS | lines 17-18 |
| Reads protected files, writes none | PASS | only writes to `$OUTPUT` |

### Design assessment — positives

- **Single-file HTML artifact with inline canvas rendering** is exactly
  the right call for a zero-dep project. No CDN, no asset pipeline, opens
  offline.
- **Terminal ASCII output alongside HTML** (lines 328-437) is great — CLI
  users get immediate feedback without opening a browser.
- **State-tolerant parsing:** every input file (`STATE_FILE`, `AUDIT_FILE`,
  `METRICS_FILE`) is guarded with `[[ -f ... ]]`, so a fresh project with
  no history renders an empty dashboard instead of crashing.

### Findings

| ID | Sev | Location | Finding |
|---|---|---|---|
| HD-01 | **MEDIUM** | 439 | `command -v xdg-open` only exists on Linux. On macOS the dashboard will never auto-open. The project README and CLAUDE.md both claim "works on macOS ARM/Intel + Linux". Fix: detect platform and choose opener. See patch below. |
| HD-02 | **MEDIUM** | 62-90, 99-118 | JSONL "parser" is `tr '{},:"' ' '` + a token state machine. This is fragile: (a) any string field containing a space (e.g. `"label":"Backend Dev"`) corrupts the next `prev` lookup; (b) nested objects break it; (c) it depends on key ordering. Works today only because `audit.jsonl` and `metrics.jsonl` happen to have flat, space-free values. Replace with per-key regex: `agent=$(grep -oE '"agent":"[^"]*"' <<< "$line" \| cut -d'"' -f4)`. Still zero-dep, still no jq. |
| HD-03 | LOW | 83-86 | Cost parsing strips all non-digits then reconstructs via `printf '%06d'`. Assumes every cost entry has exactly 6 fractional digits. If the audit writer changes format (e.g. `0.01` instead of `0.010000`) the display is silently wrong by orders of magnitude. Recommend: standardize the audit format in COST-001 follow-up, or switch to integer microdollars throughout. |
| HD-04 | LOW | 66, 104 | `for field in $(echo "$line" \| tr ...)` is subject to pathname expansion. A field containing `*` or `?` would glob. Unlikely in audit data but trivially hardened with `set -f` around the loop or `IFS` + `read -a`. |
| HD-05 | LOW | 216 | `${agent_grid_rows}` is interpolated raw into HTML. Source data is `agents.conf` (local, trusted), so real XSS risk is zero, but any future path that feeds external data through here would inject. Cheap fix: minimal `< > &` escape pass on `label` before emission. |
| HD-06 | INFO | 166-167 | `issue_val="${M_ISSUES[$i]:-0}"` followed by `cycle_issues+="${issue_val:-0}"` — the inner `:-0` is redundant because the outer already guarantees a value. Cosmetic. |

### Required fix — HD-01 (suggested patch)

```bash
# ── Open in browser (cross-platform) ──
if [[ -t 1 ]]; then
    case "$(uname -s)" in
        Darwin) command -v open      &>/dev/null && open      "$OUTPUT" 2>/dev/null & ;;
        Linux)  command -v xdg-open  &>/dev/null && xdg-open  "$OUTPUT" 2>/dev/null & ;;
    esac
fi
```

Replace lines 439-441 with the above. Five extra lines, fixes the macOS
gap without adding a dependency.

### Verdict

**APPROVED WITH CHANGES.** Not a release blocker — `scripts/health-dashboard.sh`
is a helper, not part of the orchestration loop. But HD-01 should land in
the next backend cycle (trivial patch) and HD-02 should be followed up
before the dashboard is wired into the desktop app's telemetry pane, or
the first audit.jsonl format change will silently corrupt all charts.

---

## Review queue impact

Before this cycle:
- freshness-detector.sh — pending since v0.3.0
- health-dashboard.sh — pending since cycle this-session-start

After this cycle: **2 items cleared.** Remaining P1/P2 review items per
02-cto prompt: first benchmark dry-run JSONL (waiting on 06-backend per
BENCH-001 follow-up #1), `orchystraw benchmark` CLI routing (waiting on
06-backend per BENCH-001 follow-up #2).

CTO review queue is effectively empty until 06-backend publishes
benchmark artifacts.
