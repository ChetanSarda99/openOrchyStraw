# Issue Drafts

These are drafts for GitHub issues that haven't been pushed yet (gh CLI not authenticated on Asus). Each file has frontmatter with title + labels.

## To Create Issues

Once gh is authenticated, run:
```bash
for f in .github/ISSUE_DRAFTS/[0-9]*.md; do
  title=$(grep -oP '^title: "\K[^"]+' "$f")
  labels=$(grep -oP '^labels: \K.*' "$f" | tr ',' '\n' | xargs -I{} echo -n "--label={} ")
  body=$(sed '1,/^---$/d; 1,/^---$/d' "$f")
  gh issue create --title "$title" $labels --body "$body"
done
```

Or create them manually in the GitHub UI by copying each file's content.

## Priority

P0 (critical, created first):
- 01-stall-detector-integration.md
- 02-cto-output-protocol.md

P1:
- 03-pm-force-pause-signal.md
- 04-wire-v02-modules.md

P2:
- 05-telegram-alerts.md
