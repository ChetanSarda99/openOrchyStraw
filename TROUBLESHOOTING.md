# Troubleshooting

## Common Issues

### "Prompt too short (N lines) — skipping"
Agent prompt has <30 lines. Either PM corrupted it or it was never written properly.

**Fix:** Restore from backup:
```bash
ls prompts/00-backup/ | tail -1  # find latest backup
cp prompts/00-backup/cycle-XXXXXXXX/02-backend-dev.txt prompts/02-backend/
```

### All agents fail every cycle → auto-stop after 3
Usually means your AI CLI isn't authenticated or installed.

**Fix:**
```bash
# For Claude Code:
claude --version          # is it installed?
claude -p <<< "say hi"   # does auth work?

# For Codex:
codex --version
codex -q "say hi"

# For Gemini CLI:
gemini --version
```

### Merge conflict keeps branch alive
One or more agents modified overlapping files (shouldn't happen with good ownership).

**Fix:**
```bash
git branch                                    # find the stuck branch
git checkout auto/cycle-N-XXXX-XXXX
git rebase main                               # fix conflicts
git checkout main
git merge auto/cycle-N-XXXX-XXXX --no-ff
git push origin main
git branch -d auto/cycle-N-XXXX-XXXX
```

Then check `agents.conf` — two agents probably own overlapping directories. Fix ownership before the next cycle.

### PM switches branches (WARNING in logs)
PM ran `git checkout` despite being told not to. The script recovers automatically.

**Fix:** Already handled. If persistent, add stronger warnings to PM prompt:
```
### GIT SAFETY RULES (CRITICAL)
NEVER run: git checkout, git switch, git merge, git push, git reset, git rebase
```

### Rogue writes detected
An agent wrote files outside its ownership. Script discards them automatically.

**Fix:** Check which agent did it (look at the cycle logs in `prompts/<agent>/logs/`), then tighten its ownership in `agents.conf` and add explicit "MUST NOT WRITE TO" paths in the prompt.

### Usage too high (orchestrator pausing)
`check-usage.sh` detected rate limiting. Orchestrator pauses when `usage.txt` ≥ 70.

**Fix:** Wait for rate limit to reset, or check manually:
```bash
cat prompts/00-shared-context/usage.txt    # 0=ok, 80=overage, 100=limited
./scripts/check-usage.sh                   # re-check now
```

### Prompts keep getting corrupted
PM was rewriting entire prompts and dropping sections.

**Fix:** PM should use Edit tool (not Write) to update only task sections. Add this to PM's prompt:
```
IMPORTANT: Do NOT rewrite entire prompts. Use the Edit tool to modify only:
- "What's DONE" section
- "YOUR TASKS" section
- "Agent Status Summary" (PM prompt only)
```

### Agent keeps redoing finished work
PM didn't acknowledge completed tasks, so the agent thinks they're still assigned.

**Fix:** PM must update the "What's DONE" section every cycle and remove completed items from "YOUR TASKS". This is the PM's most important job.

### No Windows notifications
PowerShell path may differ on your WSL setup.

**Fix:** Check the path in `auto-agent.sh`'s `notify()` function:
```bash
ls /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
```

### Agent hallucinates commands
Agent tries to run `/plan`, `/deploy`, `/lint` — these don't exist.

**Fix:** Only 5 slash commands are real in Claude Code: `/test`, `/review`, `/security`, `/debug`, `/refactor`. Plus any custom commands defined in your project's `CLAUDE.md`. Remove fake commands from the prompt.

---

## Logs

All logs are in `prompts/<agent>/logs/`:

```bash
# Latest PM log
ls -t prompts/01-pm/logs/01-pm-*.log | head -1 | xargs tail -50

# Latest backend log
ls -t prompts/02-backend/logs/02-backend-*.log | head -1 | xargs tail -50

# Orchestrator log (all cycles)
tail -100 prompts/01-pm/logs/orchestrator.log

# Usage status
cat prompts/00-shared-context/usage.txt
```

---

## Nuclear Reset

If everything is broken and you just want to start fresh:

```bash
git checkout main
git branch -D $(git branch | grep auto/)           # delete all stuck cycle branches
cp prompts/00-backup/cycle-LATEST/* prompts/*/      # restore from last good backup
echo "0" > prompts/00-shared-context/usage.txt      # reset usage
./scripts/auto-agent.sh orchestrate                 # restart
```
