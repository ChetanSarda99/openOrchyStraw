# {{PROJECT_NAME}} — Development Guide

## Project Overview
{{PROJECT_NAME}} is a content project managed by OrchyStraw multi-agent orchestration.
Focused on content creation, editorial workflow, and design assets.

## Agent Team

| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 01-ceo | CEO | docs/strategy/ | 3 | Content strategy & brand voice |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Editorial coordination, runs LAST |
| 06-content | Content Writer | content/ articles/ copy/ | 1 | Writing & editorial |
| 07-designer | Designer | assets/ designs/ styles/ | 1 | Visual design & assets |
| 09-qa | QA Reviewer | reports/ | 3 | Quality review & fact-checking |

## File Structure
```
agents.conf              — Agent configuration
CLAUDE.md                — This file (project guide for all agents)
prompts/                 — All agent prompts and shared context
  00-shared-context/     — Cross-agent communication (reset each cycle)
content/                 — Written content (articles, blog posts, docs)
articles/                — Published articles
copy/                    — Marketing copy, landing pages, emails
assets/                  — Images, icons, brand assets
designs/                 — Design specs, mockups
styles/                  — Style guides, brand guidelines
docs/                    — Documentation
  strategy/              — Content strategy, editorial calendar
reports/                 — QA review reports
```

## Rules
1. **Read your prompt first** — it has your current tasks
2. **Stay in your lane** — respect file ownership in agents.conf
3. **Write to shared context** — prompts/00-shared-context/ for cross-agent communication
4. **Never touch git branch operations** — orchestrator handles that
5. **Maintain brand voice** — follow CEO's brand and content guidelines
