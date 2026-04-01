#!/usr/bin/env bash
# health-dashboard.sh — Generate a self-contained HTML health dashboard
# Reads .orchystraw/metrics.jsonl + .orchystraw/audit.jsonl and produces
# a single HTML file with: agent status grid, cycle velocity chart,
# cost per agent bar chart, issue count trend.
#
# Usage: bash scripts/health-dashboard.sh [project_root] [output_file]
# Opens in browser via xdg-open when OUTPUT is not piped.

set -euo pipefail

PROJECT_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
OUTPUT="${2:-$PROJECT_ROOT/.orchystraw/dashboard.html}"
METRICS_FILE="$PROJECT_ROOT/.orchystraw/metrics.jsonl"
AUDIT_FILE="$PROJECT_ROOT/.orchystraw/audit.jsonl"
CONF_FILE="$PROJECT_ROOT/scripts/agents.conf"
STATE_FILE="$PROJECT_ROOT/.orchystraw/router-state.txt"

mkdir -p "$(dirname "$OUTPUT")"

# ── Parse agents.conf ──
declare -a AGENTS=()
declare -A AGENT_LABELS=()
declare -A AGENT_INTERVALS=()

while IFS='|' read -r id prompt ownership interval label rest; do
    [[ "$id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${id// /}" ]] && continue
    id=$(echo "$id" | xargs)
    label=$(echo "$label" | xargs)
    interval=$(echo "$interval" | xargs)
    AGENTS+=("$id")
    AGENT_LABELS["$id"]="$label"
    AGENT_INTERVALS["$id"]="$interval"
done < "$CONF_FILE"

# ── Parse router state ──
declare -A AGENT_STATUS=()
declare -A AGENT_LAST_RUN=()
declare -A AGENT_STREAK=()

if [[ -f "$STATE_FILE" ]]; then
    while IFS='|' read -r id _path outcome eff_int streak; do
        [[ "$id" =~ ^# ]] && continue
        [[ -z "$id" ]] && continue
        AGENT_STATUS["$id"]="$outcome"
        AGENT_STREAK["$id"]="$streak"
    done < "$STATE_FILE"
fi

# ── Parse audit.jsonl → per-agent totals ──
declare -A A_INV=()
declare -A A_DUR=()
declare -A A_TOK=()
declare -A A_FILES=()

if [[ -f "$AUDIT_FILE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        agent="" dur=0 tok=0 files=0
        prev=""
        for field in $(echo "$line" | tr '{},:"' ' '); do
            case "$prev" in
                agent) agent="$field" ;;
                duration_s) dur="$field" ;;
                tokens_est) tok="$field" ;;
                files) files="$field" ;;
            esac
            prev="$field"
        done
        if [[ -n "$agent" ]]; then
            A_INV["$agent"]=$(( ${A_INV["$agent"]:-0} + 1 ))
            A_DUR["$agent"]=$(( ${A_DUR["$agent"]:-0} + dur ))
            A_TOK["$agent"]=$(( ${A_TOK["$agent"]:-0} + tok ))
            A_FILES["$agent"]=$(( ${A_FILES["$agent"]:-0} + files ))
        fi
    done < "$AUDIT_FILE"
fi

# ── Parse metrics.jsonl → cycle data ──
declare -a M_CYCLES=()
declare -a M_COMMITS=()
declare -a M_ISSUES=()
declare -a M_TS=()

if [[ -f "$METRICS_FILE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        cycle=0 commits=0 issues="0" ts=""
        prev=""
        for field in $(echo "$line" | tr '{},:"' ' '); do
            case "$prev" in
                cycle) cycle="$field" ;;
                commits) commits="$field" ;;
                issues_open) issues="$field" ;;
                ts) ts="$field" ;;
            esac
            prev="$field"
        done
        M_CYCLES+=("$cycle")
        M_COMMITS+=("$commits")
        M_ISSUES+=("${issues//[^0-9]/}")
        M_TS+=("$ts")
    done < "$METRICS_FILE"
fi

# ── Build agent grid rows ──
agent_grid_rows=""
for id in "${AGENTS[@]}"; do
    status="${AGENT_STATUS[$id]:-unknown}"
    label="${AGENT_LABELS[$id]:-}"
    interval="${AGENT_INTERVALS[$id]:-?}"
    inv="${A_INV[$id]:-0}"
    dur="${A_DUR[$id]:-0}"
    tok="${A_TOK[$id]:-0}"
    files="${A_FILES[$id]:-0}"
    streak="${AGENT_STREAK[$id]:-0}"

    case "$status" in
        success) color="#22c55e" ;;
        fail)    color="#ef4444" ;;
        skip)    color="#eab308" ;;
        *)       color="#6b7280" ;;
    esac

    agent_grid_rows+="<tr>
<td><span style=\"display:inline-block;width:10px;height:10px;border-radius:50%;background:${color};margin-right:6px\"></span>${id}</td>
<td>${label}</td>
<td>${interval}</td>
<td>${status}</td>
<td>${inv}</td>
<td>${dur}s</td>
<td>${tok}</td>
<td>${files}</td>
<td>${streak}</td>
</tr>"
done

# ── Build cycle velocity JSON arrays ──
cycle_labels=""
cycle_commits=""
cycle_issues=""
for i in "${!M_CYCLES[@]}"; do
    [[ $i -gt 0 ]] && { cycle_labels+=","; cycle_commits+=","; cycle_issues+=","; }
    cycle_labels+="\"C${M_CYCLES[$i]}\""
    cycle_commits+="${M_COMMITS[$i]}"
    issue_val="${M_ISSUES[$i]:-0}"
    cycle_issues+="${issue_val:-0}"
done

# ── Build cost-per-agent JSON arrays ──
cost_labels=""
cost_values=""
first=1
for id in "${AGENTS[@]}"; do
    [[ $first -eq 0 ]] && { cost_labels+=","; cost_values+=","; }
    first=0
    cost_labels+="\"${id}\""
    cost_values+="${A_TOK[$id]:-0}"
done

# ── Write HTML ──
cat > "$OUTPUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OrchyStraw Health Dashboard</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter',system-ui,sans-serif;background:#0a0a0a;color:#e5e5e5;padding:24px}
h1{font-size:1.5rem;margin-bottom:4px;color:#fff}
.subtitle{color:#a3a3a3;font-size:.85rem;margin-bottom:24px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:24px}
.card{background:#171717;border:1px solid #262626;border-radius:8px;padding:16px}
.card h2{font-size:1rem;color:#d4d4d4;margin-bottom:12px}
table{width:100%;border-collapse:collapse;font-size:.8rem}
th{text-align:left;padding:6px 8px;border-bottom:1px solid #333;color:#a3a3a3;font-weight:500}
td{padding:6px 8px;border-bottom:1px solid #1f1f1f}
canvas{width:100%!important;max-height:220px}
.full{grid-column:1/-1}
</style>
</head>
<body>
<h1>OrchyStraw Health Dashboard</h1>
HTMLEOF

printf '<p class="subtitle">Generated: %s</p>\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT"

cat >> "$OUTPUT" << TABLEEOF
<div class="grid">
<div class="card full">
<h2>Agent Status Grid</h2>
<table>
<tr><th>Agent</th><th>Label</th><th>Interval</th><th>Status</th><th>Invocations</th><th>Wall-Clock</th><th>Est. Tokens</th><th>Files Changed</th><th>Empty Streak</th></tr>
${agent_grid_rows}
</table>
</div>

<div class="card">
<h2>Cycle Velocity (Commits)</h2>
<canvas id="velocityChart"></canvas>
</div>

<div class="card">
<h2>Cost per Agent (Est. Tokens)</h2>
<canvas id="costChart"></canvas>
</div>

<div class="card full">
<h2>Open Issues Trend</h2>
<canvas id="issueChart"></canvas>
</div>
</div>

<script>
// Minimal canvas chart renderer — no external dependencies
function drawBarChart(canvasId, labels, data, color) {
    var c = document.getElementById(canvasId);
    var ctx = c.getContext('2d');
    var dpr = window.devicePixelRatio || 1;
    var w = c.parentElement.clientWidth - 32;
    var h = 200;
    c.width = w * dpr; c.height = h * dpr;
    c.style.width = w + 'px'; c.style.height = h + 'px';
    ctx.scale(dpr, dpr);

    var max = Math.max.apply(null, data) || 1;
    var barW = Math.max(8, (w - 40) / data.length - 4);
    var offsetX = 36;

    ctx.fillStyle = '#a3a3a3'; ctx.font = '10px system-ui';
    for (var g = 0; g <= 4; g++) {
        var y = h - 20 - (g / 4) * (h - 36);
        ctx.fillText(Math.round(max * g / 4), 0, y + 3);
        ctx.strokeStyle = '#262626'; ctx.beginPath();
        ctx.moveTo(offsetX, y); ctx.lineTo(w, y); ctx.stroke();
    }

    for (var i = 0; i < data.length; i++) {
        var bh = (data[i] / max) * (h - 36);
        var x = offsetX + i * (barW + 4);
        ctx.fillStyle = color;
        ctx.fillRect(x, h - 20 - bh, barW, bh);
        ctx.fillStyle = '#a3a3a3'; ctx.font = '9px system-ui';
        ctx.save(); ctx.translate(x + barW / 2, h - 4);
        ctx.rotate(-0.5); ctx.fillText(labels[i], 0, 0);
        ctx.restore();
    }
}

function drawLineChart(canvasId, labels, data, color) {
    var c = document.getElementById(canvasId);
    var ctx = c.getContext('2d');
    var dpr = window.devicePixelRatio || 1;
    var w = c.parentElement.clientWidth - 32;
    var h = 200;
    c.width = w * dpr; c.height = h * dpr;
    c.style.width = w + 'px'; c.style.height = h + 'px';
    ctx.scale(dpr, dpr);

    var max = Math.max.apply(null, data) || 1;
    var offsetX = 36;
    var plotW = w - offsetX - 10;

    ctx.fillStyle = '#a3a3a3'; ctx.font = '10px system-ui';
    for (var g = 0; g <= 4; g++) {
        var y = h - 20 - (g / 4) * (h - 36);
        ctx.fillText(Math.round(max * g / 4), 0, y + 3);
        ctx.strokeStyle = '#262626'; ctx.beginPath();
        ctx.moveTo(offsetX, y); ctx.lineTo(w, y); ctx.stroke();
    }

    ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath();
    for (var i = 0; i < data.length; i++) {
        var x = offsetX + (data.length > 1 ? i * plotW / (data.length - 1) : plotW / 2);
        var py = h - 20 - (data[i] / max) * (h - 36);
        if (i === 0) ctx.moveTo(x, py); else ctx.lineTo(x, py);
        ctx.fillStyle = color;
        ctx.fillRect(x - 3, py - 3, 6, 6);
    }
    ctx.stroke();

    ctx.fillStyle = '#a3a3a3'; ctx.font = '9px system-ui';
    for (var i = 0; i < labels.length; i++) {
        var x = offsetX + (data.length > 1 ? i * plotW / (data.length - 1) : plotW / 2);
        ctx.fillText(labels[i], x - 8, h - 4);
    }
}

var cycleLabels = [${cycle_labels}];
var cycleCommits = [${cycle_commits}];
var cycleIssues = [${cycle_issues}];
var costLabels = [${cost_labels}];
var costValues = [${cost_values}];

if (cycleLabels.length > 0) drawBarChart('velocityChart', cycleLabels, cycleCommits, '#3b82f6');
if (costLabels.length > 0) drawBarChart('costChart', costLabels, costValues, '#f97316');
if (cycleLabels.length > 0) drawLineChart('issueChart', cycleLabels, cycleIssues, '#22c55e');
</script>
</body>
</html>
TABLEEOF

echo "Dashboard written to: $OUTPUT"

if [[ -t 1 ]] && command -v xdg-open &>/dev/null; then
    xdg-open "$OUTPUT" 2>/dev/null &
fi
