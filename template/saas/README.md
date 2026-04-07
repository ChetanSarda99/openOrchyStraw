# SaaS Template

Full SaaS application template for OrchyStraw multi-agent orchestration.

## Agents Included

- **CEO** — Vision, strategy, market positioning
- **CTO** — Architecture decisions, tech standards, code review
- **PM** — Coordination, task management, backlog prioritization
- **Backend Developer** — API, business logic, database, services
- **Frontend Developer** — UI components, pages, styling, UX
- **QA Engineer** — Testing, code quality, bug reports
- **Security Auditor** — Threat modeling, vulnerability scanning, compliance

## When to Use

Use this template when building a SaaS product with both frontend and backend
components. Suitable for web apps, dashboards, platforms, and B2B/B2C SaaS products.

## Usage

```bash
./scripts/auto-agent.sh init --template saas my-saas-project
```

## Customization

After initialization, edit `agents.conf` to adjust:
- Agent intervals (how often each agent runs)
- File ownership paths (what each agent can modify)
- Add or remove agents as needed
