#!/usr/bin/env bash
# =============================================================================
# memory.sh — Agent memory persistence for OrchyStraw (#v0.4)
#
# Provides cross-cycle learning and persistent memory for agents:
#   - Episodic memory (what happened in past cycles — outcomes, decisions)
#   - Semantic memory (facts, preferences, domain knowledge)
#   - Procedural memory (learned workflows, tool usage patterns)
#   - Memory retrieval by recency, relevance keyword, or agent ID
#
# Design: file-based, no external dependencies. Memory stored as line-delimited
# records in .orchystraw/memory/. Each record has a type, agent, timestamp,
# and content. Simple keyword search for retrieval.
#
# Usage:
#   source src/core/memory.sh
#
#   orch_mem_init "/path/to/project"
#   orch_mem_store "06-backend" "episodic" "Fixed timeout bug in agent-timeout.sh"
#   orch_mem_store "06-backend" "semantic" "Bash 5.0+ required for associative arrays"
#   orch_mem_store "06-backend" "procedural" "Always run tests before committing"
#   orch_mem_recall "06-backend" "timeout"           # keyword search
#   orch_mem_recall_recent "06-backend" 5            # last 5 memories
#   orch_mem_recall_type "06-backend" "procedural"   # by type
#   orch_mem_summary "06-backend"                    # stats
#   orch_mem_gc 30                                   # prune memories older than 30 days
#
# Requires: bash 5.0+
# =============================================================================

[[ -n "${_ORCH_MEM_LOADED:-}" ]] && return 0
readonly _ORCH_MEM_LOADED=1

# ── State ──
declare -g _ORCH_MEM_DIR=""
declare -g _ORCH_MEM_INITED=false
declare -g -i _ORCH_MEM_STORE_COUNT=0

# ── Helpers ──

_orch_mem_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "memory" "$2"
    else
        printf '[%s] [%s] [memory] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >&2
    fi
}

_orch_mem_now_epoch() {
    date '+%s'
}

_orch_mem_now_iso() {
    date '+%Y-%m-%dT%H:%M:%S'
}

# ── Public API ──

# ---------------------------------------------------------------------------
# orch_mem_init — initialize memory subsystem
# Args: $1 — project root directory
# ---------------------------------------------------------------------------
orch_mem_init() {
    local project_root="${1:?orch_mem_init requires a project directory}"

    _ORCH_MEM_DIR="${project_root}/.orchystraw/memory"
    mkdir -p "$_ORCH_MEM_DIR" 2>/dev/null || {
        _orch_mem_log ERROR "cannot create memory dir: $_ORCH_MEM_DIR"
        return 1
    }

    # Create type-specific files if they don't exist
    touch "$_ORCH_MEM_DIR/episodic.mem" 2>/dev/null
    touch "$_ORCH_MEM_DIR/semantic.mem" 2>/dev/null
    touch "$_ORCH_MEM_DIR/procedural.mem" 2>/dev/null

    _ORCH_MEM_STORE_COUNT=0
    _ORCH_MEM_INITED=true
    _orch_mem_log INFO "initialized: dir=$_ORCH_MEM_DIR"
}

# ---------------------------------------------------------------------------
# orch_mem_store — store a memory record
#
# Record format (pipe-delimited): epoch|iso_date|agent|type|content
#
# Args: $1 — agent_id, $2 — type (episodic/semantic/procedural), $3 — content
# ---------------------------------------------------------------------------
orch_mem_store() {
    local agent="${1:?orch_mem_store: agent required}"
    local mem_type="${2:?orch_mem_store: type required}"
    local content="${3:?orch_mem_store: content required}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        _orch_mem_log ERROR "not initialized — call orch_mem_init first"
        return 1
    fi

    case "$mem_type" in
        episodic|semantic|procedural) ;;
        *)
            _orch_mem_log ERROR "invalid memory type: $mem_type (valid: episodic, semantic, procedural)"
            return 1
            ;;
    esac

    # Sanitize content (remove pipe chars to avoid format corruption)
    content="${content//|/-}"

    local epoch
    epoch=$(_orch_mem_now_epoch)
    local iso
    iso=$(_orch_mem_now_iso)

    local record="${epoch}|${iso}|${agent}|${mem_type}|${content}"
    printf '%s\n' "$record" >> "$_ORCH_MEM_DIR/${mem_type}.mem" || {
        _orch_mem_log ERROR "failed to write memory record"
        return 1
    }

    _ORCH_MEM_STORE_COUNT=$((_ORCH_MEM_STORE_COUNT + 1))
    return 0
}

# ---------------------------------------------------------------------------
# orch_mem_recall — keyword search across all memory types for an agent
#
# Args: $1 — agent_id, $2 — search keyword(s)
# Outputs: matching records to stdout (most recent first)
# ---------------------------------------------------------------------------
orch_mem_recall() {
    local agent="${1:?orch_mem_recall: agent required}"
    local keyword="${2:?orch_mem_recall: keyword required}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        _orch_mem_log ERROR "not initialized"
        return 1
    fi

    local -a results=()

    local mem_type
    for mem_type in episodic semantic procedural; do
        local memfile="$_ORCH_MEM_DIR/${mem_type}.mem"
        [[ ! -f "$memfile" ]] && continue

        while IFS= read -r record; do
            [[ -z "$record" ]] && continue
            # Match agent and keyword (case-insensitive)
            local rec_agent
            rec_agent=$(echo "$record" | cut -d'|' -f3)
            [[ "$rec_agent" != "$agent" ]] && continue

            if echo "$record" | grep -qi "$keyword" 2>/dev/null; then
                results+=("$record")
            fi
        done < "$memfile"
    done

    # Sort by epoch (descending — newest first)
    if [[ ${#results[@]} -gt 0 ]]; then
        printf '%s\n' "${results[@]}" | sort -t'|' -k1 -rn
    fi
}

# ---------------------------------------------------------------------------
# orch_mem_recall_recent — get N most recent memories for an agent
#
# Args: $1 — agent_id, $2 — count (default 5)
# ---------------------------------------------------------------------------
orch_mem_recall_recent() {
    local agent="${1:?orch_mem_recall_recent: agent required}"
    local count="${2:-5}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        return 1
    fi

    local -a all_records=()
    local mem_type
    for mem_type in episodic semantic procedural; do
        local memfile="$_ORCH_MEM_DIR/${mem_type}.mem"
        [[ ! -f "$memfile" ]] && continue

        while IFS= read -r record; do
            [[ -z "$record" ]] && continue
            local rec_agent
            rec_agent=$(echo "$record" | cut -d'|' -f3)
            [[ "$rec_agent" != "$agent" ]] && continue
            all_records+=("$record")
        done < "$memfile"
    done

    if [[ ${#all_records[@]} -gt 0 ]]; then
        printf '%s\n' "${all_records[@]}" | sort -t'|' -k1 -rn | head -n "$count"
    fi
}

# ---------------------------------------------------------------------------
# orch_mem_recall_type — get memories of a specific type for an agent
#
# Args: $1 — agent_id, $2 — type (episodic/semantic/procedural)
# ---------------------------------------------------------------------------
orch_mem_recall_type() {
    local agent="${1:?orch_mem_recall_type: agent required}"
    local mem_type="${2:?orch_mem_recall_type: type required}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        return 1
    fi

    local memfile="$_ORCH_MEM_DIR/${mem_type}.mem"
    [[ ! -f "$memfile" ]] && return 0

    while IFS= read -r record; do
        [[ -z "$record" ]] && continue
        local rec_agent
        rec_agent=$(echo "$record" | cut -d'|' -f3)
        [[ "$rec_agent" == "$agent" ]] && printf '%s\n' "$record"
    done < "$memfile"
}

# ---------------------------------------------------------------------------
# orch_mem_count — count memories for an agent (optionally by type)
#
# Args: $1 — agent_id, $2 — type (optional, all types if omitted)
# ---------------------------------------------------------------------------
orch_mem_count() {
    local agent="${1:?orch_mem_count: agent required}"
    local mem_type="${2:-}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        echo "0"
        return 1
    fi

    local count=0
    local types
    if [[ -n "$mem_type" ]]; then
        types=("$mem_type")
    else
        types=(episodic semantic procedural)
    fi

    for t in "${types[@]}"; do
        local memfile="$_ORCH_MEM_DIR/${t}.mem"
        [[ ! -f "$memfile" ]] && continue
        local agent_count
        agent_count=$(grep -c "|${agent}|" "$memfile" 2>/dev/null || echo 0)
        count=$((count + agent_count))
    done

    echo "$count"
}

# ---------------------------------------------------------------------------
# orch_mem_summary — print memory stats for an agent
# ---------------------------------------------------------------------------
orch_mem_summary() {
    local agent="${1:?orch_mem_summary: agent required}"

    printf 'Memory summary for %s:\n' "$agent"
    printf '  Episodic:   %s records\n' "$(orch_mem_count "$agent" "episodic")"
    printf '  Semantic:   %s records\n' "$(orch_mem_count "$agent" "semantic")"
    printf '  Procedural: %s records\n' "$(orch_mem_count "$agent" "procedural")"
    printf '  Total:      %s records\n' "$(orch_mem_count "$agent")"
}

# ---------------------------------------------------------------------------
# orch_mem_gc — garbage collect memories older than N days
#
# Args: $1 — max age in days (default 30)
# Returns: number of pruned records on stdout
# ---------------------------------------------------------------------------
orch_mem_gc() {
    local max_age_days="${1:-30}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        _orch_mem_log ERROR "not initialized"
        return 1
    fi

    local now
    now=$(_orch_mem_now_epoch)
    local threshold=$(( now - max_age_days * 86400 ))
    local pruned=0

    local mem_type
    for mem_type in episodic semantic procedural; do
        local memfile="$_ORCH_MEM_DIR/${mem_type}.mem"
        [[ ! -f "$memfile" ]] && continue

        local tmpfile
        tmpfile=$(mktemp)
        local before_count
        before_count=$(wc -l < "$memfile")

        while IFS= read -r record; do
            [[ -z "$record" ]] && continue
            local epoch
            epoch=$(echo "$record" | cut -d'|' -f1)
            if [[ "$epoch" -ge "$threshold" ]]; then
                printf '%s\n' "$record" >> "$tmpfile"
            fi
        done < "$memfile"

        local after_count
        after_count=$(wc -l < "$tmpfile" 2>/dev/null || echo 0)
        pruned=$(( pruned + before_count - after_count ))

        mv "$tmpfile" "$memfile"
    done

    _orch_mem_log INFO "gc: pruned $pruned records older than ${max_age_days} days"
    echo "$pruned"
}

# ---------------------------------------------------------------------------
# orch_mem_export — export all memories as formatted text
# Outputs: human-readable memory dump to stdout
# ---------------------------------------------------------------------------
orch_mem_export() {
    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        return 1
    fi

    printf '# OrchyStraw Agent Memory Export\n'
    printf '# Generated: %s\n\n' "$(_orch_mem_now_iso)"

    local mem_type
    for mem_type in episodic semantic procedural; do
        local memfile="$_ORCH_MEM_DIR/${mem_type}.mem"
        [[ ! -f "$memfile" ]] && continue

        printf '## %s Memory\n\n' "${mem_type^}"

        while IFS= read -r record; do
            [[ -z "$record" ]] && continue
            local iso agent content
            iso=$(echo "$record" | cut -d'|' -f2)
            agent=$(echo "$record" | cut -d'|' -f3)
            content=$(echo "$record" | cut -d'|' -f5-)
            printf '- [%s] **%s**: %s\n' "$iso" "$agent" "$content"
        done < "$memfile"

        printf '\n'
    done
}

# ---------------------------------------------------------------------------
# orch_mem_clear — clear all memories for an agent (or all agents)
# Args: $1 — agent_id (or "all")
# ---------------------------------------------------------------------------
orch_mem_clear() {
    local agent="${1:?orch_mem_clear: agent required}"

    if [[ "$_ORCH_MEM_INITED" != "true" ]]; then
        return 1
    fi

    local mem_type
    for mem_type in episodic semantic procedural; do
        local memfile="$_ORCH_MEM_DIR/${mem_type}.mem"
        [[ ! -f "$memfile" ]] && continue

        if [[ "$agent" == "all" ]]; then
            : > "$memfile"
        else
            local tmpfile
            tmpfile=$(mktemp)
            grep -v "|${agent}|" "$memfile" > "$tmpfile" 2>/dev/null || true
            mv "$tmpfile" "$memfile"
        fi
    done

    _orch_mem_log INFO "cleared memories for: $agent"
}
