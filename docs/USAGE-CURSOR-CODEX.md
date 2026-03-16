# Using orchystraw with Cursor / Codex / Others

## Cursor

### Setup
1. Copy template: `cp -r orchystraw/template/ your-project/`
2. Open project in Cursor
3. Paste `bootstrap-prompt.txt` into Cursor's Composer (Cmd+I)

### Running Agents
- Open Composer, paste: "Read and execute prompts/02-backend-dev/02-backend-dev.txt"
- Cursor reads the file, understands the tasks, executes them
- After each agent, run PM: "Read and execute prompts/01-pm/01-project-manager.txt"

### Cursor-Specific
- Cursor reads `.cursorrules` — the bootstrap creates `CLAUDE.md` which works the same way
- Cursor's multi-file editing is strong — good for frontend/design agents
- Use Cursor's built-in terminal for `auto-agent.sh` if you have Claude Code CLI installed

---

## OpenAI Codex (CLI)

### Setup
```bash
cp -r orchystraw/template/ your-project/
cd your-project
```

### Running Agents
```bash
# Codex CLI accepts prompts via stdin
codex --approval-mode full-auto < prompts/02-backend-dev/02-backend-dev.txt
```

### Automated Cycles
Edit `auto-agent.sh` — replace the `claude` command with `codex`:
```bash
# In auto-agent.sh, change:
#   claude -p --dangerously-skip-permissions --output-format text
# To:
#   codex --approval-mode full-auto --quiet
```

### Notes
- Codex uses GPT models — prompt structure still works, but some Claude-specific references (like `/test` slash skills) won't apply
- Shared context protocol works identically
- File ownership and git workflow are tool-agnostic

---

## Aider

```bash
# Aider accepts prompts from files
aider --message-file prompts/02-backend-dev/02-backend-dev.txt
```

---

## Any AI Agent with a CLI

orchystraw works with anything that:
1. Accepts a text prompt (via stdin, file, or paste)
2. Can read/write files in your project
3. Can run shell commands

The prompt files are plain markdown. The orchestrator is a bash script. No runtime dependencies.

To adapt `auto-agent.sh` for your tool:
1. Find the `claude` command in the script (~line 150)
2. Replace with your agent's CLI command
3. Adjust flags (stdin piping, output format, permission mode)

```bash
# Claude Code
claude -p --dangerously-skip-permissions --output-format text

# Codex
codex --approval-mode full-auto --quiet

# Aider
aider --message-file /dev/stdin --yes

# Custom
your-agent --prompt-stdin --no-confirm
```

Everything else (shared context, git workflow, backups, PM coordination) stays the same.
