# orchystraw

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/v/release/ChetanSarda99/openOrchyStraw)](https://github.com/ChetanSarda99/openOrchyStraw/releases)
[![Bash 5+](https://img.shields.io/badge/bash-5%2B-green)](https://www.gnu.org/software/bash/)
[![Zero Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)](https://github.com/ChetanSarda99/openOrchyStraw)

Multi-agent AI coding orchestration. Markdown prompts + bash. No framework, no runtime, no Docker.

Runs a team of AI agents on any codebase using any AI CLI (Claude Code, Codex, Gemini CLI, Aider, Cursor, Windsurf). Each agent has a role, file ownership boundaries, and a prompt. The orchestrator runs them in sequence, enforces ownership, commits per-agent, and coordinates through shared markdown context.

---

## Install

```bash
# One-liner
curl -fsSL https://raw.githubusercontent.com/ChetanSarda99/openOrchyStraw/main/install.sh | bash

# Or manual
git clone https://github.com/ChetanSarda99/openOrchyStraw.git
cd openOrchyStraw
export PATH="$PWD/bin:$PATH"  # add to ~/.zshrc or ~/.bashrc
```

## Quick Start

```bash
# 1. Verify install
orchystraw doctor

# 2. Bootstrap a project
orchystraw init ~/my-project --template saas

# 3. Run your first cycle (dry-run, nothing is committed)
orchystraw run ~/my-project --cycles 1 --dry-run
```

When ready to run for real:

```bash
# Supervised — approve each commit
orchystraw run ~/my-project --cycles 3 --review

# Autonomous
orchystraw run ~/my-project --cycles 10
```

## Requirements

| Requirement | Notes |
|-------------|-------|
| **Bash 5.0+** | macOS: `brew install bash`. Linux: usually pre-installed. |
| **Git** | Any recent version. |
| **An AI CLI** | Anything that accepts a text prompt: `claude -p`, `codex`, `gemini`, `aider`, etc. |

Optional: `jq` (for JSON processing), `gh` (GitHub CLI for issue creation).

## Configuration

### .env

Copy `.env.example` to `.env` (or `~/.orchystraw/config.env`) and fill in your API keys:

```bash
cp .env.example .env
# Edit with your preferred editor
```

Key settings:
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GEMINI_API_KEY` — provider API keys
- `ORCH_CLI` — which AI CLI to use (default: `claude`)
- `ORCH_DEFAULT_MODEL` — default model tier (`opus`, `sonnet`, `haiku`, `gpt4o`, `local`, etc.)
- `ORCH_DAILY_BUDGET` — daily spend cap in USD
- `ORCH_LOCAL_PROVIDER` — local LLM support via Ollama or any OpenAI-compatible server

### agents.conf

Each project needs an `agents.conf` file defining the team:

```bash
# id | prompt_path | ownership | interval | label
03-pm      | prompts/03-pm/03-pm.txt       | prompts/ docs/ | 0 | PM Coordinator
06-backend | prompts/06-backend/06-backend.txt | src/ scripts/ | 1 | Backend Dev
11-web     | prompts/11-web/11-web.txt     | site/          | 1 | Web Developer
09-qa      | prompts/09-qa/09-qa.txt       | tests/         | 3 | QA Engineer
10-security| prompts/10-security/10-security.txt | (read-only) | 5 | Security Auditor
```

**Intervals:** `0` = coordinator (runs last) | `1` = every cycle | `2` = every other | `N` = every Nth cycle

### Minimal project structure

```
my-project/
  agents.conf          # Agent definitions
  prompts/             # Agent prompt files
  CLAUDE.md            # Project context (optional but recommended)
  .orchystraw/         # Auto-created on first run (state, metrics)
```

## How It Works

Each cycle:

1. **Runs agents** in sequence, respecting intervals and dependency order
2. **Enforces file ownership** — backend cannot touch frontend files, QA cannot modify scripts
3. **Commits separately** — clean git history, one commit per agent
4. **PM reviews** — coordinator runs last, updates prompts and priorities for next cycle
5. **Repeats** — set cycle count and let it run

## Features

| Feature | What it does |
|---------|-------------|
| **File ownership** | Agents can only write to paths they own. Out-of-scope changes are reverted. |
| **Worktree isolation** | Each agent runs in its own git worktree. Zero merge conflicts. |
| **Smart routing** | Dependency-aware scheduling with model tiering (opus/sonnet/haiku). |
| **Conditional activation** | Agents are skipped when no files changed in their ownership paths. |
| **Prompt compression** | Stable prompt sections are cached; only dynamic content is resent. |
| **Shared context** | Agents communicate through a shared markdown file. No APIs, no message buses. |
| **Review phase** | QA agent can approve, request changes, or comment on other agents' work. |
| **Protected files** | Scripts, config, CLAUDE.md cannot be modified by any agent. |
| **Quality scoring** | Lint + tests + diff + output + ownership scored 0-100 per agent. |
| **Decision audit trail** | Immutable JSONL log of all orchestrator decisions. |
| **Cross-project dashboard** | HTML dashboard across all registered projects. |
| **Local LLM support** | Ollama, llama.cpp, or any OpenAI-compatible local server. |

**By the numbers:** 35 bash modules, 12 configurable agent roles, 45+ tests, 8 projects wired.

## Dashboard

```bash
orchystraw app
```

Opens a local web dashboard showing registered projects, agent status, logs, and configuration. Runs on `http://localhost:4321` by default.

```bash
# Custom port
ORCH_PORT=8080 orchystraw app
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `orchystraw run <project> --cycles N` | Run N orchestration cycles on a project |
| `orchystraw run <project> --dry-run` | Preview what would happen without executing |
| `orchystraw run <project> --review` | Supervised mode — approve each commit |
| `orchystraw init <path> [--template saas\|api\|content]` | Bootstrap a new project with agents.conf + prompts |
| `orchystraw app` | Launch the local web dashboard |
| `orchystraw doctor` | Validate environment (bash version, tools, paths) |
| `orchystraw status` | Show status of all registered projects |
| `orchystraw list` | List registered projects |
| `orchystraw metrics <project>` | Show performance data for a project |
| `orchystraw decisions <project> [--last N]` | Show decision audit trail |
| `orchystraw dashboard` | Generate cross-project HTML dashboard |
| `orchystraw help` | Show help |

### Run flags

| Flag | Description |
|------|-------------|
| `--cycles N` | Number of cycles to run (default: 1) |
| `--dry-run` | Preview without executing |
| `--review` | Approve each commit before it lands |
| `--telegram` | Send Telegram notifications |
| `--sync-state` | Enable cross-project state sync |
| `--smart-models` | Use task-aware model routing |

## Architecture

35 bash modules in `src/core/`, organized by release:

- **v0.1 — Foundation** (8 modules): logging, error handling, cycle state, timeouts, locking, config validation, signals, dry-run
- **v0.2 — Smart Cycle** (7 modules): dynamic routing, review phase, worktree isolation, prompt compression, conditional activation, cycle tracking, signal handling
- **v0.3 — Extended** (6 modules): single-agent mode, task decomposition, project init, prompt templates, QMD refresh, freshness detection
- **v0.4 — Observability** (3 modules): observability spans/events, episodic memory, quality gates
- **v0.5 — Global CLI** (7 modules): co-founder agent, decision store, project registry, quality scorer, stall detector, cross-project dashboard, global CLI

Core orchestration script: `scripts/auto-agent.sh` (~2100 lines).

## Comparison

| | OrchyStraw | AutoGen | CrewAI |
|---|:---:|:---:|:---:|
| Zero dependencies (bash only) | Yes | No | No |
| Works with any AI CLI | Yes | No | No |
| File ownership enforcement | Yes | No | No |
| Git-native (commits per agent) | Yes | No | No |
| Worktree isolation | Yes | No | No |
| No Python/Node runtime | Yes | No | No |
| Human-readable prompts (markdown) | Yes | No | No |
| Token optimization | Yes | No | No |

AutoGen and CrewAI orchestrate chat agents through Python. OrchyStraw orchestrates coding agents (Claude Code, Cursor, etc.) that directly edit files. Different problem, different tool.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
