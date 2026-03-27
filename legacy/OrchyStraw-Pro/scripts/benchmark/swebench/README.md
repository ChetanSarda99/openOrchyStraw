# OrchyStraw SWE-bench Scaffold

Python glue that bridges SWE-bench's evaluation tooling with OrchyStraw's bash benchmark harness. This is the only Python component in the benchmark system (BENCH-001, Step 6).

## Prerequisites

- Python 3.9+
- `bash`, `git`, `jq` on PATH
- The rest of the benchmark harness (Steps 1-5) must be in place:
  - `scripts/benchmark/lib/instance-runner.sh`
  - `scripts/benchmark/lib/cost-estimator.sh`
  - `scripts/benchmark/lib/results-collector.sh`
  - `scripts/benchmark/run-benchmark.sh`

No pip dependencies are required for basic operation (local tasks, dry-run). The `swebench` and `datasets` packages are only needed for loading HuggingFace datasets and running SWE-bench's own evaluation harness.

## Quick start

```bash
# Dry-run with local task files (no dependencies needed)
python3 scripts/benchmark/swebench/scaffold.py --dry-run --limit 3

# Run 5 local tasks with sonnet
python3 scripts/benchmark/swebench/scaffold.py --tasks-dir scripts/benchmark/tasks/ --limit 5 --model sonnet

# Run against SWE-bench Lite (requires: pip install swebench datasets)
python3 scripts/benchmark/swebench/scaffold.py --dataset swebench_lite --limit 5 --model sonnet

# Evaluate existing predictions (requires: pip install swebench)
python3 scripts/benchmark/swebench/scaffold.py --evaluate scripts/benchmark/results/swebench-predictions-20260320-120000.jsonl
```

## CLI reference

```
python3 scaffold.py [OPTIONS]

Data source (pick one):
  --dataset NAME         Load from HuggingFace: swebench_lite, swebench, swebench_verified
  --tasks-dir DIR        Load from local JSON files in a directory
  --tasks-jsonl FILE     Load from a JSONL file
  --evaluate FILE        Run SWE-bench evaluation on existing predictions JSONL
  (default)              Loads from scripts/benchmark/tasks/

Run options:
  --limit N              Max instances to process (0 = all)
  --model NAME           Model for agent runs (default: sonnet)
  --max-cycles N         Max orchestrator cycles per instance (default: 5)
  --timeout SECS         Timeout per instance in seconds (default: 600)
  --workspace DIR        Base directory for cloned repos

Modes:
  --dry-run              Validate and show plan without running
  --verbose              Enable debug logging
```

## Output files

All output goes to `scripts/benchmark/results/` and `scripts/benchmark/reports/`:

| File | Format | Description |
|------|--------|-------------|
| `swebench-predictions-<timestamp>.jsonl` | JSONL | SWE-bench prediction format: `{"instance_id", "model_patch", "model_name_or_path"}` |
| `swebench-results-<timestamp>.jsonl` | JSONL | Full results from instance-runner.sh |
| `swebench-<date>.md` | Markdown | Human-readable summary report |

## How it works

1. **Load instances** from SWE-bench dataset, local JSON files, or JSONL
2. **Validate** repo URLs against the security regex (matches instance-runner.sh)
3. **For each instance**, write a temporary JSON file and invoke `instance-runner.sh` via subprocess
4. **Collect patches** (git diff from each workspace) into SWE-bench's expected JSONL format
5. **Write results** and generate a markdown report
6. **Optionally evaluate** using SWE-bench's harness (if package installed)

## Installing swebench (optional)

```bash
pip install swebench datasets
```

This is only needed for:
- `--dataset` flag (loading from HuggingFace)
- `--evaluate` flag (running SWE-bench's evaluation harness)

Local task files (`--tasks-dir`, `--tasks-jsonl`) work with zero pip dependencies.

## Task JSON format

Local task files should match this structure (same as SWE-bench):

```json
{
  "instance_id": "django__django-11099",
  "repo": "django/django",
  "base_commit": "17455e924e243e7a55e8a38f45966d3fce1e0b5a",
  "problem_statement": "Description of the issue...",
  "test_patch": "",
  "gold_patch": "diff --git a/..."
}
```

Fields `repo_url`, `commit`, `issue_text` are accepted as aliases for compatibility.
