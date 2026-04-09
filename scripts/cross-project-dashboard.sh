#!/usr/bin/env bash
# cross-project-dashboard.sh — Generate HTML dashboard across all registered projects
# Reads ~/.orchystraw/registry.jsonl and each project's .orchystraw/ data.
# Outputs to ~/.orchystraw/dashboard.html

set -uo pipefail

ORCH_ROOT="${ORCH_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REGISTRY_DIR="$HOME/.orchystraw"
REGISTRY_FILE="$REGISTRY_DIR/registry.jsonl"
DASHBOARD_FILE="$REGISTRY_DIR/dashboard.html"

if [[ ! -f "$REGISTRY_FILE" || ! -s "$REGISTRY_FILE" ]]; then
    echo "No projects registered in $REGISTRY_FILE"
    echo "Run 'orchystraw run <project-path>' to register projects."
    exit 1
fi

# ── Collect data from each project ──────────────────────────────────────

declare -a PROJECT_NAMES=()
declare -a PROJECT_PATHS=()
declare -a PROJECT_AGENTS=()
declare -a PROJECT_COSTS=()
declare -a PROJECT_HEALTH=()
declare -a PROJECT_INVOCATIONS=()
declare -a PROJECT_LAST_RUN=()

idx=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    name=$(echo "$line" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
    path=$(echo "$line" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4)
    last_run=$(echo "$line" | grep -o '"last_run":"[^"]*"' | head -1 | cut -d'"' -f4)

    PROJECT_NAMES+=("$name")
    PROJECT_PATHS+=("$path")
    PROJECT_LAST_RUN+=("${last_run:-never}")

    # Health
    local health="unknown"
    local agents=0
    local cost_total="0.0000"
    local invocations=0

    if [[ -d "$path/.orchystraw" ]]; then
        if [[ -f "$path/.orchestrator-pause" ]]; then
            health="PAUSED"
        else
            health="OK"
        fi

        # Count agents from router state
        if [[ -f "$path/.orchystraw/router-state.txt" ]]; then
            agents=$(grep -cv '^#' "$path/.orchystraw/router-state.txt" 2>/dev/null | tr -d ' ')
        fi

        # Sum audit cost
        if [[ -f "$path/.orchystraw/audit.jsonl" ]]; then
            invocations=$(wc -l < "$path/.orchystraw/audit.jsonl" | tr -d ' ')
            local total_cost_micro=0
            while IFS= read -r aline; do
                [[ -z "$aline" ]] && continue
                local c
                c=$(echo "$aline" | grep -o '"cost_estimate":"[^"]*"' | head -1 | cut -d'"' -f4)
                if [[ -n "$c" ]]; then
                    local cn="${c//[^0-9]/}"
                    cn="${cn:-0}"
                    total_cost_micro=$((total_cost_micro + 10#$cn))
                fi
            done < "$path/.orchystraw/audit.jsonl"
            cost_total=$(awk "BEGIN{printf \"%.4f\", $total_cost_micro / 1000000}")
        fi
    else
        if [[ -d "$path" ]]; then
            health="NO STATE"
        else
            health="MISSING"
        fi
    fi

    PROJECT_AGENTS+=("$agents")
    PROJECT_COSTS+=("$cost_total")
    PROJECT_HEALTH+=("$health")
    PROJECT_INVOCATIONS+=("$invocations")

    idx=$((idx + 1))
done < "$REGISTRY_FILE"

# ── Generate HTML ───────────────────────────────────────────────────────

mkdir -p "$REGISTRY_DIR"

cat > "$DASHBOARD_FILE" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>orchystraw — Dashboard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0a0a0a; color: #e0e0e0; padding: 2rem; }
  h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: #fff; }
  .subtitle { color: #888; margin-bottom: 2rem; font-size: 0.9rem; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; }
  th { text-align: left; padding: 0.75rem 1rem; background: #1a1a1a; border-bottom: 2px solid #333; font-weight: 600; color: #aaa; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; }
  td { padding: 0.75rem 1rem; border-bottom: 1px solid #1a1a1a; }
  tr:hover td { background: #111; }
  .health-ok { color: #4ade80; }
  .health-paused { color: #facc15; }
  .health-missing { color: #f87171; }
  .health-unknown { color: #888; }
  .metric { font-family: 'JetBrains Mono', monospace; }
  .section { margin-bottom: 2rem; }
  .section h2 { font-size: 1.1rem; margin-bottom: 1rem; color: #ccc; }
  .footer { color: #555; font-size: 0.8rem; margin-top: 3rem; }
</style>
</head>
<body>
<h1>orchystraw Dashboard</h1>
HTMLHEAD

echo "<p class=\"subtitle\">Generated $(date '+%Y-%m-%d %H:%M:%S') — ${#PROJECT_NAMES[@]} projects</p>" >> "$DASHBOARD_FILE"

# Portfolio overview table
cat >> "$DASHBOARD_FILE" << 'TABLESTART'
<div class="section">
<h2>Portfolio Overview</h2>
<table>
<thead>
<tr><th>Project</th><th>Health</th><th>Agents</th><th>Invocations</th><th>Est. Cost</th><th>Last Run</th></tr>
</thead>
<tbody>
TABLESTART

for i in $(seq 0 $((${#PROJECT_NAMES[@]} - 1))); do
    local_health="${PROJECT_HEALTH[$i]}"
    health_class="health-unknown"
    case "$local_health" in
        OK)      health_class="health-ok" ;;
        PAUSED)  health_class="health-paused" ;;
        MISSING) health_class="health-missing" ;;
    esac

    cat >> "$DASHBOARD_FILE" << ROWEOF
<tr>
  <td><strong>${PROJECT_NAMES[$i]}</strong><br><span style="color:#666;font-size:0.8rem">${PROJECT_PATHS[$i]}</span></td>
  <td class="$health_class">${PROJECT_HEALTH[$i]}</td>
  <td class="metric">${PROJECT_AGENTS[$i]}</td>
  <td class="metric">${PROJECT_INVOCATIONS[$i]}</td>
  <td class="metric">\$${PROJECT_COSTS[$i]}</td>
  <td>${PROJECT_LAST_RUN[$i]}</td>
</tr>
ROWEOF
done

cat >> "$DASHBOARD_FILE" << 'TABLEEND'
</tbody>
</table>
</div>
TABLEEND

# Per-project metrics
cat >> "$DASHBOARD_FILE" << 'METRICSHEAD'
<div class="section">
<h2>Per-Project Metrics</h2>
METRICSHEAD

for i in $(seq 0 $((${#PROJECT_NAMES[@]} - 1))); do
    local_path="${PROJECT_PATHS[$i]}"
    local_name="${PROJECT_NAMES[$i]}"

    echo "<h3 style=\"margin:1rem 0 0.5rem;color:#aaa\">$local_name</h3>" >> "$DASHBOARD_FILE"

    # Quality scores
    local_scores_file="$local_path/.orchystraw/quality-scores.jsonl"
    if [[ -f "$local_scores_file" ]]; then
        echo "<p style=\"color:#888;font-size:0.85rem\">Recent quality scores:</p>" >> "$DASHBOARD_FILE"
        echo "<pre style=\"background:#111;padding:0.5rem;border-radius:4px;font-size:0.8rem;overflow-x:auto\">" >> "$DASHBOARD_FILE"
        tail -5 "$local_scores_file" >> "$DASHBOARD_FILE"
        echo "</pre>" >> "$DASHBOARD_FILE"
    fi

    # Recent metrics
    local_metrics_file="$local_path/.orchystraw/metrics.jsonl"
    if [[ -f "$local_metrics_file" ]]; then
        echo "<p style=\"color:#888;font-size:0.85rem\">Recent metrics:</p>" >> "$DASHBOARD_FILE"
        echo "<pre style=\"background:#111;padding:0.5rem;border-radius:4px;font-size:0.8rem;overflow-x:auto\">" >> "$DASHBOARD_FILE"
        tail -5 "$local_metrics_file" >> "$DASHBOARD_FILE"
        echo "</pre>" >> "$DASHBOARD_FILE"
    fi

    if [[ ! -f "$local_scores_file" && ! -f "$local_metrics_file" ]]; then
        echo "<p style=\"color:#555;font-size:0.85rem\">No metrics data yet.</p>" >> "$DASHBOARD_FILE"
    fi
done

cat >> "$DASHBOARD_FILE" << 'METRICSEND'
</div>
METRICSEND

# Footer
cat >> "$DASHBOARD_FILE" << 'HTMLFOOT'
<div class="footer">
  orchystraw — Multi-agent AI orchestration
</div>
</body>
</html>
HTMLFOOT

echo "Dashboard generated: $DASHBOARD_FILE"
echo "  Projects: ${#PROJECT_NAMES[@]}"

# Open in browser on macOS
if command -v open &>/dev/null; then
    open "$DASHBOARD_FILE"
fi
