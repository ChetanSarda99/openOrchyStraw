# API Service Template

Backend API service template for OrchyStraw multi-agent orchestration.

## Agents Included

- **CTO** — Architecture decisions, API design, tech standards
- **PM** — Coordination, task management, backlog prioritization
- **Backend Developer** — API endpoints, business logic, database, services
- **QA Engineer** — Testing, code quality, bug reports
- **Security Auditor** — Threat modeling, vulnerability scanning, auth review

## When to Use

Use this template when building a backend API service, microservice, or
REST/GraphQL API without a frontend component. Suitable for internal services,
public APIs, webhooks, and data processing services.

## Usage

```bash
./scripts/auto-agent.sh init --template api my-api-service
```

## Customization

After initialization, edit `agents.conf` to adjust:
- Agent intervals (how often each agent runs)
- File ownership paths (what each agent can modify)
- Add a frontend agent if you later need UI
