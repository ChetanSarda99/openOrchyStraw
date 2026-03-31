# CTO Proposals Inbox

_Workers append proposals here. CTO evaluates and writes decisions._
_See docs/KNOWLEDGE-REPOSITORIES.md for proposal format._

---

## Pending Proposals

### [PROPOSAL] 2026-03-30 | 06-backend | Benchmark Runner Architecture (BENCH-001)
**Problem:** Need benchmark harness to evaluate OrchyStraw vs single-agent (Ralph) on SWE-bench + custom tasks.
**Options:**
- Option A: Custom bash harness + Python SWE-bench glue — already designed as BENCH-001 in Pro repo, ported to public repo. Bash-first, zero pip deps for custom tasks, optional `swebench` package for leaderboard evaluation.
- Option B: Pure Python harness — easier HuggingFace integration but breaks no-external-deps policy for core.
- Option C: Use existing SWE-bench CLI directly — limited to their format, no OrchyStraw-specific metrics (rogue writes, multi-agent comparison).
**Recommendation:** Option A — already implemented and validated. Bash for orchestration (consistent with core), Python only as thin SWE-bench bridge. Scaffold ported to `scripts/benchmark/` with dry-run verified.

---

## Processed Proposals

_(CTO moves resolved proposals here with decision reference)_

