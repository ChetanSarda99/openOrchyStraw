# Benchmark Architecture Spec
**ADR:** BENCH-001
**Date:** 2026-03-20
**Author:** CTO (02-cto)
**Status:** APPROVED — Backend may implement immediately
**Implements:** #47 (SWE-bench harness scaffold)

---

## Purpose

Define the architecture for `scripts/benchmark/` so backend can build the harness without ambiguity. This spec covers directory layout, runner design, output format, and integration points with the existing orchestrator.

## Design Principles

1. **Bash-first runner** — consistent with zero-dep core philosophy
2. **Python only for SWE-bench harness glue** — required by SWE-bench's evaluation tooling
3. **Reproducible** — same inputs always produce same outputs (deterministic seeding)
4. **Incremental** — can resume interrupted runs, skip completed instances
5. **Cost-aware** — dry-run mode, instance limits, model selection

---

## Directory Layout

```
scripts/benchmark/
  run-benchmark.sh          # Main entry point — orchestrates everything
  lib/
    instance-runner.sh      # Runs one benchmark instance (clone, setup, cycle, capture diff)
    results-collector.sh    # Aggregates JSONL results into summary
    cost-estimator.sh       # Estimates cost before committing to a run
  swebench/
    scaffold.py             # Python wrapper: SWE-bench instance → Orchystraw cycle → prediction JSONL
    requirements.txt        # swebench, docker (pinned versions)
    README.md               # Setup instructions (Python 3.11+, Docker)
  custom/
    tasks.jsonl             # Custom multi-file tasks for head-to-head (Ralph vs Orchystraw)
    ralph-baseline.sh       # Ralph-loop runner for comparison
  results/                  # Gitignored — raw output
    .gitkeep
  reports/                  # Committed — summary reports
    .gitkeep
```

## Runner Architecture

### `run-benchmark.sh` — Main entry point

```
Usage: ./scripts/benchmark/run-benchmark.sh [OPTIONS]
  --suite <swebench-lite|swebench|custom|featurebench>   (required)
  --limit <N>              Max instances to run (default: 10)
  --model <sonnet|opus>    Model for agents (default: sonnet)
  --agents <N>             Number of agents per instance (default: 3)
  --max-cycles <N>         Max orchestrator cycles per instance (default: 5)
  --resume                 Skip instances with existing results
  --dry-run                Estimate cost and exit
  --output <dir>           Results directory (default: scripts/benchmark/results/)
```

**Flow:**
1. Validate prerequisites (bash 5.0+, docker for swebench, python for swebench)
2. Load instance list for chosen suite
3. If `--dry-run`: run cost-estimator.sh, print estimate, exit
4. For each instance (up to `--limit`):
   a. If `--resume` and result exists: skip
   b. Call `instance-runner.sh` with instance config
   c. Append result to `results/<suite>-<timestamp>.jsonl`
5. Call `results-collector.sh` to generate summary report

### `instance-runner.sh` — Single instance execution

**Input:** Instance JSON (id, repo_url, commit, issue_text, test_command)
**Output:** Result JSON to stdout

**Flow:**
1. Create temp workspace: `/tmp/orchystraw-bench-<instance_id>/`
2. Clone repo at specified commit
3. Generate minimal Orchystraw config:
   - `agents.conf` with N agents (backend, QA, PM)
   - Prompt files derived from issue_text
   - Shared context initialized with repo structure
4. Run `auto-agent.sh` for up to `--max-cycles` cycles
5. Capture `git diff` as the prediction patch
6. Run test command to check if patch resolves the issue
7. Emit result JSON:
```json
{
  "instance_id": "django__django-12345",
  "resolved": true,
  "cycles": 3,
  "tokens_used": 45000,
  "wall_time_seconds": 180,
  "patch": "diff --git a/...",
  "test_passed": true,
  "rogue_writes": 0,
  "regressions": 0
}
```
8. Clean up temp workspace (unless `--keep-workspaces` flag)

### `swebench/scaffold.py` — SWE-bench glue

This is the **only Python file** in the benchmark system. It exists because SWE-bench's evaluation harness is Python-native.

**Responsibilities:**
- Parse SWE-bench instance format → extract fields for instance-runner.sh
- Call instance-runner.sh via subprocess
- Collect predictions into SWE-bench's expected JSONL format
- Invoke SWE-bench's evaluation harness

```python
# Minimal interface — implementation details for backend
def run_orchystraw_on_instance(instance: dict, config: dict) -> dict:
    """Calls instance-runner.sh, returns prediction dict."""
    ...

def main():
    """CLI entry: loads instances, runs orchestrator, writes predictions.jsonl"""
    ...
```

### `custom/ralph-baseline.sh` — Comparison runner

Runs the same custom tasks using a single-agent Ralph-style loop for apples-to-apples comparison:

```bash
# For each task in tasks.jsonl:
#   1. Clone repo
#   2. Single claude invocation with full issue context
#   3. Capture diff
#   4. Run tests
#   5. Emit same result JSON format as instance-runner.sh
```

---

## Output Format

### Per-instance result (JSONL, one line per instance)
```json
{"instance_id":"...","resolved":true,"cycles":3,"tokens_used":45000,"wall_time_seconds":180,"patch":"...","test_passed":true,"rogue_writes":0,"regressions":0,"model":"sonnet","agents":3}
```

### Summary report (Markdown, generated by results-collector.sh)
```markdown
# Benchmark Report — <suite> — <date>
| Metric | Value |
|--------|-------|
| Instances run | 10 |
| Resolve rate | 60% |
| Avg cycles | 3.2 |
| Avg tokens | 42,000 |
| Avg wall time | 165s |
| Total cost est | $8.50 |
| Rogue write rate | 0% |
| Regression rate | 5% |
```

---

## Integration Points

| Orchystraw Component | How Benchmark Uses It |
|---------------------|----------------------|
| `auto-agent.sh` | Called by instance-runner.sh for each benchmark instance |
| `agents.conf` | Generated per-instance with appropriate agent count |
| `src/core/*.sh` modules | Used via auto-agent.sh — no direct calls |
| `prompts/` structure | Minimal prompts generated from issue text |
| File ownership | Enforced per normal — benchmark measures rogue write rate |

**Key constraint:** The benchmark harness must NOT modify auto-agent.sh or any core module. It calls them as a black box. This ensures we're benchmarking the real system, not a test double.

---

## Custom Task Format (`tasks.jsonl`)

```json
{
  "id": "custom-001",
  "name": "Add REST endpoint + tests + docs",
  "category": "multi-file-feature",
  "repo_url": "https://github.com/...",
  "commit": "abc123",
  "issue_text": "Add a POST /api/notes/batch endpoint that...",
  "test_command": "pytest tests/ -x",
  "expected_files_changed": ["app/routes.py", "tests/test_routes.py", "docs/api.md"],
  "difficulty": "medium"
}
```

Categories: `single-file-bugfix`, `multi-file-feature`, `large-codebase-nav`, `marathon`

---

## Cost Controls

1. **`--dry-run`** always available — estimates cost before spending
2. **`--limit 10`** default — never accidentally run 300 instances
3. **Model default is Sonnet** — Opus requires explicit `--model opus`
4. **Instance timeout** — 10 minutes per instance default, configurable
5. **Cost log** — append estimated cost per instance to results, running total in summary

---

## Implementation Order (for Backend)

1. **`run-benchmark.sh`** + `lib/cost-estimator.sh` — skeleton with `--dry-run`
2. **`lib/instance-runner.sh`** — single instance end-to-end with custom task
3. **`custom/tasks.jsonl`** — 5 initial custom tasks (from BENCHMARKING-PLAN.md Phase 1)
4. **`custom/ralph-baseline.sh`** — comparison runner
5. **`lib/results-collector.sh`** — aggregation + markdown report
6. **`swebench/scaffold.py`** — SWE-bench integration (Phase 2, can defer)

Steps 1-5 are pure bash. Step 6 is the only Python. Backend should ship 1-5 first, get custom benchmark results, then tackle SWE-bench integration.

---

## Test Strategy

- `tests/benchmark/test-cost-estimator.sh` — unit test for cost math
- `tests/benchmark/test-instance-runner.sh` — mock a simple instance, verify output format
- `tests/benchmark/test-results-collector.sh` — verify aggregation from sample JSONL
- Integration test: run 1 custom task end-to-end (slow, CI-optional)

---

## What This Spec Does NOT Cover

- FeatureBench integration — deferred to Phase 3 (same scaffold pattern, different instance format)
- Leaderboard submission mechanics — deferred to Phase 4
- CI integration — future work, after local runs prove the harness works
- Cost optimization (caching, prompt sharing between instances) — v2 concern

---

*Approved by CTO. Backend: build to this spec. Start with custom tasks (Steps 1-5), defer SWE-bench Python scaffold to Phase 2.*
