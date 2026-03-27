# ADR: [ID]-[SHORT-NAME] — [Decision Title]

_Date: YYYY-MM-DD_
_Status: PROPOSED | APPROVED | SUPERSEDED_
_Author: [Role or person]_
_Supersedes: [ADR-ID if applicable]_

---

## Context

[1-3 sentences: what situation or problem triggered this decision? What constraints or pressures exist?]

---

## Decision

**[One clear sentence stating what was decided.]**

---

## Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-----------------|
| [Option A] | [pro] | [con] | [reason] |
| [Option B] | [pro] | [con] | [reason] |
| [Chosen option] | [pro] | [con] | — (chosen) |

---

## Rationale

[Why does the chosen option win? Be specific. Reference constraints from Context. What would have to be true for a different option to have won?]

---

## Consequences

**Positive:**
- [What this enables or simplifies]

**Negative / Trade-offs:**
- [What this constrains or costs]

**Future decisions triggered:**
- [Does this require follow-up ADRs? Which areas are now locked?]

---

## Actions Required

| Action | Owner | Priority | Status |
|--------|-------|----------|--------|
| [Implementation step] | [Role] | P0/P1/P2 | OPEN / DONE |
| [Documentation update] | [Role] | P1 | OPEN |

---

## Review Trigger

This decision should be revisited if:
- [Condition A — e.g., "user count exceeds 10K"]
- [Condition B — e.g., "pricing for X changes by >50%"]

---

## Naming Convention

ADR IDs use domain prefixes:

| Prefix | Domain | Examples |
|--------|--------|---------|
| `ARCH-` | Core architecture | ARCH-001-api-structure |
| `DB-` | Database | DB-001-vector-store |
| `AUTH-` | Authentication | AUTH-001-provider |
| `AI-` | AI/ML services | AI-001-llm-selection |
| `UI-` | Frontend/UI | UI-001-framework |
| `INFRA-` | Infrastructure | INFRA-001-hosting |
| `OWN-` | File/code ownership | OWN-001-agent-boundaries |
| `SEC-` | Security | SEC-001-token-storage |
| `DOCS-` | Documentation | DOCS-001-system |

Format: `PREFIX-NNN-short-slug.md`
