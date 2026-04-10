# Launch Posts — orchystraw v0.5

Ready-to-post copy for HN, Reddit, Twitter, LinkedIn. All written in plain developer voice — no buzzwords.

---

## Hacker News

**Title:**
```
Show HN: Orchystraw – Run a team of AI coding agents on any project (bash, no deps)
```

**Body:**
```
I've been running a multi-agent coding workflow on my own projects for ~6 months and finally cleaned it up enough to share.

Orchystraw is a bash + markdown orchestrator. You define agents in a config file (id, prompt path, owned files, run interval), and the script cycles through them: each agent reads shared context, writes code in their lane, and commits. PM agent runs last, coordinates everyone.

What it does:
- Runs on any codebase you can `git clone`
- Multi-project: orchystraw run ~/A ~/B ~/C --cycles 3
- Multi-model: Claude/OpenAI/Gemini/Ollama (intelligent selection per task)
- File ownership prevents agents from stepping on each other
- Auto-create GitHub issues from QA findings
- Self-improvement loop (Karpathy autoresearch pattern, optional)
- Web dashboard with live agent activity, chat, project wizard

What it isn't:
- A framework. It's bash. No pip install, no Docker.
- A new agent paradigm. It just orchestrates existing CLIs (claude, ollama, etc.).
- A magic black box. Every prompt is a markdown file you can read/edit.

Stack:
- Core: bash 5+, 35 modules, 44 unit tests
- Web app: Node + React 19 + Tailwind v4 (no Tauri yet — wraps the CLI)
- Agent runtime: shell-out to Claude Code CLI (or any AI CLI you set)

Install: curl -fsSL https://raw.githubusercontent.com/ChetanSarda99/openOrchyStraw/main/install.sh | bash

Inspired by Geoffrey Huntley's "Ralph loop" and Garry Tan's gstack. Karpathy's autoresearch is the next milestone.

Repo: https://github.com/ChetanSarda99/openOrchyStraw
Demo: assets/demo.gif

Happy to answer questions. Looking for honest feedback on the agent prompt design — that's the hardest part.
```

---

## Reddit (r/LocalLLaMA, r/programming, r/ClaudeAI)

**Title (LocalLLaMA):**
```
Built a multi-agent orchestrator in pure bash — works with Ollama too
```

**Body:**
```
Sharing a tool I've been using to run 12+ AI agents on my own projects.

It's bash + markdown — no Python, no Docker, no framework. The whole orchestrator is one script (~2000 lines) that reads agents.conf, runs eligible agents in parallel, commits their work by file ownership, and lets a PM agent coordinate.

Local LLM support: set ORCH_LOCAL_PROVIDER=ollama and ORCH_LOCAL_MODEL=llama3.3 in your config and the orchestrator routes per-agent calls to your local Ollama server. Per-agent model overrides too: heavy reasoning to Opus/o3, quick tasks to local 8B, etc.

Why I built it:
- Wanted to dogfood multi-agent on real projects, not toy examples
- Tired of pip install for every new orchestration framework
- Bash is the lowest common denominator — works on every dev machine

Open source MIT, 8 projects already wired (mine + a few friends'), 35 modules, 44 tests passing.

Repo: https://github.com/ChetanSarda99/openOrchyStraw
```

**Title (programming):**
```
Orchystraw: bash-only multi-agent AI orchestrator with file ownership + intelligent model selection
```

---

## Twitter / X

**Thread (5 tweets):**

1.
```
shipped orchystraw v0.5 — a multi-agent AI coding orchestrator in bash

12 agents. 35 modules. 8 projects. No framework. No pip install.

run a team of AI coding agents on any codebase:
$ orchystraw run ~/my-project --cycles 5

🧵
```

2.
```
each agent gets:
- a markdown prompt file you can edit
- a list of files they own (no stepping on each other)
- a run interval (every cycle, every 3rd, last, etc.)
- a model tier (opus, sonnet, haiku, gpt-4o, gemini, ollama)

PM agent coordinates everyone. Co-Founder agent makes ops decisions autonomously.
```

3.
```
multi-project support. one command runs cycles across your whole portfolio:

$ orchystraw run --all --parallel --smart-models --budget 20

each project gets its own branch, isolated worktree, real-time logs streaming via SSE
```

4.
```
web dashboard included:
- live agent activity (animated)
- agent flow diagram (SVG, hub-and-spoke)
- chat with co-founder agent (talks to claude CLI)
- github issues view (highlights ones being worked on)
- project wizard for new codebases

orchystraw app
```

5.
```
no framework lock-in. no dockerfile. no python.

it shells out to whatever AI CLI you have:
- claude (default)
- ollama (local)
- aider, custom — set ORCH_CLI

install: curl -fsSL ... | bash
github: https://github.com/ChetanSarda99/openOrchyStraw

would love feedback on the prompt design 🙏
```

---

## LinkedIn

```
After 6 months of running multi-agent AI workflows on my projects, I open-sourced the orchestrator: orchystraw.

The whole thing is bash + markdown. No Python, no Docker, no framework. Just a script that reads agents.conf and runs agents in parallel with file ownership rules.

What's actually interesting:

→ It's not a "framework" — it's a coordinator. Each agent shells out to whatever AI CLI you have (Claude Code, Ollama, aider, etc.). You can mix providers per-agent.

→ File ownership prevents agents from stepping on each other. Backend agent owns src/, web agent owns site/, designer owns assets/. The PM agent runs last and coordinates handoffs.

→ Co-Founder agent makes operational decisions autonomously: tunes intervals, allocates models, controls budget. Only escalates to me for strategic calls or budget breaches.

→ Real multi-project support. I run cycles across 8 projects with one command.

→ Comes with a web dashboard (Node + React) showing live agent activity, chat with the co-founder, GitHub issues view.

The agent prompt design was the hardest part. I'm still iterating. If you're doing similar work I'd love to compare notes.

Repo: https://github.com/ChetanSarda99/openOrchyStraw
MIT license. 35 modules, 44 tests passing.

#opensource #ai #developertools #bash
```

---

## Tips for posting

**Best times (UTC):**
- HN: Tuesday-Thursday 13:00-16:00 UTC
- Reddit /r/programming: Tuesday-Thursday 14:00-17:00 UTC
- Twitter: Tuesday-Thursday 13:00-15:00 UTC
- LinkedIn: Tuesday-Thursday 12:00-14:00 UTC

**Before posting:**
- [ ] Pin the demo GIF to the README top
- [ ] Verify install.sh actually works on a fresh shell
- [ ] Tag a v0.5.0 release with changelog
- [ ] Have a docs site URL ready (or fall back to README)
- [ ] Be ready to respond to first 3 hours of comments

**HN-specific:**
- Don't use URL shorteners
- Title must start with "Show HN:" if it's a project launch
- One link in the title, post body for context
- Reply to every comment in the first 4 hours

**Anti-patterns to avoid:**
- Don't say "revolutionary", "game-changer", "next-gen"
- Don't compare to dominant frameworks dismissively
- Don't beg for stars
- Do credit prior art (Ralph loop, gstack, autoresearch)
