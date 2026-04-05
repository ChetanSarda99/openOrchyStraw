# Active Cron Jobs — Asus Always-On Server

Last updated: 2026-04-01

## System Crontab

| Schedule | Script | Description | Telegram Topic | Thread ID |
|----------|--------|-------------|----------------|-----------|
| `0 */6 * * *` | `~/Automation/reddit-trends.sh` | Reddit trends scrape (every 6h) | macro-news-alpha | 73 |
| `0 6 * * *` | `~/Automation/google-trends.sh` | Google trends scrape (daily 6am) | macro-news-alpha | 73 |
| `30 6 * * 1` | `~/Automation/competitor-scan.sh` | Competitor scan (weekly Monday 6:30am) | General | — |
| `0 23 * * *` | `~/Automation/api-usage-report.sh` | API usage report (daily 11pm) | General | — |
| `5 */6 * * *` | `~/Automation/health-check.sh` | System health check (every 6h +5min) | General | — |
| `40 3 * * 0` | `~/Automation/cleanup-monitoring-logs.sh` | Log cleanup (weekly Sunday 3:40am) | — | — |
| `0 0 * * *` | Uptime Kuma backup | Copy Kuma DB to `~/Projects/uptime-kuma-config/` | — | — |
| `10 5 * * *` | `~/Projects/cron-scripts/morning-briefing.py` | Morning briefing (weather, meds, horoscope) | Morning Briefing | 118 |
| `30 6 * * *` | `~/Projects/cron-scripts/daily-ideas.py` | Daily business ideas → Notion | Daily Ideas | 203 |
| `*/10 * * * *` | `~/Projects/cron-scripts/telegram-watchdog.sh` | Telegram listener watchdog | — | — |

## Claude Code Scheduled Triggers

_None active._

## Telegram Topic Routing Reference

Group chat_id: `-1003847436311`

| Thread ID | Project | Directory |
|-----------|---------|-----------|
| 43 | FinanceOS (hledger) | ~/Projects/FinanceOS |
| 73 | macro-news-alpha | ~/Projects/macro-news-alpha |
| 51 | RedditYT Bot | ~/Projects/RedditYT_Bot |
| 46 | LinkedIn Automation | ~/Projects/LinkedInAutomation |
| 44 | Instagram Automation | ~/Projects/InstagramAutomation |
| 125 | Notes & Ideas | Inbox — log to Notion |
| 126 | Image Inbox | Inbox — process images to Notion |
| 127 | Notion | Notion workspace updates/queries |
| 203 | Daily Ideas | AI-generated business ideas → Notion |
| — | General | No thread ID |

## Log Locations

| Script | Log File |
|--------|----------|
| reddit-trends | `~/Automation/monitoring-logs/reddit-trends.log` |
| google-trends | `~/Automation/monitoring-logs/google-trends.log` |
| competitor-scan | `~/Automation/monitoring-logs/competitor-scan.log` |
| api-usage-report | `~/Automation/monitoring-logs/api-usage-report.log` |
| health-check | `~/Automation/monitoring-logs/health.log` |
| cleanup | `~/Automation/monitoring-logs/cleanup.log` |
| uptime-kuma backup | `/tmp/kuma-backup.log` |
| morning-briefing | `/tmp/morning_cron.log` |
| daily-ideas | `/tmp/daily_ideas.log` |
| telegram-watchdog | `/tmp/telegram-watchdog.log` |

## Output Destinations

| Script | Output |
|--------|--------|
| api-usage-report | `~/Sync/shared-state/api-usage-report.json` |
| health-check | `~/Sync/shared-state/health-status.json` |
| reddit-trends | `~/Automation/research/` |
| google-trends | `~/Automation/research/` |
