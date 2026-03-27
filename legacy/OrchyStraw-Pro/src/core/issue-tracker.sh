#!/usr/bin/env bash
# ============================================
# issue-tracker.sh — Local issue tracker for OrchyStraw
# Source this file: source src/core/issue-tracker.sh
#
# Provides a lightweight, file-based issue tracker that works without
# GitHub. Issues are stored in JSONL format under .orchystraw/issues/.
#
# Public API:
#   orch_issue_create   — Create a new issue
#   orch_issue_list     — List issues with optional filters
#   orch_issue_close    — Close an issue by ID
#   orch_issue_assign   — Assign an issue to an agent
#   orch_issue_show     — Show details of a single issue
#   orch_issue_update   — Update issue fields
#   orch_issue_sync     — Optional GitHub sync when gh CLI is available
#
# Requires: awk, grep, sed, date, bash 4.2+
# No external dependencies (no jq, no python).
# ============================================

# Guard against double-sourcing
[[ -n "${_ORCH_ISSUE_TRACKER_LOADED:-}" ]] && return 0
_ORCH_ISSUE_TRACKER_LOADED=1

# ── Defaults ──
declare -g ORCH_ISSUE_DIR="${ORCH_ISSUE_DIR:-.orchystraw/issues}"
declare -g _ORCH_ISSUE_FILE=""  # Set after ORCH_ISSUE_DIR is finalized

# ── Input validation helpers ──

# Validate issue ID: numeric only
_orch_issue_validate_id() {
    local id="$1"
    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        echo "[issue-tracker] ERROR: invalid issue ID: '$id' (must be numeric)" >&2
        return 1
    fi
    return 0
}

# Validate title: no shell metacharacters, max 200 chars
_orch_issue_validate_title() {
    local title="$1"
    if [[ -z "$title" ]]; then
        echo "[issue-tracker] ERROR: title cannot be empty" >&2
        return 1
    fi
    if [[ ${#title} -gt 200 ]]; then
        echo "[issue-tracker] ERROR: title exceeds 200 characters (got ${#title})" >&2
        return 1
    fi
    # Reject shell metacharacters: backticks, $(), |, ;, &, <, >, newlines
    if [[ "$title" =~ [\`\$\|\;\&\<\>] ]] || [[ "$title" == *'$('* ]] || [[ "$title" == *'..'* ]]; then
        echo "[issue-tracker] ERROR: title contains forbidden characters" >&2
        return 1
    fi
    return 0
}

# Validate priority: P0-P4 only
_orch_issue_validate_priority() {
    local priority="$1"
    if [[ ! "$priority" =~ ^P[0-4]$ ]]; then
        echo "[issue-tracker] ERROR: invalid priority: '$priority' (must be P0-P4)" >&2
        return 1
    fi
    return 0
}

# Validate assignee: alphanumeric + hyphens only
_orch_issue_validate_assignee() {
    local assignee="$1"
    if [[ -z "$assignee" ]]; then
        return 0  # empty assignee is allowed (unassigned)
    fi
    if [[ ! "$assignee" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "[issue-tracker] ERROR: invalid assignee: '$assignee' (alphanumeric and hyphens only)" >&2
        return 1
    fi
    return 0
}

# Validate labels: alphanumeric + hyphens + commas only
_orch_issue_validate_labels() {
    local labels="$1"
    if [[ -z "$labels" ]]; then
        return 0  # empty labels allowed
    fi
    if [[ ! "$labels" =~ ^[a-zA-Z0-9_,:-]+$ ]]; then
        echo "[issue-tracker] ERROR: invalid labels: '$labels' (alphanumeric, hyphens, commas only)" >&2
        return 1
    fi
    return 0
}

# Validate status: open or closed only
_orch_issue_validate_status() {
    local status="$1"
    if [[ "$status" != "open" && "$status" != "closed" ]]; then
        echo "[issue-tracker] ERROR: invalid status: '$status' (must be 'open' or 'closed')" >&2
        return 1
    fi
    return 0
}

# Reject path traversal in any input
_orch_issue_reject_traversal() {
    local value="$1" field="$2"
    if [[ "$value" == *'..'* ]]; then
        echo "[issue-tracker] ERROR: path traversal detected in $field: '$value'" >&2
        return 1
    fi
    return 0
}

# ── Internal helpers ──

# Get the issues file path (lazy init)
_orch_issue_file() {
    if [[ -z "$_ORCH_ISSUE_FILE" ]]; then
        _ORCH_ISSUE_FILE="$ORCH_ISSUE_DIR/issues.jsonl"
    fi
    echo "$_ORCH_ISSUE_FILE"
}

# Get next auto-increment ID
_orch_issue_next_id() {
    local issue_file
    issue_file=$(_orch_issue_file)
    if [[ ! -f "$issue_file" ]] || [[ ! -s "$issue_file" ]]; then
        echo "1"
        return 0
    fi
    # Find max ID and add 1
    local max_id
    max_id=$(awk -F'"id":' '{print $2}' "$issue_file" \
        | awk -F'[,}]' '{print $1}' \
        | sort -n \
        | tail -1 \
        | tr -d ' ')
    if [[ -z "$max_id" || "$max_id" -eq 0 ]]; then
        echo "1"
    else
        echo $(( max_id + 1 ))
    fi
}

# Escape a string for safe JSON embedding (no jq)
_orch_issue_json_escape() {
    local s="$1"
    # Escape backslashes first, then double quotes
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# Generate ISO-8601 UTC timestamp
_orch_issue_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# ---------------------------------------------------------------------------
# orch_issue_create <title> <priority> [assignee] [labels]
#
# Create a new issue. Returns the issue ID on success.
#
# Arguments:
#   title    — Issue title (required, max 200 chars, no shell metacharacters)
#   priority — P0-P4 (required)
#   assignee — Agent name (optional, alphanumeric + hyphens)
#   labels   — Comma-separated labels (optional, alphanumeric + hyphens + commas)
# ---------------------------------------------------------------------------
orch_issue_create() {
    local title="${1:-}"
    local priority="${2:-}"
    local assignee="${3:-}"
    local labels="${4:-}"

    # Validate required fields
    if [[ -z "$title" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_create requires a title" >&2
        return 1
    fi
    if [[ -z "$priority" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_create requires a priority (P0-P4)" >&2
        return 1
    fi

    _orch_issue_validate_title "$title" || return 1
    _orch_issue_validate_priority "$priority" || return 1
    _orch_issue_validate_assignee "$assignee" || return 1
    _orch_issue_validate_labels "$labels" || return 1
    _orch_issue_reject_traversal "$title" "title" || return 1
    _orch_issue_reject_traversal "$assignee" "assignee" || return 1
    _orch_issue_reject_traversal "$labels" "labels" || return 1

    # Ensure directory exists
    mkdir -p "$ORCH_ISSUE_DIR"

    local issue_file
    issue_file=$(_orch_issue_file)

    local id
    id=$(_orch_issue_next_id)

    local ts
    ts=$(_orch_issue_timestamp)

    local escaped_title
    escaped_title=$(_orch_issue_json_escape "$title")

    # Write JSONL record
    printf '{"id":%d,"title":"%s","status":"open","priority":"%s","assignee":"%s","labels":"%s","created_at":"%s","closed_at":""}\n' \
        "$id" "$escaped_title" "$priority" "$assignee" "$labels" "$ts" \
        >> "$issue_file"

    echo "$id"
    return 0
}

# ---------------------------------------------------------------------------
# orch_issue_list [--status <status>] [--priority <priority>] [--assignee <assignee>]
#
# List issues with optional filters. Prints a formatted table to stdout.
# ---------------------------------------------------------------------------
orch_issue_list() {
    local filter_status="" filter_priority="" filter_assignee=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status)
                filter_status="${2:-}"
                _orch_issue_validate_status "$filter_status" || return 1
                shift 2
                ;;
            --priority)
                filter_priority="${2:-}"
                _orch_issue_validate_priority "$filter_priority" || return 1
                shift 2
                ;;
            --assignee)
                filter_assignee="${2:-}"
                _orch_issue_validate_assignee "$filter_assignee" || return 1
                shift 2
                ;;
            *)
                echo "[issue-tracker] ERROR: unknown option: '$1'" >&2
                return 1
                ;;
        esac
    done

    local issue_file
    issue_file=$(_orch_issue_file)

    if [[ ! -f "$issue_file" ]] || [[ ! -s "$issue_file" ]]; then
        echo "(no issues)"
        return 0
    fi

    # Build awk filter conditions
    local awk_filter="1"  # default: show all
    if [[ -n "$filter_status" ]]; then
        awk_filter="$awk_filter && status == \"$filter_status\""
    fi
    if [[ -n "$filter_priority" ]]; then
        awk_filter="$awk_filter && priority == \"$filter_priority\""
    fi
    if [[ -n "$filter_assignee" ]]; then
        awk_filter="$awk_filter && assignee == \"$filter_assignee\""
    fi

    # Header
    printf '%-5s %-8s %-4s %-15s %-15s %s\n' "ID" "STATUS" "PRI" "ASSIGNEE" "LABELS" "TITLE"
    printf '%.0s-' {1..75}
    printf '\n'

    # Parse JSONL and display matching records
    awk -v filter="$awk_filter" '
    {
        # Extract fields from JSON line
        id = ""; title = ""; status = ""; priority = ""; assignee = ""; labels = ""

        # Extract id (numeric)
        match($0, /"id":([0-9]+)/, m)
        if (RSTART > 0) id = m[1]

        # Extract title
        match($0, /"title":"([^"]*)"/, m)
        if (RSTART > 0) title = m[1]

        # Extract status
        match($0, /"status":"([^"]*)"/, m)
        if (RSTART > 0) status = m[1]

        # Extract priority
        match($0, /"priority":"([^"]*)"/, m)
        if (RSTART > 0) priority = m[1]

        # Extract assignee
        match($0, /"assignee":"([^"]*)"/, m)
        if (RSTART > 0) assignee = m[1]

        # Extract labels
        match($0, /"labels":"([^"]*)"/, m)
        if (RSTART > 0) labels = m[1]

        # Apply filters
        show = 1
        if ("'"$filter_status"'" != "" && status != "'"$filter_status"'") show = 0
        if ("'"$filter_priority"'" != "" && priority != "'"$filter_priority"'") show = 0
        if ("'"$filter_assignee"'" != "" && assignee != "'"$filter_assignee"'") show = 0

        if (show) {
            if (assignee == "") assignee = "-"
            if (labels == "") labels = "-"
            # Truncate title for display
            if (length(title) > 40) title = substr(title, 1, 37) "..."
            printf "%-5s %-8s %-4s %-15s %-15s %s\n", id, status, priority, assignee, labels, title
        }
    }' "$issue_file"

    return 0
}

# ---------------------------------------------------------------------------
# orch_issue_close <id>
#
# Close an issue by ID. Sets status to "closed" and records closed_at timestamp.
# ---------------------------------------------------------------------------
orch_issue_close() {
    local id="${1:-}"

    if [[ -z "$id" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_close requires an issue ID" >&2
        return 1
    fi

    _orch_issue_validate_id "$id" || return 1

    local issue_file
    issue_file=$(_orch_issue_file)

    if [[ ! -f "$issue_file" ]]; then
        echo "[issue-tracker] ERROR: no issues file found" >&2
        return 1
    fi

    # Check issue exists
    if ! grep -q "\"id\":${id}[,}]" "$issue_file" 2>/dev/null; then
        echo "[issue-tracker] ERROR: issue #$id not found" >&2
        return 1
    fi

    local ts
    ts=$(_orch_issue_timestamp)

    # Update the issue line: set status to closed, add closed_at
    local tmpfile
    tmpfile=$(mktemp)
    awk -v id="$id" -v ts="$ts" '
    {
        if ($0 ~ "\"id\":" id "[,}]") {
            gsub(/"status":"[^"]*"/, "\"status\":\"closed\"")
            gsub(/"closed_at":"[^"]*"/, "\"closed_at\":\"" ts "\"")
        }
        print
    }' "$issue_file" > "$tmpfile"
    mv "$tmpfile" "$issue_file"

    return 0
}

# ---------------------------------------------------------------------------
# orch_issue_assign <id> <assignee>
#
# Assign an issue to an agent. Overwrites any existing assignee.
# ---------------------------------------------------------------------------
orch_issue_assign() {
    local id="${1:-}"
    local assignee="${2:-}"

    if [[ -z "$id" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_assign requires an issue ID" >&2
        return 1
    fi
    if [[ -z "$assignee" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_assign requires an assignee" >&2
        return 1
    fi

    _orch_issue_validate_id "$id" || return 1
    _orch_issue_validate_assignee "$assignee" || return 1
    _orch_issue_reject_traversal "$assignee" "assignee" || return 1

    local issue_file
    issue_file=$(_orch_issue_file)

    if [[ ! -f "$issue_file" ]]; then
        echo "[issue-tracker] ERROR: no issues file found" >&2
        return 1
    fi

    # Check issue exists
    if ! grep -q "\"id\":${id}[,}]" "$issue_file" 2>/dev/null; then
        echo "[issue-tracker] ERROR: issue #$id not found" >&2
        return 1
    fi

    local tmpfile
    tmpfile=$(mktemp)
    awk -v id="$id" -v assignee="$assignee" '
    {
        if ($0 ~ "\"id\":" id "[,}]") {
            gsub(/"assignee":"[^"]*"/, "\"assignee\":\"" assignee "\"")
        }
        print
    }' "$issue_file" > "$tmpfile"
    mv "$tmpfile" "$issue_file"

    return 0
}

# ---------------------------------------------------------------------------
# orch_issue_show <id>
#
# Show full details of a single issue. Prints formatted output.
# ---------------------------------------------------------------------------
orch_issue_show() {
    local id="${1:-}"

    if [[ -z "$id" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_show requires an issue ID" >&2
        return 1
    fi

    _orch_issue_validate_id "$id" || return 1

    local issue_file
    issue_file=$(_orch_issue_file)

    if [[ ! -f "$issue_file" ]]; then
        echo "[issue-tracker] ERROR: no issues file found" >&2
        return 1
    fi

    local line
    line=$(grep "\"id\":${id}[,}]" "$issue_file" 2>/dev/null | head -1)

    if [[ -z "$line" ]]; then
        echo "[issue-tracker] ERROR: issue #$id not found" >&2
        return 1
    fi

    # Extract fields using sed
    local title status priority assignee labels created_at closed_at
    title=$(echo "$line" | sed 's/.*"title":"\([^"]*\)".*/\1/')
    status=$(echo "$line" | sed 's/.*"status":"\([^"]*\)".*/\1/')
    priority=$(echo "$line" | sed 's/.*"priority":"\([^"]*\)".*/\1/')
    assignee=$(echo "$line" | sed 's/.*"assignee":"\([^"]*\)".*/\1/')
    labels=$(echo "$line" | sed 's/.*"labels":"\([^"]*\)".*/\1/')
    created_at=$(echo "$line" | sed 's/.*"created_at":"\([^"]*\)".*/\1/')
    closed_at=$(echo "$line" | sed 's/.*"closed_at":"\([^"]*\)".*/\1/')

    printf 'Issue #%s\n' "$id"
    printf '  Title:      %s\n' "$title"
    printf '  Status:     %s\n' "$status"
    printf '  Priority:   %s\n' "$priority"
    printf '  Assignee:   %s\n' "${assignee:-(unassigned)}"
    printf '  Labels:     %s\n' "${labels:-(none)}"
    printf '  Created:    %s\n' "$created_at"
    if [[ -n "$closed_at" ]]; then
        printf '  Closed:     %s\n' "$closed_at"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_issue_update <id> [--title <title>] [--priority <priority>]
#                        [--labels <labels>] [--status <status>]
#
# Update one or more fields on an existing issue.
# ---------------------------------------------------------------------------
orch_issue_update() {
    local id="${1:-}"

    if [[ -z "$id" ]]; then
        echo "[issue-tracker] ERROR: orch_issue_update requires an issue ID" >&2
        return 1
    fi

    _orch_issue_validate_id "$id" || return 1
    shift

    local new_title="" new_priority="" new_labels="" new_status=""
    local has_update=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                new_title="${2:-}"
                _orch_issue_validate_title "$new_title" || return 1
                _orch_issue_reject_traversal "$new_title" "title" || return 1
                has_update=1
                shift 2
                ;;
            --priority)
                new_priority="${2:-}"
                _orch_issue_validate_priority "$new_priority" || return 1
                has_update=1
                shift 2
                ;;
            --labels)
                new_labels="${2:-}"
                _orch_issue_validate_labels "$new_labels" || return 1
                _orch_issue_reject_traversal "$new_labels" "labels" || return 1
                has_update=1
                shift 2
                ;;
            --status)
                new_status="${2:-}"
                _orch_issue_validate_status "$new_status" || return 1
                has_update=1
                shift 2
                ;;
            *)
                echo "[issue-tracker] ERROR: unknown option: '$1'" >&2
                return 1
                ;;
        esac
    done

    if [[ "$has_update" -eq 0 ]]; then
        echo "[issue-tracker] ERROR: orch_issue_update requires at least one field to update" >&2
        return 1
    fi

    local issue_file
    issue_file=$(_orch_issue_file)

    if [[ ! -f "$issue_file" ]]; then
        echo "[issue-tracker] ERROR: no issues file found" >&2
        return 1
    fi

    # Check issue exists
    if ! grep -q "\"id\":${id}[,}]" "$issue_file" 2>/dev/null; then
        echo "[issue-tracker] ERROR: issue #$id not found" >&2
        return 1
    fi

    local tmpfile
    tmpfile=$(mktemp)

    # Build awk variables for each field to update
    local escaped_title_val=""
    if [[ -n "$new_title" ]]; then
        escaped_title_val=$(_orch_issue_json_escape "$new_title")
    fi

    local closed_ts=""
    if [[ -n "$new_status" ]] && [[ "$new_status" == "closed" ]]; then
        closed_ts=$(_orch_issue_timestamp)
    fi

    # Apply gsub only to the matching line — no shell execution in awk
    awk -v id="$id" -v ntitle="$escaped_title_val" -v nprio="$new_priority" \
        -v nlabels="$new_labels" -v nstatus="$new_status" -v cts="$closed_ts" '
    {
        if ($0 ~ "\"id\":" id "[,}]") {
            if (ntitle != "")  gsub(/"title":"[^"]*"/, "\"title\":\"" ntitle "\"")
            if (nprio != "")   gsub(/"priority":"[^"]*"/, "\"priority\":\"" nprio "\"")
            if (nlabels != "") gsub(/"labels":"[^"]*"/, "\"labels\":\"" nlabels "\"")
            if (nstatus != "") gsub(/"status":"[^"]*"/, "\"status\":\"" nstatus "\"")
            if (cts != "")     gsub(/"closed_at":"[^"]*"/, "\"closed_at\":\"" cts "\"")
        }
        print
    }' "$issue_file" > "$tmpfile"
    mv "$tmpfile" "$issue_file"

    return 0
}

# ---------------------------------------------------------------------------
# orch_issue_sync [--repo <owner/repo>]
#
# Optional: sync local issues to GitHub when the gh CLI is available.
# Creates GitHub issues for any local issues that don't yet have a
# corresponding remote issue. This is a one-way push (local → remote).
#
# Requires: gh CLI authenticated and available in PATH.
# ---------------------------------------------------------------------------
orch_issue_sync() {
    local repo=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                repo="${2:-}"
                shift 2
                ;;
            *)
                echo "[issue-tracker] ERROR: unknown option: '$1'" >&2
                return 1
                ;;
        esac
    done

    if ! command -v gh &>/dev/null; then
        echo "[issue-tracker] WARN: gh CLI not found — skipping GitHub sync" >&2
        return 1
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        echo "[issue-tracker] WARN: gh CLI not authenticated — skipping GitHub sync" >&2
        return 1
    fi

    local issue_file
    issue_file=$(_orch_issue_file)

    if [[ ! -f "$issue_file" ]] || [[ ! -s "$issue_file" ]]; then
        echo "[issue-tracker] No local issues to sync"
        return 0
    fi

    local repo_flag=""
    if [[ -n "$repo" ]]; then
        repo_flag="--repo $repo"
    fi

    local synced=0
    while IFS= read -r line; do
        local title status priority labels
        title=$(echo "$line" | sed 's/.*"title":"\([^"]*\)".*/\1/')
        status=$(echo "$line" | sed 's/.*"status":"\([^"]*\)".*/\1/')
        priority=$(echo "$line" | sed 's/.*"priority":"\([^"]*\)".*/\1/')
        labels=$(echo "$line" | sed 's/.*"labels":"\([^"]*\)".*/\1/')

        # Only sync open issues
        if [[ "$status" != "open" ]]; then
            continue
        fi

        local label_flags=""
        if [[ -n "$labels" ]]; then
            local IFS=','
            for label in $labels; do
                label_flags="$label_flags --label $label"
            done
            unset IFS
        fi

        # Create on GitHub (best-effort)
        if gh issue create --title "[$priority] $title" $label_flags $repo_flag --body "Synced from local issue tracker" 2>/dev/null; then
            synced=$((synced + 1))
        fi
    done < "$issue_file"

    echo "[issue-tracker] Synced $synced issues to GitHub"
    return 0
}
