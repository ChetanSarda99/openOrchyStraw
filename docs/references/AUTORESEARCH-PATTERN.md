# Karpathy's AutoResearch Pattern — Reference

**Source:** https://github.com/karpathy/autoresearch

## Core Loop
1. Agent modifies a target file (e.g., `train.py`)
2. Execute a time-boxed run (5 min)
3. Measure a single metric (val_bpb — lower is better)
4. Accept/reject changes based on improvement
5. Repeat autonomously overnight

## Key Design
- **One editable file** — agent only touches `train.py`
- **One metric** — val_bpb (bits per byte), objective and measurable
- **Fixed budget** — 5 minutes per experiment
- **Simple accept/reject** — did the metric improve? keep it. no? revert.
- **program.md** — agent instructions (human-authored, agent reads)
- **prepare.py** — fixed infrastructure (human-only, agent can't touch)

## How This Maps to OrchyStraw
| AutoResearch | OrchyStraw Equivalent |
|---|---|
| `train.py` (editable target) | Agent prompts, src/core/ modules, scripts |
| `val_bpb` (metric) | Quality score (0-100 from quality-scorer.sh) |
| 5-min experiment | One orchestration cycle |
| Accept/reject loop | Co-Founder reviews quality scores, reverts if degraded |
| `program.md` | Agent prompt files (prompts/*.txt) |
| `prepare.py` | auto-agent.sh orchestrator (protected, human-only) |

## Integration Points
- Quality scorer already produces 0-100 scores per agent
- Co-Founder module already reviews health and adjusts intervals
- Decision store already tracks accept/reject decisions
- Missing: **auto-revert on quality regression** + **self-improvement loop on prompts**
