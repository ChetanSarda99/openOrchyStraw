# CLI Guide — Choosing the Right AI Agent for Each Task

orchystraw works with **any** AI coding agent that has a CLI. But different CLIs have different strengths. This guide helps you pick the best one for each agent role.

---

## CLI Comparison

| CLI | Best For | Strengths | Weaknesses | Cost Model |
|-----|----------|-----------|------------|------------|
| **Claude Code** | Backend, architecture, complex logic | Deep reasoning, long context, excellent code quality | Slower, higher cost per token | API usage (Opus/Sonnet) |
| **Windsurf** | Frontend, multi-file refactors | Fast multi-file edits, great IDE integration | No standalone CLI (use Cascade) | Subscription + API |
| **Cursor** | Frontend, rapid prototyping | Fast, good autocomplete, multi-file | No standalone CLI (use Composer) | Subscription + API |
| **OpenAI Codex** | Quick tasks, scripting, tests | Fast, cheap, good at routine code | Less deep reasoning, smaller context | API usage (GPT-4o/o3) |
| **Aider** | Git-aware edits, pair programming | Git integration, diff-based, multi-model | Setup complexity, can be chatty | BYO API key |
| **Continue** | IDE-integrated tasks | VS Code/JetBrains native, multi-model | Newer, less battle-tested for automation | BYO API key |
| **OpenClaw** | Orchestration, life/project management | Multi-channel, cron, memory, tools | Not primarily a code agent | API usage |

---

## Recommended CLI Per Agent Role

### PM (Coordinator) — Use the smartest model available
```
Claude Code (Opus) > Windsurf > Cursor > Codex
```
**Why:** PM needs to understand cross-agent state, make strategic decisions about task decomposition, write good prompts. This is where you want the most capable model. Don't cheap out on PM.

### Backend Developer — Claude Code or Codex
```
Claude Code (Sonnet) > Codex > Aider
```
**Why:** Backend work = logic, APIs, database, auth, tests. Claude Code excels at complex logic and writing comprehensive tests. Codex is good for simpler CRUD and scripting. Aider's git-awareness helps for incremental changes.

### Frontend Developer — Windsurf or Cursor
```
Windsurf > Cursor > Claude Code (Sonnet)
```
**Why:** Frontend = many files, components, styling, layout. Windsurf and Cursor are built for multi-file editing with visual feedback. Claude Code works but is slower for the kind of rapid iteration frontend needs.

### iOS/Mobile Developer — Claude Code
```
Claude Code (Sonnet) > Cursor > Codex
```
**Why:** Swift/SwiftUI has specific patterns that Claude handles well. Mobile dev often needs understanding of framework-specific APIs (SwiftData, @Observable, etc.) where Claude's training is strong.

### Design System — Windsurf or Cursor
```
Windsurf > Cursor > Claude Code (Sonnet)
```
**Why:** Design tokens, component styling, theme files — lots of small changes across many files. Visual tools are faster here.

### QA Engineer — Claude Code (Opus)
```
Claude Code (Opus) > Claude Code (Sonnet)
```
**Why:** QA needs deep analysis — finding edge cases, security issues, race conditions. This is where Opus 4.6 shines. Don't use a fast/cheap model for QA; you'll get shallow reviews.

### Test Writer — Codex or Claude Code
```
Codex > Claude Code (Sonnet) > Aider
```
**Why:** Writing tests is more formulaic than other dev work. Codex is fast and cheap for cranking out test files. Claude Code for more complex integration/e2e tests.

### Documentation — Codex or Claude Code
```
Codex > Claude Code (Sonnet)
```
**Why:** Docs are structured, follow patterns, reference existing code. Codex is great for this — fast and cost-effective. Claude Code for architectural docs that need deeper understanding.

### DevOps — Claude Code
```
Claude Code (Sonnet) > Codex
```
**Why:** CI/CD, Docker, Terraform, k8s configs require understanding of infrastructure concepts. Claude Code's reasoning is valuable here. Codex for simpler config changes.

### Security Auditor — Claude Code (Opus)
```
Claude Code (Opus) only
```
**Why:** Security review requires the highest-capability model. Opus catches things Sonnet misses — subtle auth bypasses, injection vectors, timing attacks. No shortcuts here.

---

## Configuring Different CLIs Per Agent

### Option 1: Edit `auto-agent.sh`

In the `run_agent()` function (~line 150), the default command is:

```bash
claude -p --dangerously-skip-permissions --output-format text
```

You can add per-agent CLI selection:

```bash
run_agent() {
    local agent_id=$1
    local cli_cmd=""
    
    case "$agent_id" in
        01-pm)      cli_cmd="claude -p --dangerously-skip-permissions --output-format text --model opus" ;;
        02-backend) cli_cmd="claude -p --dangerously-skip-permissions --output-format text --model sonnet" ;;
        03-frontend) cli_cmd="codex --approval-mode full-auto --quiet" ;;
        05-qa)      cli_cmd="claude -p --dangerously-skip-permissions --output-format text --model opus" ;;
        *)          cli_cmd="claude -p --dangerously-skip-permissions --output-format text" ;;
    esac
    
    # ... rest of function uses $cli_cmd instead of claude
}
```

### Option 2: Add a CLI column to `agents.conf`

Extend the format:

```
# id | prompt | ownership | interval | label | cli
01-pm      | prompts/01-pm/01-pm.txt  | prompts/ docs/ | 0 | PM | claude --model opus
02-backend | prompts/02-backend/02-backend.txt | backend/ | 1 | Backend | claude --model sonnet
03-frontend | prompts/03-frontend/03-frontend.txt | frontend/ | 1 | Frontend | codex
05-qa      | prompts/05-qa/05-qa.txt | none | 5 | QA | claude --model opus
```

This requires modifying the config parser in `auto-agent.sh` to read a 6th column.

### Option 3: Agent-level config files

Create `prompts/<agent>/.cli` files:

```bash
# prompts/02-backend/.cli
claude -p --dangerously-skip-permissions --output-format text --model sonnet
```

```bash
# prompts/05-qa/.cli
claude -p --dangerously-skip-permissions --output-format text --model opus
```

The orchestrator checks for `.cli` in the agent's prompt dir and falls back to the default.

---

## Cost Optimization

| Strategy | Savings | Trade-off |
|----------|---------|-----------|
| Use Sonnet for devs, Opus for PM+QA | ~60% vs all-Opus | Slightly less creative dev output |
| Use Codex for test/docs agents | ~70% vs Claude | Less nuanced output |
| Set QA interval to 5-10 | ~80% on QA tokens | Bugs found later |
| Increase doc agent interval to 10 | ~90% on doc tokens | Docs lag behind code |
| Run fewer cycles overnight | Variable | Slower progress |

### Token Budget Per Cycle (approximate)

| Agent | Model | Tokens/Cycle | Cost/Cycle |
|-------|-------|-------------|------------|
| PM | Opus 4.6 | ~50K | ~$0.75 |
| Backend Dev | Sonnet 4.6 | ~80K | ~$0.24 |
| Frontend Dev | Sonnet 4.6 | ~80K | ~$0.24 |
| QA (every 5) | Opus 4.6 | ~60K | ~$0.18/cycle avg |
| **Total** | | **~270K** | **~$1.41** |

10 cycles = ~$14. A full day of automated development for the cost of a coffee.

---

## CLI Installation

### Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### OpenAI Codex
```bash
npm install -g @openai/codex
```

### Aider
```bash
pip install aider-chat
```

### Windsurf / Cursor
Download from their websites. No CLI — use their IDE chat panels for manual agent runs, or install Claude Code CLI alongside for automated cycles.
