#!/usr/bin/env bash
# =============================================================================
# auto-researcher.sh — GitHub intelligence gathering for OrchyStraw (#v0.5)
#
# Monitors high-signal GitHub accounts (users/orgs) and extracts actionable
# engineering intelligence: new repos, stack changes, patterns, breaking changes.
#
# Design: uses `gh api` for all GitHub data. No scraping, no extra dependencies.
# Results cached in .orchystraw/research-cache/. Briefs written to research/briefs/.
#
# Usage:
#   source src/core/auto-researcher.sh
#
#   orch_research_init "/path/to/project"
#   orch_research_load_sources                     # parse research-sources.conf
#   orch_research_fetch "karpathy"                 # fetch one source
#   orch_research_analyze "karpathy"               # analyze fetched data
#   orch_research_report                           # write research brief
#   orch_research_run                              # full cycle: all sources
#
# Requires: gh CLI (authenticated), bash 5.0+, jq
# =============================================================================

[[ -n "${_ORCH_RESEARCHER_LOADED:-}" ]] && return 0
readonly _ORCH_RESEARCHER_LOADED=1

# ── State ──
declare -g _ORCH_RES_PROJECT=""
declare -g _ORCH_RES_CACHE_DIR=""
declare -g _ORCH_RES_BRIEFS_DIR=""
declare -g _ORCH_RES_CONF=""
declare -g _ORCH_RES_INITED=false
declare -g -i _ORCH_RES_API_CALLS=0
declare -g -i _ORCH_RES_API_LIMIT=30
declare -g -a _ORCH_RES_SOURCES=()       # "account|type|priority|notes"
declare -g -a _ORCH_RES_FINDINGS=()      # collected findings for the brief

# ── Helpers ──

_orch_res_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "researcher" "$2"
    else
        printf '[%s] [%s] [researcher] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >&2
    fi
}

_orch_res_today() {
    date '+%Y-%m-%d'
}

_orch_res_week_ago() {
    if date -v-7d '+%Y-%m-%dT00:00:00Z' 2>/dev/null; then
        return 0
    fi
    # Linux fallback
    date -d '7 days ago' '+%Y-%m-%dT00:00:00Z' 2>/dev/null || date '+%Y-%m-%dT00:00:00Z'
}

_orch_res_api_call() {
    if (( _ORCH_RES_API_CALLS >= _ORCH_RES_API_LIMIT )); then
        _orch_res_log WARN "API rate limit reached ($_ORCH_RES_API_LIMIT calls). Skipping."
        return 1
    fi
    (( _ORCH_RES_API_CALLS++ ))
    gh api "$@" 2>/dev/null
}

# ── Public API ──

# ---------------------------------------------------------------------------
# orch_research_init — initialize the researcher subsystem
# Args: $1 — project root directory
# ---------------------------------------------------------------------------
orch_research_init() {
    local project_root="${1:?orch_research_init requires a project directory}"

    if ! command -v gh &>/dev/null; then
        _orch_res_log ERROR "gh CLI not found — install GitHub CLI first"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        _orch_res_log ERROR "jq not found — install jq first"
        return 1
    fi

    _ORCH_RES_PROJECT="$project_root"
    _ORCH_RES_CACHE_DIR="${project_root}/.orchystraw/research-cache"
    _ORCH_RES_BRIEFS_DIR="${project_root}/research/briefs"
    _ORCH_RES_CONF="${project_root}/research-sources.conf"

    mkdir -p "$_ORCH_RES_CACHE_DIR" 2>/dev/null || {
        _orch_res_log ERROR "cannot create cache dir: $_ORCH_RES_CACHE_DIR"
        return 1
    }
    mkdir -p "$_ORCH_RES_BRIEFS_DIR" 2>/dev/null || {
        _orch_res_log ERROR "cannot create briefs dir: $_ORCH_RES_BRIEFS_DIR"
        return 1
    }

    _ORCH_RES_API_CALLS=0
    _ORCH_RES_SOURCES=()
    _ORCH_RES_FINDINGS=()
    _ORCH_RES_INITED=true
    _orch_res_log INFO "initialized: project=$project_root"
}

# ---------------------------------------------------------------------------
# orch_research_load_sources — parse research-sources.conf
# Populates _ORCH_RES_SOURCES array
# ---------------------------------------------------------------------------
orch_research_load_sources() {
    if [[ "$_ORCH_RES_INITED" != "true" ]]; then
        _orch_res_log ERROR "not initialized — call orch_research_init first"
        return 1
    fi

    if [[ ! -f "$_ORCH_RES_CONF" ]]; then
        _orch_res_log ERROR "sources config not found: $_ORCH_RES_CONF"
        return 1
    fi

    _ORCH_RES_SOURCES=()
    local line account src_type priority notes
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Parse pipe-delimited fields
        IFS='|' read -r account src_type priority notes <<< "$line"
        account="${account// /}"
        src_type="${src_type// /}"
        priority="${priority// /}"
        notes="${notes#"${notes%%[![:space:]]*}"}"   # ltrim
        notes="${notes%"${notes##*[![:space:]]}"}"   # rtrim

        if [[ -z "$account" || -z "$src_type" ]]; then
            _orch_res_log WARN "skipping malformed line: $line"
            continue
        fi

        _ORCH_RES_SOURCES+=("${account}|${src_type}|${priority}|${notes}")
    done < "$_ORCH_RES_CONF"

    _orch_res_log INFO "loaded ${#_ORCH_RES_SOURCES[@]} sources from config"
}

# ---------------------------------------------------------------------------
# orch_research_fetch — fetch latest data for a single source
# Args: $1 — account name, $2 — type (user/org)
# Writes JSON cache to .orchystraw/research-cache/<account>-<date>.json
# ---------------------------------------------------------------------------
orch_research_fetch() {
    local account="${1:?orch_research_fetch: account required}"
    local src_type="${2:-user}"
    local today cache_file since

    if [[ "$_ORCH_RES_INITED" != "true" ]]; then
        _orch_res_log ERROR "not initialized — call orch_research_init first"
        return 1
    fi

    today="$(_orch_res_today)"
    cache_file="${_ORCH_RES_CACHE_DIR}/${account}-${today}.json"

    # Skip if already fetched today
    if [[ -f "$cache_file" && -s "$cache_file" ]]; then
        _orch_res_log INFO "using cached data for $account ($today)"
        return 0
    fi

    since="$(_orch_res_week_ago)"
    _orch_res_log INFO "fetching repos for $account (type=$src_type, since=$since)"

    local repos_endpoint
    if [[ "$src_type" == "org" ]]; then
        repos_endpoint="orgs/${account}/repos?sort=updated&per_page=10&since=${since}"
    else
        repos_endpoint="users/${account}/repos?sort=updated&per_page=10"
    fi

    local repos_json
    repos_json="$(_orch_res_api_call "$repos_endpoint")" || return 1

    # Fetch recent events (pushes, releases, forks)
    local events_json
    events_json="$(_orch_res_api_call "users/${account}/events/public?per_page=30")" || events_json="[]"

    # Compose cache document
    jq -n \
        --arg account "$account" \
        --arg src_type "$src_type" \
        --arg fetched_at "$(date '+%Y-%m-%dT%H:%M:%S')" \
        --argjson repos "$repos_json" \
        --argjson events "$events_json" \
        '{account: $account, type: $src_type, fetched_at: $fetched_at, repos: $repos, events: $events}' \
        > "$cache_file" 2>/dev/null

    _orch_res_log INFO "cached data for $account → $cache_file (api calls: $_ORCH_RES_API_CALLS)"
}

# ---------------------------------------------------------------------------
# orch_research_analyze — analyze cached data for a source
# Args: $1 — account name
# Appends findings to _ORCH_RES_FINDINGS
# ---------------------------------------------------------------------------
orch_research_analyze() {
    local account="${1:?orch_research_analyze: account required}"
    local today cache_file

    today="$(_orch_res_today)"
    cache_file="${_ORCH_RES_CACHE_DIR}/${account}-${today}.json"

    if [[ ! -f "$cache_file" ]]; then
        _orch_res_log WARN "no cached data for $account — run fetch first"
        return 1
    fi

    _orch_res_log INFO "analyzing $account"

    # Extract new/updated repos
    local repo_summary
    repo_summary="$(jq -r '
        .repos[:10][] |
        "- \(.name): \(.description // "no description") (★\(.stargazers_count), \(.language // "unknown"))" +
        if .created_at > (now - 604800 | todate) then " [NEW]" else "" end
    ' "$cache_file" 2>/dev/null)" || repo_summary=""

    # Extract push events (recent commits)
    local push_summary
    push_summary="$(jq -r '
        [.events[] | select(.type == "PushEvent")] | .[0:5][] |
        "- [\(.repo.name)] \(.payload.commits[0].message // "no message" | split("\n")[0])"
    ' "$cache_file" 2>/dev/null)" || push_summary=""

    # Extract release events
    local release_summary
    release_summary="$(jq -r '
        [.events[] | select(.type == "ReleaseEvent")] | .[0:3][] |
        "- [\(.repo.name)] Release: \(.payload.release.tag_name // "untagged") — \(.payload.release.name // "unnamed")"
    ' "$cache_file" 2>/dev/null)" || release_summary=""

    # Extract create events (new repos/branches)
    local create_summary
    create_summary="$(jq -r '
        [.events[] | select(.type == "CreateEvent" and .payload.ref_type == "repository")] | .[0:3][] |
        "- New repo: \(.repo.name)"
    ' "$cache_file" 2>/dev/null)" || create_summary=""

    # Build findings block
    local finding="## Source: ${account}\n"

    if [[ -n "$create_summary" ]]; then
        finding+="### New Repos\n${create_summary}\n\n"
    fi

    if [[ -n "$repo_summary" ]]; then
        finding+="### Active Repos\n${repo_summary}\n\n"
    fi

    if [[ -n "$push_summary" ]]; then
        finding+="### Recent Commits (last 7 days)\n${push_summary}\n\n"
    fi

    if [[ -n "$release_summary" ]]; then
        finding+="### Releases\n${release_summary}\n\n"
    fi

    _ORCH_RES_FINDINGS+=("$finding")
    _orch_res_log INFO "analyzed $account: $(echo -e "$finding" | wc -l | tr -d ' ') lines of findings"
}

# ---------------------------------------------------------------------------
# orch_research_report — generate a research brief from all findings
# Writes to research/briefs/YYYY-MM-DD.md
# ---------------------------------------------------------------------------
orch_research_report() {
    if [[ "$_ORCH_RES_INITED" != "true" ]]; then
        _orch_res_log ERROR "not initialized — call orch_research_init first"
        return 1
    fi

    if [[ ${#_ORCH_RES_FINDINGS[@]} -eq 0 ]]; then
        _orch_res_log WARN "no findings to report — run fetch + analyze first"
        return 1
    fi

    local today brief_file
    today="$(_orch_res_today)"
    brief_file="${_ORCH_RES_BRIEFS_DIR}/${today}.md"

    {
        echo "# Research Brief — ${today}"
        echo ""
        echo "> Auto-generated by OrchyStraw auto-researcher."
        echo "> Sources: ${#_ORCH_RES_SOURCES[@]} | API calls: ${_ORCH_RES_API_CALLS}/${_ORCH_RES_API_LIMIT}"
        echo ""

        local finding
        for finding in "${_ORCH_RES_FINDINGS[@]}"; do
            echo -e "$finding"
        done

        echo "---"
        echo ""
        echo "## Relevance to OrchyStraw"
        echo ""
        echo "_Review findings above and note patterns applicable to:_"
        echo "- Agent orchestration architecture"
        echo "- Prompt engineering techniques"
        echo "- CLI tooling patterns"
        echo "- CI/CD and automation approaches"
        echo "- Multi-agent coordination strategies"
    } > "$brief_file"

    _orch_res_log INFO "brief written → $brief_file"
    echo "$brief_file"
}

# ---------------------------------------------------------------------------
# orch_research_run — full research cycle: load → fetch → analyze → report
# This is the main entry point for automated runs.
# ---------------------------------------------------------------------------
orch_research_run() {
    if [[ "$_ORCH_RES_INITED" != "true" ]]; then
        _orch_res_log ERROR "not initialized — call orch_research_init first"
        return 1
    fi

    _orch_res_log INFO "starting research cycle"
    _ORCH_RES_FINDINGS=()
    _ORCH_RES_API_CALLS=0

    # Load sources
    orch_research_load_sources || return 1

    # Fetch + analyze each source
    local entry account src_type priority notes
    for entry in "${_ORCH_RES_SOURCES[@]}"; do
        IFS='|' read -r account src_type priority notes <<< "$entry"

        orch_research_fetch "$account" "$src_type" || {
            _orch_res_log WARN "fetch failed for $account — skipping"
            continue
        }
        orch_research_analyze "$account" || {
            _orch_res_log WARN "analyze failed for $account — skipping"
            continue
        }
    done

    # Generate report
    local brief_path
    brief_path="$(orch_research_report)" || return 1

    _orch_res_log INFO "research cycle complete — brief: $brief_path (api calls: $_ORCH_RES_API_CALLS)"
}
