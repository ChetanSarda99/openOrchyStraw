#!/usr/bin/env bash
# =============================================================================
# analyze-prompts.sh — Prompt optimization analyzer (#202)
#
# Measures token count per agent prompt across all projects, identifies
# oversized prompts, detects redundant sections, and suggests compression.
#
# Usage:
#   ./scripts/analyze-prompts.sh                          # Analyze current project
#   ./scripts/analyze-prompts.sh --all                    # All registered projects
#   ./scripts/analyze-prompts.sh --project ~/Projects/X   # Specific project
#   ./scripts/analyze-prompts.sh --threshold 300          # Custom oversized threshold (lines)
#   ./scripts/analyze-prompts.sh --output json            # JSON output
#   ./scripts/analyze-prompts.sh --fix                    # Show actionable suggestions
#
# Requires: bash 5.0+
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Auto-detect bash 5+ ──
if (( BASH_VERSINFO[0] < 5 )); then
    for _bash5 in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$_bash5" ]] && "$_bash5" -c '(( BASH_VERSINFO[0] >= 5 ))' 2>/dev/null; then
            exec "$_bash5" "$0" "$@"
        fi
    done
    printf 'ERROR: bash 5.0+ required.\n' >&2
    exit 1
fi

# ── Defaults ──

ANALYZE_ALL=false
TARGET_PROJECT=""
OVERSIZED_THRESHOLD=500       # lines — prompts above this are "oversized"
LARGE_SECTION_THRESHOLD=100   # lines — individual sections above this trigger warnings
OUTPUT_FORMAT="table"         # table | json
SHOW_FIX=false

# ── CLI args ──

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)        ANALYZE_ALL=true; shift ;;
        --project)    TARGET_PROJECT="$2"; shift 2 ;;
        --threshold)  OVERSIZED_THRESHOLD="$2"; shift 2 ;;
        --output)     OUTPUT_FORMAT="$2"; shift 2 ;;
        --fix)        SHOW_FIX=true; shift ;;
        --help|-h)
            printf 'Usage: %s [--all] [--project PATH] [--threshold N] [--output table|json] [--fix]\n' "$0"
            exit 0
            ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
done

# ── Logging ──

_log()  { printf '[analyze %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
_warn() { printf '  \033[33mWARN\033[0m  %s\n' "$*"; }
_ok()   { printf '  \033[32m OK \033[0m  %s\n' "$*"; }

# ── Analysis structures ──

declare -g -A PROMPT_DATA=()      # "project:agent:metric" -> value
declare -g -a FINDINGS=()         # array of finding strings
declare -g -a ALL_PROJECTS=()     # projects analyzed

# ── Helpers ──

_estimate_tokens() {
    local chars="$1"
    echo $(( (chars + 3) / 4 ))
}

# Detect redundant sections across prompts in a project
# Looks for section headers (## ...) that appear in multiple prompts identically
_find_redundant_sections() {
    local project_path="$1"
    local prompts_dir="$project_path/prompts"
    [[ ! -d "$prompts_dir" ]] && return

    # Collect all section headers with their content hashes
    declare -A section_hashes=()   # "header_text" -> "file1:hash file2:hash ..."
    declare -A section_content=()  # "header_text" -> first occurrence content (for display)

    while IFS= read -r prompt_file; do
        [[ ! -f "$prompt_file" ]] && continue
        local agent_name
        agent_name="$(basename "$(dirname "$prompt_file")")/$(basename "$prompt_file")"

        local current_header=""
        local current_content=""
        local in_section=false

        while IFS= read -r line; do
            if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
                # Save previous section
                if [[ "$in_section" == true && -n "$current_header" ]]; then
                    local content_hash
                    content_hash=$(printf '%s' "$current_content" | shasum -a 256 2>/dev/null | cut -d' ' -f1 || printf '%d' "${#current_content}")
                    section_hashes["$current_header"]+="$agent_name:$content_hash "
                    if [[ -z "${section_content[$current_header]+x}" ]]; then
                        section_content["$current_header"]="$current_content"
                    fi
                fi
                current_header="${BASH_REMATCH[1]}"
                current_content=""
                in_section=true
            elif [[ "$in_section" == true ]]; then
                current_content+="$line"$'\n'
            fi
        done < "$prompt_file"

        # Save final section
        if [[ "$in_section" == true && -n "$current_header" ]]; then
            local content_hash
            content_hash=$(printf '%s' "$current_content" | shasum -a 256 2>/dev/null | cut -d' ' -f1 || printf '%d' "${#current_content}")
            section_hashes["$current_header"]+="$agent_name:$content_hash "
            if [[ -z "${section_content[$current_header]+x}" ]]; then
                section_content["$current_header"]="$current_content"
            fi
        fi
    done <<< "$(find "$prompts_dir" -name '*.txt' -o -name '*.md' 2>/dev/null | sort)"

    # Find sections that appear with identical content in multiple files
    for header in "${!section_hashes[@]}"; do
        local entries="${section_hashes[$header]}"
        local -A hash_count=()
        local total_occurrences=0

        for entry in $entries; do
            local hash="${entry##*:}"
            hash_count["$hash"]=$(( ${hash_count[$hash]:-0} + 1 ))
            total_occurrences=$((total_occurrences + 1))
        done

        # If same content appears 3+ times, it's redundant
        for hash in "${!hash_count[@]}"; do
            local count="${hash_count[$hash]}"
            if [[ "$count" -ge 3 ]]; then
                local content="${section_content[$header]}"
                local content_lines
                content_lines=$(printf '%s' "$content" | wc -l | tr -d ' ')
                local content_tokens
                content_tokens=$(_estimate_tokens "${#content}")
                FINDINGS+=("REDUNDANT: \"## $header\" appears identically in $count prompts (~${content_tokens} tokens each). Move to shared context or CLAUDE.md.")
            fi
        done
    done
}

# Detect oversized sections within a single prompt
_find_oversized_sections() {
    local prompt_file="$1"
    local agent_id="$2"
    local project_name="$3"

    local current_header=""
    local section_lines=0
    local in_section=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            # Check previous section
            if [[ "$in_section" == true && "$section_lines" -gt "$LARGE_SECTION_THRESHOLD" ]]; then
                FINDINGS+=("LARGE_SECTION: $project_name/$agent_id: \"## $current_header\" has $section_lines lines. Consider condensing.")
            fi
            current_header="${BASH_REMATCH[1]}"
            section_lines=0
            in_section=true
        else
            section_lines=$((section_lines + 1))
        fi
    done < "$prompt_file"

    # Check final section
    if [[ "$in_section" == true && "$section_lines" -gt "$LARGE_SECTION_THRESHOLD" ]]; then
        FINDINGS+=("LARGE_SECTION: $project_name/$agent_id: \"## $current_header\" has $section_lines lines. Consider condensing.")
    fi
}

# ── Analyze a single project ──

_analyze_project() {
    local project_path="$1"
    local project_name
    project_name="$(basename "$project_path")"

    ALL_PROJECTS+=("$project_name")
    _log "Analyzing: $project_name"

    # Find agents.conf
    local conf=""
    for candidate in "$project_path/agents.conf" "$project_path/scripts/agents.conf"; do
        [[ -f "$candidate" ]] && { conf="$candidate"; break; }
    done

    if [[ -z "$conf" ]]; then
        _log "  SKIP: No agents.conf"
        PROMPT_DATA["$project_name:status"]="no_config"
        return
    fi

    PROMPT_DATA["$project_name:status"]="ok"

    local total_lines=0
    local total_tokens=0
    local agent_count=0
    local oversized_count=0

    # Parse each agent
    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed="${raw_line#"${raw_line%%[![:space:]]*}"}"
        [[ "$trimmed" == \#* ]] && continue

        IFS='|' read -r f_id f_prompt _ <<< "$raw_line"
        f_id="${f_id#"${f_id%%[![:space:]]*}"}"
        f_id="${f_id%"${f_id##*[![:space:]]}"}"
        f_prompt="${f_prompt#"${f_prompt%%[![:space:]]*}"}"
        f_prompt="${f_prompt%"${f_prompt##*[![:space:]]}"}"

        [[ -z "$f_id" ]] && continue
        agent_count=$((agent_count + 1))

        local prompt_file="$project_path/$f_prompt"

        if [[ ! -f "$prompt_file" ]]; then
            PROMPT_DATA["$project_name:$f_id:status"]="missing"
            FINDINGS+=("MISSING: $project_name/$f_id prompt not found: $f_prompt")
            continue
        fi

        local lines chars tokens
        lines=$(wc -l < "$prompt_file" | tr -d ' ')
        chars=$(wc -c < "$prompt_file" | tr -d ' ')
        tokens=$(_estimate_tokens "$chars")

        PROMPT_DATA["$project_name:$f_id:lines"]="$lines"
        PROMPT_DATA["$project_name:$f_id:chars"]="$chars"
        PROMPT_DATA["$project_name:$f_id:tokens"]="$tokens"

        total_lines=$((total_lines + lines))
        total_tokens=$((total_tokens + tokens))

        # Check if oversized
        if [[ "$lines" -gt "$OVERSIZED_THRESHOLD" ]]; then
            oversized_count=$((oversized_count + 1))
            PROMPT_DATA["$project_name:$f_id:oversized"]="yes"
            FINDINGS+=("OVERSIZED: $project_name/$f_id is $lines lines (~${tokens} tokens). Threshold: $OVERSIZED_THRESHOLD lines.")
        else
            PROMPT_DATA["$project_name:$f_id:oversized"]="no"
        fi

        # Analyze individual sections
        _find_oversized_sections "$prompt_file" "$f_id" "$project_name"

        # Count sections
        local section_count
        section_count=$(grep -cE '^##[[:space:]]' "$prompt_file" 2>/dev/null || echo 0)
        PROMPT_DATA["$project_name:$f_id:sections"]="$section_count"

    done < "$conf"

    PROMPT_DATA["$project_name:agent_count"]="$agent_count"
    PROMPT_DATA["$project_name:total_lines"]="$total_lines"
    PROMPT_DATA["$project_name:total_tokens"]="$total_tokens"
    PROMPT_DATA["$project_name:oversized_count"]="$oversized_count"

    # Find redundant sections across this project's prompts
    _find_redundant_sections "$project_path"
}

# ── Output formatters ──

_output_table() {
    printf '\n'
    printf '=== Prompt Analysis Report ===\n\n'

    for project_name in "${ALL_PROJECTS[@]}"; do
        local status="${PROMPT_DATA[$project_name:status]:-unknown}"
        [[ "$status" == "no_config" ]] && continue

        local agent_count="${PROMPT_DATA[$project_name:agent_count]:-0}"
        local total_tokens="${PROMPT_DATA[$project_name:total_tokens]:-0}"
        local total_lines="${PROMPT_DATA[$project_name:total_lines]:-0}"
        local oversized="${PROMPT_DATA[$project_name:oversized_count]:-0}"

        printf '## %s  (%d agents, ~%d total tokens, %d oversized)\n\n' \
            "$project_name" "$agent_count" "$total_tokens" "$oversized"

        printf '  %-18s │ %6s │ %8s │ %5s │ %8s │ %s\n' \
            "AGENT" "LINES" "TOKENS" "SECS" "STATUS" "NOTES"
        printf '  ──────────────────┼────────┼──────────┼───────┼──────────┼──────\n'

        # Re-parse agents from conf to get ordered listing
        local conf=""
        for pname in "${ALL_PROJECTS[@]}"; do
            [[ "$pname" != "$project_name" ]] && continue
        done

        # List agents with data
        for key in "${!PROMPT_DATA[@]}"; do
            [[ "$key" != "$project_name:"*":lines" ]] && continue
            local agent_id="${key#$project_name:}"
            agent_id="${agent_id%:lines}"

            local lines="${PROMPT_DATA[$project_name:$agent_id:lines]:-0}"
            local tokens="${PROMPT_DATA[$project_name:$agent_id:tokens]:-0}"
            local sections="${PROMPT_DATA[$project_name:$agent_id:sections]:-0}"
            local oversized_flag="${PROMPT_DATA[$project_name:$agent_id:oversized]:-no}"

            local status_sym="OK"
            local notes=""

            if [[ "$oversized_flag" == "yes" ]]; then
                status_sym="OVERSIZED"
                notes="reduce by ~$(( (lines - OVERSIZED_THRESHOLD) * 100 / lines ))%"
            fi

            printf '  %-18s │ %6d │ %8d │ %5d │ %8s │ %s\n' \
                "$agent_id" "$lines" "$tokens" "$sections" "$status_sym" "$notes"
        done

        printf '\n'
    done

    # Print findings
    if [[ ${#FINDINGS[@]} -gt 0 ]]; then
        printf '=== Findings ===\n\n'
        local prev_type=""
        for finding in "${FINDINGS[@]}"; do
            local type="${finding%%:*}"
            if [[ "$type" != "$prev_type" ]]; then
                printf '\n  [%s]\n' "$type"
                prev_type="$type"
            fi
            printf '  - %s\n' "${finding#*: }"
        done
        printf '\n'
    fi

    # Suggestions
    if [[ "$SHOW_FIX" == true ]]; then
        _print_suggestions
    fi
}

_output_json() {
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '  "threshold_lines": %d,\n' "$OVERSIZED_THRESHOLD"
    printf '  "projects": [\n'

    local first_proj=true
    for project_name in "${ALL_PROJECTS[@]}"; do
        local status="${PROMPT_DATA[$project_name:status]:-unknown}"
        [[ "$status" == "no_config" ]] && continue

        [[ "$first_proj" == true ]] || printf ',\n'
        first_proj=false

        printf '    {\n'
        printf '      "name": "%s",\n' "$project_name"
        printf '      "agents": %s,\n' "${PROMPT_DATA[$project_name:agent_count]:-0}"
        printf '      "total_tokens": %s,\n' "${PROMPT_DATA[$project_name:total_tokens]:-0}"
        printf '      "total_lines": %s,\n' "${PROMPT_DATA[$project_name:total_lines]:-0}"
        printf '      "oversized_count": %s,\n' "${PROMPT_DATA[$project_name:oversized_count]:-0}"
        printf '      "prompts": [\n'

        local first_agent=true
        for key in "${!PROMPT_DATA[@]}"; do
            [[ "$key" != "$project_name:"*":lines" ]] && continue
            local agent_id="${key#$project_name:}"
            agent_id="${agent_id%:lines}"

            [[ "$first_agent" == true ]] || printf ',\n'
            first_agent=false

            printf '        {"agent": "%s", "lines": %s, "tokens": %s, "sections": %s, "oversized": %s}' \
                "$agent_id" \
                "${PROMPT_DATA[$project_name:$agent_id:lines]:-0}" \
                "${PROMPT_DATA[$project_name:$agent_id:tokens]:-0}" \
                "${PROMPT_DATA[$project_name:$agent_id:sections]:-0}" \
                "$([[ "${PROMPT_DATA[$project_name:$agent_id:oversized]:-no}" == "yes" ]] && echo "true" || echo "false")"
        done

        printf '\n      ]\n'
        printf '    }'
    done

    printf '\n  ],\n'
    printf '  "findings": [\n'

    local first_f=true
    for finding in "${FINDINGS[@]}"; do
        [[ "$first_f" == true ]] || printf ',\n'
        first_f=false
        local type="${finding%%:*}"
        local msg="${finding#*: }"
        printf '    {"type": "%s", "message": "%s"}' "$type" "$msg"
    done

    printf '\n  ]\n'
    printf '}\n'
}

_print_suggestions() {
    printf '\n=== Optimization Suggestions ===\n\n'

    local has_oversized=false
    local has_redundant=false

    for finding in "${FINDINGS[@]}"; do
        [[ "$finding" == OVERSIZED:* ]] && has_oversized=true
        [[ "$finding" == REDUNDANT:* ]] && has_redundant=true
    done

    if [[ "$has_oversized" == true ]]; then
        printf '  1. OVERSIZED PROMPTS:\n'
        printf '     - Move stable sections (Tech Stack, Rules, File Ownership) to CLAUDE.md\n'
        printf '     - Use prompt-compression.sh (already built) to auto-condense stable sections\n'
        printf '     - Remove duplicate "What is OrchyStraw" boilerplate\n'
        printf '     - Consolidate overlapping task lists\n'
        printf '     - Target: each prompt under %d lines\n\n' "$OVERSIZED_THRESHOLD"
    fi

    if [[ "$has_redundant" == true ]]; then
        printf '  2. REDUNDANT SECTIONS:\n'
        printf '     - Move shared content to prompts/00-shared-context/\n'
        printf '     - Reference CLAUDE.md for project-wide info instead of duplicating\n'
        printf '     - Use prompt-template.sh includes for shared sections\n\n'
    fi

    printf '  3. GENERAL OPTIMIZATION:\n'
    printf '     - Enable prompt compression: ORCH_PROMPT_COMPRESSION=1\n'
    printf '     - Set token budgets: ORCH_PROMPT_TOKEN_BUDGET=4000\n'
    printf '     - Use tiered prompt loading (full on first run, standard on repeat)\n'
    printf '     - Review prompts quarterly — remove completed tasks, stale context\n\n'
}

# ── Discover projects ──

_discover_projects() {
    local -a projects=()

    if [[ -n "$TARGET_PROJECT" ]]; then
        projects=("$TARGET_PROJECT")
    elif [[ "$ANALYZE_ALL" == true ]]; then
        # Read from registry
        local registry="$HOME/.orchystraw/registry.jsonl"
        if [[ -f "$registry" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if [[ "$line" =~ \"path\":\"([^\"]+)\" ]]; then
                    local p="${BASH_REMATCH[1]}"
                    [[ -d "$p" ]] && projects+=("$p")
                fi
            done < "$registry"
        fi
        # Include self
        local self_found=false
        for p in "${projects[@]}"; do
            [[ "$p" == "$ORCH_ROOT" ]] && self_found=true
        done
        [[ "$self_found" == false ]] && projects+=("$ORCH_ROOT")
    else
        # Current project only
        projects=("$ORCH_ROOT")
    fi

    printf '%s\n' "${projects[@]}"
}

# ── Main ──

main() {
    _log "OrchyStraw Prompt Analyzer"

    local -a projects=()
    while IFS= read -r p; do
        [[ -n "$p" ]] && projects+=("$p")
    done <<< "$(_discover_projects)"

    if [[ ${#projects[@]} -eq 0 ]]; then
        _log "No projects found."
        exit 1
    fi

    _log "Analyzing ${#projects[@]} project(s)"

    for project in "${projects[@]}"; do
        _analyze_project "$project"
    done

    case "$OUTPUT_FORMAT" in
        table) _output_table ;;
        json)  _output_json ;;
    esac

    # Summary
    local total_findings=${#FINDINGS[@]}
    local oversized=0
    for f in "${FINDINGS[@]}"; do
        [[ "$f" == OVERSIZED:* ]] && oversized=$((oversized + 1))
    done

    _log "Done: $total_findings findings ($oversized oversized prompts)"

    # Exit with warning code if oversized prompts found
    [[ "$oversized" -gt 0 ]] && exit 2
    exit 0
}

main "$@"
