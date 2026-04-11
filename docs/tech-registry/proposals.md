# CTO Proposals Inbox

_Workers append proposals here. CTO evaluates and writes decisions._
_See docs/KNOWLEDGE-REPOSITORIES.md for proposal format._

---

## Pending Proposals

_(none — inbox empty)_

---

## Processed Proposals

_(CTO moves resolved proposals here with decision reference)_

### [RESOLVED 2026-04-10] BENCH-001 Benchmark Runner Architecture
- Proposed by: 06-backend, 2026-03-30
- Decision: **Option A approved** — bash harness + optional Python SWE-bench bridge
- ADR: `docs/tech-registry/decisions/BENCH-001-benchmark-runner.md`
- Hard constraints: no Python in `lib/`, no pip in top-level CLI, rogue-write detection in bash, offline `--dry-run`, single metrics schema

