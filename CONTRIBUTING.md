# Contributing to OrchyStraw

Thanks for your interest in contributing.

## Getting Started

```bash
git clone https://github.com/ChetanSarda99/openOrchyStraw.git
cd openOrchyStraw
export PATH="$PWD/bin:$PATH"
orchystraw doctor
```

## Running Tests

```bash
bash tests/core/run_tests.sh
```

All tests must pass before submitting a PR.

## Code Style

- **Core orchestrator:** Bash 5+. No external dependencies (no Python, no Node, no pip, no npm). Pure bash + standard Unix tools (grep, sed, awk, jq).
- **Agent prompts:** Markdown. Keep them focused on the agent's role and current tasks.
- **Dashboard app:** Node.js (server), React + Vite (frontend). Dependencies are allowed here.
- **Landing site:** Next.js 15, shadcn/ui, Tailwind.

## What to Contribute

- Bug fixes
- New `src/core/` modules (bash, no external deps)
- Agent prompt improvements
- Test coverage (add to `tests/core/`)
- Documentation
- Dashboard UI improvements
- Project templates (`template/`)

## Pull Requests

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `bash tests/core/run_tests.sh` and verify all tests pass
4. Submit a PR with a clear description of what and why

## File Ownership

The orchestrator enforces file ownership per agent. When contributing prompt or agent changes, respect the ownership boundaries defined in `agents.conf`.

## Reporting Issues

Open a GitHub issue. Include: what you expected, what happened, bash version (`bash --version`), and OS.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
