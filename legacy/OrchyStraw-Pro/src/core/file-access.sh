#!/usr/bin/env bash
# =============================================================================
# file-access.sh — 4-zone file access model for OrchyStraw (#66)
#
# Enforces file access zones so agents can only modify files they own.
# Four zones, checked in order:
#   1. Protected — no agent can modify (orchestrator infra)
#   2. Owned     — files the agent owns per agents.conf (read-write)
#   3. Shared    — files any agent can read/write (cross-agent comms)
#   4. Unowned   — files owned by another agent (read-only)
#   (fallback)   — unknown files get read-only access
#
# Usage:
#   source src/core/file-access.sh
#
#   orch_access_init "/path/to/project"
#   orch_access_parse_config "scripts/agents.conf"
#
#   # Check a single file
#   orch_access_check "06-backend" "src/core/foo.sh"
#   # => "owned:read-write"
#
#   orch_access_check "11-web" "src/core/foo.sh"
#   # => "unowned:read-only"
#
#   orch_access_check "06-backend" "scripts/auto-agent.sh"
#   # => "protected:denied"
#
#   # Boolean checks
#   if orch_access_can_write "06-backend" "src/core/foo.sh"; then
#       echo "write allowed"
#   fi
#
#   # Validate a batch of writes
#   orch_access_validate_writes "11-web" "site/index.html site/about.html src/core/foo.sh"
#   # => prints violations to stderr, returns 1
#
#   # Inspect zones
#   orch_access_zone_for "prompts/00-shared-context/context.md"
#   # => "shared"
#
#   orch_access_report
#
# Public API:
#   orch_access_init <project_root>          — initialize with project root
#   orch_access_set_protected <paths>        — set protected zone paths
#   orch_access_set_shared <paths>           — set shared zone paths
#   orch_access_register_ownership <id> <paths> — register agent's owned paths
#   orch_access_parse_config <conf_file>     — auto-populate from agents.conf
#   orch_access_check <id> <path>            — zone:permission via stdout
#   orch_access_can_write <id> <path>        — 0 if write allowed, 1 if not
#   orch_access_can_read <id> <path>         — 0 always, except protected=1
#   orch_access_validate_writes <id> <files> — 0 if all writable, 1 if any bad
#   orch_access_report                       — formatted zone/agent report
#   orch_access_zone_for <path>              — zone name only (no agent ctx)
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_FILE_ACCESS_LOADED:-}" ]] && return 0
readonly _ORCH_FILE_ACCESS_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g  _ORCH_ACCESS_ROOT=""               # Project root (absolute)
declare -ga _ORCH_ACCESS_PROTECTED=()          # Protected path prefixes
declare -ga _ORCH_ACCESS_SHARED=()             # Shared path prefixes
declare -gA _ORCH_ACCESS_OWNERSHIP=()          # agent_id → space-separated owned prefixes
declare -gA _ORCH_ACCESS_EXCLUSIONS=()         # agent_id → space-separated excluded prefixes
declare -ga _ORCH_ACCESS_ALL_AGENTS=()         # ordered list of registered agent IDs

# Default protected paths
readonly _ORCH_ACCESS_DEFAULT_PROTECTED="scripts/auto-agent.sh scripts/agents.conf scripts/check-usage.sh CLAUDE.md .orchystraw/"

# Default shared paths
readonly _ORCH_ACCESS_DEFAULT_SHARED="prompts/00-shared-context/ prompts/99-me/"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_fa_trim <string>
#   Strip leading and trailing whitespace; print the result.
_orch_fa_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# _orch_fa_normalize_path <path>
#   Remove leading ./ and ensure no double slashes. Does NOT resolve symlinks.
_orch_fa_normalize_path() {
    local p="$1"
    # Strip leading ./
    while [[ "$p" == ./* ]]; do
        p="${p#./}"
    done
    # Collapse double slashes
    while [[ "$p" == *//* ]]; do
        p="${p//\/\///}"
    done
    printf '%s' "$p"
}

# _orch_fa_matches_prefix <path> <prefix>
#   Returns 0 if path starts with prefix, or if path equals prefix.
#   Handles both directory prefixes (ending in /) and exact file matches.
_orch_fa_matches_prefix() {
    local path="$1" prefix="$2"
    path=$(_orch_fa_normalize_path "$path")
    prefix=$(_orch_fa_normalize_path "$prefix")

    # Exact match
    [[ "$path" == "$prefix" ]] && return 0

    # Prefix match — if prefix ends with /, check starts-with
    if [[ "$prefix" == */ ]]; then
        [[ "$path" == "${prefix}"* ]] && return 0
    else
        # For non-directory prefixes, match as path prefix with / boundary
        [[ "$path" == "${prefix}/"* ]] && return 0
    fi

    return 1
}

# _orch_fa_check_protected <path>
#   Returns 0 if path is in the protected zone.
_orch_fa_check_protected() {
    local path="$1"
    local prefix
    for prefix in "${_ORCH_ACCESS_PROTECTED[@]}"; do
        if _orch_fa_matches_prefix "$path" "$prefix"; then
            return 0
        fi
    done
    return 1
}

# _orch_fa_check_owned <agent_id> <path>
#   Returns 0 if path is owned by agent (and not excluded).
_orch_fa_check_owned() {
    local agent_id="$1" path="$2"
    local owned="${_ORCH_ACCESS_OWNERSHIP[$agent_id]:-}"
    local excluded="${_ORCH_ACCESS_EXCLUSIONS[$agent_id]:-}"

    [[ -z "$owned" ]] && return 1

    # Check exclusions first
    local -a excluded_arr
    IFS=' ' read -ra excluded_arr <<< "$excluded"
    local ex
    for ex in "${excluded_arr[@]}"; do
        if _orch_fa_matches_prefix "$path" "$ex"; then
            return 1
        fi
    done

    # Check ownership
    local -a owned_arr
    IFS=' ' read -ra owned_arr <<< "$owned"
    local prefix
    for prefix in "${owned_arr[@]}"; do
        if _orch_fa_matches_prefix "$path" "$prefix"; then
            return 0
        fi
    done

    return 1
}

# _orch_fa_check_shared <path>
#   Returns 0 if path is in the shared zone.
_orch_fa_check_shared() {
    local path="$1"
    local prefix
    for prefix in "${_ORCH_ACCESS_SHARED[@]}"; do
        if _orch_fa_matches_prefix "$path" "$prefix"; then
            return 0
        fi
    done
    return 1
}

# _orch_fa_check_unowned <agent_id> <path>
#   Returns 0 if path is owned by a different agent.
_orch_fa_check_unowned() {
    local agent_id="$1" path="$2"
    local other_id
    for other_id in "${_ORCH_ACCESS_ALL_AGENTS[@]}"; do
        [[ "$other_id" == "$agent_id" ]] && continue
        if _orch_fa_check_owned "$other_id" "$path"; then
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# orch_access_init <project_root>
#
# Initialize the file access module. Sets the project root and resets all
# state. Populates protected and shared zones with defaults.
# ---------------------------------------------------------------------------
orch_access_init() {
    local root="${1:?orch_access_init: project_root required}"

    _ORCH_ACCESS_ROOT="$root"
    _ORCH_ACCESS_PROTECTED=()
    _ORCH_ACCESS_SHARED=()
    _ORCH_ACCESS_OWNERSHIP=()
    _ORCH_ACCESS_EXCLUSIONS=()
    _ORCH_ACCESS_ALL_AGENTS=()

    # Apply defaults
    orch_access_set_protected "$_ORCH_ACCESS_DEFAULT_PROTECTED"
    orch_access_set_shared "$_ORCH_ACCESS_DEFAULT_SHARED"
}

# ---------------------------------------------------------------------------
# orch_access_set_protected <space-separated-paths>
#
# Replace the protected zone with the given paths.
# ---------------------------------------------------------------------------
orch_access_set_protected() {
    local paths="${1:?orch_access_set_protected: paths required}"
    _ORCH_ACCESS_PROTECTED=()
    local -a paths_arr
    IFS=' ' read -ra paths_arr <<< "$paths"
    local p
    for p in "${paths_arr[@]}"; do
        _ORCH_ACCESS_PROTECTED+=("$p")
    done
}

# ---------------------------------------------------------------------------
# orch_access_set_shared <space-separated-paths>
#
# Replace the shared zone with the given paths.
# ---------------------------------------------------------------------------
orch_access_set_shared() {
    local paths="${1:?orch_access_set_shared: paths required}"
    _ORCH_ACCESS_SHARED=()
    local -a paths_arr
    IFS=' ' read -ra paths_arr <<< "$paths"
    local p
    for p in "${paths_arr[@]}"; do
        _ORCH_ACCESS_SHARED+=("$p")
    done
}

# ---------------------------------------------------------------------------
# orch_access_register_ownership <agent_id> <space-separated-ownership>
#
# Register owned paths for an agent. Paths prefixed with ! are exclusions.
# Calling again for the same agent replaces previous ownership.
# ---------------------------------------------------------------------------
orch_access_register_ownership() {
    local agent_id="${1:?orch_access_register_ownership: agent_id required}"
    local ownership="${2:?orch_access_register_ownership: ownership required}"

    local owned="" excluded=""
    local -a ownership_arr
    IFS=' ' read -ra ownership_arr <<< "$ownership"
    local entry
    for entry in "${ownership_arr[@]}"; do
        if [[ "$entry" == !* ]]; then
            # Strip the ! prefix for exclusion paths
            excluded="${excluded} ${entry#!}"
        else
            owned="${owned} ${entry}"
        fi
    done

    _ORCH_ACCESS_OWNERSHIP["$agent_id"]="$(_orch_fa_trim "$owned")"
    _ORCH_ACCESS_EXCLUSIONS["$agent_id"]="$(_orch_fa_trim "$excluded")"

    # Track agent in the ordered list (avoid duplicates)
    local existing
    for existing in "${_ORCH_ACCESS_ALL_AGENTS[@]}"; do
        [[ "$existing" == "$agent_id" ]] && return 0
    done
    _ORCH_ACCESS_ALL_AGENTS+=("$agent_id")
}

# ---------------------------------------------------------------------------
# orch_access_parse_config <conf_file>
#
# Parse an agents.conf file and auto-populate ownership for all agents.
# Ownership is column 3 (pipe-delimited, 0-indexed). Skips comments and
# blank lines. Trims whitespace from all fields.
# ---------------------------------------------------------------------------
orch_access_parse_config() {
    local conf_file="${1:?orch_access_parse_config: conf_file required}"

    if [[ ! -r "$conf_file" ]]; then
        printf '[file-access] ERROR: cannot read config: %s\n' "$conf_file" >&2
        return 1
    fi

    while IFS= read -r raw_line; do
        # Skip blank lines
        [[ -z "${raw_line// /}" ]] && continue

        # Skip comments
        local trimmed
        trimmed=$(_orch_fa_trim "$raw_line")
        [[ "$trimmed" == \#* ]] && continue

        # Split on pipe
        local f_id f_prompt f_ownership f_interval f_label
        IFS='|' read -r f_id f_prompt f_ownership f_interval f_label <<< "$raw_line"

        f_id=$(_orch_fa_trim "$f_id")
        f_ownership=$(_orch_fa_trim "$f_ownership")

        [[ -z "$f_id" ]] && continue
        [[ -z "$f_ownership" ]] && continue

        orch_access_register_ownership "$f_id" "$f_ownership"
    done < "$conf_file"
}

# ---------------------------------------------------------------------------
# orch_access_check <agent_id> <file_path>
#
# Determine the zone and permission for a given agent+path combination.
# Prints "zone:permission" to stdout. Possible outputs:
#   protected:denied
#   owned:read-write
#   shared:read-write
#   unowned:read-only
#   unknown:read-only
# ---------------------------------------------------------------------------
orch_access_check() {
    local agent_id="${1:?orch_access_check: agent_id required}"
    local file_path="${2:?orch_access_check: file_path required}"

    file_path=$(_orch_fa_normalize_path "$file_path")

    # 1. Protected zone
    if _orch_fa_check_protected "$file_path"; then
        printf 'protected:denied\n'
        return 0
    fi

    # 2. Owned zone
    if _orch_fa_check_owned "$agent_id" "$file_path"; then
        printf 'owned:read-write\n'
        return 0
    fi

    # 3. Shared zone
    if _orch_fa_check_shared "$file_path"; then
        printf 'shared:read-write\n'
        return 0
    fi

    # 4. Unowned zone (another agent owns it)
    if _orch_fa_check_unowned "$agent_id" "$file_path"; then
        printf 'unowned:read-only\n'
        return 0
    fi

    # 5. Unknown
    printf 'unknown:read-only\n'
}

# ---------------------------------------------------------------------------
# orch_access_can_write <agent_id> <file_path>
#
# Returns 0 if the agent is allowed to write to the file, 1 otherwise.
# Write is allowed only in owned and shared zones.
# ---------------------------------------------------------------------------
orch_access_can_write() {
    local agent_id="${1:?orch_access_can_write: agent_id required}"
    local file_path="${2:?orch_access_can_write: file_path required}"

    local result
    result=$(orch_access_check "$agent_id" "$file_path")

    case "$result" in
        owned:read-write|shared:read-write) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# orch_access_can_read <agent_id> <file_path>
#
# Returns 0 if the agent is allowed to read the file.
# All zones are readable except protected (returns 1 for non-orchestrator).
# The special agent id "orchestrator" bypasses protection.
# ---------------------------------------------------------------------------
orch_access_can_read() {
    local agent_id="${1:?orch_access_can_read: agent_id required}"
    local file_path="${2:?orch_access_can_read: file_path required}"

    file_path=$(_orch_fa_normalize_path "$file_path")

    # Protected files are unreadable unless the caller is the orchestrator
    if _orch_fa_check_protected "$file_path"; then
        [[ "$agent_id" == "orchestrator" ]] && return 0
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_access_validate_writes <agent_id> <file_list>
#
# Check a space-separated list of files for write permission.
# Returns 0 if all files are writable, 1 if any violations.
# Violations are printed to stderr.
# ---------------------------------------------------------------------------
orch_access_validate_writes() {
    local agent_id="${1:?orch_access_validate_writes: agent_id required}"
    local file_list="${2:?orch_access_validate_writes: file_list required}"

    local violations=0
    local -a file_list_arr
    IFS=' ' read -ra file_list_arr <<< "$file_list"
    local f result
    for f in "${file_list_arr[@]}"; do
        if ! orch_access_can_write "$agent_id" "$f"; then
            result=$(orch_access_check "$agent_id" "$f")
            printf '[file-access] VIOLATION: agent=%s file=%s zone=%s\n' \
                "$agent_id" "$f" "$result" >&2
            (( violations++ )) || true
        fi
    done

    [[ "$violations" -eq 0 ]] && return 0
    return 1
}

# ---------------------------------------------------------------------------
# orch_access_zone_for <file_path>
#
# Returns just the zone name for a path, with no agent context.
# Checks: protected → shared → owned-by-any → unknown.
# ---------------------------------------------------------------------------
orch_access_zone_for() {
    local file_path="${1:?orch_access_zone_for: file_path required}"

    file_path=$(_orch_fa_normalize_path "$file_path")

    # Protected
    if _orch_fa_check_protected "$file_path"; then
        printf 'protected\n'
        return 0
    fi

    # Shared
    if _orch_fa_check_shared "$file_path"; then
        printf 'shared\n'
        return 0
    fi

    # Owned by any agent
    local agent_id
    for agent_id in "${_ORCH_ACCESS_ALL_AGENTS[@]}"; do
        if _orch_fa_check_owned "$agent_id" "$file_path"; then
            printf 'owned\n'
            return 0
        fi
    done

    printf 'unknown\n'
}

# ---------------------------------------------------------------------------
# orch_access_report
#
# Print a formatted report of all zones and registered agents.
# ---------------------------------------------------------------------------
orch_access_report() {
    printf '=== File Access Report ===\n'
    printf 'Project root: %s\n\n' "$_ORCH_ACCESS_ROOT"

    printf '── Protected Zone ──\n'
    local p
    for p in "${_ORCH_ACCESS_PROTECTED[@]}"; do
        printf '  %s\n' "$p"
    done
    printf '\n'

    printf '── Shared Zone ──\n'
    for p in "${_ORCH_ACCESS_SHARED[@]}"; do
        printf '  %s\n' "$p"
    done
    printf '\n'

    printf '── Agent Ownership ──\n'
    local agent_id
    for agent_id in "${_ORCH_ACCESS_ALL_AGENTS[@]}"; do
        local owned="${_ORCH_ACCESS_OWNERSHIP[$agent_id]:-}"
        local excluded="${_ORCH_ACCESS_EXCLUSIONS[$agent_id]:-}"
        printf '  %-14s owns: %s\n' "$agent_id" "$owned"
        if [[ -n "$excluded" ]]; then
            printf '  %-14s excl: %s\n' "" "$excluded"
        fi
    done
    printf '\n'
}
