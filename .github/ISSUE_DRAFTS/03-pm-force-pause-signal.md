---
title: "[FEAT] PM needs a force-pause signal, not just text recommendations"
labels: enhancement, orchestrator, P1
---

## Problem

The PM agent repeatedly wrote "RECOMMEND: pause orchestrator" in its reports (cycles 1-5 session 6) but the orchestrator kept running. PM can only recommend in prose — there's no mechanism to actually stop the cycle loop from an agent.

## Proposal

Create a file-based pause protocol:

1. Any agent can create `.orchestrator-pause` at repo root with a reason
2. The orchestrator checks for this file at the start of each cycle
3. If present: log the reason, alert CS via Telegram, exit cleanly
4. CS removes the file manually to resume

```bash
# Agent code:
echo "PM: 5 idle cycles, CTO queue blocked" > .orchestrator-pause

# Orchestrator code (auto-agent.sh, start of cycle loop):
if [[ -f .orchestrator-pause ]]; then
    echo "Orchestrator paused: $(cat .orchestrator-pause)"
    send_telegram_alert "$(cat .orchestrator-pause)"
    exit 0
fi
```

## Related

- Pairs with issue #1 (stall detector) — stall detector can also create the pause file
- Would have prevented the 21+ idle cycle run
