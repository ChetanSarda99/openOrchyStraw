# Model Registry & Update Notifications

_Date: March 17, 2026_

---

## Problem

New models drop constantly. User configured `claude-sonnet-4-6` for workers six months ago.
Now `claude-sonnet-5` exists and is 2x faster, 30% cheaper. User has no idea.

OrchyStraw should:
1. Know what models exist and their capabilities
2. Alert the user when a better option is available
3. Make updating dead simple (one command or one click)

---

## Model Registry

OrchyStraw maintains a **model catalog** — a curated list of models with metadata.

### Source of Truth

Hosted JSON file (updated by OrchyStraw team or community):

```
https://registry.orchystraw.dev/models.json
```

Cached locally at `~/.orchystraw/model-registry.json`.
Refreshed: once per day (on first `orchystraw` run), or `orchystraw models refresh`.

### Registry Format

```json
{
  "version": "2026-03-17",
  "models": [
    {
      "id": "anthropic/claude-sonnet-4-6",
      "provider": "anthropic",
      "name": "Claude Sonnet 4.6",
      "released": "2026-01-15",
      "strengths": ["code-gen", "instruction-following", "speed"],
      "weaknesses": ["complex-reasoning"],
      "best_for": ["backend", "frontend", "pm"],
      "input_cost_per_1m": 3.00,
      "output_cost_per_1m": 15.00,
      "context_window": 200000,
      "speed_tier": "fast",
      "reasoning_tier": "good",
      "status": "active",
      "superseded_by": null,
      "env_key": "ANTHROPIC_API_KEY"
    },
    {
      "id": "anthropic/claude-opus-4-6",
      "provider": "anthropic",
      "name": "Claude Opus 4.6",
      "released": "2026-01-15",
      "strengths": ["deep-reasoning", "architecture", "writing"],
      "best_for": ["ceo", "cto", "strategy"],
      "input_cost_per_1m": 15.00,
      "output_cost_per_1m": 75.00,
      "context_window": 200000,
      "speed_tier": "slow",
      "reasoning_tier": "excellent",
      "status": "active",
      "superseded_by": null,
      "env_key": "ANTHROPIC_API_KEY"
    },
    {
      "id": "anthropic/claude-sonnet-4-5",
      "provider": "anthropic",
      "name": "Claude Sonnet 4.5",
      "released": "2025-10-01",
      "status": "deprecated",
      "superseded_by": "anthropic/claude-sonnet-4-6",
      "env_key": "ANTHROPIC_API_KEY"
    },
    {
      "id": "openai/o3",
      "provider": "openai",
      "name": "OpenAI o3",
      "released": "2025-12-01",
      "strengths": ["reasoning", "math", "code-review"],
      "best_for": ["cto", "qa", "debugging"],
      "input_cost_per_1m": 10.00,
      "output_cost_per_1m": 40.00,
      "context_window": 128000,
      "speed_tier": "slow",
      "reasoning_tier": "excellent",
      "status": "active",
      "superseded_by": null,
      "env_key": "OPENAI_API_KEY"
    },
    {
      "id": "google/gemini-2.5-pro",
      "provider": "google",
      "name": "Gemini 2.5 Pro",
      "released": "2025-11-01",
      "strengths": ["multimodal", "long-context", "ui-understanding"],
      "best_for": ["pixel", "frontend", "ui-review"],
      "input_cost_per_1m": 1.25,
      "output_cost_per_1m": 5.00,
      "context_window": 1000000,
      "speed_tier": "fast",
      "reasoning_tier": "good",
      "status": "active",
      "superseded_by": null,
      "env_key": "GOOGLE_API_KEY"
    }
  ]
}
```

### Offline / Self-Hosted

If user can't reach `registry.orchystraw.dev`:
- Falls back to bundled `models.json` shipped with the CLI version
- User can manually add models: `orchystraw models add <id> --cost-in 3.0 --cost-out 15.0`
- Self-hosted registries: `orchystraw config set registry.url https://my-company.com/models.json`

---

## Update Detection

### When OrchyStraw Checks

```
On every run:
  1. Read local model-registry.json (cached)
  2. If cache older than 24h → fetch latest from registry URL
  3. Compare user's configured models against registry
  4. If any model has superseded_by set → flag for user
  5. If new model matches a role better (by best_for + cost) → suggest
```

### Notification Levels

```
INFO:    New model available (no action needed, just FYI)
SUGGEST: Better model exists for a role you're using
WARN:    Your configured model is DEPRECATED (will stop working)
```

### How the User Sees It

**CLI (v0.5):**
```bash
$ orchystraw run

⚠️  Model updates available:
  • claude-sonnet-4-6 → claude-sonnet-5 (SUGGEST)
    30% cheaper, 2x faster. Recommended for: backend, frontend, pm
  • codex-1 is DEPRECATED → codex-2 available (WARN)
    Your QA agent uses codex-1 which will stop working April 2026

  Run `orchystraw models update` to review and apply.
  Run `orchystraw models update --auto` to accept all suggestions.
  Run `orchystraw models dismiss` to snooze for 7 days.

Starting cycle 1...
```

**Tauri App (v1.0):**
```
┌─────────────────────────────────────────────────┐
│ 🔔 Model Update Available                       │
│                                                 │
│ Claude Sonnet 5 just dropped!                   │
│ 30% cheaper, better at code gen.                │
│                                                 │
│ Currently using: claude-sonnet-4-6 (4 agents)   │
│ Suggestion: switch backend, frontend, pm        │
│                                                 │
│ [Update Now]  [Review Changes]  [Dismiss]       │
└─────────────────────────────────────────────────┘
```

---

## Where Users Update Defaults

### 3 Levels of Config (cascade)

```
~/.orchystraw/config.yaml          ← GLOBAL defaults (all projects)
<project>/.orchystraw/config.yaml  ← PROJECT overrides
environment variables              ← SESSION overrides (temporary)
```

### CLI Commands

```bash
# See current config
orchystraw models list
# Output:
#   ROLE        MODEL                    SOURCE     COST/CYCLE
#   default     claude-sonnet-4-6        global     $0.05
#   cto         o3                       global     $0.20
#   qa          codex                    project    $0.08
#   pixel       gemini-2.5-pro           global     $0.04

# Update global default
orchystraw models set default anthropic/claude-sonnet-5

# Update specific role (globally)
orchystraw models set cto openai/o3-mini

# Update for THIS project only
orchystraw models set qa anthropic/claude-opus-4-6 --project

# Accept all registry suggestions
orchystraw models update --auto

# Preview what --auto would change (dry run)
orchystraw models update --dry-run

# See what's available for a role
orchystraw models recommend qa
# Output:
#   RECOMMENDED FOR: qa (code review, bug finding)
#   1. openai/codex-2       $0.03/review  reasoning: excellent  ✅ API key found
#   2. openai/o3            $0.20/review  reasoning: excellent  ✅ API key found
#   3. anthropic/opus-4-6   $0.15/review  reasoning: excellent  ✅ API key found
#   4. google/gemini-2.5    $0.02/review  reasoning: good       ❌ No API key

# Add API key for a provider
orchystraw auth add google
# Enter GOOGLE_API_KEY: ****
# Saved to ~/.orchystraw/credentials (encrypted)
# New models now available: gemini-2.5-pro, gemini-2.5-flash

# Reset everything to registry recommendations
orchystraw models reset --auto
```

### Config File (for hand-editing)

```yaml
# ~/.orchystraw/config.yaml

models:
  default: anthropic/claude-sonnet-4-6
  
  roles:
    ceo: anthropic/claude-opus-4-6
    cto: openai/o3
    pm: anthropic/claude-sonnet-4-6
    backend: anthropic/claude-sonnet-4-6
    frontend: anthropic/claude-sonnet-4-6
    pixel: google/gemini-2.5-pro
    qa: openai/codex-2
  
  fallbacks:
    openai/o3: anthropic/claude-opus-4-6
    openai/codex-2: anthropic/claude-sonnet-4-6
    google/gemini-2.5-pro: anthropic/claude-sonnet-4-6

budget:
  max_daily: 20.00
  max_per_cycle: 2.00
  max_per_agent: 0.50
  currency: USD
  alert_at_percent: 80

notifications:
  model_updates: true           # Show update notices on run
  update_check_interval: 24h    # How often to check registry
  auto_update: false            # Never auto-switch without user approval
  dismiss_duration: 7d          # Snooze duration for dismissed suggestions
```

### Tauri Settings Panel (v1.0)

```
⚙️ Models

┌─ Default Model ──────────────────────────────┐
│ [claude-sonnet-4-6          ▼]               │
│ Used when no role-specific model is set       │
└──────────────────────────────────────────────┘

┌─ Role Assignments ───────────────────────────┐
│ CEO       [claude-opus-4-6       ▼]  $0.15  │
│ CTO       [o3                    ▼]  $0.20  │
│ PM        [default               ▼]  $0.05  │
│ Backend   [default               ▼]  $0.05  │
│ Frontend  [default               ▼]  $0.05  │
│ UI/Pixel  [gemini-2.5-pro        ▼]  $0.04  │
│ QA        [codex-2               ▼]  $0.03  │
│                                              │
│ Est. cost per cycle: $0.57                   │
│ Est. cost for 10 cycles: $5.70               │
└──────────────────────────────────────────────┘

┌─ API Keys ───────────────────────────────────┐
│ ✅ Anthropic    ····4f2a    [Change]         │
│ ✅ OpenAI       ····8bc1    [Change]         │
│ ❌ Google       not set     [Add Key]        │
│ ❌ Mistral      not set     [Add Key]        │
└──────────────────────────────────────────────┘

┌─ Budget ─────────────────────────────────────┐
│ Daily limit:     [$20.00        ]            │
│ Per cycle limit: [$2.00         ]            │
│ Alert at:        [80%           ]            │
│ ☑ Pause run when budget exceeded             │
│ ☐ Auto-approve under $0.50/cycle             │
└──────────────────────────────────────────────┘

┌─ Updates ────────────────────────────────────┐
│ ☑ Check for new models daily                 │
│ ☐ Auto-switch to better models               │
│ ☑ Warn when using deprecated models          │
│ Last checked: 2 hours ago  [Check Now]       │
└──────────────────────────────────────────────┘
```

---

## Community Registry Contributions

Users can submit models to the registry:

```bash
orchystraw models submit \
  --id "mistral/mistral-large-3" \
  --provider mistral \
  --strengths "code-gen,reasoning,multilingual" \
  --best-for "backend,cto" \
  --cost-in 2.00 --cost-out 6.00
```

This creates a PR on the OrchyStraw registry repo.
Maintainers review and merge. Next registry refresh picks it up.

For self-hosted / private models:
```bash
orchystraw models add "local/my-fine-tuned" \
  --endpoint http://localhost:11434/v1 \
  --cost-in 0 --cost-out 0 \
  --best-for "backend"
```
