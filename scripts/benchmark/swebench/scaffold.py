#!/usr/bin/env python3
"""
OrchyStraw — SWE-bench Scaffold (BENCH-001, Step 6)

Bridges SWE-bench's Python evaluation tooling with the bash benchmark harness.
This is the ONLY Python component in the benchmark system.

Usage:
    python3 scaffold.py --dataset swebench_lite --limit 5 --model sonnet
    python3 scaffold.py --tasks-dir ./scripts/benchmark/tasks/ --limit 3
    python3 scaffold.py --dry-run --dataset swebench_lite --limit 10
    python3 scaffold.py --evaluate predictions.jsonl

Requires: Python 3.9+, no pip dependencies (swebench is optional).
"""

from __future__ import annotations

import argparse
import datetime
import json
import logging
import os
import re
import subprocess
import sys
import tempfile
import time

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
BENCH_DIR = SCRIPT_DIR.parent
PROJECT_ROOT = BENCH_DIR.parent.parent
LIB_DIR = BENCH_DIR / "lib"
TASKS_DIR = BENCH_DIR / "tasks"
RESULTS_DIR = BENCH_DIR / "results"
REPORTS_DIR = BENCH_DIR / "reports"

INSTANCE_RUNNER = LIB_DIR / "instance-runner.sh"

REPO_URL_REGEX = re.compile(
    r"^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(\.git)?$"
)

MODEL_NAME = "orchystraw"

LOG_FORMAT = "[scaffold] %(asctime)s  %(message)s"
LOG_DATEFMT = "%H:%M:%S"

logger = logging.getLogger("scaffold")

_swebench_available = False
try:
    from swebench.harness.run_evaluation import main as swebench_evaluate  # type: ignore
    from datasets import load_dataset  # type: ignore

    _swebench_available = True
except ImportError:
    pass


def _timestamp() -> str:
    return datetime.datetime.utcnow().strftime("%Y%m%d-%H%M%S")


def _date_stamp() -> str:
    return datetime.datetime.utcnow().strftime("%Y-%m-%d")


def _validate_repo_url(url: str) -> bool:
    return bool(REPO_URL_REGEX.match(url))


def _normalize_repo_url(instance: Dict[str, Any]) -> str:
    url = instance.get("repo_url", "")
    if url:
        return url
    repo = instance.get("repo", "")
    if repo:
        url = "https://github.com/{}.git".format(repo)
        return url
    return ""


def _instance_to_runner_json(instance: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "instance_id": instance.get("instance_id", instance.get("id", "")),
        "repo_url": _normalize_repo_url(instance),
        "base_commit": instance.get("base_commit", instance.get("commit", "")),
        "problem_statement": instance.get(
            "problem_statement", instance.get("issue_text", "")
        ),
        "test_command": instance.get("test_command", ""),
        "gold_patch": instance.get("gold_patch", instance.get("patch", "")),
        "expected_files_changed": instance.get("expected_files_changed", []),
    }


def load_from_swebench(dataset_name: str, limit: int) -> List[Dict[str, Any]]:
    if not _swebench_available:
        logger.error(
            "swebench package not installed. "
            "Install with: pip install swebench datasets\n"
            "Or use --tasks-dir to load from local JSON files."
        )
        sys.exit(1)

    logger.info("Loading dataset '%s' via HuggingFace...", dataset_name)

    dataset_map = {
        "swebench_lite": "princeton-nlp/SWE-bench_Lite",
        "swebench": "princeton-nlp/SWE-bench",
        "swebench_verified": "princeton-nlp/SWE-bench_Verified",
    }
    hf_name = dataset_map.get(dataset_name, dataset_name)

    ds = load_dataset(hf_name, split="test")
    instances = []
    for i, row in enumerate(ds):
        if limit > 0 and i >= limit:
            break
        instances.append(dict(row))

    logger.info("Loaded %d instance(s) from %s", len(instances), hf_name)
    return instances


def load_from_tasks_dir(tasks_dir: Path, limit: int) -> List[Dict[str, Any]]:
    if not tasks_dir.is_dir():
        logger.error("Tasks directory not found: %s", tasks_dir)
        sys.exit(1)

    json_files = sorted(tasks_dir.glob("*.json"))
    if not json_files:
        logger.error("No .json files found in %s", tasks_dir)
        sys.exit(1)

    instances = []
    for jf in json_files:
        if limit > 0 and len(instances) >= limit:
            break
        try:
            with open(jf, "r") as f:
                data = json.load(f)
            iid = data.get("instance_id", data.get("id", ""))
            if not iid:
                logger.warning("Skipping %s: no instance_id", jf.name)
                continue
            instances.append(data)
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Skipping %s: %s", jf.name, exc)

    logger.info("Loaded %d instance(s) from %s", len(instances), tasks_dir)
    return instances


def load_from_jsonl(jsonl_path: Path, limit: int) -> List[Dict[str, Any]]:
    if not jsonl_path.is_file():
        logger.error("JSONL file not found: %s", jsonl_path)
        sys.exit(1)

    instances = []
    with open(jsonl_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if limit > 0 and len(instances) >= limit:
                break
            try:
                instances.append(json.loads(line))
            except json.JSONDecodeError as exc:
                logger.warning("Skipping malformed line: %s", exc)

    logger.info("Loaded %d instance(s) from %s", len(instances), jsonl_path)
    return instances


def run_instance(
    instance: Dict[str, Any],
    workspace_base: str,
    model: str,
    max_cycles: int,
    timeout: int,
) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    runner_json = _instance_to_runner_json(instance)
    instance_id = runner_json["instance_id"]
    repo_url = runner_json["repo_url"]

    if not _validate_repo_url(repo_url):
        logger.error(
            "SECURITY: invalid repo URL for %s: '%s' — skipping",
            instance_id,
            repo_url,
        )
        return None, None

    if not INSTANCE_RUNNER.is_file():
        logger.error("instance-runner.sh not found: %s", INSTANCE_RUNNER)
        sys.exit(1)

    tmp_fd, tmp_path = tempfile.mkstemp(
        prefix="orchystraw-instance-", suffix=".json"
    )
    try:
        with os.fdopen(tmp_fd, "w") as tmp_f:
            json.dump(runner_json, tmp_f)

        cmd = [
            "bash",
            str(INSTANCE_RUNNER),
            tmp_path,
            workspace_base,
            model,
            str(max_cycles),
            str(timeout),
        ]

        logger.info("Running instance %s (model=%s, timeout=%ds)", instance_id, model, timeout)

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout + 60,
        )

        if proc.returncode != 0:
            logger.warning(
                "instance-runner.sh returned %d for %s: %s",
                proc.returncode,
                instance_id,
                proc.stderr.strip()[-200:] if proc.stderr else "(no stderr)",
            )

        stdout = proc.stdout.strip()
        if not stdout:
            logger.warning("No output from instance-runner.sh for %s", instance_id)
            return None, None

        result = json.loads(stdout)
        patch = _extract_patch(workspace_base, instance_id)

        return result, patch

    except subprocess.TimeoutExpired:
        logger.error("Timeout expired for %s", instance_id)
        return None, None
    except json.JSONDecodeError as exc:
        logger.error("Failed to parse runner output for %s: %s", instance_id, exc)
        return None, None
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def _extract_patch(workspace_base: str, instance_id: str) -> str:
    workspace = os.path.join(workspace_base, instance_id)
    if not os.path.isdir(workspace):
        return ""
    try:
        proc = subprocess.run(
            ["git", "diff"],
            capture_output=True,
            text=True,
            cwd=workspace,
            timeout=30,
        )
        return proc.stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        return ""


def write_predictions(
    predictions: List[Dict[str, Any]], output_path: Path
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for pred in predictions:
            line = json.dumps(pred, ensure_ascii=False)
            f.write(line + "\n")
    logger.info("Predictions written to %s (%d entries)", output_path, len(predictions))


def write_results(
    results: List[Dict[str, Any]], output_path: Path
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for result in results:
            line = json.dumps(result, ensure_ascii=False)
            f.write(line + "\n")
    logger.info("Results written to %s (%d entries)", output_path, len(results))


def generate_report(
    predictions: List[Dict[str, Any]],
    results: List[Dict[str, Any]],
    suite: str,
    model: str,
    output_path: Path,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    total = len(results)
    resolved = sum(1 for r in results if r.get("resolved", False))
    failed = sum(
        1 for r in results if r.get("status") in ("fail", "no_changes")
    )
    errors = total - resolved - failed
    patches_produced = sum(1 for p in predictions if p.get("model_patch", ""))
    avg_time = (
        sum(r.get("wall_time_seconds", 0) for r in results) / total
        if total > 0
        else 0
    )
    resolve_rate = round(resolved / total * 100, 1) if total > 0 else 0.0

    lines = [
        "# SWE-bench Report -- {} -- {}".format(suite, _date_stamp()),
        "",
        "| Metric | Value |",
        "|--------|-------|",
        "| Suite | {} |".format(suite),
        "| Model | {} |".format(model),
        "| Instances run | {} |".format(total),
        "| Patches produced | {} |".format(patches_produced),
        "| Resolved (tests pass) | {} |".format(resolved),
        "| Failed | {} |".format(failed),
        "| Errors | {} |".format(errors),
        "| Resolve rate | {}% |".format(resolve_rate),
        "| Avg wall time | {:.1f}s |".format(avg_time),
        "",
        "## Per-Instance Results",
        "",
        "| Instance | Status | Time(s) | Patch | Match |",
        "|----------|--------|---------|-------|-------|",
    ]

    for r in results:
        iid = r.get("instance_id", "?")
        status = r.get("status", "?")
        wtime = r.get("wall_time_seconds", 0)
        has_patch = "yes" if r.get("diff_length", 0) > 0 else "no"
        pmatch = r.get("patch_match", 0)
        lines.append(
            "| {} | {} | {} | {} | {} |".format(iid, status, wtime, has_patch, pmatch)
        )

    lines.append("")
    lines.append("---")
    lines.append("*Generated by OrchyStraw benchmark harness (scaffold.py)*")
    lines.append("")

    with open(output_path, "w") as f:
        f.write("\n".join(lines))

    logger.info("Report written to %s", output_path)


def evaluate_predictions(predictions_path: Path) -> None:
    if not _swebench_available:
        logger.error(
            "swebench package not installed. Cannot run --evaluate.\n"
            "Install with: pip install swebench"
        )
        sys.exit(1)

    if not predictions_path.is_file():
        logger.error("Predictions file not found: %s", predictions_path)
        sys.exit(1)

    logger.info("Running SWE-bench evaluation on %s...", predictions_path)

    cmd = [
        sys.executable,
        "-m",
        "swebench.harness.run_evaluation",
        "--predictions_path",
        str(predictions_path),
        "--swe_bench_tasks",
        "princeton-nlp/SWE-bench_Lite",
        "--log_dir",
        str(RESULTS_DIR / "swebench-eval-logs"),
        "--testbed",
        str(Path(tempfile.gettempdir()) / "swebench-testbed"),
        "--verbose",
    ]

    logger.info("Command: %s", " ".join(cmd))

    try:
        proc = subprocess.run(cmd, timeout=3600)
        if proc.returncode == 0:
            logger.info("SWE-bench evaluation completed successfully.")
        else:
            logger.error(
                "SWE-bench evaluation failed with exit code %d", proc.returncode
            )
            sys.exit(1)
    except subprocess.TimeoutExpired:
        logger.error("SWE-bench evaluation timed out (1h limit).")
        sys.exit(1)
    except FileNotFoundError:
        logger.error("Failed to invoke swebench evaluation module.")
        sys.exit(1)


def dry_run(instances: List[Dict[str, Any]], model: str) -> None:
    logger.info("DRY RUN: %d instance(s)", len(instances))
    print()

    valid = 0
    invalid = 0

    for inst in instances:
        runner_json = _instance_to_runner_json(inst)
        iid = runner_json["instance_id"]
        repo_url = runner_json["repo_url"]
        commit = runner_json["base_commit"]
        problem = runner_json["problem_statement"]

        url_ok = _validate_repo_url(repo_url)
        has_problem = bool(problem.strip())
        has_commit = bool(commit.strip())

        status_parts = []
        if not url_ok:
            status_parts.append("INVALID URL")
        if not has_problem:
            status_parts.append("NO PROBLEM STATEMENT")
        if not has_commit:
            status_parts.append("NO COMMIT")
        status = ", ".join(status_parts) if status_parts else "OK"

        if status_parts:
            invalid += 1
        else:
            valid += 1

        problem_preview = problem.replace("\n", " ").strip()
        if len(problem_preview) > 80:
            problem_preview = problem_preview[:77] + "..."

        print("  {:40s}  {:10s}  {}".format(iid[:40], commit[:10] if commit else "?", status))
        print("    repo:    {}".format(repo_url))
        print("    problem: {}".format(problem_preview))
        print("    would:   clone -> checkout {} -> run agent (model={}) -> collect patch".format(
            commit[:10] if commit else "?", model
        ))
        print()

    print("---")
    print("Valid: {}  Invalid: {}  Total: {}".format(valid, invalid, len(instances)))
    print()


def run_benchmark(
    instances: List[Dict[str, Any]],
    model: str,
    max_cycles: int,
    timeout: int,
    workspace_base: Optional[str] = None,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    if workspace_base is None:
        workspace_base = os.path.join(
            tempfile.gettempdir(), "orchystraw-bench-{}".format(os.getpid())
        )

    ts = _timestamp()
    predictions_path = RESULTS_DIR / "swebench-predictions-{}.jsonl".format(ts)
    results_path = RESULTS_DIR / "swebench-results-{}.jsonl".format(ts)
    report_path = REPORTS_DIR / "swebench-{}.md".format(_date_stamp())

    predictions: List[Dict[str, Any]] = []
    results: List[Dict[str, Any]] = []

    total = len(instances)
    logger.info("Starting benchmark: %d instance(s), model=%s, cycles=%d, timeout=%ds",
                total, model, max_cycles, timeout)

    for idx, instance in enumerate(instances, 1):
        runner_json = _instance_to_runner_json(instance)
        iid = runner_json["instance_id"]

        logger.info("[%d/%d] %s", idx, total, iid)

        result, patch = run_instance(
            instance, workspace_base, model, max_cycles, timeout
        )

        prediction = {
            "instance_id": iid,
            "model_patch": patch or "",
            "model_name_or_path": MODEL_NAME,
        }
        predictions.append(prediction)

        if result is not None:
            results.append(result)
        else:
            results.append({
                "instance_id": iid,
                "resolved": False,
                "status": "error",
                "agent_exit_code": -1,
                "cycles": 0,
                "wall_time_seconds": 0,
                "test_passed": False,
                "patch_match": 0,
                "rogue_writes": 0,
                "model": model,
                "agents": 1,
                "timestamp": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "diff_length": 0,
            })

    write_predictions(predictions, predictions_path)
    write_results(results, results_path)
    generate_report(predictions, results, "swebench", model, report_path)

    resolved = sum(1 for r in results if r.get("resolved", False))
    patches = sum(1 for p in predictions if p.get("model_patch", ""))
    rate = round(resolved / total * 100, 1) if total > 0 else 0.0

    print()
    print("=" * 60)
    print("  SWE-bench Benchmark Complete")
    print("=" * 60)
    print("  Instances:        {}".format(total))
    print("  Patches produced: {}".format(patches))
    print("  Resolved:         {}".format(resolved))
    print("  Resolve rate:     {}%".format(rate))
    print()
    print("  Predictions: {}".format(predictions_path))
    print("  Results:     {}".format(results_path))
    print("  Report:      {}".format(report_path))
    print("=" * 60)
    print()

    return predictions, results


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="OrchyStraw SWE-bench scaffold -- bridges SWE-bench with the bash benchmark harness.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Examples:
  %(prog)s --dataset swebench_lite --limit 5 --model sonnet
  %(prog)s --tasks-dir ./scripts/benchmark/tasks/ --limit 3
  %(prog)s --dry-run --dataset swebench_lite --limit 10
  %(prog)s --evaluate predictions.jsonl
""",
    )

    source = parser.add_mutually_exclusive_group()
    source.add_argument(
        "--dataset",
        type=str,
        choices=["swebench_lite", "swebench", "swebench_verified"],
        help="SWE-bench dataset to load (requires swebench + datasets packages)",
    )
    source.add_argument(
        "--tasks-dir",
        type=str,
        help="Directory containing local task JSON files (default: scripts/benchmark/tasks/)",
    )
    source.add_argument(
        "--tasks-jsonl",
        type=str,
        help="JSONL file containing task instances",
    )
    source.add_argument(
        "--evaluate",
        type=str,
        metavar="PREDICTIONS_JSONL",
        help="Run SWE-bench evaluation on an existing predictions file",
    )

    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Maximum number of instances to process (0 = all, default: 0)",
    )
    parser.add_argument(
        "--model",
        type=str,
        default="sonnet",
        help="Model to use for agent runs (default: sonnet)",
    )
    parser.add_argument(
        "--max-cycles",
        type=int,
        default=5,
        help="Maximum orchestrator cycles per instance (default: 5)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        help="Timeout per instance in seconds (default: 600)",
    )
    parser.add_argument(
        "--workspace",
        type=str,
        default=None,
        help="Base directory for workspaces (default: /tmp/orchystraw-bench-<pid>)",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate instances and show plan without running",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(format=LOG_FORMAT, datefmt=LOG_DATEFMT, level=level)

    if args.evaluate:
        evaluate_predictions(Path(args.evaluate))
        return

    if args.dataset:
        instances = load_from_swebench(args.dataset, args.limit)
    elif args.tasks_jsonl:
        instances = load_from_jsonl(Path(args.tasks_jsonl), args.limit)
    elif args.tasks_dir:
        instances = load_from_tasks_dir(Path(args.tasks_dir), args.limit)
    else:
        instances = load_from_tasks_dir(TASKS_DIR, args.limit)

    if not instances:
        logger.error("No instances loaded. Check your data source.")
        sys.exit(1)

    if args.dry_run:
        dry_run(instances, args.model)
        return

    run_benchmark(
        instances=instances,
        model=args.model,
        max_cycles=args.max_cycles,
        timeout=args.timeout,
        workspace_base=args.workspace,
    )


if __name__ == "__main__":
    main()
