# Pattern Analysis — What Orchystraw's PM Loop Maps To
**Last Updated:** March 16, 2026  
**Author:** CS + Chai

---

## The Insight

Orchystraw's PM cycle isn't novel. It implements some of the most validated coordination patterns in human history. What's novel is doing it with markdown + bash for AI agents, when everyone else is building custom Python frameworks.

---

## Exact Pattern Matches

### OODA Loop (John Boyd, military strategy)
Observe → Orient → Decide → Act

PM observes (reads shared context), orients (compares to project goals), decides (what each agent should do next), acts (writes new standing orders into prompt files). Military command & control. Closest 1:1 match.

### PDCA / Deming Cycle (lean manufacturing)
Plan → Do → Check → Act

Workers Do. PM Checks (reads shared context). PM Acts (writes new prompts). Next cycle Plans (agents read fresh prompts). Toyota Production System. CS knows this from FMCG/mechanical engineering background.

### Scrum Sprint (agile)
Sprint Planning → Work → Review → Retro → Next Sprint

Each Orchystraw cycle = a sprint. PM = Scrum Master + Product Owner. Shared context = standup notes. Standing orders = sprint backlog. Difference: sprints are 2 weeks; cycles are 5 minutes.

---

## Architecture Matches

### Blackboard Architecture (AI, 1980s)
Multiple specialist "knowledge sources" independently read from and write to a shared blackboard. A controller decides who runs next.

**This is exactly Orchystraw:**
- Shared context = the blackboard
- PM = the controller
- Workers = knowledge sources
- Origin: Hearsay-II speech recognition (Carnegie Mellon, 1970s)
- One of the oldest multi-agent patterns in AI research

### Stigmergy (Biology — ant colonies)
Agents don't communicate directly. They modify a shared environment. Other agents read the modifications and respond.

Ants leave pheromone trails → other ants follow. Orchystraw agents write to shared context → other agents read and build on it. Indirect coordination through a shared medium. No message-passing needed.

### Hub-and-Spoke (Logistics / networking)
Workers never talk to each other. Everything routes through PM. Deliberately NOT a mesh.

Google DeepMind paper "Towards a Science of Scaling Agent Systems" (Dec 2025) proved that mesh topology multiplies errors in multi-agent systems. Hierarchy reduces them. Orchystraw chose the right topology.

### MapReduce (Google, 2004)
Workers = Map phase (parallel, independent, each processes its slice). PM = Reduce phase (aggregates results, produces synthesized output). Next cycle = new Map.

Distributed computing's most proven pattern for parallel work.

---

## Software Engineering Matches

### Redux / Flux (Facebook, 2014)
- Single source of truth = shared context (the store)
- Workers = reducers (take state + action → new state)
- PM = dispatcher (decides what actions to send)
- Unidirectional data flow (workers write → PM reads → PM writes → workers read)

### Event Sourcing
- Shared context = append-only event log
- Each agent reads the log, decides what to do
- PM compresses/summarizes old entries
- The log IS the system of record

### Hollywood Principle
"Don't call us, we'll call you." Workers don't request work — PM assigns it by writing into their prompt files. Workers just execute whatever's in front of them.

### REPL (Read-Eval-Print Loop)
Each agent REPLs: Read prompt → Evaluate (code) → Print to shared context → Loop (PM writes next prompt). The system is a REPL of REPLs.

---

## Management / Organizational Theory

### Span of Control (Henri Fayol, 1916)
Each manager should oversee 5-7 direct reports. Orchystraw's PM manages 3-5 worker agents. Exceeding this = PM prompt gets too long = context overload. Same constraint, different century.

### Management by Objectives (Peter Drucker, 1954)
Manager sets objectives → workers execute autonomously → results reviewed at end of period. PM writes objectives in prompt files → workers code autonomously → PM reviews via shared context. This IS MBO.

### Toyota Production System / Kanban
Work pulled from a board. WIP limits. Continuous flow.
- Shared context = Kanban board
- File ownership = WIP limits (each agent has a lane)
- PM = team lead moving cards

---

## What This Means

Every multi-agent framework (CrewAI, AutoGen, MetaGPT, LangGraph) reinvents coordination from scratch with custom Python orchestration. They build complex infrastructure to solve a problem that was solved decades ago.

Orchystraw doesn't reinvent anything. It implements the blackboard pattern (1970s AI), the OODA loop (1960s military), and the Deming cycle (1950s manufacturing) — using markdown files and a bash script.

**The simplicity IS the insight.** The most validated coordination patterns in history don't need a framework. They need a convention.
