# OrchyStraw Migration Guide

## Version History

| Version | Description | Status |
|---------|-------------|--------|
| v0.1.0 | Bash-only orchestrator, 8 core modules | Tagged, shipped |
| v0.2.0 | Expanded to 40+ core modules, issue tracker, model routing | Current development |
| v0.5.0 | CLI binary + SQLite persistence | Planned |
| v1.0.0 | Tauri desktop app | Planned |

---

## v0.1.0 to v0.2.0

### Breaking Changes

1. **New `.orchystraw/` directory** — v0.2 stores version metadata in `.orchystraw/version`. This directory must exist.
2. **30+ new core modules** — `src/core/` grew from ~8 to 40+ modules including `config-validator.sh`, `issue-tracker.sh`, `model-registry.sh`, `dynamic-router.sh`, and others.
3. **`agents.conf` format changes** — v0.2 expects new fields:
   - `model_routing` — per-agent model assignment (claude/codex/gemini)
   - `conditional_activation` — frequency-based agent scheduling (every cycle, every 2nd, etc.)
   - Agent numbering expanded from 8 to 11 agents (added Pixel, Security, Web)
4. **New directories** — `research/`, `site/`, `pixel-agents/`, `docs/references/` are expected by various agents.
5. **Shared context reset** — `prompts/00-shared-context/` files are reset each cycle; v0.2 adds structured cycle context files (`context-cycle-N.md`).

### Automated Migration

```bash
# Check what version you're on
bash scripts/migrate.sh detect

# Preview changes (dry run, no modifications)
bash scripts/migrate.sh check

# Apply the upgrade
bash scripts/migrate.sh upgrade
```

### Manual Migration Steps

If you prefer to migrate manually:

**Step 1: Create the .orchystraw directory**
```bash
mkdir -p .orchystraw
echo "0.2.0" > .orchystraw/version
```

**Step 2: Verify core modules**

Ensure these key v0.2 modules exist in `src/core/`:
- `config-validator.sh` — validates agents.conf
- `cycle-state.sh` — persistent cycle state management
- `dynamic-router.sh` — model routing per agent
- `error-handler.sh` — centralized error handling
- `issue-tracker.sh` — local JSONL issue tracking
- `knowledge-base.sh` — shared knowledge store
- `model-registry.sh` — model definitions and capabilities
- `prompt-compression.sh` — prompt size optimization

If any are missing, pull the latest from the `main` branch.

**Step 3: Update agents.conf**

Compare your `agents.conf` against `agents.conf.example`. Key additions for v0.2:
```conf
# Each agent entry now supports:
# model_routing=claude|codex|gemini
# activation=every|every-2nd|every-3rd
```

**Step 4: Add new directories**

```bash
mkdir -p research site docs/references
```

**Step 5: Verify**

```bash
bash scripts/migrate.sh detect
# Should report: v0.2.0
```

---

## Future Migrations

### v0.2.0 to v0.5.0 (planned)
- SQLite database in `.orchystraw/db/`
- CLI binary replaces raw bash invocation
- Issue tracker migrates from JSONL to SQLite

### v0.5.0 to v1.0.0 (planned)
- Tauri desktop app wraps the CLI
- `src-tauri/` becomes the primary interface
- Rust IPC commands for all orchestrator functions
