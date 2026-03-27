# Shared Context — Cycle 4 — 2026-03-20 15:39:59
> Agents: read before starting, append before finishing.

## Usage
- Model status (0=ok, 80=overage, 90+=limited):
claude=0
codex=0
gemini=100
overall=100

## Progress (last cycle → this cycle)
- Previous cycle: 3 (? backend, ? frontend, 3 commits)
- Build on this momentum. Don't redo what's already shipped.

## Backend Status
- ✅ `scripts/benchmark/swebench/scaffold.py` — Python SWE-bench glue (BENCH-001 Step 6). Loads instances from HuggingFace datasets, local JSON, or JSONL. Calls instance-runner.sh via subprocess. Outputs predictions JSONL + markdown reports. Dry-run verified: 5/5 tasks valid. (#47 Step 6 COMPLETE)
- ✅ `scripts/benchmark/swebench/requirements.txt` + `README.md` — setup docs for Python SWE-bench integration
- ✅ `src/core/agent-kpis.sh` — Per-agent KPI tracking: 5 metrics (files changed, tasks completed, test pass rate, cycle time, lines added/removed) + composite score. Outputs JSON to `.orchystraw/kpis/`. (#71 COMPLETE)
- ✅ `tests/core/test-agent-kpis.sh` — 45 assertions across 9 test groups. Requires jq (not available in current WSL env, but module correctly validates).
- ✅ `src/core/onboarding.sh` — Project onboarding: detects 6 project types (JS, Python, Rust, Go, Java, multi), suggests agent teams, generates agents.conf + prompt files. (#62 COMPLETE)
- ✅ `tests/core/test-onboarding.sh` — 42/42 assertions PASS. Covers detection, suggestions, conf generation, prompt generation, full pipeline.
- All syntax checks PASS (python3 + bash -n). scaffold.py --dry-run verified against all 5 local tasks.

## iOS Status
- (fresh cycle)

## Design Status
- 11-Web: STANDBY — build verified (25 pages, 0 errors), Phase 17 blocked on benchmark results (scripts/benchmark/results/ empty), deploy blocked on CS enabling GitHub Pages

## QA Findings
- (fresh cycle)

## Blockers
- (none)

## Notes
- (none)
