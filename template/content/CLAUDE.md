# {{PROJECT_NAME}} — Development Guide

## Project Overview
{{PROJECT_NAME}} is a content/marketing project managed by OrchyStraw multi-agent orchestration.
Focused on content creation, editorial workflow, brand voice, visual design, and audience growth.

## Agent Team

| ID | Role | Owns | Interval | Notes |
|----|------|------|----------|-------|
| 01-ceo | CEO | docs/strategy/ | 3 | Content strategy, brand voice, audience, growth |
| 03-pm | PM | prompts/ docs/ | 0 (last) | Editorial coordination, content pipeline, runs LAST |
| 06-content | Content Writer | content/ articles/ copy/ | 1 | All written content — posts, articles, scripts, captions |
| 07-designer | Designer | assets/ designs/ styles/ | 1 | Visual design — carousels, graphics, thumbnails, brand |
| 09-qa | QA Reviewer | reports/ | 3 | Content quality, grammar, brand voice, fact-checking |

## File Structure
```
agents.conf              — Agent configuration
CLAUDE.md                — This file (project guide for all agents)
prompts/                 — All agent prompts and shared context
  00-shared-context/     — Cross-agent communication (reset each cycle)
  01-ceo/ .. 09-qa/      — Individual agent prompts
  99-me/                 — Human action items (escalations)
content/                 — Written content (articles, blog posts, docs)
articles/                — Published articles
copy/                    — Marketing copy, landing pages, emails
assets/                  — Images, icons, brand assets (exports)
designs/                 — Design specs, mockups, source files
styles/                  — Brand guide, style documentation
docs/                    — Documentation
  strategy/              — Content strategy, brand voice, audience, competitive analysis, growth
reports/                 — QA review reports
```

## Quality Pipeline

Every piece of content follows this research-first workflow:
1. **Strategy** — CEO sets direction, topics, and brand voice in `docs/strategy/`
2. **Brief** — PM writes a content brief and assigns to Content Writer and Designer
3. **Research** — Content Writer researches the topic online. Designer references design guides. NEVER write from training data alone.
4. **Create** — Content Writer drafts the piece. Designer creates visual assets.
5. **QA Review** — 09-qa reviews for brand voice, grammar, facts, platform compliance, visual quality
6. **Revise** — Writer and Designer address QA feedback
7. **Final** — PM marks as ready for publication

## Shared Reference Documents

All agents must check these before making decisions in their domain:

| Document | Path | Used By |
|----------|------|---------|
| Best Practices | `~/Projects/shared/docs/BEST-PRACTICES-2026.md` | All agents |
| Viral Content Strategy | `~/Projects/shared/docs/VIRAL-CONTENT-STRATEGY-2026.md` | CEO, Content Writer |
| Carousel Design Guide | `~/Projects/shared/docs/CAROUSEL-DESIGN-GUIDE-2026.md` | Designer, QA |
| Landing Page Design | `~/Projects/shared/docs/LANDING-PAGE-DESIGN-GUIDE-2026.md` | Designer (web assets) |

## Content Quality Standards

- Every piece matches CEO's brand voice guidelines
- All facts verified with current online sources (not training data)
- Content formatted for the target platform (length, structure, hashtags, SEO)
- Visual assets match brand guide (colors, fonts, dimensions)
- Carousel slides follow the carousel design guide
- Hook grabs attention in the first line/slide
- CTA is clear and appropriately placed
- Content frontmatter filled out completely (title, date, platform, status, persona)

## Rules

1. **Read your prompt first** — it has your current tasks and role boundaries
2. **Research before creating** — use WebSearch for current trends, facts, competitor content
3. **Stay in your lane** — respect file ownership in agents.conf
4. **Write to shared context** — prompts/00-shared-context/ for cross-agent communication
5. **Never touch git branch operations** — orchestrator handles that
6. **Use Edit, not Write** — for prompt updates (preserve structure)
7. **Follow the brand voice** — CEO's voice guidelines are law
8. **Reference the design guides** — before creating any visual content
9. **Flag blockers** — write to prompts/99-me/ for human intervention needs
10. **Check PM's assignments** — PM's content briefs are your work queue
