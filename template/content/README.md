# Content Project Template

Content creation and editorial workflow template for OrchyStraw multi-agent orchestration.

## Agents Included

- **CEO** — Content strategy, brand voice, editorial direction
- **PM** — Editorial calendar, coordination, task management
- **Content Writer** — Articles, blog posts, documentation, marketing copy
- **Designer** — Visual assets, brand guidelines, design specs
- **QA Reviewer** — Fact-checking, grammar, consistency, quality review

## When to Use

Use this template for content-heavy projects: blogs, documentation sites,
marketing campaigns, editorial workflows, knowledge bases, and content libraries.

## Usage

```bash
./scripts/auto-agent.sh init --template content my-content-project
```

## Customization

After initialization, edit `agents.conf` to adjust:
- Agent intervals (how often each agent runs)
- File ownership paths (what each agent can modify)
- Add a developer agent if you need code alongside content
