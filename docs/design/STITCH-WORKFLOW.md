# Google Stitch 2.0 — UI Design Workflow
## AI-Powered UI Generation for OrchyStraw Agents

**Tool:** [stitch.withgoogle.com](https://stitch.withgoogle.com/)
**Gemini CLI Extension:** `gemini extensions install https://github.com/gemini-cli-extensions/stitch --auto-update`
**SDK:** [github.com/google-labs-code/stitch-sdk](https://github.com/google-labs-code/stitch-sdk)

---

## What is Stitch?

Google Labs AI UI design tool that converts:
- **Natural language prompts** → high-fidelity UI screens
- **Screenshots/wireframes** → digital UI with code
- **Sketches** → polished interfaces

Powered by Gemini 2.5 Pro / 3 Flash. Exports HTML + CSS + JS, or paste to Figma.

---

## Workflow for UI Agents

### Step 1: Generate Screens from Description
Use Gemini CLI with Stitch extension:
```
gemini> Generate a Stitch screen for: dashboard showing agent status cards with progress bars, 
terminal-style dark theme, monospace font, orange accent on dark gray
```

### Step 2: Iterate with Chat
Stitch supports conversational refinement:
- "Make the header more compact"
- "Add a sidebar with agent list"
- "Change to neobrutalist style with hard shadows"

### Step 3: Export
- **HTML/CSS/JS** — drop directly into `site/` (landing page) or Tauri UI
- **Figma paste** — for further refinement before coding
- **Screenshot** — use as reference image for coding agents

### Step 4: Code Integration
- Landing page agent: export HTML, integrate into Next.js components
- Tauri UI agent: export as React components, adapt for Tauri
- iOS agent: use exported screenshot as reference for SwiftUI implementation

---

## Design Principles (from APP_DESIGN_WORKFLOW)

1. **Research first** — Use Mobbin + Sensor Tower to study competitor UIs
2. **Mood board** — Pick 2-3 reference apps, document likes/dislikes
3. **Functional > beautiful** — Every element serves a user goal
4. **Thumb-reachable** — Primary actions in lower third of screen
5. **Iterate with Stitch** — Generate variants, pick best, refine
6. **Export to code** — Don't hand-code UI from scratch when Stitch can generate it

---

## Authentication

### Option A: API Key (recommended)
1. Go to stitch.withgoogle.com → Settings → API Keys → Create Key
2. Configure: `export API_KEY="your-key"` then run sed command per extension docs

### Option B: Google Cloud ADC
1. `gcloud auth login`
2. Set project + enable Stitch MCP API
3. Grant `serviceUsageConsumer` role

---

## MCP Server Capabilities
- `list_projects` — list Stitch projects
- `get_project` — project details
- `get_screens` — all screens in a project  
- `download_assets` — HTML + images
- `generate_screen` — text → UI (Gemini 3 Pro or Flash)
