# ADR COST-001: Token Budget Architecture

_Date: March 30, 2026_
_Status: APPROVED_
_Author: CTO_
_Implements: #173 (Token Budget Architecture)_
_Related: MODEL-001 (Model Tiering), EFFICIENCY-001 (Script-First)_

---

## Context

OrchyStraw runs multiple agents per cycle, each consuming tokens. Without budget
controls, a 10-cycle run can cost $10–$25 with all-Opus. MODEL-001 introduced
per-agent model tiering (40–60% savings). This ADR defines the budget tracking,
enforcement, and PM-skip policy that completes the cost control picture.

## Decision

### 1. Per-Agent Token Budgets via agents.conf

Add `max_tokens` as a column in agents.conf v3:

```
# id | prompt | ownership | interval | label | model | max_tokens
06-backend | prompts/06-backend/06-backend.txt | scripts/ src/core/ ... | 1 | Backend Developer | sonnet | 200000
02-cto     | prompts/02-cto/02-cto.txt         | docs/architecture/     | 2 | CTO               | opus   | 150000
01-ceo     | prompts/01-ceo/01-ceo.txt         | docs/strategy/         | 3 | CEO               | opus   | 100000
09-qa      | prompts/09-qa/09-qa.txt           | tests/ reports/        | 3 | QA Engineer       | opus   | 150000
03-pm      | prompts/03-pm/03-pm.txt           | prompts/ docs/         | 0 | PM Coordinator    | sonnet | 200000
```

`max_tokens` is the **output token cap** passed to the AI tool via `--max-tokens`.
This is the primary cost lever — input tokens are determined by prompt size (controlled
by prompt-compression.sh), output tokens are where runaway costs happen.

**Default:** If column is missing, use `$ORCH_DEFAULT_MAX_TOKENS` env var or `150000`.

### 2. Model Tiering Policy (from MODEL-001, refined)

| Agent | Model | Rationale |
|-------|-------|-----------|
| 01-CEO | opus | Strategic reasoning, long-horizon planning |
| 02-CTO | opus | Architecture decisions, code review depth |
| 03-PM | sonnet | Coordination is structured, not creative |
| 06-Backend | sonnet | Code generation — sonnet handles bash/scripts well |
| 08-Pixel | sonnet | Template-based JSONL emission |
| 09-QA | opus | Bug detection requires deep reasoning |
| 10-Security | opus | Vulnerability analysis, threat modeling |
| 11-Web | sonnet | Frontend code generation |
| 13-HR | haiku | Simple status updates, team composition |

**Override:** `--model opus` flag on CLI forces all agents to opus (for critical cycles).
Per-agent override: `ORCH_MODEL_OVERRIDE_09_QA=opus` env var.

### 3. PM Skip Policy

When `pre-pm-lint.sh` outputs `Recommendation: PM SKIP`, the orchestrator skips the
PM agent entirely. This is the single biggest cost saver for quiet cycles.

**When PM SKIP is safe:**
- Zero commits from all agents (truly empty cycle)
- All agents were skipped by conditional activation (no work detected)
- No errors in agent logs
- No P0/P1 blockers in 99-actions.txt

**When PM SKIP is NOT safe (override to FULL REVIEW):**
- Any agent produced commits (even 1)
- Agent logs contain errors
- New P0/P1 blockers detected
- First cycle of a run (cycle 1 always gets PM review)

The current implementation in auto-agent.sh (lines 793–817) correctly implements this:
it checks `Recommendation: PM SKIP` from lint output and skips `run_pm()`. The lint
script's verdict logic (lines 199–208) is sound — it only recommends SKIP when
`TOTAL_COMMITS == 0`.

**Edge case:** A cycle where agents ran but produced no file changes is still a SKIP.
This is correct — if agents consumed tokens but changed nothing, running PM to "review
nothing" wastes more tokens. The lint report is saved to `lint-cycle-N.md` for auditing.

### 4. Cost Tracking

#### What to Log

Each cycle should log:
- Agents invoked (count and IDs)
- Agents skipped (count, IDs, and skip reason)
- Model used per agent
- Output token count per agent (from log file size as proxy)
- PM skipped? (yes/no)
- Total estimated cost

#### Where to Store

```
prompts/00-shared-context/cost-log.jsonl
```

One JSON line per cycle:
```json
{"cycle": 5, "timestamp": "2026-03-30 09:15:00", "agents_run": 3, "agents_skipped": 5, "pm_skipped": true, "estimated_cost_usd": 0.12}
```

JSONL is append-only, grep-friendly, and trivially parseable in bash (`jq`-optional).

#### How to Alert

- `check-usage.sh` already monitors API usage percentage (pauses at 70%)
- Add: if estimated daily cost exceeds `$ORCH_DAILY_BUDGET` (env var, default $20),
  log a WARNING and notify via toast
- Do NOT hard-stop on budget — that's v0.5 scope. v0.2 is observe-and-warn only.

### 5. Cost Estimation Formula

Claude Code doesn't expose token counts directly. Proxy estimation:

```bash
# Input tokens ≈ prompt file size / 4 (rough chars-to-tokens ratio)
input_estimate=$(( $(wc -c < "$prompt_file") / 4 ))

# Output tokens ≈ log file size / 4
output_estimate=$(( $(wc -c < "$log_file") / 4 ))

# Cost per model (approximate, input + output)
# opus:  $15/M input + $75/M output
# sonnet: $3/M input + $15/M output
# haiku:  $0.80/M input + $4/M output
```

These are rough estimates. Good enough for budget warnings, not for billing.

### 6. agents.conf v3 Format

Combining MODEL-001 and COST-001, the proposed v3 format:

```
# id | prompt_path | ownership | interval | label | model | max_tokens
```

7 columns. Backward compatible: if columns 6–7 are missing, use defaults
(`opus` and `150000`). The parser already uses `IFS='|'` so adding columns
is a matter of reading two more fields.

**Deferred columns** (v0.5+): `priority`, `depends_on`, `reviews`. These add
complexity without clear v0.2 value. Keep the format minimal.

### 7. Implementation

Changes needed:

1. **auto-agent.sh:** Parse columns 6–7 from agents.conf. Pass `--model` to
   `claude` invocation. Pass `--max-tokens` if supported by the tool.
2. **config-validator.sh:** Validate model values (`opus`/`sonnet`/`haiku`).
   Warn on unknown. Validate max_tokens is numeric and > 0.
3. **pre-pm-lint.sh:** Add cost estimate row to the report (model × log size).
4. **New: cost-logger.sh** — Append JSONL line after each cycle. ~30 lines of bash.

## Consequences

- **Positive:** Visibility into per-cycle cost. PM skip saves ~$0.15–$0.30 per quiet cycle. Model tiering saves 40–60% overall. Budget warnings prevent surprise bills.
- **Negative:** Cost estimates are approximate (chars/4 is a rough proxy). Over-aggressive PM skip could miss coordination needs on "almost quiet" cycles.
- **Risk:** Token budgets that are too low cause agents to produce truncated output. Mitigated by: generous defaults (150K–200K), PM reviews output quality, config-validator warns on suspiciously low values.

## Constraints

- Zero external dependencies. Cost logging is bash + echo to JSONL.
- `jq` is optional — scripts work without it (grep/awk for JSONL parsing).
- Budget enforcement is warn-only in v0.2. Hard stops are v0.5 scope.
- agents.conf remains the single source of truth — no separate models.yaml.
