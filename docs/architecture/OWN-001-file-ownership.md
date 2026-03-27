# ADR: OWN-001 — File Ownership Boundaries

_Date: March 18, 2026_
_Status: APPROVED_
_Author: CTO (02-cto)_

---

## Context

OrchyStraw uses file ownership in `agents.conf` to determine which agent commits which files. Several ownership issues have emerged that need formal resolution.

## Issues

### 1. Dual agents.conf (BUG-009)

Two `agents.conf` files exist with divergent content:

| File | Agents | Used by |
|------|--------|---------|
| `scripts/agents.conf` | 8 agents | `auto-agent.sh` (line 33) |
| `agents.conf` (root) | 13 agents | Nothing — orphaned |

**Risk:** Human edits the wrong file, agents never see changes.

**Decision:** Root `agents.conf` is the **canonical** file. `auto-agent.sh` should reference `$PROJECT_ROOT/agents.conf`. The `scripts/agents.conf` copy should be deleted after migration. CS must apply this change (protected file).

### 2. src/ Ownership Overlap

| Agent | Owns | Actual files |
|-------|------|-------------|
| 05-tauri-ui | `src/ public/ index.html src/styles/` | React frontend |
| 06-backend | `src/core/ src/lib/` | Orchestrator modules |

`src/` (parent) contains `src/core/` and `src/lib/` (children). Git pathspec processes in order — backend's specific paths should win, but commit order in the same cycle could cause conflicts.

**Decision for v0.1:** PM must not schedule both 05-tauri-ui and 06-backend for `src/` work in the same cycle. Document as known limitation.

**Decision for v0.5:** Add overlap detection to `config-validator.sh`. If agent A owns a parent path and agent B owns a child path, emit a warning. If both are scheduled in the same cycle, emit an error.

### 3. auto-agent.sh Has No Owner

The orchestrator script is PROTECTED (rogue detector restores it) but no agent is responsible for its evolution. Backend agent writes modules to `src/core/` that get `source`d, but can't modify the script itself.

**Decision:** `auto-agent.sh` is **human-only (CS) with CTO review**. Backend contributes via `src/core/` modules. This is intentional — the orchestrator should not modify itself.

Add a comment header to `auto-agent.sh`:
```
# Owner: CS (human) — CTO reviews changes
# Agents contribute modules via src/core/ (sourced at runtime)
# Protected by rogue detector — agent changes are auto-reverted
```

### 4. Backend scripts/ vs Protected Files

06-backend owns `scripts/` but `scripts/auto-agent.sh`, `scripts/agents.conf`, and `scripts/check-*.sh` are PROTECTED. Backend agent does work on protected files that gets silently discarded.

**Decision for v0.1:** Use exclusion syntax in agents.conf:
```
06-backend | ... | scripts/ !scripts/auto-agent.sh !scripts/agents.conf !scripts/check-*.sh src/core/ src/lib/ | ...
```

**Decision for v0.5:** Move non-protected helper scripts to `scripts/helpers/` and narrow backend ownership to `scripts/helpers/ src/core/ src/lib/`.

---

## Summary of Actions

| Action | Owner | Priority | Status |
|--------|-------|----------|--------|
| Migrate CONF_FILE to root agents.conf | CS | P0 | SPEC |
| Delete scripts/agents.conf after migration | CS | P0 | SPEC |
| Add exclusions to backend ownership | CS | P1 | SPEC |
| Add owner comment to auto-agent.sh header | CS | P2 | SPEC |
| Overlap detection in config-validator.sh | 06-backend | P2 (v0.5) | FUTURE |
