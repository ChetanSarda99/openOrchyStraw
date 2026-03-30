# ADR EFFICIENCY-001: Script-First Architecture

_Date: March 30, 2026_
_Status: APPROVED_
_Author: CTO_
_Implements: #174 (Efficiency Sprint)_

---

## Context

Before v0.2, agents did everything: read git logs, count files, parse configs, analyze
shared context, and then do their actual judgment work. This burned tokens on mechanical
tasks that a bash script can do for free.

The efficiency sprint (commit a1a33f4) introduced a new pattern: **scripts handle
mechanical work, agents handle judgment work only.** This ADR documents that principle
as a binding architecture decision.

## Decision

### 1. The Script-First Rule

Before adding work to an agent prompt, apply this test:

> **Can a regex, grep, diff, or wc do it? → Script. Needs reasoning? → Agent.**

Scripts run in milliseconds, cost zero tokens, and produce deterministic output.
Agents cost $0.05–$0.30 per invocation and hallucinate. Never burn tokens on
work a script can do reliably.

### 2. What Moved from Agents to Scripts (v0.2)

| Work | Before (agent) | After (script) | Token Savings |
|------|---------------|----------------|---------------|
| Git commit summary per agent | PM reads `git log`, counts manually | `pre-pm-lint.sh` § Agent Commit Summary | ~500 tokens/cycle |
| Shared context health check | PM scans context.md, judges freshness | `pre-pm-lint.sh` § Shared Context Contributions | ~300 tokens/cycle |
| Prompt health audit | PM reads each prompt, judges completeness | `pre-pm-lint.sh` § Prompt Health | ~800 tokens/cycle |
| GitHub issue sync | PM runs `gh issue list`, formats manually | `pre-pm-lint.sh` § GitHub Issues | ~400 tokens/cycle |
| Agent log error detection | PM reads logs, searches for errors | `pre-pm-lint.sh` § Agent Logs | ~300 tokens/cycle |
| Blocker detection | PM reads 99-actions.txt, finds P0/P1 | `pre-pm-lint.sh` § Blockers | ~200 tokens/cycle |
| Cycle verdict (skip PM?) | Not possible — PM always ran | `pre-pm-lint.sh` § Verdict | ~2000 tokens/cycle (entire PM skip) |
| Agent eligibility check | Orchestrator ran all scheduled agents | `conditional-activation.sh` | ~2000+ tokens/skipped agent |
| Per-agent context filtering | All agents got full shared context | `differential-context.sh` | ~200 tokens/agent |
| Session history compression | Full session tracker (growing unbounded) | `session-tracker.sh` windowing | ~500 tokens/cycle at 10+ cycles |

**Estimated total savings:** 3,000–7,000 tokens per cycle, plus entire agent skips
on quiet cycles. At 10 cycles/run, this is 30,000–70,000 tokens saved.

### 3. Script Catalog

Scripts that implement the script-first principle:

| Script | Purpose | Runs When |
|--------|---------|-----------|
| `scripts/pre-pm-lint.sh` | Digest cycle results into structured report for PM | Before PM agent, every cycle |
| `src/core/conditional-activation.sh` | Skip agents with no relevant work | Before each agent launch |
| `src/core/differential-context.sh` | Filter shared context per agent | During agent prompt assembly |
| `src/core/session-tracker.sh` | Compress cross-cycle history with windowing | During agent prompt assembly |
| `src/core/prompt-compression.sh` | Estimate and compress prompt token counts | During agent prompt assembly |

### 4. Script-Agent Interface Contract

Scripts produce **structured markdown** that gets injected into agent prompts.
The contract:

- Scripts output to stdout (pipe-friendly, testable)
- Output is markdown with headers, tables, and bullet points
- Agents receive script output as context sections (not as instructions)
- Scripts never modify agent prompts directly — the orchestrator handles injection
- Scripts are fail-open: if a script fails, the agent runs with full unfiltered context

### 5. When NOT to Script

Do not script:
- **Priority judgment** — which task matters most requires reasoning
- **Code review** — evaluating correctness needs understanding
- **Architecture decisions** — tradeoff analysis is judgment work
- **Prompt writing** — generating instructions for other agents
- **Conflict resolution** — deciding between competing approaches
- **Creative work** — what to build, how to name things

If you find yourself writing a bash script that does string matching to approximate
reasoning ("if context contains 'BREAKING' then assign to QA"), stop. That's a
heuristic masquerading as judgment. Let the agent do it.

### 6. Future Script Candidates

Work currently done by agents that could move to scripts:

| Candidate | Agent | Feasibility | Priority |
|-----------|-------|-------------|----------|
| Pre-cycle file stats | PM | High — `wc -l`, `find`, `git diff --stat` | P1 |
| Commit message summary | PM | High — `git log --oneline` + formatting | P1 |
| Agent health report | PM | Medium — log size + error grep (pre-pm-lint already does this) | P2 |
| Secrets scan | Security | High — `grep -r` for patterns | P1 |
| Dependency audit | CTO | Medium — parse Cargo.toml/package.json for new deps | P2 |

## Consequences

- **Positive:** Dramatic token savings. PM agent focuses on judgment (task assignment, priority) instead of data gathering. Quiet cycles skip PM entirely. Deterministic, testable data collection.
- **Negative:** More bash to maintain. Script bugs produce wrong data that agents trust blindly. Scripts must be in the PROTECTED list to prevent agent modification.
- **Risk:** Over-scripting. If scripts start making judgment calls (e.g., "this agent should work on X"), we've recreated the agent in bash but worse. The decision framework ("can a regex do it?") prevents this.

## Review of pre-pm-lint.sh (v1)

Reviewed as part of this ADR. Findings:

| Finding | Severity | Description |
|---------|----------|-------------|
| LINT-01 | LOW | `set -uo pipefail` missing `-e`. Silent failures possible if a command fails mid-script. Not blocking — script output is advisory, not safety-critical. |
| LINT-02 | LOW | `git log --since="1 hour ago"` is fragile. Cycles can run faster or slower than 1 hour. Should use branch-based diff (`main..HEAD`) or `HEAD~N`. |
| LINT-03 | LOW | `git log --all` searches all branches including stale ones. Should constrain to current branch or `main..HEAD`. |
| LINT-04 | INFO | No `CONF_FILE` existence check. If `scripts/agents.conf` is missing, the while loop silently produces empty output. Should error early. |
| LINT-05 | INFO | Report format is clean and well-structured. Tables, verdicts, and recommendations are all useful for PM consumption. No missing sections identified. |

**Verdict: APPROVED with 4 LOW/INFO findings.** None blocking. Backend should address LINT-01 through LINT-04 in a follow-up.

## Constraints

- Zero external dependencies. All scripts are bash + coreutils + git.
- Scripts must be in the PROTECTED list in `detect_rogue_writes()` to prevent agent tampering.
- `pre-pm-lint.sh` is already protected (lives in `scripts/`).
