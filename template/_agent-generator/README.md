# Agent Generator Template

This directory contains the template the **Co-Founder agent** uses to spawn new agents on demand.

## How it works

When the user (via chat) asks the Co-Founder to create a new agent:
1. Co-Founder generates an agent ID (e.g., `14-data-pipeline`)
2. Reads `agent-template.txt`
3. Substitutes placeholders with the user's specs
4. Writes the new prompt to `prompts/<agent-id>/<agent-id>.txt`
5. Adds an entry to `agents.conf`
6. Reloads the agent registry
7. Confirms back to the user in chat

## Placeholders

| Placeholder | Description |
|-------------|-------------|
| `{{AGENT_LABEL}}` | Display name (e.g., "Data Pipeline Engineer") |
| `{{ROLE_DESCRIPTION}}` | One-line role summary |
| `{{PROJECT_NAME}}` | Current project name |
| `{{CREATED_DATE}}` | Today's date (ISO) |
| `{{REASON_FOR_CREATION}}` | Why this agent was needed (from user request) |
| `{{OWNED_PATHS}}` | Markdown list of owned file paths |
| `{{INITIAL_TASK}}` | First task description |

## Example: User says "Create an agent for our data pipelines"

Co-Founder generates:
- **id:** `14-data-pipeline`
- **label:** Data Pipeline Engineer
- **owns:** `pipelines/`, `etl/`, `dags/`
- **interval:** 2 (every 2 cycles)

Then writes:
- `prompts/14-data-pipeline/14-data-pipeline.txt` (from this template)
- Adds line to `agents.conf`
- Confirms: "Created 14-data-pipeline. It will run every 2 cycles starting next cycle."

## Constraints

The Co-Founder MUST:
- Validate the agent ID format (`NN-name`)
- Ensure no path conflicts with existing agents
- Set sensible interval (1-5)
- Get user confirmation before saving
- Document creation in `docs/operations/COFOUNDER-PLAYBOOK.md`
