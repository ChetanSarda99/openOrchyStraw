---
title: "[FEAT] Telegram alerts for orchestrator events"
labels: enhancement, observability, P2
---

## Proposal

Wire `~/Projects/shared/scripts/send-telegram.sh` into the orchestrator to send alerts on key events so CS can monitor from mobile without logging in.

## Events to Alert On

1. **Orchestrator pause** — either manual (`.orchestrator-pause` file) or auto (stall detector)
2. **Agent failures** — when any agent exits non-zero
3. **CTO queue items added** — so CS can batch-approve quickly
4. **Session complete** — summary of cycles, commits, idle detection
5. **API quota warnings** — when approaching rate limits

## Alert Format

Short message with repo + cycle context:
```
[openOrchyStraw] cycle 7 PAUSED: stall detector (3 idle cycles)
[openOrchyStraw] CTO queue now has 5 items — review needed
```

Route to Telegram topic 129 (or a new "infra alerts" topic).

## Implementation

- Add `src/core/notify.sh` wrapper around send-telegram.sh
- Add notify calls at critical points in auto-agent.sh
- Rate-limit: max 1 alert per 10 min to avoid spam

## Related

- Pairs with issues #1 (stall detector) and #3 (force pause)
