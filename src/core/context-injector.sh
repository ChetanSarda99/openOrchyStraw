#!/usr/bin/env bash
# context-injector.sh — Sourceable module for gathering OrchyStraw context
# Provides structured context for Claude sessions: git info, agent status, project metadata.
#
# Usage:
#   source src/core/context-injector.sh
#   context="$(orch_context_gather /path/to/project)"

[[ -n "${_ORCH_CONTEXT_INJECTOR_LOADED:-}" ]] && return 0
_ORCH_CONTEXT_INJECTOR_LOADED=1

# ── orch_context_git_info ──────────────────────────────────────────────
# Git status, branch, recent commits, upstream delta.
# Args: $1 = directory (default: pwd)
orch_context_git_info() {
    local dir="${1:-.}"
    if ! git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Not a git repository."
        return 1
    fi

    local branch ahead behind status
    branch="$(git -C "$dir" branch --show-current 2>/dev/null || echo "detached")"

    # Upstream delta
    ahead="$(git -C "$dir" rev-list --count @{upstream}..HEAD 2>/dev/null || echo "?")"
    behind="$(git -C "$dir" rev-list --count HEAD..@{upstream} 2>/dev/null || echo "?")"

    echo "Branch: $branch"
    [[ "$ahead" != "?" ]] && echo "Upstream: +${ahead}/-${behind} commits"

    # Status summary (staged/modified/untracked counts)
    local staged modified untracked
    staged="$(git -C "$dir" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')"
    modified="$(git -C "$dir" diff --numstat 2>/dev/null | wc -l | tr -d ' ')"
    untracked="$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"
    echo "Status: ${staged} staged, ${modified} modified, ${untracked} untracked"

    # Recent commits
    echo ""
    echo "Recent commits:"
    git -C "$dir" log --oneline -5 2>/dev/null | sed 's/^/  /'
}

# ── orch_context_agent_status ──────────────────────────────────────────
# Parse agents.conf and summarize active agents.
# Args: $1 = path to agents.conf
orch_context_agent_status() {
    local conf="${1:-agents.conf}"
    if [[ ! -f "$conf" ]]; then
        echo "No agents.conf found."
        return 1
    fi

    local count=0
    echo "Active agents:"
    while IFS='|' read -r id prompt ownership interval label; do
        # Skip comments and blank lines
        [[ "$id" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${id// /}" ]] && continue

        id="$(echo "$id" | xargs)"
        interval="$(echo "$interval" | xargs)"
        label="$(echo "$label" | xargs)"

        echo "  ${id} — ${label} (every ${interval} cycles)"
        ((count++))
    done < "$conf"
    echo "Total: ${count} agents"
}

# ── orch_context_project_info ──────────────────────────────────────────
# Project name, orchystraw version tag, last run time.
# Args: $1 = project directory
orch_context_project_info() {
    local dir="${1:-.}"
    local name version last_run

    name="$(basename "$(cd "$dir" && pwd)")"
    echo "Project: $name"

    # OrchyStraw version from latest tag
    version="$(git -C "$dir" describe --tags --abbrev=0 2>/dev/null || echo "untagged")"
    echo "Version: $version"

    # Last orchestration run
    local state_file="$dir/.orchystraw/state.json"
    if [[ -f "$state_file" ]]; then
        last_run="$(grep -o '"last_run":"[^"]*"' "$state_file" 2>/dev/null | head -1 | cut -d'"' -f4)"
        [[ -n "$last_run" ]] && echo "Last run: $last_run"
    fi

    # Is this an orchystraw project?
    if [[ -f "$dir/agents.conf" ]]; then
        echo "Type: OrchyStraw-managed project"
    else
        echo "Type: Standalone project"
    fi
}

# ── orch_context_gather ────────────────────────────────────────────────
# Full context string combining all sections.
# Args: $1 = project directory (default: pwd)
orch_context_gather() {
    local dir="${1:-.}"
    local shared_claude="$HOME/Projects/shared/CLAUDE.md"

    echo "═══ OrchyStraw Context ═══"
    echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo ""

    echo "── Project ──"
    orch_context_project_info "$dir"
    echo ""

    echo "── Git ──"
    orch_context_git_info "$dir"
    echo ""

    if [[ -f "$dir/agents.conf" ]]; then
        echo "── Agents ──"
        orch_context_agent_status "$dir/agents.conf"
        echo ""
    fi

    if [[ -f "$shared_claude" ]]; then
        echo "── Shared Context (summary) ──"
        head -50 "$shared_claude"
        echo ""
    fi

    echo "═══ End Context ═══"
}
