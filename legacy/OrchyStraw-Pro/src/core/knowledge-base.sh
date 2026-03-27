#!/usr/bin/env bash
# ============================================
# knowledge-base.sh — Cross-project knowledge persistence module
# Source this file: source src/core/knowledge-base.sh
#
# Stores and retrieves knowledge entries organized by domain.
# Persists to ~/.orchystraw/knowledge/ so knowledge is available
# across different project directories.
#
# Public API:
#   orch_kb_init              — Create knowledge directory structure
#   orch_kb_store             — Store a knowledge entry
#   orch_kb_retrieve          — Retrieve a specific entry
#   orch_kb_search            — Search entries by keyword
#   orch_kb_list              — List domains or entries in a domain
#   orch_kb_delete            — Remove a knowledge entry
#   orch_kb_merge_on_init     — Merge project-local and global knowledge
#   orch_kb_export            — Export all knowledge as markdown
#
# Requires: grep, sed, date, bash 4.2+
# No external dependencies (no python, no jq).
# ============================================

# Guard against double-sourcing
[[ -n "${_ORCH_KNOWLEDGE_BASE_LOADED:-}" ]] && return 0
_ORCH_KNOWLEDGE_BASE_LOADED=1

# ── Defaults ──
declare -g ORCHYSTRAW_HOME="${ORCHYSTRAW_HOME:-$HOME/.orchystraw}"
declare -g _ORCH_KB_DIR="${ORCHYSTRAW_HOME}/knowledge"

# ── Input validation ──
# Domain names: alphanumeric, hyphens, underscores only
_orch_kb_validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "[knowledge-base] ERROR: invalid domain name: '$domain'" >&2
        return 1
    fi
    return 0
}

# Key names: alphanumeric, hyphens, underscores, dots only
_orch_kb_validate_key() {
    local key="$1"
    if [[ ! "$key" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        echo "[knowledge-base] ERROR: invalid key name: '$key'" >&2
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# orch_kb_init
#
# Create ~/.orchystraw/knowledge/ directory structure if missing.
# Create index file if missing. Idempotent.
# ---------------------------------------------------------------------------
orch_kb_init() {
    mkdir -p "$_ORCH_KB_DIR"
    if [[ ! -f "$_ORCH_KB_DIR/index.txt" ]]; then
        touch "$_ORCH_KB_DIR/index.txt"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# _orch_kb_timestamp
#
# Generate ISO-8601 timestamp (no timezone suffix for portability).
# ---------------------------------------------------------------------------
_orch_kb_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%S'
}

# ---------------------------------------------------------------------------
# _orch_kb_update_index <domain> <key> <description>
#
# Add or update an entry in the index file.
# ---------------------------------------------------------------------------
_orch_kb_update_index() {
    local domain="$1" key="$2" description="$3"
    local ts
    ts=$(_orch_kb_timestamp)
    local entry="${domain}/${key}|${ts}|${description}"

    # Remove existing entry for this domain/key if present
    if [[ -f "$_ORCH_KB_DIR/index.txt" ]]; then
        # Use a temp file to avoid in-place sed portability issues
        local tmpfile
        tmpfile=$(mktemp)
        grep -Fv "${domain}/${key}|" "$_ORCH_KB_DIR/index.txt" > "$tmpfile" 2>/dev/null || true
        mv "$tmpfile" "$_ORCH_KB_DIR/index.txt"
    fi

    echo "$entry" >> "$_ORCH_KB_DIR/index.txt"
}

# ---------------------------------------------------------------------------
# _orch_kb_remove_from_index <domain> <key>
#
# Remove an entry from the index file.
# ---------------------------------------------------------------------------
_orch_kb_remove_from_index() {
    local domain="$1" key="$2"

    if [[ -f "$_ORCH_KB_DIR/index.txt" ]]; then
        local tmpfile
        tmpfile=$(mktemp)
        grep -Fv "${domain}/${key}|" "$_ORCH_KB_DIR/index.txt" > "$tmpfile" 2>/dev/null || true
        mv "$tmpfile" "$_ORCH_KB_DIR/index.txt"
    fi
}

# ---------------------------------------------------------------------------
# orch_kb_store <domain> <key> <value>
#
# Store a knowledge entry. Domain is a category (e.g. "patterns",
# "decisions", "anti-patterns", "tools", "conventions"). Key is a short
# identifier. Value is the content.
#
# File: ~/.orchystraw/knowledge/{domain}/{key}.md
# ---------------------------------------------------------------------------
orch_kb_store() {
    local domain="${1:-}"
    local key="${2:-}"
    local value="${3:-}"

    if [[ -z "$domain" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_store requires a domain" >&2
        return 1
    fi
    if [[ -z "$key" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_store requires a key" >&2
        return 1
    fi
    if [[ -z "$value" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_store requires a value" >&2
        return 1
    fi

    _orch_kb_validate_domain "$domain" || return 1
    _orch_kb_validate_key "$key" || return 1

    # Ensure init has been called
    if [[ ! -d "$_ORCH_KB_DIR" ]]; then
        echo "[knowledge-base] ERROR: knowledge base not initialized. Run orch_kb_init first." >&2
        return 1
    fi

    local domain_dir="$_ORCH_KB_DIR/$domain"
    mkdir -p "$domain_dir"

    local entry_file="$domain_dir/${key}.md"
    local ts
    ts=$(_orch_kb_timestamp)

    # Determine created timestamp — preserve if updating
    local created="$ts"
    if [[ -f "$entry_file" ]]; then
        local existing_created
        existing_created=$(sed -n 's/^created: //p' "$entry_file" | head -1)
        if [[ -n "$existing_created" ]]; then
            created="$existing_created"
        fi
    fi

    # Detect project name from git or pwd
    local project=""
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || true)
    fi
    if [[ -z "$project" ]]; then
        project=$(basename "$(pwd)")
    fi

    # Extract first line for index description
    local first_line
    first_line=$(echo "$value" | head -1)

    # Sanitize value: replace bare "---" lines to prevent frontmatter corruption
    local safe_value
    safe_value=$(printf '%s' "$value" | sed 's/^---$/- - -/g')

    # Write the entry file
    {
        echo "---"
        echo "domain: $domain"
        echo "key: $key"
        echo "created: $created"
        echo "updated: $ts"
        echo "project: $project"
        echo "---"
        echo "$safe_value"
    } > "$entry_file"

    # Update the index
    _orch_kb_update_index "$domain" "$key" "$first_line"

    return 0
}

# ---------------------------------------------------------------------------
# orch_kb_retrieve <domain> <key>
#
# Retrieve a specific knowledge entry. Prints value content (after
# frontmatter) to stdout. Returns 1 if not found.
# ---------------------------------------------------------------------------
orch_kb_retrieve() {
    local domain="${1:-}"
    local key="${2:-}"

    if [[ -z "$domain" || -z "$key" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_retrieve requires domain and key" >&2
        return 1
    fi

    _orch_kb_validate_domain "$domain" || return 1
    _orch_kb_validate_key "$key" || return 1

    local entry_file="$_ORCH_KB_DIR/$domain/${key}.md"

    if [[ ! -f "$entry_file" ]]; then
        return 1
    fi

    # Print everything after the closing --- of frontmatter
    local in_frontmatter=0
    local frontmatter_closed=0
    while IFS= read -r line; do
        if [[ "$frontmatter_closed" -eq 1 ]]; then
            echo "$line"
        elif [[ "$line" == "---" && "$in_frontmatter" -eq 0 ]]; then
            in_frontmatter=1
        elif [[ "$line" == "---" && "$in_frontmatter" -eq 1 ]]; then
            frontmatter_closed=1
        fi
    done < "$entry_file"

    return 0
}

# ---------------------------------------------------------------------------
# orch_kb_search <query>
#
# Search all knowledge entries by grep. Prints matching entries with
# domain/key context. Returns 1 if no matches found.
# ---------------------------------------------------------------------------
orch_kb_search() {
    local query="${1:-}"

    if [[ -z "$query" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_search requires a query" >&2
        return 1
    fi

    if [[ ! -d "$_ORCH_KB_DIR" ]]; then
        return 1
    fi

    local found=0
    local domain_dir domain_name entry_file key_name

    for domain_dir in "$_ORCH_KB_DIR"/*/; do
        [[ -d "$domain_dir" ]] || continue
        domain_name=$(basename "$domain_dir")

        for entry_file in "$domain_dir"*.md; do
            [[ -f "$entry_file" ]] || continue
            key_name=$(basename "$entry_file" .md)

            if grep -qi "$query" "$entry_file" 2>/dev/null; then
                echo "[$domain_name/$key_name]"
                # Print matching lines with context
                grep -i "$query" "$entry_file" 2>/dev/null | while IFS= read -r match_line; do
                    echo "  $match_line"
                done
                echo ""
                found=1
            fi
        done
    done

    if [[ "$found" -eq 0 ]]; then
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_kb_list [domain]
#
# List all entries in a domain. If domain is empty, list all domains
# with entry counts.
# ---------------------------------------------------------------------------
orch_kb_list() {
    local domain="${1:-}"

    if [[ ! -d "$_ORCH_KB_DIR" ]]; then
        echo "[knowledge-base] ERROR: knowledge base not initialized" >&2
        return 1
    fi

    if [[ -n "$domain" ]]; then
        _orch_kb_validate_domain "$domain" || return 1
    fi

    if [[ -z "$domain" ]]; then
        # List all domains with entry counts
        local domain_dir domain_name count
        local any_found=0

        for domain_dir in "$_ORCH_KB_DIR"/*/; do
            [[ -d "$domain_dir" ]] || continue
            domain_name=$(basename "$domain_dir")
            count=0
            for f in "$domain_dir"*.md; do
                [[ -f "$f" ]] && count=$((count + 1))
            done
            if [[ "$count" -gt 0 ]]; then
                printf '%s (%d entries)\n' "$domain_name" "$count"
                any_found=1
            fi
        done

        if [[ "$any_found" -eq 0 ]]; then
            echo "(no domains)"
        fi
    else
        # List entries in a specific domain
        local domain_dir="$_ORCH_KB_DIR/$domain"

        if [[ ! -d "$domain_dir" ]]; then
            echo "[knowledge-base] ERROR: domain '$domain' not found" >&2
            return 1
        fi

        local entry_file key_name
        local any_found=0

        for entry_file in "$domain_dir"/*.md; do
            [[ -f "$entry_file" ]] || continue
            key_name=$(basename "$entry_file" .md)
            # Get the updated timestamp from frontmatter
            local updated
            updated=$(sed -n 's/^updated: //p' "$entry_file" | head -1)
            printf '%s  (updated: %s)\n' "$key_name" "${updated:-unknown}"
            any_found=1
        done

        if [[ "$any_found" -eq 0 ]]; then
            echo "(no entries)"
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_kb_delete <domain> <key>
#
# Remove a knowledge entry. Update index. Return 1 if not found.
# ---------------------------------------------------------------------------
orch_kb_delete() {
    local domain="${1:-}"
    local key="${2:-}"

    if [[ -z "$domain" || -z "$key" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_delete requires domain and key" >&2
        return 1
    fi

    _orch_kb_validate_domain "$domain" || return 1
    _orch_kb_validate_key "$key" || return 1

    local entry_file="$_ORCH_KB_DIR/$domain/${key}.md"

    if [[ ! -f "$entry_file" ]]; then
        return 1
    fi

    rm -f "$entry_file"
    _orch_kb_remove_from_index "$domain" "$key"

    # Remove domain directory if empty
    local remaining=0
    for f in "$_ORCH_KB_DIR/$domain"/*.md; do
        [[ -f "$f" ]] && remaining=$((remaining + 1))
    done
    if [[ "$remaining" -eq 0 ]]; then
        rmdir "$_ORCH_KB_DIR/$domain" 2>/dev/null || true
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_kb_merge_on_init <project_root>
#
# Called during project init. Reads project-specific
# .orchystraw/knowledge/ and merges into global ~/.orchystraw/knowledge/
# (newer wins by timestamp). Also copies relevant global entries into
# project-local cache.
# ---------------------------------------------------------------------------
orch_kb_merge_on_init() {
    local project_root="${1:-}"

    if [[ -z "$project_root" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_merge_on_init requires a project root" >&2
        return 1
    fi

    local project_kb="$project_root/.orchystraw/knowledge"
    local global_kb="$_ORCH_KB_DIR"

    # Ensure global KB exists
    orch_kb_init

    # Phase 1: Merge project-local into global (newer wins)
    if [[ -d "$project_kb" ]]; then
        local domain_dir domain_name entry_file key_name
        for domain_dir in "$project_kb"/*/; do
            [[ -d "$domain_dir" ]] || continue
            domain_name=$(basename "$domain_dir")

            for entry_file in "$domain_dir"*.md; do
                [[ -f "$entry_file" ]] || continue
                key_name=$(basename "$entry_file" .md)

                local global_file="$global_kb/$domain_name/${key_name}.md"

                if [[ -f "$global_file" ]]; then
                    # Compare timestamps — newer wins
                    local local_updated global_updated
                    local_updated=$(sed -n 's/^updated: //p' "$entry_file" | head -1)
                    global_updated=$(sed -n 's/^updated: //p' "$global_file" | head -1)

                    # String comparison works for ISO timestamps
                    if [[ "$local_updated" > "$global_updated" ]]; then
                        mkdir -p "$global_kb/$domain_name"
                        cp "$entry_file" "$global_file"
                        # Update index from file content
                        local desc
                        desc=$(_orch_kb_extract_first_content_line "$entry_file")
                        _orch_kb_update_index "$domain_name" "$key_name" "$desc"
                    fi
                else
                    # Global doesn't have it — copy in
                    mkdir -p "$global_kb/$domain_name"
                    cp "$entry_file" "$global_file"
                    local desc
                    desc=$(_orch_kb_extract_first_content_line "$entry_file")
                    _orch_kb_update_index "$domain_name" "$key_name" "$desc"
                fi
            done
        done
    fi

    # Phase 2: Copy global entries into project-local cache
    mkdir -p "$project_kb"

    local domain_dir domain_name entry_file key_name
    for domain_dir in "$global_kb"/*/; do
        [[ -d "$domain_dir" ]] || continue
        domain_name=$(basename "$domain_dir")

        for entry_file in "$domain_dir"*.md; do
            [[ -f "$entry_file" ]] || continue
            key_name=$(basename "$entry_file" .md)

            local local_file="$project_kb/$domain_name/${key_name}.md"

            if [[ -f "$local_file" ]]; then
                # Compare — newer wins
                local local_updated global_updated
                local_updated=$(sed -n 's/^updated: //p' "$local_file" | head -1)
                global_updated=$(sed -n 's/^updated: //p' "$entry_file" | head -1)

                if [[ "$global_updated" > "$local_updated" ]]; then
                    mkdir -p "$project_kb/$domain_name"
                    cp "$entry_file" "$local_file"
                fi
            else
                mkdir -p "$project_kb/$domain_name"
                cp "$entry_file" "$local_file"
            fi
        done
    done

    return 0
}

# ---------------------------------------------------------------------------
# _orch_kb_extract_first_content_line <file>
#
# Extract the first line of content after frontmatter.
# ---------------------------------------------------------------------------
_orch_kb_extract_first_content_line() {
    local file="$1"
    local in_frontmatter=0
    local frontmatter_closed=0

    while IFS= read -r line; do
        if [[ "$frontmatter_closed" -eq 1 ]]; then
            if [[ -n "$line" ]]; then
                echo "$line"
                return 0
            fi
        elif [[ "$line" == "---" && "$in_frontmatter" -eq 0 ]]; then
            in_frontmatter=1
        elif [[ "$line" == "---" && "$in_frontmatter" -eq 1 ]]; then
            frontmatter_closed=1
        fi
    done < "$file"

    echo "(no description)"
}

# ---------------------------------------------------------------------------
# orch_kb_export <output_file>
#
# Export all knowledge as a single markdown file (for sharing/backup).
# ---------------------------------------------------------------------------
orch_kb_export() {
    local output_file="${1:-}"

    if [[ -z "$output_file" ]]; then
        echo "[knowledge-base] ERROR: orch_kb_export requires an output file path" >&2
        return 1
    fi

    if [[ ! -d "$_ORCH_KB_DIR" ]]; then
        echo "[knowledge-base] ERROR: knowledge base not initialized" >&2
        return 1
    fi

    local ts
    ts=$(_orch_kb_timestamp)

    {
        echo "# OrchyStraw Knowledge Base Export"
        echo ""
        echo "Exported: $ts"
        echo ""

        local domain_dir domain_name entry_file key_name
        for domain_dir in "$_ORCH_KB_DIR"/*/; do
            [[ -d "$domain_dir" ]] || continue
            domain_name=$(basename "$domain_dir")

            echo "## $domain_name"
            echo ""

            for entry_file in "$domain_dir"*.md; do
                [[ -f "$entry_file" ]] || continue
                key_name=$(basename "$entry_file" .md)

                echo "### $key_name"
                echo ""

                # Print content after frontmatter
                local in_fm=0
                local fm_closed=0
                while IFS= read -r line; do
                    if [[ "$fm_closed" -eq 1 ]]; then
                        echo "$line"
                    elif [[ "$line" == "---" && "$in_fm" -eq 0 ]]; then
                        in_fm=1
                    elif [[ "$line" == "---" && "$in_fm" -eq 1 ]]; then
                        fm_closed=1
                    fi
                done < "$entry_file"

                echo ""
            done
        done
    } > "$output_file"

    echo "$output_file"
    return 0
}
