# Scripted vs Prompted — What Should Be Code vs Instructions

_Date: March 17, 2026_

---

## The Question

Right now, most OrchyStraw intelligence lives in **prompts** (markdown instructions).
The **scripts** handle mechanical orchestration (run agent, commit, detect rogue).

Should critique, debate, quality gates, and decision-making be **scripted** (enforced by code)
or **prompted** (requested in markdown)?

---

## Current Split

### In Scripts (enforced — can't be bypassed)
- ✅ Agent execution order (interval-based scheduling)
- ✅ Usage checking (pause at rate limit)
- ✅ File ownership enforcement (rogue detection)
- ✅ Protected files (immutable list)
- ✅ Git operations (commit per agent, branch management)
- ✅ Cycle counting and state persistence

### In Prompts (requested — agent can ignore)
- ⚠️ Research-First protocol (agent SHOULD check registry before building)
- ⚠️ Proposals to CTO (agent SHOULD submit, but nothing stops them from just building)
- ⚠️ QA review (agent SHOULD write tests, but no gate blocks merge without them)
- ⚠️ Anti-pattern checking (agent SHOULD read anti-patterns, but might not)
- ⚠️ Shared context writing (agent SHOULD update status, but nothing validates)

### The Gap
Everything in the "prompted" category is a suggestion. An agent having a bad day
(hallucinating, confused, or just ignoring instructions) can skip all of it.

---

## What SHOULD Be Scripted (Enforced by Code)

### 1. Quality Gates (block merge until conditions met)

```bash
# After each agent runs, BEFORE committing:
quality_gate() {
    local agent_id=$1
    
    # Gate 1: Did the agent modify ONLY owned files?
    check_ownership "$agent_id" || return 1
    
    # Gate 2: If tests exist, do they pass?
    if [ -d "tests/" ]; then
        run_tests "$agent_id" || {
            log "GATE FAIL: Tests broken by $agent_id"
            git checkout -- .  # Discard changes
            return 1
        }
    fi
    
    # Gate 3: Did the agent write to shared context? (required)
    if ! grep -q "$agent_id" prompts/00-shared-context/context.md; then
        log "WARNING: $agent_id did not update shared context"
        # Don't block — but log it
    fi
    
    # Gate 4: Linting (if linter configured)
    if [ -f ".orchystraw/lint.sh" ]; then
        bash .orchystraw/lint.sh || {
            log "GATE FAIL: Lint errors from $agent_id"
            return 1
        }
    fi
    
    return 0
}
```

### 2. Critique Loop (scripted, not just prompted)

Instead of telling QA to "review" in a prompt, the orchestrator **forces** a review cycle:

```bash
# After worker agent completes, run automated critique
critique_loop() {
    local agent_id=$1
    local max_retries=2
    local attempt=0
    
    while [ $attempt -lt $max_retries ]; do
        # Run QA agent on JUST this agent's changes
        local diff=$(git diff --stat)
        local critique=$(run_agent "09-qa" \
            "Review these changes by $agent_id. Respond APPROVE or REJECT with reasons:
             $diff")
        
        if echo "$critique" | grep -qi "APPROVE"; then
            log "Critique PASSED for $agent_id (attempt $((attempt+1)))"
            return 0
        fi
        
        log "Critique REJECTED for $agent_id — re-running with feedback"
        # Re-run the worker with the critique as context
        run_agent "$agent_id" \
            "Your previous work was rejected by QA. Fix these issues: $critique"
        attempt=$((attempt+1))
    done
    
    log "FAILED: $agent_id could not pass critique after $max_retries attempts"
    git checkout -- .  # Discard
    return 1
}
```

### 3. Research Gate (scripted — must propose before building)

```bash
# Before running a worker on a NEW feature (not a bug fix):
research_gate() {
    local agent_id=$1
    local task_type=$2  # 'feature' or 'fix'
    
    [ "$task_type" = "fix" ] && return 0  # Bug fixes skip research
    
    # Check if this domain has an approved decision
    local domain=$(extract_domain "$agent_id")
    if ! grep -q "$domain" docs/tech-registry/registry.md 2>/dev/null; then
        log "RESEARCH GATE: No approved decision for domain '$domain'"
        log "Running $agent_id in RESEARCH mode (output to proposals.md)"
        
        # Run agent with research-only prompt
        run_agent "$agent_id" \
            "RESEARCH ONLY — do not build. Research 2-3 options for $domain.
             Submit proposal to docs/tech-registry/proposals.md. Do not write code."
        
        return 1  # Don't proceed to build — wait for CTO cycle
    fi
    
    return 0
}
```

### 4. Debate Mode (two agents argue, CTO decides)

```bash
# For major architectural decisions:
debate() {
    local topic=$1
    
    # Agent A argues for
    local pro=$(run_agent "06-backend" \
        "Argue FOR: $topic. Give technical reasons, cost analysis, DX impact.")
    
    # Agent B argues against
    local con=$(run_agent "09-qa" \
        "Argue AGAINST: $topic. Give risks, alternatives, maintenance burden.")
    
    # CTO evaluates both arguments
    local decision=$(run_agent "02-cto" \
        "You have two positions on '$topic':
         PRO: $pro
         CON: $con
         Make a decision. Write ADR to docs/tech-registry/decisions/")
    
    log "DEBATE RESOLVED: $topic → CTO decision written"
}
```

---

## What Should Stay Prompted (Not Scripted)

- Creative work (what to build, how to architect features)
- Code style preferences beyond linting
- Communication tone in shared context
- Priority judgment (which task to tackle first)
- When to escalate to founder

These are judgment calls. Scripts can't enforce taste.

---

## The Right Split

| Concern | Enforcement | Why |
|---------|-------------|-----|
| File ownership | **Scripted** | Agent MUST NOT touch other files. Period. |
| Protected files | **Scripted** | Orchestrator/config are sacred. |
| Test pass before commit | **Scripted** | Broken tests = broken product. No exceptions. |
| Shared context update | **Scripted** (warning) | Team needs visibility. Warn, don't block. |
| Research before build | **Scripted** (gate) | Prevents reinventing wheels. CTO must approve new deps. |
| Critique/QA loop | **Scripted** | Quality floor. Retry or discard. |
| Debate on architecture | **Scripted** (triggered) | Major decisions need structured argument, not one agent deciding. |
| Lint/format | **Scripted** | Consistency. Automated. |
| What to build | **Prompted** | Creative judgment — can't script this. |
| How to solve a problem | **Prompted** | Engineering judgment. |
| Code quality beyond lint | **Prompted** | Taste. |
| Escalation to founder | **Prompted** | Context-dependent. |

---

## Implementation Priority

1. **Quality gates** (test pass before commit) — v0.5
2. **Critique loop** (QA reviews worker output, retry on reject) — v0.5
3. **Research gate** (must have CTO-approved decision before building with new dep) — v0.5
4. **Debate mode** (opt-in, for major architectural decisions) — v1.0
5. **Shared context validation** (warn if agent didn't update) — v0.5

All of these should be in the Python rewrite (v0.5), not bolted onto bash.
The bash version gets the basic quality gate (test pass) and that's it.
