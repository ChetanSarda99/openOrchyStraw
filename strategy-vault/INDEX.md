# OrchyStraw Strategy Vault — Index

> Auto-generated index. Every active file, one-line description, clean tree.  
> _Last updated: 2026-03-22_

---

## Root

| File | Description |
|------|-------------|
| `README.md` | Vault overview — start here before starting anything |
| `AGENTS.md` | Codex agent instructions (research & code review role) |
| `CLAUDE.md` | Claude development guide for OrchyStraw |
| `GEMINI.md` | Gemini agent instructions (UI/design/frontend role) |
| `agents.conf` | 13-agent orchestrator config — maps agents to prompts & file ownership |

---

## prompts/

Agent prompt files for the 13-agent OrchyStraw self-development team.

```
prompts/
  00-session-tracker/SESSION_TRACKER.txt   ← Tracks active session state across cycles
  00-shared-context/context.md             ← Shared context injected into all agents
  00-shared-context/usage.txt             ← Usage notes for shared context
  01-ceo/01-ceo.txt                        ← CEO agent: strategy, priorities, CEO updates
  02-cto/02-cto.txt                        ← CTO agent: architecture, tech decisions
  03-pm/03-pm.txt                          ← PM agent: specs, roadmap, sprint planning
  04-tauri-rust/04-tauri-rust.txt          ← Tauri/Rust agent: desktop backend
  05-tauri-ui/05-tauri-ui.txt              ← Tauri UI agent: desktop frontend
  06-backend/06-backend.txt               ← Backend agent: Node.js/API services
  07-ios/07-ios.txt                        ← iOS agent: Swift/SwiftUI mobile app
  08-pixel/08-pixel.txt                    ← Pixel agent: design system & UI components
  09-qa/09-qa.txt                          ← QA agent: testing, anti-patterns, review
  10-security/10-security.txt              ← Security agent: audits & hardening
  11-web/11-web.txt                        ← Web agent: landing page & docs site
  12-brand/12-brand.txt                    ← Brand agent: naming, identity, copy
  13-hr/13-hr.txt                          ← HR agent: norms, onboarding, team health
  99-me/99-actions.txt                     ← CS's direct action prompts
  memo-agents/                             ← Legacy memo-era agent prompts (reference)
```

---

## scripts/

```
scripts/
  auto-agent.sh          ← Main orchestrator loop — runs agents in cycle
  check-domain.sh        ← Domain availability checker
  check-usage.sh         ← AI usage/cost monitoring
  agents.conf.example    ← Example agents.conf with documentation
```

---

## strategy/

The living knowledge base. Organized by domain.

### strategy/app-building/

Core engineering and product-building references.

| File | Description |
|------|-------------|
| `AGENT-DESIGN-REFERENCE.md` | How to write effective agent prompts |
| `ANTI-PATTERNS.md` | Known anti-patterns to avoid — maintained by QA + CTO |
| `API-DESIGN-GUIDE.md` | REST API design conventions and best practices |
| `APP-BUILDING-BEST-PRACTICES.md` | Proven best practices from $2k/month app case study |
| `APP-DESIGN-WORKFLOW.md` | Design-to-code workflow for mobile apps with AI |
| `APP-MINDSET.md` | Mental model and mindset for building Memo |
| `ARCHITECTURE-REFERENCE.md` | How the OrchyStraw orchestrator works |
| `ARCHITECTURE-TEMPLATE.md` | Reusable architecture doc template for new apps |
| `DEPLOYMENT-GUIDE.md` | Production deployment runbook for Node.js on Railway |
| `MVP-PLANNING-GUIDE.md` | Phase-by-phase MVP plan for solo indie apps |

### strategy/app-store/

App Store submission and Apple platform strategy.

| File | Description |
|------|-------------|
| `APP-STORE-REVIEW-CHECKLIST.md` | Pre-TestFlight & pre-submission checklist for Memo |
| `APPLE-INTELLIGENCE-STRATEGY.md` | Strategy for leveraging Apple Intelligence features |

### strategy/brand/

Brand identity, naming, and setup guides.

| File | Description |
|------|-------------|
| `APP-BRANDING.md` | Brand strategy for Memo |
| `BRAND-NAME-SCIENCE.md` | Research-backed principles for memorable brand names |
| `BRAND-SETUP-GUIDE.md` | Two-layer brand setup guide for CS's app empire |
| `NAME-CHANGE-PROPOSAL.md` | Proposal to rename Memo → Rekall (March 2026) |

### strategy/creative/

Creative direction and ad concepts.

| File | Description |
|------|-------------|
| `AD-CONCEPT-TRANSFORMATION.md` | Ad concept: the transformation story for Memo |
| `CREATIVE-FRAMEWORK.md` | Creative framework — all ideas ladder to core transformation promise |

### strategy/marketing/

Marketing plans and growth strategy.

| File | Description |
|------|-------------|
| `MARKETING-PLAN.md` | NoteNest/Memo marketing plan (March 2026) |
| `MARKETING-STRATEGY.md` | Executive marketing strategy for Memo 2026 |
| `MARKETING-STRATEGY-2026.md` | Complete app marketing playbook for Sarda Labs launches |

### strategy/research/

Research guides and accumulated learnings.

| File | Description |
|------|-------------|
| `AI-MODEL-STRATEGY-GUIDE.md` | How to choose, route, and cost-optimize AI models |
| `COMPETITIVE-ANALYSIS-GUIDE.md` | How to research your market before building |
| `FEASIBILITY-CHECKLIST.md` | Pre-build feasibility checklist for new product ideas |
| `KNOWLEDGE-REPOSITORIES.md` | Shared intelligence and learnings across projects |
| `RESEARCH-LEARNINGS.md` | OrchyStraw improvement research and roadmap notes |

### strategy/stacks/

Approved tech stacks for each layer of the system.

| File | Description |
|------|-------------|
| `DOCS-STACK.md` | Documentation site stack reference (for agent 11-web) |
| `LANDING-PAGE-STACK.md` | Landing page stack reference (for agent 11-web) |
| `TAURI-STACK.md` | Tauri desktop app stack reference (agents 04, 05) |
| `TECH-STACK-GUIDE.md` | Tech stack decision guide for indie apps (2026) |

### strategy/team/

Team norms, conventions, and contribution guides.

| File | Description |
|------|-------------|
| `CONTRIBUTING.md` | Contribution guide for the Memo project |
| `CONVENTIONS.md` | Code style and naming conventions |

---

## templates/

Reusable templates, organized by category.

### templates/project/

Drop-in AI agent instruction files for new projects.

| File | Description |
|------|-------------|
| `AGENTS-TEMPLATE.md` | Template for multi-agent AGENTS.md setup |
| `CLAUDE-TEMPLATE.md` | Template for CLAUDE.md project instructions |
| `GEMINI-TEMPLATE.md` | Template for GEMINI.md design agent instructions |

### templates/planning/

Planning and decision-tracking templates.

| File | Description |
|------|-------------|
| `ADR-TEMPLATE.md` | Architecture Decision Record (ADR) template |
| `CEO-UPDATE-TEMPLATE.md` | CEO cycle update template |
| `DECISION-LOG-TEMPLATE.md` | Decision log / ADR tracker for a new app |
| `PRODUCT-SPEC.md` | Product specification template |

### templates/technical/

Technical reference and analysis templates.

| File | Description |
|------|-------------|
| `COMPETITIVE-ANALYSIS.md` | Competitive analysis template |
| `TECH-REGISTRY-TEMPLATE.md` | Tech stack registry template (single source of truth) |

### templates/team/

Team and agent onboarding templates.

| File | Description |
|------|-------------|
| `NORMS-TEMPLATE.md` | Team norms & conventions template |
| `ONBOARDING-TEMPLATE.md` | Agent/team member onboarding guide template |

---

## archive/

Historical and superseded content. Read-only reference.

```
archive/
  FIGMA_MCP_SETUP.md             ← Figma MCP setup notes (superseded)
  LIFE_CATEGORIZATION_SYSTEM.md  ← Early life categorization system
  MACBOOK_MIGRATION.md           ← MacBook migration notes
  README.md                      ← Archive index
  duplicates/                    ← Files deduplicated during vault reorganization
  memo-originals/                ← Original Memo-era agent files
  memo/                          ← Memo context snapshots
  orchystraw-originals/          ← Original OrchyStraw architecture, cycles, research
  rekall-originals/              ← Original Rekall specs and research
```
