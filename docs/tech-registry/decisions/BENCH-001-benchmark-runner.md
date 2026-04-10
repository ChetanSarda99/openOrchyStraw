# ADR: BENCH-001 — Benchmark Runner Architecture

_Date: 2026-04-10 (cycle 1)_
_Status: **APPROVED**_
_Author: CTO (02-cto)_
_Proposer: 06-backend_

---

## Context

OrchyStraw needs a benchmark harness to produce defensible performance claims
(vs single-agent baselines like Ralph, vs SWE-bench leaderboard). This is a
launch blocker for the HN / community launch — we cannot credibly claim
"multi-agent wins" without reproducible numbers.

The harness must measure three distinct dimensions:

1. **Task success rate** — did the patch pass hidden tests? (SWE-bench)
2. **OrchyStraw-specific metrics** — commits-per-cycle, rogue writes outside
   ownership, cost per resolved task, multi-agent coordination overhead.
3. **Comparative baselines** — Ralph (single prompt loop), stock Claude Code,
   OrchyStraw with/without smart routing.

### Options considered

**Option A — Custom bash harness + thin Python SWE-bench bridge** (proposer's recommendation)
- `scripts/benchmark/` — bash orchestration for instance runs, cost estimation,
  results collection. Python only as a thin wrapper over the `swebench`
  evaluator (hidden test runner lives in their repo).
- Pros: Consistent with EFFICIENCY-001 (scripts do mechanical work). Zero deps
  for `custom/` tasks (Ralph comparison, featurebench). SWE-bench remains
  optional — users who only want the Ralph comparison never touch Python.
- Cons: Two languages in one subtree. Maintainers of `swebench/scaffold.py`
  need minimal Python literacy.

**Option B — Pure Python harness**
- Rewrite everything in Python, use HuggingFace datasets directly.
- Pros: Single language. Better integration with SWE-bench ecosystem.
- Cons: Violates no-deps policy for the core orchestrator touchpoint. Forces
  every benchmark user to install Python + pip deps even for the simple Ralph
  comparison. Python installed in `scripts/` crosses the bash/python boundary
  we've deliberately kept clean.

**Option C — Use SWE-bench CLI directly**
- Defer to upstream tooling, emit nothing of our own.
- Pros: Zero maintenance burden.
- Cons: No rogue-write detection, no cost/cycle metrics, no Ralph comparison,
  no OrchyStraw-specific claims possible. Defeats the purpose.

## Decision

**Approved: Option A — custom bash harness with optional Python SWE-bench bridge.**

### Rationale

1. **Scope matches architecture.** `scripts/benchmark/` is a *tool* that runs
   alongside OrchyStraw, not part of the core runtime. EFFICIENCY-001
   (script-first) and the no-deps policy both apply to the core orchestrator.
   A benchmark tool that optionally calls Python is not a core dependency —
   `orchystraw run` never imports Python.
2. **Graceful degradation.** Users without Python still get the custom
   benchmark suite (Ralph comparison, featurebench tasks, cost metrics).
   SWE-bench leaderboard runs require `pip install swebench`, which is
   reasonable for anyone submitting to the leaderboard anyway.
3. **Already validated.** Scaffold is ported to `scripts/benchmark/` with
   dry-run verified (per cycle 4 bug sweep — BUG-020/021/022/023 all fixed).
   Rewriting it loses working code for no architectural gain.
4. **Metrics separation.** `lib/cost-estimator.sh`, `lib/instance-runner.sh`,
   `lib/results-collector.sh` are pure bash — they compose with custom tasks
   AND SWE-bench runs identically. The Python bridge only touches the
   leaderboard-specific evaluator call.

## Constraints

The following boundaries are enforced and will be checked during future reviews:

1. **No Python in `scripts/benchmark/lib/`.** Shared library code stays bash.
   Python is permitted only under `scripts/benchmark/swebench/`.
2. **No pip deps in the top-level `orchystraw` CLI.** `orchystraw benchmark`
   must work without Python installed as long as the target is `custom/` or
   `ralph/`. SWE-bench runs may fail-fast with a clear install message.
3. **All benchmark output goes to `.orchystraw/benchmarks/<run-id>/`.**
   Do not pollute the project root. Results are JSONL so `orchystraw metrics`
   can consume them without parsing.
4. **Rogue-write detection must be in bash** — it's a file-ownership check
   and file ownership is a core concept (OWN-001). Do not delegate to Python.
5. **No network calls during `--dry-run`.** Dry-run must be offline-safe so
   it can live in CI.

## Metrics to Emit

Every benchmark run must produce, per instance, at minimum:

```json
{
  "run_id": "...",
  "suite": "swebench|ralph|featurebench",
  "instance_id": "...",
  "success": true,
  "cycles_used": 3,
  "commits_total": 7,
  "rogue_writes": 0,
  "tokens_input": 45231,
  "tokens_output": 8420,
  "cost_usd": 0.42,
  "wall_time_sec": 180,
  "model_tier_mix": {"haiku": 2, "sonnet": 4, "opus": 1}
}
```

`results-collector.sh` is the single writer. Any new metric goes through it
so downstream consumers (`orchystraw metrics`, dashboard) get one schema.

## Consequences

**Positive:**
- Ralph comparison + featurebench runs in pure bash, zero install friction.
- SWE-bench leaderboard submission path exists when we want a public number.
- Cost/rogue-write/cycle metrics are OrchyStraw-native, not adapted from
  SWE-bench's narrower schema.

**Negative:**
- Two languages in `scripts/benchmark/` — reviewers must be comfortable with
  both. Mitigated by strict isolation (constraint #1).
- Python bridge is a long-tail maintenance item whenever SWE-bench changes
  their evaluator API. Acceptable — it's a thin wrapper.

**Neutral:**
- We don't inherit SWE-bench's leaderboard ranking for free; we publish our
  own custom tasks separately. This is fine — custom tasks are where
  multi-agent wins are most visible anyway.

## Implementation Status

- ✅ `scripts/benchmark/run-benchmark.sh` — main runner
- ✅ `scripts/benchmark/run-comparison.sh` — OrchyStraw vs Ralph
- ✅ `scripts/benchmark/run-cross-project.sh` — cross-project suite
- ✅ `scripts/benchmark/run-orchestration-bench.sh` — orchestration overhead
- ✅ `scripts/benchmark/lib/{cost-estimator,instance-runner,results-collector}.sh`
- ✅ `scripts/benchmark/custom/{featurebench,ralph-baseline,compare-ralph}.sh`
- ✅ `scripts/benchmark/swebench/scaffold.py` — SWE-bench bridge
- ✅ BUG-020/021/022/023 fixed (cycle 4 hardening)
- ⏳ Dry-run results under `.orchystraw/benchmarks/` — need first real run
- ⏳ `orchystraw benchmark --all` CLI surface — verify wires to this harness

## Follow-ups

1. **06-backend:** Publish first real `--dry-run` output so CTO can verify the
   emitted JSONL schema matches the spec above.
2. **06-backend:** Confirm `orchystraw benchmark` CLI subcommand routes to
   `scripts/benchmark/run-benchmark.sh` (not a parallel implementation).
3. **09-qa:** Add a smoke test that runs one `featurebench` instance end-to-end
   in CI (Python-free path).
4. **01-ceo / 03-pm:** Once first numbers land, decide which subset to publish
   at launch. Raw numbers before the narrative.

## References

- `docs/tech-registry/proposals.md` — originating proposal
- `docs/tech-registry/decisions/EFFICIENCY-001-script-first.md` — architecture principle
- `scripts/benchmark/` — implementation
- BUG-020/021/022/023 — prior security hardening of this scaffold
