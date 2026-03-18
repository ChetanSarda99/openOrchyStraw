# ADR: BASH-001 — Bash Version Compatibility

_Date: 2026-03-18_
_Status: **APPROVED**_
_Author: CTO (02-cto)_

---

## Context

OrchyStraw's core orchestrator is bash-only (no external dependencies). Cycle 1
delivered 7 bash modules in `src/core/`. Some use associative arrays (`declare -A`)
which require bash 4.0+. Module headers inconsistently claim "bash 5.x" when most
code only needs bash 4.0.

macOS ships bash 3.2 (GPLv2). Linux distros ship bash 5.x. WSL ships bash 5.x.

## Decision

**Minimum supported version: bash 5.0**

Rationale:
- `error-handler.sh` and `logger.sh` already require bash 5.0 for associative arrays
  with `declare -g -A` (global scope in functions — bash 5.0+ behavior)
- All target environments (Linux, WSL, macOS with `brew install bash`) have bash 5.x
- Supporting bash 4.x would constrain future module development for minimal gain
- macOS users must install modern bash via Homebrew regardless (3.2 → 5.x is the jump)

## Implementation

1. **Version guard** — Add to `auto-agent.sh` after `set -uo pipefail`:
   ```bash
   if ((BASH_VERSINFO[0] < 5)); then
       echo "ERROR: OrchyStraw requires bash 5.0+" >&2
       echo "  macOS: brew install bash && sudo chsh -s /opt/homebrew/bin/bash" >&2
       exit 1
   fi
   ```

2. **Module headers** — Standardize all `src/core/*.sh` to declare `# Requires: bash 5.0+`

3. **Shebang** — Use `#!/usr/bin/env bash` everywhere (portable, finds Homebrew bash on macOS)

4. **CI** — When CI exists, test on bash 5.0, 5.1, 5.2

## Rejected Alternatives

- **Bash 4.0 minimum**: Would require rewriting `error-handler.sh` and `logger.sh`
  to avoid `declare -g -A`. Not worth the constraint.
- **POSIX sh**: Would lose arrays, associative arrays, `[[ ]]`, regex matching.
  Incompatible with the orchestrator's design.

## Consequences

- macOS users need `brew install bash` (one-time setup, documented in README)
- All modules can freely use bash 5.x features (nameref, associative arrays, etc.)
- Version guard catches the problem immediately with actionable error message
