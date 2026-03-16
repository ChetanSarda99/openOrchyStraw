# Using orchystraw with Windsurf

## Quick Start

### 1. Copy the template
```bash
cp -r orchystraw/template/ your-project/
cd your-project
```

### 2. Bootstrap via Windsurf Cascade
Open Windsurf in your project, then paste the contents of `orchystraw/bootstrap-prompt.txt` into Cascade (Cmd+L or the chat panel).

Windsurf will scan your project and generate all the prompt files, agents.conf, and CLAUDE.md (which Windsurf also reads as project rules).

### 3. Run agents manually
For each agent, paste their prompt into Cascade:
```
Read and execute: prompts/02-backend-dev/02-backend-dev.txt
```

Windsurf will read the file, understand the context, and execute the tasks.

### 4. PM coordination
After dev agents finish, run the PM:
```
Read and execute: prompts/01-pm/01-project-manager.txt
```

The PM reviews what was built, updates all agent prompts for the next cycle, and manages GitHub issues.

---

## Windsurf-Specific Notes

### Cascade vs Terminal
- **Cascade (chat):** Use for individual agent runs. Paste the prompt or tell it to read the file.
- **Terminal:** Use `auto-agent.sh` for automated multi-cycle runs (requires Claude Code CLI installed alongside Windsurf).

### Project Rules
Windsurf reads `CLAUDE.md` (and `.windsurfrules`) as project context. The bootstrap creates `CLAUDE.md` with:
- Tech stack decisions
- File ownership boundaries
- Coding standards
- "DO NOT CHANGE" architecture constraints

### Flows (Windsurf's Automation)
Windsurf Flows can automate the cycle:
1. Create a Flow that runs each agent prompt in sequence
2. Set triggers (e.g., on git push, on schedule)
3. Each step reads the agent prompt file and executes

### Multi-File Editing
Windsurf's strength is multi-file editing — agents that need to touch many files (like frontend devs creating components) work particularly well in Windsurf.

---

## Hybrid Setup (Recommended)

Many teams use **Windsurf for interactive development** and **Claude Code CLI for automated cycles**:

```
Interactive work (you're watching):  → Windsurf Cascade
Automated overnight cycles:          → ./scripts/auto-agent.sh orchestrate 10
Quick single-agent run:              → claude --print < prompts/02-backend-dev/02-backend-dev.txt
```

The prompt files are the same regardless of which tool runs them. That's the point — orchystraw is tool-agnostic.

---

## Differences from Claude Code

| Feature | Claude Code | Windsurf |
|---------|------------|----------|
| CLI automation | Native (`claude -p`) | Needs Claude Code installed |
| Interactive editing | Terminal only | Full IDE |
| Multi-file edits | Good | Excellent |
| Project rules | `CLAUDE.md` | `CLAUDE.md` + `.windsurfrules` |
| Model selection | Config/flag | UI model picker |
| Cost tracking | API billing | Windsurf subscription + API |

Both work with orchystraw. Use whichever fits your workflow.
