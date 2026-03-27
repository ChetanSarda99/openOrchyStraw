# Platform Compatibility — OrchyStraw

_Date: March 17, 2026_
_Priority: Mac first, Linux second, Windows third_

---

## Current State: BROKEN on macOS

### The Problem
`auto-agent.sh` uses `declare -A` (associative arrays) — requires bash 4.0+.
macOS ships bash 3.2 (2007, last GPLv2 version — Apple won't ship GPLv3).

```bash
# This line crashes on stock macOS:
declare -A AGENT_PROMPTS=()
# bash: declare: -A: invalid option
```

### Other bash 4+ features we use
- Associative arrays (`declare -A`) — used heavily for agent config
- `${!array[@]}` iteration over associative arrays
- Possibly `|&` (pipe stderr), `mapfile`, `readarray` (none found currently)

### Fix Options

| Option | Effort | Mac | Windows | Linux |
|--------|--------|-----|---------|-------|
| **A: Require `brew install bash`** | Low | ✅ (needs brew) | ❌ | ✅ |
| **B: Rewrite in POSIX sh** | High | ✅ native | ❌ | ✅ |
| **C: Rewrite core in Python** | Medium | ✅ native | ✅ | ✅ |
| **D: Rewrite core in Node.js** | Medium | ✅ (needs node) | ✅ | ✅ |
| **E: Rewrite core in Rust** | High | ✅ native | ✅ | ✅ |

### Recommendation: Option C (Python) for v0.5, Option E (Rust) for v1.0

**Why Python for v0.5:**
- Ships with macOS (Python 3 via Xcode tools)
- Cross-platform without any install
- SQLite is built into Python stdlib
- Can reuse all the logic from bash — just cleaner
- Easy to prototype the VCS adapter, issue tracker, knowledge queries
- Everyone on the team (agents) can read/write Python

**Why Rust for v1.0:**
- Tauri is already Rust — natural fit
- Single binary, no runtime dependency
- The orchestrator becomes a Tauri command, not a separate script
- Performance matters when running 10+ agents in parallel

### Migration Path
```
v0.1 (now)     → bash (Linux/WSL only, Mac needs brew)
v0.5 (next)    → Python CLI (`orchystraw` command)
v1.0 (Tauri)   → Rust core, Python for plugins/scripts
```

### Immediate Fix for Mac (v0.1)
Add to README and install script:
```bash
# macOS: install modern bash
brew install bash

# Verify version 4+
/opt/homebrew/bin/bash --version

# Option 1: Update shebang in auto-agent.sh
#!/opt/homebrew/bin/bash

# Option 2: Run explicitly
/opt/homebrew/bin/bash scripts/auto-agent.sh orchestrate 10
```

Update `auto-agent.sh` line 1:
```bash
#!/usr/bin/env bash
# Requires bash 4.0+ (macOS: brew install bash)
```

Add version check at top of script:
```bash
if ((BASH_VERSINFO[0] < 4)); then
    echo "ERROR: bash 4+ required. macOS: brew install bash"
    exit 1
fi
```

---

## Platform Priority

### Tier 1: macOS (PRIMARY — ship first)
- Most indie devs / solo founders use Mac
- CS's target audience: solo builders, ADHD devs, indie hackers
- Tauri has excellent macOS support
- Claude Code / Codex / Cursor all Mac-first

### Tier 2: Linux
- Already works (bash 5.x standard)
- WSL2 counts as Linux (CS's current dev setup)
- Server/CI environments

### Tier 3: Windows
- Tauri supports Windows natively
- Python CLI would work
- Bash scripts would need WSL or Git Bash
- Lowest priority — most target users are on Mac

---

## What Needs to Change for Mac

### Phase 1: Immediate (v0.1 compat)
1. Add bash version check to auto-agent.sh
2. Update shebang to `#!/usr/bin/env bash`
3. Document `brew install bash` in README
4. Test on macOS (CS needs a Mac or we use CI)

### Phase 2: Python rewrite (v0.5)
1. `orchystraw` Python CLI replaces bash scripts
2. SQLite integration (stdlib)
3. VCS adapter (subprocess calls to git/svn/etc)
4. Built-in issue tracker
5. `pip install orchystraw` or `brew install orchystraw`

### Phase 3: Rust/Tauri (v1.0)
1. Core orchestrator in Rust
2. Tauri desktop app
3. Python kept for plugin scripts only
4. `brew install --cask orchystraw` (GUI app)
