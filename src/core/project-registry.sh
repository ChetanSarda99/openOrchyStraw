#!/usr/bin/env bash
# project-registry.sh — Global project registry at ~/.orchystraw/
# Tracks all projects that use orchystraw, their names, paths, and last run times.
#
# Registry format (JSONL): {"path":"/abs/path","name":"MyProject","registered":"2026-04-07T12:00:00Z","last_run":"2026-04-07T12:00:00Z"}

_ORCH_PROJECT_REGISTRY_LOADED=1

ORCH_REGISTRY_DIR="$HOME/.orchystraw"
ORCH_REGISTRY_FILE="$ORCH_REGISTRY_DIR/registry.jsonl"

# ── orch_registry_init ──────────────────────────────────────────────────
# Create ~/.orchystraw directory and registry file if they don't exist.
orch_registry_init() {
    mkdir -p "$ORCH_REGISTRY_DIR"
    if [[ ! -f "$ORCH_REGISTRY_FILE" ]]; then
        touch "$ORCH_REGISTRY_FILE"
    fi
}

# ── orch_registry_register ──────────────────────────────────────────────
# Register a project. Deduplicates by path.
# Args: $1 = absolute path, $2 = project name
orch_registry_register() {
    local path="$1"
    local name="${2:-$(basename "$path")}"
    local ts
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    orch_registry_init

    # Dedup: skip if already registered with same path
    if grep -q "\"path\":\"$path\"" "$ORCH_REGISTRY_FILE" 2>/dev/null; then
        return 0
    fi

    # Append new entry
    echo "{\"path\":\"$path\",\"name\":\"$name\",\"registered\":\"$ts\",\"last_run\":\"$ts\"}" >> "$ORCH_REGISTRY_FILE"
}

# ── orch_registry_list ──────────────────────────────────────────────────
# Print a table of all registered projects.
orch_registry_list() {
    orch_registry_init

    if [[ ! -s "$ORCH_REGISTRY_FILE" ]]; then
        echo "No projects registered."
        echo "  Run 'orchystraw run <project-path>' to register a project."
        return 0
    fi

    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  orchystraw — Registered Projects                              ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    printf "║  %-18s %-40s ║\n" "NAME" "PATH"
    echo "╠══════════════════════════════════════════════════════════════════╣"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local name path last_run
        name=$(echo "$line" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        path=$(echo "$line" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4)
        last_run=$(echo "$line" | grep -o '"last_run":"[^"]*"' | head -1 | cut -d'"' -f4)
        printf "║  %-18s %-40s ║\n" "${name:0:18}" "${path:0:40}"
        printf "║  %-18s %-40s ║\n" "" "Last run: ${last_run:-never}"
    done < "$ORCH_REGISTRY_FILE"

    echo "╚══════════════════════════════════════════════════════════════════╝"
}

# ── orch_registry_status ────────────────────────────────────────────────
# Read each project's .orchystraw/ and show health.
orch_registry_status() {
    orch_registry_init

    if [[ ! -s "$ORCH_REGISTRY_FILE" ]]; then
        echo "No projects registered."
        return 0
    fi

    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  orchystraw — Project Status                                            ║"
    echo "╠══════════════════════════════════════════════════════════════════════════╣"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local name path
        name=$(echo "$line" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        path=$(echo "$line" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4)

        local health="unknown"
        local agents="-"
        local last_cost="-"

        if [[ -d "$path/.orchystraw" ]]; then
            # Check for pause file
            if [[ -f "$path/.orchestrator-pause" ]]; then
                health="PAUSED"
            elif [[ -f "$path/.orchystraw/router-state.txt" ]]; then
                # Count agents from router state
                agents=$(grep -cv '^#' "$path/.orchystraw/router-state.txt" 2>/dev/null | tr -d ' ')
                [[ "$agents" == "0" ]] && agents="-"
                health="OK"
            elif [[ -f "$path/.orchystraw/router-state.json" ]]; then
                health="OK"
            else
                health="NEW"
            fi

            # Get last audit cost
            if [[ -f "$path/.orchystraw/audit.jsonl" ]]; then
                local audit_lines
                audit_lines=$(wc -l < "$path/.orchystraw/audit.jsonl" | tr -d ' ')
                last_cost="${audit_lines} invocations"
            fi
        else
            if [[ -d "$path" ]]; then
                health="NO STATE"
            else
                health="MISSING"
            fi
        fi

        printf "║  %-15s  %-8s  agents=%-4s  %s\n" "${name:0:15}" "$health" "$agents" "$last_cost"
        printf "║    %s\n" "${path}"
    done < "$ORCH_REGISTRY_FILE"

    echo "╚══════════════════════════════════════════════════════════════════════════╝"
}

# ── orch_registry_update_last_run ───────────────────────────────────────
# Update the last_run timestamp for a project.
# Args: $1 = absolute path
orch_registry_update_last_run() {
    local path="$1"
    local ts
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    orch_registry_init

    if [[ ! -f "$ORCH_REGISTRY_FILE" ]]; then
        return 1
    fi

    # Update in place using temp file
    local tmp
    tmp=$(mktemp)
    local found=false

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local entry_path
        entry_path=$(echo "$line" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [[ "$entry_path" == "$path" ]]; then
            # Replace last_run timestamp
            echo "$line" | sed "s/\"last_run\":\"[^\"]*\"/\"last_run\":\"$ts\"/" >> "$tmp"
            found=true
        else
            echo "$line" >> "$tmp"
        fi
    done < "$ORCH_REGISTRY_FILE"

    if [[ "$found" == true ]]; then
        mv "$tmp" "$ORCH_REGISTRY_FILE"
    else
        rm -f "$tmp"
        return 1
    fi
}

# ── orch_registry_remove ───────────────────────────────────────────────
# Remove a project from the registry.
# Args: $1 = absolute path
orch_registry_remove() {
    local path="$1"

    orch_registry_init

    if [[ ! -f "$ORCH_REGISTRY_FILE" ]]; then
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    grep -v "\"path\":\"$path\"" "$ORCH_REGISTRY_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$ORCH_REGISTRY_FILE"
}

# ── orch_registry_get_all_paths ─────────────────────────────────────────
# Output all registered project paths, one per line.
orch_registry_get_all_paths() {
    orch_registry_init

    if [[ ! -s "$ORCH_REGISTRY_FILE" ]]; then
        return 0
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        echo "$line" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4
    done < "$ORCH_REGISTRY_FILE"
}
