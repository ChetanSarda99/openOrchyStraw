# DOCS-001: Documentation Site

_Decision Date: 2026-03-17_
_Status: APPROVED (LOCKED)_
_Decided By: CTO + Founder_

---

## Domain
Documentation Site — Platform, structure, theming

## Decision
Mintlify (same platform as Claude Code docs, Conductor docs, Anthropic API docs)

## Setup
```bash
npm install -g mintlify
cd site/docs && mintlify init && mintlify dev
```

## Rationale
- Industry standard for developer docs — used by Anthropic, Conductor, and many others
- MDX content format is familiar and version-controllable
- Built-in components: Card, Tabs, Accordion, CodeGroup, Steps
- MCP server available for AI-assisted doc writing
- Free tier sufficient for open-source project

## Theme
- Primary: #F97316 (orange)
- Dark background: #0a0a0a (shared with Tauri + landing page)

## Content Structure
introduction → quickstart → configuration → writing-prompts → shared-context → auto-cycle → examples → FAQ

## Alternatives Considered
- **Nextra**: Good but less polished, no built-in search quality
- **Docusaurus**: Heavier, React-based, overkill for markdown docs

## Reversibility
High — content is MDX/Markdown. Can migrate to any docs platform.
