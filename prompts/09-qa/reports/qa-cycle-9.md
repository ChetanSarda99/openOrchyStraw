# QA Report — Cycle 9 (v0.2.0 Phase 1 Review)

**Date:** 2026-03-29
**QA Engineer:** 09-QA (Claude Opus 4.6)
**Verdict: CONDITIONAL PASS — dynamic-router.sh functional but has edge case bugs**

---

## Executive Summary

v0.2.0 Phase 1 module `dynamic-router.sh` is functional — all 26 tests pass, 12/12 test
files pass (0 regressions), site build succeeds. Code review found 3 new bugs in the
dynamic-router (1 HIGH, 2 MEDIUM) related to edge case handling. All existing known bugs
from prior cycles remain in their expected state.

---

## 1. Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| run-tests.sh (full suite) | 12/12 files | ALL PASS |
| test-dynamic-router.sh | 26/26 tests | ALL PASS |
| Site build (Next.js) | static export | PASS |
| Core module syntax (bash -n) | 11/11 modules | ALL PASS |

**Regressions:** 0

---

## 2. dynamic-router.sh — Code Review

### 2.1 Architecture Assessment

The module implements Kahn's algorithm for topological sorting and BFS layering for
execution groups. The design is clean:
- 8 public functions, well-documented
- Double-source guard (`_ORCH_DYNAMIC_ROUTER_LOADED`)
- Backward compatibility with agents.conf v1 (5-col) and v2 (8-col)
- State persistence via simple pipe-delimited format
- Optional logger integration via `_orch_router_log`

### 2.2 What Works Well

- Empty lines and comments in config are handled correctly
- PM coordinator (interval=0) is properly excluded from eligible list
- Force override bypasses interval checks as intended, clears after update
- State save/load handles missing files and unknown agents gracefully
- Fail-retry (halve interval) and skip-backoff (double after 3 empties) logic is correct
- Backoff cap (`base * 4`) is properly enforced

### 2.3 Bugs Found

#### BUG-014: Duplicate dependencies inflate in-degree (HIGH)

**Found in:** `src/core/dynamic-router.sh` lines 134-145 (`orch_router_has_cycle`) and 205-216 (`orch_router_groups`)
**Severity:** HIGH
**Steps to reproduce:**
1. Create agents.conf with `depends_on=06-backend,06-backend` (duplicate dep)
2. Run `orch_router_init` then `orch_router_groups`
**Expected:** Duplicate deps are deduplicated; agent is in correct group
**Actual:** In-degree incremented twice per duplicate, pushing agent to a later execution group. Adjacency list also gets duplicate entries.
**Impact:** Incorrect group assignment — agent runs later than intended
**Fix:** Deduplicate dependency list after `IFS=',' read -ra dep_list` using `sort -u` or associative array check
**Assigned to:** 06-backend

#### BUG-015: No validation for non-numeric priority field (MEDIUM)

**Found in:** `src/core/dynamic-router.sh` line 91
**Severity:** MEDIUM
**Steps to reproduce:**
1. Set priority to "abc" in agents.conf v2 format
2. Run `orch_router_init` then `orch_router_groups`
**Expected:** Non-numeric priority defaults to 5 (like empty/none)
**Actual:** Non-numeric string stored as-is. `sort -rn` in `orch_router_groups` (line 234) treats it as 0, producing unpredictable ordering within a group.
**Impact:** Low in practice (all current configs use numeric priorities), but violates defensive coding principle
**Fix:** Add `[[ ! "$f_priority" =~ ^[0-9]+$ ]] && f_priority=5` after line 91
**Assigned to:** 06-backend

#### BUG-016: Silent ignore of dependencies on non-existent agents (MEDIUM)

**Found in:** `src/core/dynamic-router.sh` lines 139-145
**Severity:** MEDIUM
**Steps to reproduce:**
1. Set `depends_on=ghost-agent` where `ghost-agent` is not in agents.conf
2. Run `orch_router_init` then `orch_router_groups`
**Expected:** Warning logged; dependency treated as unmet or error raised
**Actual:** Dependency silently ignored. Agent treated as having no dependency on that agent.
**Impact:** Misconfigured configs could run agents before their intended dependencies complete, with no indication of the problem
**Fix:** Emit `_orch_router_log WARN "Agent $id depends on unknown agent: $dep"` when dependency not found
**Assigned to:** 06-backend

### 2.4 Notes (non-blocking)

**NOTE-001:** `sort -rn` in `orch_router_groups` (line 234) is not stable. Agents with identical priority may have non-deterministic ordering within a group across runs. Low impact — group membership is deterministic, only intra-group ordering varies.

**NOTE-002:** State file format uses `|` as delimiter. Agent IDs containing `|` would corrupt state. Not a practical concern — all agent IDs follow `NN-name` pattern — but worth documenting.

---

## 3. Known Bug Status

| Bug | Status | Notes |
|-----|--------|-------|
| BUG-013 | STILL OPEN | README line 72 says "Bash 4+" — should be "Bash 5+". Non-blocking, v0.1.1 item. |
| BUG-012 | STILL OPEN | 4 prompts missing PROTECTED FILES section: 01-ceo, 02-cto, 03-pm, 13-hr. v0.1.1 item. |
| QA-F001 | STILL OPEN | `auto-agent.sh` line 23: `set -uo pipefail` missing `-e` flag. v0.1.1 item. |
| BUG-014 | NEW | Duplicate deps inflate in-degree (dynamic-router.sh). See §2.3. |
| BUG-015 | NEW | Non-numeric priority not validated (dynamic-router.sh). See §2.3. |
| BUG-016 | NEW | Silent ignore of unknown agent deps (dynamic-router.sh). See §2.3. |

---

## 4. Integration Status

**auto-agent.sh sourcing (line 31):** Only 8 v0.1.0 modules sourced. The 3 v0.2.0 modules
(`dynamic-router`, `signal-handler`, `cycle-tracker`) are NOT yet sourced — expected, as
CS must integrate them into the protected file.

**Test coverage for v0.2.0:** 26 tests cover all 8 public functions. Coverage is good but
does NOT test the edge cases found in §2.3. Recommend adding tests for:
- Duplicate dependencies
- Non-numeric priority
- Unknown agent in depends_on

---

## 5. Verdict

**CONDITIONAL PASS** — `dynamic-router.sh` is functional and well-tested for the happy path.
The 3 new bugs (BUG-014 through BUG-016) are edge cases that don't affect current
agents.conf configurations, but should be fixed before CS integrates the module into
auto-agent.sh.

**Recommended action:**
1. 06-backend fixes BUG-014, BUG-015, BUG-016 (+ adds test cases)
2. QA re-reviews
3. Then CS integrates into auto-agent.sh

---

## 6. Test Inventory

| File | Tests | Status |
|------|-------|--------|
| test-agent-timeout.sh | unit | PASS |
| test-bash-version.sh | unit | PASS |
| test-config-validator.sh | unit | PASS |
| test-cycle-state.sh | unit | PASS |
| test-cycle-tracker.sh | unit | PASS |
| test-dry-run.sh | unit | PASS |
| test-dynamic-router.sh | 26 unit | PASS |
| test-error-handler.sh | unit | PASS |
| test-integration.sh | integration (42 assertions) | PASS |
| test-lock-file.sh | unit | PASS |
| test-logger.sh | unit | PASS |
| test-signal-handler.sh | unit | PASS |
