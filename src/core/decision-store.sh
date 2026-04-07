#!/usr/bin/env bash
# =============================================================================
# decision-store.sh — Persist orchestration decisions + user inputs across
# cycles and sessions.
#
# Stores decisions as JSONL in .orchystraw/decisions.jsonl. Each entry records
# who (actor) did what (type), with details, timestamps, and cycle context.
#
# Provides:
#   orch_decision_init          — Create decisions.jsonl if not exists
#   orch_decision_log           — Append a decision to the JSONL log
#   orch_decision_query         — Search decisions with filters
#   orch_decision_summarize     — Generate markdown summary of recent decisions
#   orch_decision_review_log    — Log --review mode responses (y/n/s per agent)
#
# Usage:
#   source src/core/decision-store.sh
#   orch_decision_init
#   orch_decision_log "cofounder" "interval_change" "agent=06-backend from=1 to=2 reason=idle 3 cycles"
#   orch_decision_query --actor cofounder --last 5
#   orch_decision_summarize --last 20
#   orch_decision_review_log "06-backend" "y" 7
#
# Requires: bash 4.0+, date with -u support
# =============================================================================

[[ -n "${_ORCH_DECISION_STORE_LOADED:-}" ]] && return 0
_ORCH_DECISION_STORE_LOADED=1

# ── Constants ──

_ORCH_DECISION_DIR=".orchystraw"
_ORCH_DECISION_FILE="${_ORCH_DECISION_DIR}/decisions.jsonl"

# Valid actors and types for validation
_ORCH_DECISION_VALID_ACTORS="cofounder pm founder system"
_ORCH_DECISION_VALID_TYPES="interval_change model_change priority_change approval escalation review_response"

# ── Internal state ──

declare -g _ORCH_DECISION_INITED=false
declare -g _ORCH_DECISION_PROJECT_ROOT=""

# ── Logging helper ──

_decision_log() {
    local level="$1" msg="$2"
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$level" "decision-store" "$msg"
    fi
}

# ── JSON helpers ──

# Escape a string for safe JSON embedding (no jq dependency)
_decision_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Get ISO 8601 UTC timestamp
_decision_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S'
}

# =============================================================================
# orch_decision_init [project_root]
#
# Create .orchystraw/decisions.jsonl if it does not exist.
# If project_root is given, operates relative to that directory;
# otherwise uses the current working directory.
#
# Returns: 0 on success, 1 on failure
# =============================================================================

orch_decision_init() {
    local project_root="${1:-${PROJECT_ROOT:-.}}"
    _ORCH_DECISION_PROJECT_ROOT="$project_root"

    local dir="$project_root/$_ORCH_DECISION_DIR"
    local file="$project_root/$_ORCH_DECISION_FILE"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            _decision_log "ERROR" "Failed to create directory: $dir"
            return 1
        }
    fi

    if [[ ! -f "$file" ]]; then
        touch "$file" || {
            _decision_log "ERROR" "Failed to create decisions file: $file"
            return 1
        }
    fi

    _ORCH_DECISION_INITED=true
    _decision_log "INFO" "Decision store initialized: $file"
    return 0
}

# =============================================================================
# orch_decision_log <actor> <type> <details>
#
# Append a decision record to the JSONL log.
#
# Arguments:
#   actor   — cofounder|pm|founder|system
#   type    — interval_change|model_change|priority_change|approval|escalation|review_response
#   details — free-form key=value pairs (e.g. "agent=06-backend from=1 to=2 reason=idle 3 cycles")
#
# The current cycle number is read from the CYCLE global variable if set.
#
# Format: {"ts":"...","cycle":N,"actor":"...","type":"...","details":{...}}
#
# Returns: 0 on success, 1 on validation error, 2 if not initialized
# =============================================================================

orch_decision_log() {
    local actor="${1:?orch_decision_log: actor required}"
    local dtype="${2:?orch_decision_log: type required}"
    local details="${3:-}"

    if [[ "$_ORCH_DECISION_INITED" != "true" ]]; then
        _decision_log "ERROR" "Decision store not initialized — call orch_decision_init first"
        return 2
    fi

    # Validate actor
    local valid=false
    local a
    for a in $_ORCH_DECISION_VALID_ACTORS; do
        [[ "$a" == "$actor" ]] && valid=true
    done
    if [[ "$valid" != "true" ]]; then
        _decision_log "WARN" "Invalid actor: $actor (valid: $_ORCH_DECISION_VALID_ACTORS)"
        return 1
    fi

    # Validate type
    valid=false
    local t
    for t in $_ORCH_DECISION_VALID_TYPES; do
        [[ "$t" == "$dtype" ]] && valid=true
    done
    if [[ "$valid" != "true" ]]; then
        _decision_log "WARN" "Invalid type: $dtype (valid: $_ORCH_DECISION_VALID_TYPES)"
        return 1
    fi

    local ts
    ts="$(_decision_timestamp)"
    local cycle="${CYCLE:-0}"
    local file="$_ORCH_DECISION_PROJECT_ROOT/$_ORCH_DECISION_FILE"

    # Parse details key=value pairs into JSON object fields
    # Strategy: find all key= positions, then extract value as text between them
    local details_json=""
    if [[ -n "$details" ]]; then
        # First, collect all key=value pair boundaries
        local -a keys=()
        local -a values=()
        local -a positions=()

        # Find positions of each key= pattern using iterative matching
        local tmp="$details"
        local offset=0
        # Match optionally leading non-= chars + whitespace, then key=
        local _re='^([^=]*[[:space:]])([a-zA-Z_][a-zA-Z0-9_]*)=(.*)'
        local _re_start='^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)'
        while [[ -n "$tmp" ]]; do
            local prefix="" key="" after=""
            if [[ "$tmp" =~ $_re_start ]]; then
                # Key at start of string
                key="${BASH_REMATCH[1]}"
                after="${BASH_REMATCH[2]}"
                prefix=""
            elif [[ "$tmp" =~ $_re ]]; then
                prefix="${BASH_REMATCH[1]}"
                key="${BASH_REMATCH[2]}"
                after="${BASH_REMATCH[3]}"
            else
                break
            fi
            local pos=$(( offset + ${#prefix} ))
            keys+=("$key")
            positions+=("$pos")
            # Move past "key=" to continue searching
            local skip=$(( ${#prefix} + ${#key} + 1 ))
            tmp="${details:$(( offset + skip ))}"
            offset=$(( offset + skip ))
        done

        # Now extract values: each value runs from after its key= to the start of the next key
        local num_keys=${#keys[@]}
        local k
        for (( k=0; k<num_keys; k++ )); do
            local key="${keys[$k]}"
            local val_start=$(( ${positions[$k]} + ${#key} + 1 ))  # after "key="
            local val_end
            if (( k + 1 < num_keys )); then
                val_end=${positions[$((k + 1))]}
            else
                val_end=${#details}
            fi
            local value="${details:$val_start:$((val_end - val_start))}"
            # Trim trailing whitespace from value
            value="${value%"${value##*[![:space:]]}"}"

            local escaped_key escaped_val
            escaped_key="$(_decision_json_escape "$key")"
            escaped_val="$(_decision_json_escape "$value")"
            [[ -n "$details_json" ]] && details_json="${details_json},"
            details_json="${details_json}\"${escaped_key}\":\"${escaped_val}\""
        done
    fi

    # Build the JSONL line
    local escaped_actor escaped_type
    escaped_actor="$(_decision_json_escape "$actor")"
    escaped_type="$(_decision_json_escape "$dtype")"

    local json_line
    json_line="{\"ts\":\"${ts}\",\"cycle\":${cycle},\"actor\":\"${escaped_actor}\",\"type\":\"${escaped_type}\""
    if [[ -n "$details_json" ]]; then
        json_line="${json_line},${details_json}}"
    else
        json_line="${json_line}}"
    fi

    printf '%s\n' "$json_line" >> "$file" || {
        _decision_log "ERROR" "Failed to write decision to $file"
        return 1
    }

    _decision_log "INFO" "Decision logged: actor=$actor type=$dtype cycle=$cycle"
    return 0
}

# =============================================================================
# orch_decision_query [flags]
#
# Search decisions with optional filters. Outputs matching JSONL lines.
#
# Flags:
#   --actor <actor>    Filter by actor
#   --type <type>      Filter by type
#   --since <date>     Filter entries on or after date (YYYY-MM-DD)
#   --agent <agent>    Filter entries containing agent ID in the line
#   --last <N>         Show only the last N matching entries
#   --table            Output as human-readable table instead of JSONL
#
# Returns: 0 on success (even if no matches), 1 if not initialized
# =============================================================================

orch_decision_query() {
    if [[ "$_ORCH_DECISION_INITED" != "true" ]]; then
        _decision_log "ERROR" "Decision store not initialized"
        return 1
    fi

    local filter_actor="" filter_type="" filter_since="" filter_agent=""
    local last_n=0 table_mode=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --actor)   filter_actor="$2"; shift 2 ;;
            --type)    filter_type="$2"; shift 2 ;;
            --since)   filter_since="$2"; shift 2 ;;
            --agent)   filter_agent="$2"; shift 2 ;;
            --last)    last_n="$2"; shift 2 ;;
            --table)   table_mode=true; shift ;;
            *)         shift ;;
        esac
    done

    local file="$_ORCH_DECISION_PROJECT_ROOT/$_ORCH_DECISION_FILE"
    [[ ! -f "$file" ]] && return 0

    # Collect matching lines
    local -a matches=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Filter by actor
        if [[ -n "$filter_actor" ]]; then
            [[ "$line" != *"\"actor\":\"${filter_actor}\""* ]] && continue
        fi

        # Filter by type
        if [[ -n "$filter_type" ]]; then
            [[ "$line" != *"\"type\":\"${filter_type}\""* ]] && continue
        fi

        # Filter by agent (substring match anywhere in the line)
        if [[ -n "$filter_agent" ]]; then
            [[ "$line" != *"${filter_agent}"* ]] && continue
        fi

        # Filter by since date (compare timestamp prefix)
        if [[ -n "$filter_since" ]]; then
            # Extract ts value from JSON line
            local ts_val=""
            if [[ "$line" =~ \"ts\":\"([^\"]+)\" ]]; then
                ts_val="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$ts_val" ]]; then
                # Compare date portion (YYYY-MM-DD)
                local ts_date="${ts_val:0:10}"
                [[ "$ts_date" < "$filter_since" ]] && continue
            fi
        fi

        matches+=("$line")
    done < "$file"

    # Apply --last N
    local total=${#matches[@]}
    local start=0
    if [[ "$last_n" -gt 0 && "$total" -gt "$last_n" ]]; then
        start=$(( total - last_n ))
    fi

    if [[ "$table_mode" == true ]]; then
        printf '%-20s %-6s %-12s %-18s %s\n' "TIMESTAMP" "CYCLE" "ACTOR" "TYPE" "DETAILS"
        printf '%-20s %-6s %-12s %-18s %s\n' "--------------------" "------" "------------" "------------------" "-------"
    fi

    local i
    for (( i=start; i<total; i++ )); do
        local entry="${matches[$i]}"
        if [[ "$table_mode" == true ]]; then
            # Extract fields for table display
            local ts="" cyc="" act="" typ=""
            [[ "$entry" =~ \"ts\":\"([^\"]+)\" ]] && ts="${BASH_REMATCH[1]}"
            [[ "$entry" =~ \"cycle\":([0-9]+) ]] && cyc="${BASH_REMATCH[1]}"
            [[ "$entry" =~ \"actor\":\"([^\"]+)\" ]] && act="${BASH_REMATCH[1]}"
            [[ "$entry" =~ \"type\":\"([^\"]+)\" ]] && typ="${BASH_REMATCH[1]}"
            # Details: everything after the type field
            local det=""
            # Remove the standard fields to get remaining details
            det="${entry#*\"type\":\"${typ}\"}"
            det="${det#,}"
            det="${det%\}}"
            [[ "$det" == "}" ]] && det=""
            printf '%-20s %-6s %-12s %-18s %s\n' "${ts:0:19}" "$cyc" "$act" "$typ" "$det"
        else
            printf '%s\n' "$entry"
        fi
    done

    return 0
}

# =============================================================================
# orch_decision_summarize [--last N]
#
# Generate a markdown summary of recent decisions. Groups by actor, shows
# counts by type, and highlights escalations.
#
# Flags:
#   --last <N>    Summarize only the last N decisions (default: all)
#
# Returns: 0 on success, 1 if not initialized
# =============================================================================

orch_decision_summarize() {
    if [[ "$_ORCH_DECISION_INITED" != "true" ]]; then
        _decision_log "ERROR" "Decision store not initialized"
        return 1
    fi

    local last_n=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --last) last_n="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local file="$_ORCH_DECISION_PROJECT_ROOT/$_ORCH_DECISION_FILE"
    [[ ! -f "$file" ]] && { printf '# Decision Summary\n\nNo decisions recorded.\n'; return 0; }

    # Read all lines
    local -a lines=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        lines+=("$line")
    done < "$file"

    local total=${#lines[@]}
    [[ "$total" -eq 0 ]] && { printf '# Decision Summary\n\nNo decisions recorded.\n'; return 0; }

    local start=0
    if [[ "$last_n" -gt 0 && "$total" -gt "$last_n" ]]; then
        start=$(( total - last_n ))
    fi

    # Count by actor and type
    declare -A actor_counts=()
    declare -A type_counts=()
    declare -A actor_type_counts=()
    local -a escalations=()
    local count=0

    local i
    for (( i=start; i<total; i++ )); do
        local entry="${lines[$i]}"
        local act="" typ=""
        [[ "$entry" =~ \"actor\":\"([^\"]+)\" ]] && act="${BASH_REMATCH[1]}"
        [[ "$entry" =~ \"type\":\"([^\"]+)\" ]] && typ="${BASH_REMATCH[1]}"

        actor_counts["$act"]=$(( ${actor_counts["$act"]:-0} + 1 ))
        type_counts["$typ"]=$(( ${type_counts["$typ"]:-0} + 1 ))
        actor_type_counts["${act}|${typ}"]=$(( ${actor_type_counts["${act}|${typ}"]:-0} + 1 ))
        count=$(( count + 1 ))

        if [[ "$typ" == "escalation" ]]; then
            escalations+=("$entry")
        fi
    done

    # Output markdown summary
    printf '# Decision Summary\n\n'
    printf '**Total decisions:** %d\n\n' "$count"

    # By actor
    printf '## By Actor\n\n'
    printf '| Actor | Count | Types |\n'
    printf '|-------|-------|-------|\n'
    for act in "${!actor_counts[@]}"; do
        local types_str=""
        for key in "${!actor_type_counts[@]}"; do
            if [[ "$key" == "${act}|"* ]]; then
                local t="${key#*|}"
                local c="${actor_type_counts[$key]}"
                [[ -n "$types_str" ]] && types_str="${types_str}, "
                types_str="${types_str}${t}(${c})"
            fi
        done
        printf '| %s | %d | %s |\n' "$act" "${actor_counts[$act]}" "$types_str"
    done

    # By type
    printf '\n## By Type\n\n'
    printf '| Type | Count |\n'
    printf '|------|-------|\n'
    for typ in "${!type_counts[@]}"; do
        printf '| %s | %d |\n' "$typ" "${type_counts[$typ]}"
    done

    # Escalations
    if [[ ${#escalations[@]} -gt 0 ]]; then
        printf '\n## Escalations\n\n'
        for esc in "${escalations[@]}"; do
            local ts="" cyc="" reason=""
            [[ "$esc" =~ \"ts\":\"([^\"]+)\" ]] && ts="${BASH_REMATCH[1]}"
            [[ "$esc" =~ \"cycle\":([0-9]+) ]] && cyc="${BASH_REMATCH[1]}"
            [[ "$esc" =~ \"reason\":\"([^\"]+)\" ]] && reason="${BASH_REMATCH[1]}"
            printf -- '- **Cycle %s** (%s): %s\n' "$cyc" "${ts:0:19}" "${reason:-no reason recorded}"
        done
    fi

    printf '\n'
    return 0
}

# =============================================================================
# orch_decision_review_log <agent_id> <response> [cycle]
#
# Log a --review mode response (y/n/s per agent).
#
# Arguments:
#   agent_id  — the agent being reviewed
#   response  — y (approved), n (rejected), s (skipped)
#   cycle     — cycle number (optional, defaults to CYCLE global or 0)
#
# Returns: 0 on success
# =============================================================================

orch_decision_review_log() {
    local agent_id="${1:?orch_decision_review_log: agent_id required}"
    local response="${2:?orch_decision_review_log: response required}"
    local cycle="${3:-${CYCLE:-0}}"

    # Normalize response to full word
    local response_word
    case "$response" in
        y|Y) response_word="approved" ;;
        n|N) response_word="rejected" ;;
        s|S) response_word="skipped" ;;
        *)   response_word="$response" ;;
    esac

    # Temporarily set CYCLE for orch_decision_log
    local saved_cycle="${CYCLE:-}"
    CYCLE="$cycle"

    orch_decision_log "founder" "review_response" "agent=${agent_id} response=${response_word}"
    local rc=$?

    # Restore CYCLE
    if [[ -n "$saved_cycle" ]]; then
        CYCLE="$saved_cycle"
    else
        unset CYCLE 2>/dev/null || true
    fi

    return $rc
}
