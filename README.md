# openOrchyStraw 🍓

**Get multiple AI agents working on the same codebase.** Markdown prompts + bash script. No framework, no dependencies.

Works with Claude Code, Codex, Gemini, Aider, Windsurf, Cursor — anything that takes a prompt.

## What It Does

Define agents in `agents.conf`, give each a markdown prompt file, and run:

```bash
bash scripts/auto-agent.sh orchestrate 5   # run 5 cycles
```

The orchestrator:
1. Runs each agent in sequence (respecting cycle intervals)
2. Enforces file ownership (agents can't write outside their paths)
3. Commits each agent's work separately
4. Runs the PM agent last to review + update prompts for next cycle
5. Backs up prompts, tracks progress, handles errors

## Agent Configuration

```
# agents.conf — Format: id | prompt_path | ownership | interval | label
03-pm        | prompts/03-pm/03-pm.txt    | prompts/ docs/ | 0 | PM Coordinator
04-tauri-rust| prompts/04-tauri-rust/...  | src-tauri/      | 1 | Rust Developer
05-tauri-ui  | prompts/05-tauri-ui/...    | src/            | 1 | UI Developer
06-backend   | prompts/06-backend/...     | backend/        | 1 | Backend Dev
09-qa        | prompts/09-qa/...          | none            | 3 | QA Engineer
```

- **interval=1**: runs every cycle
- **interval=2**: every other cycle
- **interval=0**: coordinator, runs LAST

## Quick Start

```bash
git clone https://github.com/ChetanSarda99/openOrchyStraw.git
cd openOrchyStraw

# Edit agents.conf for your project
# Write prompt files for each agent
# Run it
bash scripts/auto-agent.sh orchestrate 3
```

## Monorepo Consolidation (Mar 27, 2026)

This repo now acts as the single public "massive open OrchyStraw" workspace.

Imported legacy repositories:
- `legacy/OrchyStraw-Pro/` (from `ChetanSarda99/OrchyStraw-Pro`)
- `legacy/OrchyStraw-private/` (from `ChetanSarda99/OrchyStraw`)
- `strategy-vault/` (from `ChetanSarda99/orchystraw_strategy_vault`)

Active root scaffold remains in the main repository root.

## Features

- 🔒 **File ownership enforcement** — agents can't write outside their paths
- 🔄 **Auto-cycle** — PM reviews, updates prompts, next cycle starts automatically
- 📊 **Usage tracking** — pauses when API usage hits threshold
- 🛡️ **Protected files** — scripts, config, CLAUDE.md can't be modified by agents
- 📋 **Shared context** — agents read/write to shared context file for coordination
- 💾 **Prompt backups** — every cycle backs up all prompts before PM modifies them
- 🌿 **Git integration** — feature branches per cycle, commits per agent, auto-merge

## Requirements

- Bash 5+
- Git
- An AI CLI that accepts a prompt: `claude -p`, `codex`, `gemini`, `aider`, etc.

## License

MIT
