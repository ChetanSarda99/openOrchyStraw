# Contributing to OrchyStraw

Thanks for wanting to help. Here's how to get involved.

## Ways to contribute

- **Share your agents.conf** — If you've set up OrchyStraw for a project, share your agent config as an example. Different stacks (Python/Django, Go, Rust, React Native) help everyone.
- **Improve the docs** — Found something confusing? Fix it or open an issue.
- **Add a usage guide** — We have guides for Claude Code, Windsurf, and Cursor. If you've used OrchyStraw with another CLI (Gemini, Aider, Continue, Codex), write one.
- **Report bugs in `auto-agent.sh`** — If the orchestrator does something weird, file an issue with your logs.
- **Suggest prompt patterns** — If you've found a prompt structure that works better for a specific agent role, share it.

## How to submit changes

1. Fork the repo
2. Create a branch (`git checkout -b my-change`)
3. Make your changes
4. Test if applicable (run `auto-agent.sh list` to verify config parsing, etc.)
5. Submit a PR with a clear description of what and why

## What we're looking for

- **Real-world configs** — The more agent configurations from real projects, the better the examples get
- **Platform coverage** — Linux and macOS testing (the script is bash-based and currently tested on WSL/Linux)
- **New agent patterns** — Security auditor, performance reviewer, migration specialist, docs writer — if you've built one, contribute it

## What we're not looking for

- Adding dependencies. The whole point is zero deps — markdown and bash.
- Turning this into a framework. It's a scaffold. Keep it simple.
- AI-generated PRs with no real testing. If you haven't run it, don't submit it.

## Code style

- Shell scripts: use `shellcheck` if possible
- Markdown: no trailing whitespace, one newline at end of file
- Keep it readable. Comments > cleverness.

## Questions?

Open a [discussion](https://github.com/ChetanSarda99/orchystraw/discussions) or file an issue.
