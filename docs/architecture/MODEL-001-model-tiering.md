# ADR MODEL-001: Model Tiering per Agent

_Date: March 29, 2026_
_Status: APPROVED_
_Author: CTO_
_Implements: #46 (Model Tiering)_

---

## Context

All agents currently use the same model (Claude Opus 4.6). This is expensive and unnecessary — a CEO writing a strategic memo doesn't need the same model as a Backend agent writing bash. Different tasks have different capability requirements.

## Decision

### 1. Model Column in agents.conf

Add `model` as column 9 in agents.conf v2:

```
# id | prompt | ownership | interval | label | priority | depends_on | reviews | model
06-backend | ... | 1 | Backend | 10 | none | none | sonnet
01-ceo | ... | 3 | CEO | 3 | none | none | opus
09-qa | ... | 3 | QA | 5 | 06-backend | 06-backend | opus
```

**Default:** If column 9 is missing, use `$ORCH_DEFAULT_MODEL` (env var) or `opus` as fallback.

### 2. Model Mapping

The `model` column value maps to the AI tool's model flag:

| Value | Claude Code Flag | Use Case |
|-------|-----------------|----------|
| `opus` | `--model claude-opus-4-6` | Strategy, architecture, complex reasoning (CEO, CTO, QA) |
| `sonnet` | `--model claude-sonnet-4-6` | Code generation, routine tasks (Backend, Frontend, Web) |
| `haiku` | `--model claude-haiku-4-5` | Simple formatting, status updates (HR, Brand) |

The orchestrator passes the model flag when invoking the agent:
```bash
claude --model "${AGENT_MODELS[$id]}" --prompt-file "$prompt_path" ...
```

### 3. Agent-to-Model Recommendations

| Agent | Recommended Model | Rationale |
|-------|------------------|-----------|
| 01-CEO | opus | Strategic reasoning, long-horizon planning |
| 02-CTO | opus | Architecture decisions, code review |
| 03-PM | sonnet | Coordination, prompt updates (structured, not creative) |
| 06-Backend | sonnet | Code generation — sonnet is sufficient for bash/scripts |
| 08-Pixel | sonnet | Template-based JSONL emission |
| 09-QA | opus | Bug detection requires deep reasoning |
| 10-Security | opus | Vulnerability analysis, threat modeling |
| 11-Web | sonnet | Frontend code generation |
| 13-HR | haiku | Simple status updates |

### 4. Cost Impact

| Scenario | Estimated Cost per Cycle |
|----------|-------------------------|
| All Opus (v0.1 current) | ~$1.00–$2.50 per cycle |
| Tiered (v0.2 proposed) | ~$0.40–$1.00 per cycle |
| Savings | **40–60% reduction** |

Numbers are approximate — actual cost depends on prompt size, output length, and which agents run.

### 5. Override Mechanism

```bash
# Force all agents to use opus (debugging, important cycles)
./auto-agent.sh --model opus

# Override a single agent for one cycle
ORCH_MODEL_OVERRIDE_09_QA=opus ./auto-agent.sh
```

CLI `--model` flag overrides all per-agent settings. Env var `ORCH_MODEL_OVERRIDE_<ID>` overrides a single agent.

### 6. No Model Registry Service (Yet)

The design docs describe a hosted model registry (`registry.orchystraw.dev`). **This is deferred.** For v0.2:
- Model names are simple strings in agents.conf
- The orchestrator maps them to flags at invocation time
- No network calls, no JSON registry, no update detection

A registry makes sense when OrchyStraw supports multiple AI tools (Codex, Gemini, Aider) and needs to track model availability, deprecation, and capability matrices. That's v0.5+ scope.

### 7. Implementation

Changes to `auto-agent.sh`:
- Parse column 9 from agents.conf into `AGENT_MODELS` associative array
- Pass `--model "${AGENT_MODELS[$id]}"` to `claude` invocation in `run_agent()`
- Respect `--model` CLI override and `ORCH_MODEL_OVERRIDE_*` env vars

New addition to `config-validator.sh`:
- Validate model values are in allowed set: `opus`, `sonnet`, `haiku`
- Warn on unknown model values (don't fail — forward compatibility)

## Consequences

- **Positive:** 40-60% cost reduction. Right-sized models for each task. Opens path to multi-provider support.
- **Negative:** Wrong model assignment could degrade output quality. Mitigated by: QA catches regressions, PM can override.
- **Risk:** Model names change across providers. Mitigated by: abstract names (`opus`/`sonnet`) mapped to concrete flags in one place.

## Constraints

- No external dependencies. Model mapping is a bash associative array.
- Model column is optional — backward compatible with v0.1 agents.conf (5 columns).
- The orchestrator does NOT validate model availability at runtime — if Claude Code doesn't support the model, the agent invocation fails and error-handler.sh captures it.
