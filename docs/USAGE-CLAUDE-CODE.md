# Using orchystraw with Claude Code

## Quick Start (5 minutes)

### 1. Copy the template into your project
```bash
cp -r orchystraw/template/ your-project/
cd your-project
```

### 2. Run the bootstrap
```bash
claude --print "$(cat orchystraw/bootstrap-prompt.txt)"
```

This scans your codebase and generates:
- `CLAUDE.md` — project rules all agents follow
- `scripts/agents.conf` — who runs, what model, what order
- `prompts/01-pm/01-project-manager.txt` — PM tailored to your project
- `prompts/02-*/` through `05-*/` — dev agents matched to your stack
- `prompts/00-shared-context/context.md` — the shared brain

### 3. Run a single agent manually
```bash
claude --print < prompts/02-backend-dev/02-backend-dev.txt
```

### 4. Run a full orchestrated cycle
```bash
./scripts/auto-agent.sh orchestrate 5   # run 5 cycles
```

---

## Claude Code Flags That Matter

| Flag | What It Does | When to Use |
|------|-------------|-------------|
| `--print` | Non-interactive, outputs to stdout | Always for automated runs |
| `--dangerously-skip-permissions` | No confirmation prompts | Automated cycles (understand the risk) |
| `--output-format text` | Plain text output | Log parsing |
| `-p` | Read prompt from stdin | Piping prompt files |

### Recommended command for agents:
```bash
claude -p --dangerously-skip-permissions --output-format text < prompts/02-backend-dev/02-backend-dev.txt
```

### For PM (coordinator):
```bash
claude -p --dangerously-skip-permissions --output-format text < prompts/01-pm/01-project-manager.txt
```

---

## Model Selection

Claude Code uses your configured model by default. For orchystraw, you want:

| Agent Role | Recommended Model | Why |
|-----------|-------------------|-----|
| PM (coordinator) | Opus 4.6 | Needs strategic thinking, cross-agent awareness |
| Backend Dev | Sonnet 4.6 | Good balance of speed and quality for code |
| Frontend Dev | Sonnet 4.6 | Same |
| QA | Opus 4.6 | Needs deep analysis, security review |
| Design System | Sonnet 4.6 | Fast iteration on components |

Set model per-agent in `agents.conf` or use Claude Code's model picker.

---

## The Shared Context Protocol

Every agent:
1. **Reads** `prompts/00-shared-context/context.md` before starting
2. **Executes** their prompt tasks
3. **Appends** what they built/changed/need to the shared context file

The orchestrator injects shared context automatically when using `auto-agent.sh`. For manual runs, tell the agent:

```
Before starting, read prompts/00-shared-context/context.md.
After finishing, append your changes to that file.
```

---

## Directory Structure After Bootstrap

```
your-project/
├── CLAUDE.md                              ← project rules (auto-generated)
├── prompts/
│   ├── 00-shared-context/
│   │   ├── context.md                     ← shared brain (read/append)
│   │   ├── progress.json                  ← file counts per cycle
│   │   └── usage.txt                      ← API usage tracking
│   ├── 00-session-tracker/
│   │   └── SESSION_TRACKER.txt            ← cross-cycle history
│   ├── 00-backup/                         ← auto-backups per cycle
│   ├── 01-pm/
│   │   ├── 01-project-manager.txt         ← PM prompt
│   │   └── logs/                          ← PM logs per cycle
│   ├── 02-backend-dev/
│   │   ├── 02-backend-dev.txt             ← backend agent prompt
│   │   └── logs/
│   ├── 03-frontend-dev/                   ← (or ios-dev, etc.)
│   ├── 04-design-system/                  ← (optional)
│   ├── 05-qa/                             ← (optional, runs less frequently)
│   └── 99-me/
│       └── 99-actions.txt                 ← YOUR manual action items
├── scripts/
│   ├── agents.conf                        ← agent roster + config
│   ├── auto-agent.sh                      ← orchestrator
│   └── check-usage.sh                     ← API usage checker
└── (your actual project files)
```

---

## Tips

### 1. PM writes standing orders, not chat
The PM doesn't "talk" to devs. It updates their prompt files with specific objectives. This is the key insight — async file-based delegation beats LLM-to-LLM conversation.

### 2. One agent, one domain
Backend dev doesn't touch iOS files. QA doesn't fix bugs. File ownership in `agents.conf` enforces this — the orchestrator commits by ownership and detects rogue writes.

### 3. Specific objectives beat vague ones
❌ "Improve the authentication system"  
✅ "Add JWT refresh token endpoint at POST /api/auth/refresh. Write 3 integration tests. Update shared-context when done."

### 4. "DO NOT CHANGE" sections
Put `DO NOT CHANGE` headers around architecture decisions in prompts. Agents will respect these and won't rewrite your tech stack choices.

### 5. QA runs less frequently
QA doesn't need to run every cycle. Set `interval=5` in agents.conf so QA runs every 5th cycle. Saves tokens, QA has more to review.

### 6. Check the logs
Every agent writes logs to `prompts/<agent>/logs/`. If an agent fails, the log tells you why. Most failures are: prompt too short, context too large, or ownership conflict.

### 7. Watch for prompt inflation
PM can bloat agent prompts over cycles. If a prompt exceeds ~4000 lines, manually trim the history sections. The orchestrator backs up every cycle so you can always restore.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Agent writes outside its ownership | Orchestrator auto-reverts rogue writes. Check `agents.conf` ownership paths. |
| PM switches git branches | Orchestrator detects and recovers. PM prompt has `GIT SAFETY RULES` section. |
| Agent produces tiny output | Prompt might be too short (<30 lines) or corrupted. Check backup, restore. |
| Context file gets too large | Archive old context: `cp context.md context-cycle-N.md` and reset. |
| All agents fail | Check API usage (`check-usage.sh`). Likely rate limited or over quota. |
