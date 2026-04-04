# openOrchyStraw

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/ChetanSarda99/openOrchyStraw)](https://github.com/ChetanSarda99/openOrchyStraw/releases)
[![GitHub stars](https://img.shields.io/github/stars/ChetanSarda99/openOrchyStraw)](https://github.com/ChetanSarda99/openOrchyStraw/stargazers)
[![Bash 5+](https://img.shields.io/badge/bash-5%2B-green)](https://www.gnu.org/software/bash/)
[![Zero Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)](https://github.com/ChetanSarda99/openOrchyStraw)

**Run a team of AI coding agents on any codebase.** Markdown prompts + bash script. No framework, no dependencies.

Works with Claude Code, Codex, Gemini, Aider, Windsurf, Cursor -- anything that takes a prompt.

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/ChetanSarda99/openOrchyStraw.git
cd openOrchyStraw

# 2. Configure your agents
cat > agents.conf << 'EOF'
# id | prompt_path | ownership | interval | label
03-pm      | prompts/03-pm/03-pm.txt           | prompts/ docs/ | 0 | PM Coordinator
06-backend | prompts/06-backend/06-backend.txt  | src/ scripts/  | 1 | Backend Dev
09-qa      | prompts/09-qa/09-qa.txt            | tests/         | 3 | QA Engineer
EOF

# 3. Write agent prompts (see examples/ for templates)

# 4. Preview what would happen
bash scripts/auto-agent.sh orchestrate 3 --dry-run

# 5. Run for real
bash scripts/auto-agent.sh orchestrate 3
```

## What It Does

The orchestrator reads `agents.conf`, runs each AI agent with its prompt, enforces file ownership, commits changes, and coordinates via shared context.

Each cycle:
1. **Run agents** in sequence (respecting intervals and dependencies)
2. **Enforce ownership** -- agents can only write to files they own
3. **Commit separately** -- clean git history with per-agent attribution
4. **PM reviews** -- coordinator agent runs last, updates prompts for next cycle
5. **Repeat** -- auto-cycle mode runs N cycles unattended

## Agent Configuration

```bash
# agents.conf -- 5-column format
# id | prompt_path | ownership | interval | label
03-pm        | prompts/03-pm/03-pm.txt       | prompts/ docs/ | 0 | PM Coordinator
06-backend   | prompts/06-backend/06-backend.txt | src/ scripts/ | 1 | Backend Dev
11-web       | prompts/11-web/11-web.txt     | site/          | 1 | Web Developer
09-qa        | prompts/09-qa/09-qa.txt       | tests/         | 3 | QA Engineer
10-security  | prompts/10-security/10-security.txt | (read-only) | 5 | Security Auditor
```

**Intervals:** `0` = coordinator (runs last) | `1` = every cycle | `2` = every other | `3+` = every Nth cycle

## Features

| Feature | Description |
|---------|-------------|
| **File ownership** | Agents can only write to paths they own. Changes outside ownership are reverted. |
| **Auto-cycle** | PM reviews, updates prompts, next cycle starts automatically. |
| **Worktree isolation** | Each agent runs in its own git worktree. Zero conflicts. |
| **Smart routing** | Dependency-aware scheduling with model tiering (opus/sonnet/haiku). |
| **Prompt compression** | Tiered loading: stable sections cached, only dynamic content resent. |
| **Conditional activation** | Skip idle agents when no files changed in their ownership paths. |
| **Shared context** | Agents communicate through a shared markdown file. No APIs, no message buses. |
| **Git integration** | Feature branches per cycle, commits per agent, auto-merge. |
| **Review phase** | QA agent can approve, request changes, or comment on other agents' work. |
| **Protected files** | Scripts, config, CLAUDE.md cannot be modified by any agent. |

## Comparison

| | OrchyStraw | AutoGen | CrewAI | Ralph |
|---|:---:|:---:|:---:|:---:|
| Zero dependencies (bash only) | Yes | No | No | No |
| Works with any AI CLI | Yes | No | No | Partial |
| File ownership enforcement | Yes | No | No | No |
| Git-native (commits per agent) | Yes | No | No | Yes |
| Worktree isolation | Yes | No | No | No |
| Auto-cycle with PM review | Yes | Partial | Partial | No |
| Token optimization | Yes | No | No | No |
| Human-readable prompts | Yes | No | No | Yes |
| No Python/Node runtime | Yes | No | No | Partial |

**Key difference:** AutoGen and CrewAI are Python frameworks for chat agents. OrchyStraw orchestrates real coding agents (Claude Code, Cursor, etc.) that edit files directly. No runtime, no message passing, no dependencies.

## Architecture

20+ composable bash modules in `src/core/`:

- **v0.1.0 -- Foundation** (8 modules): logging, error handling, cycle state, timeouts, locking, config validation, signals, dry-run
- **v0.2.0 -- Smart Cycle** (7 modules): dynamic routing, review phase, worktree isolation, prompt compression, conditional activation, differential context, session tracking
- **v0.3.0 -- Extended** (5+ modules): single-agent mode, task decomposition, project initialization, prompt templates, QMD refresh

## Requirements

- **Bash 5.0+** (macOS: `brew install bash`)
- **Git**
- **An AI CLI** that accepts a prompt: `claude -p`, `codex`, `gemini`, `aider`, etc.

## Documentation

- [Landing page](https://chetansarda99.github.io/openOrchyStraw/)
- [Quickstart guide](https://chetansarda99.github.io/openOrchyStraw/docs/quickstart)
- [agents.conf reference](https://chetansarda99.github.io/openOrchyStraw/docs/api/agents-conf)

## License

MIT
