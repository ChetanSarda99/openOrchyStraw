# Requirements

Everything OrchyStraw needs to run, and how to install it.

## Required

These are mandatory to run the orchestrator (`scripts/auto-agent.sh`).

| Dependency | Min Version | Used By |
|------------|-------------|---------|
| **bash** | 5.0+ | Orchestrator, all core modules. Uses `declare -gA`, namerefs, `${var^^}`. macOS ships bash 3.2 — you must upgrade. |
| **git** | 2.15+ | Branch management, worktrees (`git worktree` needs 2.15+), commits, diffs. |
| **claude** (Claude Code CLI) | latest | Every agent invocation. The orchestrator pipes prompts to `claude -p`. |

## Optional

Only needed for specific features. The orchestrator runs fine without these.

| Dependency | Used By | Notes |
|------------|---------|-------|
| **jq** | Benchmarks (`run-benchmark.sh`, `compare-ralph.sh`, `instance-runner.sh`), results aggregation | Parses JSON task files, emits structured result JSON. |
| **python3** | Benchmarks (`scaffold.py`, `results-collector.sh`, `compare-ralph.sh`) | 3.9+. No pip packages required for core benchmark. SWE-bench suite needs `pip install swebench datasets`. |
| **gh** (GitHub CLI) | `pre-pm-lint.sh` (issue sync), PM agent (milestone/issue queries) | Gracefully skipped if missing — prints "gh CLI not available". |
| **qmd** | `auto-agent.sh` (codebase indexing on QA cycles) | Skipped if missing. Optional semantic search for agents. |
| **Node.js + npm** | Landing page (`site/`) | Node 20+. Uses Next.js 16, React 19, Tailwind 4. Run `npm install` in `site/`. |
| **timeout** (coreutils) | `instance-runner.sh` (benchmark timeout enforcement) | Pre-installed on Linux. On macOS: `brew install coreutils` (provides `gtimeout`, or use `brew install coreutils` and add to PATH). |

## macOS Install

```bash
# Required
brew install bash
# Verify: /opt/homebrew/bin/bash --version (should be 5.x)
# Add to PATH or set as default shell:
#   echo '/opt/homebrew/bin/bash' | sudo tee -a /etc/shells
#   chsh -s /opt/homebrew/bin/bash

brew install git

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Optional
brew install jq
brew install gh
brew install python@3
brew install coreutils   # provides timeout (gtimeout)
brew install node        # for site/ only
```

## Linux Install (Debian/Ubuntu)

```bash
# Required
sudo apt update
sudo apt install bash git

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Optional
sudo apt install jq python3 gh
# Node.js (for site/ only) — use nodesource or nvm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs
```

## Verify Your Setup

```bash
# Required — all three must pass
bash --version | head -1          # bash 5.x+
git --version                     # git 2.15+
claude --version                  # any recent version

# Optional — check what you have
jq --version 2>/dev/null          || echo "jq: not installed (needed for benchmarks)"
python3 --version 2>/dev/null     || echo "python3: not installed (needed for benchmarks)"
gh --version 2>/dev/null          || echo "gh: not installed (needed for GitHub issue sync)"
node --version 2>/dev/null        || echo "node: not installed (needed for site/)"
```

Or run the built-in version check:

```bash
source src/core/bash-version.sh
# Exits with error if bash < 5.0
```
